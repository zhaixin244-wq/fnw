# fnw

[中文版](README_zh.md)

---

### Overview

**fnw** is a Claude Code plugin that provides a complete AI-driven workflow for digital chip/module architecture design — from requirement exploration to RTL code delivery. It orchestrates multiple specialized AI Agents, each responsible for a distinct stage of the chip design pipeline, backed by a structured knowledge base of bus protocols, common building blocks (CBB), IP cores, and industry best practices.

### Key Features

- **12 Specialized Agents** covering the full chip design lifecycle: requirement exploration, functional specification, microarchitecture, architecture review, RTL coding, synthesis & timing, top integration, low-power design, DFT, verification architecture, verification environment, and project management
- **230+ Skills** spanning chip-specific tasks, engineering workflows, code quality, and multi-language support
- **Structured Knowledge Base** with protocol specifications (AXI, AHB, APB, PCIe, USB, DDR, etc.), CBB library (FIFO, arbiter, CDC, ECC, etc.), CPU/MMU/networking references
- **Document Templates** for Functional Specifications (FS) and Microarchitecture Specifications with strict quality checklists
- **Chart Generation Pipeline** using D2 (architecture diagrams, state machines) and Wavedrom (timing diagrams) compiled to PNG
- **RTL Coding Standards** enforced through automated lint checks and comprehensive design rule verification
- **Built-in UART Example** demonstrating the complete design flow from requirements to RTL

### Architecture

```
fnw/
├── .claude/
│   ├── agents/            # 12 specialized AI Agents
│   │   ├── chip-requirement-arch.md   # Requirement exploration & solution trade-off
│   │   ├── chip-fs-writer.md          # Functional Specification authoring
│   │   ├── chip-microarch-writer.md   # Microarchitecture specification authoring
│   │   ├── chip-arch-reviewer.md      # Architecture review & defect analysis
│   │   ├── chip-code-writer.md        # RTL code implementation
│   │   ├── chip-sta-analyst.md        # Synthesis & timing analysis
│   │   ├── chip-top-integrator.md     # Top-level integration
│   │   ├── chip-lowpower-designer.md  # Low-power design
│   │   ├── chip-dft-engineer.md       # DFT design
│   │   ├── chip-verfi-arch.md         # Verification architecture
│   │   ├── chip-env-writer.md         # Verification environment
│   │   └── chip-project-lead.md       # Project management
│   ├── skills/            # 230+ Skill definitions
│   ├── knowledge/         # Structured knowledge base
│   ├── rules/             # Coding standards & document templates
│   ├── shared/            # Shared configurations & quality checklists
│   ├── wiki/              # LLM Wiki knowledge system
│   └── tools/             # External tools (d2, chromium, etc.)
├── uart_work/             # UART example workspace (complete design flow demo)
│   ├── ds/doc/pr/         # Requirement summary, solution, ADR
│   ├── ds/doc/fs/         # Functional Specification
│   ├── ds/doc/ua/         # Microarchitecture documents + review report
│   ├── ds/rtl/            # RTL source (7 submodules + SVA)
│   └── ds/run/            # Synthesis/Lint scripts
├── memory/                # Persistent memory for cross-session context
└── requirements.txt       # Python/Node.js dependency specifications
```

### Design Workflow

The plugin implements a complete chip design workflow:

| Phase | Agent | Input | Output |
|-------|-------|-------|--------|
| **Phase 1: Requirement** | `chip-requirement-arch` | User's rough requirements | Requirement summary, solution document, ADR |
| **Phase 2: FS** | `chip-fs-writer` | Requirement summary + solution | Functional Specification with interface definitions, PPA targets, RTM |
| **Phase 3: Microarchitecture** | `chip-microarch-writer` | FS document | Microarchitecture specs per submodule (datapath, FSM, FIFO, IP integration) |
| **Phase 4: Review** | `chip-arch-reviewer` | Microarchitecture documents | Review report covering requirements, completeness, defects, protocol compliance |
| **Phase 5: RTL** | `chip-code-writer` | Reviewed microarchitecture | Verilog RTL, SDC constraints, UPF, SVA assertions |
| **Phase 6: Synthesis** | `chip-sta-analyst` | RTL + SDC | Synthesis report, timing report, area report |
| **Phase 7: Integration** | `chip-top-integrator` | Submodule RTL | Top module, interface checks, system lint |

### Agents

