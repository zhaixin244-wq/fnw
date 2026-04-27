# fnw — AI 驱动芯片设计平台

**[English](README_en.md)** | **[中文](README_zh.md)**

---

A Claude Code plugin for AI-driven digital chip/module architecture design — from requirement exploration to RTL delivery.

## Quick Start

```bash
# 1. Clone
git clone <repository-url> fnw && cd fnw

# 2. Install Python dependencies
pip install Pillow pyyaml

# 3. Install Node.js dependencies (optional, for timing diagrams)
npm install

# 4. Open in Claude Code and start designing
# Just tell Claude: "帮我设计一个 UART 模块"
```

## What You Get

- **12 specialized Agents** covering the full chip design lifecycle
- **230+ Skills** for chip-specific tasks and engineering workflows
- **Structured knowledge base**: 17+ bus protocols, 40+ CBBs, IP cores
- **Document templates** with quality checklists (FS: 22, Microarch: 36, RTL: 39)
- **RTL coding standards** enforced via Verilator lint + SVA assertions
- **Built-in UART example** with complete design flow (24 files, 8000+ lines)

## Agents

| Agent | Role | Activation |
|-------|------|------------|
| chip-requirement-arch | Requirement exploration | 赵知几 / Archie |
| chip-fs-writer | Functional Specification | 钱典成 / Felix |
| chip-microarch-writer | Microarchitecture | 陈佳微 / Marcus |
| chip-arch-reviewer | Architecture review | 宋晶瑶 / Clara |
| chip-code-writer | RTL implementation | 张铭研 / Ethan |
| chip-sta-analyst | Synthesis & timing | 周闻哲 / Winston |
| chip-top-integrator | Top-level integration | 陆灵犀 / Lexi |
| chip-lowpower-designer | Low-power design | 沈未央 / Shannon |
| chip-dft-engineer | DFT design | 陆青萝 / Tina |
| chip-verfi-arch | Verification architecture | 顾衡之 / Daniel |
| chip-env-writer | Verification environment | 韩映川 / Henry |
| chip-project-lead | Project management | 林若水 / Linus |

> See [README_zh.md](README_zh.md) or [README_en.md](README_en.md) for detailed installation instructions, agent dialogue examples, and complete usage guide.
