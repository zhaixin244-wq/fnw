# fnw

[English](README_en.md)

---

### 概述

**fnw** 是一个 Claude Code 插件，提供从需求探索到 RTL 代码交付的完整 AI 驱动芯片/模块架构设计工作流。它编排多个专业化 AI Agent，每个 Agent 负责芯片设计流程的不同阶段，并以结构化的总线协议、通用构建模块（CBB）、IP 核和行业最佳实践知识库为支撑。

### 核心特性

- **12 个专业化 Agent**，覆盖芯片设计全生命周期：需求探索、功能规格、微架构、架构评审、RTL 编码、综合时序、顶层集成、低功耗、DFT、验证架构、验证环境、项目管理
- **230+ 个 Skill**，涵盖芯片专用任务、工程工作流、代码质量、多语言支持
- **结构化知识库**，包含协议规范（AXI、AHB、APB、PCIe、USB、DDR 等）、CBB 库（FIFO、仲裁器、CDC、ECC 等）、CPU/MMU/网络参考
- **文档模板**，用于功能规格书（FS）和微架构规格书，配备严格的质量检查清单
- **图表生成流水线**，使用 D2（架构图、状态机）和 Wavedrom（时序图）编译为 PNG
- **RTL 编码规范**，通过自动化 lint 检查和全面的设计规则验证强制执行
- **内置 UART 示例**，展示从需求到 RTL 的完整设计流程

### 项目结构

```
fnw/
├── .claude/
│   ├── agents/            # 12 个专业化 AI Agent
│   │   ├── chip-requirement-arch.md   # 需求探索 & 方案论证
│   │   ├── chip-fs-writer.md          # 功能规格书编写
│   │   ├── chip-microarch-writer.md   # 微架构规格书编写
│   │   ├── chip-arch-reviewer.md      # 架构评审 & 缺陷分析
│   │   ├── chip-code-writer.md        # RTL 代码实现
│   │   ├── chip-sta-analyst.md        # 综合 & 时序分析
│   │   ├── chip-top-integrator.md     # 顶层集成
│   │   ├── chip-lowpower-designer.md  # 低功耗设计
│   │   ├── chip-dft-engineer.md       # DFT 设计
│   │   ├── chip-verfi-arch.md         # 验证架构
│   │   ├── chip-env-writer.md         # 验证环境编写
│   │   └── chip-project-lead.md       # 项目管理
│   ├── skills/            # 230+ 个 Skill 定义
│   ├── knowledge/         # 结构化知识库
│   ├── rules/             # 编码规范 & 文档模板
│   ├── shared/            # 共享配置 & 质量检查清单
│   ├── wiki/              # LLM Wiki 知识系统
│   └── tools/             # 外部工具（d2、chromium 等）
├── uart_work/             # UART 示例工作区（完整设计流程演示）
│   ├── ds/doc/pr/         # 需求汇总、方案、ADR
│   ├── ds/doc/fs/         # 功能规格书
│   ├── ds/doc/ua/         # 微架构文档 + 评审报告
│   ├── ds/rtl/            # RTL 源码（7 个子模块 + SVA）
│   └── ds/run/            # 综合/Lint 脚本
├── memory/                # 跨会话持久记忆
└── requirements.txt       # Python/Node.js 依赖规格
```

### 设计工作流

插件实现完整的芯片设计工作流：

| 阶段 | Agent | 输入 | 输出 |
|------|-------|------|------|
| **阶段 1：需求** | `chip-requirement-arch` | 用户的初步需求 | 需求汇总、方案文档、ADR |
| **阶段 2：FS** | `chip-fs-writer` | 需求汇总 + 方案 | 功能规格书（接口定义、PPA 目标、RTM） |
| **阶段 3：微架构** | `chip-microarch-writer` | FS 文档 | 各子模块微架构规格（数据通路、FSM、FIFO、IP 集成） |
| **阶段 4：评审** | `chip-arch-reviewer` | 微架构文档 | 评审报告（需求覆盖度、完整性、缺陷、协议合规） |
| **阶段 5：RTL** | `chip-code-writer` | 评审通过的微架构 | Verilog RTL、SDC 约束、UPF、SVA 断言 |
| **阶段 6：综合** | `chip-sta-analyst` | RTL + SDC | 综合报告、时序报告、面积报告 |
| **阶段 7：集成** | `chip-top-integrator` | 子模块 RTL | 顶层模块、接口检查、系统 lint |

### Agent 一览

