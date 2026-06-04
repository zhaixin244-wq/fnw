# GPU Shader Core 需求汇总表

> 版本：v1.0
> 日期：2026-06-04
> schema_version: 1.0
> 模块：GPU Shader Core
> 工艺：5nm / 频率：2.5GHz
> 面积约束：3mm² / 功耗约束：500mW

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| 模块名称 | GPU Shader Core |
| 版本 | v1.0 |
| 文档编号 | GPU-SC-REQ-v1.0 |
| 生成日期 | 2026-06-04 |
| 需求总数 | 35 项 |
| 当前阶段 | stageC phase2（需求汇总冻结） |

---

## 2. 基础约束需求（REQ-001 ~ REQ-028）

| 需求ID | 需求名称 | 需求描述 | 确认值 | 优先级 | 来源阶段 | 状态 |
|--------|----------|----------|--------|--------|----------|------|
| REQ-001 | 工艺与频率 | 工艺节点和工作频率 | 5nm / 2.5GHz | Must | stageB phase1 | Confirmed |
| REQ-002 | 接口协议 | 主接口协议和位宽 | AXI4 512-bit | Must | stageB phase1 | Confirmed |
| REQ-003 | 数据流特征 | SIMD 宽度和分区配置 | 128-wide SIMD, 4x32 sub-partition | Should | stageB phase1 | Confirmed |
| REQ-004 | 延迟约束 | 管线深度上限 | ≤10 cycles | Should | stageB phase1 | Confirmed |
| REQ-005 | PPA 约束 | 面积和功耗上限 | 面积 ≤3mm², 功耗 ≤500mW | Must | stageB phase1 | Confirmed |
| REQ-006 | 时钟域 | 时钟域数量和名称 | 3 domains (core/uncore/axi) | Should | stageB phase1 | Confirmed |
| REQ-007 | 低功耗设计 | 功耗域和 Power Gating | 4 domains, PG 支持 | Should | stageB phase1 | Confirmed |
| REQ-008 | DFT 设计 | 扫描链和 MBIST 配置 | 128 chains, 20x 压缩, 3 MBIST | Could | stageB phase1 | Confirmed |
| REQ-009 | 可靠性设计 | ECC/Parity 保护策略 | ECC SECDED | Should | stageB phase1 | Confirmed |
| REQ-010 | 复位策略 | 复位方式和极性 | 异步复位同步释放, 低有效 | Should | stageB phase1 | Confirmed |
| REQ-011 | CDC 策略 | 跨时钟域处理方案 | 集中式 CDC, Always-On 域 | Should | stageB phase1 | Confirmed |
| REQ-012 | 存储器选型 | 各存储器类型和容量 | RF 16bank + SM 64KB + D-Cache 64KB + I-Cache 32KB + L2 256KB + Const 16KB + TC 64KB | Should | stageB phase1 | Confirmed |
| REQ-013 | PVT 条件 | 工艺/电压/温度 corner | TT/SS/FF, -40~125°C | Should | stageB phase1 | Confirmed |
| REQ-014 | 封装约束 | 封装类型和引脚数 | BGA ≤1000 pins | Should | stageB phase1 | Confirmed |
| REQ-015 | 电压域 | 核心和 IO 电压 | Core 0.75V, IO 1.05V | Should | stageB phase1 | Confirmed |
| REQ-016 | 带宽约束 | 内存带宽下限 | ≥51.2 GB/s | Should | stageB phase1 | Confirmed |
| REQ-017 | 线程配置 | 最大线程数和 Warp 大小 | 2048 threads/SM, 32 threads/Warp | Should | stageB phase1 | Confirmed |
| REQ-018 | 安全隔离 | VF 级隔离和 SR-IOV | VF isolation | Should | stageB phase1 | Confirmed |
| REQ-019 | 调试接口 | 调试访问方式 | JTAG + 断点/单步 | Should | stageB phase1 | Confirmed |
| REQ-020 | 性能监控 | 硬件性能计数器 | PMU | Should | stageB phase1 | Confirmed |
| REQ-021 | 热管理 | 温度传感器和 DVFS | DVFS 接口 | Should | stageB phase1 | Confirmed |
| REQ-022 | 形式验证属性 | SVA 属性覆盖 | SVA 关键路径 | Should | stageB phase1 | Confirmed |
| REQ-023 | 时序约束 | SDC 约束和时序裕量 | 10% margin | Should | stageB phase1 | Confirmed |
| REQ-024 | 形式验证 | 形式验证覆盖范围 | 关键模块形式验证 | Should | stageB phase1 | Confirmed |
| REQ-025 | UVM 验证 | 验证环境和覆盖率 | UVM 4 层, 覆盖率 ≥90%, 4 人团队 | Should | stageB phase1 | Confirmed |
| REQ-026 | 封装热阻 | 热阻上限 | θJA ≤15°C/W | Should | stageB phase1 | Confirmed |
| REQ-027 | 老化裕量 | 老化设计裕量 | ≥10% | Could | stageB phase1 | Confirmed |
| REQ-028 | 时钟抖动 | 时钟抖动上限 | ≤50ps RMS | Could | stageB phase1 | Confirmed |

