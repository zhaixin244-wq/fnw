# chip-requirement-arch 调试模式

> 通过双 Agent 自动对话验证需求探索流程与质量

---

## 概述

调试模式用于自动化测试 chip-requirement-arch agent 的流程执行质量。通过启动两个 subagent（一个扮演用户，一个扮演苏启辰），模拟真实对话场景，验证流程完整性、交付物质量和 REQ 编号规范。

---

## 快速开始

### 运行基础场景

```
/test-chip-requirement-arch basic_dma
```

### 运行其他场景

```
/test-chip-requirement-arch complex_pcie
/test-chip-requirement-arch vague_input
/test-chip-requirement-arch edge_cases
```

### 运行复杂模块随机场景（40k+ RTL）

```
/test-chip-requirement-arch complex_random
```

从 50 个 4 万行以上 RTL 的复杂模块中随机选择一个，覆盖全部测试维度。详见 `scenarios/complex_modules/README.md`。

---

## 可用场景

| 场景 ID | 名称 | 描述 | 用户角色 | 预计耗时 |
|---------|------|------|----------|----------|
| `basic_dma` | 基础 DMA | 标准流程测试 | clear_expert | 30 min |
| `complex_pcie` | 复杂 PCIe | 高级场景测试 | clear_expert | 45 min |
| `vague_input` | 模糊输入 | 边界测试 | vague_beginner | 40 min |
| `edge_cases` | 边界条件 | 异常处理测试 | challenging_reviewer | 50 min |
| `complex_random` | 复杂模块随机 | 从 50 个 40k+ RTL 模块池随机选择 | 随机（E/C/V） | 50~70 min |

### 场景说明

#### basic_dma - 基础 DMA
- **模块**: DMA 引擎
- **特点**: 单通道 DMA + APB 控制 + AXI4 Master
- **测试重点**: 标准流程执行、REQ 编号规范
- **适用**: 验证基本功能

#### complex_pcie - 复杂 PCIe
- **模块**: PCIe 控制器
- **特点**: PCIe Gen4 x16、多虚拟通道、高性能要求
- **测试重点**: 复杂协议处理、多通道管理
- **适用**: 验证高级场景处理能力

#### vague_input - 模糊输入
- **模块**: 数据处理器
- **特点**: 用户表达模糊、需求不明确
- **测试重点**: 追问能力、澄清技巧、需求收敛
- **适用**: 验证引导能力

#### edge_cases - 边界条件
- **模块**: 混合控制器
- **特点**: 多协议桥接、复杂约束、挑战性问题
- **测试重点**: 矛盾处理、需求变更应对、对抗性问题回答
- **适用**: 验证应变能力

---

## 用户角色

| 角色 ID | 名称 | 特点 | 适用场景 |
|---------|------|------|----------|
| `clear_expert` | 清晰表达的专家 | 回复直接、信息完整 | basic_dma, complex_pcie |
| `vague_beginner` | 模糊表达的新手 | 回复模糊、需要引导 | vague_input |
| `challenging_reviewer` | 挑战性审查者 | 提出质疑、要求论证 | edge_cases |

---

## 输出结构

```
.claude/debug/chip-requirement-arch/debug_output/
└── {scenario_id}_{timestamp}/
    ├── dialog.md           # 完整对话记录
    ├── evaluation.md       # 质量评估报告
    ├── summary.md          # 调试摘要
    ├── outputs/            # 生成的交付物
    │   ├── {module}_pr_v1.0.md
    │   ├── {module}_requirement_summary_v1.0.md
    │   ├── {module}_solution_v1.0.md
    │   ├── {module}_ADR_v1.0.md
    │   └── {module}_trace_graph.yaml
    └── flow/               # 流程记录
        └── {module}_pr_v1.0.md
```

---

## 评估标准

调试模式复用现有的评估标准：

- **评估标准文件**: `.claude/evaluation_criteria/chip-requirement-arch-eva.md`
- **满分**: 100 分
- **等级**: S (90-100), A (80-89), B (70-79), C (60-69), D (<60)

### 门控检查

| 门控 | 检查内容 | 不通过结果 |
|------|----------|------------|
| 门控 1 | 流程完整性 (G-01~G-09) | 直接 D 级 |
| 门控 2 | 文档质量 (G-10~G-18) | 直接 C 级 |

### 评估维度

| 维度 | 权重 | 说明 |
|------|------|------|
| D1 需求采集完整性 | 17% | stage0/stageA/stageB 执行质量 |
| D2 需求一致性 | 7% | stageC 矛盾检测质量 |
| D3 需求文档质量 | 11% | stageC 汇总表质量 |
| D4 方案细化质量 | 16% | stageD 执行质量 |
| D5 子模块分解质量 | 11% | E 阶段递归分解 |
| D6 顶层集成质量 | 8% | F 阶段接口一致性 |
| D7 ADR 文档质量 | 7% | 架构决策记录 |
| D8 方案验证与评审 | 7% | 对抗性评审 |
| D9 追溯完整性 | 6% | REQ 编号 + RTM |
| D10 过程规范性 | 10% | 流程遵循 + 文件管理 |

