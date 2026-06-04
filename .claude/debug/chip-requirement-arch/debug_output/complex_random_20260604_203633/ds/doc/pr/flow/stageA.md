# GPU Shader Core - stageA 最小信息集 沟通记录

> 模块：GPU Shader Core
> 阶段：stageA（最小信息集）
> 日期：2026-06-04

---

## [STAGE-START] stageA - 最小信息集

> **锚定**：模块=GPU Shader Core | 定位=GPU 计算单元，集成 SIMD/纹理/光栅化/Tensor Core | 硬约束=面积 3mm²(5nm), 功耗 500mW, 频率 2.5GHz | 阶段=stageA

---

## 纹理采样单元配置回答

**苏启辰**：

你提到 stage0 没有覆盖纹理采样单元的配置，这里先补上。

### 纹理 Cache 结构

| 层级 | 配置 | 容量 | 关联度 | 说明 |
|------|------|------|--------|------|
| **L1 Texture Cache** | 每 sub-partition 独立 | 16KB | 4-way | 本地缓存，减少 L2 访问 |
| **L2 Texture Cache** | Shader Core 共享 | 256KB | 8-way | 4 个 sub-partition 共享 |
| **Texture Request Queue** | 每 Texture Unit | 32 entries | - | 缓存未命中请求 |

**L1 Texture Cache 设计要点**：
- 行大小 64B（一个 cache line 恰好容纳一个 4x4 RGBA FP16 纹素块）
- 支持 LRU 替换策略
- 写策略：只读（纹理数据由 L2/显存写入，L1 不回写）
- 支持纹理压缩（BC/ASTC 格式解压在 L2 侧完成）

**L2 Texture Cache 设计要点**：
- 行大小 64B，与 L1 对齐
- 支持 interleaved bank 访问（4 banks），隐藏访问延迟
- 合并请求：同一 cache line 的多个请求合并为一次 L2 访问

### 采样并发度

| 参数 | 配置 | 说明 |
|------|------|------|
| **Texture Unit 数量** | 每 sub-partition 2 个 | 共 8 个 Texture Unit |
| **每 Unit 并发请求数** | 16 outstanding requests | 支持延迟隐藏 |
| **每 Unit 采样吞吐** | 1 bilinear sample/cycle | 双线性插值 |
| **总采样吞吐** | 8 samples/cycle | 8 个 Texture Unit 并行 |
| **地址计算** | 每 Unit 1 次/cycle | 纹理坐标 → 物理地址 |
| **数据返回** | 每 Unit 4 texels/cycle | 2x2 bilinear 采样块 |

### 纹理采样流水线

| 阶段 | 功能 | 延迟 |
|------|------|------|
| Stage 0 | 纹理坐标计算（地址计算单元） | 1 cycle |
| Stage 1 | L1 Cache 查找 | 1 cycle |
| Stage 2 | L1 命中判断 + 格式解压 | 1 cycle |
| Stage 3 | 双线性插值 / 各向异性过滤 | 1-4 cycles |
| Stage 4 | 结果格式转换 + 写回寄存器文件 | 1 cycle |

**总延迟**：5-8 cycles（L1 命中时），20-40 cycles（L1 未命中，需访问 L2）

### 纹理单元面积预估

| 组件 | 面积（5nm） | 说明 |
|------|------------|------|
| L1 Texture Cache（8 个） | 0.08mm² | 8 x 16KB x 4-way |
| L2 Texture Cache（1 个） | 0.12mm² | 256KB x 8-way |
| Texture Unit 逻辑（8 个） | 0.06mm² | 地址计算 + 插值 + 格式转换 |
| Texture Request Queue | 0.02mm² | 8 x 32 entries |
| **合计** | **0.28mm²** | 占面积约束 9.3% |

**数据说明**：纹理单元面积 0.28mm²，加上之前估算的寄存器文件 0.55mm²、Tensor Core 0.2mm²、Warp Scheduler 0.15mm²，已用面积约 1.18mm²，留给 SIMD 执行单元、光栅化、控制逻辑约 1.82mm²，预算充足。

---

## stageA 四个核心问题

### 问题 1：SoC 接口确认

stage0 已确认 Shader Core 位于 GPU 计算单元，上游是命令处理器，下游是 L2 缓存/显存控制器。现在需要细化接口：