---

## 3. 头脑风暴新增需求（REQ-029 ~ REQ-035）

| 需求ID | 需求名称 | 需求描述 | 优先级 | 来源阶段 | 状态 | 备注 |
|--------|----------|----------|--------|----------|------|------|
| REQ-029 | Ray Tracing 单元 | 硬件 RT Core, BVH 遍历加速, Ray-Box/Ray-Triangle 交集测试 | Must | stageB phase2 | Confirmed | 对标 RTX/RDNA3 RT |
| REQ-030 | Mesh Shader | 替代传统 VS+GS 管线, 支持 Meshlet 渲染 | Must | stageB phase2 | Confirmed | DX12 Ultimate 必备 |
| REQ-031 | Async Compute | 独立计算队列, 图形/计算并行执行 | Must | stageB phase2 | Confirmed | 提升 GPU 利用率 |
| REQ-032 | Programmable Blending | 像素级可编程混合操作 | Should | stageB phase2 | Confirmed | 自定义混合方程 |
| REQ-033 | VRS 2.0 | Variable Rate Shading 2.0, Per-Draw + Per-Primitive | Should | stageB phase2 | Confirmed | 着色速率控制 |
| REQ-034 | Geometry Shader | 传统几何着色器（微码模拟） | Could | stageB phase2 | Confirmed | 无专用硬件, 微码模拟 |
| REQ-035 | Tile-Based Rendering | 分块渲染, 降低带宽需求 | Could | stageB phase2 | Deferred | 延后至下一代 |

---

## 4. 矛盾调和记录

### 4.1 矛盾调和结果

| 矛盾编号 | 矛盾描述 | 严重度 | 调和方案 | 最终决策 |
|----------|----------|--------|----------|----------|
| #1 | 面积预算超标 30% | CRITICAL | B+C 组合 | 去掉 GS 硬件, RF 32→16, SM 128→64KB, I-Cache 64→32KB |
| #2 | 功耗预算偏紧 | HIGH | B | 强制 Clock Gating, 未使用单元自动关时钟 |
| #3 | 功耗域 vs CDC 复杂度 | MEDIUM | A | CDC 模块放在 Always-On 域 |
| #4 | 验证复杂度 vs 周期 | MEDIUM | A+B | 4 人团队 + 分阶段验证 |
| #5 | GS vs MS 功能重叠 | LOW | C | GS 用微码模拟, 无专用硬件 |

### 4.2 面积压缩方案

当前面积预估 3.52mm²，需压缩至 ≤3mm²。

**推荐保守组合**（3.09mm²）：

| 措施 | 面积节省 | 累计 |
|------|----------|------|
| L2 Cache 256KB→128KB | -0.10mm² | 3.42mm² |
| RF bank 16→8 | -0.12mm² | 3.30mm² |
| Texture Cache 64KB→32KB | -0.04mm² | 3.26mm² |
| Constant Memory 16KB→4KB | -0.02mm² | 3.24mm² |
| RT 单元简化（共享 ALU 复用） | -0.10mm² | 3.14mm² |
| DFT 压缩比 20x→10x | -0.05mm² | 3.09mm² |

**激进组合**（3.00mm²）：额外压缩 L2→64KB + D-Cache→32KB。

---

## 5. 优先级分布

| 优先级 | 数量 | 需求ID |
|--------|------|--------|
| Must | 6 | REQ-001, REQ-002, REQ-005, REQ-029, REQ-030, REQ-031 |
| Should | 24 | REQ-003, REQ-004, REQ-006, REQ-007, REQ-009~026, REQ-032, REQ-033 |
| Could | 4 | REQ-008, REQ-027, REQ-028, REQ-034 |
| Deferred | 1 | REQ-035 |

---

## 6. Frozen REQ（硬约束，不可变更）

| REQ | 冻结原因 |
|-----|----------|
| REQ-001 | 工艺节点 5nm + 频率 2.5GHz（产品规格锁定） |
| REQ-002 | AXI4 512-bit（SoC 总线架构锁定） |
| REQ-005 | 面积 3mm² + 功耗 500mW（封装/散热锁定） |
| REQ-006 | 3 时钟域（时钟架构锁定） |

---

## 7. 追溯信息

- **stage0**：模块定位探索 → GPU Shader Core 在 SoC GPU 中的角色确认
- **stageA**：4 个核心问题 → 位置/功能/PPA 优先级/结论确认
- **stageB phase1**：28 项约束逐项确认 → 全部 Confirmed
- **stageB phase2**：5 轮头脑风暴 → 7 项新功能需求（REQ-029~035）
- **stageC phase1**：矛盾检测 → 5 个矛盾发现 → 调和方案确认
- **stageC phase2**：需求汇总表生成 → 35 项需求冻结

---

## 8. 版本历史

| 版本 | 日期 | 变更描述 |
|------|------|----------|
| v1.0 | 2026-06-04 | 初始版本，35 项需求确认，5 个矛盾调和 |
