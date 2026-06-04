# 需求探索流程总览（chip-requirement-arch）

> 本文件是需求探索全流程的唯一流程入口，由 agent 定义文件引用。
> 各阶段详细规则在 `flow/stage{X}-detail.json` 中定义，本文件仅提供速查和全景视图。

---

## 1. 流程全景图

```
用户输入
  │
  ▼
┌─────────────┐    Read todo-mechanism.md
│  entry      │    输出代办清单
└──────┬──────┘
       │ 用户确认清单
       ▼
┌─────────────┐    输入分型
│ input_triage├──────────────────────────────────────┐
└──────┬──────┘                                      │
       │ complete: 直接核对                          │
       │ partial:  补齐                              │
       │ vague:    全量采集                           │
       ▼                                             │
┌─────────────┐    定性探索                          │
│   stage0    │    模块定位/核心功能/关键约束/初步方向 │
└──────┬──────┘                                      │
       │                                             │
       ▼                                             │
┌─────────────┐    4 个核心问题                      │
│   stageA    │    位置/功能/PPA优先级/结论确认       │
└──────┬──────┘                                      │
       │                                             │
       ▼                                             │
┌─────────────┐    28 项约束逐项确认                  │
│ stageB      │    phase1: 约束检查 → phase2: 头脑风暴│
│ phase1→phase2│   （phase1 完成后自动触发 phase2）   │
└──────┬──────┘                                      │
       │                                             │
       ▼                                             │
┌─────────────┐    矛盾检测 + 需求汇总               │
│ stageC      │    phase1: 矛盾检测 → phase2: 汇总冻结│
│ phase1→phase2│   （phase1 完成后自动触发 phase2）   │
└──────┬──────┘                                      │
       │                                             │
       ▼                                             │
┌─────────────────────────────────────────┐          │
│ stageD group1-step1: RTL 行数估算       │          │
│                                         │          │
│  ┌─── ≤3000行 ───┐  ┌─── >3000行 ───┐  │          │
│  │               │  │               │  │          │
│  ▼               │  ▼               │  │          │
│ group1-step2~    │  stageE          │  │          │
│ group5-step6     │  递归分解 ────────┼──┼──────────┘
│ （20个子阶段）    │  每个子模块       │  │
│  │               │  独立走           │  │
│  │               │  B phase2→D→F    │  │
│  │               │  │               │  │
│  ▼               │  ▼               │  │
│ ┌─────────────┐  │ ┌─────────────┐  │  │
│ │  stageF     │◄─┘ │  stageF     │◄─┘  │
│ │  顶层集成   │    │  顶层集成   │    │
│ └─────────────┘    └─────────────┘    │
└─────────────────────────────────────────┘
```

---

## 2. 各阶段速查

### stage0 ~ stageC

| 阶段 | 名称 | 目标 | 加载文件 | 输出物 |
|------|------|------|----------|--------|
| stage0 | 前置探索 | 模块在 SoC 中的角色，确认初步方向 | 无 | `flow/stage0.md` |
| stageA | 最小信息集 | 收集 4 个核心问题答案 | requirement-template.json | `flow/stageA.md` |
| stageB phase1 | 约束检查 | 逐项确认 28 个约束项 | requirement-checklist.json + stageB-detail.json + protocol-mapping.json | `flow/stageB_phase1.md` |
| stageB phase2 | 头脑风暴 | 5 维度探索追加需求 | stageB-detail.json (post_stageB_brainstorming) | `flow/stageB_phase2.md` + 追加 REQ |
| stageC phase1 | 矛盾检测 | 检测需求项之间的矛盾 | conflict-detection-rules.json + stageC-phase1-detail.json | `flow/stageC_phase1.md` |
| stageC phase2 | 需求汇总 | 输出汇总表，用户确认后冻结 | stageC-detail.json | `flow/stageC_phase2.md` + requirement_summary + trace_graph.yaml |

