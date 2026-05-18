# FNW AI 芯片设计平台

> 本项目为芯片架构设计工作区，使用 AI Agent 辅助完成从需求探索到 RTL 实现的全流程。

---


---

## 项目概述

- **领域**：芯片/SoC 架构设计与 RTL 实现
- **语言**：Verilog-2005（可综合 RTL）+ SystemVerilog（仅 interface/typedef/SVA）
- **工具链**：oss-cad-suite（Verilator lint、Yosys 综合、gtkwave 波形查看）、d2（架构图）、wavedrom-cli（时序图）、playwright（自动化）
- **交互语言**：中文为主，技术术语保留英文（CDC、PPA、AXI、RTL 等）

---

## 目录结构

```
.
├── .claude/
│   ├── rules/                # 项目级规则（编码规范、模板、Agent 调用规则）
│   │   ├── coding-style.md          # RTL 编码规范（Verilog-2005）
│   │   ├── chip-agent-mandatory.md  # Agent 强制调用规则
│   │   ├── function-spec-template.md # FS 功能规格书模板
│   │   └── microarchitecture-template.md # 微架构文档模板
│   ├── shared/               # 共享配置与工具
│   │   ├── agent-common-base.md     # 公共基座（交互/降级/Wiki检索/权限）
│   │   ├── todo-mechanism.md        # 代办清单门控机制
│   │   ├── change-propagation-v2.md # 变更传播规则（全链路）
│   │   ├── chart-generation-spec.md # 图表生成规范
│   │   ├── quality-checklist-*.md   # 质量检查清单
│   │   ├── change-detect.sh         # 变更检测脚本
│   │   └── wiki-lint.sh             # Wiki 健康检查脚本
│   ├── commands/             # 用户可调用命令
│   │   ├── wiki-lint.md             # /wiki-lint 知识库健康检查
│   │   ├── wiki-ingest.md           # /wiki-ingest 源文件编译
│   │   ├── wiki-save.md             # /wiki-save 会话归档
│   │   └── rtl-lint.md              # /rtl-lint RTL 综合 lint
│   ├── hooks.json            # 会话 Hook
│   ├── wiki/                 # LLM 预编译结构化知识（已迁移到 tools/claude-obsidian/wiki/）
│   ├── knowledge/            # 原始协议/CBB 文档（已迁移到 tools/claude-obsidian/.raw/sources/）
│   └── tools/                # 工具链
│       ├── oss-cad-suite/           # Verilator/Yosys/gtkwave
│       ├── verible/                 # Verible lint/format/LSP 工具
│       ├── claude-obsidian/         # claude-obsidian 知识管理工具（git clone）
│       ├── DeepTutor/               # 知识探索工具
│       └── update-claude-obsidian.sh # 更新脚本
├── work/                     # 项目工作区
│   ├── data_adpt_work/       # 数据适配器模块工作区（当前项目）
│   │   ├── ds/
│   │   │   ├── doc/pr/       # 需求/方案/ADR 文档
│   │   │   ├── doc/fs/       # FS 功能规格书 + 图表
│   │   │   ├── doc/ua/       # 微架构文档 + 图表
│   │   │   └── rtl/          # RTL 代码
│   │   └── ...
│   └── pcie_rtag_ctrl/       # PCIe RTAG 控制器项目
├── doc/                      # 项目级文档（介绍、PPT 等）
├── memory/                   # 跨会话记忆
└── requirements.txt          # Python 依赖
```

---

## 核心工作流

芯片设计遵循 **需求探索 → 方案论证 → FS → 微架构 → RTL 实现 → 综合 → 集成 → 验证 → 评审** 的流程：

