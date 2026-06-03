# {scenario_name} 调试报告

> 调试时间：{timestamp}
> 场景：{scenario_id}
> 用户角色：{user_persona}
> 对话轮数：{dialog_rounds}
> 耗时：{duration}

---

## 1. 调试摘要

| 指标 | 结果 |
|------|------|
| 完成状态 | {completed/timeout/incomplete} |
| 完成阶段数 | {stages_completed}/{expected_stages} |
| 生成 REQ 数 | {req_count} |
| 交付物完整度 | {deliverables_complete}/{deliverables_expected} |
| 对话轮数 | {dialog_rounds} |
| 耗时 | {duration} |

---

## 2. 流程检查

### 2.1 阶段完成情况

| 阶段 | 状态 | 标记正确 | 交付物 | 说明 |
|------|------|----------|--------|------|
| stage0 | ✅/❌ | ✅/❌ | ✅/❌ | {detail} |
| stageA | ✅/❌ | ✅/❌ | ✅/❌ | {detail} |
| stageB phase1 | ✅/❌ | ✅/❌ | ✅/❌ | {detail} |
| stageB phase2 | ✅/❌ | ✅/❌ | ✅/❌ | {detail} |
| stageC phase1 | ✅/❌ | ✅/❌ | ✅/❌ | {detail} |
| stageC phase2 | ✅/❌ | ✅/❌ | ✅/❌ | {detail} |
| stageD | ✅/❌ | ✅/❌ | ✅/❌ | {detail} |

### 2.2 门控检查结果

| # | 门控条件 | 验证命令 | 结果 | 说明 |
|---|----------|----------|------|------|
| G-01 | stageB phase1 >= 70% | `grep -c "✅" requirement_summary` | PASS/FAIL | {N}/28 |
| G-02 | stageB phase2 已执行 | `grep -c "stageB phase2" requirement_summary` | PASS/FAIL | {detail} |
| G-03 | stageC phase1 已执行 | `grep -c "stageC phase1" pr_v1.0.md` | PASS/FAIL | {detail} |
| G-04 | stageC phase2 已执行 | `ls requirement_summary_v1.0.md` | PASS/FAIL | {detail} |
| G-05 | stageD 已执行 | `ls solution_v1.0.md` | PASS/FAIL | {detail} |

**门控结论**: {门控 1 PASS/FAIL} → {门控 2 PASS/FAIL} → {最终等级}

---

## 3. 质量评估

### 3.1 维度评分

| 维度 | 权重 | 满分 | 得分 | 加权分 | 说明 |
|------|------|------|------|--------|------|
| D1 需求采集完整性 | 17% | 22 | {N} | {N} | {detail} |
| D2 需求一致性 | 7% | 10 | {N} | {N} | {detail} |
| D3 需求文档质量 | 11% | 12 | {N} | {N} | {detail} |
| D4 方案细化质量 | 16% | 20 | {N} | {N} | {detail} |
| D5 子模块分解质量 | 11% | 14 | {N} | {N} | {detail} |
| D6 顶层集成质量 | 8% | 8 | {N} | {N} | {detail} |
| D7 ADR 文档质量 | 7% | 8 | {N} | {N} | {detail} |
| D8 方案验证与评审 | 7% | 7 | {N} | {N} | {detail} |
| D9 追溯完整性 | 6% | 8 | {N} | {N} | {detail} |
| D10 过程规范性 | 10% | 12 | {N} | {N} | {detail} |
| **总分** | **100%** | — | — | **{N}** | |

### 3.2 等级判定

| 等级 | 分数范围 | 说明 |
|------|----------|------|
| **S** | 90-100 | 卓越：全流程规范执行，输出物完整可追溯 |
| **A** | 80-89 | 优秀：流程基本规范，输出物完整 |
| **B** | 70-79 | 良好：核心流程执行到位 |
| **C** | 60-69 | 合格：基本流程完成（或门控 2 触发） |
| **D** | <60 | 不合格：流程严重缺失（或门控 1 触发） |

**当前等级**: {S/A/B/C/D}

---

## 4. 对话统计

| 统计项 | 数值 |
|--------|------|
| 总轮数 | {rounds} |
| Agent 回复平均长度 | {avg_length} 字符 |
| 用户追问次数 | {follow_ups} |
| 阶段切换次数 | {stage_switches} |
| 平均每阶段轮数 | {avg_rounds_per_stage} |

### 4.1 对话质量分析

| 指标 | 数值 | 说明 |
|------|------|------|
| 信息密度 | {density} | 每轮有效信息量 |
| 追问效率 | {efficiency} | 追问获得的信息量 |
| 流程遵循度 | {compliance} | 遵循标准流程的程度 |

---

## 5. 交付物检查

### 5.1 文件清单

| 文件 | 存在 | 大小 | 行数 | REQ 数 | 说明 |
|------|------|------|------|--------|------|
| pr_v1.0.md | ✅/❌ | {size} | {lines} | - | {detail} |
| requirement_summary_v1.0.md | ✅/❌ | {size} | {lines} | {req_count} | {detail} |
| solution_v1.0.md | ✅/❌ | {size} | {lines} | - | {detail} |
| ADR_v1.0.md | ✅/❌ | {size} | {lines} | - | {detail} |
| trace_graph.yaml | ✅/❌ | {size} | {lines} | - | {detail} |

### 5.2 REQ 编号检查

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 编号连续性 | PASS/FAIL | {detail} |
| 编号唯一性 | PASS/FAIL | {detail} |
| 编号格式 | PASS/FAIL | {detail} |
| REQ 总数 | {count} | |

### 5.3 内容质量检查

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 章节完整性 | PASS/FAIL | {detail} |
| 格式规范性 | PASS/FAIL | {detail} |
| 内容一致性 | PASS/FAIL | {detail} |

---

## 6. 问题与建议

### 6.1 发现的问题

| # | 优先级 | 问题描述 | 影响 | 位置 |
|---|--------|----------|------|------|
| 1 | H/M/L | {problem_1} | {impact} | {location} |
| 2 | H/M/L | {problem_2} | {impact} | {location} |

### 6.2 优化建议

| # | 建议内容 | 预期效果 | 实现难度 |
|---|----------|----------|----------|
| 1 | {suggestion_1} | {effect} | H/M/L |
| 2 | {suggestion_2} | {effect} | H/M/L |

### 6.3 根因分析

| 问题 | 根因 | 解决方案 |
|------|------|----------|
| {problem} | {root_cause} | {solution} |

---

## 7. 附录

### 7.1 完整对话记录
见 `dialog.md`

### 7.2 交付物清单
见 `outputs/` 目录

### 7.3 评估标准
见 `.claude/evaluation_criteria/chip-requirement-arch-eva.md`

### 7.4 场景配置
```json
{scenario_config}
```

### 7.5 用户角色配置
```json
{user_persona_config}
```

---

## 8. 结论

### 8.1 总体评价

{总体评价，2-3 句话}

### 8.2 关键发现

1. {finding_1}
2. {finding_2}
3. {finding_3}

### 8.3 后续行动

1. {action_1}
2. {action_2}
3. {action_3}

---

**报告生成时间**: {timestamp}
**调试工具版本**: v1.0
**评估标准版本**: v12.0
