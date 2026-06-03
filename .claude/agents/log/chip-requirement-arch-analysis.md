# chip-requirement-arch 全文件分析报告

> 分析日期：2026-06-03
> 分析范围：Agent 定义 + 4 个 includes + 10 个引用 JSON + 示例 + 评估标准 + 变更日志
> 分析维度：清晰度 / 结构化程度 / LLM 歧义 / 跨文件矛盾 / 数字与规则一致性

---

## 一、文件清单与依赖图

### 1.1 核心文件（4 个）

| 文件 | 版本 | Token 估算 | 角色 |
|------|------|-----------|------|
| `agents/chip-requirement-arch.md` | v12.0 | ~4K (L0) | Agent 主定义 |
| `shared/agent-common-base.md` | - | ~2K | 公共基座（includes） |
| `shared/todo-mechanism.md` | - | ~1.2K | 代办清单（includes） |
| `shared/sdd-spec-traceability.md` | - | ~3K | SDD 追溯（includes） |
| `shared/change-propagation-v2.md` | - | ~2.5K | 变更传播（includes） |

### 1.2 L1 启动层文件（4 个）

| 文件 | 版本 | Token 估算 |
|------|------|-----------|
| `shared/context-layers.json` | v1.0 | ~0.5K |
| `shared/requirement-template.json` | v1.3 | ~1.4K |
| `shared/flow/stage-definition.json` | v1.0 | ~1.0K |
| `shared/todo-mechanism.md` | - | (已在 includes) |

### 1.3 L2 阶段层文件（10 个）

| 文件 | 版本 | 加载时机 |
|------|------|----------|
| `shared/requirement-checklist.json` | v1.3 | stageB phase1 |
| `shared/flow/stageB-detail.json` | v1.3 | stageB phase1 + phase2 |
| `shared/flow/execution-hints.json` | v1.4 | stageB phase1 (按需) |
| `shared/flow/protocol-mapping.json` | v1.0 | stageB phase1 (按需) |
| `shared/conflict-detection-rules.json` | v1.5 | stageC phase1 |
| `shared/flow/stageC-phase1-detail.json` | v1.3 | stageC phase1 |
| `shared/flow/stageC-detail.json` | v1.3 | stageC phase2 |
| `shared/flow/stageD-detail.json` | v2.0 | stageD |
| `shared/solution-template.json` | v1.3 | stageD |
| `shared/flow/area-estimation.json` | v1.0 | stageD (按需) |
| `shared/flow/e-stage-detail.json` | v2.0 | stageE |

### 1.4 辅助文件（3 个）

| 文件 | 角色 |
|------|------|
| `agents/examples/chip-requirement-arch-stage0-C-example.md` | 示例对话 |
| `evaluation_criteria/chip-requirement-arch-eva.md` | 评估标准 |
| `agents/log/chip-requirement-arch-changelog.md` | 变更日志 |

---

## 二、逐文件分析

### 2.1 Agent 主定义（chip-requirement-arch.md）

**清晰度：⭐⭐⭐⭐ (4/5)**
- 角色定义清晰，三条铁律简洁有力
- L0/L1/L2 分层设计合理，token 预算控制到位
- stageD group/step 编码表完整，20 个子阶段一目了然

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 分层架构（L0 常驻 → L1 启动 → L2 阶段）是优秀的 token 管理设计
- 编码规则速查表便于 LLM 快速定位
- 结构化标记规范（[STAGE-START] 等）标准化程度高

**LLM 歧义风险：⚠️ 中等**
- **问题 1**：stageB phase2 的 REQ 编号起始值。主定义说"从 REQ-029 起"，但 requirement-template.json 也说"从 REQ-029 起"，而 requirement-checklist.json 有 28 项（REQ-001~REQ-028）。如果 stageB phase1 确认的 28 项中有些被标记为"跳过"或"不适用"，追加 REQ 仍从 029 起？还是从实际确认的最大编号+1？**存在歧义**。
- **问题 2**：stageD group1-step1 的"RTL 行数 > 3000 行"阈值。主定义和 stageD-detail.json 都说 3000，但 e-stage-detail.json 的 `max_recursion_depth` 是 5。如果递归 5 层后仍有子模块 > 3000 行怎么办？**未定义兜底行为**。
- **问题 3**：stageD 的 `stageD group5-step3` 名称是"DFX 设计"，但主定义 §L2 阶段层注入内容写的是"DFT 设计"，stage-definition.json 写的也是"DFX"。**DFX vs DFT 混用**。

**跨文件矛盾：见第四章**

---

### 2.2 公共基座（agent-common-base.md）

**清晰度：⭐⭐⭐⭐ (4/5)**
- 四个章节职责分明（交互/降级/Wiki/权限）
- Wiki 三层知识系统架构清晰
- 文件权限规则有明确的越权处理流程

