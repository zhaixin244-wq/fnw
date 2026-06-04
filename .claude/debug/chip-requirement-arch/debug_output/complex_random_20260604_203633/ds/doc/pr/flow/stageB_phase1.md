# GPU Shader Core - stageB phase1 沟通记录

> 模块：GPU Shader Core
> 阶段：stageB phase1
> 日期：2026-06-04

---

## [STAGE-START] stageB phase1 约束检查

### 轮 15 - REQ-008 DFT 确认（续）

**苏启辰**：
DFT 方案确认：128 条扫描链，压缩比 20x，3 个 MBIST 控制器。面积含 DFT 后 2.91mm²，裕量 3%。

LBIST 建议：GPU Shader Core 逻辑规模大（~420kGates），建议需要 LBIST，覆盖率目标 ≥90%。故障覆盖率综合目标 ≥95%。

面积 2.91mm² 含 DFT 作为硬约束，stageD 严格控制。

**用户**：
DFT 方案基本接受。扫描链 128 条，压缩比 20x。MBIST 3 个控制器。但面积裕量 3% 太紧了，你提到含 DFT 后 2.91mm²，这个数字在 stageD 要严格控制。另外 LBIST 需要吗？故障覆盖率目标多少？这些你没提。先继续下一项，DFT 细节留到 stageD。

---

### 轮 16 - REQ-009/012 存储器与可靠性

**苏启辰**：
先回答补充问题：

**LBIST**：对于 GPU Shader Core 这种复杂设计，建议需要 LBIST。理由：逻辑规模大（~420kGates），ATPG 向量数量多，测试时间长。LBIST 可在片内自主生成测试向量，减少 ATE 依赖。建议 LBIST 覆盖率目标 90%+，与扫描链互补。

**故障覆盖率目标**：
- 扫描链 ATPG：≥ 95% stuck-at fault coverage
- MBIST：100% SRAM 单元覆盖
- LBIST：≥ 90%（可选）
- 综合目标：≥ 95% 故障覆盖率

**面积控制**：2.91mm² 含 DFT 作为硬约束，stageD 严格执行。

---

现在继续 REQ-012（存储器选型），为 REQ-009 铺垫。

GPU Shader Core 需要多种存储器：

| 存储器 | 用途 | 类型 | 深度/容量 | 说明 |
|--------|------|------|-----------|------|
| Register File | Operand Collector | RegFile | 32 bank × 1024 × 32b | 已确认配置 |
| Shared Memory | 线程块共享数据 | SRAM | 64KB~128KB | 可配置 |
| L1 Data Cache | 纹理/加载缓存 | SRAM | 32KB~64KB | 组相联 |
| Instruction Cache | 指令缓存 | SRAM | 16KB~32KB | |
| Constant Memory | 常量缓存 | SRAM | 8KB~16KB | 只读 |
| L2 Cache | 全局缓存（可选） | SRAM | 256KB~512KB | 跨 SM 共享 |

**ECC/Parity 需求**：

| 存储器 | 保护类型 | 理由 |
|--------|----------|------|
| Register File | Parity | 面积敏感，检错即可 |
| Shared Memory | ECC (SECDED) | 关键数据，需纠错 |
| L1/L2 Cache | ECC (SECDED) | 数据完整性 |
| Instruction Cache | Parity | 指令错误可重取 |

**问题**：
1. Shared Memory 容量偏好？64KB 还是 128KB？
2. L2 Cache 是否需要？容量偏好？
3. 以上 ECC/Parity 方案是否接受？

**用户**：
待确认...

---

## 已确认约束表

