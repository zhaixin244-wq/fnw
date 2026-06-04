# GPU Shader Core - stageB phase2 头脑风暴 沟通记录

> 模块：GPU Shader Core
> 阶段：stageB phase2（头脑风暴 Feature Discovery）
> 日期：2026-06-04

---

## [STAGE-START] stageB phase2 头脑风暴

> **锚定**：模块=GPU Shader Core | 定位=GPU 计算单元，SIMT 执行+纹理采样+光栅化+Tensor Core | 硬约束={面积3mm², 功耗500mW, 频率2.5GHz, 5nm} | 阶段=stageB phase2

### 头脑风暴维度规划

| 轮次 | 维度 | 状态 |
|------|------|------|
| 第 1 轮 | 功能扩展 | ✅ 已完成 |
| 第 2 轮 | 性能优化 | ✅ 已完成 |
| 第 3 轮 | 兼容性 | 🔄 执行中 |
| 第 4 轮 | 可测试性 | ⬜ 待执行 |
| 第 5 轮 | 可维护性 | ⬜ 待执行 |

---

## 第 1 轮：功能扩展维度

### 轮 35 — 功能扩展探索

**苏启辰**：

基于 stageB phase1 已确认的 36 项约束，探索功能扩展维度。GPU Shader Core 已覆盖核心 SIMT 执行、纹理采样、光栅化、Tensor Core。以下按现代 GPU 架构实践，逐项分析可能遗漏的功能：

**功能扩展候选清单**：

| # | 功能项 | 说明 | 行业参考 |
|---|--------|------|----------|
| 1 | Ray Tracing 单元 | 硬件加速光线遍历+求交+BVH | NVIDIA RTX, AMD RDNA2+ |
| 2 | Geometry Shader | 几何着色器阶段 | DX10+, OpenGL |
| 3 | Mesh Shader | 网格着色器（替代传统 VS+GS） | DX12U, Vulkan |
| 4 | Programmable Blending | 可编程混合单元 | 移动端 GPU |
| 5 | VRS 2.0 | 可变速率着色 | DX12U |
| 6 | Async Compute | 异步计算引擎 | AMD GCN+, NVIDIA Maxwell+ |
| 7 | Tile-Based Rendering | 分块渲染 | 移动端 GPU (Mali, Adreno) |

请逐项确认优先级：Must / Should / Could / 不需要。

---

### 轮 36 — 功能扩展确认

**用户**：

- Ray Tracing 单元：Must，现代 GPU 标配，DX12U 要求
- Geometry Shader：Could，软件模拟即可，不硬件加速
- Mesh Shader：Must，DX12U/Vulkan 要求
- Programmable Blending：Should，移动端有用
- VRS 2.0：Should，DX12U 特性
- Async Compute：Must，现代 GPU 关键特性
- Tile-Based Rendering：Could，桌面 GPU 不需要，移动 GPU 才需要

---

### 第 1 轮结论 — 新增 REQ

| REQ | 功能项 | 确认值 | 优先级 | 备注 |
|-----|--------|--------|--------|------|
| REQ-029 | Ray Tracing 单元 | 硬件加速 RT Core（光线遍历+求交+BVH） | Must | DX12U 要求，现代 GPU 标配 |
| REQ-030 | Geometry Shader | 软件模拟，不硬件加速 | Could | 面积紧张，GS 使用率低 |
| REQ-031 | Mesh Shader | 硬件支持 Mesh/Amplification Shader | Must | DX12U/Vulkan 核心特性 |
| REQ-032 | Programmable Blending | 可编程混合单元 | Should | 移动端有用，桌面可选 |
| REQ-033 | VRS 2.0 | 可变速率着色（2x2/4x4 tile） | Should | DX12U 特性 |
| REQ-034 | Async Compute | 硬件级异步计算引擎（独立队列+调度） | Must | 现代 GPU 关键特性 |
| REQ-035 | Tile-Based Rendering | 不采用 | Could | 桌面 GPU 不需要，已排除 |

**矛盾检测**：
- REQ-029（RT Core）vs 面积约束 3mm²：RT Core 预估额外 0.3~0.5mm²，含 DFT 后总面积可能超标。需在 stageD 详细评估。
- REQ-034（Async Compute）vs 功耗约束 500mW：异步计算增加调度复杂度和额外功耗，需在 stageD 功耗优化中关注。
- REQ-031（Mesh Shader）vs REQ-030（Geometry Shader）：Mesh Shader 可替代 GS，两者不冲突（GS 软件模拟，Mesh 硬件加速）。