**结构化程度：⭐⭐⭐⭐ (4/5)**
- 降级策略表格式统一
- Wiki 检索流程三阶段定义明确

**LLM 歧义风险：⚠️ 低**
- **问题 1**：§三 Wiki 检索协议的"铁律"说"每次涉及协议/接口/CBB/选型/编码前，必须先完成 Wiki 检索"。但 stage0/stageA 阶段尚未确定具体协议，此时是否需要 Wiki 检索？**边界条件不明确**。
- **问题 2**：§四文件权限规则说".claude/ 目录仅影可修改"，但 Agent 的 `includes` 引用了 `.claude/shared/` 下的文件。如果 Agent 需要更新这些文件（如修复错误），是否需要转交影？**实际操作中可能造成摩擦**。

---

### 2.3 代办清单（todo-mechanism.md）

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 步进模式 vs 调试模式的区分非常清晰
- 关键决策点（方案选择/输入缺失/架构疑问/范围变更）定义明确
- 批量确认优化提供了灵活的交互方式

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 清单格式模板标准化
- 调试模式输出物定义完整

**LLM 歧义风险：✅ 极低**
- 无明显歧义点

---

### 2.4 SDD 追溯规范（sdd-spec-traceability.md）

**清晰度：⭐⭐⭐⭐ (4/5)**
- 全链路追溯模型（REQ→FS→BDD→UA→RTL→SVA→UVM）清晰
- L1~L11 层级定义完整
- 追溯图 YAML Schema 定义明确

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 12 个章节层次分明
- Agent 追溯职责表一目了然

**LLM 歧义风险：⚠️ 低-中**
- **问题 1**：§10.1 L1 层 REQ 编号格式写"三位数字，001~999。超过 999 时扩展为 REQ-{NNNN}"。但主定义的 SDD 编号规范说"REQ-XXX（三位数字）"，未提及扩展规则。**扩展规则仅在追溯规范中定义，主定义未引用**。
- **问题 2**：§9.3 追溯图更新规则说"不可删除，只能标记废弃"，但未定义废弃节点的清理策略。长期累积可能导致追溯图膨胀。

---

### 2.5 变更传播（change-propagation-v2.md）

**清晰度：⭐⭐⭐⭐ (4/5)**
- 变更传播树状图直观
- 各阶段变更源与影响表完整
- Critical/Major/Minor 分级明确

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 7 个章节覆盖全链路
- 版本号更新规则和级联规则清晰

**LLM 歧义风险：⚠️ 低**
- **问题 1**：§3.3 影响分析规则中"PPA 指标大幅调整"标记为 Critical，但"大幅"未量化。>20%？>50%？**缺乏量化阈值**。

---

### 2.6 context-layers.json

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 分层架构定义精确
- Token 预算逐层标注
- 加载序列清晰

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- JSON 结构规范
- 优化策略有状态追踪

**LLM 歧义风险：✅ 极低**

---

### 2.7 requirement-template.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 流程骨架完整
- 输入分诊逻辑清晰
- Skill 契约定义明确

**结构化程度：⭐⭐⭐⭐ (4/5)**
- 各 stage 定义有 trigger/output/transition
- 异常处理场景覆盖

**LLM 歧义风险：⚠️ 中等**
- **问题 1**：`input_triage` 的判定规则"≥6项约束维度且>500字 → complete"。"6项约束维度"是指用户输入中提及的不同约束类别数？还是 requirement-checklist.json 中的 seq 编号？**判定标准不明确**。
- **问题 2**：`exception_handling` 中"用户跳过确认直接出方案"的 `force_completion: true` 行为。这与 todo-mechanism.md 的"每步必须暂停等待用户确认"存在**潜在冲突**。虽然 exception_handling 有 4 步补救措施，但"强制完成"的语义与"步进模式"矛盾。
- **问题 3**：stageC phase2 的 `schema_version: "1.0"` 与 requirement-checklist.json 的 `version: "1.3"` 不一致。**版本号含义不同但字段名相同，容易混淆**。

---

### 2.8 stage-definition.json

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 统一编码规则是本 Agent 体系的核心改进
- 旧→新映射表便于迁移
- 校验规则（正则表达式）精确

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 嵌套结构清晰（stage → phases/groups → steps）
- file_mapping 集中管理依赖

**LLM 歧义风险：⚠️ 低**
- **问题 1**：`old_to_new_mapping` 中"D1"映射到"stageD group1-step3 / stageD group2-step1"，"D2"映射到"stageD group2-step1 / stageD group2-step4"。旧 D1 和 D2 都映射到 group2-step1，说明旧编码存在重叠。映射表标注"仅作历史参考"，但如果 Agent 需要处理旧格式输入，**重叠可能导致歧义**。

