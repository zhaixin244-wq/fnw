# fnw

[English](README_en.md)

---

### 概述

**fnw** 是一个 Claude Code 插件，提供从需求探索到 RTL 代码交付的完整 AI 驱动芯片/模块架构设计工作流。它编排多个专业化 AI Agent，每个 Agent 负责芯片设计流程的不同阶段，并以结构化的总线协议、通用构建模块（CBB）、IP 核和行业最佳实践知识库为支撑。

### 核心特性

- **6 个专业化 Agent**，覆盖芯片设计全生命周期：需求探索、功能规格、微架构、架构评审、RTL 编码和代码评审
- **230+ 个 Skill**，涵盖芯片专用任务、工程工作流、代码质量、多语言支持
- **结构化知识库**，包含协议规范（AXI、AHB、APB、PCIe、USB、DDR 等）、CBB 库（FIFO、仲裁器、CDC、ECC 等）、CPU/MMU/网络参考
- **文档模板**，用于功能规格书（FS）和微架构规格书，配备严格的质量检查清单
- **图表生成流水线**，使用 D2（架构图、状态机）和 Wavedrom（时序图）编译为 PNG
- **RTL 编码规范**，通过自动化 lint 检查和全面的设计规则验证强制执行

### 项目结构

```
fnw/
├── .claude/
│   ├── agents/            # 6 个专业化 AI Agent
│   │   ├── chip-requirement-arch.md   # 需求探索 & 方案论证
│   │   ├── chip-fs-writer.md          # 功能规格书编写
│   │   ├── chip-microarch-writer.md   # 微架构规格书编写
│   │   ├── chip-arch-reviewer.md      # 架构评审 & 缺陷分析
│   │   ├── chip-code-writer.md        # RTL 代码实现
│   │   └── chip-arch.md               # 通用芯片架构 Agent
│   ├── skills/            # 230+ 个 Skill 定义
│   │   ├── chip-impl-*/   # RTL 实现相关 Skill（编码、SDC/SVA、lint 等）
│   │   ├── chip-png-*/    # 图表生成（D2、Wavedrom、接口图）
│   │   ├── chip-*-architect/  # CDC、低功耗、可靠性架构
│   │   └── ...            # 工程、测试、DevOps、安全等 Skill
│   ├── knowledge/         # 结构化知识库
│   │   ├── bus-protocol/  # AXI、AHB、APB、PCIe、USB、DDR、SPI、I2C、UART 等
│   │   ├── cbb/           # 通用构建模块（FIFO、仲裁器、CDC、ECC 等）
│   │   ├── IP/            # IP 核参考（ARM、RISC-V、Ethernet、DDR、PCIe、USB）
│   │   ├── cpu/           # CPU 架构（流水线、Cache、分支预测、中断）
│   │   ├── mmu/           # MMU（页表、TLB、虚拟化、内存保护）
│   │   └── ...            # 网络协议、IO 协议、验证
│   ├── rules/             # 编码规范 & 文档模板
│   │   ├── coding-style.md              # RTL 编码规范（Verilog-2005）
│   │   ├── function-spec-template.md    # FS 文档模板
│   │   └── microarchitecture-template.md # 微架构文档模板
│   ├── shared/            # 共享配置 & 质量检查清单
│   ├── prompts/           # Agent 提示词模板
│   ├── phases/            # 工作流阶段定义（JSON）
│   ├── wiki/              # LLM Wiki 知识系统
│   └── tools/             # 外部工具（d2、chromium 等）
├── memory/                # 跨会话持久记忆
├── LICENSE                # MIT 许可证
└── requirements.txt       # Python/Node.js 依赖规格
```

### 设计工作流

插件实现了 5 阶段芯片设计工作流：

| 阶段 | Agent | 输入 | 输出 |
|------|-------|------|------|
| **阶段 1：需求** | `chip-requirement-arch` | 用户的初步需求 | 需求汇总、方案文档、ADR |
| **阶段 2：FS** | `chip-fs-writer` | 需求汇总 + 方案 | 功能规格书（接口定义、PPA 目标、RTM） |
| **阶段 3：微架构** | `chip-microarch-writer` | FS 文档 | 各子模块微架构规格（数据通路、FSM、FIFO、IP 集成） |
| **阶段 4：评审** | `chip-arch-reviewer` | 微架构文档 | 评审报告（需求覆盖度、完整性、缺陷、协议合规） |
| **阶段 5：RTL** | `chip-code-writer` | 评审通过的微架构 | Verilog RTL、SDC 约束、UPF、SVA 断言 |

### Agent 一览

| Agent | 角色 | 专长 |
|-------|------|------|
| **chip-requirement-arch** | 需求探索 & 方案论证 | 头脑风暴、多方案比选、约束收敛、DSE |
| **chip-fs-writer** | 功能规格书编写 | 需求到规格映射、接口定义、PPA 规格、RTM |
| **chip-microarch-writer** | 微架构规格书编写 | 数据通路设计、控制逻辑、FSM、FIFO、IP/CBB 集成 |
| **chip-arch-reviewer** | 架构评审 & 缺陷分析 | 需求覆盖度、文档完整性、协议合规、PPA 审计 |
| **chip-code-writer** | RTL 代码实现 | Verilog/RTL、CDC/RDC、低功耗、SDC、SVA、综合脚本 |

