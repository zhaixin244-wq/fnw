# bitstream_rx_engine PR 沟通记录

> 版本：v1.0
> 日期：2026-06-04
> 阶段：stageB phase2（执行中）
> 当前进度：stageB phase2（执行中）
> 已完成：（无）
> 父模块：fpga_partial_reconfig
> 子模块 ID：1（L1）

---

## 父模块上下文摘要

**功能**：FPGA 部分重配置控制器，通过 PCIe DMA 或本地 Flash 接收比特流，在运行时对 FPGA 部分区域进行动态重配置，支持多租户隔离和比特流完整性校验。

**关键约束**：16nm / 500MHz / 逻辑 < 200kGates / 动态功耗 < 180mW

**接口**：上游=Host CPU（PCIe DMA），下游=FPGA 可配置逻辑块（ICAP），控制=APB

**兄弟模块**：
- bitstream_val_mgr（下游）：CRC-32 校验 + LZ4 解压
- icap_write_engine（下游）：ICAP 32-bit 写入
- isolation_mgr（并行）：多租户隔离
- reg_interface（并行）：APB 寄存器接口

---

## 继承 REQ（同步自父模块）

| 全局 REQ | 约束项 | 确认值 | 优先级 | 适用性 |
|----------|--------|--------|--------|--------|
| REQ-002 | 接口协议 | PCIe DMA + Flash（预留） | Must | 适用——本模块直接对接 PCIe DMA |
| REQ-003 | 数据流特征 | 比特流 8~32MB / DMA 突发 256B | Should | 适用——本模块接收数据流 |
| REQ-012 | 存储器选型 | 外部 DDR + 片上 256KB SRAM | Should | 适用——本模块写入 DDR/SRAM 缓存 |
| REQ-015 | DMA 握手接口 | PCIe DMA 标准，256B 突发，1 通道 | Should | 适用——本模块实现 DMA 从接口 |
| REQ-037 | 比特流加载进度查询 | Host CPU 可查询加载进度百分比 | Should | 适用——本模块跟踪接收进度 |
| REQ-038 | 比特流分段加载 | 支持大比特流分段传输 | Should | 适用——本模块实现分段接收 |

---

## [PHASE-START] stageB phase2

### 头脑风暴 Feature Discovery

**触发条件**：子模块从 stageB phase2 开始
**执行方式**：按 5 个维度探索（功能扩展/性能优化/兼容性/可测试性/可维护性）

---

#### 维度 1：功能扩展

**Q1**：bitstream_rx_engine 在接收比特流方面，是否有父模块 REQ 未覆盖的额外功能需求？

**A1**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| DMA 地址表管理 | 支持多个 DMA 源地址段，便于非连续内存传输 | Should | 扩展 REQ-015 |
| 比特流头解析 | 解析比特流头部信息（版本/大小/CRC），传递给 val_mgr | Must | 补充 REQ-003/032 |
| 传输中断恢复 | DMA 传输中断后从断点续传，而非重新开始 | Should | 补充 REQ-038 |
| 流量控制反压 | 当下游 SRAM 缓存满时，向 PCIe DMA 发送反压信号 | Should | 补充 REQ-015 |

---

#### 维度 2：性能优化

**Q2**：在比特流接收性能方面，是否有额外优化需求？

**A2**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| DMA 零拷贝传输 | DMA 直接写入 SRAM/DDR，减少中间缓冲 | Should | 优化 REQ-012/015 |
| 多通道 DMA | 支持 2~4 个 DMA 通道并行接收 | Could | 扩展 REQ-015（当前 1 通道） |
| 预取机制 | 提前发起下一段 DMA 请求，隐藏启动延迟 | Should | 优化 REQ-038 |

---

#### 维度 3：兼容性

**Q3**：是否需要兼容不同版本的 PCIe DMA 或 Flash 接口？

**A3**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| PCIe Gen2/Gen3 自适应 | 自动检测 PCIe 速率并调整 DMA 参数 | Could | 扩展 REQ-002 |
| Flash 多型号适配 | 支持不同厂商 SPI Flash 的读取时序差异 | Could | 扩展 REQ-002（Flash 预留） |

---

#### 维度 4：可测试性

**Q4**：在接收引擎的验证方面，有哪些额外需求？

**A4**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| DMA 数据回环测试 | 将接收到的数据回环发送，验证 DMA 通路完整性 | Should | 验证 REQ-015 |
| 接收 FIFO 水位观测 | 通过 APB 寄存器观测 DMA 接收 FIFO 当前水位 | Should | 调试支持 |
| DMA 传输日志 | 记录最近 N 次 DMA 传输的源地址/长度/状态 | Should | 调试支持 |

---

#### 维度 5：可维护性

**Q5**：在接收引擎的运维和调试方面，有哪些需求？

**A5**（基于功能分析）：