---

### 2.9 requirement-checklist.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 28 项约束清单完整
- category 分类合理（independent/conditional/infer_from_position 等）
- hint_ref 机制有效压缩 token

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 每项有 seq/id/name/q/cat/hint_ref/dep
- trigger_rules 有关键词规则和语义判断

**LLM 歧义风险：⚠️ 中等**
- **问题 1**：`not_applicable_rules` 中"含糊敷衍"的处理："追问 1 次→A/B 二选一；追问 2 次仍敷衍→强制用推荐值"。但 `vague_input_probing_strategy` 中说"追问上限仍为 2 次"。两处的追问上限一致（2 次），但**处理策略不同**：checklist 说"强制用推荐值"，probing 说"2 次追问后使用推荐值，但必须标注'基于通用知识，待用户确认'"。**标注要求不一致**。
- **问题 2**：REQ-026 的 cat 是 "conditional_optional"，但 stageC-detail.json 的 priority_grading 默认规则说"REQ-026 → Should（封装约束在芯片级项目中重要）"。conditional_optional 通常意味着"大多数情况跳过"，但 Should 意味着"应尽量满足"。**分类与优先级存在张力**。

---

### 2.10 conflict-detection-rules.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 17 条基础规则覆盖全面
- 每条规则有 id/name/logic/example/involved_keys/detection_tip
- 条件规则和实验性规则独立文件，按需加载

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 分层设计（基础/条件/实验）优秀
- 输出格式模板标准化

**LLM 歧义风险：⚠️ 低-中**
- **问题 1**：部分规则的 `ref_values_key` 引用 `reference-values.json`，但该文件未在本次分析中读取。如果 reference-values.json 中的数值与 execution-hints.json 中的行业典型值不一致，**可能导致矛盾检测误判**。
- **问题 2**：CDC-01 规则的 `arch_review_cross_ref` 引用了 "arch-review/cdc-reset-timing-rules.json CDC-01~06"。这引入了跨子系统的编号冲突风险——conflict-detection 的 CDC-01 和 arch-review 的 CDC-01 是不同的规则。**编号空间未隔离**。

---

### 2.11 solution-template.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 方案比选框架完整
- 比较表模板 13 个维度全面
- 敏感性分析定义明确

**结构化程度：⭐⭐⭐⭐ (4/5)**
- single_solution_elements 列表 20 项，覆盖全面
- adr_brainstorm_record 格式标准化

**LLM 歧义风险：⚠️ 中等**
- **问题 1**：`single_solution_elements` 中"存储设计"的 requirement 写"stageD group3-step3 + group3-step4 产出"，但 group3-step3 是链表设计，group3-step4 是寄存器定义。SRAM 设计是 group3-step1，FIFO 是 group3-step2。**引用错误**——应为 group3-step1 + group3-step2。
- **问题 2**：`sensitivity_analysis` 的触发条件"方案对比完成后、推荐方案前自动执行"。但 stageD 的执行流程中，方案对比和推荐在哪个 group/step？**未明确绑定到具体子阶段**。

---

### 2.12 stageB-detail.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 8 步执行流程清晰
- 6 种 category 处理规则明确
- 头脑风暴 5 维度定义完整

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- vague_input_probing_strategy 独立成节
- realtime_conflict_check_pairs 定义明确

**LLM 歧义风险：⚠️ 中等**
- **问题 1**：`post_stageB_brainstorming` 的 `new_req_persistence.blocking_rule` 说"未写入 requirement_summary 的 REQ 不得进入 stageC phase1"。但主定义的 stageB phase2 输出物写"output/{module}_requirement_summary_v1.0.md 中追加 REQ-029+"。如果 requirement_summary 在 stageC phase2 才首次生成（主定义 §文件写入时机），那 stageB phase2 如何追加到一个尚不存在的文件？**文件创建时机矛盾**。
- **问题 2**：`multi_round_rules.termination_conditions` 有 3 个条件，但 `max_rounds: 5`。如果 5 轮内用户从未明确说"没有更多需求"，而是每轮都提出新 REQ，Agent 在第 5 轮后是否强制结束？**强制结束的行为未定义**。

---

### 2.13 stageC-phase1-detail.json

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- post_stageB_processing 的 CDC 模板自动生成逻辑清晰
- experimental_feedback 的反馈收集流程完整
- end_to_end_coverage 的端到端视图定义明确

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 触发条件（active/conditional_load/passive）三路分明
- 覆盖率分析输出格式标准化

**LLM 歧义风险：✅ 极低**

---