| 阶段 | 专用 Agent | 输出物 |
|------|-----------|--------|
| 项目管理/风险管控 | `chip-project-lead` | 项目全景图、风险登记表、进度报告、汇报材料 |
| 需求探索/方案论证 | `chip-requirement-arch` | requirement_summary、solution、ADR |
| FS 功能规格书 | `chip-fs-writer` | {module}_FS_v{X}.md |
| UA 微架构文档 | `chip-microarch-writer` | {module}_{sub}_microarch_v{X}.md |
| RTL 代码实现 | `chip-code-writer` | .v / .sv / _sva.sv / _tb.v |
| 综合/时序分析 | `chip-sta-analyst` | .sdc、综合报告、时序报告、面积报告 |
| 顶层集成 | `chip-top-integrator` | {module}_top.v、接口检查报告、系统 lint 报告 |
| 低功耗设计 | `chip-lowpower-designer` | .upf、功耗方案文档、功耗分析报告 |
| DFT 设计 | `chip-dft-engineer` | DFT 架构文档、DFT 检查报告、MBIST 集成指南 |
| 架构评审 | `chip-arch-reviewer` | 评审报告 |
| 验证架构 | `chip-verfi-arch` | 测试点分解、验证环境方案、用例规划、覆盖率模型 |
| 验证环境/TB 实现 | `chip-env-writer` | UVM 验证环境代码（Agent/Driver/Monitor/Scoreboard/Coverage/Env/Test/TB Top） |
| 驱动架构规划 | `chip-sw-driver` | 驱动架构规格书、API 接口规格、寄存器映射方案、驱动集成指南 |
| 固件代码实现 | `chip-firmware-writer` | 寄存器头文件（.h/.svh）、驱动源码、测试程序、初始化脚本 |
| 软件验证 | `chip-sw-verifier` | 测试计划、单元测试、集成测试、Mock 硬件层、覆盖率报告 |
| 代码审查 | `chip-sw-reviewer` | 审查报告（静态分析、安全审查、编码规范、API 一致性） |
| 性能分析 | `chip-sw-profiler` | 性能报告（延迟分析、吞吐分析、热点函数、优化建议） |

---

## 强制规则

### 1. 芯片任务必须使用专用 Agent

RTL/FS/UA/评审/验证/验证环境相关任务**禁止手动生成**，必须调用对应专用 Agent。详见 `.claude/rules/chip-agent-mandatory.md`。

**唯一例外**：
- 仅读取/搜索现有代码
- 仅回答代码解释性问题
- 修改量极小（<5 行）且用户明确要求手动
- 非芯片任务（项目管理、git、文档格式）

### 2. 知识检索优先

涉及协议/接口/CBB/选型/编码前，**必须先完成 Wiki 检索**。流程：`index.md` → wiki 页面 → 原始文档（按需）。详见 `.claude/shared/agent-common-base.md` §三。

### 3. 代办清单门控

Agent 激活后**第一步必须输出代办清单**，标注每个步骤的预期输出物和执行组。支持步进模式（默认）和连续模式。详见 `.claude/shared/todo-mechanism.md`。

### 4. 编码规范

RTL 编码严格遵循 `.claude/rules/coding-style.md`，核心要点：
- Verilog-2005 + SV Interface（仅 interface/typedef/modport）
- 异步复位同步释放，低有效 `rst_n`
- 组合逻辑 `always @(*)` 必须赋默认值，case 必须有 default
- 禁止门控时钟（用标准 ICG）、禁止 task、禁止 casex/casez
- 子模块实例化必须名称关联
- generate 块必须有标签
- 注释覆盖率 >30%，禁止注水注释

### 5. Agent 执行模式

所有 Agent 调用**默认使用前台模式**（`run_in_background` 不设或设为 `false`），确保用户能实时看到 Agent 输出并与之交互。仅当用户明确要求"后台运行"时才使用 `run_in_background: true`。

### 6. 变更传播

上游文档变更时需判断是否触发级联更新。端口/FSM/FIFO/CBB 变更 → 强制重新实现。详见 `.claude/shared/change-propagation-v2.md`（全链路变更传播，覆盖 REQ→FS→BDD→UA→RTL→验证）。

---

## 文档模板

- **FS 模板**：`.claude/rules/function-spec-template.md`
- **微架构模板**：`.claude/rules/microarchitecture-template.md`
- **质量检查清单**：`.claude/shared/quality-checklist-fs.md`、`quality-checklist-microarch.md`、`quality-checklist-impl.md`

---

## 工具使用

