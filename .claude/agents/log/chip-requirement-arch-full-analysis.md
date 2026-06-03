# chip-requirement-arch 全文件深度分析报告（v2）

> 分析日期：2026-06-03
> 分析范围：Agent 定义 + 4 个 includes + 15 个引用 JSON/MD + 示例 + 评估标准 + 变更日志 + 成员档案
> 分析方法：逐文件精读，交叉验证，数字/规则一致性全量扫描
> 前版参考：chip-requirement-arch-analysis.md（v1），本报告在前版基础上修正误判、补充遗漏

---

## 一、文件清单与依赖图

### 1.1 全量文件清单（23 个）

| # | 文件 | 版本 | Token 估算 | 加载层 | 角色 |
|---|------|------|-----------|--------|------|
| 1 | `agents/chip-requirement-arch.md` | v12.0 | ~4K (L0) | 常驻 | Agent 主定义 |
| 2 | `shared/agent-common-base.md` | - | ~2K | includes | 公共基座 |
| 3 | `shared/todo-mechanism.md` | - | ~1.2K | includes | 代办清单 |
| 4 | `shared/sdd-spec-traceability.md` | - | ~3K | includes | SDD 追溯 |
| 5 | `shared/change-propagation-v2.md` | - | ~2.5K | includes | 变更传播 |
| 6 | `shared/context-layers.json` | v1.0 | ~0.5K | L1 | 上下文分层 |
| 7 | `shared/requirement-template.json` | v1.3 | ~1.4K | L1 | 流程骨架 |
| 8 | `shared/flow/stage-definition.json` | v1.0 | ~1.0K | L1 | 编码规则 |
| 9 | `shared/requirement-checklist.json` | v1.3 | ~1.9K | L2 stageB | 28 项约束 |
| 10 | `shared/flow/stageB-detail.json` | v1.3 | ~2.5K | L2 stageB | B 阶段规则 |
| 11 | `shared/flow/execution-hints.json` | v1.4 | ~1.5K | L2 stageB | 执行提示 |
| 12 | `shared/flow/protocol-mapping.json` | v1.0 | ~0.5K | L2 stageB | 协议映射 |
| 13 | `shared/conflict-detection-rules.json` | v1.5 | ~3.5K | L2 stageC | 矛盾检测 |
| 14 | `shared/flow/stageC-phase1-detail.json` | v1.3 | ~0.5K | L2 stageC | C1 详细规则 |
| 15 | `shared/flow/stageC-detail.json` | v1.3 | ~0.7K | L2 stageC | C2 详细规则 |
| 16 | `shared/flow/stageD-detail.json` | v2.0 | ~4K | L2 stageD | D 阶段规则 |
| 17 | `shared/solution-template.json` | v1.3 | ~1.5K | L2 stageD | 方案模板 |
| 18 | `shared/flow/area-estimation.json` | v1.0 | ~1.0K | L2 stageD | 面积估算 |
| 19 | `shared/flow/e-stage-detail.json` | v2.0 | ~5K | L2 stageE | 递归分解 |
| 20 | `agents/examples/chip-requirement-arch-stage0-C-example.md` | - | ~2K | 按需 | 示例对话 |
| 21 | `evaluation_criteria/chip-requirement-arch-eva.md` | v6.0 | ~4K | 按需 | 评估标准 |
| 22 | `agents/log/chip-requirement-arch-changelog.md` | - | ~1.5K | 按需 | 变更日志 |
| 23 | `doc/member/01_苏启辰_chip-requirement-arch.md` | - | ~0.5K | 按需 | 成员档案 |

**总 Token 预算**：L0 ~4K + includes ~8.7K + L1 ~2.9K + L2 ~16.6K = **~32.2K**（不含按需文件）

### 1.2 依赖关系图