### 2.14 stageC-detail.json

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 灰色表达系统化处理是亮点
- 优先级分级规则有动态覆盖机制
- 变更冷却机制（3 次上限）防止死循环

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 团队协作角色权重定义明确
- 冻结/解冻规则清晰

**LLM 歧义风险：⚠️ 低**
- **问题 1**：`priority_grading.default_rules` 中 REQ-026 的默认是 "Should"，但 `dynamic_overrides` 中 REQ-026 的 `default` 也是 "Should"，`override` 是 "Must"（chip_level 场景）。这意味着 REQ-026 的"默认"在两处定义一致，但**conditional_optional 的 cat 与 Should 的默认优先级之间的逻辑关系未解释**。

---

### 2.15 stageD-detail.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 20 个子阶段定义完整，每个有 input_analysis/brainstorm_focus/output/skip_condition
- 条件跳过规则 12 条覆盖全面
- min_qa_pairs 逐子阶段定义

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- context_isolation 配置精确
- wiki_brainstorm_integration 的搜索映射 20 个子阶段全覆盖

**LLM 歧义风险：⚠️ 中等**
- **问题 1**：`sub_stages` 中 stageD group3-step4（寄存器定义）的 `depends_on` 是 `["stageD group1-step1"]`，但其 `input_analysis.source` 包含 "stageD group5-step5 接口定义"。group5-step5 在 group3-step4 之后执行（按 phase_execution_order）。**依赖关系与输入来源矛盾**——它依赖一个尚未执行的子阶段的输出。
- **问题 2**：stageD group2-step3（性能优化）的 `depends_on` 是 `["stageD group2-step1", "stageD group2-step4"]`。但 group2-step4 在 group2-step3 之前执行（step 顺序 1→2→3→4？还是 1→2→4→3？）。按 sub_stages 数组顺序，step3 在 step4 前面，但 depends_on 说 step3 依赖 step4。**执行顺序与依赖关系矛盾**。
- **问题 3**：`conditional_skip_rules` 中 stageD group2-step3 的跳过条件是 "REQ-004 为 Could 级且无明确性能要求"。但 `conditional_skip_enhancement.verification_rules` 中同一子阶段的验证规则是 "检查 REQ-004 优先级"。如果 REQ-004 是 Should（非 Could 也非 Must），是否跳过？**边界条件不明确**。
- **问题 4**：`f_stage.scope_boundary.excluded` 包含"顶层模块 RTL 代码生成"和"系统级 Lint"，标注"delegated_to: chip-top-integrator"。但主定义 stageF 的输出物包含"拓扑图 + 接口检查"。如果 F 阶段不做 RTL，那"接口检查"的深度是什么级别？**职责边界需更精确**。

---

### 2.16 e-stage-detail.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 递归分解流程 5 步清晰
- 自包含 todolist 10 个 section 定义完整
- 规则重载机制和上下文隔离机制是解决注意力飘逸的关键设计

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 标准化 todolist 模板详尽
- 目录结构统一规则（level pattern）清晰

**LLM 歧义风险：⚠️ 中等-高**
- **问题 1**：`directory_creation.unified_structure.level_0_top` 的 outputs_files 列表包含 6 个文件（pr/requirement_summary/solution/ADR/trace_graph/todolist），但 `submodule_deliverables.required_files` 只有 5 个（不含 todolist）。而 `output_files.submodule_deliverables.files` 也是 5 个。**顶层 6 文件 vs 子模块 5 文件的差异未解释**——todolist 是仅顶层需要？还是子模块也需要（如"子模块 todolist：如有下级模块"）？
- **问题 2**：`self_contained_todolist.sections` 的 S7 是"Wiki 知识库参考"，但 `rule_reload_mechanism.reload_files` 中没有 Wiki 相关的重载项。**自包含 todolist 包含 Wiki 参考，但规则重载不包含 Wiki 检索规则**。
- **问题 3**：`submodule_execution_flow.start_stage` 是 "stageB phase2"，但 `parent_requirement_sync.timing` 是"子模块 stageB phase2 开始前"。这意味着子模块的完整流程是：parent_requirement_sync → stageB phase2 → stageC → stageD。但 `tree_todolist.template` §3 阶段 3 的步骤 6 写的是 "stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD -> stageE"，**未包含 parent_requirement_sync 步骤**。流程定义不完整。
- **问题 4**：`context_isolation.subagent_inputs` 的 S-02 来源是 "{name}/todolist.md"，但 todolist 的路径在 `tree_todolist.template` 中定义为 "<module>_work/ds/doc/pr/e_stage_tree_todolist.md"。子模块的 todolist 是独立文件还是主 todolist 的一部分？**路径不一致**。

---

