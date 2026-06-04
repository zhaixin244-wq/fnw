# reg_interface PR 沟通记录

> 版本：v1.0
> 日期：2026-06-04
> 阶段：stageB phase2（执行中）
> 当前进度：stageB phase2（执行中）
> 已完成：（无）
> 父模块：fpga_partial_reconfig
> 子模块 ID：5（L1）
> 与其他子模块关系：聚合所有子模块的状态/控制/统计信号，对外暴露 APB 接口

---

## 父模块上下文摘要

**功能**：FPGA 部分重配置控制器，支持多租户隔离和比特流完整性校验。

**关键约束**：16nm / 500MHz / 逻辑 < 200kGates / 动态功耗 < 180mW

**软件接口**：PCIe PF/VF 驱动 + APB MMIO，中断为主+轮询为辅

**兄弟模块信号聚合**：
- bitstream_rx_engine：进度/FIFO 水位/统计/暂停控制
- bitstream_val_mgr：校验状态/统计/错误注入/版本信息
- icap_write_engine：ICAP 状态/统计/时序配置/超时配置
- isolation_mgr：区域表/租户权限/违规状态/回滚状态

---

## 继承 REQ（同步自父模块）

| 全局 REQ | 约束项 | 确认值 | 优先级 | 适用性 |
|----------|--------|--------|--------|--------|
| REQ-002 | 接口协议 | APB 32-bit 从接口 | Must | 适用——本模块实现 APB 从接口 |
| REQ-016 | 中断接口 | 5 中断（重配完成/校验错误/回滚/隔离违规/DMA超时）+ W1C | Should | 适用——本模块实现中断控制 |
| REQ-017 | 调试接口 | APB 寄存器访问内部状态 | Could | 适用——本模块提供调试寄存器 |
| REQ-019 | 软件接口 | PCIe PF/VF 驱动 + APB MMIO | Should | 适用——本模块是软件访问入口 |
| REQ-020 | 系统级约束 | BE QoS / Device Cache 属性 | Should | 适用——APB 接口系统集成 |
| REQ-033 | 错误注入控制 | APB 可注入 CRC/超时/ICAP 故障 | Should | 适用——本模块提供注入控制寄存器 |
| REQ-034 | 状态机观测 | 内部 FSM 状态暴露到 APB | Should | 适用——本模块提供观测寄存器 |
| REQ-035 | 性能计数器 | 重配置次数/耗时/错误计数 | Should | 适用——本模块实现计数器 |
| REQ-036 | 超时阈值可配 | DMA/ICAP 超时阈值 APB 可配 | Should | 适用——本模块提供配置寄存器 |

---

## [PHASE-START] stageB phase2

### 头脑风暴 Feature Discovery

**触发条件**：子模块从 stageB phase2 开始
**执行方式**：按 5 个维度探索（功能扩展/性能优化/兼容性/可测试性/可维护性）

---

#### 维度 1：功能扩展

**Q1**：reg_interface 在寄存器接口方面，是否有父模块 REQ 未覆盖的额外功能需求？

**A1**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| 寄存器保护 | 关键配置寄存器写保护（需特定序列解锁） | Must | 补充 REQ-018（物理隔离） |
| 寄存器版本号 | 硬件版本寄存器，软件可读取识别硬件版本 | Should | 补充 REQ-032 |
| 软件复位控制 | APB 可触发各子模块软件复位 | Should | 运维灵活性 |
| 寄存器镜像 | 关键寄存器双镜像，读回校验防 SEU | Could | 扩展 REQ-009 |

---

#### 维度 2：性能优化

**Q2**：在 APB 寄存器访问性能方面，是否有额外优化需求？

**A2**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| APB 零等待访问 | 寄存器读写无等待状态 | Should | 优化 REQ-002 |
| 批量读取 | 支持连续地址批量读取（Burst） | Could | 扩展 REQ-002 |
| 寄存器缓存 | 热点寄存器缓存在 APB 接口侧 | Could | 优化 REQ-002 |

---

#### 维度 3：兼容性

**Q3**：是否需要兼容不同版本的 APB 协议或寄存器映射？

**A3**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| APB3/APB4 兼容 | 支持 APB3 和 APB4 协议 | Should | 扩展 REQ-002 |
| 寄存器映射可配 | 部分寄存器地址可通过硬件配置调整 | Could | 扩展 REQ-002 |

---

#### 维度 4：可测试性

**Q4**：在寄存器接口的验证方面，有哪些额外需求？

**A4**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| 寄存器回环测试 | 写入后读回校验，验证 APB 通路完整性 | Should | 验证 REQ-002 |
| 只读寄存器写保护测试 | 验证只读寄存器写保护功能 | Should | 验证 REQ-018 |
| 中断触发测试 | APB 可手动触发每个中断，验证中断通路 | Should | 验证 REQ-016 |

