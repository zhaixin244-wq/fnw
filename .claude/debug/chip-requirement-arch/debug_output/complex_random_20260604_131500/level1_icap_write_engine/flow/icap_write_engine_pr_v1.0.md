# icap_write_engine PR 沟通记录

> 版本：v1.0
> 日期：2026-06-04
> 阶段：stageB phase2（执行中）
> 当前进度：stageB phase2（执行中）
> 已完成：（无）
> 父模块：fpga_partial_reconfig
> 子模块 ID：3（L1）
> 上游依赖：bitstream_val_mgr（子模块 2）

---

## 父模块上下文摘要

**功能**：FPGA 部分重配置控制器，通过 PCIe DMA 或本地 Flash 接收比特流，在运行时对 FPGA 部分区域进行动态重配置。

**关键约束**：16nm / 500MHz / 逻辑 < 200kGates / 动态功耗 < 180mW

**上游模块**：bitstream_val_mgr — 输出校验通过且解压后的比特流数据

**下游目标**：FPGA ICAP 配置接口（Xilinx 7-series 兼容，32-bit，顺序写入）

---

## 继承 REQ（同步自父模块）

| 全局 REQ | 约束项 | 确认值 | 优先级 | 适用性 |
|----------|--------|--------|--------|--------|
| REQ-002 | 接口协议 | ICAP 32-bit（Xilinx 7-series 兼容） | Must | 适用——本模块驱动 ICAP 接口 |
| REQ-004 | 延迟与吞吐 | 整体重配延迟 < 200ms | Should | 适用——ICAP 写入延迟计入总延迟 |
| REQ-006 | 时钟与复位 | ICAP 独立时钟域（100~200MHz） | Must | 适用——本模块在 ICAP 时钟域工作 |
| REQ-011 | CDC 策略 | 主域→ICAP：异步 FIFO（深度≥4） | Should | 适用——本模块接收跨域数据 |
| REQ-014 | 接口时序约束 | ICAP: setup ≤ 2ns, output delay ≤ 3ns | Should | 适用——本模块驱动 ICAP 时序 |
| REQ-028 | 时钟树约束 | SSC 1% down-spread / OCV 5% | Should | 适用——ICAP 时钟域需时钟树约束 |
| REQ-031 | 传输-校验-写入流水线 | 三阶段重叠，写入段与校验段并行 | Should | 适用——本模块实现写入段 |
| REQ-036 | 运行时可配置超时阈值 | ICAP 超时阈值 APB 可配 | Should | 适用——本模块实现 ICAP 超时 |

---

## [PHASE-START] stageB phase2

### 头脑风暴 Feature Discovery

**触发条件**：子模块从 stageB phase2 开始
**执行方式**：按 5 个维度探索（功能扩展/性能优化/兼容性/可测试性/可维护性）

---

#### 维度 1：功能扩展

**Q1**：icap_write_engine 在 ICAP 写入方面，是否有父模块 REQ 未覆盖的额外功能需求？

**A1**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| ICAP 写入状态机 | 完整的写入状态机（空闲/接收/写入/完成/错误） | Must | 补充 REQ-002 |
| 写入顺序保证 | 保证比特流数据按顺序写入 ICAP，无乱序 | Must | 补充 REQ-002 |
| ICAP 复位序列 | 上电后 ICAP 初始化序列（同步字/命令头） | Should | 补充 REQ-002 |
| 写入暂停/恢复 | 支持写入过程中暂停和恢复 | Should | 扩展 REQ-031 |

---

#### 维度 2：性能优化

**Q2**：在 ICAP 写入性能方面，是否有额外优化需求？

**A2**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| ICAP 写入流水线 | 异步 FIFO 读取与 ICAP 写入重叠执行 | Should | 优化 REQ-031 |
| 自适应写入速率 | 根据 ICAP 就绪信号动态调整写入速率 | Could | 扩展 REQ-014 |
| 写入预取 | 从异步 FIFO 预取下一数据，减少 ICAP 等待 | Should | 优化 REQ-031 |

---

#### 维度 3：兼容性

**Q3**：是否需要兼容不同版本的 ICAP 接口？

**A3**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| ICAP 时序可配 | ICAP 时序参数（setup/hold/delay）可通过 APB 配置 | Should | 扩展 REQ-014 |
| 多 FPGA 型号适配 | 不同 FPGA 型号的 ICAP 时序差异适配 | Could | 扩展 REQ-002 |

---

#### 维度 4：可测试性

**Q4**：在 ICAP 写入引擎的验证方面，有哪些额外需求？