> **stageB phase2 强制执行规则**：stageB phase1 28 项全部确认后，**必须执行 phase2，禁止跳过**。违规处理：输出 `[PHASE-SKIP-ERROR] stageB phase2 被跳过，Agent 已停止`。

### stageD（5 groups × 20 steps）

| Group | 名称 | Steps | 输出章节 |
|-------|------|-------|----------|
| group1 | 架构规划 | step1: RTL行数估算 + step2: CBB选型 + step3: 子模块划分 | §3, §13, §3.4 |
| group2 | 数据通路 | step1: 数据通路 + step2: 流水线 + step3: 控制逻辑/FSM + step4: 性能优化 | §5.1, §5.4, §5.2-5.3, §8.1 |
| group3 | 存储与资源 | step1: SRAM + step2: FIFO + step3: 链表 + step4: 寄存器 | §11.1, §11.2, §11.3, §7.1 |
| group4 | 流控与时钟 | step1: 调度 + step2: 流控 + step3: CDC | §12.1, §12.2, §7.2 |
| group5 | 优化与可靠性 | step1: 面积 + step2: 时序 + step3: DFX + step4: 可靠性 + step5: 接口 + step6: 功耗 | §8.3, §6, §9, §10.1, §4, §10.2 |

**执行顺序**：每个 group 内部 step 按编号顺序执行（线性依赖）。group2 的 step3(控制逻辑/FSM) 在 step4(性能优化) 之前，因性能优化需参考 FSM 状态数。

**加载文件**：进入 stageD 时 Read `stageD-detail.json` + `solution-template.json`；进入每个 group 时 Read `stageD-group{N}.json`。

**可跳过 step**：group1-step2(无CBB)、group2-step2(无流水线)、group2-step4(REQ-004为Could且无明确性能要求)、group3-step1~4(无SRAM/FIFO/链表/寄存器)、group4-step1(单通道)、group4-step2(无数据流)、group4-step3(单时钟域)、group5-step3(无DFX)、group5-step6(无低功耗)。

### stageD 方案文档章节映射

> stageD 每个 step 的输出写入方案文档的对应章节。以下为完整映射：

```markdown
# {模块名} 架构方案文档

## 1. 文档信息
## 2. 修订历史
## 3. 架构概述（stageD group1-step1 + group1-step3）
## 4. 接口定义（stageD group5-step5）
## 5. 数据通路与控制逻辑（stageD group2-step1 + group2-step2 + group2-step3）
## 6. 关键时序分析（stageD group5-step2）
## 7. 寄存器定义与 CDC 方案（stageD group3-step4 + group4-step3）
## 8. PPA 预估（stageD group5-step1 + group2-step4）
## 9. DFX 设计（stageD group5-step3）
## 10.1 可靠性设计（stageD group5-step4）
## 10.2 低功耗设计（stageD group5-step6）
## 11. 存储设计（stageD group3-step1 + group3-step2 + group3-step3）
## 12. 调度与流控（stageD group4-step1 + group4-step2）
## 13. CBB 集成（stageD group1-step2）
## 14. 风险与缓解
## 15. 追溯矩阵（RTM）
```

### stageE（条件触发）

| 项目 | 说明 |
|------|------|
| 触发条件 | stageD group1-step1 估算 RTL 行数 > 3000 |
| 加载文件 | e-stage-detail.json |
| 递归深度 | 最大 5 层（超过时强制停止，标记为叶子节点，ADR 标注风险） |
| 执行流程 | 估算 → 头脑风暴确认划分 → 划分子模块 → 创建 level{N}_{name}/ 目录 → 递归直到所有叶子 ≤3000 → 逐个子模块执行 stageB phase2 ~ stageD → 全部完成 → stageF |
| 目录结构 | `<module>_work/ds/doc/pr/level1_{subA}/level2_{subA1}/outputs/+flow/` |

**stageE 返回规则**：

