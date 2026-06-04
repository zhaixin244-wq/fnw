# 国密/国际双模加密引擎 PR 沟通记录

> 版本：v1.0
> 日期：2026-06-04
> 阶段：已完成
> 当前进度：全部完成
> 已完成：stage0, stageA, stageB phase1, stageB phase2, stageC phase1, stageC phase2, stageD, stageE

---

## 输入分型

| 维度 | 内容 |
|------|------|
| 模块名称 | 国密/国际双模加密引擎 (crypto_engine) |
| SoC 位置 | 安全子系统 |
| 上游 | CPU/DMA（AXI） |
| 下游 | 密钥存储/安全隔离区 |
| 功能特性 | SM2/SM3/SM4 + AES/SHA/RSA、抗侧信道 |
| 优先级 | 安全性 > 性能 > 面积 |
| 工艺 | 28nm |
| 频率 | 400MHz |
| 预期 REQ 数 | 40 |

**分型结果**：partial（6项约束维度，覆盖工艺/接口/PPA/功能/安全，但未覆盖全部28项）
**后续路径**：stage0 → stageA → stageB phase1 补齐 → stageC phase1 → stageC phase2

---

## 已确认约束表

| # | 约束项 | 确认值 | 确认阶段 | 备注 |
|---|--------|--------|----------|------|
| 1 | 工艺节点 | 28nm | 输入 | - |
| 2 | 工作频率 | 400MHz | 输入 | - |
| 3 | 安全优先级 | 安全性 > 性能 > 面积 | 输入 | - |
| 4 | 抗侧信道防护 | 高级防护，DPA/SPA抵抗，过商密认证 | stage0 | - |
| 5 | 双模处理模式 | 并行处理，国密与国际算法不互相阻塞 | stage0 | - |
| 6 | AXI接口宽度 | 128bit | stage0 | - |

---

## stage0 探索记录

### 探索结论

| # | 探索项 | 结论 | 备注 |
|---|--------|------|------|
| 1 | 模块定位 | 安全子系统核心加密处理单元，负责国密+国际双模算法运算，不含密钥管理和协议处理 | 边界清晰 |
| 2 | 核心功能 | SM2/SM3/SM4（国密）+ AES/SHA/RSA（国际）+ 高级抗侧信道防护（DPA/SPA抵抗） | 功能明确 |
| 3 | 关键约束 | 安全性优先（商密认证），双模并行处理（不阻塞），128bit AXI，28nm/400MHz | 已确认 |
| 4 | 初步架构方向 | 独立双引擎方案（并行处理需求决定），共享AXI接口 | 已确认 |

### 用户确认记录

- Q1: 抗侧信道防护等级？ → A1: 高级防护，要过商密认证，DPA/SPA抵抗必须做
- Q2: 双模处理模式？ → A2: 需要并行处理，国密和国际算法同时跑，不能互相阻塞
- Q3: AXI接口宽度？ → A3: 128bit，上游DMA搬数据量大

---

## stageA 记录

| # | 问题 | 答案 | 来源 |
|---|------|------|------|
| 1 | 模块在SoC中的位置？ | 安全子系统，上游CPU/DMA（AXI 128bit），下游密钥存储/安全隔离区 | 用户输入 |
| 2 | 核心功能一句话？ | 国密SM2/SM3/SM4与国际AES/SHA/RSA双模并行加密引擎，高级抗侧信道防护 | stage0确认 |
| 3 | PPA优先级排序？ | 安全性 > 性能 > 面积 | 用户输入 |
| 4 | stage0结论确认？ | 已确认：独立双引擎架构，共享AXI接口 | stage0确认 |

---

## stageB phase1 记录

28项约束检查完成，详见 requirement_summary。

关键确认项：
- REQ-001: 28nm / 400MHz
- REQ-002: AXI4 128bit
- REQ-010: 商密认证，高级抗侧信道
- REQ-029~040: 头脑风暴追加12项

---

## stageB phase2 记录

头脑风暴5维度探索，追加12个REQ（REQ-029~REQ-040）：
- 功能扩展：SM2并行、SM3流水线、AES-GCM、KDF、TRNG
- 性能优化：多通道、流水线可配置、DMA背压
- 兼容性：SM4/AES动态切换
- 可测试性：错误注入
- 可维护性：性能计数器、密钥统计

---

## stageC phase1 记录

矛盾检测结果：
- 无矛盾：15项
- 不适用：2项（单时钟域）
- 关注项：5项（面积/并行度/资源竞争/验证复杂度）

---

## stageC phase2 记录

需求汇总表生成，40个REQ：
- Must: 9项
- Should: 20项
- Could: 6项
- N/A: 5项

---

## stageD 记录

RTL行数估算：7050行 > 3000行阈值，进入stageE递归分解。

子模块分组：
- 国密引擎组：SM2/SM3/SM4（1900行）
- 国际引擎组：AES/SHA/RSA（1900行）
- 公共模块组：AXI/APB/Scheduler/KeyMgr/SideChannel/IRQ/Perf（2850行）

方案文档：crypto_engine_solution_v1.0.md
ADR文档：crypto_engine_ADR_v1.0.md

---

## 交付物清单

| 文件 | 路径 | 说明 |
|------|------|------|
| PR沟通记录 | flow/crypto_engine_pr_v1.0.md | 本文档 |
| 需求汇总表 | outputs/crypto_engine_requirement_summary_v1.0.md | 40个REQ |
| 方案文档 | outputs/crypto_engine_solution_v1.0.md | 架构方案 |
| ADR文档 | outputs/crypto_engine_ADR_v1.0.md | 6个架构决策 |
| 追溯图 | outputs/crypto_engine_trace_graph.yaml | 需求追溯 |