| # | 约束项 | 确认值 | 确认阶段 | 备注 |
|---|--------|--------|----------|------|
| 1 | 工艺节点 | 5nm | stageB phase1 | - |
| 2 | 工作频率 | 2.5GHz | stageB phase1 | - |
| 3 | 接口协议 | AXI4 512-bit | stageB phase1 | - |
| 4 | 数据流特征 | SIMT 128-wide SIMD | stageB phase1 | 4x32 sub-partition |
| 5 | 延迟 | ≤10 cycles 管线深度 | stageB phase1 | - |
| 6 | 吞吐 | 1024 FP16 ops/cycle | stageB phase1 | Tensor Core |
| 7 | 面积预算 | 3mm² | stageB phase1 | 含 DFT 2.91mm² |
| 8 | 功耗预算 | 500mW | stageB phase1 | - |
| 9 | 时钟域 | 3个 | stageB phase1 | core/uncore/axi |
| 10 | 复位策略 | 异步复位同步释放 | stageB phase1 | 低有效 |
| 11 | 功耗域 | 4个独立域 | stageB phase1 | - |
| 12 | DFT 扫描链 | 128条，压缩比20x | stageB phase1 | - |
| 13 | MBIST | 3个控制器 | stageB phase1 | - |
| 14 | 故障覆盖率 | ≥95% | stageB phase1 | LBIST ≥90% |

---

### 轮 17 - REQ-012/009 存储器与可靠性确认

**苏启辰**：
存储器与可靠性方案确认：

| 存储器 | 类型 | 容量 | 保护类型 | 说明 |
|--------|------|------|----------|------|
| Register File | RegFile | 32 bank × 1024 × 32b | Parity | Operand Collector |
| Shared Memory | SRAM | 128KB | ECC (SECDED) | 线程块共享 |
| L1 Data Cache | SRAM | 64KB | ECC (SECDED) | 组相联 |
| Instruction Cache | SRAM | 32KB | Parity | 指令可重取 |
| Constant Memory | SRAM | 16KB | Parity | 只读 |

无 L2 Cache（已确认）。

**用户**：
存储器方案接受。Shared Memory 128KB，RF 用 Parity，ECC 方案按你说的来。无 L2 Cache。继续下一项。

---

### 轮 18 - REQ-011 CDC 策略确认

**苏启辰**：
CDC 方案确认：

**方案 A（推荐）**：所有 CDC 集中在专用 CDC 模块
- 优势：便于 lint 和形式验证，集中管理，易维护
- 劣势：CDC 模块面积略大

**方案 B**：各子模块内部分散处理 CDC
- 优势：模块独立性强
- 劣势：lint 和形式验证分散，维护困难

512-bit AXI 数据通路必须用异步 FIFO + Gray 码指针（位宽大，双触发器不适用）。

**用户**：
CDC 方案接受。选方案 A，所有 CDC 集中在专用 CDC 模块，便于 lint 和形式验证。512-bit AXI 数据通路用异步 FIFO + Gray 码指针，这个是必须的。继续下一项。

---

## 已确认约束表

| # | 约束项 | 确认值 | 确认阶段 | 备注 |
|---|--------|--------|----------|------|
| 1 | 工艺节点 | 5nm | stageB phase1 | - |
| 2 | 工作频率 | 2.5GHz | stageB phase1 | - |
| 3 | 接口协议 | AXI4 512-bit | stageB phase1 | - |
| 4 | 数据流特征 | SIMT 128-wide SIMD | stageB phase1 | 4x32 sub-partition |
| 5 | 延迟 | ≤10 cycles 管线深度 | stageB phase1 | - |
| 6 | 吞吐 | 1024 FP16 ops/cycle | stageB phase1 | Tensor Core |
| 7 | 面积预算 | 3mm² | stageB phase1 | 含 DFT 2.91mm² |
| 8 | 功耗预算 | 500mW | stageB phase1 | - |
| 9 | 时钟域 | 3个 | stageB phase1 | core/uncore/axi |
| 10 | 复位策略 | 异步复位同步释放 | stageB phase1 | 低有效 |
| 11 | 功耗域 | 4个独立域 | stageB phase1 | - |
| 12 | DFT 扫描链 | 128条，压缩比20x | stageB phase1 | - |
| 13 | MBIST | 3个控制器 | stageB phase1 | - |
| 14 | 故障覆盖率 | ≥95% | stageB phase1 | LBIST ≥90% |
| 15 | Register File | Parity | stageB phase1 | 32 bank × 1024 × 32b |
| 16 | Shared Memory | 128KB, ECC (SECDED) | stageB phase1 | 线程块共享 |
| 17 | L1 Data Cache | 64KB, ECC (SECDED) | stageB phase1 | 组相联 |
| 18 | Instruction Cache | 64KB, Parity | stageB phase1 | L1 I-Cache |
| 19 | Constant Cache | 32KB, Parity | stageB phase1 | 只读 |
| 20 | L2 Cache | 无 | stageB phase1 | - |
| 21 | CDC 方案 | 集中式 CDC 模块 | stageB phase1 | 512-bit AXI 用异步 FIFO |
| 22 | CDC 同步策略 | 异步 FIFO + Gray 码 | stageB phase1 | 大位宽必须 |