| Agent | Role | Activation Names |
|-------|------|-----------------|
| **chip-requirement-arch** | Requirement exploration & trade-off | 赵知几 / 知几 / Archie |
| **chip-fs-writer** | Functional Specification authoring | 钱典成 / 典成 / Felix |
| **chip-microarch-writer** | Microarchitecture specification authoring | 孙弘微 / 弘微 / Marcus |
| **chip-arch-reviewer** | Architecture review & defect analysis | 宋晶瑶 / 晶瑶 / Clara |
| **chip-code-writer** | RTL code implementation | 张铭研 / 铭研 / Ethan |
| **chip-sta-analyst** | Synthesis & timing analysis | 周闻哲 / 闻哲 / Winston |
| **chip-top-integrator** | Top-level integration | 陆灵犀 / 灵犀 / Lexi |
| **chip-lowpower-designer** | Low-power design | 沈未央 / 未央 / Shannon |
| **chip-dft-engineer** | DFT design | 陆青萝 / 青萝 / Tina |
| **chip-verfi-arch** | Verification architecture | 顾衡之 / 衡之 / Daniel |
| **chip-env-writer** | Verification environment | 韩映川 / 映川 / Henry |
| **chip-project-lead** | Project management | 林若水 / 若水 / Linus |

### Usage

#### Quick Start

```bash
# 1. Clone the repository
git clone <repository-url> fnw

# 2. Install dependencies
cd fnw
pip install -r requirements.txt
npm install

# 3. Use in Claude Code
# Just tell Claude what module you want to design
```

#### Start a New Module Design

```
User: 帮我设计一个 UART 模块
```

The `chip-requirement-arch` Agent will activate and guide you through requirement exploration.

#### Full Workflow Example (UART)

```bash
# Phase 1: Requirement exploration
User: 赵知几，帮我梳理一个 UART 模块的需求

# Phase 2: Functional Specification
User: 小成，根据需求汇总写 FS 文档

# Phase 3: Microarchitecture
User: 小微，基于 FS 写微架构文档

# Phase 4: Architecture Review
User: 晶瑶，评审一下微架构文档

# Phase 5: RTL Implementation
User: 铭研，根据微架构文档生成 RTL 代码

# Phase 6: Synthesis
User: 闻哲，对 RTL 进行综合和时序分析
```

#### Initialize Module Work Directory

```bash
bash .claude/skills/chip-create-dir/init_workdir.sh <module_name>
```

Creates a standardized directory structure with `ds/` (design) and `dv/` (verification) subtrees.

### Built-in Example: UART

The project includes a complete UART module design example (`uart_work/`), demonstrating the full flow from requirements to RTL:

| File | Description |
|------|-------------|
| `ds/doc/pr/uart_requirement_summary_v1.0.md` | Requirement summary (17 requirements) |
| `ds/doc/pr/uart_solution_v1.0.md` | Architecture solution (4 ADRs) |
| `ds/doc/fs/uart_FS_v1.0.md` | Functional Specification (15 chapters, 1250 lines) |
| `ds/doc/ua/*_microarch_v1.0.md` | 7 submodule microarchitecture documents |
| `ds/doc/ua/uart_review_report_v1.0.md` | Architecture review report |
| `ds/rtl/*.v` | 7 RTL source files + SVA assertions |
| `ds/run/` | Lint/Synthesis scripts + SDC constraints |

**UART Module Features**:
- Standard UART asynchronous communication (5/6/7/8 data bits, 1/1.5/2 stop bits, parity)
- Fractional baud rate generator (9600~921600 bps, accuracy < 0.1%)
- TX/RX FIFO (depth 16, register array)
- Hardware RTS/CTS flow control
- 16550-compatible register layout
- APB slave interface
- Loopback self-test mode

### Quality Assurance

- **RTL Coding Standards**: Enforced via `rules/coding-style.md`
- **Document Quality Checklists**: 22-item FS checklist, 36-item microarchitecture checklist, 39-item RTL implementation checklist
- **Automated Lint**: Verilator `--lint-only -Wall` integration
- **SVA Assertions**: SystemVerilog assertions bound via `ifdef ASSERT_ON`
- **Degradation Strategy**: Graceful fallback when external tools are unavailable (D2, Wavedrom, RAG)

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI or IDE extension
- **Python 3.8+** with packages: `Pillow`, `pyyaml`, `pytest`
- **Node.js 16+** with packages: `@wavedrom/cli`, `playwright-core`
- **D2** diagram language (optional, for architecture diagram generation)
- **Verilator** (optional, for RTL lint checks)
- **Yosys** (optional, for synthesis verification)

### License

MIT License - see [LICENSE](LICENSE) for details.