**A4**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| ICAP 回环测试 | 将写入数据回环读出，验证 ICAP 通路完整性 | Should | 验证 REQ-002 |
| 写入数据校验 | 写入后回读校验，确认数据正确写入 | Could | 补充 REQ-009 |
| ICAP 状态观测 | APB 可观测 ICAP 当前状态（空闲/忙碌/错误） | Should | 调试支持 |

---

#### 维度 5：可维护性

**Q5**：在 ICAP 写入引擎的运维和调试方面，有哪些需求？

**A5**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| 写入耗时统计 | 记录每次 ICAP 写入的耗时（cycles） | Should | 扩展 REQ-035 |
| ICAP 错误日志 | 记录最近 N 次 ICAP 错误的详细信息 | Should | 调试支持 |
| 写入进度反馈 | 向上游模块反馈当前写入进度 | Should | 与 REQ-037 协同 |

---

### 头脑风暴追加 REQ 汇总

基于 5 个维度探索，以下 Feature 建议追加为子模块本地 REQ：

| 本地 REQ | Feature | 维度 | 优先级 | 确认值 |
|----------|---------|------|--------|--------|
| LREQ-001 | ICAP 写入状态机 | 功能扩展 | Must | 完整 FSM（空闲/接收/写入/完成/错误），非法状态回收至空闲 |
| LREQ-002 | 写入顺序保证 | 功能扩展 | Must | 保证比特流数据按顺序写入 ICAP，无乱序 |
| LREQ-003 | ICAP 复位序列 | 功能扩展 | Should | 上电后 ICAP 初始化序列（同步字/命令头） |
| LREQ-004 | 写入暂停/恢复 | 功能扩展 | Should | 支持写入过程中暂停和恢复 |
| LREQ-005 | 写入预取 | 性能优化 | Should | 从异步 FIFO 预取下一数据，减少 ICAP 等待 |
| LREQ-006 | ICAP 时序可配 | 兼容性 | Should | ICAP 时序参数可通过 APB 配置 |
| LREQ-007 | ICAP 状态观测 | 可测试性 | Should | APB 可观测 ICAP 当前状态 |
| LREQ-008 | ICAP 错误日志 | 可维护性 | Should | 记录最近 N 次 ICAP 错误详情 |

### 矛盾检查

| 检查对 | 结果 | 说明 |
|--------|------|------|
| LREQ-005（预取）vs REQ-011（异步 FIFO） | 无矛盾 | 预取在 FIFO 读取端优化 |
| LREQ-006（时序可配）vs REQ-014（setup≤2ns） | 无矛盾 | 可配参数在协议约束范围内 |
| LREQ-001（状态机）vs REQ-036（超时） | 无矛盾 | 超时是状态机的异常处理分支 |

**结论**：追加 8 个本地 REQ，无矛盾。

### 用户确认

用户确认 8 个本地 REQ 均可接受。补充建议：LREQ-006 ICAP 时序可配，建议通过 APB 寄存器配置 ICAP 时钟分频系数。

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
| 1 | FREQ-01 | 频率 vs 工艺 | REQ-001(继承) | PASS | 16nm 支持 ICAP 100~200MHz |
| 2 | FREQ-02 | 延迟 vs 频率 | REQ-004(继承) | PASS | ICAP 写入延迟在 200ms 预算内 |
| 3 | AREA-01 | 面积 vs 功能复杂度 | REQ-005(继承) | PASS | 500 行预估，逻辑面积 ~25kGates |
| 4 | AREA-02 | 面积 vs 并行度 | REQ-003(继承) | PASS | 单引擎顺序写入 |
| 5 | AREA-03 | 可靠性 vs 面积 | REQ-009(继承) | N/A | 本子模块无 ECC 需求 |
| 6 | POWER-01 | 功耗 vs 工艺/频率 | REQ-001/005(继承) | PASS | ICAP 引擎功耗 < 15mW |
| 7 | POWER-02 | 低功耗 vs DFT | REQ-007/008(继承) | PASS | 标准方案 |
| 8 | IO-01 | 接口位宽 vs 数据粒度 | REQ-002(继承) | PASS | ICAP 32-bit = 比特流字粒度 |
| 9 | IO-02 | 多模块共享资源 | REQ-012(继承) | N/A | 本子模块不直接访问 SRAM |
| 10 | IO-03 | 安全隔离 | REQ-018(继承) | N/A | 本子模块不涉及隔离 |
| 11 | PVT-01 | PVT vs 功耗 | REQ-013(继承) | PASS | ICAP 引擎功耗裕量充足 |
| 12 | MEM-01 | 存储 vs 面积 | REQ-012(继承) | PASS | 仅异步 FIFO，无大容量存储 |
| 13 | CDC-01 | CDC vs 时序裕量 | REQ-004/006/011(继承) | PASS | 异步 FIFO 延迟 2-3 cycles，相对 200ms 可忽略 |
| 14 | PERF-01 | 延迟 vs 吞吐 | REQ-004(继承) | PASS | ICAP 顺序写入，无矛盾 |
| 15 | DYN-01 | 功能重叠 | LREQ vs 继承 REQ | PASS | LREQ-001(状态机)与 REQ-036(超时)功能不同 |
| 16 | DYN-02 | PPA 交叉矛盾 | LREQ vs 继承 REQ | PASS | 本地 REQ 无额外 PPA 约束 |
| 17 | DYN-03 | 接口冲突 | LREQ vs REQ-002 | PASS | 本地 REQ 均使用 ICAP 接口 |

