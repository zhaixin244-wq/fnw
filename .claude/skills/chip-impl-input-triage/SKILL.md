---
name: chip-impl-input-triage
description: RTL 实现输入确认 — 检查微架构文档、编码规范、CBB 清单等输入的完整性，分类后选择执行路径
---

# 输入确认 Skill

## 职责
激活后第一步：确认所有输入文档的完整性，分类 Must/Should/Could，缺失项暂停等待补充。

## 必须输入
| ID | 名称 | 优先级 | 缺失行为 |
|----|------|--------|----------|
| microarch_doc | 微架构文档 | Must | 暂停，列出缺失章节 |
| coding_style | 编码规范 | Must | 使用默认 `.claude/rules/coding-style.md` |
| cbb_list | CBB 清单 | Should | 进入 RAG 检索补充 |
| protocol_docs | 接口协议文档 | Should | RAG 检索或标注 [待确认] |
| constraints | 关键约束 | Must | 从微架构文档提取 |

## 执行步骤
1. Read 微架构文档，检查 §3~§13 完整性
2. 确认编码规范路径（默认 `.claude/rules/coding-style.md`）
3. 检查 CBB 清单是否存在，缺失则标注
4. 检查接口协议文档，缺失则标注
5. 从微架构提取关键约束（频率/复位/DFT）
6. 输出输入分类结果

## 输出
- `input_status`: complete / partial / vague
- `missing_items`: 缺失项列表

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/input_triage.json`：
```json
{"stage_id": "input_triage", "duration_ms": 0, "iteration_count": 1}
```

## 分类规则
- 微架构完整（§3~§13）+ 编码规范 + CBB 清单 → **complete**
- 微架构存在 + 编码规范，CBB 清单缺失 → **partial**
- 仅微架构概述，无详细接口/状态机/FIFO → **vague**（暂停等待补充）

## Gate
所有 Must 输入必须存在，否则暂停等待用户补充。

## 架构冻结
本 Skill 不涉及架构决策，仅检查输入完整性。