```
chip-requirement-arch.md (主定义)
├── includes:
│   ├── agent-common-base.md (交互/降级/Wiki/权限)
│   ├── todo-mechanism.md (步进/调试模式)
│   ├── sdd-spec-traceability.md (L1~L11 追溯)
│   └── change-propagation-v2.md (全链路变更)
├── L1 启动层:
│   ├── context-layers.json
│   ├── requirement-template.json
│   │   └── references: stageB-detail.json, stageC-phase1-detail.json,
│   │                   stageC-detail.json, stageD-detail.json, solution-template.json
│   └── stage-definition.json
│       └── references: stageB-detail.json, stageD-detail.json, e-stage-detail.json
├── L2 stageB:
│   ├── requirement-checklist.json → execution-hints.json
│   ├── stageB-detail.json → grey_expression_system (自含)
│   └── protocol-mapping.json
├── L2 stageC:
│   ├── conflict-detection-rules.json → conflict-detection-conditional.json
│   │                                 → conflict-detection-experimental.json
│   │                                 → reference-values.json
│   ├── stageC-phase1-detail.json → coverage-model.json → end-to-end-coverage-report.json
│   └── stageC-detail.json
├── L2 stageD:
│   ├── stageD-detail.json → stageD-group{1-5}.json (按需)
│   │                      → specialist-orchestration.json
│   │                      → rtl-readiness-checklist.json
│   ├── solution-template.json → area-estimation.json
│   │                          → arch-review-rules.json → arch-review/*.json
│   └── (wiki/index.md — 头脑风暴前检索)
├── L2 stageE:
│   └── e-stage-detail.json → todolist_template.md
└── 辅助:
    ├── examples/chip-requirement-arch-stage0-C-example.md
    ├── evaluation_criteria/chip-requirement-arch-eva.md
    ├── agents/log/chip-requirement-arch-changelog.md
    └── doc/member/01_苏启辰_chip-requirement-arch.md
```

---

## 二、逐文件深度分析

### 2.1 Agent 主定义（chip-requirement-arch.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 角色定义、三条铁律、编码规则速查表清晰 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | L0/L1/L2 分层设计优秀，token 预算控制到位 |
| LLM 歧义 | ⚠️ 中等 | 3 个歧义点 |

**歧义点**：

| # | 问题 | 严重度 | 说明 |
|---|------|--------|------|
| A-01 | stageB phase2 追加 REQ 的文件创建时机 | 🔴 高 | §文件写入时机表：stageB phase2 写 `outputs/{module}_requirement_summary_v1.0.md`（创建），stageC phase2 也写同一文件（追加确认/冻结标记）。但 stageB-detail.json 的 `blocking_rule` 说"未写入 requirement_summary 的 REQ 不得进入 stageC phase1"。**语义矛盾**：stageB phase2 是创建文件还是追加到已存在的文件？ |
| A-02 | DFX vs DFT 混用 | 🟡 中 | §L2 阶段层注入内容表：stageD group5-step3 = "DFT 设计"。但 stage-definition.json 写 "DFX 设计"，stageD-detail.json 也写 "DFX"。**同一子阶段两个名称**。 |
| A-03 | output/ vs outputs/ 路径前缀 | 🟡 中 | §文件写入时机表用 `output/{module}_...`（无 s），但 e-stage-detail.json 和评估标准都用 `outputs/`（有 s）。**路径不一致导致文件查找失败**。 |

---

### 2.2 公共基座（agent-common-base.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 四章职责分明 |
| 结构化 | ⭐⭐⭐⭐ (4/5) | 降级策略表、Wiki 检索三阶段定义明确 |
| LLM 歧义 | ⚠️ 低 | 1 个边界条件 |

**歧义点**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-04 | Wiki 检索铁律的边界条件 | 🟢 低 | §三说"涉及协议/接口/CBB/选型/编码前必须先完成 Wiki 检索"，但 stage0/stageA 尚未确定具体协议。§三补充了"stage0/stageA 的定性探索不受此约束"，但这个例外条款在铁律正文之后，**LLM 可能先看到铁律就执行，忽略后续例外**。 |

---

### 2.3 代办清单（todo-mechanism.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐⭐ (5/5) | 步进/调试模式区分清晰 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 清单格式模板标准化 |
| LLM 歧义 | ✅ 极低 | 无明显歧义 |

**与 requirement-template.json 的潜在冲突**：见 §三 C-07。

---

### 2.4 SDD 追溯规范（sdd-spec-traceability.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 全链路追溯模型清晰 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 12 章层次分明 |
| LLM 歧义 | ⚠️ 低 | 1 个不一致 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-05 | REQ 扩展规则仅在追溯规范定义 | 🟢 低 | §10.1 L1 层写"REQ-{NNN}（三位数字，001~999。超过 999 时扩展为 REQ-{NNNN}）"。但主定义 §SDD 编号规范仅写"REQ-XXX（三位数字）"，**未提及扩展规则**。Agent 在主定义中看到的规则不含扩展，可能在 >999 时不知所措。 |

