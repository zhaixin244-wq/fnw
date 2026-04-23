---
name: chip-impl-delivery
description: 交付 — 验证交付物完整性，输出交付清单
---

# 交付 Skill

## 职责
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
1. 检查所有必须文件是否存在
2. 检查 Lint 报告是否 ALL PASS
3. 检查综合报告是否 ALL PASS + 面积达标
4. 输出交付清单

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