### 芯片专用 Skill（14 个）

| Skill | 说明 |
|-------|------|
| `chip-budget-allocator` | 系统级 PPA 指标按层级拆解到子模块 |
| `chip-cdc-architect` | 时钟域划分与 CDC 信号同步策略 |
| `chip-design-space-explorer` | 面积/性能/功耗三维帕累托最优设计探索 |
| `chip-diagram-generator` | Mermaid/Wavedrom 图表生成 |
| `chip-doc-structurer` | 文档章节结构与内容权重设计 |
| `chip-interface-contractor` | 精确接口契约（端口、时序、SVA） |
| `chip-low-power-architect` | 功耗域、隔离、保持、UPF 设计 |
| `chip-ppa-formatter` | 结构化 PPA 规格表输出 |
| `chip-protocol-compliance-checker` | AXI/ACE/CHI/TileLink/APB/AHB 协议合规检查 |
| `chip-reliability-architect` | ECC/Parity/TMR、老化、IR Drop、ESD 分析 |
| `chip-review-checklister` | 9 维度评审清单与完整性评分 |
| `chip-rtl-guideline-generator` | RTL 编码规范生成（Clock/Reset/DFT/SVA） |
| `chip-traceability-linker` | 需求追溯矩阵（RTM）与覆盖率统计 |
| `chip-version-diff-generator` | 架构版本差异对比与影响分析 |

### 知识库

内置知识库覆盖：

- **总线协议**（17 种）：AXI4、AXI4-Lite、AXI4-Stream、AHB、APB、PCIe、USB、DDR、SPI、I2C、UART、CAN、JTAG、MIPI、TileLink、Wishbone
- **通用构建模块**（40+ 种）：FIFO、仲裁器、CDC 同步器、ECC、CRC、Crossbar、桶形移位器、时钟分频/门控、格雷码等
- **IP 核**：ARM Cortex 系列、RISC-V、Ethernet MAC/PCS、DDR 控制器、PCIe 控制器、USB 控制器、PLL/DLL、SPI/I2C/UART
- **CPU 架构**：流水线、Cache 层次结构、分支预测、中断控制器、多核
- **MMU**：页表、TLB、内存保护、虚拟化、地址空间、内存属性
- **验证方法学**：验证方法论参考

### 环境要求

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI 或 IDE 扩展
- **Python 3.8+**，依赖包：`Pillow`、`pyyaml`、`pytest`
- **Node.js 16+**，依赖包：`@wavedrom/cli`、`playwright-core`
- **D2** 图表语言（可选，用于架构图生成）

### 安装

1. 克隆本仓库到项目根目录：
   ```bash
   git clone <repository-url> .claude
   ```

2. 安装 Python 依赖：
   ```bash
   pip install -r requirements.txt
   ```

3. 安装 Node.js 依赖：
   ```bash
   npm install
   ```

4. （可选）安装 D2 用于架构图生成：
   - 从 [D2 releases](https://github.com/terrastruct/d2/releases) 下载
   - 将 `d2.exe` 放入 `.claude/tools/d2/` 或添加到系统 PATH

### 使用方法

#### 启动新模块设计

```
用户：帮我设计一个 PCIe RC 模块
```

`chip-requirement-arch` Agent 将激活并引导您完成需求探索。

#### 完整工作流示例

```bash
# 阶段 1：需求探索
用户：赵知几，帮我梳理一个 AXI-to-APB bridge 的需求

# 阶段 2：功能规格
用户：小成，根据需求汇总写 FS 文档

# 阶段 3：微架构
用户：小微，基于 FS 写微架构文档

# 阶段 4：架构评审
用户：评审一下微架构文档

# 阶段 5：RTL 实现
用户：根据微架构文档生成 RTL 代码
```

#### Agent 唤醒方式

通过名称或昵称唤醒 Agent：

| Agent | 唤醒名称 |
|-------|---------|
| chip-requirement-arch | 赵知几 / 知几 / 小几 / Archie / 架构师 / 需求师 |
| chip-fs-writer | 钱典成 / 典成 / 小成 / Felix / 规格师 / FS师 |
| chip-microarch-writer | 孙弘微 / 弘微 / 小微 / Sam / 微架构师 |

#### 初始化模块工作目录

```bash
bash .claude/skills/chip-create-dir/init_workdir.sh <模块名>
```

创建标准化目录结构，包含 `ds/`（设计）和 `dv/`（验证）两级子树。

### 质量保障

- **RTL 编码规范**：通过 `rules/coding-style.md` 强制执行 — 覆盖命名、模块声明、时钟/复位、FSM、握手、FIFO、CDC、DFT 和可综合性检查
- **文档质量检查清单**：22 项 FS 检查、36 项微架构检查、39 项 RTL 实现检查
- **自动化 Lint**：集成 Verilator `--lint-only -Wall`
- **SVA 断言**：通过 `` `ifdef ASSERT_ON `` 绑定的 SystemVerilog 断言
- **降级策略**：外部工具不可用时的优雅降级（D2、Wavedrom、RAG）

### 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。