---

### 2.5 变更传播（change-propagation-v2.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 传播树状图直观 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 7 章覆盖全链路 |
| LLM 歧义 | ⚠️ 低 | 1 个量化缺失 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-06 | "PPA 指标大幅调整"未量化 | 🟢 低 | §2.1 REQ 阶段变更表：修改 PPA 指标（>20%）标为 Critical。但 §3.3 影响分析规则中"PPA 指标大幅调整"标为 Critical 却**未给出阈值**。两处定义同一概念但量化标准不一致。 |

---

### 2.6 context-layers.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐⭐ (5/5) | 分层架构定义精确 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | JSON 结构规范 |
| LLM 歧义 | ✅ 极低 | 无 |

---

### 2.7 requirement-template.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 流程骨架完整 |
| 结构化 | ⭐⭐⭐⭐ (4/5) | 各 stage 有 trigger/output/transition |
| LLM 歧义 | ⚠️ 中等 | 2 个歧义点 |

**歧义点**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-07 | input_triage "≥6项约束维度"判定标准不明确 | 🟡 中 | 用户输入中提及的不同约束类别数？还是 requirement-checklist.json 中的 seq 编号？**LLM 无法精确判定**。 |
| A-08 | exception_handling "用户跳过确认直接出方案" 与步进模式冲突 | 🟡 中 | `force_completion: true` 行为（列出未确认项 → 标注假设 → 暂停要求确认）本质上仍是步进模式的变体，但字段名 `force_completion` 暗示"强制完成"，**语义误导**。已在 v12.0 中修正为"步进模式，禁止强制完成"，但字段名未改。 |

---

### 2.8 stage-definition.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐⭐ (5/5) | 统一编码规则是核心改进 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 校验正则精确 |
| LLM 歧义 | ⚠️ 低 | 1 个历史遗留 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-09 | old_to_new_mapping D1/D2 重叠映射 | 🟢 低 | D1→"group1-step3 / group2-step1"，D2→"group2-step1 / group2-step4"。旧 D1 和 D2 都映射到 group2-step1。标注"仅作历史参考"，但如果 Agent 需要处理旧格式输入，**重叠可能导致歧义**。 |

---

### 2.9 requirement-checklist.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 28 项约束完整 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | hint_ref 机制有效压缩 token |
| LLM 歧义 | ⚠️ 中等 | 2 个歧义点 |

**歧义点**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-10 | not_applicable_rules "含糊敷衍" 与 stageB-detail vague_input_probing_strategy 标注要求不一致 | 🟡 中 | checklist：追问 2 次仍敷衍→"强制用推荐值"。stageB-detail：2 次追问后使用推荐值，但必须标注"基于通用知识，待用户确认"。**checklist 缺少标注要求**。 |
| A-11 | REQ-026 cat=conditional_optional 与 stageC-detail 默认优先级=Should 的逻辑关系不明 | 🟡 中 | conditional_optional 通常意味着"大多数情况跳过"，但 Should 意味着"应尽量满足"。**分类与优先级存在张力**。 |

---

### 2.10 stageB-detail.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 8 步执行流程清晰 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 灰色表达系统独立成节 |
| LLM 歧义 | ⚠️ 中等 | 2 个歧义点 |

**歧义点**：

| # | 问题 | 严重度 |
|---|------|--------|
| C-01 | new_req_persistence.target 文件在 stageB phase2 时尚不存在 | 🔴 高 | blocking_rule："未写入 requirement_summary 的 REQ 不得进入 stageC phase1"。但主定义 §文件写入时机：requirement_summary 在 stageC phase2 才创建。**Agent 无法写入不存在的文件**。 |
| A-12 | multi_round_rules 第 5 轮后强制结束行为未定义 | 🟡 中 | max_rounds=5，termination_conditions 有 3 个条件。如果用户每轮都提出新 REQ，第 5 轮后是否强制结束？**行为未定义**。 |

---