### 2.17 area-estimation.json

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 逻辑/存储/IO 三部分估算框架清晰
- kGates→mm² 换算表按工艺节点提供
- 参考值示例实用

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 输出格式模板标准化

**LLM 歧义风险：✅ 极低**

---

### 2.18 protocol-mapping.json

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 三层分类（basic/highspeed/mixed）合理
- 映射关系明确

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**

**LLM 歧义风险：✅ 极低**

---

### 2.19 execution-hints.json

**清晰度：⭐⭐⭐⭐ (4/5)**
- 28 项执行提示覆盖完整
- 每项有具体操作指导和行业参考值

**结构化程度：⭐⭐⭐⭐ (4/5)**
- 纯文本格式，缺少结构化字段（如 trigger_condition/output_format）

**LLM 歧义风险：⚠️ 低**
- **问题 1**：REQ-001 的 hint 提供了行业典型 Fmax 参考值（28nm 400-500MHz），但 area-estimation.json 的 `kGates_to_mm2` 提供的是面积换算。两者的工艺节点范围一致（28nm/16nm/7nm/5nm），但**未交叉验证数值一致性**。

---

### 2.20 评估标准（chip-requirement-arch-eva.md）

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 10 个维度、100 分制评分体系完整
- 门控检查 18 项（G-01~G-18）定义明确
- 验证脚本可直接执行

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**
- 评分流程 8 步严格按顺序
- 扣分项速查表 30+ 项

**LLM 歧义风险：⚠️ 中等**
- **问题 1**：版本号写"v6.0（同步 agent v12.0+）"，但门控检查引用的文件路径格式（outputs/{module}_requirement_summary_v1.0.md）使用的是 `outputs/` 前缀。而主定义的文件写入时机表使用 `output/`（无 s）。**路径前缀不一致**。
- **问题 2**：G-08 检查"子模块交付文件 ≥3"，但 e-stage-detail.json 定义子模块需要 5 个文件。G-08 的阈值 3 远低于标准 5。**门控阈值与交付标准不匹配**。
- **问题 3**：D4.2 检查"D 子阶段执行完整性"要求 "group1-step1~group5-step6 全部执行，Q&A ≥ 50"。但 20 个子阶段，每个 min_qa_pairs 最少 3 条，总计至少 60 条。50 的阈值低于理论最小值 60。**阈值设置不合理**。

---

### 2.21 示例对话（chip-requirement-arch-stage0-C-example.md）

**清晰度：⭐⭐⭐⭐⭐ (5/5)**
- 完整展示了 stage0→stageD 的流程
- 代办清单格式规范
- 对抗性评审集成展示

**结构化程度：⭐⭐⭐⭐⭐ (5/5)**

**LLM 歧义风险：⚠️ 低**
- **问题 1**：示例中 stageD group1-step1 说"单模块预估 ≤ 500 行 RTL"，然后直接进入 group1-step3。但主定义说 group1-step1 完成后应进入 group1-step2（CBB 选型）。示例跳过了 group1-step2，但**未标注跳过原因**（虽然 group1-step2 的 skip_condition 是"无CBB"，示例中应显式标注）。

---

## 三、跨文件矛盾清单

### 3.1 🔴 严重矛盾（需立即修复）

| # | 矛盾描述 | 文件 A | 文件 B | 影响 |
|---|----------|--------|--------|------|
| C-01 | **stageB phase2 追加 REQ 的写入目标文件在 stageC phase2 才首次创建** | stageB-detail.json (blocking_rule: "未写入 requirement_summary 不得进入 stageC") | 主定义 §文件写入时机 (stageC phase2 才写 requirement_summary) | Agent 执行时无法在 stageB phase2 写入尚不存在的文件 |
| C-02 | **stageD group2-step3 依赖 group2-step4，但数组顺序 step3 在 step4 前** | stageD-detail.json depends_on | stageD-detail.json sub_stages 数组顺序 | 执行顺序歧义：按数组顺序还是按依赖图？ |
| C-03 | **stageD group3-step4 依赖 group5-step5（尚未执行）** | stageD-detail.json depends_on | stageD-detail.json phase_execution_order | 输入来源引用了未来子阶段的输出 |
| C-04 | **solution-template.json "存储设计"引用了错误的子阶段** | solution-template.json single_solution_elements | stageD-detail.json sub_stages | 存储设计应引用 group3-step1+step2，非 group3-step3+step4 |
| C-05 | **评估标准 G-08 门控阈值（≥3 文件）与交付标准（5 文件）不匹配** | chip-requirement-arch-eva.md | e-stage-detail.json | 门控检查放水，可能遗漏不完整的交付 |
| C-06 | **文件路径前缀 outputs/ vs output/ 不一致** | chip-requirement-arch-eva.md | 主定义 §文件写入时机 | grep/find 命令可能找不到文件 |

