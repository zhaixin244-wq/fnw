# GPU Shader Core - stageB phase2 头脑风暴沟通记录

> 模块：GPU Shader Core
> 阶段：stageB phase2（头脑风暴 Feature Discovery）
> 日期：2026-06-04

---

## [STAGE-START] stageB phase2 头脑风暴

---

## 轮 1：功能扩展维度

### 苏启辰：

**功能扩展维度分析** — GPU Shader Core 的功能扩展潜力：

**P0（Must — 竞品必备）**：
- **REQ-029: Ray Tracing 单元** — 硬件 RT Core，BVH 遍历加速，Ray-Box/Ray-Triangle 交集测试。对标 NVIDIA RTX / AMD RDNA3 RT。
- **REQ-030: Mesh Shader** — 替代传统 VS+GS 管线，支持 Meshlet 渲染，GPU 驱动几何处理。DX12 Ultimate 必备。
- **REQ-031: Async Compute** — 独立计算队列，图形/计算并行执行，提升 GPU 利用率。

**P1（Should — 差异化竞争力）**：
- **REQ-032: Programmable Blending** — 像素级可编程混合操作，支持自定义混合方程。
- **REQ-033: VRS 2.0** — Variable Rate Shading 2.0，Per-Draw + Per-Primitive 着色速率控制。

**P2（Could — 远期规划）**：
- **REQ-034: Geometry Shader** — 传统几何着色器，兼容旧引擎。
- **REQ-035: Tile-Based Rendering** — 分块渲染，降低带宽需求，移动端 GPU 核心特性。

### 用户回复：
P0 全部采纳。P1 全部采纳。P2 只采纳 Geometry Shader（兼容性需要），TBR 延后。

---

## 轮 2：性能优化维度

### 苏启辰：

**性能优化维度分析**：

**P0（Must — 性能基线）**：
- **Warp 乱序执行** — 指令级并行最大化，掩盖内存延迟
- **D-Cache 预取** — 纹理/数据预取，减少 Cache Miss
- **RF Bank 冲突优化** — Register File Bank Conflict 消除，提升 Warp 吞吐

**P1（Should — 性能增强）**：
- **I-Cache 预取** — 指令 Cache 预取，Shader 分支密集场景优化
- **SM Bank 冲突优化** — 共享内存 Bank 冲突消除
- **RT BVH 压缩** — BVH 数据压缩，减少 RT 内存占用

**P2（Could — 前沿特性）**：
- **TC FP8/INT8** — Tensor Core 支持 FP8/INT8 低精度计算，AI 推理加速

### 用户回复：
P0 全部采纳。P1 全部采纳。P2 采纳 TC FP8/INT8。

---

## 轮 3：兼容性维度

### 苏启辰：

**兼容性维度分析**：

**P0（Must — 必须兼容）**：
- **API 版本兼容** — DirectX 12 Ultimate / Vulkan 1.3+ 完整支持
- **Shader Model 兼容** — SM 6.7+ 完整支持，向下兼容 SM 5.0
- **指令集兼容** — 通用计算指令集（OpenCL/CUDA 兼容子集）

**P1（Should — 应尽量兼容）**：
- **驱动 ABI 稳定性** — 驱动接口二进制兼容，版本升级不破坏现有应用
- **内存模型兼容** — Vulkan Memory Model 兼容，多线程内存一致性
- **精度兼容** — IEEE 754 浮点精度，与竞品计算结果一致

**P2（Could — 可选兼容）**：
- **调试接口兼容** — PIX / RenderDoc 等主流调试工具兼容

### 用户回复：
P0 全部采纳。P1 全部采纳。P2 采纳调试接口兼容（PIX/RenderDoc）。

---

## 轮 4：可测试性维度

### 苏启辰：

**可测试性维度分析**：

**P0（Must — 芯片基础可测试性）**：
- **扫描链 DFT** — 全芯片扫描链插入，ATPG 向量生成，故障覆盖率 >98%
- **MBIST** — 所有 SRAM/Cache 的内建自测试，支持批量测试和维修
- **JTAG 接口** — 标准 IEEE 1149.1 JTAG，支持边界扫描和调试访问