| 潜在 Feature | 说明 | 建议优先级 | 与父模块 REQ 关系 |
|--------------|------|-----------|-------------------|
| DMA 超时可配 | DMA 传输超时阈值通过 APB 动态配置 | Should | 扩展 REQ-036 |
| 接收统计寄存器 | 已接收字节数/包数/错误数统计 | Should | 扩展 REQ-035 |
| 动态暂停/恢复 | Host CPU 可暂停和恢复 DMA 接收 | Should | 运维灵活性 |

---

### 头脑风暴追加 REQ 汇总

基于 5 个维度探索，以下 Feature 建议追加为子模块本地 REQ：

| 本地 REQ | Feature | 维度 | 优先级 | 确认值 |
|----------|---------|------|--------|--------|
| LREQ-001 | 比特流头解析 | 功能扩展 | Must | 解析比特流头部（版本/大小/CRC），传递给 bitstream_val_mgr |
| LREQ-002 | 流量控制反压 | 功能扩展 | Should | SRAM 缓存满时向 PCIe DMA 发送反压信号 |
| LREQ-003 | 传输中断恢复 | 功能扩展 | Should | DMA 传输中断后从断点续传 |
| LREQ-004 | DMA 零拷贝传输 | 性能优化 | Should | DMA 直接写入 SRAM/DDR，减少中间缓冲 |
| LREQ-005 | 接收 FIFO 水位观测 | 可测试性 | Should | APB 可观测 DMA 接收 FIFO 水位 |
| LREQ-006 | DMA 传输日志 | 可测试性 | Should | 记录最近 N 次 DMA 传输详情 |
| LREQ-007 | 接收统计寄存器 | 可维护性 | Should | 已接收字节数/包数/错误数统计 |
| LREQ-008 | 动态暂停/恢复 | 可维护性 | Should | Host CPU 可暂停和恢复 DMA 接收 |

### 矛盾检查

| 检查对 | 结果 | 说明 |
|--------|------|------|
| LREQ-002（反压）vs REQ-038（分段加载） | 无矛盾 | 反压是流控机制，分段是传输策略，互补 |
| LREQ-004（零拷贝）vs REQ-012（DDR+SRAM） | 无矛盾 | 零拷贝优化存储访问路径 |
| LREQ-003（断点续传）vs REQ-015（DMA 256B 突发） | 无矛盾 | 断点续传在突发粒度之上 |

**结论**：追加 8 个本地 REQ，无矛盾。

### 用户确认

用户确认 8 个本地 REQ 均可接受。补充建议：LREQ-003 断点续传需明确续传粒度，建议在微架构阶段定义。

## [PHASE-END] stageB phase2

---

## [PHASE-START] stageC phase1

### 矛盾检测执行

**检测范围**：
- 基础检测：17 条（针对本子模块继承 REQ + 本地 REQ 适用项）
- 动态检测：3 条（DYN-01/02/03，针对本地 REQ vs 继承 REQ）
- 条件检测：不适用（REQ-022~025 均为 skipped）

**检测结果**：

| # | 规则 ID | 规则名称 | 涉及 REQ | 结果 | 说明 |
|---|---------|----------|----------|------|------|
| 1 | FREQ-01 | 频率 vs 工艺 | REQ-001(继承) | PASS | 16nm/500MHz，DMA 接口逻辑远低于 Fmax |
| 2 | FREQ-02 | 延迟 vs 频率 | REQ-004(继承) | PASS | DMA 接收延迟非 cycle 级约束 |
| 3 | AREA-01 | 面积 vs 功能复杂度 | REQ-005(继承) | PASS | 700 行预估，逻辑面积 ~30kGates，在预算内 |
| 4 | AREA-02 | 面积 vs 并行度 | REQ-003(继承) | PASS | 单通道 DMA，无并行需求 |
| 5 | AREA-03 | 可靠性 vs 面积 | REQ-009(继承) | N/A | 本子模块无 ECC/TMR 需求 |
| 6 | POWER-01 | 功耗 vs 工艺/频率 | REQ-001/005(继承) | PASS | DMA 接口逻辑功耗 < 20mW |
| 7 | POWER-02 | 低功耗 vs DFT | REQ-007/008(继承) | PASS | 全局 Clock Gating + 标准扫描链 |
| 8 | IO-01 | 接口位宽 vs 数据粒度 | REQ-002/003(继承) | PASS | PCIe DMA 数据宽度与比特流字粒度匹配 |
| 9 | IO-02 | 多模块共享资源竞争 | REQ-012(继承) | **WARN** | DMA 写入 SRAM 与 val_mgr 读取 SRAM 共享，需仲裁 |
| 10 | IO-03 | 安全隔离 vs 地址碎片化 | REQ-018(继承) | N/A | 本子模块不涉及隔离 |
| 11 | PVT-01 | PVT vs 功耗预算 | REQ-013(继承) | PASS | DMA 接口逻辑功耗裕量充足 |
| 12 | MEM-01 | 存储容量 vs 面积 | REQ-012(继承) | PASS | DDR 外部，SRAM 256KB 面积单独计算 |
| 13 | CDC-01 | CDC vs 时序裕量 | REQ-011(继承) | PASS | PCIe→主域异步 FIFO，延迟可忽略 |
| 14 | DYN-01 | 功能重叠 | LREQ vs 继承 REQ | PASS | LREQ-001(头解析)与 REQ-037(进度查询)功能不同 |
| 15 | DYN-02 | PPA 交叉矛盾 | LREQ vs 继承 REQ | PASS | 本地 REQ 无额外 PPA 约束 |
| 16 | DYN-03 | 接口冲突 | LREQ vs REQ-002 | PASS | 本地 REQ 均使用已有接口（PCIe DMA/APB） |