### 3.2 🟡 中等矛盾（建议修复）

| # | 矛盾描述 | 文件 A | 文件 B |
|---|----------|--------|--------|
| M-01 | **DFX vs DFT 混用** | 主定义 §L2 阶段层 (DFT) | stage-definition.json (DFX) |
| M-02 | **REQ 扩展规则（>999 时 4 位）仅在追溯规范定义** | sdd-spec-traceability.md §10.1 | 主定义 §SDD 编号规范 |
| M-03 | **追问标注要求不一致** | requirement-checklist.json (强制用推荐值) | stageB-detail.json (标注"基于通用知识，待用户确认") |
| M-04 | **REQ-026 的 cat (conditional_optional) 与默认优先级 (Should) 逻辑关系不明** | requirement-checklist.json | stageC-detail.json |
| M-05 | **e-stage todolist 模板未包含 parent_requirement_sync 步骤** | e-stage-detail.json tree_todolist.template §3 | e-stage-detail.json submodule_execution_flow |
| M-06 | **子模块 todolist 路径不一致** | e-stage-detail.json context_isolation (S-02) | e-stage-detail.json tree_todolist (output_path) |
| M-07 | **评估标准 D4.2 Q&A 阈值（50）低于理论最小值（60）** | chip-requirement-arch-eva.md | stageD-detail.json min_qa_pairs |

### 3.3 🟢 轻微不一致（可选修复）

| # | 描述 | 文件 |
|---|------|------|
| L-01 | conflict-detection CDC-01 与 arch-review CDC-01 编号空间未隔离 | conflict-detection-rules.json |
| L-02 | stage-definition.json old_to_new_mapping D1/D2 重叠映射 | stage-definition.json |
| L-03 | context-layers.json stageC phase1 budget 描述有 3 个数值（典型/条件/含覆盖率） | context-layers.json |
| L-04 | changelog v7.4 提到"D 阶段每个 Phase 使用独立 subagent"，但 stageD-detail.json 的 context_isolation 是 group 级别而非 step 级别 | changelog vs stageD-detail.json |

---

## 四、数字与规则一致性检查

### 4.1 关键数字

| 数字 | 主定义 | checklist | stageB-detail | stageD-detail | e-stage-detail | 一致性 |
|------|--------|-----------|---------------|---------------|----------------|--------|
| stageB 约束项数 | 28 | 28 (REQ-001~028) | 28 | - | - | ✅ |
| 追加 REQ 起始编号 | REQ-029 | - | REQ-029 | - | - | ✅ |
| 追问上限 | 2 次 | 2 次 | 2 次 | - | - | ✅ |
| 关键 REQ 追问次数 | 2 次 | - | 2 次 | - | - | ✅ |
| 最大默认值数 | - | 5 | 5 | - | - | ✅ |
| RTL 行数阈值 | 3000 | - | - | 3000 | 3000 | ✅ |
| 最大递归深度 | - | - | - | - | 5 | ✅ |
| D 子阶段总数 | 20 | - | - | 20 | - | ✅ |
| min_qa_pairs 默认 | - | - | - | 3 | - | ✅ |
| 头脑风暴最大轮数 | 5 | - | 5 | - | - | ✅ |
| 变更冷却上限 | - | - | - | - | - | ✅ (stageC-detail: 3) |
| 矛盾检测基础规则数 | 17 | - | - | - | - | ✅ (conflict-rules: 17) |
| 评估门控 G-01 阈值 | ≥20 | - | - | - | - | ⚠️ (28 项中 ≥20 = 71%，与"≥70%"一致) |
| 评估门控 G-08 阈值 | ≥3 | - | - | - | ≥5 | ❌ (矛盾) |

### 4.2 关键规则

| 规则 | 定义位置 | 执行位置 | 一致性 |
|------|----------|----------|--------|
| 步进模式为默认 | todo-mechanism.md | 主定义 §L0 | ✅ |
| 每步暂停等待确认 | todo-mechanism.md | 主定义 + stageB-detail | ✅ |
| stageB phase2 强制执行 | 主定义 §stageB phase2 | stage-definition.json | ✅ |
| stageD 输出统一文档 | 主定义 §stageD | stageD-detail.json | ✅ |
| 对抗性评审自动触发 | 主定义 §对抗性评审 | stageD-detail.json adversarial_review_trigger | ✅ |
| Wiki 检索优先 | agent-common-base.md §三 | stageD-detail.json wiki_brainstorm_integration | ✅ |
| 灰色表达处理 | stageC-detail.json | stageB-detail.json trigger_rules | ⚠️ (两处定义有细微差异) |
| 强制完成 vs 步进模式 | requirement-template.json exception_handling | todo-mechanism.md | ⚠️ (潜在冲突) |