---

### 矛盾检测结果汇总

| 类别 | 数量 |
|------|------|
| PASS | 14 |
| WARN | 0 |
| N/A | 3 |
| **矛盾** | **0 个** |
| **警告** | **0 个** |

---

## [PHASE-END] stageC phase1

---

## [PHASE-START] stageC phase2

### 需求确认汇总表

> schema_version: 1.0
> module_name: icap_write_engine
> parent_module: fpga_partial_reconfig
> date: 2026-06-04
> total_reqs: 16（8 继承 + 8 本地）
> priority_distribution: Must=4, Should=12

| # | REQ | 约束项 | 确认值 | 优先级 | 状态 | 来源 |
|---|-----|--------|--------|--------|------|------|
| 1 | REQ-002 | ICAP 接口 | ICAP 32-bit（Xilinx 7-series 兼容） | Must | confirmed | 继承自父模块 |
| 2 | REQ-004 | 延迟与吞吐 | 整体重配延迟 < 200ms | Should | confirmed | 继承自父模块 |
| 3 | REQ-006 | 时钟与复位 | ICAP 独立时钟域（100~200MHz） | Must | confirmed | 继承自父模块 |
| 4 | REQ-011 | CDC 策略 | 主域→ICAP：异步 FIFO（深度≥4） | Should | confirmed | 继承自父模块 |
| 5 | REQ-014 | 接口时序约束 | ICAP: setup ≤ 2ns, output delay ≤ 3ns | Should | confirmed | 继承自父模块 |
| 6 | REQ-028 | 时钟树约束 | SSC 1% down-spread / OCV 5% | Should | confirmed | 继承自父模块 |
| 7 | REQ-031 | 流水线（写入段） | 三阶段重叠，写入段与校验段并行 | Should | confirmed | 继承自父模块 |
| 8 | REQ-036 | 超时阈值可配 | ICAP 超时阈值 APB 可配 | Should | confirmed | 继承自父模块 |
| 9 | LREQ-001 | ICAP 写入状态机 | 完整 FSM（空闲/接收/写入/完成/错误） | Must | confirmed | 头脑风暴新增 |
| 10 | LREQ-002 | 写入顺序保证 | 比特流数据按顺序写入 ICAP，无乱序 | Must | confirmed | 头脑风暴新增 |
| 11 | LREQ-003 | ICAP 复位序列 | 上电后初始化序列（同步字/命令头） | Should | confirmed | 头脑风暴新增 |
| 12 | LREQ-004 | 写入暂停/恢复 | 支持写入过程中暂停和恢复 | Should | confirmed | 头脑风暴新增 |
| 13 | LREQ-005 | 写入预取 | 从异步 FIFO 预取下一数据，减少 ICAP 等待 | Should | confirmed | 头脑风暴新增 |
| 14 | LREQ-006 | ICAP 时序可配 | APB 配置 ICAP 时钟分频系数 | Should | confirmed | 用户确认 |
| 15 | LREQ-007 | ICAP 状态观测 | APB 可观测 ICAP 当前状态 | Should | confirmed | 头脑风暴新增 |
| 16 | LREQ-008 | ICAP 错误日志 | 记录最近 N 次 ICAP 错误详情 | Should | confirmed | 头脑风暴新增 |

### 优先级统计

| 优先级 | 数量 | REQ 编号 |
|--------|------|----------|
| Must | 4 | REQ-002, REQ-006, LREQ-001, LREQ-002 |
| Should | 12 | REQ-004, REQ-011, REQ-014, REQ-028, REQ-031, REQ-036, LREQ-003~008 |

### 冻结规则

**冻结条件**：用户确认本汇总表后自动冻结
**冻结范围**：16 项 REQ（8 继承 + 8 本地）

## [PHASE-END] stageC phase2