---

### 矛盾检测结果汇总

| 类别 | 数量 |
|------|------|
| PASS | 14 |
| WARN | 1（IO-02） |
| N/A | 2 |
| **矛盾** | **0 个** |
| **警告** | **1 个** |

---

### 警告详情

#### WARN-01: IO-02 共享 SRAM 竞争

| 项目 | 内容 |
|------|------|
| 涉及 REQ | REQ-012（外部 DDR + 片上 256KB SRAM） |
| 警告描述 | DMA 写入端口与 bitstream_val_mgr 读取端口共享 256KB SRAM，峰值带宽可能超过 SRAM 端口带宽 |
| 建议 | 1. SRAM 采用 1R1W 双端口设计 2. DMA 写入与 val_mgr 读取可同时进行 3. 微架构阶段需详细设计仲裁策略 |

---

### 用户确认（警告处理）

用户确认 1R1W 双端口 SRAM 设计可接受。

## [PHASE-END] stageC phase1

---

## [PHASE-START] stageC phase2

### 需求确认汇总表

> schema_version: 1.0
> module_name: bitstream_rx_engine
> parent_module: fpga_partial_reconfig
> date: 2026-06-04
> total_reqs: 14（6 继承 + 8 本地）
> priority_distribution: Must=2, Should=12

| # | REQ | 约束项 | 确认值 | 优先级 | 状态 | 来源 |
|---|-----|--------|--------|--------|------|------|
| 1 | REQ-002 | PCIe DMA 接口 | PCIe DMA 标准 + Flash（预留） | Must | confirmed | 继承自父模块 |
| 2 | REQ-003 | 数据流特征 | 比特流 8~32MB / DMA 突发 256B | Should | confirmed | 继承自父模块 |
| 3 | REQ-012 | 存储器选型 | 外部 DDR + 片上 256KB SRAM（1R1W 双端口） | Should | confirmed | 继承+用户确认 |
| 4 | REQ-015 | DMA 握手接口 | PCIe DMA 标准，256B 突发，递增地址，1 通道 | Should | confirmed | 继承自父模块 |
| 5 | REQ-037 | 加载进度查询 | Host CPU 可查询当前加载进度百分比 | Should | confirmed | 继承自父模块 |
| 6 | REQ-038 | 分段加载 | 支持大比特流分段传输，降低片上缓存需求 | Should | confirmed | 继承自父模块 |
| 7 | LREQ-001 | 比特流头解析 | 解析比特流头部（版本/大小/CRC），传递给 val_mgr | Must | confirmed | 头脑风暴新增 |
| 8 | LREQ-002 | 流量控制反压 | SRAM 缓存满时向 PCIe DMA 发送反压信号 | Should | confirmed | 头脑风暴新增 |
| 9 | LREQ-003 | 传输中断恢复 | DMA 传输中断后从断点续传（续传粒度微架构阶段定义） | Should | confirmed | 头脑风暴新增 |
| 10 | LREQ-004 | DMA 零拷贝传输 | DMA 直接写入 SRAM/DDR，减少中间缓冲 | Should | confirmed | 头脑风暴新增 |
| 11 | LREQ-005 | 接收 FIFO 水位观测 | APB 可观测 DMA 接收 FIFO 水位 | Should | confirmed | 头脑风暴新增 |
| 12 | LREQ-006 | DMA 传输日志 | 记录最近 N 次 DMA 传输的源地址/长度/状态 | Should | confirmed | 头脑风暴新增 |
| 13 | LREQ-007 | 接收统计寄存器 | 已接收字节数/包数/错误数统计 | Should | confirmed | 头脑风暴新增 |
| 14 | LREQ-008 | 动态暂停/恢复 | Host CPU 可暂停和恢复 DMA 接收 | Should | confirmed | 头脑风暴新增 |

### 优先级统计

| 优先级 | 数量 | REQ 编号 |
|--------|------|----------|
| Must | 2 | REQ-002, LREQ-001 |
| Should | 12 | REQ-003, REQ-012, REQ-015, REQ-037, REQ-038, LREQ-002~008 |

### 冻结规则

**冻结条件**：用户确认本汇总表后自动冻结
**冻结范围**：14 项 REQ（6 继承 + 8 本地）

## [PHASE-END] stageC phase2