---

## 五、优化方案

### 5.1 🔴 P0：严重矛盾修复（6 项）

#### OP-01：修复 stageB phase2 文件写入时机矛盾

**问题**：stageB phase2 要求写入 requirement_summary，但该文件在 stageC phase2 才创建。

**方案**：
1. 在主定义 §文件写入时机表中，将 requirement_summary 的创建时机提前到 stageB phase2
2. 或者，stageB phase2 的追加 REQ 写入 PR 沟通记录（flow/），stageC phase2 汇总时再合并到 requirement_summary
3. 推荐方案 2，因为 stageB phase2 的 REQ 尚未经过矛盾检测，不适合直接写入正式文档

**修改文件**：
- `agents/chip-requirement-arch.md`：§文件写入时机表，stageB phase2 目标改为 `flow/{module}_pr_v1.0.md`
- `shared/flow/stageB-detail.json`：`new_req_persistence.target` 改为 flow 文件，`blocking_rule` 改为"未写入 PR 记录不得进入 stageC"

#### OP-02：修复 stageD 子阶段依赖关系矛盾

**问题**：group2-step3 依赖 group2-step4（但数组顺序 step3 在 step4 前），group3-step4 依赖 group5-step5（尚未执行）。

**方案**：
1. stageD-detail.json 的 `phase_execution_order` 应基于依赖图拓扑排序，而非线性顺序
2. group2-step3 应在 group2-step4 之后执行
3. group3-step4 的 `depends_on` 应改为 `["stageD group1-step1"]`，`input_analysis.source` 中的 "stageD group5-step5" 改为 "stageC phase2 REQ-002 接口协议"（寄存器定义不需要等接口定义完成）

**修改文件**：
- `shared/flow/stageD-detail.json`：
  - group2-step3 的 depends_on 保持不变，但 sub_stages 数组顺序调整为 step1→step2→step4→step3
  - group3-step4 的 input_analysis.source 删除 group5-step5 引用
  - 补充 phase_execution_order 说明："按依赖图拓扑排序，非线性顺序"

#### OP-03：修复 solution-template.json 存储设计引用错误

**问题**：存储设计引用 group3-step3+step4，应为 group3-step1+step2。

**方案**：修改 `single_solution_elements` 中"存储设计"的 requirement。

**修改文件**：
- `shared/solution-template.json`：存储设计 requirement 改为 "stageD group3-step1 + group3-step2 产出：SRAM/FIFO 实例列表 + 深度计算依据"

#### OP-04：修复评估标准文件路径不一致

**问题**：outputs/ vs output/ 前缀不一致。

**方案**：统一为 `outputs/`（带 s），因为 e-stage-detail.json 和评估标准都使用 outputs/。

**修改文件**：
- `agents/chip-requirement-arch.md`：§文件写入时机表中所有 `output/` 改为 `outputs/`

#### OP-05：修复评估门控 G-08 阈值

**问题**：G-08 阈值 ≥3 远低于交付标准 5 文件。

**方案**：G-08 阈值改为 ≥5。

**修改文件**：
- `evaluation_criteria/chip-requirement-arch-eva.md`：G-08 PASS 条件改为"每个目录 ≥5"

#### OP-06：修复评估标准 D4.2 Q&A 阈值

**问题**：D4.2 阈值 50 低于理论最小值 60（20 子阶段 × 3 min_qa_pairs）。

**方案**：D4.2 阈值改为 ≥60。

**修改文件**：
- `evaluation_criteria/chip-requirement-arch-eva.md`：D4.2 满分条件改为 "Q&A ≥ 60"

---

### 5.2 🟡 P1：中等矛盾修复（7 项）

#### OP-07：统一 DFX/DFT 术语

**方案**：统一使用 DFX（Design for X，包含 DFT/调试/诊断），主定义 §L2 阶段层注入内容的"DFT 设计"改为"DFX 设计"。

**修改文件**：
- `agents/chip-requirement-arch.md`：§L2 阶段层 stageD group5-step3 注入内容描述

#### OP-08：补充 REQ 扩展规则到主定义

**方案**：在主定义 §SDD 需求编号规范中补充"超过 999 时扩展为 4 位数字"。

**修改文件**：
- `agents/chip-requirement-arch.md`：§SDD 需求编号规范

#### OP-09：统一追问标注要求

**方案**：以 stageB-detail.json 为准（更严格），checklist 的 not_applicable_rules 补充标注要求。

**修改文件**：
- `shared/requirement-checklist.json`：not_applicable_rules 中"含糊敷衍"的 action 补充"标注'基于通用知识，待用户确认'"

#### OP-10：补充 REQ-026 优先级逻辑说明

