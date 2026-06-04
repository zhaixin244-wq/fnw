# GPU Shader Core PR 沟通记录索引

> 版本：v1.0
> 日期：2026-06-04
> 当前进度：stageB phase2（执行中 — 头脑风暴第2轮：性能优化）
> 已完成：stage0, stageA, stageB phase1

---

## 各阶段沟通记录

| 阶段 | 文件 | 状态 |
|------|------|------|
| stage0 | stage0.md | 已完成 |
| stageA | stageA.md | 已完成 |
| stageB phase1 | stageB_phase1.md | 已完成 |
| stageB phase2 | stageB_phase2.md | 执行中 |
| stageC phase1 | stageC_phase1.md | 待执行 |
| stageC phase2 | stageC_phase2.md | 待执行 |
| stageD | stageD.md | 待执行 |
| stageE | stageE.md | 待执行 |
| stageF | stageF.md | 待执行 |

---

## 已确认约束表

| # | 约束项 | 确认值 | 确认阶段 | 备注 |
|---|--------|--------|----------|------|
| 1 | 工艺与频率 (REQ-001) | 5nm / 2.5GHz | stageB phase1 | 用户确认 |
| 2 | 接口协议 (REQ-002) | 512-bit AXI4，标准协议 | stageB phase1 | 用户确认 |
| 3 | 数据流特征 (REQ-003) | SIMT 执行模型，128-wide SIMD | stageB phase1 | 用户确认 |
| 4 | 延迟与吞吐 (REQ-004) | 1024 FP16 ops/cycle，64 warps | stageB phase1 | 用户确认 |
| 5 | 面积与功耗 (REQ-005) | 3mm² / 500mW | stageB phase1 | 用户确认，功耗高风险 |
| 6 | 时钟与复位 (REQ-006) | 3 时钟域，异步复位同步释放 | stageB phase1 | 用户确认 |
| 7 | 低功耗 (REQ-007) | 4 独立功耗域（Core/Tensor/Texture/Raster） | stageB phase1 | 用户确认，方案 B 独立功耗域 |

---

## stageB phase2 头脑风暴新增 REQ

| REQ | 功能项 | 确认值 | 优先级 | 来源 |
|-----|--------|--------|--------|------|
| REQ-029 | Ray Tracing 单元 | 硬件加速 RT Core（光线遍历+求交+BVH） | Must | stageB phase2 轮1 功能扩展 |
| REQ-030 | Geometry Shader | 软件模拟，不硬件加速 | Could | stageB phase2 轮1 功能扩展 |
| REQ-031 | Mesh Shader | 硬件支持 Mesh/Amplification Shader | Must | stageB phase2 轮1 功能扩展 |
| REQ-032 | Programmable Blending | 可编程混合单元 | Should | stageB phase2 轮1 功能扩展 |
| REQ-033 | VRS 2.0 | 可变速率着色（2x2/4x4 tile） | Should | stageB phase2 轮1 功能扩展 |
| REQ-034 | Async Compute | 硬件级异步计算引擎（独立队列+调度） | Must | stageB phase2 轮1 功能扩展 |
| REQ-035 | Tile-Based Rendering | 不采用（桌面 GPU，TBR 无优势） | Could | stageB phase2 轮1 功能扩展，已排除 |