**[HARD-CONSTRAINT-RISK] REQ-029 RT Core 面积风险：预估额外 0.3~0.5mm²，加上已有 2.91mm²，总面积可能达 3.2~3.4mm²，超出 3mm² 预算。需在 stageD 做面积压缩或功能裁剪。**

---

## [STEP-PAUSE] 第 1 轮功能扩展已完成，等待用户确认后进入第 2 轮

---

## 第 2 轮：性能优化维度

### 轮 37 — 性能优化探索

**苏启辰**：

> **锚定**：模块=GPU Shader Core | 定位=GPU 计算单元，SIMT 执行+纹理采样+光栅化+Tensor Core+RT Core+Mesh Shader | 硬约束={面积3mm², 功耗500mW, 频率2.5GHz, 5nm} | 阶段=stageB phase2 第2轮

基于第 1 轮功能扩展结果，探索性能优化维度。当前已确认的性能基线：
- 计算吞吐：1024 FP16 ops/cycle（Tensor Core）
- SIMD 宽度：128-wide, 4x32 sub-partition
- Warp 数量：64 warps
- 纹理吞吐：8 samples/cycle
- 接口带宽：512-bit AXI4 @ 2.5GHz = 160 GB/s

以下按 GPU 性能优化实践，逐项分析可能的性能增强需求：

**性能优化候选清单**：

| # | 优化项 | 说明 | 性能收益 | 面积/功耗代价 |
|---|--------|------|----------|-------------|
| 1 | **Warp 级乱序执行** | Warp 间乱序调度，隐藏长延迟操作（如纹理/RT） | 吞吐 +15~25% | 控制逻辑 +0.05mm² |
| 2 | **指令 Cache 预取** | I-Cache 硬件预取（顺序预取 + 分支预测） | I-Cache 命中率 +5~10% | 预取逻辑 +0.02mm² |
| 3 | **数据 Cache 预取** | D-Cache 硬件预取（stride 检测 + 预取引擎） | D-Cache 命中率 +10~20% | 预取引擎 +0.03mm² |
| 4 | **寄存器文件 Bank 冲突优化** | Operand Collector 动态 bank 映射 | RF 吞吐 +10~15% | 映射逻辑 +0.02mm² |
| 5 | **L1 Cache 写回/写穿可配置** | 支持 Write-Back 和 Write-Through 模式切换 | 写带宽灵活性 | 控制逻辑 +0.01mm² |
| 6 | **双发射（Dual Issue）** | 同一周期发射 2 条独立指令到不同执行单元 | 指令吞吐 +30~50% | 发射逻辑 +0.08mm² |
| 7 | **Tensor Core FP8/INT8 混合精度** | 在 FP16 基础上支持 FP8/INT8 低精度加速 | TC 吞吐翻倍 | 格式转换 +0.05mm² |
| 8 | **RT Core BVH 压缩** | BVH 节点压缩存储，减少内存带宽消耗 | RT 带宽 -30~40% | 解压逻辑 +0.02mm² |
| 9 | **Shared Memory Bank 冲突消除** | 动态 bank 偏移（XOR-based） | SM 吞吐 +5~10% | 偏移逻辑 +0.01mm² |
| 10 | **Occupancy 优化 - 寄存器文件分区** | RF 按 warp 分区，减少上下文切换开销 | Warp 切换延迟 -20% | 分区逻辑 +0.03mm² |

**性能优化与硬约束的关系**：

| 优化项 | 面积影响 | 功耗影响 | 时序影响 |
|--------|----------|----------|----------|
| Warp 乱序 | +0.05mm² | +5mW | 无关键路径 |
| I-Cache 预取 | +0.02mm² | +3mW | 无关键路径 |
| D-Cache 预取 | +0.03mm² | +5mW | 无关键路径 |
| RF Bank 冲突 | +0.02mm² | +2mW | 无关键路径 |
| L1 WB/WT | +0.01mm² | +1mW | 无关键路径 |
| 双发射 | +0.08mm² | +15mW | 发射逻辑关键路径 |
| TC FP8/INT8 | +0.05mm² | +8mW | 格式转换延迟 |
| RT BVH 压缩 | +0.02mm² | +3mW | 解压延迟 1~2 cycles |
| SM Bank 冲突 | +0.01mm² | +1mW | 无关键路径 |
| RF 分区 | +0.03mm² | +3mW | 无关键路径 |
| **合计** | **+0.32mm²** | **+46mW** | |