**Shader Core 与外部模块的接口带宽需求是多少？**

| 接口 | 方向 | 候选配置 | 说明 |
|------|------|----------|------|
| **命令接口** | 输入 | APB/自定义寄存器接口 | 命令处理器 → Shader Core |
| **数据接口** | 双向 | AXI4 256-bit / 512-bit | Shader Core ↔ L2/显存 |
| **共享内存接口** | 双向 | 专用端口 256-bit | 多 Shader Core 间共享数据 |

**候选方案**：

| 方案 | 数据接口宽度 | 带宽@2.5GHz | 面积开销 |
|------|-------------|-------------|----------|
| **A：256-bit AXI4** | 256-bit | 80 GB/s | +0.05mm² |
| **B：512-bit AXI4** | 512-bit | 160 GB/s | +0.08mm² |
| **C：自定义接口** | 可配置 | 可配置 | +0.03mm² |

**我的建议**：方案 B（512-bit AXI4），理由：
- 128-wide SIMD 每周期读取 128 x 4B = 512B 数据，需要高带宽
- 纹理采样单元的突发访问也需要充足带宽
- 512-bit @ 2.5GHz 提供 160 GB/s 带宽，满足 4 个 sub-partition 并发访问

请确认接口方案，或者你有其他考虑？

---

### 问题 2：核心功能细化

stage0 确认了四大功能模块（SIMD + 纹理 + 光栅化 + Tensor Core）。现在需要确认两个细节：

**2a. 光栅化后端的职责范围**

光栅化后端在 Shader Core 内部的职责：

| 方案 | 职责 | 说明 |
|------|------|------|
| **A：片段处理** | 仅负责片段着色（Fragment Shader） | 三角形 setup 和光栅化在外部 |
| **B：片段+深度** | 片段着色 + 深度测试 + 模板测试 | 完整的像素输出流水线 |
| **C：全功能** | 片段着色 + 深度/模板 + 混合（Blend）+ 输出合并 | 类似 NVIDIA 的 ROP |

**我的建议**：方案 B（片段+深度），理由：
- 深度/模板测试与片段着色紧密耦合，放在一起减少数据搬运
- 混合（Blend）操作通常在 ROP 中完成，ROP 一般在 Shader Core 外部
- 三角形 setup 和光栅化（扫描转换）也在外部，Shader Core 只接收片段

**2b. Shader Core 支持的着色器类型**

| 着色器类型 | 是否支持 | 说明 |
|-----------|----------|------|
| Vertex Shader | 是 | 顶点变换 |
| Fragment/Pixel Shader | 是 | 像素着色 |
| Compute Shader | 是 | 通用计算 |
| Geometry Shader | 可选 | 几何变换 |
| Tessellation | 可选 | 曲面细分 |
| Mesh Shader | 可选 | 现代 GPU 新增 |

请确认光栅化后端的职责范围和支持的着色器类型。

---

### 问题 3：PPA 优先级确认

stage0 已确认"性能 > 功耗 > 面积"的优先级。现在需要量化确认：

**已确认的硬约束**：

| 约束项 | 约束值 | 来源 |
|--------|--------|------|
| 面积 | 3mm²（5nm） | 用户提供 |
| 功耗 | 500mW | 用户提供 |
| 频率 | 2.5GHz | 场景上下文 |
| 工艺 | 5nm | 场景上下文 |

**需要确认的 PPA 目标**：

| 指标 | 候选目标 | 说明 |
|------|----------|------|
| **SIMD 吞吐** | 128 FP32 ops/cycle | 128 lanes x 1 FP32 |
| **Tensor Core 吞吐** | 512 FP16 ops/cycle | 16x16 x 2（乘累加） |
| **纹理吞吐** | 8 texels/cycle | 8 Texture Units |
| **寄存器文件延迟** | 1 cycle | Operand Collector 命中 |
| **L1 Cache 命中延迟** | 1 cycle | 数据 Cache |
| **L2 Cache 命中延迟** | 10-20 cycles | 共享 L2 |

请确认这些 PPA 目标是否合理，或者你有其他指标要求？

---

### 问题 4：关键约束确认

**4a. Warp 数量与面积权衡**

根据面积约束 3mm²，我做了一个粗略的面积预算分配：