| 场景 | 返回条件 | 目标阶段 | 检查点 |
|------|----------|----------|--------|
| 所有叶子节点完成 | 所有子模块 `stageD_complete == true` | stageF | `all_submodules_completed == true` |
| 单个子模块完成 | 当前子模块 stageD group5-step6 完成 | 下一个子模块 | `current_submodule_completed == true` |

**子模块完成标记**（每个子模块完成后更新 todolist）：

```markdown
| 子模块 | 状态 | 完成时间 | 备注 |
|--------|------|----------|------|
| {submodule_name} | ✅ completed | {timestamp} | stageD group5-step6 已完成 |
```

**禁止行为**：
- ❌ 禁止在 stageE 完成后忘记执行 stageF
- ❌ 禁止跳过未完成的子模块
- ❌ 禁止在子模块 stageD 未完成时标记为 completed

### stageF

| 项目 | 说明 |
|------|------|
| 触发条件 | 所有子模块 stageD 完成（或 stageE 所有叶子完成） |
| 输出物 | outputs/{module}_top_integration.md + outputs/{module}_topology.png |

---

## 3. 关键决策规则

### 3.1 输入分型

| 输入类型 | 判断条件 | 后续路径 |
|----------|----------|----------|
| complete | ≥6 项约束维度且 >500 字 | stage0 → A → B phase1 核对 → C |
| partial | 2-5 项约束维度 | stage0 → A → B phase1 补齐 → C |
| vague | 仅模块名/一句话 | stage0 → A → B phase1 全量 → C |

### 3.2 RTL 行数跳转

```
stageD group1-step1 估算 RTL 总行数
  ├── ≤3000 → 继续 group1-step2 ~ group5-step6（标准流程）
  └── >3000 → 跳过 group1-step2 ~ group5-step6 → stageE 递归分解
```

### 3.3 stageD step 跳过条件

详见 `stage-definition.json` 的 `conditional_skip_rules.skippable_steps`。

---

## 4. 结构标记速查

| 标记 | 用途 | 格式 |
|------|------|------|
| `[STAGE-START]` | stage 开始 | `## [STAGE-START] stage_name` |
| `[STAGE-END]` | stage 结束 | `## [STAGE-END] stage_name` |
| `[PHASE-START]` | phase 开始 | `## [PHASE-START] stage_name phase_name` |
| `[PHASE-END]` | phase 结束 | `## [PHASE-END] stage_name phase_name` |
| `[GROUP-START]` | group 开始 | `## [GROUP-START] stageD group_name` |
| `[GROUP-END]` | group 结束 | `## [GROUP-END] stageD group_name` |
| `[STEP-START]` | step 开始 | `## [STEP-START] stageD step_name` |
| `[STEP-END]` | step 结束 | `## [STEP-END] stageD step_name` |
| `[STEP-PAUSE]` | 步进暂停 | `[STEP-PAUSE] {stage/phase/step} 已完成，等待用户确认后继续。` |
| `[DELIVERABLE-ERROR]` | 交付物缺失 | `[DELIVERABLE-ERROR] {stage/phase/step} 缺少 {文件名}` |
| `[TODOLIST-ERROR]` | todolist 不完整 | `[TODOLIST-ERROR] {level}.{模块} todolist 缺失 {内容}` |
| `[RECURSIVE-ERROR]` | 递归未执行 | `[RECURSIVE-ERROR] {模块} >3000行未继续分解` |
| `[DIR-ERROR]` | 目录缺失 | `[DIR-ERROR] {目录路径} 未创建` |
| `[PHASE-SKIP-ERROR]` | phase 被跳过 | `[PHASE-SKIP-ERROR] {stage} {phase} 被跳过` |
| `[STAGE-TRANSITION]` | 阶段跳转 | `[STAGE-TRANSITION] {源阶段} → {目标阶段}` |
| `[CONTEXT-DRIFT]` | 模块名偏移 | `[CONTEXT-DRIFT] 模块名从 {old} 偏移到 {new}` |
| `[PATH-WARNING]` | 路径偏移 | `[PATH-WARNING] 目标路径 {path} 不在工作目录 {dir} 内` |
| `[HARD-CONSTRAINT-VIOLATION]` | 硬约束违反 | `[HARD-CONSTRAINT-VIOLATION] {约束项} 预估 {值} 超出约束 {值}` |
| `[CROSS-AGENT-REQUEST]` | 越权请求 | `[CROSS-AGENT-REQUEST] 请求者/目标文件/原因/内容` |

