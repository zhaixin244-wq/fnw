# chip-requirement-arch 全量文件分析报告

> 分析日期：2026-06-03
> 分析范围：agent 定义 + 递归引用的所有文件（共 35+ 文件）
> 分析维度：清晰度 / 结构化程度 / LLM 歧义 / 跨文件矛盾 / 数字与规则一致性

---

## 一、文件清单与递归引用图

### 1.1 直接引用文件

| # | 文件 | 引用方式 | Token 估算 |
|---|------|----------|-----------|
| 1 | `.claude/agents/chip-requirement-arch.md` | 主定义（L0 常驻） | ~8K |
| 2 | `.claude/shared/agent-common-base.md` | includes | ~2.5K |
| 3 | `.claude/shared/todo-mechanism.md` | includes + L1 | ~1.2K |
| 4 | `.claude/shared/sdd-spec-traceability.md` | includes | ~3K（§1~5+§10） |
| 5 | `.claude/shared/change-propagation-v2.md` | includes | ~2.5K |
| 6 | `.claude/shared/context-layers.json` | L1 启动层 | ~0.5K |
| 7 | `.claude/shared/requirement-template.json` | L1 启动层 | ~1.4K |
| 8 | `.claude/shared/flow/stage-definition.json` | L1 启动层 | ~1.0K |
| 9 | `.claude/shared/requirement-checklist.json` | stageB phase1 | ~1.9K |
| 10 | `.claude/shared/flow/stageB-detail.json` | stageB phase1+phase2 | ~2.5K |
| 11 | `.claude/shared/conflict-detection-rules.json` | stageC phase1 | ~3.5K |
| 12 | `.claude/shared/flow/stageC-phase1-detail.json` | stageC phase1 | ~0.5K |
| 13 | `.claude/shared/flow/stageC-detail.json` | stageC phase2 | ~0.7K |
| 14 | `.claude/shared/flow/stageD-detail.json` | stageD | ~2.0K |
| 15 | `.claude/shared/flow/e-stage-detail.json` | stageE | ~5K |
| 16 | `.claude/shared/solution-template.json` | stageD | ~1.5K |
| 17 | `.claude/shared/flow/area-estimation.json` | stageD | ~1.0K |
| 18 | `.claude/shared/flow/rtl-readiness-checklist.json` | stageD | ~1.0K |
| 19 | `.claude/agents/examples/chip-requirement-arch-stage0-C-example.md` | 外置示例 | ~3K |
| 20 | `.claude/evaluation_criteria/chip-requirement-arch-eva.md` | 评估标准 | ~8K |
| 21 | `doc/member/01_苏启辰_chip-requirement-arch.md` | 人格档案 | ~1K |

### 1.2 间接引用文件（stageD 子阶段按需加载）

| # | 文件 | 触发条件 |
|---|------|----------|
| 22 | `.claude/shared/flow/stageD-group1.json` | 进入 group1 |
| 23 | `.claude/shared/flow/stageD-group2.json` | 进入 group2 |
| 24 | `.claude/shared/flow/stageD-group3.json` | 进入 group3 |
| 25 | `.claude/shared/flow/stageD-group4.json` | 进入 group4 |
| 26 | `.claude/shared/flow/stageD-group5.json` | 进入 group5 |
| 27 | `.claude/shared/flow/execution-hints.json` | stageB 按需 |
| 28 | `.claude/shared/flow/protocol-mapping.json` | stageB 推断 |
| 29 | `.claude/shared/flow/reference-values.json` | 矛盾检测参考值 |
| 30 | `.claude/shared/flow/conflict-detection-conditional.json` | 条件规则 |
| 31 | `.claude/shared/flow/conflict-detection-experimental.json` | 实验规则 |
| 32 | `.claude/shared/flow/coverage-model.json` | 覆盖率分析 |
| 33 | `.claude/shared/flow/end-to-end-coverage-report.json` | 端到端覆盖 |
| 34 | `.claude/shared/flow/specialist-orchestration.json` | 专项编排 |
| 35 | `.claude/shared/flow/d-phase-context-isolation.json` | D 阶段隔离 |

---

## 二、逐文件分析

### 2.1 主定义文件 `.claude/agents/chip-requirement-arch.md`