| 子模块 | 面积预估（5nm） | 占比 |
|--------|----------------|------|
| 寄存器文件 + Operand Collector | 0.55mm² | 18.3% |
| SIMD 执行单元（4x32-wide） | 0.8mm² | 26.7% |
| Tensor Core | 0.2mm² | 6.7% |
| 纹理单元 + Cache | 0.28mm² | 9.3% |
| Warp Scheduler + 记分板 | 0.15mm² | 5.0% |
| 光栅化后端 | 0.15mm² | 5.0% |
| 控制逻辑 + 指令 Cache | 0.3mm² | 10.0% |
| 接口 + 互联 | 0.2mm² | 6.7% |
| **预留裕量** | **0.37mm²** | **12.3%** |
| **合计** | **3.0mm²** | **100%** |

基于这个预算，64 warps 的寄存器文件面积 0.55mm² 可以接受。如果功耗超出预算，可以考虑减少到 48 或 32 warps。

**请确认 64 warps 的配置是否可行？**

**4b. 功耗预算分配**

| 子模块 | 功耗预估（5nm, 2.5GHz） | 占比 |
|--------|------------------------|------|
| SIMD 执行单元 | 150mW | 30% |
| 寄存器文件 | 80mW | 16% |
| Tensor Core | 60mW | 12% |
| 纹理单元 | 50mW | 10% |
| Cache（L1+L2） | 60mW | 12% |
| Warp Scheduler + 控制 | 40mW | 8% |
| 接口 + 互联 | 30mW | 6% |
| **预留裕量** | **30mW** | **6%** |
| **合计** | **500mW** | **100%** |

功耗预算 500mW 在 5nm/2.5GHz 下比较紧张。如果实际功耗超出，可能需要降低频率或减少 warp 数量。

**请确认功耗预算是否可以调整？**

---

## 待确认清单

| # | 问题 | 候选方案 | 优先级 |
|---|------|----------|--------|
| 1 | 数据接口宽度 | 256-bit / 512-bit / 自定义 | High |
| 2a | 光栅化后端职责 | 片段处理 / 片段+深度 / 全功能 | High |
| 2b | 着色器类型 | 必选+可选列表 | Medium |
| 3 | PPA 目标量化 | SIMD/TC/纹理/Cache 吞吐和延迟 | High |
| 4a | Warp 数量 | 64（默认）/ 48 / 32 | High |
| 4b | 功耗预算 | 500mW（默认）/ 可调整？ | Medium |

---

---

### 轮 7（用户确认回复）

**用户确认结果**：

| # | 问题 | 用户选择 | 备注 |
|---|------|----------|------|
| 1 | 数据接口宽度 | **方案 B：512-bit AXI4** | - |
| 2a | 光栅化后端职责 | **方案 B：片段+深度** | 混合（Blend）放外部 ROP |
| 2b | 着色器类型 | V/F/C 必选，G 可选 | Tessellation 和 Mesh Shader 暂不需要 |
| 3 | PPA 目标 | 数值合理，**Tensor Core 吞吐提升至 1024 FP16 ops/cycle** | 对标 Hopper 级别 |
| 4a | Warp 数量 | **64 warps** 确认 | - |
| 4b | 功耗预算 | **500mW 不变** | Tensor Core 功耗需多分配 |

**关键变更**：
- Tensor Core 吞吐从 512 → 1024 FP16 ops/cycle（16x16 x 4，乘累加）
- 功耗预算分配中 Tensor Core 占比需上调

## stageA 结论摘要

| # | 决策项 | 确认值 |
|---|--------|--------|
| 1 | 接口协议 | 512-bit AXI4 数据接口 + APB 命令接口 |
| 2 | 光栅化后端 | 片段着色 + 深度/模板测试，混合放外部 ROP |
| 3 | 着色器类型 | Vertex/Fragment/Compute 必选，Geometry 可选 |
| 4 | SIMD 配置 | 128-wide SIMD，4x32 sub-partition |
| 5 | Tensor Core | FP8，16x16，1024 FP16 ops/cycle |
| 6 | Warp 配置 | 64 warps，两级 Warp Scheduler |
| 7 | 面积约束 | 3mm²（5nm） |
| 8 | 功耗约束 | 500mW（Tensor Core 功耗多分配） |
| 9 | 频率 | 2.5GHz |
| 10 | 工艺 | 5nm |

## [STAGE-END] stageA 已完成，所有四个核心问题用户已确认。