**方案**：在 stageC-detail.json 的 priority_grading 中补充说明：conditional_optional 的 REQ 在激活后按 default_rules 分配优先级，未激活时标记为"不适用"。

**修改文件**：
- `shared/flow/stageC-detail.json`：priority_grading 补充说明

#### OP-11：补充 e-stage todolist 模板的 parent_requirement_sync 步骤

**方案**：在 tree_todolist.template §3 阶段 3 步骤 6 前插入 parent_requirement_sync 步骤。

**修改文件**：
- `shared/flow/e-stage-detail.json`：tree_todolist.template §3

#### OP-12：统一子模块 todolist 路径

**方案**：明确子模块 todolist 为独立文件 `{name}_todolist.md`，存放在子模块 outputs/ 目录。

**修改文件**：
- `shared/flow/e-stage-detail.json`：context_isolation.S-02 路径改为 `{name}/outputs/{name}_todolist.md`

#### OP-13：补充 stageD 子阶段执行顺序说明

**方案**：在 stageD-detail.json 中明确说明执行顺序基于依赖图拓扑排序，并列出推荐执行顺序。

**修改文件**：
- `shared/flow/stageD-detail.json`：补充 `recommended_execution_order` 字段

---

### 5.3 🟢 P2：优化改进（5 项）

#### OP-14：隔离矛盾检测与架构评审的编号空间

**方案**：arch-review 的 CDC 规则改为前缀 `AR-CDC-`，避免与 conflict-detection 的 `CDC-` 混淆。

**修改文件**：
- `shared/flow/conflict-detection-rules.json`：CDC-01 的 arch_review_cross_ref 更新引用

#### OP-15：补充灰色表达处理的一致性定义

**方案**：将灰色表达处理规则统一维护在 stageC-detail.json，stageB-detail.json 通过引用方式使用。

**修改文件**：
- `shared/flow/stageB-detail.json`：trigger_rules.semantic_judgment 引用 stageC-detail.json 的 grey_expression_system

#### OP-16：补充 PPA "大幅调整"的量化阈值

**方案**：在 change-propagation-v2.md 中定义"大幅调整"为 >20%。

**修改文件**：
- `shared/change-propagation-v2.md`：§3.3 补充量化定义

#### OP-17：补充强制完成与步进模式的协调规则

**方案**：在 requirement-template.json 的 exception_handling 中明确：force_completion 仅在用户明确要求跳过确认时触发，且后续必须补确认。

**修改文件**：
- `shared/requirement-template.json`：exception_handling 补充协调说明

#### OP-18：补充 sensitivity_analysis 的子阶段绑定

**方案**：在 stageD-detail.json 的 stageD group5-step1（面积预估）中补充 sensitivity_analysis 触发点。

**修改文件**：
- `shared/flow/stageD-detail.json`：group5-step1 补充 sensitivity_analysis 触发

---

## 六、总结

### 6.1 整体评价

| 维度 | 评分 | 说明 |
|------|------|------|
| **清晰度** | ⭐⭐⭐⭐ (4/5) | 大部分文件清晰，少数术语混用（DFX/DFT）和路径不一致 |
| **结构化程度** | ⭐⭐⭐⭐⭐ (5/5) | 分层架构（L0/L1/L2）和编码规则（stage/phase/group/step）是优秀设计 |
| **LLM 可执行性** | ⭐⭐⭐⭐ (4/5) | 主要风险在依赖关系矛盾和文件创建时序，可能导致 Agent 执行卡死 |
| **跨文件一致性** | ⭐⭐⭐½ (3.5/5) | 6 个严重矛盾 + 7 个中等矛盾需要修复 |
| **规则完备性** | ⭐⭐⭐⭐ (4/5) | 覆盖全面，少数边界条件未定义（递归 5 层后兜底、强制结束行为） |

### 6.2 优先级排序

| 优先级 | 数量 | 预计工作量 | 风险 |
|--------|------|-----------|------|
| P0 严重矛盾 | 6 项 | 2-3 小时 | 不修复可能导致 Agent 执行卡死或产出错误 |
| P1 中等矛盾 | 7 项 | 1-2 小时 | 不修复可能导致规则理解偏差 |
| P2 优化改进 | 5 项 | 1 小时 | 提升一致性和可维护性 |

### 6.3 核心改进方向

1. **依赖关系治理**：stageD 子阶段的依赖图需要拓扑排序验证，避免循环依赖和前向引用
2. **文件生命周期管理**：明确每个文件的创建/追加/冻结时机，避免写入不存在的文件
3. **术语统一**：DFX/DFT、outputs/output、REQ 扩展规则等需要单一权威定义
4. **评估标准校准**：门控阈值和评分阈值需要与交付标准对齐
