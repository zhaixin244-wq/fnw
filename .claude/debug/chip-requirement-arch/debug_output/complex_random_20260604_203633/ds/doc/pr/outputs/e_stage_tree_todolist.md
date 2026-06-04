# E 阶段树形 Todolist - GPU Shader Core

> 本文件是 E 阶段递归分解的执行指南。Agent 必须按本文件定义的流程和顺序逐步执行。
> v6.6：多级递归（直到 <3000 行），逐级 todolist 跟踪，todolist 强制执行。

---

## 1. 递归分解结果

| ID | 名称 | 层级 | 父节点 | 预估行数 | 状态 | 执行顺序 | 依赖 | 全局 REQ | 本地 REQ |
|----|------|------|--------|----------|------|----------|------|----------|----------|
| 0 | GPU Shader Core（顶层） | L0 | - | 12900 | completed | 0 | - | REQ-001~REQ-035 | - |
| 1 | sm_core | L1 | 顶层 | 2800 | pending | 1 | - | REQ-003,REQ-004 | 待分配 |
| 2 | rt_core | L1 | 顶层 | 1200 | pending | 2 | 1 | REQ-029 | 待分配 |
| 3 | mesh_shader | L1 | 顶层 | 900 | pending | 3 | 1 | REQ-030 | 待分配 |
| 4 | async_compute | L1 | 顶层 | 900 | pending | 4 | 1 | REQ-031 | 待分配 |
| 5 | warp_scheduler | L1 | 顶层 | 1000 | pending | 5 | 1 | REQ-003,REQ-004 | 待分配 |
| 6 | register_file | L1 | 顶层 | 500 | pending | 6 | 1,5 | REQ-003 | 待分配 |
| 7 | shared_memory | L1 | 顶层 | 400 | pending | 7 | 1 | REQ-003 | 待分配 |
| 8 | cache_subsystem | L1 | 顶层 | 2500 | pending | 8 | 1,2,3,4 | REQ-016,REQ-020 | 待分配 |
| 9 | axi_interface | L1 | 顶层 | 700 | pending | 9 | 8 | REQ-002 | 待分配 |
| 10 | cdc_module | L1 | 顶层 | 300 | pending | 10 | - | REQ-006,REQ-011 | 待分配 |
| 11 | power_manager | L1 | 顶层 | 300 | pending | 11 | - | REQ-005,REQ-007 | 待分配 |
| 12 | dft_wrapper | L1 | 顶层 | 500 | pending | 12 | - | REQ-012 | 待分配 |
| 13 | ecc_encoder | L1 | 顶层 | 400 | pending | 13 | 6,7,8 | REQ-009 | 待分配 |
| 14 | debug_pmu | L1 | 顶层 | 400 | pending | 14 | - | REQ-013,REQ-014 | 待分配 |
| 15 | top_ctrl | L1 | 顶层 | 800 | pending | 15 | 1,5 | REQ-001,REQ-004 | 待分配 |

**状态说明**：pending -> in_progress -> completed -> skipped
**递归终止**：所有叶子节点预估行数 <3000（本次无需递归，全部为 L1 叶子节点）

---

## 2. 父模块上下文摘要

### 2.1 模块定位
GPU Shader Core 是 SoC 中的着色器计算核心，负责顶点/像素/计算着色器执行、光线追踪加速、Mesh Shader 处理。

### 2.2 关键约束（继承自 L0）

| 约束项 | 值 | 来源 |
|--------|-----|------|
| 工艺节点 | 5nm | REQ-001（Frozen） |
| 工作频率 | 2.5GHz | REQ-001（Frozen） |
| 接口协议 | AXI4 512-bit | REQ-002（Frozen） |
| 面积约束 | 3mm²（Target） | REQ-005（Frozen） |
| 功耗约束 | 500mW | REQ-005（Frozen） |
| 时钟域 | 3 个（core/uncore/axi） | REQ-006（Frozen） |
| 功耗域 | 4 个独立域 | REQ-007 |
| SIMD 宽度 | 128-wide，4x32 sub-partition | REQ-003 |
| 管线深度 | ≤10 cycles | REQ-004 |
| 内存带宽 | ≥51.2 GB/s | REQ-016 |

### 2.3 架构方案
混合式架构：集中式核心控制 + 分布式加速器（RT Core / Mesh Shader / Async Compute 独立运行）。

---

## 3. 子模块接口契约

### 3.1 子模块间关键接口