---

## [STEP-PAUSE] REQ-011 已确认，继续 REQ-013

---

### 轮 19 - REQ-013 PVT 条件确认

**苏启辰**：
PVT 条件确认：
- 温度范围：-10°C ~ 100°C（结温）
- 电压范围：0.75V ~ 0.85V
- Corner：TT + SS + FF（三个 corner 必须验证）
- AOCV derate 范围：0.95 ~ 1.05

**用户**：
PVT 条件接受。继续下一项。

---

### 轮 20 - REQ-014 接口时序确认

**苏启辰**：
接口时序约束确认：
- 输入 setup time：≤ 0.5ns（相对 clk 上升沿）
- 输入 hold time：≤ 0.5ns
- 输出 delay：≤ 0.5ns（clk 到输出有效）
- 接口时序裕量目标：≥ 0.1ns

**用户**：
接口时序接受。继续下一项。

---

### 轮 21 - REQ-015 DMA 握手

**苏启辰**：
REQ-015 DMA 握手：GPU Shader Core 作为 IP 级模块，不直接对接 DMA 控制器。DMA 由 SoC 顶层集成时处理。标记为不适用。

**用户**：
确认不适用。继续。

---

### 轮 22 - REQ-016 中断方案确认

**苏启辰**：
中断方案确认：
- 中断类型：MSI-X + 轮询混合
- MSI-X：用于关键事件（错误、完成通知）
- 轮询：用于高频状态查询（性能计数器、渲染状态）
- 中断向量数：≥ 16 个
- 中断延迟目标：≤ 1μs（MSI-X）

**用户**：
中断方案接受。继续下一项。

---

### 轮 23 - REQ-017 调试接口确认

**苏启辰**：
调试接口确认：
- JTAG 接口：标准 IEEE 1149.1
- 性能计数器：16 个可配置计数器
- Trace 接口：可选，用于指令流追踪
- Debug 寄存器：通过 APB 访问

**用户**：
调试接口接受。继续下一项。

---

### 轮 24 - REQ-018 安全隔离确认

**苏启辰**：
安全隔离方案确认：
- 隔离级别：硬件级 VF 级（SR-IOV）
- 每个 VF 独立的寄存器空间、中断、DMA 通道
- PF 管理 VF 生命周期
- 内存隔离：IOMMU + 页表隔离
- 安全等级：支持多租户隔离

**用户**：
安全隔离方案接受。继续下一项。

---

### 轮 25 - REQ-019 软件接口确认

**苏启辰**：
软件接口确认：
- 驱动模型：PF/VF 驱动分离
- 配置接口：APB 桥接（寄存器访问）
- 数据接口：Ring Buffer（命令队列）
- Ring Buffer 深度：≥ 256 entries
- 命令格式：128-bit 固定长度

**用户**：
软件接口接受。继续下一项。

---

### 轮 26 - REQ-020 系统级约束确认

