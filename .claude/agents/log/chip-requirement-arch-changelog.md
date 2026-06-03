# chip-requirement-arch 变更日志

> 从 Agent 定义文件外置，减少常驻 context 消耗。
> Agent 激活时无需读取本文件，仅在需要追溯版本变更时按需 Read。

---

## v12.0 (2026-06-03)
- 方案 C 全面重构：统一编码规则（stage/phase/group/step），创建 stage-definition.json
- stageB phase2 写入目标修正为 PR 记录（非 requirement_summary），解决文件创建时序矛盾
- stageD 子阶段执行顺序铁律：recommended_execution_order 优先于 sub_stages 数组顺序
- DFX/DFT 术语统一为 DFX（Design for X）
- e-stage todolist 模板补充 parent_requirement_sync 步骤
- e-stage 子模块交付文件扩展为 6 个（含条件 todolist）
- 递归深度兜底行为定义：超过 5 层强制停止 + ADR 标注风险
- 评估标准阈值校准：G-17 ≥62，D4.2 ≥60，G-08 ≥5
- PPA "大幅调整" 量化阈值统一为 >20%
- stageB phase2 强制终止行为定义（5 轮后自动结束）
- input_triage 约束维度判定标准明确
- exception_handling 补充 step_mode_enforcement 标记

## v12.0-patch (2026-06-03) — 跨文件矛盾修复 + 可维护性优化
### P0 修复（严重矛盾）
- **OPT-01**：requirement-template.json sub_stages 数组 group2 内顺序修正为 step1→step2→step4→step3（与 recommended_execution_order 一致）
- **OPT-02**：e-stage-detail.json output_files 统一为 6 个文件（含 todolist），evaluation D5.5/G-08 同步更新

### P1 修复（LLM 歧义）
- **OPT-04**：context-layers.json stageB budget 修正为 ~4K tokens（与实际文件大小一致）
- **OPT-05**：evaluation D4.2 补充说明：条件跳过的子阶段不计入遗漏
- **OPT-06**：stageD-detail.json context_isolation 占位符从 `{N-1}` 改为具体文件名（group2→group1_summary, group3→group2_summary, group4→group3_summary, group5→group4_summary）

### P2 优化（可维护性）
- **OPT-07**：stage-definition.json 新增 constants 节，集中定义 18 个全局常量（RTL_LINE_THRESHOLD=3000, CONSTRAINT_ITEM_COUNT=28 等）
- **OPT-08**：evaluation G-08b 脚本完善，增加孙模块目录结构验证（outputs/flow/ 子目录检查）
- **OPT-09**：stage-definition.json 新增 file_to_stages 反向索引，20 个文件→引用 stage 映射

## v8.0~v11.0 (2026-06-01 ~ 2026-06-03)
- 中间版本为增量迭代，关键变更已合并至 v12.0

## v7.4 (2026-06-01)
- D 阶段上下文隔离：每个 Phase 使用独立 subagent 执行，Phase 间传递精简摘要（≤1K tokens），解决 D 阶段注意力飘逸问题
- D 阶段自包含 todolist：每个 Phase 的 todolist 包含执行所需的全部信息（输入上下文/Wiki 检索/子阶段 flow/RTL 检查/输出模板）
- D 阶段 RTL 就绪度检查：每个 Phase 完成后执行 8 项 RTL 就绪度检查，不通过阻断下一 Phase

## v7.3 (2026-06-01)
- D 阶段重组为 5 个 Phase：Phase1(架构规划) → Phase2(数据通路与流水线) → Phase3(存储与资源管理) → Phase4(流控与时钟域) → Phase5(优化与可靠性)
- D 子阶段编号改为 D_phase{X}-{Y} 格式（如 D_phase1-1 = 原 D0）
- 新增 D0b(CBB 模块使用规划)、D2b(流水线设计)、D12b(性能分析与优化)
- D 阶段 Wiki 集成头脑风暴：每轮头脑风暴前必须检索 Wiki 知识库

## v7.2 (2026-06-01)
- D 阶段新增 3 个子阶段：D0b(CBB 模块使用规划)、D2b(流水线设计)、D12b(性能分析与优化)
- D 阶段 Wiki 集成头脑风暴：每轮头脑风暴前必须检索 Wiki 知识库

## v7.1 (2026-06-01)
- B+ 新增 REQ 写入 requirement_summary：头脑风暴新增的 REQ 必须实时写入 outputs/{name}_requirement_summary_v1.0.md，未写入不得进入下一阶段
- 子模块同步父级需求：子模块进入 B+ 前，必须先分析父模块 requirement_summary，将适用的需求同步到本子模块

