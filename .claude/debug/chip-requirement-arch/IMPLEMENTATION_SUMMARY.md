# chip-requirement-arch 调试模式实现总结

> 实现日期：2026-06-03
> 版本：v1.0

---

## 实现概述

为 chip-requirement-arch agent 添加了调试模式，通过双 Agent 自动对话验证需求探索流程与质量。

---

## 创建的文件清单

### 1. 斜杠命令定义
| 文件 | 用途 |
|------|------|
| `.claude/commands/debug-chip-requirement-arch.md` | 斜杠命令定义，触发调试模式 |

### 2. 调试框架
| 文件 | 用途 |
|------|------|
| `.claude/debug/chip-requirement-arch/README.md` | 调试模式使用说明 |
| `.claude/debug/chip-requirement-arch/debug-runner.md` | 调试协调脚本，定义完整调试流程 |
| `.claude/debug/chip-requirement-arch/IMPLEMENTATION_SUMMARY.md` | 本文件，实现总结 |

### 3. 测试场景配置
| 文件 | 场景 | 描述 |
|------|------|------|
| `scenarios/basic_dma.json` | 基础 DMA | 标准流程测试 |
| `scenarios/complex_pcie.json` | 复杂 PCIe | 高级场景测试 |
| `scenarios/vague_input.json` | 模糊输入 | 边界测试 |
| `scenarios/edge_cases.json` | 边界条件 | 异常处理测试 |

### 4. 用户角色定义
| 文件 | 角色 | 特点 |
|------|------|------|
| `user-personas/clear_expert.json` | 清晰表达的专家 | 回复直接、信息完整 |
| `user-personas/vague_beginner.json` | 模糊表达的新手 | 回复模糊、需要引导 |
| `user-personas/challenging_reviewer.json` | 挑战性审查者 | 提出质疑、要求论证 |

### 5. 报告模板
| 文件 | 用途 |
|------|------|
| `templates/debug-report-template.md` | 调试报告模板，包含完整评估格式 |

### 6. 更新的文件
| 文件 | 更新内容 |
|------|----------|
| `.claude/agents/chip-requirement-arch.md` | 添加调试模式章节 |

---

## 架构设计

```
用户输入：/debug chip-requirement-arch basic_dma
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                    调试协调脚本 (debug-runner.md)              │
│  1. 读取场景配置 scenarios/basic_dma.json                     │
│  2. 读取用户角色 user-personas/clear_expert.json              │
│  3. 创建调试工作目录 debug_output/basic_dma_TIMESTAMP/        │
│  4. 启动双 Agent 对话循环                                      │
│  5. 收集对话记录                                              │
│  6. 生成评估报告                                              │
└────────────┬────────────────────────┬───────────────────────┘
             │                        │
             ▼                        ▼
    ┌────────────────────┐   ┌────────────────────┐
    │ 用户 Agent          │   │ 苏启辰 Agent        │
    │ (subagent)         │   │ (subagent)         │
    │                    │   │                    │
    │ 角色：clear_expert  │   │ 角色：chip-requirement-arch │
    │ 行为：LLM 生成回复  │   │ 行为：执行需求采集   │
    └────────────────────┘   └────────────────────┘
```

---

## 使用方法

### 基本用法

```
/debug chip-requirement-arch [scenario_id]
```

### 示例

```bash
# 运行基础 DMA 场景
/debug chip-requirement-arch basic_dma

# 运行复杂 PCIe 场景
/debug chip-requirement-arch complex_pcie

# 运行模糊输入场景
/debug chip-requirement-arch vague_input

# 运行边界条件场景
/debug chip-requirement-arch edge_cases
```

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
```

---

## 评估标准

调试模式复用现有评估标准：

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

## 设计决策

### 1. 触发方式
**选择**: 斜杠命令触发
**原因**: 用户友好，易于记忆和使用

### 2. 用户 Agent 智能程度
**选择**: LLM 生成回复
**原因**: 灵活自然，可处理意外问题

### 3. 测试场景类型
**选择**: 完整场景集
**原因**: 覆盖各种情况，测试更全面

---

## 扩展点

### 1. 自定义场景
用户可以创建自己的场景配置文件，放在 `scenarios/` 目录下。

### 2. 自定义角色
用户可以创建自己的用户角色配置文件，放在 `user-personas/` 目录下。

### 3. 并行调试
后续版本可支持同时运行多个场景。

### 4. CI/CD 集成
将调试模式集成到 CI 流程，自动验证 Agent 更新。

---

## 验证方式

### 功能验证
1. 运行 `/debug chip-requirement-arch basic_dma`
2. 确认双 Agent 对话正常进行
3. 检查生成的交付物

### 质量验证
1. 检查评估报告是否准确
2. 验证 REQ 编号连续性
3. 确认阶段标记正确

### 边界测试
1. 运行 vague_input 场景
2. 运行 edge_cases 场景
3. 确认异常处理正确

---

## 后续工作

1. **测试运行**: 实际运行调试模式，验证功能
2. **场景优化**: 根据测试结果优化场景配置
3. **文档完善**: 补充使用示例和最佳实践
4. **性能优化**: 优化对话循环效率

---

## 相关文档

- **Agent 定义**: `.claude/agents/chip-requirement-arch.md`
- **评估标准**: `.claude/evaluation_criteria/chip-requirement-arch-eva.md`
- **阶段定义**: `.claude/shared/flow/stage-definition.json`
- **示例对话**: `.claude/agents/examples/chip-requirement-arch-stage0-C-example.md`
- **调试说明**: `.claude/debug/chip-requirement-arch/README.md`