---

## 5. 权威源声明

> 每个规则域有且仅有一个权威文件。其他文件仅可引用，不可重复定义。

| 规则域 | 权威文件 | agent 引用方式 |
|--------|----------|----------------|
| 步进模式/暂停/批量确认/调试模式 | `todo-mechanism.md` | agent 文件不重复，直接遵循 |
| 编码规则（stage/phase/group/step） | `stage-definition.json` | agent 文件不重复，直接遵循 |
| 文件加载时机 | `context-layers.json` | agent 文件不重复，直接遵循 |
| 状态转移规则 | `stage-definition.json` state_transitions | 本文件 §2 引用 |
| 流程详细规则 | `flow/stage{X}-detail.json` | 本文件 §2 引用 |
| 矛盾检测规则 | `conflict-detection-rules.json` | stageC phase1 按需加载 |
| 追溯编号规范 | `sdd-spec-traceability.md` §10.1 | agent 文件不重复 |
| 变更传播规则 | `change-propagation-v2.md` | agent 不使用，下游 agent 自行 includes |

---

## 6. 文件索引

### 配置文件（flow/*.json）

| 文件 | 用途 | 加载阶段 |
|------|------|----------|
| `stage-definition.json` | stage/phase/group/step 统一定义 + 状态转移 + 编码校验 | L1 启动 |
| `stageB-detail.json` | stageB phase1 执行规则 + phase2 头脑风暴规则 | stageB |
| `stageC-phase1-detail.json` | stageC phase1 矛盾检测执行规则 | stageC phase1 |
| `stageC-detail.json` | stageC phase2 需求汇总规则 | stageC phase2 |
| `stageD-detail.json` | stageD 元数据 + RTL 行数跳转规则 | stageD |
| `stageD-group{1-5}.json` | 各 group 内 step 详细规则 | stageD 按 group |
| `e-stage-detail.json` | stageE 递归分解详细规则 | stageE |
| `protocol-mapping.json` | 位置→协议推断映射 | stageB phase1 |
| `execution-hints.json` | 28 项约束的执行提示（hint_ref 机制） | stageB phase1 按需 |
| `conflict-detection-rules.json` | 17 条基础矛盾检测规则 | stageC phase1 |
| `conflict-detection-conditional.json` | 7 条条件矛盾检测规则 | stageC phase1 按需 |
| `conflict-detection-experimental.json` | 5 条实验矛盾检测规则 | stageC phase1 按需 |
| `reference-values.json` | 矛盾检测参考值 | stageC phase1 按需 |
| `area-estimation.json` | 面积估算参数 | stageD group5-step1 |
| `rtl-readiness-checklist.json` | RTL 就绪度检查清单 | stageD |
| `solution-template.json` | 方案文档模板 | stageD |
| `req-to-rules-mapping.json` | REQ→规则映射（增量变更用） | 变更时 |

### 共享文件

| 文件 | 用途 |
|------|------|
| `agent-common-base.md` | 交互风格 + 降级策略 + Wiki 检索 + 文件权限 |
| `todo-mechanism.md` | 步进模式 + 批量确认 + 调试模式 + 代办清单格式 |
| `sdd-spec-traceability.md` | SDD 追溯规范（§1-5 概述+追溯模型+标注+职责+检查） |
| `context-layers.json` | 上下文分层定义（L0/L1/L2/L3 + 加载序列） |
| `requirement-template.json` | 流程骨架（entry + input_triage + 各 stage 概要） |
| `requirement-checklist.json` | 28 项约束检查清单（精简版，hint_ref 引用） |