**清晰度**：⭐⭐⭐⭐☆ (4/5)
- 角色定义、铁律、编码规则速查清晰
- 流程定义按 stage 分节，每节有目标/步骤/输出物
- stageD 方案文档结构映射表（step → 章节）非常实用

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)
- L0/L1/L2 三层加载机制设计精良
- 编码规则统一（stage/phase/group/step）
- 结构化标记规范完整

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| §stageB phase1 "28 个约束项" | checklist 实际有 28 项（REQ-001~REQ-028），但 stageB-detail.json 的 `vague_input_probing_strategy` 中提到 "REQ-001~REQ-028"，而 `requirement-checklist.json` 确实是 28 项。数字一致，但 LLM 可能混淆 "28 项确认" 和 "REQ-001~REQ-028 编号" | 低 |
| §stageD "group1-step1~group5-step6 共 20 个子阶段" | 实际计数：group1(3)+group2(4)+group3(4)+group4(3)+group5(6)=20 ✅ | 无 |
| §stageE "RTL 行数 > 3000 行" | 阈值在 agent 主文件、stage-definition.json、e-stage-detail.json、stageD-detail.json 四处均写 3000，一致 ✅ | 无 |
| §stageB phase2 "追加 REQ 编号规则详见 stageB-detail.json" | 编号规则同时在 requirement-template.json 和 stageB-detail.json 定义，需确认权威源 | 中 |

**跨文件矛盾**：无严重矛盾

---

### 2.2 `agent-common-base.md`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 五个章节职责分明（交互/降级/Wiki/权限/文件管理）
- 降级策略表格化，每种场景有明确行为

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| §三 Wiki 检索 "铁律" | "涉及协议/接口/CBB/选型/编码前，必须先完成 Wiki 检索"，但 stage0/stageA 例外。LLM 可能在 stageB phase1 早期就触发 Wiki 检索（此时还在做约束确认，不是选型） | 低 |
| §四 权限规则 | "芯片 Agent 禁止修改 `.claude/`"，但 agent 定义中 includes 引用了 `.claude/shared/` 下的文件。这是读取权限，不是修改权限，但 LLM 可能困惑 | 低 |

---

### 2.3 `todo-mechanism.md`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 步进模式 vs 调试模式区分明确
- 关键决策点处理规则清晰

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| §调试模式 "自动决策-待确认" | 调试模式下自动选择推荐方案，但 evaluation 标准中 G-01~G-09 门控检查要求实际文件存在。如果调试模式自动决策导致文件质量不足，评估会扣分但不会阻断 | 低 |

---

### 2.4 `sdd-spec-traceability.md`

**清晰度**：⭐⭐⭐⭐☆ (4/5)
- 追溯模型清晰（REQ→FS→BDD→UA→RTL→SVA→UVM）
- L1~L11 层级定义完整
- 但 §6~§9 对 chip-requirement-arch 来说是 "仅了解" 内容，增加了阅读负担