### 2.11 conflict-detection-rules.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 17+3 条规则覆盖全面 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 分层设计（基础/条件/实验）优秀 |
| LLM 歧义 | ⚠️ 低 | 1 个编号冲突 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-13 | CDC-01 与 arch-review CDC-01 编号空间未隔离 | 🟢 低 | `arch_review_cross_ref` 引用 "arch-review/cdc-reset-timing-rules.json CDC-01~06"。两个不同子系统的规则使用相同编号前缀。 |

---

### 2.12 stageD-detail.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 20 个子阶段定义完整 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | context_isolation、wiki_brainstorm_integration 设计优秀 |
| LLM 歧义 | ⚠️ 中等 | 3 个歧义点 |

**歧义点**：

| # | 问题 | 严重度 |
|---|------|--------|
| C-02 | group2-step3 依赖 group2-step4，但 sub_stages 数组顺序 step3 在 step4 前 | 🔴 高 | `recommended_execution_order` 已修正（step4 在 step3 前），但 `sub_stages` 数组顺序未同步。**LLM 可能按数组顺序执行而非依赖图**。 |
| C-03 | group3-step4 的 input_analysis.source 引用 group5-step5（尚未执行） | 🔴 高 | group3 在 group5 之前执行，group3-step4 不可能引用 group5-step5 的输出。**前向引用**。 |
| A-14 | group5-step3 name="DFX 设计" 但 content="DFT 设计" | 🟡 中 | 同一 JSON 对象内 name 和 content 使用不同术语。 |

---

### 2.13 e-stage-detail.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 递归分解流程 5 步清晰 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 自包含 todolist 10 个 section 定义完整 |
| LLM 歧义 | ⚠️ 中-高 | 4 个歧义点 |

**歧义点**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-15 | 顶层 6 文件 vs 子模块 5 文件的差异未解释 | 🟡 中 | level_0_top.outputs_files 有 6 个（含 todolist），level_N_submodule.outputs_files 也有 6 个（含 todolist）。但 `submodule_deliverables.required_files` 只有 5 个（不含 todolist）。**todolist 是否为子模块必须交付物？** |
| A-16 | todolist 模板未包含 parent_requirement_sync 步骤 | 🟡 中 | submodule_execution_flow.execution_order 步骤 3.5 定义了 parent_requirement_sync，但 tree_todolist.template §3 阶段 3 步骤 6 直接从 stageB phase2 开始，**遗漏了同步步骤**。 |
| A-17 | 子模块 todolist 路径不一致 | 🟡 中 | context_isolation.S-02 source = "{name}/outputs/{name}_todolist.md"。但 tree_todolist output_path = "<module>_work/ds/doc/pr/e_stage_tree_todolist.md"（全局 todolist）。**子模块 todolist 是独立文件还是全局 todolist 的一部分？** |
| A-18 | max_recursion_depth=5 的兜底行为未定义 | 🟡 中 | recursion_check.max_depth=5，note 说"超过 5 层时暂停请用户确认是否继续分解"。但如果用户说"继续"，**是否允许突破 5 层？还是强制停止？** |

---

### 2.14 solution-template.json

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 方案比选框架完整 |
| 结构化 | ⭐⭐⭐⭐ (4/5) | 比较表 13 维度全面 |
| LLM 歧义 | ⚠️ 中等 | 1 个引用错误 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| C-04 | single_solution_elements "存储设计" 引用错误子阶段 | 🔴 高 | requirement 写 "stageD group3-step3 + group3-step4 产出"。但 group3-step3=链表设计，group3-step4=寄存器定义。SRAM=group3-step1，FIFO=group3-step2。**应为 group3-step1 + group3-step2**。 |

---

### 2.15 评估标准（chip-requirement-arch-eva.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐⭐ (5/5) | 10 维度、100 分制评分体系完整 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 验证脚本可直接执行 |
| LLM 歧义 | ⚠️ 中等 | 3 个阈值错误 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| C-05 | G-08 门控阈值 ≥3 远低于交付标准 5 文件 | 🔴 高 | e-stage-detail 定义子模块需要 5 个文件（pr/requirement_summary/solution/ADR/trace_graph）。G-08 PASS 条件应为 ≥5。 |
| C-06 | D4.2 Q&A 阈值 50 低于理论最小值 60 | 🟡 中 | 20 个子阶段 × min_qa_pairs 最少 3 = 60。阈值应 ≥60。 |
| C-07 | G-17 Q&A 阈值 ≥30 与 D4.2 不一致 | 🟡 中 | 门控 2 的 G-17 要求 ≥30，但 D4.2 满分要求 ≥60。**门控阈值应与评分阈值对齐**。 |

