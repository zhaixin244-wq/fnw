# GPU Shader Core - stageC phase2 需求汇总表

> 模块：GPU Shader Core
> 阶段：stageC phase2（需求汇总表生成）
> 日期：2026-06-04

---

## [STAGE-START] stageC phase2 需求汇总

---

## 面积压缩深度分析

### 当前面积重算（用户选择的调和方案后）

| 调整项 | 面积变化 | 说明 |
|--------|----------|------|
| 去掉 GS 硬件 | -0.05mm² | GS 用微码模拟 |
| RF bank 32→16 | -0.15mm² | Register File 带宽降低 |
| SM 128→64KB | -0.10mm² | Shared Memory 减半 |
| I-Cache 64→32KB | -0.08mm² | 指令缓存减半 |
| **小计** | **-0.38mm²** | |
| **调整后总面积** | **3.52mm²** | 仍超出 3mm² 约束 0.52mm² |

### 面积分布分析（3.52mm² 拆解）

基于 5nm 工艺 SRAM 密度约 4-6 Mbit/mm²、RF 密度约 2-3 Mbit/mm²、逻辑密度约 10-15 MGates/mm²：

| 组件 | 预估面积 | 占比 | 说明 |
|------|----------|------|------|
| SRAM 总计（SM+I-Cache+D-Cache+L2+Const+TC） | ~1.05mm² | 30% | SM 64KB + I-Cache 32KB + D-Cache 64KB + L2 256KB + Const 16KB + TC 64KB = 496KB |
| Register File（16 bank） | ~0.35mm² | 10% | 16×1024×32b = 512Kbit |
| RT 单元（BVH 遍历） | ~0.30mm² | 9% | Ray-Box/Ray-Triangle 硬件加速 |
| Mesh/Async 逻辑 | ~0.20mm² | 6% | Meshlet + 异步计算队列 |
| SIMD 数据通路（128-wide） | ~0.50mm² | 14% | ALU 阵列 + 互连 |
| 控制逻辑 + FSM | ~0.30mm² | 9% | Warp 调度 + 指令发射 + 记分板 |
| DFT（扫描链+MBIST+LBIST） | ~0.30mm² | 9% | 128 扫描链 + 3 MBIST + LBIST |
| ECC/Parity 逻辑 | ~0.15mm² | 4% | SECDED 编解码器 |
| 接口逻辑（AXI4） | ~0.15mm² | 4% | AXI4 512-bit 主/从接口 |
| 其他（时钟树/复位/IO） | ~0.22mm² | 6% | 时钟树 + 复位同步器 + pad |
| **合计** | **3.52mm²** | **100%** | |

### 进一步压缩方案（从 3.52mm² 压至 ≤3.0mm²）

**[HARD-CONSTRAINT-VIOLATION] 面积预估 3.52mm² 超出约束 3.0mm²，需压缩 0.52mm²**

需要从以下组件中合计压缩 0.52mm²：

| # | 压缩措施 | 面积节省 | 性能影响 | 风险 |
|---|----------|----------|----------|------|
| C1 | L2 Cache 256KB→128KB | -0.10mm² | L2 命中率下降，带宽压力增加 | 中 |
| C2 | L2 Cache 256KB→64KB（更激进） | -0.15mm² | L2 命中率显著下降 | 高 |
| C3 | RF bank 16→8 | -0.12mm² | Register File 带宽减半，可能引入 bank 冲突 | 中-高 |
| C4 | Constant Memory 16KB→4KB | -0.02mm² | 常量缓存容量降低 | 低 |
| C5 | Texture Cache 64KB→32KB | -0.04mm² | 纹理缓存命中率下降 | 低-中 |
| C6 | D-Cache 64KB→32KB | -0.04mm² | 数据缓存命中率下降 | 中 |
| C7 | L2 Cache 直接去掉 | -0.20mm² | 依赖外部内存层次 | 高 |
| C8 | RT BVH 单元简化（共享 ALU 复用） | -0.10mm² | RT 性能下降 | 中 |
| C9 | 减少 DFT 冗余（降低压缩比 20x→10x） | -0.05mm² | 测试时间增加 | 低 |

**推荐组合方案**（保守，性能影响可控）：

| 措施 | 节省 | 累计 |
|------|------|------|
| 基线（用户已选） | - | 3.52mm² |
| C1: L2 256KB→128KB | -0.10mm² | 3.42mm² |
| C3: RF bank 16→8 | -0.12mm² | 3.30mm² |
| C5: TC 64KB→32KB | -0.04mm² | 3.26mm² |
| C4: Const 16KB→4KB | -0.02mm² | 3.24mm² |
| C8: RT 单元简化 | -0.10mm² | 3.14mm² |
| C9: DFT 压缩比降级 | -0.05mm² | 3.09mm² |
| **合计** | **-0.43mm²** | **3.09mm²** |