---

#### 维度 5：可维护性

**Q5**：在寄存器接口的运维和调试方面，有哪些需求？

**A5**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| 访问日志 | 记录最近 N 次 APB 访问（地址/数据/读写） | Should | 调试支持 |
| 中断状态快照 | 中断触发时自动保存相关状态寄存器 | Should | 调试支持 |
| 寄存器访问统计 | 每个寄存器的读/写次数统计 | Could | 运维支持 |

---

### 头脑风暴追加 REQ 汇总

基于 5 个维度探索，以下 Feature 建议追加为子模块本地 REQ：

| 本地 REQ | Feature | 维度 | 优先级 | 确认值 |
|----------|---------|------|--------|--------|
| LREQ-001 | 寄存器写保护 | 功能扩展 | Must | 关键配置寄存器需特定序列解锁后才能写入 |
| LREQ-002 | 软件复位控制 | 功能扩展 | Should | APB 可触发各子模块独立软件复位 |
| LREQ-003 | 硬件版本寄存器 | 功能扩展 | Should | 硬件版本号寄存器，软件可读取 |
| LREQ-004 | APB 零等待访问 | 性能优化 | Should | 寄存器读写无等待状态 |
| LREQ-005 | APB3/APB4 兼容 | 兼容性 | Should | 支持 APB3 和 APB4 协议 |
| LREQ-006 | 中断触发测试 | 可测试性 | Should | APB 可手动触发每个中断 |
| LREQ-007 | 访问日志 | 可维护性 | Should | 记录最近 N 次 APB 访问详情 |
| LREQ-008 | 中断状态快照 | 可维护性 | Should | 中断触发时自动保存相关状态 |

### 矛盾检查

| 检查对 | 结果 | 说明 |
|--------|------|------|
| LREQ-001（写保护）vs REQ-018（物理隔离） | 无矛盾 | 写保护是物理隔离的具体实现 |
| LREQ-004（零等待）vs REQ-002（APB） | 无矛盾 | APB 标准支持零等待 |
| LREQ-005（APB3/4）vs REQ-020（系统约束） | 无矛盾 | APB 版本兼容不影响系统集成 |

**结论**：追加 8 个本地 REQ，无矛盾。

### 用户确认

用户确认 8 个本地 REQ 均可接受。补充建议：LREQ-001 解锁序列采用标准 Key-Value 模式（写入 0x55AA 再写入 0xAA55 解锁）。

## [PHASE-END] stageB phase2

---

## [PHASE-START] stageC phase1

### 矛盾检测执行

**检测范围**：
- 基础检测：17 条（针对本子模块继承 REQ + 本地 REQ 适用项）
- 动态检测：3 条（DYN-01/02/03）
- 条件检测：不适用（REQ-022~025 均为 skipped）

**检测结果**：

| # | 规则 ID | 规则名称 | 涉及 REQ | 结果 | 说明 |
|---|---------|----------|----------|------|------|
| 1 | FREQ-01 | 频率 vs 工艺 | REQ-001(继承) | PASS | 16nm/500MHz，APB 寄存器逻辑远低于 Fmax |
| 2 | FREQ-02 | 延迟 vs 频率 | REQ-004(继承) | PASS | APB 寄存器访问延迟 < 10 cycles |
| 3 | AREA-01 | 面积 vs 功能复杂度 | REQ-005(继承) | PASS | 700 行预估，逻辑面积 ~35kGates |
| 4 | AREA-02 | 面积 vs 并行度 | REQ-003(继承) | PASS | 单端口 APB，无并行需求 |
| 5 | AREA-03 | 可靠性 vs 面积 | REQ-009(继承) | PASS | 写保护逻辑面积开销 < 2kGates |
| 6 | POWER-01 | 功耗 vs 工艺/频率 | REQ-001/005(继承) | PASS | APB 接口逻辑功耗 < 10mW |
| 7 | POWER-02 | 低功耗 vs DFT | REQ-007/008(继承) | PASS | 标准方案 |
| 8 | IO-01 | 接口位宽 vs 数据粒度 | REQ-002(继承) | PASS | APB 32-bit = 寄存器宽度 |
| 9 | IO-02 | 多模块共享资源 | REQ-012(继承) | N/A | 本子模块不直接访问 SRAM |
| 10 | IO-03 | 安全隔离 vs 地址碎片化 | REQ-018(继承) | PASS | APB 地址空间充足，无碎片化 |
| 11 | PVT-01 | PVT vs 功耗 | REQ-013(继承) | PASS | APB 接口功耗裕量充足 |
| 12 | MEM-01 | 存储 vs 面积 | REQ-012(继承) | PASS | 仅寄存器阵列，无 SRAM |
| 13 | CDC-01 | CDC vs 时序裕量 | REQ-011(继承) | N/A | APB 在主时钟域内，无 CDC |
| 14 | PERF-01 | 延迟 vs 吞吐 | REQ-004(继承) | PASS | APB 单事务访问，无矛盾 |
| 15 | DYN-01 | 功能重叠 | LREQ vs 继承 REQ | PASS | LREQ-001(写保护)与 REQ-018(隔离)功能互补 |
| 16 | DYN-02 | PPA 交叉矛盾 | LREQ vs 继承 REQ | PASS | 本地 REQ 无额外 PPA 约束 |
| 17 | DYN-03 | 接口冲突 | LREQ vs REQ-002 | PASS | 本地 REQ 均使用 APB 接口 |