---

### 2.16 示例对话（chip-requirement-arch-stage0-C-example.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐⭐ (5/5) | 完整展示 stage0→stageD 流程 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 代办清单格式规范 |
| LLM 歧义 | ⚠️ 低 | 1 个跳过未标注 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-19 | stageD group1-step1 后跳过 group1-step2 未标注原因 | 🟢 低 | 示例中 group1-step1 完成后直接进入 group1-step3，跳过了 group1-step2（CBB 选型）。虽然 group1-step2 的 skip_condition 是"无CBB"，但示例**未显式标注跳过原因**。 |

---

### 2.17 变更日志（chip-requirement-arch-changelog.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐ (4/5) | 变更记录详细 |
| 结构化 | ⭐⭐⭐⭐ (4/5) | 按版本倒序排列 |
| LLM 歧义 | ⚠️ 低 | 1 个版本断层 |

**问题**：

| # | 问题 | 严重度 |
|---|------|--------|
| A-20 | 版本断层：Agent v12.0，changelog 最高 v7.4 | 🟢 低 | v7.4→v12.0 之间有 5 个大版本未记录变更内容。**变更追溯不完整**。 |

---

### 2.18 成员档案（01_苏启辰_chip-requirement-arch.md）

| 维度 | 评分 | 说明 |
|------|------|------|
| 清晰度 | ⭐⭐⭐⭐⭐ (5/5) | 角色定义完整 |
| 结构化 | ⭐⭐⭐⭐⭐ (5/5) | 表格化信息清晰 |
| LLM 歧义 | ✅ 极低 | 无 |

---

## 三、跨文件矛盾清单

### 3.1 🔴 严重矛盾（7 项，需立即修复）

| # | 矛盾描述 | 文件 A | 文件 B | 影响 |
|---|----------|--------|--------|------|
| C-01 | **stageB phase2 追加 REQ 的写入目标文件在 stageC phase2 才首次创建** | stageB-detail.json (blocking_rule) | 主定义 §文件写入时机 | Agent 执行时无法写入不存在的文件 |
| C-02 | **stageD group2-step3 依赖 group2-step4，但 sub_stages 数组顺序 step3 在 step4 前** | stageD-detail.json depends_on | stageD-detail.json sub_stages 数组 | LLM 可能按数组顺序而非依赖图执行 |
| C-03 | **stageD group3-step4 引用 group5-step5（尚未执行的子阶段）** | stageD-detail.json input_analysis.source | stageD-detail.json phase_execution_order | 前向引用，输入数据不存在 |
| C-04 | **solution-template.json "存储设计" 引用错误子阶段** | solution-template.json | stageD-detail.json | 存储设计应引用 group3-step1+step2，非 group3-step3+step4 |
| C-05 | **评估标准 G-08 门控阈值（≥3）与交付标准（5 文件）不匹配** | chip-requirement-arch-eva.md | e-stage-detail.json | 门控放水，遗漏不完整交付 |
| C-06 | **评估标准 D4.2 Q&A 阈值（50）低于理论最小值（60）** | chip-requirement-arch-eva.md | stageD-detail.json min_qa_pairs | 评分标准低于实际要求 |
| C-07 | **exception_handling force_completion 与 todo-mechanism 步进模式语义冲突** | requirement-template.json | todo-mechanism.md | 字段名暗示"强制完成"，但规则要求"禁止强制完成" |

### 3.2 🟡 中等矛盾（8 项，建议修复）