3.09mm² 仍在 3mm² 边界。需再压缩 0.09mm²：

**补充措施**：
- C6: D-Cache 64KB→32KB（-0.04mm²）→ 3.05mm²
- 或 C7 部分: L2 进一步 128KB→64KB（再-0.05mm²）→ 3.04mm²

**激进组合方案**（性能影响较大，面积裕量充足）：

| 措施 | 节省 | 累计 |
|------|------|------|
| 基线（用户已选） | - | 3.52mm² |
| C2: L2 256KB→64KB | -0.15mm² | 3.37mm² |
| C3: RF bank 16→8 | -0.12mm² | 3.25mm² |
| C5: TC 64KB→32KB | -0.04mm² | 3.21mm² |
| C6: D-Cache 64KB→32KB | -0.04mm² | 3.17mm² |
| C4: Const 16KB→4KB | -0.02mm² | 3.15mm² |
| C8: RT 单元简化 | -0.10mm² | 3.05mm² |
| C9: DFT 压缩比降级 | -0.05mm² | **3.00mm²** |
| **合计** | **-0.52mm²** | **3.00mm²** |

**苏启辰建议**：推荐保守组合方案（3.09mm²），面积约束 3mm² 作为目标值而非硬约束，留 3% 裕量（3.09mm²）更稳健。若必须严格 ≤3mm²，采用激进方案但需接受 L2 仅 64KB 和 RF bank 冲突风险。

---

## 需求汇总表

### schema_version: 1.0

### 基础约束需求（REQ-001 ~ REQ-028）

| 需求ID | 需求名称 | 需求描述 | 确认值 | 优先级 | 来源阶段 | 状态 |
|--------|----------|----------|--------|--------|----------|------|
| REQ-001 | 工艺与频率 | 工艺节点 5nm，工作频率 2.5GHz | 5nm / 2.5GHz | Must | stageB phase1 | Confirmed |
| REQ-002 | 接口协议 | AXI4 512-bit 主/从接口 | AXI4 512-bit | Must | stageB phase1 | Confirmed |
| REQ-003 | 数据流特征 | SIMT 128-wide SIMD，4×32 sub-partition | 128-wide SIMD | Should | stageB phase1 | Confirmed |
| REQ-004 | 延迟约束 | 管线深度 ≤10 cycles | ≤10 cycles | Should | stageB phase1 | Confirmed |
| REQ-005 | PPA 约束 | 面积 ≤3mm²，功耗 ≤500mW | 3mm² / 500mW | Must | stageB phase1 | Confirmed |
| REQ-006 | 时钟域 | 3 个时钟域：core/uncore/axi | 3 domains | Should | stageB phase1 | Confirmed |
| REQ-007 | 低功耗设计 | 4 个独立功耗域，支持 Power Gating | 4 domains | Should | stageB phase1 | Confirmed |
| REQ-008 | DFT 设计 | 128 扫描链，压缩比 20x，3 MBIST 控制器 | 128 chains / 20x | Could | stageB phase1 | Confirmed |
| REQ-009 | 可靠性设计 | ECC SECDED 保护关键存储器 | ECC/SECDED | Should | stageB phase1 | Confirmed |
| REQ-010 | 复位策略 | 异步复位同步释放，低有效 | async reset | Should | stageB phase1 | Confirmed |
| REQ-011 | CDC 策略 | 集中式 CDC 模块，双触发器 + 异步 FIFO | Centralized CDC | Should | stageB phase1 | Confirmed |
| REQ-012 | 存储器选型 | RF 16bank + SM 64KB + D-Cache 64KB + I-Cache 32KB + L2 256KB + Const 16KB + TC 64KB | 见存储表 | Should | stageB phase1 | Confirmed |
| REQ-013 | PVT 条件 | TT/SS/FF corner，-40~125°C | 3 corners | Should | stageB phase1 | Confirmed |
| REQ-014 | 封装约束 | BGA 封装，引脚数 ≤1000 | BGA ≤1000 | Should | stageB phase1 | Confirmed |
| REQ-015 | 电压域 | 核心 0.75V，IO 1.05V | 0.75V/1.05V | Should | stageB phase1 | Confirmed |
| REQ-016 | 带宽约束 | 内存带宽 ≥51.2 GB/s | ≥51.2 GB/s | Should | stageB phase1 | Confirmed |
| REQ-017 | 线程配置 | 最大 2048 线程/SM，32 线程/Warp | 2048/32 | Should | stageB phase1 | Confirmed |
| REQ-018 | 安全隔离 | VF 级隔离，支持 SR-IOV | VF isolation | Should | stageB phase1 | Confirmed |
| REQ-019 | 调试接口 | JTAG + 调试断点/单步 | JTAG | Should | stageB phase1 | Confirmed |
| REQ-020 | 性能监控 | PMU 硬件性能计数器 | PMU | Should | stageB phase1 | Confirmed |
| REQ-021 | 热管理 | 温度传感器 + DVFS 接口 | DVFS | Should | stageB phase1 | Confirmed |
| REQ-022 | 形式验证属性 | SVA 属性覆盖关键路径 | SVA | Should | stageB phase1 | Confirmed |
| REQ-023 | 时序约束 | SDC 约束完整，时序裕量 ≥10% | 10% margin | Should | stageB phase1 | Confirmed |
| REQ-024 | 形式验证 | 形式验证覆盖关键模块 | Formal | Should | stageB phase1 | Confirmed |
| REQ-025 | UVM 验证 | UVM 4 层验证环境，功能覆盖率 ≥90% | UVM 90% | Should | stageB phase1 | Confirmed |
| REQ-026 | 封装热阻 | θJA ≤15°C/W | ≤15°C/W | Should | stageB phase1 | Confirmed |
| REQ-027 | 老化裕量 | 老化裕量 ≥10% | ≥10% | Could | stageB phase1 | Confirmed |
| REQ-028 | 时钟抖动 | 时钟抖动 ≤50ps RMS | ≤50ps | Could | stageB phase1 | Confirmed |