`[HARD-CONSTRAINT-CHECK] 全部采用时：面积 2.91 + 0.32 + RT(0.4) = 3.63mm²，超标 21%。功耗 500 + 46 = 546mW，超标 9%。必须做取舍。`

**推荐优先级分组**：

| 优先级 | 优化项 | 理由 |
|--------|--------|------|
| **P0 必选** | Warp 乱序、D-Cache 预取、RF Bank 冲突 | 面积代价小，性能收益大 |
| **P1 推荐** | I-Cache 预取、SM Bank 冲突、RT BVH 压缩 | 代价极小，收益明确 |
| **P2 可选** | TC FP8/INT8、RF 分区、L1 WB/WT | 代价中等，收益看场景 |
| **P3 延后** | 双发射 | 面积代价大，时序风险高 |

请逐项确认优先级：P0 必选 / P1 推荐 / P2 可选 / P3 延后 / 不需要。

---

### 轮 38 — 性能优化确认

**用户**：

- P0 必选：全部采纳（Warp 乱序、D-Cache 预取、RF Bank 冲突优化）
- P1 推荐：全部采纳（I-Cache 预取、SM Bank 冲突、RT BVH 压缩）
- P2 可选：只采纳 TC FP8/INT8（推理场景必须），RF 分区和 L1 WB/WT 延后
- P3 延后：双发射不采纳
- 面积预估要重新算，RT Core 的 0.4mm² 面积加上去后 3mm² 预算很紧

---

### 第 2 轮结论 — 性能优化确认

| 优化项 | 优先级 | 确认结果 | 面积代价 | 功耗代价 |
|--------|--------|----------|----------|----------|
| Warp 级乱序执行 | P0 | 采纳 | +0.05mm² | +5mW |
| D-Cache 预取 | P0 | 采纳 | +0.03mm² | +5mW |
| RF Bank 冲突优化 | P0 | 采纳 | +0.02mm² | +2mW |
| I-Cache 预取 | P1 | 采纳 | +0.02mm² | +3mW |
| SM Bank 冲突消除 | P1 | 采纳 | +0.01mm² | +1mW |
| RT Core BVH 压缩 | P1 | 采纳 | +0.02mm² | +3mW |
| TC FP8/INT8 混合精度 | P2 | 采纳（推理必须） | +0.05mm² | +8mW |
| RF 分区 | P2 | 延后 | - | - |
| L1 WB/WT 可配置 | P2 | 延后 | - | - |
| 双发射 | P3 | 不采纳 | - | - |

**面积重算**：

| 组成部分 | 面积 |
|----------|------|
| 基线（stageB phase1） | 2.91mm² |
| RT Core（REQ-029） | +0.40mm² |
| P0 优化（乱序+D-Cache+RF Bank） | +0.10mm² |
| P1 优化（I-Cache+SM Bank+BVH压缩） | +0.05mm² |
| P2 优化（TC FP8/INT8） | +0.05mm² |
| **总计（含 DFT 前）** | **3.51mm²** |
| DFT 开销（~8%） | +0.28mm² |
| **总计（含 DFT）** | **3.79mm²** |

**[HARD-CONSTRAINT-VIOLATION] 面积预估 3.79mm² 超出约束 3mm²，超标 26.3%。**

**面积压缩策略（待 stageD 落实）**：
1. Cache 容量削减：L1I 16KB→8KB（-0.08mm²）、L1D 32KB→16KB（-0.12mm²）
2. Tensor Core 数量削减：8 个→4 个（-0.15mm²）
3. SIMD 宽度缩减：128-wide→64-wide（-0.20mm²）
4. Warp 数量削减：64→32（-0.08mm²）
5. 以上组合可压缩 0.45~0.63mm²，目标压到 3.14~3.34mm²（含 DFT），仍有超标风险

**功耗重算**：

| 组成部分 | 功耗 |
|----------|------|
| 基线 | ~500mW |
| P0+P1+P2 优化 | +46mW |
| **总计** | **~546mW** |

**[HARD-CONSTRAINT-RISK] 功耗预估 546mW 超出约束 500mW，超标 9.2%。需在 stageD 做功耗优化（Clock Gating、电压调节等）。**

**新增 REQ**：

