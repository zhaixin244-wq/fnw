# FNW AI 芯片设计平台

> 本项目为芯片架构设计工作区，使用 AI Agent 辅助完成从需求探索到 RTL 实现的全流程。

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
│   │   ├── interaction-style.md     # 交互风格规范
│   │   ├── todo-mechanism.md        # 代办清单门控机制
│   │   ├── rag-mandatory-search.md  # Wiki 知识检索协议
│   │   ├── change-propagation.md    # 变更传播规则
│   │   ├── degradation-strategy.md  # 降级策略
│   │   ├── chart-generation-spec.md # 图表生成规范
│   │   ├── quality-checklist-*.md   # 质量检查清单
│   │   └── change-detect.sh         # 变更检测脚本
│   ├── wiki/                 # LLM 预编译结构化知识（协议/CBB/设计模式）
│   ├── knowledge/            # 原始协议/CBB 文档
│   └── tools/                # 工具链（oss-cad-suite 等）
├── data_adpt_work/           # 数据适配器模块工作区（当前项目）
│   ├── ds/
│   │   ├── doc/pr/           # 需求/方案/ADR 文档
│   │   ├── doc/fs/           # FS 功能规格书 + 图表
│   │   ├── doc/ua/           # 微架构文档 + 图表
│   │   └── rtl/              # RTL 代码
│   └── ...
├── doc/                      # 项目级文档（介绍、PPT 等）
├── memory/                   # 跨会话记忆
└── requirements.txt          # Python 依赖
```

---

## 核心工作流

芯片设计遵循 **需求探索 → 方案论证 → FS → 微架构 → RTL 实现 → 评审** 的流程：

| 阶段 | 专用 Agent | 输出物 |
|------|-----------|--------|
| 需求探索/方案论证 | `chip-requirement-arch` | requirement_summary、solution、ADR |
| FS 功能规格书 | `chip-fs-writer` | {module}_FS_v{X}.md |
| UA 微架构文档 | `chip-microarch-writer` | {module}_{sub}_microarch_v{X}.md |
| RTL 代码实现 | `chip-code-writer` | .v / .sv / _sva.sv / _tb.v / .sdc |
| 架构评审 | `chip-arch-reviewer` | 评审报告 |

---

## 强制规则

### 1. 芯片任务必须使用专用 Agent

RTL/FS/UA/评审相关任务**禁止手动生成**，必须调用对应专用 Agent。详见 `.claude/rules/chip-agent-mandatory.md`。

**唯一例外**：
- 仅读取/搜索现有代码
- 仅回答代码解释性问题
- 修改量极小（<5 行）且用户明确要求手动
- 非芯片任务（项目管理、git、文档格式）

### 2. 知识检索优先

涉及协议/接口/CBB/选型/编码前，**必须先完成 Wiki 检索**。流程：`index.md` → wiki 页面 → 原始文档（按需）。详见 `.claude/shared/rag-mandatory-search.md`。

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

上游文档变更时需判断是否触发级联更新。端口/FSM/FIFO/CBB 变更 → 强制重新实现。详见 `.claude/shared/change-propagation.md`。

---

## 文档模板

- **FS 模板**：`.claude/rules/function-spec-template.md`
- **微架构模板**：`.claude/rules/microarchitecture-template.md`
- **质量检查清单**：`.claude/shared/quality-checklist-fs.md`、`quality-checklist-microarch.md`、`quality-checklist-impl.md`

---

## 工具使用

| 工具 | 用途 | 命令 |
|------|------|------|
| Verilator | RTL lint 检查 | `verilator --lint-only -Wall {file}.v` |
| Yosys | 综合 | `yosys -p "read_verilog {file}.v; synth" ` |
| d2 | 架构图/状态机图 | `d2 --layout dagre {file}.d2 {file}.png` |
| wavedrom-cli | 时序图 | `wavedrom-cli -i {file}.json -p {file}.png` |
| gtkwave | 波形查看 | `gtkwave {file}.vcd` |

工具路径：`.claude/tools/oss-cad-suite/bin/`

---

## 降级策略

外部资源不可用时不中断工作流：RAG 无结果 → 标注"基于通用知识"继续；图表编译失败 → 保留源文件，降级为文本描述。详见 `.claude/shared/degradation-strategy.md`。

---

## 记忆系统

跨会话记忆存储在 `memory/` 目录，索引文件为 `memory/MEMORY.md`。包含用户角色、反馈偏好、项目上下文、外部参考等类型。
