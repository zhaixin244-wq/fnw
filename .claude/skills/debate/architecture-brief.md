# Project Architecture

**FNW AI 芯片设计平台** - 使用 AI Agent 辅助完成从需求探索到 RTL 实现的芯片架构设计工作区。

## Tech Stack

- **Language:** Verilog-2005（可综合 RTL）+ SystemVerilog（仅 interface/typedef/SVA）
- **Toolchain:** oss-cad-suite（Verilator lint、Yosys 综合、gtkwave 波形查看）
- **Diagram:** d2（架构图）、wavedrom-cli（时序图）
- **Automation:** playwright（自动化测试）
- **Agent Framework:** Claude Code + 专用芯片 Agent 体系

## Directory Structure

```
.
├── .claude/
│   ├── rules/                # 项目级规则（编码规范、模板、Agent 调用规则）
│   │   ├── coding-style.md          # RTL 编码规范（Verilog-2005）
│   │   ├── chip-agent-mandatory.md  # Agent 强制调用规则
│   │   ├── function-spec-template.md # FS 功能规格书模板
│   │   └── microarchitecture-template.md # 微架构文档模板
│   ├── shared/               # 共享配置与工具
│   ├── wiki/                 # LLM 预编译结构化知识（协议/CBB/设计模式）
│   ├── knowledge/            # 原始协议/CBB 文档
│   ├── skills/               # Skill 定义（含 devils-advocate、debate）
│   └── tools/                # 工具链（oss-cad-suite 等）
├── {module}_work/           # 数据适配器模块工作区（当前项目）
│   ├── ds/
│   │   ├── doc/pr/           # 需求/方案/ADR 文档
│   │   ├── doc/fs/           # FS 功能规格书 + 图表
│   │   ├── doc/ua/           # 微架构文档 + 图表
│   │   └── rtl/              # RTL 代码
├── doc/                      # 项目级文档
├── memory/                   # 跨会话记忆
└── requirements.txt          # Python 依赖
```

## Key Patterns

- **Agent 强制调用:** RTL/FS/UA/评审/验证相关任务必须调用对应专用 Agent（chip-code-writer、chip-fs-writer、chip-microarch-writer 等），禁止手动生成
- **知识检索优先:** 涉及协议/接口/CBB/选型前必须先完成 Wiki 检索（index.md → wiki 页面 → 原始文档）
- **代办清单门控:** Agent 激活后第一步必须输出代办清单，标注预期输出物和执行组
- **异步复位同步释放:** 统一低有效异步复位 `rst_n`，所有寄存器明确复位值
- **Valid-Ready 握手:** valid 不依赖 ready（防组合环路），ready 优先仅依赖下游

## Notes

- 交互语言：中文为主，技术术语保留英文（CDC、PPA、AXI、RTL 等）
- 编码规范：Verilog-2005 + SV Interface，禁止门控时钟（用标准 ICG）、禁止 task、禁止 casex/casez
- 变更传播：上游文档变更需判断是否触发级联更新（端口/FSM/FIFO/CBB 变更 → 强制重新实现）
- 降级策略：RAG 无结果 → 标注"基于通用知识"继续；图表编译失败 → 保留源文件，降级为文本描述