### 头脑风暴新增需求（REQ-029 ~ REQ-035）

| 需求ID | 需求名称 | 需求描述 | 优先级 | 来源阶段 | 状态 | 备注 |
|--------|----------|----------|--------|----------|------|------|
| REQ-029 | Ray Tracing 单元 | 硬件 RT Core，BVH 遍历加速，Ray-Box/Ray-Triangle 交集测试 | Must | stageB phase2 | Confirmed | 对标 RTX/RDNA3 RT |
| REQ-030 | Mesh Shader | 替代传统 VS+GS 管线，支持 Meshlet 渲染 | Must | stageB phase2 | Confirmed | DX12 Ultimate 必备 |
| REQ-031 | Async Compute | 独立计算队列，图形/计算并行执行 | Must | stageB phase2 | Confirmed | 提升 GPU 利用率 |
| REQ-032 | Programmable Blending | 像素级可编程混合操作 | Should | stageB phase2 | Confirmed | 自定义混合方程 |
| REQ-033 | VRS 2.0 | Variable Rate Shading 2.0，Per-Draw + Per-Primitive | Should | stageB phase2 | Confirmed | 着色速率控制 |
| REQ-034 | Geometry Shader | 传统几何着色器（微码模拟） | Could | stageB phase2 | Confirmed | 调和方案：微码模拟，无专用硬件 |
| REQ-035 | Tile-Based Rendering | 分块渲染，降低带宽需求 | Could | stageB phase2 | Deferred | 延后至下一代 |

### 矛盾调和后的约束修订

| 需求ID | 修订项 | 原始值 | 调和后值 | 调和原因 |
|--------|--------|--------|----------|----------|
| REQ-005 | 面积约束 | 3mm²（含 DFT 2.91mm²） | 3mm²（目标值，3% 裕量=3.09mm² 可接受） | 面积压缩后 3.09mm²，严格 ≤3mm² 需激进裁剪 |
| REQ-005 | 功耗约束 | 500mW | 500mW + 强制 Clock Gating | 未使用功能单元自动关时钟 |
| REQ-007 | 功耗域策略 | 4 个独立域 | 4 域，CDC 模块放在 Always-On 域 | 调和方案 A |
| REQ-008 | DFT 压缩比 | 20x | 10x（可选降级） | 面积压缩措施 C9 |
| REQ-011 | CDC 策略 | 集中式 CDC | 集中式 CDC，Always-On 域 | 调和方案 A |
| REQ-012 | 存储器配置 | RF 32bank + SM 128KB + I-Cache 64KB | RF 16bank + SM 64KB + I-Cache 32KB | 面积压缩 |
| REQ-034 | Geometry Shader | 硬件实现 | 微码模拟 | 调和方案 C |
| REQ-025 | 验证策略 | 2 人团队 | 4 人团队 + 分阶段验证 | 调和方案 A+B |

### 优先级分布统计

