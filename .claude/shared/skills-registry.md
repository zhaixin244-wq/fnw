# Skills 调用注册表（共享）

> 按使用频率分为两层。Agent 定义中内联高频核心 Skills，其余按需从此表查找。
>
> **调用方式**：通过 `Skill` 工具调用。调用失败时按降级策略内化执行（见下方降级策略）。

---

## 高频核心 Skills（Agent 定义中直接引用）

> 每个 Agent 启动/执行时大概率会用到的，内联到 Agent 定义的"Skills 调用偏好"中。

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `rag-query` | 从 `.claude/knowledge/` 检索协议/CBB 文档 | 每个 Agent 启动时的 RAG 检索 |
| `smart-explore` | AST 结构化分析已有代码，4-8x token 节省 | 需要分析已有 RTL/网表时 |
| `verification-before-completion` | "证据先于声明"铁律：逐项验证 | 每个步骤完成时的质量检查 |
| `brainstorming` | 9 步硬门控探索流程 | 需求探索启动时 |
| `systematic-debugging` | 四阶段根因分析法 | 时序不收敛 / 架构缺陷分析时 |
| `architecture-decision-records` | Nygard ADR 格式记录 | 用户在 2+ 方案间做选择时 |

---

## 按需调用 Skills（从注册表查找，不在 Agent 定义中内联）

### 芯片专用

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `chip-doc-structurer` | 文档章节结构 + 内容权重 | FS/微架构编写启动时 |
| `chip-diagram-generator` | D2 模块框图、数据通路图、状态机图（dagre 布局） | 需要可视化架构时（已被 chip-png-d2-gen 替代） |
| `chip-png-d2-gen` | D2 架构图/流程图/状态机→PNG（dagre布局） | 需要生成可渲染的架构框图PNG时 |
| `chip-png-wavedrom-gen` | Wavedrom JSON 时序图→PNG | 需要生成可渲染的时序图PNG时 |
| `chip-png-interface-gen` | Verilog模块声明→接口端口PNG图 | 需要生成接口端口图PNG时 |
| `chip-interface-contractor` | 精确接口契约（端口表 + 时序 + SVA） | 定义接口时 |
| `chip-ppa-formatter` | 结构化 PPA 表（Target/Budget/Estimated） | 输出 PPA 预估时 |
| `chip-traceability-linker` | RTM 需求追溯矩阵 + 覆盖率统计 | 编写 RTM 或检查追溯时 |
| `chip-design-space-explorer` | Area-Performance-Power 三维 DSE | 多方案比选时 |
| `chip-budget-allocator` | 系统级 PPA 到子模块的预算拆解 | 顶层微架构 PPA 分配时 |
| `chip-cdc-architect` | CDC 信号表 + 同步策略选择 | 跨时钟域设计时 |
| `chip-low-power-architect` | Power Domain + Isolation + UPF | 低功耗设计时 |
| `chip-reliability-architect` | ECC/Parity/TMR + 老化裕量 | 可靠性设计时 |
| `chip-rtl-guideline-generator` | 5 维编码规范（Clock/Reset/DFT/SVA） | 生成 RTL 实现指导时 |
| `chip-protocol-compliance-checker` | 协议合规逐条核对 | 检查总线接口合规性时 |
| `chip-review-checklister` | 9 维度评审清单 + 完整性评分 | 架构评审时 |
| `chip-version-diff-generator` | 版本间架构变更对比 | 有历史版本需要对比时 |

### 计划与执行

| Skill | 用途 | 调用时机 | 边界说明 |
|-------|------|----------|----------|
| `writing-plans` | 从规格生成详细的分步实现计划 | 有明确规格，需要写计划文档时 | **输出**：计划文档 |
| `make-plan` | 编排型计划生成（分 phase，可跨 session 执行） | 大型任务需要跨 session 分阶段执行时 | **输出**：分 phase 计划，供 `do` 执行 |
| `do` | 部署子 agent 执行 `make-plan` 生成的计划 | 有现成计划，需要编排子 agent 执行时 | **输入**：`make-plan` 的输出 |
| `executing-plans` | 分阶段计划执行 + 检查点 | 从架构计划到 RTL 实现 | 有检查点的渐进执行 |
| `subagent-driven-development` | 当前 session 内为独立任务派发子 agent + 两阶段 review | 计划中的任务独立性强，session 内并行时 | 区别于 `do`：不跨 session |
| `dispatching-parallel-agents` | 2+ 完全独立的调查/分析任务并行派发 | 多个不相关 bug/分析任务并行时 | 纯调查型，`subagent` 是实现型 |

### 质量与验证

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `verification-loop` | 多轮验证（Lint/CDC/Synthesis） | RTL 交付前质量门禁 |
| `skill-comply` | Agent 行为合规测量 | 验证 agent 是否遵循 skills 规范 |
| `skill-stocktake` | Skills 质量审计 | 定期维护 skills 库 |
| `rules-distill` | 从实践中提取规则 | 沉淀编码规范和最佳实践 |

### 上下文管理

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `strategic-compact` | 在逻辑阶段边界手动 compact，保留关键上下文 | 长对话接近 context 上限时 |
| `context-budget` | 审计各组件（Agent/Skill/规则）的 token 消耗 | 性能下降或新增组件前评估空间 |
| `code-tour` | 代码架构导览 | RTL 评审/理解已有设计时 |
| `codebase-onboarding` | 项目结构分析与入门指南 | 新项目/已有项目结构分析时 |

---

## 降级策略

| 场景 | 行为 |
|------|------|
| Skill 调用失败 | 将该功能**内化执行**，输出中注明 "内化执行" |
| 知识库无相关文档 | 回退到 LLM 通用知识，标注来源缺失 |
