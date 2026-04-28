---
name: chip-review-checklister
description: "Use when reviewing FS, UA, or RTL documents against quality checklists. Triggers on 'review', '评审', '检查清单', 'checklist', 'review report', '评审报告', '自检报告'. Generates structured review checklist and report."
---

# Chip Review Checklister

## 任务
生成针对芯片模块架构的评审 Checklist 并标注风险等级。

## 评审维度
1. **架构完整性**：是否有明确的模块边界、数据通路、控制逻辑？
2. **接口精确性**：信号位宽、时钟域、复位策略、握手协议是否完整？
3. **PPA 可行性**：指标是否量化、是否经过快速建模、是否有裕量？
4. **时序收敛**：关键路径是否已识别、流水线级数是否合理？
5. **CDC 安全**：跨时钟域信号是否已识别、同步策略是否正确？
6. **低功耗设计**：Power Domain 划分、Iso/Retention、UPF 意图是否清晰？
7. **可靠性**：SEU 防护、老化降额、电压降/EM 评估是否到位？
8. **验证策略**：功能覆盖率计划、断言、形式验证范围是否定义？
9. **RTL 可综合性**：代码规范、Clock/Reset 策略、DFT 友好性。

## 执行步骤
1. 针对用户提供的架构文档或描述，逐项检查并给出状态（Pass / Fail / N/A / Open）。
2. 对 Fail/Open 项标注风险等级（Critical / High / Medium / Low）并给出具体建议。
3. 输出 Schema 级完整性评分（百分比）。

## 输出格式
```markdown
| 检查项 | 状态 | 风险等级 | 发现/建议 |
|--------|------|----------|-----------|
| 关键路径已识别 | Pass | - | - |
| CDC 同步策略 | Open | High | 缺少异步 FIFO 深度计算 |

**完整性评分：X/Y (Z%)**
```

## 使用示例

**示例 1**：
- 用户：「评审公共模块的微架构文档」
- 行为：逐项检查架构完整性、接口精确性、PPA 可行性、CDC 安全等 9 个维度，对 Fail/Open 项标注风险等级，输出评审 Checklist

**示例 2**：
- 用户：「帮我检查 buf_mgr 的 RTL 可综合性」
- 行为：聚焦 RTL 可综合性维度，检查编码规范、Clock/Reset 策略、DFT 友好性，输出检查结果和建议

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 文档缺失 | 架构文档路径无效 | 暂停，提示用户提供文档 |
| 评审维度不适用 | 模块无 CDC/低功耗需求 | 对应维度标记 N/A |
| 信息不足 | 文档描述过于简略 | 对无法判断项标记 Open，标注 `[REVIEW-NEED-MORE]` |

## 检查点

**检查前**：
- 确认架构文档路径有效
- 确认评审维度已明确（全量/聚焦）

**检查后**：
- 确认 9 个维度均已检查并标注状态
- 确认 Fail/Open 项已标注风险等级
- 确认完整性评分已输出