**结构化程度**：⭐⭐⭐⭐☆ (4/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| §10.1 L1 "REQ-{NNN}（三位数字，001~999。超过 999 时扩展为 REQ-{NNNN}）" | agent 主文件速查也写了同样内容，但格式略有差异（主文件用括号，sdd 用反引号）。不影响理解 | 低 |

---

### 2.5 `change-propagation-v2.md`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 变更传播模型树形图清晰
- 各阶段变更源与影响表格化
- Critical/Major/Minor 分级明确

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：无

---

### 2.6 `context-layers.json`

**清晰度**：⭐⭐⭐⭐☆ (4/5)
- L0~L3 四层定义清晰
- Token 预算明确
- 但 `optimization_strategies` 中的 "status: pending" 可能误导 LLM 认为尚未完成

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**跨文件矛盾**：
| 位置 | 矛盾描述 | 严重度 |
|------|----------|--------|
| `L1_startup.files` 列出 4 个文件 | 与 agent 主文件 §L1 表格一致 ✅ | 无 |
| `L2_stage.stageB.budget` "~6K tokens" | 实际 requirement-checklist.json ~1.9K + stageB-detail.json ~0.6K + execution-hints.json ~1.5K = ~4K，与标注的 6K 有差距 | 低 |

---

### 2.7 `requirement-template.json`

**清晰度**：⭐⭐⭐⭐☆ (4/5)
- 流程骨架完整
- 但 `stageB` 的 `phases` 只定义了 `phase1`，缺少 `phase2` 的完整定义（仅引用 stageB-detail.json）
- `stageD.sub_stages` 数组与 `stageD-detail.json` 的 `recommended_execution_order` 存在潜在冲突

**结构化程度**：⭐⭐⭐⭐☆ (4/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| `stageD.sub_stages` 数组顺序 | 数组按 group1-step1, group1-step2, group1-step3, group2-step1... 排列，但 `stageD-detail.json` 的 `recommended_execution_order` 中 group2 的顺序是 step1→step2→**step4→step3**。LLM 可能按数组顺序执行而非推荐顺序 | **高** |
| `stageB.phase2.new_req_rules.numbering` | 写 "详见 stageB-detail.json"，但 requirement-template 自身也有 numbering 规则描述，两处需一致 | 中 |

**跨文件矛盾**：
| 位置 | 矛盾描述 | 严重度 |
|------|----------|--------|
| requirement-template `stageD.sub_stages` vs stageD-detail `recommended_execution_order` | **数组顺序 vs 推荐顺序不一致**（group2 内 step3/step4 顺序颠倒） | **高** |

---

### 2.8 `stage-definition.json`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 统一编码规则集中管理
- old_to_new_mapping 便于历史迁移
- validation_rules 提供正则校验

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| `old_to_new_mapping.D1` | "旧 D1 覆盖范围模糊，以 stageD-detail 为准" — 这是正确的处理方式，但 LLM 在处理旧文档引用时可能困惑 | 低 |

---

### 2.9 `requirement-checklist.json`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 28 项约束清单表格化
- 每项有 id/name/q/cat/hint_ref/dep
- 依赖关系（dep）明确

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| `dep` 语义 | 文档说 "dep 为硬阻断：前置 REQ 未确认时，本项不可确认"，但 `trigger_rules` 中有 "灰色表达处理规则"，LLM 可能在 dep 未满足时仍尝试确认 | 低 |
| `not_applicable_rules` 第三条 | "含糊敷衍" 的处理是 "第1次追问→第2次追问→2次后仍敷衍→强制用推荐值"，但 `vague_input_probing_strategy` 中的追问上限也是 2 次。两者一致 ✅ | 无 |

---

### 2.10 `stageB-detail.json`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 执行步骤清晰（8 步）
- 分类处理规则（category_processing）每类有明确行为
- 灰色表达系统化处理（grey_expression_system）设计精良

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| `post_stageB_brainstorming.new_req_rules.numbering` | "从 REQ-029 起连续编号"，但 requirement-template 也定义了同样的规则。如果主模块已追加到 REQ-033，子模块应从 REQ-034 起 — 这个逻辑在 e-stage-detail.json 的 `parent_requirement_sync` 中有定义 | 中 |
| `multi_round_rules.max_rounds: 5` | 与 agent 主文件 "5 轮后自动结束" 一致 ✅ | 无 |

---

### 2.11 `conflict-detection-rules.json`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 17 条基础规则，每条有 id/name/logic/involved_keys/detection_tip
- 引用 reference_values_ref 外置参考值

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| `DYN-01~03` 的 `involved_keys` | DYN-01 使用 "REQ-029+"，但实际追加 REQ 可能从 REQ-029 或更高编号开始。LLM 需要动态理解 "+" 含义 | 低 |

---

### 2.12 `stageD-detail.json`

**清晰度**：⭐⭐⭐⭐☆ (4/5)
- 子阶段定义完整（20 个）
- 条件跳过规则清晰
- Wiki 集成规则详细

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| `recommended_execution_order.stageD group2` | 顺序为 step1→step2→**step4→step3**，与 sub_stages 数组顺序不同。agent 主文件有明确说明 "step4 在 step3 之前"，但 requirement-template 的 sub_stages 数组是 step1→step2→step3→step4 | **高** |
| `phases.stageD group2.context_isolation.input_files` | 写 "flow/group{N-1}_summary.md"，但 N 是 group 编号（2），实际应引用 group1 的摘要。占位符 `{N-1}` 的解析可能有歧义 | 中 |

**跨文件矛盾**：
| 位置 | 矛盾描述 | 严重度 |
|------|----------|--------|
| stageD-detail `recommended_execution_order` vs requirement-template `sub_stages` | group2 内 step3/step4 顺序不一致 | **高** |
| stageD-detail `substage_depth_requirements.min_qa_pairs` 总和 | 4+3+3+3+3+3+4+4+4+3+3+3+3+3+3+3+3+3+3+3 = 64，与 evaluation G-17 的 "≥64 个 Q&A" 一致 ✅ | 无 |

---

### 2.13 `e-stage-detail.json`

**清晰度**：⭐⭐⭐⭐☆ (4/5)
- 递归分解规则详细
- 自包含 todolist 模板设计精良
- 防飘逸机制（anti_drift）考虑周全

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| `e_stage_definition.max_recursion_depth: 5` | 与 `submodule_execution_flow.recursion_check.max_depth: 5` 一致 ✅ | 无 |
| `submodule_deliverables.required_files` 列出 6 个文件 | 但 `output_files.submodule_deliverables.files` 只列出 5 个（缺 todolist）。两处定义不一致 | **中** |
| `directory_creation.unified_structure.level_N_submodule.outputs_files` 列出 6 个文件 | 包含 todolist，与 `submodule_deliverables.required_files` 一致，但 `output_files.submodule_deliverables.files` 只有 5 个 | **中** |

**跨文件矛盾**：
| 位置 | 矛盾描述 | 严重度 |
|------|----------|--------|
| e-stage-detail `submodule_deliverables.required_files` (6个) vs `output_files.submodule_deliverables.files` (5个) | 同一文件内两处定义不一致 | **中** |
| e-stage-detail `level_N_submodule.start_stage` 写 "stageB phase2" | 但 `submodule_execution_flow.start_stage` 也写 "stageB phase2"，一致 ✅ | 无 |

---

### 2.14 `evaluation_criteria/chip-requirement-arch-eva.md`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 10 个维度、18 个门控检查项，每项有验证命令
- 扣分项速查表实用
- 评估一致性保证机制完善

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**LLM 歧义风险**：
| 位置 | 歧义描述 | 严重度 |
|------|----------|--------|
| G-17 "≥64 个 Q&A" | 验证命令是 `grep -c "^- Q:" 方案文档`，但实际 Q&A 记录格式可能不是每行以 "- Q:" 开头。如果格式变化，grep 可能漏计 | 中 |
| D4.2 "group1-step1~group5-step6 全部执行" | 但条件跳过的子阶段不算 "未执行"，评估标准未明确说明跳过项是否计入 "全部执行" | 中 |
| D5.5 "每个叶子节点 5 文件" | 但 e-stage-detail 中有 6 文件（含 todolist）的定义。评估标准写 5 文件，与 e-stage-detail 的 `submodule_deliverables.required_files` (6个) 矛盾 | **中** |

**跨文件矛盾**：
| 位置 | 矛盾描述 | 严重度 |
|------|----------|--------|
| evaluation D5.5 "5 文件" vs e-stage-detail `required_files` (6个) | 评估标准与交付规范不一致 | **中** |
| evaluation G-08 "每个目录 ≥5" vs e-stage-detail "6 文件" | 门控检查阈值与交付规范不一致 | **中** |

---

### 2.15 `doc/member/01_苏启辰_chip-requirement-arch.md`

**清晰度**：⭐⭐⭐⭐⭐ (5/5)
- 人格档案完整（性格/职责/能力边界/协作关系）
- 与 agent 主文件一致

**结构化程度**：⭐⭐⭐⭐⭐ (5/5)

**跨文件矛盾**：无

---

## 三、跨文件矛盾汇总

### 3.1 严重矛盾（需修复）

| # | 矛盾描述 | 涉及文件 | 影响 |
|---|----------|----------|------|
| **C-01** | **stageD group2 执行顺序不一致**：requirement-template.json 的 `sub_stages` 数组顺序是 step1→step2→step3→step4，但 stageD-detail.json 的 `recommended_execution_order` 是 step1→step2→**step4→step3**。agent 主文件有说明但 requirement-template 没有 | requirement-template.json, stageD-detail.json, agent 主文件 | LLM 可能按错误顺序执行 group2 |
| **C-02** | **子模块交付文件数量不一致**：e-stage-detail.json 内部两处定义矛盾（`required_files` 6个 vs `output_files` 5个），evaluation 标准写 5 个 | e-stage-detail.json, evaluation | 评估标准与交付规范不一致 |

### 3.2 中等矛盾（建议修复）

| # | 矛盾描述 | 涉及文件 | 影响 |
|---|----------|----------|------|
| **C-03** | **REQ 编号起始规则分散**：新 REQ 从 REQ-029 起编号的规则在 requirement-template.json 和 stageB-detail.json 两处定义，子模块编号规则在 e-stage-detail.json 定义 | requirement-template.json, stageB-detail.json, e-stage-detail.json | LLM 可能混淆权威源 |
| **C-04** | **context-layers.json stageB budget "~6K" 与实际文件大小不符** | context-layers.json, requirement-checklist.json, stageB-detail.json, execution-hints.json | Token 预算估算不准确 |
| **C-05** | **evaluation D5.5 与 e-stage-detail 交付文件数量不一致** | evaluation, e-stage-detail.json | 评估可能漏检 todolist 文件 |

### 3.3 轻微不一致（可接受）

| # | 描述 | 涉及文件 |
|---|------|----------|
| C-06 | sdd-spec-traceability.md §10.1 REQ 编号格式描述与 agent 主文件速查略有措辞差异 | sdd-spec-traceability.md, agent 主文件 |
| C-07 | old_to_new_mapping 中 D1/D2/D3 映射 "范围模糊" 标注 | stage-definition.json |
| C-08 | DYN-01~03 使用 "REQ-029+" 动态编号 | conflict-detection-rules.json |

---

## 四、数字与规则一致性检查

### 4.1 关键数字

| 数字 | 出现位置 | 一致性 |
|------|----------|--------|
| **28 项约束** | agent 主文件, requirement-checklist.json (28条), stageB-detail.json | ✅ 一致 |
| **3000 行阈值** | agent 主文件, stage-definition.json, e-stage-detail.json, stageD-detail.json | ✅ 一致 |
| **20 个 D 子阶段** | agent 主文件, stage-definition.json (计数20), stageD-detail.json (20个) | ✅ 一致 |
| **5 轮头脑风暴上限** | agent 主文件, stageB-detail.json, requirement-template.json | ✅ 一致 |
| **64 个 min_qa_pairs 总和** | stageD-detail.json (求和64), evaluation G-17 (≥64) | ✅ 一致 |
| **17 条基础矛盾检测** | agent 主文件, conflict-detection-rules.json (17条) | ✅ 一致 |
| **5 条实验性规则** | requirement-template.json, conflict-detection-rules.json (5条) | ✅ 一致 |
| **7 条条件规则** | conflict-detection-rules.json, context-layers.json | ✅ 一致 |
| **5 个递归深度上限** | e-stage-detail.json (两处) | ✅ 一致 |
| **REQ-004/016/020 关键追问** | agent 主文件, stageB-detail.json, evaluation | ✅ 一致 |
| **2 次追问上限** | requirement-checklist.json, stageB-detail.json | ✅ 一致 |
| **5 个默认值上限** | stageB-detail.json, evaluation D1.3 | ✅ 一致 |
| **5 个头脑风暴维度** | agent 主文件, stageB-detail.json (5个维度) | ✅ 一致 |
| **5 个规格自检项** | e-stage-detail.json, evaluation D3.4 | ✅ 一致 |

### 4.2 关键规则

| 规则 | 出现位置 | 一致性 |
|------|----------|--------|
| **步进模式为默认** | agent 主文件, todo-mechanism.md | ✅ 一致 |
| **stageB phase2 强制执行** | agent 主文件 "铁律", todo-mechanism.md | ✅ 一致 |
| **新 REQ 从 REQ-029 起编号** | requirement-template.json, stageB-detail.json | ✅ 一致 |
| **子模块从 stageB phase2 开始** | e-stage-detail.json (两处) | ✅ 一致 |
| **子模块 REQ 从父模块最大+1 起** | e-stage-detail.json | ✅ 一致 |
| **跳过子阶段需标注原因+影响+替代方案** | stageD-detail.json, evaluation D7.4 | ✅ 一致 |
| **Nygard ADR 格式** | requirement-template.json, stageD-detail.json, evaluation | ✅ 一致 |

---

## 五、LLM 理解歧义专项分析

### 5.1 高风险歧义（可能导致流程错误）

| # | 歧义描述 | 出现位置 | 建议修复 |
|---|----------|----------|----------|
| **A-01** | **group2 执行顺序**：LLM 可能按 sub_stages 数组顺序（step1→step2→step3→step4）而非推荐顺序（step1→step2→step4→step3）执行 | requirement-template.json | 在 requirement-template.json 的 sub_stages 数组中按推荐顺序排列，或添加注释 |
| **A-02** | **子模块交付文件数**：LLM 可能生成 5 个文件（按 evaluation）或 6 个文件（按 e-stage-detail required_files），取决于读取哪个定义 | e-stage-detail.json, evaluation | 统一为 6 个文件（含 todolist），更新 evaluation |

### 5.2 中风险歧义（可能导致输出质量下降）

| # | 歧义描述 | 出现位置 | 建议修复 |
|---|----------|----------|----------|
| **A-03** | **D 子阶段跳过是否计入 "全部执行"**：evaluation D4.2 说 "全部执行"，但条件跳过的子阶段不算未执行 | evaluation | 在 D4.2 中明确 "跳过的子阶段不计入遗漏" |
| **A-04** | **Q&A 计数格式**：evaluation G-17 用 `grep -c "^- Q:"` 计数，但实际格式可能变化 | evaluation | 放宽 grep 模式或改用语义计数 |
| **A-05** | **context_isolation 占位符解析**：`flow/group{N-1}_summary.md` 中 `{N-1}` 的解析规则不明确 | stageD-detail.json | 改为具体文件名或明确解析规则 |

### 5.3 低风险歧义（不太可能导致错误）

| # | 歧义描述 | 出现位置 |
|---|----------|----------|
| A-06 | Wiki 检索时机：stageB phase1 是否需要 Wiki 检索（铁律说 "编码前"，但 stageB 还在做约束确认） | agent-common-base.md |
| A-07 | 人格档案座右铭与 agent 主文件略有差异（多了 "模糊的需求是灾难的开始"） | doc/member/ |
| A-08 | DYN-01~03 的 "REQ-029+" 动态编号理解 | conflict-detection-rules.json |

---

## 六、优化方案

### 6.1 必须修复（P0 — 解决跨文件矛盾）

#### OPT-01：统一 stageD group2 执行顺序

**问题**：C-01 — requirement-template.json sub_stages 数组顺序与 stageD-detail.json recommended_execution_order 不一致

**方案**：
1. 修改 `requirement-template.json` 的 `stageD.sub_stages` 数组，将 group2 内顺序改为 step1→step2→step4→step3（与 recommended_execution_order 一致）
2. 或在 requirement-template.json 中添加注释："执行顺序以 stageD-detail.json recommended_execution_order 为准"

**影响文件**：`requirement-template.json`

#### OPT-02：统一子模块交付文件数量

**问题**：C-02 — e-stage-detail.json 内部矛盾 + evaluation 标准不一致

**方案**：
1. 修改 `e-stage-detail.json` 的 `output_files.submodule_deliverables.files`，从 5 个扩展为 6 个（添加 todolist）
2. 修改 `evaluation` 的 D5.5 和 G-08，将 "5 文件" 改为 "6 文件（含 todolist）" 或 "5 基础文件 + 条件 todolist"
3. 明确 todolist 是 "有递归时必须，无递归时可选"

**影响文件**：`e-stage-detail.json`, `evaluation`

### 6.2 建议修复（P1 — 消除 LLM 歧义）

#### OPT-03：统一 REQ 编号规则权威源

**问题**：C-03 — 新 REQ 编号规则在多处定义

**方案**：
1. 将 `requirement-template.json` 的 `stageB phase2.new_req_rules.numbering` 改为引用形式："详见 stageB-detail.json post_stageB_brainstorming.new_req_rules.numbering（权威定义）"
2. 将 `e-stage-detail.json` 的子模块编号规则标注为 "扩展规则，适用于 E 阶段子模块"

**影响文件**：`requirement-template.json`, `e-stage-detail.json`

#### OPT-04：修正 context-layers.json Token 预算

**问题**：C-04 — stageB budget 估算不准确

**方案**：将 `L2_stage.stageB.budget` 从 "~6K tokens" 修正为 "~4K tokens（典型）/ ~5.5K tokens（含 execution-hints）"

**影响文件**：`context-layers.json`

#### OPT-05：明确 D 子阶段跳过与执行完整性的关系

**问题**：A-03 — evaluation D4.2 歧义

**方案**：在 evaluation D4.2 的评分标准中添加："条件跳过的子阶段不计入遗漏，但需在 ADR 中标注原因+影响+替代方案"

**影响文件**：`evaluation`

#### OPT-06：明确 context_isolation 占位符

**问题**：A-05 — `{N-1}` 解析规则不明确

**方案**：将 `stageD-detail.json` 的 `context_isolation.input_files` 从 `flow/group{N-1}_summary.md` 改为具体示例 `flow/stageD_group1_summary.md`，并在描述中说明 "N 为当前 group 编号"

**影响文件**：`stageD-detail.json`

### 6.3 可选优化（P2 — 提升可维护性）

#### OPT-07：抽取公共常量定义

**问题**：关键数字（3000/28/20/5/64/17）分散在多个文件中

**方案**：在 `stage-definition.json` 中添加 `constants` 节，集中定义所有关键数字，其他文件引用

```json
"constants": {
  "RTL_LINE_THRESHOLD": 3000,
  "CONSTRAINT_ITEM_COUNT": 28,
  "D_SUBSTAGE_COUNT": 20,
  "MAX_BRAINSTORM_ROUNDS": 5,
  "MIN_QA_PAIRS_TOTAL": 64,
  "BASE_CONFLICT_RULES": 17,
  "EXPERIMENTAL_RULES": 5,
  "CONDITIONAL_RULES": 7,
  "MAX_RECURSION_DEPTH": 5,
  "MAX_DEFAULT_VALUES": 5,
  "MAX追问次数": 2,
  "BRAINSTORM_DIMENSIONS": 5,
  "SELF_CHECK_ITEMS": 5
}
```

#### OPT-08：evaluation 门控验证脚本修复

**问题**：G-08b 脚本逻辑不完整（孙模块检查标注为 "信息性"）

**方案**：完善 G-08b 脚本，使其能正确检测孙模块是否在子模块目录下

#### OPT-09：添加 cross-reference 索引

**问题**：文件间引用关系复杂，难以维护

**方案**：在 `stage-definition.json` 的 `file_mapping` 中添加反向索引（每个文件被哪些 stage 引用）

---

## 七、总结

### 7.1 整体评价

| 维度 | 评分 | 说明 |
|------|------|------|
| 文件清晰度 | ⭐⭐⭐⭐☆ 4.3/5 | 绝大多数文件清晰度高，少数 JSON 嵌套层级较深 |
| 结构化程度 | ⭐⭐⭐⭐⭐ 4.8/5 | 分层架构设计精良，JSON Schema 规范 |
| LLM 歧义风险 | ⭐⭐⭐⭐☆ 4.0/5 | 2 个高风险歧义（group2 顺序、交付文件数），5 个中风险 |
| 跨文件一致性 | ⭐⭐⭐⭐☆ 4.0/5 | 2 个严重矛盾，3 个中等矛盾 |
| 数字规则一致性 | ⭐⭐⭐⭐⭐ 4.9/5 | 所有关键数字和规则高度一致 |

### 7.2 优先级排序

| 优先级 | 编号 | 描述 | 工作量 |
|--------|------|------|--------|
| **P0** | OPT-01 | 统一 group2 执行顺序 | 5 min |
| **P0** | OPT-02 | 统一子模块交付文件数 | 10 min |
| **P1** | OPT-03 | 统一 REQ 编号权威源 | 5 min |
| **P1** | OPT-04 | 修正 Token 预算 | 2 min |
| **P1** | OPT-05 | 明确跳过与完整性关系 | 5 min |
| **P1** | OPT-06 | 明确占位符解析 | 3 min |
| **P2** | OPT-07 | 抽取公共常量 | 15 min |
| **P2** | OPT-08 | 修复门控脚本 | 10 min |
| **P2** | OPT-09 | 添加交叉引用索引 | 10 min |

### 7.3 风险评估

- **最高风险**：OPT-01（group2 执行顺序）— 如果 LLM 按错误顺序执行，可能导致性能优化（step3）在控制逻辑（step4）之前完成，而 step3 本应参考 step4 的 FSM 状态数
- **次高风险**：OPT-02（交付文件数）— 评估标准与实际交付不一致，可能导致评估漏检
- **其余风险**：均为中低风险，不影响核心流程正确性