**苏启辰**：
系统级约束确认：
- QoS：支持优先级仲裁（4 级优先级）
- 地址空间：48-bit VA / 44-bit PA
- Cache 一致性：硬件 Snoop（MESI 协议）
- 系统接口：AXI4 512-bit（已确认）

**用户**：
系统级约束接受。继续下一项。

---

### 轮 27 - REQ-021 功耗状态机确认

**苏启辰**：
功耗状态机确认：
- Core 域：Active + Clock Gating（2 状态）
- 其他域：Active + Clock Gating + Power Gating（3 状态）
- 状态切换延迟：CG ≤ 1 cycle，PG ≤ 100 cycles
- 唤醒源：软件触发 + 事件触发

**用户**：
功耗状态机接受。继续下一项。

---

### 轮 28 - REQ-022 PLL 确认

**苏启辰**：
REQ-022 PLL：PLL 由顶层 CMU（Clock Management Unit）提供，Shader Core 不包含 PLL。时钟输入由外部提供。

**用户**：
确认 PLL 由顶层提供。继续。

---

### 轮 29 - REQ-023 SerDes/PHY

**苏启辰**：
REQ-023 SerDes/PHY：GPU Shader Core 作为 IP 级模块，不包含 SerDes/PHY。高速接口由 SoC 顶层集成时处理。标记为不适用。

**用户**：
确认不适用。继续。

---

### 轮 30 - REQ-024 形式验证确认

**苏启辰**：
形式验证需求确认：
- CDC 形式验证：必须（集中式 CDC 模块便于验证）
- FSM 形式验证：必须（状态机死锁/活锁检测）
- 等价性检查：RTL vs Gate-level
- 属性检查：关键断言

**用户**：
形式验证需求接受。继续下一项。

---

### 轮 31 - REQ-025 验证方法学确认

**苏启辰**：
验证方法学确认：
- 验证方法学：UVM（Universal Verification Methodology）
- 验证层次：4 层（Block → Subsystem → Chip → System）
- 回归测试：≥ 1000 用例
- 覆盖率目标：代码覆盖率 ≥ 95%，功能覆盖率 ≥ 90%
- 随机验证：约束随机 + 定向测试

**用户**：
验证方法学接受。继续下一项。

---

### 轮 32 - REQ-026/027 封装与EMC/ESD

**苏启辰**：
REQ-026 封装：GPU Shader Core 作为 IP 级模块，封装由 SoC 顶层决定。标记为不适用。

REQ-027 EMC/ESD：IP 级模块不直接处理 EMC/ESD，由 SoC 顶层集成时考虑。标记为不适用。

**用户**：
确认都不适用。继续最后一项。

---

### 轮 33 - REQ-028 时钟树约束确认

**苏启辰**：
时钟树约束确认：
- AOCV（Advanced On-Chip Variation）：必须考虑
- SOCV（Statistical On-Chip Variation）：必须考虑
- 时钟树综合算法：CCOpt（Clock Concurrent Optimization）
- Skew 目标：≤ 50ps
- Jitter 目标：≤ 30ps
- 时钟树级数：≤ 10 级

**用户**：
时钟树约束接受。AOCV derate 范围合理，skew 目标没问题。CCOpt 算法可以。28 项约束全部确认完成，进入下一个阶段吧。

---

## 最终已确认约束表（28项全部完成）

