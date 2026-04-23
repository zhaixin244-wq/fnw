# fnw

[中文版](README_zh.md)

---

### Overview

**fnw** is a Claude Code plugin that provides a complete AI-driven workflow for digital chip/module architecture design — from requirement exploration to RTL code delivery. It orchestrates multiple specialized AI Agents, each responsible for a distinct stage of the chip design pipeline, backed by a structured knowledge base of bus protocols, common building blocks (CBB), IP cores, and industry best practices.

### Key Features

- **6 Specialized Agents** covering the full chip design lifecycle: requirement exploration, functional specification, microarchitecture, architecture review, RTL coding, and code review
- **230+ Skills** spanning chip-specific tasks, engineering workflows, code quality, and multi-language support
- **Structured Knowledge Base** with protocol specifications (AXI, AHB, APB, PCIe, USB, DDR, etc.), CBB library (FIFO, arbiter, CDC, ECC, etc.), CPU/MMU/networking references
- **Document Templates** for Functional Specifications (FS) and Microarchitecture Specifications with strict quality checklists
- **Chart Generation Pipeline** using D2 (architecture diagrams, state machines) and Wavedrom (timing diagrams) compiled to PNG
- **RTL Coding Standards** enforced through automated lint checks and comprehensive design rule verification

### Architecture

```
fnw/
├── .claude/
│   ├── agents/            # 6 specialized AI Agents
│   │   ├── chip-requirement-arch.md   # Requirement exploration & solution trade-off
│   │   ├── chip-fs-writer.md          # Functional Specification authoring
│   │   ├── chip-microarch-writer.md   # Microarchitecture specification authoring
│   │   ├── chip-arch-reviewer.md      # Architecture review & defect analysis
│   │   ├── chip-code-writer.md        # RTL code implementation
│   │   └── chip-arch.md               # General chip architecture Agent
│   ├── skills/            # 230+ Skill definitions
│   │   ├── chip-impl-*/   # RTL implementation skills (coding, SDC/SVA, lint, etc.)
│   │   ├── chip-png-*/    # Chart generation (D2, Wavedrom, interface diagrams)
│   │   ├── chip-*-architect/  # CDC, low-power, reliability architecture
│   │   └── ...            # Engineering, testing, DevOps, security skills
│   ├── knowledge/         # Structured knowledge base
│   │   ├── bus-protocol/  # AXI, AHB, APB, PCIe, USB, DDR, SPI, I2C, UART, etc.
│   │   ├── cbb/           # Common Building Blocks (FIFO, arbiter, CDC, ECC, etc.)
│   │   ├── IP/            # IP core references (ARM, RISC-V, Ethernet, DDR, PCIe, USB)
│   │   ├── cpu/           # CPU architecture (pipeline, cache, branch predictor, interrupt)
│   │   ├── mmu/           # MMU (page table, TLB, virtualization, memory protection)
│   │   └── ...            # Network protocol, I/O protocol, verification
│   ├── rules/             # Coding standards & document templates
│   │   ├── coding-style.md              # RTL coding standard (Verilog-2005)
│   │   ├── function-spec-template.md    # FS document template
│   │   └── microarchitecture-template.md # Microarchitecture document template
│   ├── shared/            # Shared configurations & quality checklists
│   ├── prompts/           # Agent prompt templates
│   ├── phases/            # Workflow phase definitions (JSON)
│   ├── wiki/              # LLM Wiki knowledge system
│   └── tools/             # External tools (d2, chromium, etc.)
├── memory/                # Persistent memory for cross-session context
├── LICENSE                # MIT License
└── requirements.txt       # Python/Node.js dependency specifications
```

### Design Workflow

The plugin implements a 5-phase chip design workflow:

| Phase | Agent | Input | Output |
|-------|-------|-------|--------|
| **Phase 1: Requirement** | `chip-requirement-arch` | User's rough requirements | Requirement summary, solution document, ADR |
| **Phase 2: FS** | `chip-fs-writer` | Requirement summary + solution | Functional Specification with interface definitions, PPA targets, RTM |
| **Phase 3: Microarchitecture** | `chip-microarch-writer` | FS document | Microarchitecture specs per submodule (datapath, FSM, FIFO, IP integration) |
| **Phase 4: Review** | `chip-arch-reviewer` | Microarchitecture documents | Review report covering requirements, completeness, defects, protocol compliance |
| **Phase 5: RTL** | `chip-code-writer` | Reviewed microarchitecture | Verilog RTL, SDC constraints, UPF, SVA assertions |

### Agents

| Agent | Role | Expertise |
|-------|------|-----------|
| **chip-requirement-arch** | Requirement exploration & trade-off analysis | Brainstorming, multi-solution comparison, constraint convergence, DSE |
| **chip-fs-writer** | Functional Specification authoring | Requirement-to-spec mapping, interface definition, PPA specification, RTM |
| **chip-microarch-writer** | Microarchitecture specification authoring | Datapath design, control logic, FSM, FIFO, IP/CBB integration |
| **chip-arch-reviewer** | Architecture review & defect analysis | Requirement coverage, document completeness, protocol compliance, PPA audit |
| **chip-code-writer** | RTL code implementation | Verilog/RTL, CDC/RDC, low-power, SDC, SVA, synthesis scripts |