**P1（Should — 增强可测试性）**：
- **PMU（性能监控单元）** — 硬件性能计数器，支持 Cache Miss/Warp Stall/RT 命中率等关键指标采集
- **调试断点/单步** — Shader 指令级调试，支持断点、单步执行、寄存器查看
- **错误注入** — 硬件错误注入接口，用于可靠性验证和故障恢复测试

**P2（Could — 可选增强）**：
- **覆盖率统计** — 硬件覆盖率统计单元，验证阶段必须，用于功能覆盖率收集

**P3（延后）**：
- 在线逻辑分析仪（ILA）嵌入 — 延后至后续版本

### 用户回复：
P0+P1 全部采纳。P2 只采纳覆盖率统计（验证阶段必须）。P3 延后。继续最后一个维度。

---

## 轮 5：可维护性维度（待确认）

### 苏启辰：

**可维护性维度分析** — GPU Shader Core 的长期可维护性和演进能力：

**P0（Must — 芯片生命周期可维护性）**：
- **微码可更新** — Shader Core 微码支持运行时更新，修复硬件 Bug 不需要重新流片。通过 JTAG 或驱动加载新微码。
- **错误日志持久化** — 硬件错误日志（ECC 错误、超时、死锁检测）写入非易失存储，支持事后分析。
- **热管理反馈** — 温度传感器 + 动态频率/电压调节（DVFS）接口，防止过热损坏。

**P1（Should — 运维友好性）**：
- **版本寄存器** — 硬件版本号、配置寄存器、Feature Bits 只读寄存器，驱动启动时读取以适配不同版本。
- **分区隔离** — Shader Core 内部分区（如 SM 分区）支持独立关断/降频，故障分区可隔离不影响整体。
- **遥测接口** — 运行时状态（温度、功耗、错误计数）通过标准接口上报，支持远程监控。

**P2（Could — 演进友好性）**：
- **可扩展总线架构** — 内部总线（如 AXI/自定义）预留扩展槽位，未来可挂载新子模块而不改动已有互联。
- **配置可编程** — 关键参数（如 Warp 大小、Cache 策略、仲裁权重）通过寄存器配置，同一 RTL 可适配不同产品线。

**P3（延后）**：
- 自修复机制（BISR/BIRA） — 片上 SRAM 冗余行自动修复，延后至下一代。

### 确认问题：
请确认 P0/P1/P2/P3 的优先级分层和采纳决策。

### 用户回复：
可维护性：P0+P1 全部采纳，P2 只采纳配置可编程（产品线复用很重要），P3 延后。5 轮头脑风暴全部完成，进入 stageC 吧。

---

## 头脑风暴总结（5轮全部完成）

### 功能扩展（7项采纳）
- REQ-029: Ray Tracing 单元 (Must)
- REQ-030: Mesh Shader (Must)
- REQ-031: Async Compute (Must)
- REQ-032: Programmable Blending (Should)
- REQ-033: VRS 2.0 (Should)
- REQ-034: Geometry Shader (Could - 采纳)
- REQ-035: Tile-Based Rendering (Could - 延后)

### 性能优化（7项采纳）
- Warp 乱序执行、D-Cache 预取、RF Bank 冲突优化、I-Cache 预取、SM Bank 冲突优化、RT BVH 压缩、TC FP8/INT8

### 兼容性（8项采纳）
- API 版本、Shader Model、指令集、驱动 ABI、内存模型、精度、调试接口兼容

### 可测试性（7项采纳）
- 扫描链 DFT、MBIST、JTAG、PMU、调试断点/单步、错误注入、覆盖率统计

### 可维护性（6项采纳）
- 微码可更新、错误日志持久化、热管理反馈、版本寄存器、分区隔离、遥测接口、配置可编程

---

## [STAGE-END] stageB phase2 已完成（5轮头脑风暴全部完成）