| 优先级 | 数量 | 占比 | 需求ID |
|--------|------|------|--------|
| Must | 5 | 11% | REQ-001, REQ-002, REQ-005, REQ-029, REQ-030, REQ-031 |
| Should | 24 | 55% | REQ-003, REQ-004, REQ-006, REQ-007, REQ-009, REQ-010, REQ-011, REQ-013~026, REQ-032, REQ-033 |
| Could | 8 | 18% | REQ-008, REQ-027, REQ-028, REQ-034 |
| Deferred | 1 | 2% | REQ-035 |
| 冻结 | 4 | 9% | REQ-001, REQ-002, REQ-005, REQ-006（硬约束不可变更） |
| 面积修订 | 5 | - | REQ-005, REQ-007, REQ-008, REQ-011, REQ-012, REQ-034, REQ-025 |

---

## 覆盖率分析

### 覆盖热力图（调和后更新）

| 维度 | 覆盖状态 | 说明 |
|------|----------|------|
| 频率/工艺 | HOT | 5nm @ 2.5GHz 已充分覆盖 |
| 接口 | HOT | AXI4 512-bit 已确认 |
| 功能 | HOT | 15+ 功能已定义（含头脑风暴新增） |
| PPA | WARM（改善） | 面积从 3.52mm² 压缩至 ~3.09mm²，功耗强制 Clock Gating |
| 可靠性 | WARM | ECC/Parity 已确认 |
| DFT | WARM | 128 扫描链，可选压缩比降级 |
| CDC | WARM | Always-On 域方案已确认 |
| 验证 | WARM | 4 人团队 + 分阶段验证 |

### Frozen REQ（硬约束，不可变更）

| REQ | 冻结原因 |
|-----|----------|
| REQ-001 | 工艺节点 5nm + 频率 2.5GHz（产品规格锁定） |
| REQ-002 | AXI4 512-bit（SoC 总线架构锁定） |
| REQ-005 | 面积 3mm² + 功耗 500mW（封装/散热锁定） |
| REQ-006 | 3 时钟域（时钟架构锁定） |

### 端到端覆盖率视图

| REQ | 需求覆盖 | 方案覆盖 | 验证覆盖 | 评审覆盖 | 状态 |
|-----|----------|----------|----------|----------|------|
| REQ-001 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-002 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-003 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-004 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-005 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖（面积调和中） |
| REQ-006 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-007 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-008 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-009 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-010 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-011 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-012 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖（面积调和中） |
| REQ-013~028 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-029 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-030 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-031 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-032~033 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖 |
| REQ-034 | ✅ | ⬜ | ⬜ | ⬜ | 部分覆盖（微码模拟） |
| REQ-035 | ✅ | ⬜ | ⬜ | ⬜ | Deferred |

**覆盖率统计**：
- 已全覆盖：0/35（0%）
- 部分覆盖：34/35（97%）
- 未覆盖：0/35（0%）
- Deferred：1/35（3%）
- Frozen：4/35（11%）

> 注：需求覆盖已完成（stageC），方案覆盖（stageD）、验证覆盖（stageE/F）、评审覆盖将在后续阶段逐步填充。

---

## [PHASE-END] stageC phase2 需求汇总表生成完成

## [STEP-PAUSE] stageC phase2 需求汇总表已生成，请确认后继续。
- 需求总数：35 项（28 基础 + 7 头脑风暴）
- Must：6 项 / Should：24 项 / Could：4 项 / Deferred：1 项
- 面积压缩方案：推荐保守组合（3.09mm²）或激进组合（3.00mm²）
- 矛盾调和：5 个矛盾全部调和
- 冻结 REQ：4 项（硬约束不可变更）

---

### 轮 44（用户确认）

**苏启辰**：
请确认需求汇总表：35 项需求、优先级分布、面积压缩方案选择。

**用户**：
面积压缩选保守组合 3.09mm²，3mm² 作为 Target 而非 Budget，3% 裕量可接受。需求汇总表 35 项确认完整，优先级正确。冻结 REQ 确认同意。进入 stageD。

---

## 阶段结论

stageC phase2 需求汇总表已确认并冻结：
- 需求总数：35 项
- Must：6 项（REQ-001/002/005/029/030/031）
- Should：24 项
- Could：4 项（REQ-008/027/028/034）
- Deferred：1 项（REQ-035）
- Frozen：4 项（REQ-001/002/005/006）
- 面积：3.09mm²（Target，保守组合）
- 功耗：500mW + 强制 Clock Gating
- 矛盾调和：5 个矛盾全部解决

## [STAGE-END] stageC phase2 已完成，需求冻结确认。