### Chip-Specific Skills (14 Skills)

| Skill | Description |
|-------|-------------|
| `chip-budget-allocator` | System-level PPA budget decomposition to submodules |
| `chip-cdc-architect` | Clock domain crossing analysis and sync strategy |
| `chip-design-space-explorer` | Area-Performance-Power Pareto-optimal design exploration |
| `chip-diagram-generator` | Mermaid/Wavedrom diagram generation |
| `chip-doc-structurer` | Document chapter structure and content weighting |
| `chip-interface-contractor` | Precise interface contract (ports, timing, SVA) |
| `chip-low-power-architect` | Power domain, isolation, retention, UPF design |
| `chip-ppa-formatter` | Structured PPA specification tables |
| `chip-protocol-compliance-checker` | AXI/ACE/CHI/TileLink/APB/AHB protocol compliance |
| `chip-reliability-architect` | ECC/Parity/TMR, aging, IR Drop, ESD analysis |
| `chip-review-checklister` | 9-dimension review checklist with completeness scoring |
| `chip-rtl-guideline-generator` | RTL coding standard generation (Clock/Reset/DFT/SVA) |
| `chip-traceability-linker` | Requirements Traceability Matrix (RTM) with coverage stats |
| `chip-version-diff-generator` | Architecture version diff and impact analysis |

### Knowledge Base

The built-in knowledge base covers:

- **Bus Protocols** (17): AXI4, AXI4-Lite, AXI4-Stream, AHB, APB, PCIe, USB, DDR, SPI, I2C, UART, CAN, JTAG, MIPI, TileLink, Wishbone
- **Common Building Blocks** (40+): FIFO, arbiter, CDC sync, ECC, CRC, crossbar, barrel shifter, clock divider/gating, gray code, and more
- **IP Cores**: ARM Cortex cores, RISC-V, Ethernet MAC/PCS, DDR controller, PCIe controller, USB controller, PLL/DLL, SPI/I2C/UART
- **CPU Architecture**: Pipeline, cache hierarchy, branch predictor, interrupt controller, multi-core
- **MMU**: Page table, TLB, memory protection, virtualization, address space, memory attributes
- **Verification**: Verification methodology references

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI or IDE extension
- **Python 3.8+** with packages: `Pillow`, `pyyaml`, `pytest`
- **Node.js 16+** with packages: `@wavedrom/cli`, `playwright-core`
- **D2** diagram language (optional, for architecture diagram generation)

### Installation

1. Clone this repository into your project's root:
   ```bash
   git clone <repository-url> .claude
   ```

2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Install Node.js dependencies:
   ```bash
   npm install
   ```

4. (Optional) Install D2 for architecture diagram generation:
   - Download from [D2 releases](https://github.com/terrastruct/d2/releases)
   - Place `d2.exe` in `.claude/tools/d2/` or add to system PATH

### Usage

#### Start a New Module Design

```
User: 帮我设计一个 PCIe RC 模块
```

The `chip-requirement-arch` Agent will activate and guide you through requirement exploration.

#### Full Workflow Example

```bash
# Phase 1: Requirement exploration
User: 赵知几，帮我梳理一个 AXI-to-APB bridge 的需求

# Phase 2: Functional Specification
User: 小成，根据需求汇总写 FS 文档

# Phase 3: Microarchitecture
User: 小微，基于 FS 写微架构文档

# Phase 4: Architecture Review
User: 评审一下微架构文档

# Phase 5: RTL Implementation
User: 根据微架构文档生成 RTL 代码
```

#### Agent Activation

Agents are activated by name or nickname:

| Agent | Activation Names |
|-------|-----------------|
| chip-requirement-arch | 赵知几 / 知几 / 小几 / Archie / 架构师 / 需求师 |
| chip-fs-writer | 钱典成 / 典成 / 小成 / Felix / 规格师 / FS师 |
| chip-microarch-writer | 孙弘微 / 弘微 / 小微 / Sam / 微架构师 |

#### Initialize Module Work Directory

```bash
bash .claude/skills/chip-create-dir/init_workdir.sh <module_name>
```

Creates a standardized directory structure with `ds/` (design) and `dv/` (verification) subtrees.

### Quality Assurance

- **RTL Coding Standards**: Enforced via `rules/coding-style.md` — covers naming, module declaration, clock/reset, FSM, handshake, FIFO, CDC, DFT, and synthesizability checks
- **Document Quality Checklists**: 22-item FS checklist, 36-item microarchitecture checklist, 39-item RTL implementation checklist
- **Automated Lint**: Verilator `--lint-only -Wall` integration
- **SVA Assertions**: SystemVerilog assertions bound via `ifdef ASSERT_ON`
- **Degradation Strategy**: Graceful fallback when external tools are unavailable (D2, Wavedrom, RAG)

### License

MIT License - see [LICENSE](LICENSE) for details.