| # | 矛盾描述 | 文件 A | 文件 B |
|---|----------|--------|--------|
| M-01 | **DFX vs DFT 混用** | 主定义 §L2 (DFT) / stageD-detail.json content (DFT) | stage-definition.json (DFX) / stageD-detail.json name (DFX) |
| M-02 | **REQ 扩展规则仅在追溯规范定义** | sdd-spec-traceability.md §10.1 | 主定义 §SDD 编号规范 |
| M-03 | **追问标注要求不一致** | requirement-checklist.json (无标注要求) | stageB-detail.json (必须标注"基于通用知识") |
| M-04 | **REQ-026 cat 与默认优先级逻辑关系不明** | requirement-checklist.json (conditional_optional) | stageC-detail.json (Should) |
| M-05 | **e-stage todolist 模板未包含 parent_requirement_sync 步骤** | e-stage-detail.json tree_todolist.template | e-stage-detail.json submodule_execution_flow |
| M-06 | **子模块 todolist 路径不一致** | e-stage-detail.json context_isolation.S-02 | e-stage-detail.json tree_todolist.output_path |
| M-07 | **output/ vs outputs/ 路径前缀不一致** | 主定义 §文件写入时机 | e-stage-detail.json + 评估标准 |
| M-08 | **G-17 Q&A 阈值（≥30）与 D4.2（≥60）不一致** | 评估标准 G-17 | 评估标准 D4.2 |

### 3.3 🟢 轻微不一致（5 项，可选修复）

| # | 描述 | 文件 |
|---|------|------|
| L-01 | conflict-detection CDC-01 与 arch-review CDC-01 编号空间未隔离 | conflict-detection-rules.json |
| L-02 | stage-definition.json old_to_new_mapping D1/D2 重叠映射 | stage-definition.json |
| L-03 | changelog v7.4→v12.0 版本断层 | changelog |
| L-04 | e-stage rule_reload_mechanism 包含 coding-style.md 但标注"chip-requirement-arch 不需要" | e-stage-detail.json |
| L-05 | 示例对话跳过 group1-step2 未标注原因 | 示例文件 |

---

## 四、数字与规则一致性检查

### 4.1 关键数字一致性

| 数字 | 主定义 | checklist | stageB-detail | stageD-detail | e-stage-detail | 评估标准 | 结论 |
|------|--------|-----------|---------------|---------------|----------------|----------|------|
| stageB 约束项数 | 28 | 28 (REQ-001~028) | 28 | - | - | G-01: ≥20 | ✅ |
| 追加 REQ 起始编号 | REQ-029 | - | REQ-029 | - | - | - | ✅ |
| 追问上限 | 2 次 | 2 次 | 2 次 | - | - | - | ✅ |
| 关键 REQ 追问次数 | 2 次 | - | 2 次 | - | - | - | ✅ |
| 最大默认值数 | - | 5 | 5 | - | - | - | ✅ |
| RTL 行数阈值 | 3000 | - | - | 3000 | 3000 | - | ✅ |
| 最大递归深度 | - | - | - | - | 5 | - | ✅ |
| D 子阶段总数 | 20 | - | - | 20 | - | D4.2 | ✅ |
| min_qa_pairs 默认 | - | - | - | 3 | - | - | ✅ |
| min_qa_pairs 总和 | - | - | - | 62 (4+3+3+3+3+3+4+4+4+3+3+3+3+3+3+3+3+3+3+3) | - | D4.2: ≥50 | ❌ (50<62) |
| 头脑风暴最大轮数 | 5 | - | 5 | - | - | - | ✅ |
| 子模块交付文件数 | - | - | - | - | 5/6 | G-08: ≥3 | ❌ (3<5) |
| G-17 Q&A 阈值 | - | - | - | - | - | ≥30 | ❌ (30<60) |

### 4.2 关键规则一致性

| 规则 | 定义位置 | 执行位置 | 一致性 |
|------|----------|----------|--------|
| 步进模式为默认 | todo-mechanism.md | 主定义 §L0 | ✅ |
| stageB phase2 强制执行 | 主定义 §stageB phase2 | stage-definition.json | ✅ |
| stageD 输出统一文档 | 主定义 §stageD | stageD-detail.json | ✅ |
| 对抗性评审自动触发 | 主定义 §对抗性评审 | stageD-detail.json adversarial_review_trigger | ✅ |
| Wiki 检索优先 | agent-common-base.md §三 | stageD-detail.json wiki_brainstorm_integration | ✅ |
| 子模块从 stageB phase2 开始 | e-stage-detail.json submodule_execution_flow | e-stage-detail.json tree_todolist.template | ✅ |
| parent_requirement_sync 在 stageB phase2 前 | e-stage-detail.json submodule_execution_flow.step 3.5 | e-stage-detail.json tree_todolist.template §3 | ❌ (模板遗漏) |
| DFX/DFT 术语统一 | stage-definition.json (DFX) | 主定义 (DFT) | ❌ (混用) |