| Agent | 角色 | 唤醒名称 |
|-------|------|----------|
| **chip-requirement-arch** | 需求探索 & 方案论证 | 赵知几 / 知几 / 小几 / Archie |
| **chip-fs-writer** | 功能规格书编写 | 钱典成 / 典成 / 小成 / Felix |
| **chip-microarch-writer** | 微架构规格书编写 | 孙弘微 / 弘微 / 小微 / Marcus |
| **chip-arch-reviewer** | 架构评审 & 缺陷分析 | 宋晶瑶 / 晶瑶 / Clara |
| **chip-code-writer** | RTL 代码实现 | 张铭研 / 铭研 / Ethan |
| **chip-sta-analyst** | 综合 & 时序分析 | 周闻哲 / 闻哲 / Winston |
| **chip-top-integrator** | 顶层集成 | 陆灵犀 / 灵犀 / Lexi |
| **chip-lowpower-designer** | 低功耗设计 | 沈未央 / 未央 / Shannon |
| **chip-dft-engineer** | DFT 设计 | 陆青萝 / 青萝 / Tina |
| **chip-verfi-arch** | 验证架构 | 顾衡之 / 衡之 / Daniel |
| **chip-env-writer** | 验证环境编写 | 韩映川 / 映川 / Henry |
| **chip-project-lead** | 项目管理 | 林若水 / 若水 / Linus |

### 使用方法

#### 快速开始

```bash
# 1. 克隆仓库
git clone <repository-url> fnw

# 2. 安装依赖
cd fnw
pip install -r requirements.txt
npm install

# 3. 在 Claude Code 中使用
# 直接告诉 Claude 你要设计什么模块即可
```

#### 启动新模块设计

```
用户：帮我设计一个 UART 模块
```

`chip-requirement-arch` Agent 将激活并引导您完成需求探索。

#### 完整工作流示例（UART）

```bash
# 阶段 1：需求探索
用户：赵知几，帮我梳理一个 UART 模块的需求

# 阶段 2：功能规格
用户：小成，根据需求汇总写 FS 文档

# 阶段 3：微架构
用户：小微，基于 FS 写微架构文档

# 阶段 4：架构评审
用户：晶瑶，评审一下微架构文档

# 阶段 5：RTL 实现
用户：铭研，根据微架构文档生成 RTL 代码

# 阶段 6：综合验证
用户：闻哲，对 RTL 进行综合和时序分析
```

#### 初始化模块工作目录

```bash
bash .claude/skills/chip-create-dir/init_workdir.sh <模块名>
```

创建标准化目录结构，包含 `ds/`（设计）和 `dv/`（验证）两级子树。

### 内置示例：UART

项目包含一个完整的 UART 模块设计示例（`uart_work/`），展示从需求到 RTL 的全流程：

| 文件 | 说明 |
|------|------|
| `ds/doc/pr/uart_requirement_summary_v1.0.md` | 需求汇总（17 条需求） |
| `ds/doc/pr/uart_solution_v1.0.md` | 架构方案（4 个 ADR） |
| `ds/doc/fs/uart_FS_v1.0.md` | 功能规格书（15 章，1250 行） |
| `ds/doc/ua/*_microarch_v1.0.md` | 7 个子模块微架构文档 |
| `ds/doc/ua/uart_review_report_v1.0.md` | 架构评审报告 |
| `ds/rtl/*.v` | 7 个 RTL 源文件 + SVA 断言 |
| `ds/run/` | Lint/综合脚本 + SDC 约束 |

**UART 模块特性**：
- 标准 UART 异步通信（5/6/7/8 数据位，1/1.5/2 停止位，奇偶校验）
- 小数波特率发生器（9600~921600 bps，精度 < 0.1%）
- TX/RX FIFO（深度 16，寄存器阵列）
- 硬件 RTS/CTS 流控
- 16550 兼容寄存器布局
- APB 从接口
- Loopback 自测试模式

### 质量保障

- **RTL 编码规范**：通过 `rules/coding-style.md` 强制执行
- **文档质量检查清单**：22 项 FS 检查、36 项微架构检查、39 项 RTL 实现检查
- **自动化 Lint**：集成 Verilator `--lint-only -Wall`
- **SVA 断言**：通过 `` `ifdef ASSERT_ON `` 绑定的 SystemVerilog 断言
- **降级策略**：外部工具不可用时的优雅降级（D2、Wavedrom、RAG）

### 环境要求

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI 或 IDE 扩展
- **Python 3.8+**，依赖包：`Pillow`、`pyyaml`、`pytest`
- **Node.js 16+**，依赖包：`@wavedrom/cli`、`playwright-core`
- **D2** 图表语言（可选，用于架构图生成）
- **Verilator**（可选，用于 RTL lint 检查）
- **Yosys**（可选，用于综合验证）

### 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。
