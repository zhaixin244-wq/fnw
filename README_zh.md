# fnw — AI 驱动芯片设计平台

[English](README_en.md)

---

## 目录

- [概述](#概述)
- [环境要求与安装](#环境要求与安装)
- [快速开始](#快速开始)
- [Agent 详解与对话示例](#agent-详解与对话示例)
- [设计工作流](#设计工作流)
- [内置示例：UART](#内置示例uart)
- [项目结构](#项目结构)
- [质量保障](#质量保障)
- [常见问题](#常见问题)

---

## 概述

**fnw** 是一个 Claude Code 插件，提供从需求探索到 RTL 代码交付的完整 AI 驱动芯片/模块架构设计工作流。

**核心能力**：
- **12 个专业化 Agent**，覆盖芯片设计全生命周期
- **230+ 个 Skill**，涵盖芯片专用任务和工程工作流
- **结构化知识库**，包含 17+ 总线协议、40+ CBB、IP 核参考
- **文档模板**，FS（22 项检查）和微架构（36 项检查）质量门控
- **RTL 编码规范**，39 项实现检查 + Verilator lint 集成
- **图表生成**，D2 架构图 + Wavedrom 时序图

---

## 环境要求与安装

### 必需环境

| 工具 | 版本要求 | 用途 |
|------|----------|------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | 最新版 | AI Agent 运行平台 |
| [Python](https://www.python.org/) | 3.8+ | 图表处理、脚本工具 |
| [Node.js](https://nodejs.org/) | 16+ | Wavedrom 时序图生成 |

### 可选工具（推荐安装）

| 工具 | 用途 | 下载地址 |
|------|------|----------|
| [D2](https://d2lang.com/) | 架构图、状态机图生成 | [GitHub Releases](https://github.com/terrastruct/d2/releases) |
| [Verilator](https://www.veripool.org/verilator/) | RTL lint 检查 | [官网](https://www.veripool.org/verilator/) |
| [Yosys](https://yosyshq.net/yosys/) | RTL 综合验证 | [GitHub](https://github.com/YosysHQ/yosys) |
| [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite) | 一站式 EDA 工具包（含 Verilator + Yosys + GTKWave） | [GitHub Releases](https://github.com/YosysHQ/oss-cad-suite/releases) |

### 安装步骤

#### 1. 克隆仓库

```bash
# 方式一：作为项目根目录使用
git clone <repository-url> fnw
cd fnw

# 方式二：作为已有项目的 Claude 插件
cd your_project
git clone <repository-url> .claude
```

#### 2. 安装 Python 依赖

```bash
pip install -r requirements.txt
```

**核心依赖说明**：

| 包名 | 用途 | 是否必需 |
|------|------|----------|
| `Pillow>=9.0` | 接口图生成（chip-png-interface-gen） | 推荐 |
| `pyyaml>=6.0` | YAML 配置解析 | 推荐 |
| `pytest>=7.0` | 测试框架 | 可选 |
| `python-dotenv>=1.0` | 环境变量加载 | 可选 |

> 如果只做 RTL 设计，只需安装 `Pillow` 和 `pyyaml`：
> ```bash
> pip install Pillow pyyaml
> ```

#### 3. 安装 Node.js 依赖

```bash
npm install
```

**核心依赖说明**：

| 包名 | 用途 | 是否必需 |
|------|------|----------|
| `@wavedrom/cli` | Wavedrom 时序图 JSON → SVG/PNG | 推荐 |
| `playwright-core` | 无头浏览器渲染图表 | 推荐 |

> 如果不需要时序图生成，可以跳过 Node.js 安装。

#### 4. 安装 D2（可选，用于架构图）

```bash
# Windows (使用 scoop)
scoop install d2

# macOS (使用 brew)
brew install d2

# Linux (使用官方脚本)
curl -fsSL https://d2lang.com/install.sh | sh -

# 或手动下载：https://github.com/terrastruct/d2/releases
# 将 d2 可执行文件放入 .claude/tools/d2/ 或添加到系统 PATH
```

#### 5. 安装 EDA 工具（可选，用于 lint/综合）

```bash
# 推荐使用 oss-cad-suite（包含 Verilator + Yosys + GTKWave）
# 下载地址：https://github.com/YosysHQ/oss-cad-suite/releases
# 解压后将 bin/ 目录添加到系统 PATH

# 验证安装
verilator --version
yosys --version
```

#### 6. 验证安装

```bash
# 检查 Python
python --version  # 应 >= 3.8

# 检查 Node.js
node --version  # 应 >= 16

# 检查 D2（如已安装）
d2 --version

# 检查 Verilator（如已安装）
verilator --version
```

### 安装问题排查

| 问题 | 解决方案 |
|------|----------|
| `pip install` 报错权限不足 | 使用 `pip install --user -r requirements.txt` |
| `npm install` 报错 | 尝试 `npm install --legacy-peer-deps` |
| D2 命令找不到 | 确认已添加到 PATH，或放置在 `.claude/tools/d2/` |
| Verilator 缺少 Perl 模块 | 安装 `Pod::Usage`：`cpan install Pod::Usage` |
| 图表生成失败 | 不影响核心工作流，Agent 会自动降级为文本描述 |

---

## 快速开始

### 第一次使用

1. 打开 Claude Code（CLI 或 IDE 扩展）
2. 进入项目目录
3. 直接告诉 Claude 你想设计什么：

```
用户：帮我设计一个 UART 模块
```

Claude 会自动激活 `chip-requirement-arch` Agent，引导你完成需求探索。

### 最简流程（3 步出 RTL）

```
用户：帮我设计一个简单的 GPIO 模块，8 位宽，支持输入输出方向配置

# Agent 会自动完成需求探索 → FS → 微架构 → RTL 全流程
# 如果想一步步来，可以说：
用户：一步步来，先帮我梳理需求
```

### 控制执行模式

| 你说的话 | Agent 行为 |
|----------|-----------|
| "一步步来" / "先出清单" | 步进模式：每步暂停等你确认 |
| "直接写" / "一口气完成" | 连续模式：列出清单后连续执行 |
| "暂停一下" | 在任意时刻暂停 |
| "继续" | 从暂停处继续 |

---

## Agent 详解与对话示例

### 1. chip-requirement-arch（需求探索 & 方案论证）

**角色**：赵知几（Archie）—— 需求探索与架构方案专家

**能做什么**：
- 从模糊需求收敛到明确的模块规格
- 多方案比选（面积 vs 性能 vs 功耗权衡）
- 需求汇总表、架构方案文档、ADR（架构决策记录）生成
- 协议选型对比（如 AXI vs AHB vs APB）
- CBB 选型指导（FIFO、仲裁器、CDC 等）

**唤醒方式**：`赵知几` / `知几` / `小几` / `Archie` / `需求师`

**对话示例**：

```
用户：赵知几，我想设计一个 SPI Master 模块，支持 4 种 SPI 模式，
     最高时钟 50MHz，挂在外设总线上。帮我梳理一下需求。

Archie：【需求探索 · 赵知几/Archie】

好的，让我先梳理一下需求。我会从以下几个维度来分析：

1. 协议规范：SPI 4 种模式（CPOL/CPHA 组合）
2. 接口需求：APB 配置接口 + SPI 物理接口
3. 功能需求：Master 角色、可配时钟分频、片选管理
4. 性能需求：50MHz SPI 时钟、FIFO 深度
5. 可靠性需求：超时检测、错误处理

我先生成需求汇总表，然后给出方案比选。需要我一步步来还是直接生成？

用户：直接生成

Archie：好的，我来生成需求汇总和方案文档...
```

**输出文件**：
- `{module}_requirement_summary_v1.0.md` — 需求汇总表
- `{module}_solution_v1.0.md` — 架构方案文档
- `{module}_ADR_v1.0.md` — 架构决策记录

---

### 2. chip-fs-writer（功能规格书编写）

**角色**：钱典成（Felix）—— 功能规格文档专家

**能做什么**：
- 将需求汇总 + 方案转化为正式的 FS 功能规格书
- 精确定义每个接口（信号名、位宽、方向、时钟域、复位值）
- 完整的寄存器定义（地址映射 + 位域 + 访问类型）
- PPA 量化指标（性能/功耗/面积）
- 需求追溯矩阵（RTM）确保每条需求都有对应规格

**唤醒方式**：`钱典成` / `典成` / `小成` / `Felix` / `规格师`

**对话示例**：

```
用户：小成，根据 uart_work/ds/doc/pr/ 下面的需求和方案文档，
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

用户：好的，开始吧

Felix：正在编写功能规格书...
```

**输出文件**：
- `{module}_FS_v1.0.md` — 功能规格书（含 15 章完整内容）

**关键检查项**：
- 每条 REQ 都有对应的 FS 章节
- 每个接口都有完整的信号列表
- 每个寄存器都有位域定义
- PPA 指标都有量化值或标注"待综合验证"

---

### 3. chip-microarch-writer（微架构规格书编写）

**角色**：陈佳微（Marcus）—— 微架构设计专家

**能做什么**：
- 将 FS 转化为可直接指导 RTL 编码的微架构文档
- 数据通路设计（从输入到输出的完整路径）
- 状态机设计（状态定义 + 转移条件 + 编码方式）
- FIFO 深度计算（基于流控模型，非拍脑袋）
- 关键时序分析（Tslack 公式 + SDC 约束建议）
- IP/CBB 集成方案

**唤醒方式**：`陈佳微` / `佳微` / `小微` / `Marcus` / `微架构师`

**对话示例**：

```
用户：小微，基于 uart_FS_v1.0.md，为每个子模块写微架构文档。

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

用户：直接写，一口气完成

Marcus：好的，连续模式。开始逐个生成...
```

**输出文件**：
- `{module}_{submodule}_microarch_v1.0.md` — 每个子模块的微架构文档

**铁律**：
- FIFO 深度必须有计算依据
- 顶层模块只做连线，禁止逻辑
- 寄存器模块只做配置，功能表放功能模块

---

### 4. chip-arch-reviewer（架构评审）

**角色**：宋晶瑶（Clara）—— 架构评审专家

**能做什么**：
- 交付物齐全性检查（PR/FS/UA/RTL/SVA/SDC/脚本）
- PR→FS 需求追溯（覆盖率统计）
- FS→UA 端口/参数一致性检查
- UA→RTL 实现一致性检查
- 编码规范检查（coding-style.md 39 项）
- 架构缺陷扫描（组合环路/latch/CDC/复位）
- 生成评审报告（Critical/Major/Minor 分级）

**唤醒方式**：`宋晶瑶` / `晶瑶` / `Clara` / `评审师`

**对话示例**：

```
用户：晶瑶，评审一下 UART 的微架构和 RTL 代码。

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

用户：好的

Clara：正在扫描交付物...

[Step 1] 交付物检查：✅ 全部齐全
[Step 3] 需求追溯：17/17 REQ 覆盖，覆盖率 100%
[Step 5] UA→RTL 一致性：发现 3 个 Critical 问题...

评审报告已生成，结论：⚠️ 有条件通过
```

**输出文件**：
- `{module}_review_report_v1.0.md` — 评审报告

**评审结论**：
- ✅ 通过：所有检查项通过，可进入下一阶段
- ⚠️ 有条件通过：部分问题需修复后重新验证
- ❌ 不通过：存在严重问题，需返回设计阶段

---

### 5. chip-code-writer（RTL 代码实现）

**角色**：张铭研（Ethan）—— RTL 编码专家

**能做什么**：
- 根据微架构文档生成可综合的 Verilog RTL 代码
- 生成 SVA 断言文件（握手稳定性/数据稳定性/FSM 检查）
- 生成 SDC 约束文件
- 生成 Lint 脚本和综合脚本
- 自动执行 Verilator lint 检查（0 error 门禁）
- 自动执行 Yosys 综合验证
- Lint/综合失败时自动修复（自愈循环，最多 10 次）

**唤醒方式**：`张铭研` / `铭研` / `Ethan` / `RTL工程师`

**对话示例**：

```
用户：铭研，根据微架构文档生成 UART 的 RTL 代码。

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

用户：开始

Ethan：正在生成 uart_fifo.v（底层 CBB 优先）...
```

**输出文件**：
- `{module}_top.v` — 顶层模块
- `{module}_{sub}.v` — 各子模块 RTL
- `{module}_sva.sv` — SVA 断言
- `{module}.f` — 文件列表
- `{module}.sdc` — SDC 约束
- `lint.sh` — Lint 检查脚本
- `synth_yosys.tcl` — 综合脚本

**质量门禁（自动执行）**：
- Verilator `--lint-only -Wall` 零 error
- Yosys 综合零 error + 面积合理
- 自检 IC-01~39 + IM-01~08 全部通过

---

### 6. chip-sta-analyst（综合与时序分析）

**角色**：周闻哲（Winston）—— 综合与时序专家

**能做什么**：
- RTL 综合（Yosys/Design Compiler）
- SDC 约束编写与优化
- 时序分析（建立时间/保持时间检查）
- 面积预估与优化建议
- 时序违例修复建议（重定时/流水线/逻辑优化）

**唤醒方式**：`周闻哲` / `闻哲` / `Winston` / `综合工程师`

**对话示例**：

```
用户：闻哲，对 UART RTL 进行综合和时序分析。

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

**输出文件**：
- `synth_report.md` — 综合报告
- `timing_report.md` — 时序报告
- `area_report.md` — 面积报告

---

### 7. chip-top-integrator（顶层集成）

**角色**：陆灵犀（Lexi）—— 顶层集成专家

**能做什么**：
- 子模块集成与连线
- 跨模块接口对齐检查
- 系统级 lint
- 顶层连线验证
- 集成测试

**唤醒方式**：`陆灵犀` / `灵犀` / `Lexi` / `集成工程师`

**对话示例**：

```
用户：灵犀，把 UART 的 7 个子模块集成到顶层。

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

### 8. chip-lowpower-designer（低功耗设计）

**角色**：沈未央（Shannon）—— 低功耗设计专家

**能做什么**：
- 功耗域规划
- UPF 文件生成
- Isolation / Level Shifter 方案
- Clock Gating 设计
- 功耗分析与优化

**唤醒方式**：`沈未央` / `未央` / `Shannon` / `低功耗设计师`

**对话示例**：

```
用户：未央，为 UART 模块做低功耗设计，需要支持睡眠模式。

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

**输出文件**：
- `{module}.upf` — UPF 低功耗文件
- `lowpower_design.md` — 低功耗方案文档

---

### 9. chip-dft-engineer（DFT 设计）

**角色**：陆青萝（Tina）—— DFT 设计专家

**能做什么**：
- DFT 架构规划
- 扫描链插入
- MBIST / LBIST 集成
- ATPG 测试向量生成
- DFT 检查报告

**唤醒方式**：`陆青萝` / `青萝` / `Tina` / `DFT工程师`

**对话示例**：

```
用户：青萝，为 UART 添加 DFT 支持。

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

**输出文件**：
- `dft_architecture.md` — DFT 架构文档
- `dft_check_report.md` — DFT 检查报告

---

### 10. chip-verfi-arch（验证架构）

**角色**：顾衡之（Daniel）—— 验证架构专家

**能做什么**：
- 测试点分解（从 FS 需求到可验证的测试点）
- 验证环境方案设计（UVM 架构、Agent 配置）
- 用例规划（功能覆盖、边界覆盖、异常覆盖）
- 覆盖率模型定义
- 验证计划文档生成

**唤醒方式**：`顾衡之` / `衡之` / `Daniel` / `验证架构师`

**对话示例**：

```
用户：衡之，为 UART 制定验证计划。

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

**输出文件**：
- `dv/doc/plan/verification_plan.md` — 总验证方案
- `dv/doc/chk_point/test_points.md` — 测试点分解
- `dv/env/plan/env_architecture.md` — 验证环境方案

---

### 11. chip-env-writer（验证环境编写）

**角色**：韩映川（Henry）—— 验证环境实现专家

**能做什么**：
- 根据验证方案生成完整的 UVM 验证环境代码
- Agent / Driver / Monitor / Scoreboard / Coverage
- Env / Test / Sequence / TB Top
- 编译检查门禁（0 Error）
- 方案一致性自检

**唤醒方式**：`韩映川` / `映川` / `Henry` / `TB工程师`

**对话示例**：

```
用户：映川，根据验证方案生成 UART 的 UVM 验证环境。

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

**输出文件**：
- `dv/env/*.sv` — UVM 验证环境代码
- `dv/tb/*.sv` — Testbench 顶层
- `dv/case/*.sv` — 测试用例

---

### 12. chip-project-lead（项目管理）

**角色**：林若水（Linus）—— 项目总负责人

**能做什么**：
- 项目全景图和进度跟踪
- 风险识别与管控
- 跨模块协调
- 门控检查（Gate Review）
- 汇报材料生成

**唤醒方式**：`林若水` / `若水` / `Linus` / `项目负责人`

**对话示例**：

```
用户：若水，帮我梳理一下 UART 项目的整体进度。

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

## 设计工作流

### 标准流程

```
用户需求
    │
    ▼
┌─────────────────┐
│ 1. 需求探索      │  chip-requirement-arch
│    需求汇总 + 方案 │  → requirement_summary + solution + ADR
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 2. 功能规格      │  chip-fs-writer
│    15 章 FS 文档  │  → {module}_FS_v1.0.md
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 3. 微架构        │  chip-microarch-writer
│    每子模块独立文档 │  → {sub}_microarch_v1.0.md × N
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 4. 架构评审      │  chip-arch-reviewer
│    9 步全面检查   │  → review_report_v1.0.md
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 5. RTL 实现      │  chip-code-writer
│    Verilog + SVA  │  → *.v + *_sva.sv + .sdc
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 6. 综合验证      │  chip-sta-analyst
│    时序 + 面积    │  → 综合报告 + 时序报告
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 7. 顶层集成      │  chip-top-integrator
│    子模块连线     │  → {module}_top.v
└─────────────────┘
```

### 非标准流程（按需使用）

| 场景 | 使用的 Agent |
|------|-------------|
| 需要低功耗设计 | `chip-lowpower-designer` |
| 需要 DFT 支持 | `chip-dft-engineer` |
| 需要验证计划 | `chip-verfi-arch` |
| 需要 UVM 环境 | `chip-env-writer` |
| 需要项目管理 | `chip-project-lead` |

---

## 内置示例：UART

项目包含一个完整的 UART 模块设计示例（`uart_work/`），展示从需求到 RTL 的全流程。

### 文件清单

```
uart_work/
├── ds/doc/pr/
│   ├── uart_requirement_summary_v1.0.md   # 需求汇总（17 条需求）
│   ├── uart_solution_v1.0.md              # 架构方案（子模块划分）
│   └── uart_ADR_v1.0.md                   # 架构决策记录（5 个 ADR）
├── ds/doc/fs/
│   └── uart_FS_v1.0.md                    # 功能规格书（15 章，1250 行）
├── ds/doc/ua/
│   ├── uart_fifo_microarch_v1.0.md        # FIFO 微架构
│   ├── uart_baud_gen_microarch_v1.0.md    # 波特率发生器微架构
│   ├── uart_reg_mod_microarch_v1.0.md     # 寄存器模块微架构
│   ├── uart_tx_microarch_v1.0.md          # 发送模块微架构
│   ├── uart_rx_microarch_v1.0.md          # 接收模块微架构
│   ├── uart_ctrl_microarch_v1.0.md        # 控制模块微架构
│   ├── uart_top_microarch_v1.0.md         # 顶层模块微架构
│   └── uart_review_report_v1.0.md         # 架构评审报告
├── ds/rtl/
│   ├── uart_fifo.v                        # 参数化同步 FIFO
│   ├── uart_baud_gen.v                    # 小数波特率发生器
│   ├── uart_tx.v                          # 发送 FSM + 移位寄存器
│   ├── uart_rx.v                          # 接收 FSM + 过采样 + CDC
│   ├── uart_reg_mod.v                     # APB 寄存器模块
│   ├── uart_ctrl.v                        # 中断聚合 + 流控
│   ├── uart_top.v                         # 顶层集成
│   └── uart_sva.sv                        # SVA 断言
└── ds/run/
    ├── uart.f                             # 文件列表
    ├── uart.sdc                           # SDC 约束（50MHz）
    ├── lint.sh                            # Lint 检查脚本
    └── synth_yosys.tcl                    # Yosys 综合脚本
```

### UART 模块特性

| 特性 | 规格 |
|------|------|
| 通信协议 | 标准 UART 异步串行 |
| 数据位 | 5 / 6 / 7 / 8 位可配 |
| 停止位 | 1 / 1.5 / 2 位可配 |
| 校验 | 奇校验 / 偶校验 / 无校验 |
| 波特率 | 9600 ~ 921600 bps（小数分频，精度 < 0.1%） |
| FIFO | TX 16 字节 + RX 16 字节 |
| 流控 | 硬件 RTS/CTS |
| 中断 | TX 空 / RX 满 / 帧错误 / 校验错误 / Break |
| 寄存器 | 16550 兼容布局 |
| 接口 | APB 从接口（32 位数据宽度） |
| 测试 | Loopback 自测试模式 |
| 过采样 | 16x / 8x 可配 |

---

## 项目结构

```
fnw/
├── .claude/
│   ├── agents/            # 12 个专业化 AI Agent 定义
│   ├── skills/            # 230+ 个 Skill 定义
│   ├── knowledge/         # 结构化知识库
│   │   ├── bus-protocol/  # 总线协议（AXI/AHB/APB/PCIe/USB/DDR/SPI/I2C/UART...）
│   │   ├── cbb/           # 通用构建模块（FIFO/仲裁器/CDC/ECC/CRC...）
│   │   ├── IP/            # IP 核参考
│   │   ├── cpu/           # CPU 架构
│   │   └── mmu/           # MMU
│   ├── rules/             # 编码规范 & 文档模板
│   │   ├── coding-style.md              # RTL 编码规范
│   │   ├── function-spec-template.md    # FS 模板
│   │   ├── microarchitecture-template.md # 微架构模板
│   │   └── review-report-template.md    # 评审报告模板
│   ├── shared/            # 共享配置 & 质量检查清单
│   │   ├── quality-checklist-fs.md      # FS 质量检查（22 项）
│   │   ├── quality-checklist-microarch.md # 微架构质量检查（36 项）
│   │   ├── quality-checklist-impl.md    # RTL 实现检查（39 项）
│   │   └── ...                          # 交互风格、降级策略、变更传播等
│   ├── wiki/              # LLM Wiki 知识系统
│   └── tools/             # 外部工具配置
├── uart_work/             # UART 示例工作区
├── memory/                # 跨会话持久记忆
├── doc/member/            # Agent 成员档案
├── requirements.txt       # Python 依赖
├── package.json           # Node.js 依赖
└── LICENSE                # MIT 许可证
```

---

## 质量保障

### 文档质量

| 文档类型 | 检查项数 | 检查清单位置 |
|----------|----------|-------------|
| FS 功能规格书 | 22 项 | `.claude/shared/quality-checklist-fs.md` |
| 微架构规格书 | 36 项 | `.claude/shared/quality-checklist-microarch.md` |
| RTL 实现 | 39 项 | `.claude/shared/quality-checklist-impl.md` |

### RTL 编码规范

核心规则（`.claude/rules/coding-style.md`）：
- Verilog-2005 + SV Interface（仅 interface/typedef/modport）
- 异步复位同步释放，低有效 `rst_n`
- 组合逻辑 `always @(*)` 必须赋默认值，case 必须有 default
- 禁止门控时钟（用标准 ICG）、禁止 task、禁止 casex/casez
- 子模块实例化必须名称关联
- generate 块必须有标签
- 注释覆盖率 > 30%

### 自动化检查

| 工具 | 命令 | 用途 |
|------|------|------|
| Verilator | `verilator --lint-only -Wall` | RTL lint 检查 |
| Yosys | `yosys -p "read_verilog *.v; synth"` | 综合验证 |
| D2 | `d2 --layout dagre *.d2 *.png` | 架构图生成 |
| wavedrom-cli | `wavedrom-cli -i *.json -p *.png` | 时序图生成 |

---

## 常见问题

### Q: 我不懂芯片设计，能用吗？

可以。Agent 会引导你从需求开始，一步步完成设计。你只需要描述你想要什么功能，Agent 会帮你梳理需求、选择方案、编写文档、生成代码。

### Q: 需要安装所有依赖吗？

不需要。核心工作流只需要 Claude Code + Python（Pillow + pyyaml）。Node.js、D2、Verilator、Yosys 都是可选的。缺少时 Agent 会自动降级（如图表用文本描述代替）。

### Q: Agent 生成的代码可以直接综合吗？

可以。Agent 生成的 RTL 代码遵循可综合编码规范，并自动执行 lint 检查。但建议在实际综合前，用目标工艺库进行完整的时序分析。

### Q: 如何修改 Agent 生成的文档/代码？

直接编辑文件即可。如果你修改了上游文档（如 FS），可以告诉 Agent 重新生成下游文档（如微架构或 RTL）。Agent 会自动检测变更并进行级联更新。

### Q: 可以只用部分 Agent 吗？

可以。每个 Agent 都是独立的。你可以跳过某些阶段，直接从任意阶段开始。例如，如果你已经有微架构文档，可以直接让 `chip-code-writer` 生成 RTL。

### Q: 如何添加自己的模块设计？

1. 创建工作目录：`bash .claude/skills/chip-create-dir/init_workdir.sh <模块名>`
2. 告诉 Claude 你要设计什么：`帮我设计一个 XXX 模块`
3. Agent 会引导你完成后续流程

### Q: 图表生成失败怎么办？

不影响核心工作流。Agent 会自动降级为文本描述，并保留 D2/Wavedrom 源文件。你可以稍后手动编译：
```bash
d2 --layout dagre *.d2 *.png
wavedrom-cli -i *.json -p *.png
```

### Q: 如何查看时序图？

安装 GTKWave 后：
```bash
gtkwave simulation.vcd
```

---

## 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。