---

## 五、优化方案

### 5.1 🔴 P0：严重矛盾修复（7 项）

#### OP-01：修复 stageB phase2 文件写入时机矛盾

**问题**：C-01 — stageB phase2 要求写入 requirement_summary，但该文件在 stageC phase2 才创建。

**推荐方案**：stageB phase2 的追加 REQ 先写入 PR 沟通记录（flow/），stageC phase2 汇总时合并到 requirement_summary。理由：stageB phase2 的 REQ 尚未经过矛盾检测，不适合直接写入正式文档。

**修改文件**：
- `agents/chip-requirement-arch.md`：§文件写入时机表，stageB phase2 目标改为 `flow/{module}_pr_v1.0.md`
- `shared/flow/stageB-detail.json`：`new_req_persistence.target` 改为 flow 文件，`blocking_rule` 改为"未写入 PR 记录不得进入 stageC"

#### OP-02：修复 stageD 子阶段依赖关系矛盾

**问题**：C-02 + C-03 — group2-step3/step4 顺序矛盾，group3-step4 前向引用 group5-step5。

**修改文件**：
- `shared/flow/stageD-detail.json`：
  - group3-step4 的 input_analysis.source 删除 group5-step5 引用，改为"stageC phase2 REQ-002 接口协议"
  - 补充说明："sub_stages 数组顺序不代表执行顺序，执行顺序以 recommended_execution_order 为准"

#### OP-03：修复 solution-template.json 存储设计引用错误

**问题**：C-04 — 存储设计引用 group3-step3+step4，应为 group3-step1+step2。

**修改文件**：
- `shared/solution-template.json`：存储设计 requirement 改为 "stageD group3-step1 + group3-step2 产出"

#### OP-04：统一文件路径前缀为 outputs/

**问题**：C-07 (M-07) — output/ vs outputs/ 不一致。

**修改文件**：
- `agents/chip-requirement-arch.md`：§文件写入时机表中所有 `output/` 改为 `outputs/`

#### OP-05：修复评估标准 G-08 阈值

**问题**：C-05 — G-08 阈值 ≥3 远低于交付标准 5 文件。

**修改文件**：
- `evaluation_criteria/chip-requirement-arch-eva.md`：G-08 PASS 条件改为"每个目录 ≥5"

#### OP-06：修复评估标准 D4.2 和 G-17 Q&A 阈值

**问题**：C-06 + C-07 (M-08) — D4.2 阈值 50 低于理论最小值 62，G-17 阈值 30 更低。

**修改文件**：
- `evaluation_criteria/chip-requirement-arch-eva.md`：
  - D4.2 满分条件改为 "Q&A ≥ 62"
  - G-17 PASS 条件改为 "≥62"

#### OP-07：修复 exception_handling force_completion 语义

**问题**：C-07 — 字段名 `force_completion` 与实际行为（禁止强制完成）矛盾。

**修改文件**：
- `shared/requirement-template.json`：将 `force_completion: true` 改为 `step_mode_enforcement: true`，action 保持不变

---

### 5.2 🟡 P1：中等矛盾修复（8 项）

#### OP-08：统一 DFX/DFT 术语

**方案**：统一使用 DFX（Design for X，包含 DFT/调试/诊断）。

**修改文件**：
- `agents/chip-requirement-arch.md`：§L2 阶段层 stageD group5-step3 注入内容改为"DFX 设计"
- `shared/flow/stageD-detail.json`：group5-step3 content 改为 "DFX 设计（DFT/调试/诊断）"

#### OP-09：补充 REQ 扩展规则到主定义

**修改文件**：
- `agents/chip-requirement-arch.md`：§SDD 需求编号规范补充"超过 999 时扩展为 4 位数字"

#### OP-10：统一追问标注要求

**修改文件**：
- `shared/requirement-checklist.json`：not_applicable_rules "含糊敷衍" action 补充"标注'基于通用知识，待用户确认'"

#### OP-11：补充 REQ-026 优先级逻辑说明

**修改文件**：
- `shared/flow/stageC-detail.json`：priority_grading 补充说明"conditional_optional 的 REQ 在激活后按 default_rules 分配优先级，未激活时标记为'不适用'"

#### OP-12：补充 e-stage todolist 模板的 parent_requirement_sync 步骤