| 源 | 目标 | 接口 | 位宽 | 协议 | 说明 |
|----|------|------|------|------|------|
| sm_core | register_file | rf_rd/wr | 128x32b | 自定义 | RF 读写端口 |
| sm_core | shared_memory | sm_rd/wr | 128x32b | 自定义 | SM 访问 |
| warp_scheduler | sm_core | warp_issue | - | 自定义 | Warp 指令发射 |
| rt_core | cache_subsystem | rt_l2_req/rsp | 512b | 自定义 | RT L2 访问 |
| mesh_shader | cache_subsystem | mesh_l2_req/rsp | 512b | 自定义 | Mesh L2 访问 |
| async_compute | cache_subsystem | comp_l2_req/rsp | 512b | 自定义 | 计算 L2 访问 |
| cache_subsystem | axi_interface | axi_req/rsp | 512b | AXI4 | 外部内存访问 |
| top_ctrl | 全部 | ctrl/status | - | 自定义 | 顶层控制 |

### 3.2 时钟域映射

| 子模块 | 时钟域 | 说明 |
|--------|--------|------|
| sm_core | clk_core | 核心时钟域 2.5GHz |
| rt_core | clk_core | 核心时钟域 |
| mesh_shader | clk_core | 核心时钟域 |
| async_compute | clk_core | 核心时钟域 |
| warp_scheduler | clk_core | 核心时钟域 |
| register_file | clk_core | 核心时钟域 |
| shared_memory | clk_core | 核心时钟域 |
| cache_subsystem | clk_core + clk_uncore | 双时钟域（L1 core / L2 uncore） |
| axi_interface | clk_axi | AXI 时钟域 |
| cdc_module | 全部 | CDC 同步器 |
| power_manager | clk_uncore | uncore 时钟域 |
| dft_wrapper | clk_core | 核心时钟域 |
| ecc_encoder | clk_core | 核心时钟域 |
| debug_pmu | clk_uncore | uncore 时钟域 |
| top_ctrl | clk_uncore | uncore 时钟域 |

---

## 4. 继承约束链

| 约束项 | L0 值 | L1 继承方式 | 说明 |
|--------|-------|------------|------|
| 频率 2.5GHz | REQ-001 | 所有 clk_core 子模块直接继承 | 5nm 工艺可达 |
| 面积 3mm² | REQ-005 | 各子模块面积预算分配（见 stageD group1-step1 §6） | 总计 3.04mm² |
| 功耗 500mW | REQ-005 | 各子模块功耗预算分配 | 需 Clock Gating |
| AXI4 512-bit | REQ-002 | axi_interface 直接继承 | 其他子模块通过 cache 间接 |
| ECC SECDED | REQ-009 | ecc_encoder 负责 | RF/SM/Cache 保护 |
| 3 时钟域 | REQ-006 | cdc_module 负责同步 | core/uncore/axi |
| 4 功耗域 | REQ-007 | power_manager 负责控制 | PG + CG |

---

## 5. 子模块 flow 定义

> **铁律：子模块必须严格按本级 todolist 定义的 flow 执行。缺失则报错停止。**

| 子模块 ID | 名称 | 必须执行的 flow | 交付文件 |
|-----------|------|----------------|----------|
| 1 | sm_core | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 2 | rt_core | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 3 | mesh_shader | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 4 | async_compute | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 5 | warp_scheduler | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 6 | register_file | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 7 | shared_memory | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 8 | cache_subsystem | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 9 | axi_interface | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 10 | cdc_module | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 11 | power_manager | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 12 | dft_wrapper | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 13 | ecc_encoder | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 14 | debug_pmu | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 15 | top_ctrl | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |

**todolist 完整性检查**：每个子模块必须有明确的 flow 定义和交付文件清单。缺失 -> [TODOLIST-ERROR] -> 停止执行。

---

## 6. 交付文件内容模板

### 6.1 outputs/ 目录（每个子模块 5 个文件）

| # | 文件 | 命名 | 说明 |
|---|------|------|------|
| 1 | PR 沟通记录 | `{name}_pr_v1.0.md` | 完整 stageB phase2~stageD 沟通记录 |
| 2 | 需求汇总表 | `{name}_requirement_summary_v1.0.md` | REQ 汇总（从父模块同步 + 本地新增） |
| 3 | 方案文档 | `{name}_solution_v1.0.md` | §3~§14 完整方案 |
| 4 | ADR 文档 | `{name}_ADR_v1.0.md` | Nygard 格式架构决策 |
| 5 | 追溯图 | `{name}_trace_graph.yaml` | L1 节点追溯 |

