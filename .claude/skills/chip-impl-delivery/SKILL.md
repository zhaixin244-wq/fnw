---
name: chip-impl-delivery
description: "Use when verifying RTL implementation deliverables completeness before delivery. Triggers on '交付', 'delivery', '交付物', '交付清单', '完整性检查', 'deliverables'. Validates all deliverables exist and pass quality gates, outputs delivery checklist."
---

# 交付 Skill

## 任务
验证所有交付物存在且通过质量门禁，输出交付清单。

## 输入
- `all_outputs`: 所有阶段的输出
- `work_dir`: 工作目录路径

## 交付物清单（10 项）
1. RTL 源码 `.v`
2. CBB 清单 `_cbb_list.md`
3. SDC `.sdc`
4. SVA `_sva.sv`
5. Interface `_intf.sv`（如需）
6. UPF `.upf`（如需）
7. TB `_tb.v`（如需）
8. Makefile/Lint/综合脚本
9. Lint 报告 `lint_summary.log`（ALL PASS）
10. 综合报告 `synth_summary.log`（ALL PASS + 面积达标）

## 执行步骤
1. 用 `Glob` 搜索 `{module}_work/ds/rtl/*.v` 获取 RTL 文件列表，用 `Glob` 搜索 `{module}_work/ds/doc/ua/*.md` 获取 UA 文档列表。若文件不存在，暂停并提示用户
2. 检查所有必须文件是否存在
3. 检查 Lint 报告是否 ALL PASS
4. 检查综合报告是否 ALL PASS + 面积达标
5. 输出交付清单

## 输出
- `delivery_manifest`: 交付清单（文件列表 + 状态）

## Gate
所有 10 项交付物必须存在且通过。

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/delivery.json`：
```json
{"stage_id": "delivery", "duration_ms": 0, "iteration_count": 1}
```

## 下游消费者
- chip-arch-reviewer：消费 RTL .v + SVA .sv + CBB 清单
- 综合工具：消费 RTL .v + SDC .sdc
- 仿真工具：消费 RTL .v + TB .v + SVA .sv

## 使用示例

**示例 1**：
- 用户：「公共模块 RTL 已完成，请执行交付物完整性检查」
- 行为：读取 `{module}_work/` 目录，逐项检查 10 项交付物（RTL .v、CBB 清单、SDC、SVA、Lint 报告、综合报告等），输出交付清单表格及状态

**示例 2**：
- 用户：「帮我确认 buf_mgr 的 Lint 和综合报告是否通过」
- 行为：检查 `buf_mgr_work/ds/report/lint/lint_summary.log` 是否 ALL PASS，检查 `synth_summary.log` 是否 ALL PASS + 面积达标，输出结果

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 交付物缺失 | 必须文件不存在于工作目录 | 列出缺失文件清单，暂停等待补充 |
| Lint 报告未通过 | `lint_summary.log` 非 ALL PASS | 标注 FAIL 项，建议回到 quality-gate 修复 |
| 综合报告面积超标 | 面积差异 >50% | 标注 Critical，暂停等待用户确认 |
| 工作目录不存在 | `{module}_work/` 路径无效 | 提示用户先执行模块结构规划和 RTL 实现 |

## 检查点

**检查前**：
- 确认 `{module}_work/` 目录存在且非空
- 确认至少 RTL 源码 `.v` 文件已生成

**检查后**：
- 确认交付清单 10 项全部标记状态（Pass/Fail/Missing）
- 确认 metrics 已写入 `{work_dir}/ds/report/metrics/delivery.json`