**修改文件**：
- `shared/flow/e-stage-detail.json`：tree_todolist.template §3 阶段 3 步骤 6 前插入 parent_requirement_sync 步骤

#### OP-13：统一子模块 todolist 路径

**修改文件**：
- `shared/flow/e-stage-detail.json`：context_isolation.S-02 路径改为 `{name}/outputs/{name}_todolist.md`，与 level_N_submodule.outputs_files 一致

#### OP-14：明确顶层 vs 子模块交付文件差异

**修改文件**：
- `shared/flow/e-stage-detail.json`：submodule_deliverables.required_files 补充第 6 个文件 `{name}_todolist.md`，或在 todolist_note 中明确"仅触发递归分解时生成"

#### OP-15：补充 max_recursion_depth 兜底行为

**修改文件**：
- `shared/flow/e-stage-detail.json`：recursion_check.max_depth_note 改为"超过 5 层时强制停止递归，将当前模块标记为叶子节点（即使 >3000 行），在 ADR 中标注风险"

---

### 5.3 🟢 P2：优化改进（5 项）

#### OP-16：隔离矛盾检测与架构评审的编号空间

**修改文件**：
- `shared/conflict-detection-rules.json`：CDC-01 的 arch_review_cross_ref 更新引用，建议 arch-review 使用前缀 `AR-CDC-`

#### OP-17：补充灰色表达处理的一致性定义

**修改文件**：
- `shared/requirement-checklist.json`：trigger_rules.semantic_judgment 引用 stageB-detail.json grey_expression_system

#### OP-18：补充 PPA "大幅调整"的量化阈值

**修改文件**：
- `shared/change-propagation-v2.md`：§3.3 补充"大幅调整 = >20%"

#### OP-19：补充 stageB phase2 第 5 轮后强制结束行为

**修改文件**：
- `shared/flow/stageB-detail.json`：multi_round_rules 补充"第 5 轮后自动结束，输出最终追加 REQ 汇总 + 头脑风暴总结，不再接受新 REQ"

#### OP-20：补充 input_triage 判定标准

**修改文件**：
- `shared/requirement-template.json`：input_triage.rules 补充"约束维度 = 用户输入中明确提及的不同约束类别数（工艺/接口/PPA/功耗/DFT/CDC/安全等）"

---

## 六、总结

### 6.1 整体评价

| 维度 | 评分 | 说明 |
|------|------|------|
| **清晰度** | ⭐⭐⭐⭐ (4/5) | 大部分文件清晰，少数术语混用和路径不一致 |
| **结构化程度** | ⭐⭐⭐⭐⭐ (5/5) | L0/L1/L2 分层架构和 stage/phase/group/step 编码规则是优秀设计 |
| **LLM 可执行性** | ⭐⭐⭐⭐ (4/5) | 主要风险在依赖关系矛盾和文件创建时序 |
| **跨文件一致性** | ⭐⭐⭐½ (3.5/5) | 7 个严重矛盾 + 8 个中等矛盾需要修复 |
| **规则完备性** | ⭐⭐⭐⭐ (4/5) | 覆盖全面，少数边界条件未定义 |

### 6.2 优先级排序

| 优先级 | 数量 | 预计工作量 | 风险 |
|--------|------|-----------|------|
| P0 严重矛盾 | 7 项 | 2-3 小时 | 不修复可能导致 Agent 执行卡死或产出错误 |
| P1 中等矛盾 | 8 项 | 1-2 小时 | 不修复可能导致规则理解偏差 |
| P2 优化改进 | 5 项 | 1 小时 | 提升一致性和可维护性 |

### 6.3 核心改进方向

1. **依赖关系治理**：stageD 子阶段的依赖图需要拓扑排序验证，sub_stages 数组顺序应与 recommended_execution_order 一致，或明确声明"以 recommended_execution_order 为准"
2. **文件生命周期管理**：明确每个文件的创建/追加/冻结时机，避免写入不存在的文件
3. **术语统一**：DFX/DFT、outputs/output 需要单一权威定义
4. **评估标准校准**：门控阈值和评分阈值需要与交付标准对齐（G-08: ≥5, D4.2/G-17: ≥62）
5. **边界条件补全**：递归 5 层兜底、第 5 轮后强制结束、input_triage 判定标准