| # | 约束项 | 确认值 | 确认阶段 | 备注 |
|---|--------|--------|----------|------|
| 1 | 工艺节点 | 5nm | stageB phase1 | - |
| 2 | 工作频率 | 2.5GHz | stageB phase1 | Core域 |
| 3 | 接口协议 | 512-bit AXI4 | stageB phase1 | - |
| 4 | 数据流 | 128-bit指令 + 512-bit数据 | stageB phase1 | SIMT执行模型 |
| 5 | 计算延迟 | ALU 20c, TC 50c | stageB phase1 | 计算延迟优先 |
| 6 | 面积约束 | 3mm² | stageB phase1 | 含DFT 2.91mm² |
| 7 | 功耗约束 | 500mW | stageB phase1 | - |
| 8 | 时钟域 | 3个 | stageB phase1 | core/uncore/axi |
| 9 | 复位策略 | 异步复位同步释放 | stageB phase1 | 低有效 |
| 10 | 功耗域 | 4个独立域 | stageB phase1 | - |
| 11 | 扫描链 | 128条，压缩比20x | stageB phase1 | - |
| 12 | MBIST | 3个控制器 | stageB phase1 | - |
| 13 | 故障覆盖率 | ≥95% | stageB phase1 | LBIST ≥90% |
| 14 | Register File | Parity | stageB phase1 | 32 bank × 1024 × 32b |
| 15 | Shared Memory | 128KB, ECC (SECDED) | stageB phase1 | 线程块共享 |
| 16 | L1 Data Cache | 64KB, ECC (SECDED) | stageB phase1 | 组相联 |
| 17 | Instruction Cache | 64KB, Parity | stageB phase1 | L1 I-Cache |
| 18 | Constant Cache | 32KB, Parity | stageB phase1 | 只读 |
| 19 | L2 Cache | 无 | stageB phase1 | - |
| 20 | CDC方案 | 集中式CDC模块 | stageB phase1 | 512-bit AXI用异步FIFO |
| 21 | PVT条件 | -10~100°C, 0.75~0.85V, TT+SS+FF | stageB phase1 | - |
| 22 | 接口时序 | setup/hold ≤0.5ns, output delay ≤0.5ns | stageB phase1 | - |
| 23 | DMA握手 | 不适用 | stageB phase1 | IP级 |
| 24 | 中断 | MSI-X + 轮询混合 | stageB phase1 | ≥16向量 |
| 25 | 调试 | JTAG + 16个性能计数器 | stageB phase1 | - |
| 26 | 安全隔离 | 硬件级VF级 + SR-IOV | stageB phase1 | - |
| 27 | 软件接口 | PF/VF驱动, APB桥接, Ring Buffer | stageB phase1 | 256 entries |
| 28 | 系统级 | QoS 4级, 48-bit VA/44-bit PA, 硬件Snoop | stageB phase1 | MESI协议 |
| 29 | 功耗状态 | Core(Active+CG), 其他(Active+CG+PG) | stageB phase1 | - |
| 30 | PLL | 由顶层CMU提供 | stageB phase1 | - |
| 31 | SerDes/PHY | 不适用 | stageB phase1 | IP级 |
| 32 | 形式验证 | CDC+FSM必须 | stageB phase1 | - |
| 33 | 验证方法学 | UVM 4层，千级回归 | stageB phase1 | 覆盖率≥95% |
| 34 | 封装 | 不适用 | stageB phase1 | IP级 |
| 35 | EMC/ESD | 不适用 | stageB phase1 | IP级 |
| 36 | 时钟树 | AOCV+SOCV, CCOpt, skew≤50ps | stageB phase1 | - |

---

## 硬约束提取

| 约束类型 | 数值 | 来源 |
|----------|------|------|
| 面积 | 3mm²（含DFT 2.91mm²） | REQ-005 |
| 功耗 | 500mW | REQ-005 |
| 频率 | 2.5GHz | REQ-001 |
| 接口带宽 | 512-bit @ 2.5GHz = 160GB/s | REQ-002 |
| 计算延迟 | ALU ≤20c, TC ≤50c | REQ-004 |
| 时序 | setup/hold ≤0.5ns | REQ-014 |
| 时钟skew | ≤50ps | REQ-028 |

---

## 阶段结论

stageB phase1 28项约束检查全部完成。确认26项，跳过4项（DMA握手、SerDes/PHY、封装、EMC/ESD 均为不适用）。硬约束已提取，可进入stageB phase2头脑风暴。

## [STAGE-END] stageB phase1 已完成