| REQ | 优化项 | 确认值 | 优先级 |
|-----|--------|--------|--------|
| REQ-036 | Warp 乱序调度 | 硬件级 Warp 间乱序调度器 | P0 必选 |
| REQ-037 | Cache 预取引擎 | I-Cache 顺序预取 + D-Cache stride 预取 | P0 必选 |
| REQ-038 | RF Bank 冲突优化 | Operand Collector 动态 bank 映射 | P0 必选 |
| REQ-039 | TC FP8/INT8 | Tensor Core 支持 FP8/INT8 混合精度 | P2 可选 |

---

## [STEP-PAUSE] 第 2 轮性能优化已完成，等待用户确认后进入第 3 轮

---

## 第 3 轮：兼容性维度

### 轮 39 — 兼容性探索

**苏启辰**：

> **锚定**：模块=GPU Shader Core | 定位=GPU 计算单元，SIMT 执行+纹理采样+光栅化+Tensor Core+RT Core+Mesh Shader | 硬约束={面积3mm², 功耗500mW, 频率2.5GHz, 5nm} | 阶段=stageB phase2 第3轮

基于前两轮结果，探索兼容性维度。GPU Shader Core 需要兼容多个 API 标准、驱动版本和硬件生态。以下按 GPU 兼容性实践，逐项分析可能的兼容性需求：

**兼容性候选清单**：

| # | 兼容性项 | 说明 | 行业参考 |
|---|----------|------|----------|
| 1 | **API 版本兼容** | DX12 Ultimate / Vulkan 1.3+ / OpenGL 4.6 / OpenCL 3.0 | NVIDIA/AMD 全系 |
| 2 | **驱动 ABI 稳定性** | 硬件寄存器接口版本化，驱动向前/向后兼容 | NVIDIA/AMD 驱动模型 |
| 3 | **Shader Model 兼容** | SM 6.0 ~ SM 6.8（DX12 Shader Model） | DX12 规范 |
| 4 | **指令集兼容** | 自定义 ISA 版本化，支持旧版指令 | NVIDIA PTX / AMD GCN ISA |
| 5 | **内存模型兼容** | Vulkan Memory Model / OpenCL 内存一致性 | Vulkan/OpenCL 规范 |
| 6 | **精度兼容** | IEEE 754 浮点精度 / 着色器精度要求 | DX/Vulkan 精度规范 |
| 7 | **扩展兼容** | SPIR-V 扩展 / Vulkan 扩展 / OpenCL 扩展 | 各 API 扩展注册表 |
| 8 | **硬件抽象层** | HAL 接口标准化，便于多代硬件复用驱动 | NVIDIA/AMD 驱动架构 |
| 9 | **调试接口兼容** | GPU 调试器接口（如 PIX、RenderDoc、Nsight） | 调试工具生态 |
| 10 | **性能计数器兼容** | 标准化性能计数器接口（如 PerfKit、RGP） | 性能分析工具 |

**兼容性与硬约束的关系**：

| 兼容性项 | 面积影响 | 功耗影响 | 设计复杂度 |
|----------|----------|----------|------------|
| API 版本兼容 | 无直接面积 | 无 | 中（功能覆盖） |
| 驱动 ABI 稳定性 | 寄存器冗余 +0.01mm² | 无 | 低 |
| Shader Model 兼容 | 指令解码 +0.02mm² | +2mW | 中 |
| 指令集兼容 | ISA 解码 +0.03mm² | +3mW | 高 |
| 内存模型兼容 | 内存屏障逻辑 +0.02mm² | +2mW | 高 |
| 精度兼容 | 精度转换单元 +0.01mm² | +1mW | 低 |
| 扩展兼容 | 扩展寄存器 +0.01mm² | +1mW | 低 |
| 硬件抽象层 | 无直接面积 | 无 | 中 |
| 调试接口兼容 | 调试寄存器 +0.01mm² | 无 | 低 |
| 性能计数器兼容 | 计数器逻辑 +0.01mm² | 无 | 低 |
| **合计** | **+0.12mm²** | **+10mW** | |

**推荐优先级分组**：

| 优先级 | 兼容性项 | 理由 |
|--------|----------|------|
| **P0 必选** | API 版本兼容、Shader Model 兼容、指令集兼容 | GPU 核心卖点，市场准入 |
| **P1 推荐** | 驱动 ABI 稳定性、内存模型兼容、精度兼容 | 工程质量，长期维护 |
| **P2 可选** | 扩展兼容、硬件抽象层、调试接口、性能计数器 | 增值特性，可迭代 |

请逐项确认优先级：P0 必选 / P1 推荐 / P2 可选 / 不需要。