### 6.2 flow/ 目录（每个子模块 4 个文件）

| # | 文件 | 说明 |
|---|------|------|
| 1 | `stageB_phase2.md` | 头脑风暴 Feature Discovery（必须） |
| 2 | `stageC_phase1.md` | 矛盾检测 |
| 3 | `stageC_phase2.md` | 需求确认汇总 |
| 4 | `stageD.md` | 方案细化（D0~D14） |

---

## 7. Wiki 知识库参考

| 子模块 | 相关 Wiki 页面 | 说明 |
|--------|---------------|------|
| sm_core | SIMD 架构、ALU 设计 | 128-wide 数据通路 |
| rt_core | BVH 遍历、Ray 交集 | 光线追踪硬件 |
| mesh_shader | Meshlet 渲染 | 图元处理 |
| warp_scheduler | Warp 调度、记分板 | 指令级并行 |
| cache_subsystem | 多级缓存、一致性 | 缓存层次设计 |
| axi_interface | AXI4 协议 | 总线接口 |
| cdc_module | CDC 设计模式 | 跨时钟域 |
| ecc_encoder | SECDED 编码 | 纠错编码 |

---

## 8. 质量门控检查清单

| # | 检查项 | 方法 | 阻断条件 |
|---|--------|------|----------|
| 1 | 目录结构存在 | ls 检查 | 缺失 -> 阻断 |
| 2 | 每个子模块 5 文件齐全 | find 检查 | <3 -> 阻断 |
| 3 | REQ 编号连续无跳号 | grep 检查 | 跳号 -> 阻断 |
| 4 | stageB_phase2.md 存在 | ls 检查 | 缺失 -> 阻断 |
| 5 | 规格自检 5 项通过 | 逐项检查 | 未通过 -> 阻断 |
| 6 | 全部 completed | 状态检查 | pending -> 阻断 |

---

## 9. 执行进度跟踪

| 层级 | 模块 | 总数 | completed | in_progress | pending | 进度 |
|------|------|------|-----------|-------------|---------|------|
| L0 | 顶层 | 1 | 1 | 0 | 0 | 100% |
| L1 | 子模块 | 15 | 0 | 0 | 15 | 0% |
| **全局** | **所有** | **16** | **1** | **0** | **15** | **6%** |

---

## 10. 执行顺序建议

按依赖关系排序的推荐执行顺序：

**第一批（无依赖，可并行）**：
1. sm_core（ID=1）- 核心数据通路，其他模块依赖
10. cdc_module（ID=10）- CDC 同步器，独立
11. power_manager（ID=11）- 功耗管理，独立
12. dft_wrapper（ID=12）- DFT 逻辑，独立
14. debug_pmu（ID=14）- 调试/PMU，独立

**第二批（依赖 sm_core）**：
5. warp_scheduler（ID=5）- 依赖 sm_core
6. register_file（ID=6）- 依赖 sm_core + warp_scheduler
7. shared_memory（ID=7）- 依赖 sm_core

**第三批（依赖 sm_core + cache）**：
2. rt_core（ID=2）- 依赖 sm_core
3. mesh_shader（ID=3）- 依赖 sm_core
4. async_compute（ID=4）- 依赖 sm_core

**第四批（缓存子系统）**：
8. cache_subsystem（ID=8）- 依赖多个上游

**第五批（接口和顶层）**：
9. axi_interface（ID=9）- 依赖 cache_subsystem
13. ecc_encoder（ID=13）- 依赖 RF/SM/Cache
15. top_ctrl（ID=15）- 最后执行，依赖全部

---

## 11. todolist 完整性自检

| # | 检查项 | 状态 |
|---|--------|------|
| 1 | S1 递归分解结果表格完整 | PASS |
| 2 | S2 父模块上下文摘要存在 | PASS |
| 3 | S3 子模块接口契约定义完整 | PASS |
| 4 | S4 继承约束链明确 | PASS |
| 5 | S5 子模块 flow 定义完整（15 个） | PASS |
| 6 | S6 交付文件模板存在 | PASS |
| 7 | S7 Wiki 参考已列出 | PASS |
| 8 | S8 质量门控清单完整 | PASS |
| 9 | S9 执行进度跟踪已初始化 | PASS |
| 10 | S10 自检通过 | PASS |

**自检结论**：todolist 完整，可进入子模块执行阶段。
