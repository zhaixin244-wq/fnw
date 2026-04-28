---
name: chip-impl-input-triage
description: "Use when checking RTL implementation input completeness before coding. Triggers on '输入确认', 'input triage', '输入检查', '文档完整性', '输入分类', 'input check'. Checks microarch docs, coding style, CBB list completeness and selects execution path."
---

# 输入确认 Skill

## 任务
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
1. 用 `Glob` 搜索 `{module}_work/ds/doc/ua/*.md` 获取微架构文档列表，确认 `.claude/rules/coding-style.md` 存在。若文件不存在，暂停并提示用户
2. Read 微架构文档，检查 §3~§13 完整性
3. 确认编码规范路径（默认 `.claude/rules/coding-style.md`）
4. 检查 CBB 清单是否存在，缺失则标注
5. 检查接口协议文档，缺失则标注
6. 从微架构提取关键约束（频率/复位/DFT）
7. 输出输入分类结果

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

## 使用示例

**示例 1**：
- 用户：「公共模块微架构文档已就绪，帮我检查输入是否完整」
- 行为：读取微架构文档，检查 §3~§13 完整性，确认编码规范路径，检查 CBB 清单和协议文档，输出 `input_status: complete/partial/vague`

**示例 2**：
- 用户：「我要开始写 buf_mgr 的 RTL，先做输入确认」
- 行为：检查微架构文档是否存在、端口列表是否完整、FSM/FIFO 章节是否有详细设计，缺失项列出清单并暂停

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 微架构文档缺失 | 文件路径不存在或为空 | 暂停，提示用户先完成微架构设计 |
| 微架构章节不完整 | §3~§13 有缺失章节 | 列出缺失章节，标注 `vague`，暂停等待补充 |
| 编码规范路径无效 | 默认 `.claude/rules/coding-style.md` 不存在 | 提示用户确认编码规范路径 |
| CBB 清单缺失 | 无 CBB 清单文件 | 标注 `partial`，进入 RAG 检索补充 |

## 检查点

**检查前**：
- 确认微架构文档路径有效
- 确认编码规范文件存在

**检查后**：
- 确认 `input_status` 已输出（complete/partial/vague）
- 确认缺失项清单已列出（如有）
- 确认 metrics 已写入 `{work_dir}/ds/report/metrics/input_triage.json`