---

## 自定义场景

### 创建场景配置

在 `scenarios/` 目录下创建 JSON 文件：

```json
{
  "scenario_id": "my_scenario",
  "name": "我的测试场景",
  "description": "场景描述",
  "module_name": "my_module",
  "user_persona": "clear_expert",
  "initial_input": "帮我做一下 XXX 的需求采集",
  "context": {
    "soc_position": "...",
    "upstream": "...",
    "downstream": "...",
    "priority": "..."
  },
  "expected_stages": ["stage0", "stageA", "stageB", "stageC", "stageD"],
  "expected_deliverables": ["..."],
  "timeout_minutes": 30,
  "max_dialog_rounds": 50,
  "pass_criteria": {
    "min_stages_completed": 5,
    "min_req_count": 20,
    "required_deliverables": 4
  }
}
```

### 创建用户角色

在 `user-personas/` 目录下创建 JSON 文件：

```json
{
  "persona_id": "my_persona",
  "name": "我的用户角色",
  "description": "角色描述",
  "behavior": {
    "response_style": "direct",
    "detail_level": "high",
    "confirmation_pattern": "explicit_yes",
    "challenge_level": "none"
  },
  "system_prompt": "你是...",
  "stage_responses": {
    "stage0": {
      "typical_answers": {
        "role": "...",
        "priority": "..."
      }
    }
  }
}
```

---

## 工作原理

### 调试流程

1. **初始化**
   - 读取场景配置和用户角色
   - 创建调试工作目录

2. **启动双 Agent**
   - 用户 Agent: 模拟用户行为，根据场景生成回复
   - 苏启辰 Agent: 执行标准需求探索流程

3. **对话循环**
   - 双 Agent 交替对话
   - 记录对话历史
   - 检查完成条件

4. **质量评估**
   - 检查流程完整性
   - 检查交付物质量
   - 生成评估报告

5. **输出结果**
   - 对话记录
   - 评估报告
   - 调试摘要

### Agent 交互

```
用户输入: /test-chip-requirement-arch basic_dma
    │
    ▼
调试协调器
    │
    ├─► 用户 Agent (subagent)
    │   - 角色: clear_expert
    │   - 输入: 场景配置 + 角色定义
    │   - 输出: 用户回复
    │
    └─► 苏启辰 Agent (subagent)
        - 角色: chip-requirement-arch
        - 输入: 用户回复 + 流程规则
        - 输出: Agent 回复 + 交付物
```

---

## 常见问题

### Q: 调试模式和正常模式有什么区别？

A: 调试模式使用两个 subagent 自动对话，无需人工参与。正常模式需要用户手动回复。

### Q: 调试模式的结果准确吗？

A: 调试模式使用 LLM 生成用户回复，可能与真实用户行为有差异。建议将调试结果作为参考，结合人工测试验证。

### Q: 如何添加新的测试场景？

A: 在 `scenarios/` 目录下创建 JSON 配置文件，参考 `basic_dma.json` 的格式。

### Q: 调试模式支持并行运行吗？

A: 当前版本不支持并行运行。后续版本将添加并行支持。

### Q: 调试报告在哪里？

A: 调试报告保存在 `.claude/debug/chip-requirement-arch/debug_output/{scenario_id}_{timestamp}/` 目录下。

---

## 文件结构

```
.claude/debug/chip-requirement-arch/
├── README.md                      # 本文件
├── debug-runner.md                # 调试协调脚本
├── scenarios/                     # 测试场景配置
│   ├── basic_dma.json             # 基础 DMA 场景
│   ├── complex_pcie.json          # 复杂 PCIe 场景
│   ├── vague_input.json           # 模糊输入场景
│   ├── edge_cases.json            # 边界测试场景
│   └── complex_modules/           # 50 个 40k+ RTL 复杂模块池
│       ├── README.md              # 复杂模块说明
│       ├── module_pool.json       # 模块定义（50 个）
│       ├── coverage_matrix.json   # 覆盖矩阵
│       └── select_module.sh       # 随机选择脚本
├── user-personas/                 # 用户角色定义
│   ├── clear_expert.json          # 清晰表达的专家
│   ├── vague_beginner.json        # 模糊表达的新手
│   └── challenging_reviewer.json  # 挑战性审查者
├── templates/                     # 报告模板
│   └── debug-report-template.md   # 调试报告模板
└── debug_output/                  # 调试输出目录（运行时生成）
```

---

## 更新日志

### v1.0 (2026-06-03)
- 初始版本
- 支持 4 种测试场景
- 支持 3 种用户角色
- 集成现有评估标准
- 生成对话记录和评估报告

---

## 相关文档

- **Agent 定义**: `.claude/agents/chip-requirement-arch.md`
- **评估标准**: `.claude/evaluation_criteria/chip-requirement-arch-eva.md`
- **阶段定义**: `.claude/shared/flow/stage-definition.json`
- **示例对话**: `.claude/agents/examples/chip-requirement-arch-stage0-C-example.md`
