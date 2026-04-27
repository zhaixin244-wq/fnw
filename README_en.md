# fnw — AI-Driven Chip Design Platform

[中文版](README_zh.md)

---

## Table of Contents

- [Overview](#overview)
- [Requirements & Installation](#requirements--installation)
- [Quick Start](#quick-start)
- [Agent Details & Dialogue Examples](#agent-details--dialogue-examples)
- [Design Workflow](#design-workflow)
- [Built-in Example: UART](#built-in-example-uart)
- [Project Structure](#project-structure)
- [Quality Assurance](#quality-assurance)
- [FAQ](#faq)

---

## Overview

**fnw** is a Claude Code plugin that provides a complete AI-driven workflow for digital chip/module architecture design — from requirement exploration to RTL code delivery.

**Core Capabilities**:
- **12 Specialized Agents** covering the full chip design lifecycle
- **230+ Skills** for chip-specific tasks and engineering workflows
- **Structured Knowledge Base** with 17+ bus protocols, 40+ CBBs, IP core references
- **Document Templates** with quality checklists (FS: 22 items, Microarch: 36 items)
- **RTL Coding Standards** with 39 implementation checks + Verilator lint integration
- **Chart Generation** with D2 architecture diagrams + Wavedrom timing diagrams

---

## Requirements & Installation

### Required

| Tool | Version | Purpose |
|------|---------|---------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Latest | AI Agent runtime platform |
| [Python](https://www.python.org/) | 3.8+ | Image processing, scripts |
| [Node.js](https://nodejs.org/) | 16+ | Wavedrom timing diagram generation |

### Optional (Recommended)

| Tool | Purpose | Download |
|------|---------|----------|
| [D2](https://d2lang.com/) | Architecture & state machine diagrams | [GitHub Releases](https://github.com/terrastruct/d2/releases) |
| [Verilator](https://www.veripool.org/verilator/) | RTL lint checking | [Official](https://www.veripool.org/verilator/) |
| [Yosys](https://yosyshq.net/yosys/) | RTL synthesis verification | [GitHub](https://github.com/YosysHQ/yosys) |
| [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite) | All-in-one EDA toolkit (Verilator + Yosys + GTKWave) | [GitHub Releases](https://github.com/YosysHQ/oss-cad-suite/releases) |

### Installation Steps

#### 1. Clone Repository

```bash
# Option A: Use as project root
git clone <repository-url> fnw
cd fnw

# Option B: Use as Claude plugin in existing project
cd your_project
git clone <repository-url> .claude
```

#### 2. Install Python Dependencies

```bash
pip install -r requirements.txt
```

**Core Dependencies**:

| Package | Purpose | Required? |
|---------|---------|-----------|
| `Pillow>=9.0` | Interface diagram generation (chip-png-interface-gen) | Recommended |
| `pyyaml>=6.0` | YAML config parsing | Recommended |
| `pytest>=7.0` | Testing framework | Optional |
| `python-dotenv>=1.0` | Environment variable loading | Optional |

> For RTL design only, just install Pillow and pyyaml:
> ```bash
> pip install Pillow pyyaml
> ```

#### 3. Install Node.js Dependencies

```bash
npm install
```

**Core Dependencies**:

| Package | Purpose | Required? |
|---------|---------|-----------|
| `@wavedrom/cli` | Wavedrom JSON → SVG/PNG conversion | Recommended |
| `playwright-core` | Headless browser for chart rendering | Recommended |

> Skip this if you don't need timing diagram generation.

#### 4. Install D2 (Optional, for Architecture Diagrams)

```bash
# Windows (using scoop)
scoop install d2

# macOS (using brew)
brew install d2

# Linux (using official script)
curl -fsSL https://d2lang.com/install.sh | sh -

# Or manually download: https://github.com/terrastruct/d2/releases
# Place d2 executable in .claude/tools/d2/ or add to system PATH
```

#### 5. Install EDA Tools (Optional, for Lint/Synthesis)

```bash
# Recommended: oss-cad-suite (includes Verilator + Yosys + GTKWave)
# Download: https://github.com/YosysHQ/oss-cad-suite/releases
# Extract and add bin/ to system PATH

# Verify installation
verilator --version
yosys --version
```

#### 6. Verify Installation

```bash
# Check Python
python --version  # Should be >= 3.8

# Check Node.js
node --version  # Should be >= 16

# Check D2 (if installed)
d2 --version

# Check Verilator (if installed)
verilator --version
```

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `pip install` permission error | Use `pip install --user -r requirements.txt` |
| `npm install` error | Try `npm install --legacy-peer-deps` |
| D2 command not found | Confirm PATH includes D2, or place in `.claude/tools/d2/` |
| Verilator missing Perl module | Install `Pod::Usage`: `cpan install Pod::Usage` |
| Chart generation fails | Doesn't affect core workflow, Agent auto-degrades to text description |

---

## Quick Start

### First Use

1. Open Claude Code (CLI or IDE extension)
2. Navigate to project directory
3. Tell Claude what you want to design:

```
User: 帮我设计一个 UART 模块
```

Claude will automatically activate the `chip-requirement-arch` Agent and guide you through requirement exploration.

### Simplest Flow (3 Steps to RTL)

```
User: 帮我设计一个简单的 GPIO 模块，8 位宽，支持输入输出方向配置

# Agent will automatically complete: Requirements → FS → Microarch → RTL
# To go step by step, say:
User: 一步步来，先帮我梳理需求
```

### Controlling Execution Mode

| What You Say | Agent Behavior |
|--------------|----------------|
| "一步步来" / "先出清单" | Step mode: pause after each step for your confirmation |
| "直接写" / "一口气完成" | Continuous mode: list plan then execute continuously |
| "暂停一下" | Pause at any point |
| "继续" | Resume from pause |

---

## Agent Details & Dialogue Examples

### 1. chip-requirement-arch (Requirement Exploration & Solution Trade-off)

**Role**: 赵知几 (Archie) — Requirement exploration and architecture solution expert

**What It Can Do**:
- Converge from vague requirements to clear module specifications
- Multi-solution comparison (area vs performance vs power trade-offs)
- Generate requirement summary, solution document, ADR (Architecture Decision Record)
- Protocol selection comparison (e.g., AXI vs AHB vs APB)
- CBB selection guidance (FIFO, arbiter, CDC, etc.)

**Activation Names**: `赵知几` / `知几` / `小几` / `Archie` / `需求师`

**Dialogue Example**:

```
User: 赵知几，我想设计一个 SPI Master 模块，支持 4 种 SPI 模式，
     最高时钟 50MHz，挂在外设总线上。帮我梳理一下需求。

Archie：【需求探索 · 赵知几/Archie】

好的，让我先梳理一下需求。我会从以下几个维度来分析：

1. 协议规范：SPI 4 种模式（CPOL/CPHA 组合）
2. 接口需求：APB 配置接口 + SPI 物理接口
3. 功能需求：Master 角色、可配时钟分频、片选管理
4. 性能需求：50MHz SPI 时钟、FIFO 深度
5. 可靠性需求：超时检测、错误处理

我先生成需求汇总表，然后给出方案比选。需要我一步步来还是直接生成？

User: 直接生成

Archie：好的，我来生成需求汇总和方案文档...
```

**Output Files**:
- `{module}_requirement_summary_v1.0.md` — Requirement summary
- `{module}_solution_v1.0.md` — Architecture solution document
- `{module}_ADR_v1.0.md` — Architecture Decision Record

---

### 2. chip-fs-writer (Functional Specification Authoring)

**Role**: 钱典成 (Felix) — Functional specification document expert

**What It Can Do**:
- Transform requirement summary + solution into formal FS document
- Precisely define every interface (signal name, width, direction, clock domain, reset value)
- Complete register definitions (address map + bit fields + access types)
- Quantified PPA targets (Performance/Power/Area)
- Requirements Traceability Matrix (RTM) ensuring every requirement has a spec

**Activation Names**: `钱典成` / `典成` / `小成` / `Felix` / `规格师`

**Dialogue Example**:

```
User: 小成，根据 uart_work/ds/doc/pr/ 下面的需求和方案文档，
     写一份完整的 FS 功能规格书。

Felix：【FS文档编写 · 钱典成/Felix】

收到，我来编写 UART 模块的功能规格书。

先确认输入：
- ✅ 需求汇总：uart_requirement_summary_v1.0.md
- ✅ 方案文档：uart_solution_v1.0.md
- ✅ ADR：uart_ADR_v1.0.md

我将按 15 章模板结构编写，包含：
- §4 功能描述（含 REQ 追溯）
- §5 子模块设计（7 个子模块的端口和接口时序）
- §6 顶层接口定义
- §7 寄存器定义（16550 兼容布局）
- §8 PPA 规格（量化指标）
- §14 需求追溯矩阵

开始编写，预计生成 1000+ 行的完整规格书。

User：好的，开始吧

Felix：正在编写功能规格书...
```

**Output Files**:
- `{module}_FS_v1.0.md` — Functional Specification (15 chapters)

**Key Checks**:
- Every REQ has corresponding FS chapter
- Every interface has complete signal list
- Every register has bit field definition
- PPA metrics are quantified or marked "pending synthesis verification"

---

### 3. chip-microarch-writer (Microarchitecture Specification Authoring)

**Role**: 陈佳微 (Marcus) — Microarchitecture design expert

**What It Can Do**:
- Transform FS into microarchitecture documents that directly guide RTL coding
- Data path design (complete path from input to output)
- State machine design (state definition + transition conditions + encoding)
- FIFO depth calculation (based on flow control model, not guesswork)
- Critical timing analysis (Tslack formula + SDC constraint suggestions)
- IP/CBB integration design

**Activation Names**: `陈佳微` / `佳微` / `小微` / `Marcus` / `微架构师`

**Dialogue Example**:

```
User: 小微，基于 uart_FS_v1.0.md，为每个子模块写微架构文档。

Marcus：【微架构编写 · 陈佳微/Marcus】

收到 FS 文档，我来为 7 个子模块编写微架构规格书。

子模块清单：
1. uart_fifo — 参数化同步 FIFO（独立 CBB）
2. uart_baud_gen — 小数波特率发生器
3. uart_reg_mod — APB 从接口 + 寄存器
4. uart_tx — 发送状态机 + 移位寄存器
5. uart_rx — 接收状态机 + 过采样
6. uart_ctrl — 中断聚合 + 流控
7. uart_top — 顶层集成（仅连线）

每个文档包含：
- 数据通路（输入→处理→输出）
- 状态机（状态转移表 + 编码）
- FIFO 深度计算（R_prod/R_cons/B_max/D_fb）
- 关键时序分析（Tslack = Tclk - Tcq - Tlogic - Tsetup）
- RTL 实现指导（伪代码框架）

先写 uart_fifo（底层 CBB），再逐个向上。

User：直接写，一口气完成

Marcus：好的，连续模式。开始逐个生成...
```

**Output Files**:
- `{module}_{submodule}_microarch_v1.0.md` — One document per submodule

**Iron Rules**:
- FIFO depth must have calculation basis
- Top-level module: interconnect only, zero logic
- Register module: config registers only, functional tables to function modules

---

### 4. chip-arch-reviewer (Architecture Review)

**Role**: 宋晶瑶 (Clara) — Architecture review expert

**What It Can Do**:
- Deliverable completeness check (PR/FS/UA/RTL/SVA/SDC/scripts)
- PR→FS requirements traceability (coverage statistics)
- FS→UA port/parameter consistency check
- UA→RTL implementation consistency check
- Coding standard check (39 items from coding-style.md)
- Architecture defect scan (combinational loops/latch/CDC/reset)
- Generate review report (Critical/Major/Minor classification)

**Activation Names**: `宋晶瑶` / `晶瑶` / `Clara` / `评审师`

**Dialogue Example**:

```
User: 晶瑶，评审一下 UART 的微架构和 RTL 代码。

Clara：【架构评审 · 宋晶瑶/Clara】

收到，我来对 UART 模块进行全面评审。

评审范围：
- PR 文档（需求/方案/ADR）
- FS 文档
- 7 个微架构文档
- 7 个 RTL 源文件 + SVA
- 运行脚本（.f/.sdc/lint.sh/synth.tcl）

评审流程（9 步）：
1. 交付物齐全性检查
2. 质量门禁检查（Lint/综合）
3. PR→FS 需求追溯
4. FS→UA 端口一致性
5. UA→RTL 实现一致性
6. FSM/FIFO 参数一致性
7. SDC 约束一致性
8. 架构缺陷扫描
9. 生成评审报告

开始逐项检查...

User：好的

Clara：正在扫描交付物...

[Step 1] 交付物检查：✅ 全部齐全
[Step 3] 需求追溯：17/17 REQ 覆盖，覆盖率 100%
[Step 5] UA→RTL 一致性：发现 3 个 Critical 问题...

评审报告已生成，结论：⚠️ 有条件通过
```

**Output Files**:
- `{module}_review_report_v1.0.md` — Review report

**Review Conclusions**:
- ✅ Passed: All checks pass, ready for next phase
- ⚠️ Conditional Pass: Some issues need fixing before re-verification
- ❌ Failed: Serious issues found, return to design phase

---

### 5. chip-code-writer (RTL Code Implementation)

**Role**: 张铭研 (Ethan) — RTL coding expert

**What It Can Do**:
- Generate synthesizable Verilog RTL from microarchitecture documents
- Generate SVA assertion files (handshake stability/data stability/FSM checks)
- Generate SDC constraint files
- Generate Lint scripts and synthesis scripts
- Auto-execute Verilator lint check (0 error gate)
- Auto-execute Yosys synthesis verification
- Auto-fix lint/synthesis failures (self-healing loop, max 10 iterations)

**Activation Names**: `张铭研` / `铭研` / `Ethan` / `RTL工程师`

**Dialogue Example**:

```
User: 铭研，根据微架构文档生成 UART 的 RTL 代码。

Ethan：【RTL实现 · 张铭研/Ethan】

收到微架构文档，我来生成 RTL 代码。

架构冻结铁律：严格按微架构实现，不做任何架构修改。

生成清单（按依赖顺序）：
1. uart_fifo.v — 参数化 FIFO（底层 CBB）
2. uart_baud_gen.v — 波特率发生器
3. uart_tx.v — 发送 FSM + 移位寄存器
4. uart_rx.v — 接收 FSM + 过采样 + CDC
5. uart_reg_mod.v — APB 寄存器模块
6. uart_ctrl.v — 中断 + 流控
7. uart_top.v — 顶层集成
8. uart_sva.sv — SVA 断言

辅助文件：
9. uart.f — 文件列表
10. uart.sdc — SDC 约束
11. lint.sh — Lint 脚本
12. synth_yosys.tcl — 综合脚本

编码规范：
- Verilog-2005，文件头五项齐全
- 时序逻辑 always @(posedge clk or negedge rst_n) + <=
- 组合逻辑 always @(*) 赋默认值 + case default
- FSM 两段式 + 非法状态回收 IDLE
- 子模块名称关联实例化

开始按依赖顺序生成...

User：开始

Ethan：正在生成 uart_fifo.v（底层 CBB 优先）...
```

**Output Files**:
- `{module}_top.v` — Top-level module
- `{module}_{sub}.v` — Submodule RTL
- `{module}_sva.sv` — SVA assertions
- `{module}.f` — File list
- `{module}.sdc` — SDC constraints
- `lint.sh` — Lint check script
- `synth_yosys.tcl` — Synthesis script

**Quality Gates (Auto-executed)**:
- Verilator `--lint-only -Wall` zero errors
- Yosys synthesis zero errors + reasonable area
- Self-check IC-01~39 + IM-01~08 all pass

---

### 6. chip-sta-analyst (Synthesis & Timing Analysis)

**Role**: 周闻哲 (Winston) — Synthesis and timing expert

**What It Can Do**:
- RTL synthesis (Yosys/Design Compiler)
- SDC constraint writing and optimization
- Timing analysis (setup/hold time checks)
- Area estimation and optimization suggestions
- Timing violation fix suggestions (retiming/pipelining/logic optimization)

**Activation Names**: `周闻哲` / `闻哲` / `Winston` / `综合工程师`

**Dialogue Example**:

```
User: 闻哲，对 UART RTL 进行综合和时序分析。

Winston：【综合与时序 · 周闻哲/Winston】

收到，我来对 UART 进行综合分析。

工作内容：
1. 读取 RTL + SDC 约束
2. 执行 Yosys 综合
3. 分析时序报告（setup/hold slack）
4. 分析面积报告（逻辑单元/SRAM）
5. 输出综合报告

时钟约束：50MHz（20ns 周期）
目标工艺：通用 28nm 标准单元库

正在执行综合...
```

**Output Files**:
- `synth_report.md` — Synthesis report
- `timing_report.md` — Timing report
- `area_report.md` — Area report

---

### 7. chip-top-integrator (Top-Level Integration)

**Role**: 陆灵犀 (Lexi) — Top-level integration expert

**What It Can Do**:
- Submodule integration and wiring
- Cross-module interface alignment checks
- System-level lint
- Top-level connection verification
- Integration testing

**Activation Names**: `陆灵犀` / `灵犀` / `Lexi` / `集成工程师`

**Dialogue Example**:

```
User: 灵犀，把 UART 的 7 个子模块集成到顶层。

Lexi：【顶层集成 · 陆灵犀/Lexi】

收到，我来进行顶层集成。

集成清单：
1. 检查子模块接口定义一致性
2. 生成顶层连线（uart_top.v）
3. 执行系统级 lint
4. 验证信号连接完整性

注意：顶层模块只做连线和子模块实例化，
      不包含任何逻辑（无 always 块）。

正在生成顶层模块...
```

---

### 8. chip-lowpower-designer (Low-Power Design)

**Role**: 沈未央 (Shannon) — Low-power design expert

**What It Can Do**:
- Power domain planning
- UPF file generation
- Isolation / Level Shifter design
- Clock Gating design
- Power analysis and optimization

**Activation Names**: `沈未央` / `未央` / `Shannon` / `低功耗设计师`

**Dialogue Example**:

```
User: 未央，为 UART 模块做低功耗设计，需要支持睡眠模式。

Shannon：【低功耗设计 · 沈未央/Shannon】

收到，我来设计低功耗方案。

分析：
- UART 是低速外设，功耗本身不大
- 主要优化点：Clock Gating（空闲时关时钟）
- 可选：独立功耗域，支持深度睡眠

方案：
1. UART 模块级 ICG（APB 无访问时 gate 时钟）
2. TX/RX 独立 ICG（发送/接收可独立关断）
3. UPF 文件定义功耗域和电源状态

正在生成低功耗方案...
```

**Output Files**:
- `{module}.upf` — UPF low-power file
- `lowpower_design.md` — Low-power design document

---

### 9. chip-dft-engineer (DFT Design)

**Role**: 陆青萝 (Tina) — DFT design expert

**What It Can Do**:
- DFT architecture planning
- Scan chain insertion
- MBIST / LBIST integration
- ATPG test vector generation
- DFT check reports

**Activation Names**: `陆青萝` / `青萝` / `Tina` / `DFT工程师`

**Dialogue Example**:

```
User: 青萝，为 UART 添加 DFT 支持。

Tina：【DFT设计 · 陆青萝/Tina】

收到，我来规划 UART 的 DFT 方案。

DFT 需求分析：
- UART 无 SRAM → 不需要 MBIST
- UART 是数字逻辑 → 需要扫描链
- 需要 scan_en 端口用于扫描模式

方案：
1. 所有寄存器接入扫描链
2. ICG 添加 scan_en 端口
3. 异步复位在扫描模式下同步释放
4. 生成 DFT 检查报告

正在生成 DFT 方案...
```

**Output Files**:
- `dft_architecture.md` — DFT architecture document
- `dft_check_report.md` — DFT check report

---

### 10. chip-verfi-arch (Verification Architecture)

**Role**: 顾衡之 (Daniel) — Verification architecture expert

**What It Can Do**:
- Test point decomposition (from FS requirements to verifiable test points)
- Verification environment architecture design (UVM architecture, Agent configuration)
- Test case planning (functional coverage, boundary coverage, exception coverage)
- Coverage model definition
- Verification plan document generation

**Activation Names**: `顾衡之` / `衡之` / `Daniel` / `验证架构师`

**Dialogue Example**：

```
User: 衡之，为 UART 制定验证计划。

Daniel：【验证架构 · 顾衡之/Daniel】

收到，我来制定 UART 的验证架构方案。

分析范围：
- FS 功能规格书（17 条需求）
- 微架构文档（7 个子模块）

验证策略：
1. 测试点分解：从 17 条 REQ 提取可验证测试点
2. 验证环境方案：UVM 架构 + Agent 配置
3. 用例规划：功能/边界/异常场景
4. 覆盖率模型：FSM 状态覆盖 + 握手组合覆盖

输出目录：
- dv/doc/plan/ — 总验证方案
- dv/doc/chk_point/ — 测试点与用例规划
- dv/env/plan/ — 验证环境方案

正在分解测试点...
```

**Output Files**:
- `dv/doc/plan/verification_plan.md` — Verification plan
- `dv/doc/chk_point/test_points.md` — Test point decomposition
- `dv/env/plan/env_architecture.md` — Verification environment architecture

---

### 11. chip-env-writer (Verification Environment Authoring)

**Role**: 韩映川 (Henry) — Verification environment implementation expert

**What It Can Do**:
- Generate complete UVM verification environment code from verification plan
- Agent / Driver / Monitor / Scoreboard / Coverage
- Env / Test / Sequence / TB Top
- Compilation check gate (0 Error)
- Plan consistency self-check

**Activation Names**: `韩映川` / `映川` / `Henry` / `TB工程师`

**Dialogue Example**：

```
User: 映川，根据验证方案生成 UART 的 UVM 验证环境。

Henry：【验证环境 · 韩映川/Henry】

收到验证方案，我来生成 UVM 验证环境代码。

生成清单：
1. uart_agent — uvm_agent（含 driver + monitor）
2. uart_driver — uvm_driver（APB 事务驱动）
3. uart_monitor — uvm_monitor（APB + UART 监控）
4. uart_scoreboard — 数据比对
5. uart_coverage — 功能覆盖率
6. uart_env — uvm_env（环境顶层）
7. uart_test — uvm_test（测试基类）
8. uart_sequence — uvm_sequence（激励生成）
9. uart_tb_top — 仿真顶层

编码规范：遵循 vcoding-style.md
编译门禁：0 Error

正在生成验证环境...
```

**Output Files**:
- `dv/env/*.sv` — UVM verification environment code
- `dv/tb/*.sv` — Testbench top level
- `dv/case/*.sv` — Test cases

---

### 12. chip-project-lead (Project Management)

**Role**: 林若水 (Linus) — Project lead

**What It Can Do**:
- Project overview and progress tracking
- Risk identification and management
- Cross-module coordination
- Gate review checks
- Report material generation

**Activation Names**: `林若水` / `若水` / `Linus` / `项目负责人`

**Dialogue Example**：

```
User: 若水，帮我梳理一下 UART 项目的整体进度。

Linus：【项目管理 · 林若水/Linus】

收到，我来梳理 UART 项目进度。

当前状态：
- ✅ 阶段 1：需求探索 — 完成
- ✅ 阶段 2：FS 编写 — 完成
- ✅ 阶段 3：微架构编写 — 完成
- ✅ 阶段 4：架构评审 — 有条件通过（3 个 Critical 已修复）
- ✅ 阶段 5：RTL 实现 — 完成
- ⬜ 阶段 6：综合验证 — 待执行
- ⬜ 阶段 7：验证环境 — 待执行

风险项：
- [低] 图表未生成（降级为文本描述）
- [低] Lint 未执行（Verilator 环境问题）

建议下一步：
1. 执行综合验证（闻哲）
2. 制定验证计划（衡之）
3. 生成验证环境（映川）
```

---

## Design Workflow

### Standard Flow

```
User Requirements
    │
    ▼
┌─────────────────┐
│ 1. Requirement   │  chip-requirement-arch
│    Summary + Sol │  → requirement_summary + solution + ADR
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 2. FS Document   │  chip-fs-writer
│    15-chapter FS │  → {module}_FS_v1.0.md
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 3. Microarch     │  chip-microarch-writer
│    Per-submodule │  → {sub}_microarch_v1.0.md × N
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 4. Review        │  chip-arch-reviewer
│    9-step check  │  → review_report_v1.0.md
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 5. RTL           │  chip-code-writer
│    Verilog + SVA │  → *.v + *_sva.sv + .sdc
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 6. Synthesis     │  chip-sta-analyst
│    Timing + Area │  → synthesis + timing reports
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 7. Integration   │  chip-top-integrator
│    Submodule link│  → {module}_top.v
└─────────────────┘
```

### Optional Flow (As Needed)

| Scenario | Agent to Use |
|----------|-------------|
| Need low-power design | `chip-lowpower-designer` |
| Need DFT support | `chip-dft-engineer` |
| Need verification plan | `chip-verfi-arch` |
| Need UVM environment | `chip-env-writer` |
| Need project management | `chip-project-lead` |

---

## Built-in Example: UART

The project includes a complete UART module design example (`uart_work/`), demonstrating the full flow from requirements to RTL.

### File List

```
uart_work/
├── ds/doc/pr/
│   ├── uart_requirement_summary_v1.0.md   # Requirement summary (17 requirements)
│   ├── uart_solution_v1.0.md              # Architecture solution (submodule division)
│   └── uart_ADR_v1.0.md                   # Architecture Decision Record (5 ADRs)
├── ds/doc/fs/
│   └── uart_FS_v1.0.md                    # Functional Specification (15 chapters, 1250 lines)
├── ds/doc/ua/
│   ├── uart_fifo_microarch_v1.0.md        # FIFO microarchitecture
│   ├── uart_baud_gen_microarch_v1.0.md    # Baud rate generator microarchitecture
│   ├── uart_reg_mod_microarch_v1.0.md     # Register module microarchitecture
│   ├── uart_tx_microarch_v1.0.md          # Transmitter microarchitecture
│   ├── uart_rx_microarch_v1.0.md          # Receiver microarchitecture
│   ├── uart_ctrl_microarch_v1.0.md        # Control module microarchitecture
│   ├── uart_top_microarch_v1.0.md         # Top-level microarchitecture
│   └── uart_review_report_v1.0.md         # Architecture review report
├── ds/rtl/
│   ├── uart_fifo.v                        # Parameterized sync FIFO
│   ├── uart_baud_gen.v                    # Fractional baud rate generator
│   ├── uart_tx.v                          # TX FSM + shift register
│   ├── uart_rx.v                          # RX FSM + oversampling + CDC
│   ├── uart_reg_mod.v                     # APB register module
│   ├── uart_ctrl.v                        # Interrupt aggregation + flow control
│   ├── uart_top.v                         # Top-level integration
│   └── uart_sva.sv                        # SVA assertions
└── ds/run/
    ├── uart.f                             # File list
    ├── uart.sdc                           # SDC constraints (50MHz)
    ├── lint.sh                            # Lint check script
    └── synth_yosys.tcl                    # Yosys synthesis script
```

### UART Module Specifications

| Feature | Specification |
|---------|--------------|
| Protocol | Standard UART asynchronous serial |
| Data bits | 5 / 6 / 7 / 8 bits configurable |
| Stop bits | 1 / 1.5 / 2 bits configurable |
| Parity | Odd / Even / None |
| Baud rate | 9600 ~ 921600 bps (fractional divider, accuracy < 0.1%) |
| FIFO | TX 16 bytes + RX 16 bytes |
| Flow control | Hardware RTS/CTS |
| Interrupts | TX empty / RX full / Frame error / Parity error / Break |
| Registers | 16550-compatible layout |
| Interface | APB slave (32-bit data width) |
| Test mode | Loopback self-test |
| Oversampling | 16x / 8x configurable |

---

## Project Structure

```
fnw/
├── .claude/
│   ├── agents/            # 12 specialized AI Agent definitions
│   ├── skills/            # 230+ Skill definitions
│   ├── knowledge/         # Structured knowledge base
│   │   ├── bus-protocol/  # Bus protocols (AXI/AHB/APB/PCIe/USB/DDR/SPI/I2C/UART...)
│   │   ├── cbb/           # Common Building Blocks (FIFO/arbiter/CDC/ECC/CRC...)
│   │   ├── IP/            # IP core references
│   │   ├── cpu/           # CPU architecture
│   │   └── mmu/           # MMU
│   ├── rules/             # Coding standards & document templates
│   │   ├── coding-style.md              # RTL coding standard
│   │   ├── function-spec-template.md    # FS template
│   │   ├── microarchitecture-template.md # Microarchitecture template
│   │   └── review-report-template.md    # Review report template
│   ├── shared/            # Shared configs & quality checklists
│   │   ├── quality-checklist-fs.md      # FS quality check (22 items)
│   │   ├── quality-checklist-microarch.md # Microarch quality check (36 items)
│   │   ├── quality-checklist-impl.md    # RTL implementation check (39 items)
│   │   └── ...                          # Interaction style, degradation strategy, etc.
│   ├── wiki/              # LLM Wiki knowledge system
│   └── tools/             # External tool configs
├── uart_work/             # UART example workspace
├── memory/                # Cross-session persistent memory
├── doc/member/            # Agent member profiles
├── requirements.txt       # Python dependencies
├── package.json           # Node.js dependencies
└── LICENSE                # MIT License
```

---

## Quality Assurance

### Document Quality

| Document Type | Check Items | Checklist Location |
|---------------|-------------|-------------------|
| FS Functional Specification | 22 items | `.claude/shared/quality-checklist-fs.md` |
| Microarchitecture Specification | 36 items | `.claude/shared/quality-checklist-microarch.md` |
| RTL Implementation | 39 items | `.claude/shared/quality-checklist-impl.md` |

### RTL Coding Standard

Core rules (`.claude/rules/coding-style.md`):
- Verilog-2005 + SV Interface (interface/typedef/modport only)
- Async reset sync release, active-low `rst_n`
- Combinational `always @(*)` must assign defaults, case must have default
- No gated clocks (use standard ICG), no task, no casex/casez
- Submodule instantiation must use named connection
- Generate blocks must have labels
- Comment coverage > 30%

### Automated Checks

| Tool | Command | Purpose |
|------|---------|---------|
| Verilator | `verilator --lint-only -Wall` | RTL lint check |
| Yosys | `yosys -p "read_verilog *.v; synth"` | Synthesis verification |
| D2 | `d2 --layout dagre *.d2 *.png` | Architecture diagram generation |
| wavedrom-cli | `wavedrom-cli -i *.json -p *.png` | Timing diagram generation |

---

## FAQ

### Q: I don't know chip design. Can I use this?

Yes. Agents guide you from requirements step by step. You just need to describe what functionality you want, and the Agent will help you organize requirements, choose solutions, write documents, and generate code.

### Q: Do I need to install all dependencies?

No. The core workflow only needs Claude Code + Python (Pillow + pyyaml). Node.js, D2, Verilator, and Yosys are all optional. When missing, Agents automatically degrade (e.g., charts become text descriptions).

### Q: Can the generated code be directly synthesized?

Yes. The RTL code follows synthesizable coding standards and auto-executes lint checks. However, it's recommended to do complete timing analysis with your target technology library before actual synthesis.

### Q: How do I modify Agent-generated documents/code?

Just edit the files directly. If you modify upstream documents (e.g., FS), you can tell the Agent to regenerate downstream documents (e.g., microarchitecture or RTL). The Agent will automatically detect changes and cascade updates.

### Q: Can I use only some Agents?

Yes. Each Agent is independent. You can skip phases and start from any point. For example, if you already have microarchitecture documents, you can directly ask `chip-code-writer` to generate RTL.

### Q: How do I add my own module design?

1. Create work directory: `bash .claude/skills/chip-create-dir/init_workdir.sh <module_name>`
2. Tell Claude what you want to design: `帮我设计一个 XXX 模块`
3. Agent will guide you through the rest

### Q: What if chart generation fails?

It doesn't affect the core workflow. Agents automatically degrade to text descriptions and preserve D2/Wavedrom source files. You can compile manually later:
```bash
d2 --layout dagre *.d2 *.png
wavedrom-cli -i *.json -p *.png
```

### Q: How do I view timing diagrams?

After installing GTKWave:
```bash
gtkwave simulation.vcd
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.