## v7.0 (2026-06-01)
- 去掉连续模式：仅支持步进模式，每步完成后必须暂停等待用户确认
- 新增调试模式：用户说"调试模式/debug mode/后台测试"时激活，Agent 后台自动执行全流程，输出评估报告和优化建议
- 非调试模式禁止后台执行：必须使用步进模式与用户逐一问答
- flow/ 完整记录：步进模式和调试模式均需完整输出每个 stage 的 Q&A 记录到 flow/ 目录

## v6.9 (2026-06-01)
- 上下文隔离机制：每个递归层级使用独立 subagent 执行，拥有全新上下文窗口（~7K tokens），仅传递精简输入（Agent 定义+todolist+父模块摘要+接口契约+继承约束），不传递父级完整历史，保证 L3 与 L0 拥有完全等同的规则注意力

## v6.8 (2026-06-01)
- 规则重载机制：每级子模块执行前重新读取 Agent 定义、编码规范、stageB 规则、本级 todolist，确保规则在上下文顶部

## v6.7 (2026-06-01)
- 自包含 todolist：每个 todolist 包含执行所需的全部信息（父模块上下文/接口契约/继承约束链/flow 定义/输出模板/Wiki 参考/质量门控）
- 防飘逸机制：父模块上下文摘要 + 接口契约 + 继承约束链 + flow 详细定义 + 输出模板 + 质量门控 + 完整性自检

## v6.6 (2026-06-01)
- 多级递归：递归不限于两级（子模块→孙模块），持续到所有叶子节点 <3000 行，目录为 level{N}_{name}/ 逐级嵌套
- 逐级执行：每级独立执行，通过该级 todolist 跟踪状态，先顶层再逐级子模块
- todolist 强制执行：子模块严格按上级 todolist 定义的 flow 执行，缺失则报错停止
- 全局完成检查：所有流程完成后扫描所有层级 todolist，确认全部 completed 才进入 F 阶段

## v6.5 (2026-06-01)
- E 阶段执行顺序优化：先生成顶层 outputs+todolist，再逐级生成子模块 outputs+todolist
- 统一目录结构：outputs/ 交付物目录 + flow/ 流程记录目录，适用于所有层级
- 子模块起始状态改为 B+ 阶段：子模块从 stageB+ 开始（头脑风暴 Feature Discovery）
- B+ 多轮头脑风暴：参考 Wiki 知识库，每轮后用户确认才进入下一阶段

## v6.4 (2026-06-01)
- E 阶段统一目录结构：子模块创建一级目录，孙模块在子模块目录下创建子目录，文件名={目录名}_{类型}.md

## v6.3 (2026-06-01)
- E 阶段强制目录创建：递归分解完成后立即为每个叶子节点创建子模块目录（mkdir -p）
- E 阶段强制 todolist：所有递归完成后必须生成 e_stage_tree_todolist.md，无 todolist 不得进入子模块 D 阶段
- 子模块完成检查：所有叶子节点 completed 后检查 5 个交付文件齐全，缺失则阻断 F 阶段
- 评估硬性门控：流程完整性门控（→D 级）+ 文档质量门控（→C 级）

## v6.2 (2026-06-01)
- stageB+ 头脑风暴 Feature Discovery：stageB 完成后使用头脑风暴 skill 与用户探索是否需要追加新 feature（REQ-029+），追加 REQ 逐一确认细节

## v6.1 (2026-06-01)
- E 阶段子模块交付文档等同主模块：每个子模块必须产出 5 个完整文件（PR/需求汇总/方案/ADR/追溯图）

## v6.0 (2026-06-01)
- E 阶段头脑风暴：每次子模块划分使用头脑风暴 skill 与用户确认划分原则
- E 阶段文档质量：子模块进入 D 阶段的文档必须达到 C 阶段出口文档质量标准
- E 阶段执行顺序：先完成所有 E~D0 递归，再生成 todolist，再逐个子模块确认
- E 阶段递归分解：支持多层级子模块递归分解，直到所有叶子节点 <3000 行
- D0 流程优化：先估算 RTL 总行数，超过 3000 行直接跳转 E 阶段
- F 阶段：顶层集成（接口一致性检查、拓扑图、方案文档 §14；RTL 代码和 Lint 由 chip-top-integrator 负责）
- 强化 stageB 关键 REQ 追问策略（REQ-004/016/020 追问 2 次）
- 添加 stageC0 覆盖率热力图输出
- 强化跳过 D 子阶段 ADR 标注（原因+影响+替代方案）
- 添加灰色表达系统化处理规则
- 添加文件版本号管理规范
- 强化 D 子阶段执行深度（min_qa_pairs）
- 添加实验性检测量化要求（EXP-05）
- 强化 D 子阶段跳过判断逻辑验证