| 工具 | 用途 | 命令 |
|------|------|------|
| Verilator | RTL 功能 lint | `verilator --lint-only -Wall {file}.v` |
| Verible Lint | RTL 风格 lint | `.claude/tools/verible/verible-verilog-lint.exe --rules_config=.claude/tools/verible/verible-lint.rules {file}.v` |
| Verible Format | RTL 自动格式化 | `.claude/tools/verible/verible-verilog-format.exe {file}.v` |
| Verible Syntax | RTL 语法检查 | `.claude/tools/verible/verible-verilog-syntax.exe {file}.v` |
| Yosys | 综合 | `yosys -p "read_verilog {file}.v; synth"` |
| d2 | 架构图/状态机图 | `d2 --layout dagre {file}.d2 {file}.png` |
| wavedrom-cli | 时序图 | `wavedrom-cli -i {file}.json -p {file}.png` |
| gtkwave | 波形查看 | `gtkwave {file}.vcd` |
| wiki-lint | 知识库健康检查 | `/wiki-lint` 或 `bash tools/claude-obsidian/.claude/shared/wiki-lint.sh` |
| wiki-ingest | 源文件编译为 wiki | `ingest {path}` 或 `/wiki-ingest {path}` |
| wiki-save | 会话归档 | `/save` 或 `/wiki-save` |

工具路径：
- Verilator/Yosys/gtkwave：`.claude/tools/oss-cad-suite/bin/`
- Verible：`.claude/tools/verible/`

---

## 降级策略

外部资源不可用时不中断工作流：RAG 无结果 → 标注"基于通用知识"继续；图表编译失败 → 保留源文件，降级为文本描述。详见 `.claude/shared/agent-common-base.md` §二。

---

## 记忆系统

本项目使用 **claude-mem** 作为核心记忆引擎，自动捕获跨会话经验。

### 工作原理

- 每次 Read/Edit/Bash 操作自动产生压缩 observation，存储在 `.claude/mem/`（SQLite + Chroma）
- 新会话启动时，相关 observation 自动注入 prompt（无需手动读取）
- Knowledge Agent corpus 提供语义查询能力

### Knowledge Agent Corpora

**共享记忆**（所有 Agent 可查询）：
- `chip-shared-protocols` — 协议知识（AXI/PCIe/NVMe/Virtio）
- `chip-shared-patterns` — RTL 设计模式（FIFO/仲裁器/CDC）
- `chip-shared-decisions` — 架构决策记录（ADR）
- `chip-shared-defects` — 缺陷修复记录
- `chip-shared-methods` — 方法学执行经验

**Agent 独享记忆**（仅对应 Agent 查询）：
- `chip-{agent}-memory` — 每个 Agent 的专属经验库

### 查询方式

```
search(query="关键词", project="fnw-arch")     — 搜索 observation
query_corpus name="corpus-name" question="问题" — 语义查询 corpus
list_corpora()                                   — 查看所有 corpus
```

### 与 Wiki 的关系

- **claude-mem**：动态经验积累（自动捕获，语义查询）
- **Wiki**：静态知识库（手动编译，精确规范）
- Agent 执行时先查 claude-mem 经验，需要精确规范时再读 Wiki

### Wiki 健康检查

定期运行 `wiki-lint` 检查知识库健康状态：
- 索引一致性、死链接、空页面、过期声明
- 格式一致性、来源追溯、孤立页面、交叉引用完整性

### Wiki Ingest

使用 `ingest` 或 `/wiki-ingest` 将 `.raw/sources/` 中的原始文档编译为结构化 wiki 页面：
- `ingest {path}` — 单文件编译
- `ingest all of these` — 批量编译所有未处理文件

知识库存储位置：`tools/claude-obsidian/wiki/`

<!-- superpowers-zh:begin (do not edit between these markers) -->
# Superpowers-ZH 中文增强版

本项目已安装 superpowers-zh 技能框架（20 个 skills）。

## 核心规则