---

### 矛盾检测结果汇总

| 类别 | 数量 |
|------|------|
| PASS | 15 |
| WARN | 0 |
| N/A | 2 |
| **矛盾** | **0 个** |
| **警告** | **0 个** |

---

## [PHASE-END] stageC phase1

---

## [PHASE-START] stageC phase2

### 需求确认汇总表

> schema_version: 1.0
> module_name: reg_interface
> parent_module: fpga_partial_reconfig
> date: 2026-06-04
> total_reqs: 17（9 继承 + 8 本地）
> priority_distribution: Must=3, Should=13, Could=1

| # | REQ | 约束项 | 确认值 | 优先级 | 状态 | 来源 |
|---|-----|--------|--------|--------|------|------|
| 1 | REQ-002 | APB 接口 | APB 32-bit 从接口 | Must | confirmed | 继承自父模块 |
| 2 | REQ-016 | 中断接口 | 5 中断（重配完成/校验错误/回滚/隔离违规/DMA超时）+ W1C | Should | confirmed | 继承自父模块 |
| 3 | REQ-017 | 调试接口 | APB 寄存器访问内部状态 | Could | confirmed | 继承自父模块 |
| 4 | REQ-019 | 软件接口 | PCIe PF/VF 驱动 + APB MMIO | Should | confirmed | 继承自父模块 |
| 5 | REQ-020 | 系统级约束 | BE QoS / Device Cache 属性 | Should | confirmed | 继承自父模块 |
| 6 | REQ-033 | 错误注入控制 | APB 可注入 CRC/超时/ICAP 故障 | Should | confirmed | 继承自父模块 |
| 7 | REQ-034 | 状态机观测 | 内部 FSM 状态暴露到 APB | Should | confirmed | 继承自父模块 |
| 8 | REQ-035 | 性能计数器 | 重配置次数/耗时/错误计数 | Should | confirmed | 继承自父模块 |
| 9 | REQ-036 | 超时阈值可配 | DMA/ICAP 超时阈值 APB 可配 | Should | confirmed | 继承自父模块 |
| 10 | LREQ-001 | 寄存器写保护 | Key-Value 解锁（0x55AA → 0xAA55） | Must | confirmed | 用户确认 |
| 11 | LREQ-002 | 软件复位控制 | APB 可触发各子模块独立软件复位 | Should | confirmed | 头脑风暴新增 |
| 12 | LREQ-003 | 硬件版本寄存器 | 硬件版本号寄存器，软件可读 | Should | confirmed | 头脑风暴新增 |
| 13 | LREQ-004 | APB 零等待访问 | 寄存器读写无等待状态 | Should | confirmed | 头脑风暴新增 |
| 14 | LREQ-005 | APB3/APB4 兼容 | 支持 APB3 和 APB4 协议 | Should | confirmed | 头脑风暴新增 |
| 15 | LREQ-006 | 中断触发测试 | APB 可手动触发每个中断 | Should | confirmed | 头脑风暴新增 |
| 16 | LREQ-007 | 访问日志 | 记录最近 N 次 APB 访问详情 | Should | confirmed | 头脑风暴新增 |
| 17 | LREQ-008 | 中断状态快照 | 中断触发时自动保存相关状态 | Should | confirmed | 头脑风暴新增 |

### 优先级统计

| 优先级 | 数量 | REQ 编号 |
|--------|------|----------|
| Must | 3 | REQ-002, LREQ-001 |
| Should | 13 | REQ-016, REQ-019, REQ-020, REQ-033, REQ-034, REQ-035, REQ-036, LREQ-002~008 |
| Could | 1 | REQ-017 |

### 冻结规则

**冻结条件**：用户确认本汇总表后自动冻结
**冻结范围**：17 项 REQ（9 继承 + 8 本地）

## [PHASE-END] stageC phase2