1. **收到任务时，先检查是否有匹配的 skill** — 哪怕只有 1% 的可能性也要检查
2. **设计先于编码** — 收到功能需求时，先用 brainstorming skill 做需求分析
3. **测试先于实现** — 写代码前先写测试（TDD）
4. **验证先于完成** — 声称完成前必须运行验证命令

## 可用 Skills

Skills 位于 `.claude/skills/` 目录，每个 skill 有独立的 `SKILL.md` 文件。

- **brainstorming**: 在任何创造性工作之前必须使用此技能——创建功能、构建组件、添加功能或修改行为。在实现之前先探索用户意图、需求和设计。
- **chinese-code-review**: 中文 review 沟通参考——话术模板、分级标注（必须修复/建议修改/仅供参考）、国内团队常见反模式应对。仅在用户显式 /chinese-code-review 时调用，不要根据上下文自动触发。
- **chinese-commit-conventions**: 中文 commit 与 changelog 配置参考——Conventional Commits 中文适配、commitlint/husky/commitizen 中文模板、conventional-changelog 中文配置。仅在用户显式 /chinese-commit-conventions 时调用，不要根据上下文自动触发。
- **chinese-documentation**: 中文文档排版参考——中英文空格、全半角标点、术语保留、链接格式、中文文案排版指北约定。仅在用户显式 /chinese-documentation 时调用，不要根据上下文自动触发。
- **chinese-git-workflow**: 国内 Git 平台配置参考——Gitee、Coding.net、极狐 GitLab、CNB 的 SSH/HTTPS/凭据/CI 接入差异与镜像同步配置。仅在用户显式 /chinese-git-workflow 时调用，不要根据上下文自动触发。
- **dispatching-parallel-agents**: 当面对 2 个以上可以独立进行、无共享状态或顺序依赖的任务时使用
- **executing-plans**: 当你有一份书面实现计划需要在单独的会话中执行，并设有审查检查点时使用
- **finishing-a-development-branch**: 当实现完成、所有测试通过、需要决定如何集成工作时使用——通过提供合并、PR 或清理等结构化选项来引导开发工作的收尾
- **mcp-builder**: MCP 服务器构建方法论 — 系统化构建生产级 MCP 工具，让 AI 助手连接外部能力
- **receiving-code-review**: 收到代码审查反馈后、实施建议之前使用，尤其当反馈不明确或技术上有疑问时——需要技术严谨性和验证，而非敷衍附和或盲目执行
- **requesting-code-review**: 完成任务、实现重要功能或合并前使用，用于验证工作成果是否符合要求
- **subagent-driven-development**: 当在当前会话中执行包含独立任务的实现计划时使用
- **systematic-debugging**: 遇到任何 bug、测试失败或异常行为时使用，在提出修复方案之前执行
- **test-driven-development**: 在实现任何功能或修复 bug 时使用，在编写实现代码之前
- **using-git-worktrees**: 当需要开始与当前工作区隔离的功能开发或执行实现计划之前使用——创建具有智能目录选择和安全验证的隔离 git 工作树
- **using-superpowers**: 在开始任何对话时使用——确立如何查找和使用技能，要求在任何响应（包括澄清性问题）之前调用 Skill 工具
- **verification-before-completion**: 在宣称工作完成、已修复或测试通过之前使用，在提交或创建 PR 之前——必须运行验证命令并确认输出后才能声称成功；始终用证据支撑断言
- **workflow-runner**: 在 Claude Code / OpenClaw / Cursor 中直接运行 agency-orchestrator YAML 工作流——无需 API key，使用当前会话的 LLM 作为执行引擎。当用户提供 .yaml 工作流文件或要求多角色协作完成任务时触发。
- **writing-plans**: 当你有规格说明或需求用于多步骤任务时使用，在动手写代码之前
- **writing-skills**: 当创建新技能、编辑现有技能或在部署前验证技能是否有效时使用

## 如何使用

当任务匹配某个 skill 时，使用 `Skill` 工具加载对应 skill 并严格遵循其流程。绝不要用 Read 工具读取 SKILL.md 文件。

如果你认为哪怕只有 1% 的可能性某个 skill 适用于你正在做的事情，你必须调用该 skill 检查。
<!-- superpowers-zh:end -->
