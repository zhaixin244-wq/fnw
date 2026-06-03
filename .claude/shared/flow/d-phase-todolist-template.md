# D 阶段 Todolist 模板

> 每个 Phase 完成后更新状态。subagent 按此 todolist 执行。

## Phase 执行跟踪

| Phase | 名称 | sub_stage 数 | 状态 | 完成时间 | 摘要文件 |
|-------|------|-------------|------|----------|----------|
| stageD group1 | 架构规划 | 3 | ⬜ pending | - | flow/stageD_group1_summary.md |
| stageD group2 | 数据通路与控制 | 4 | ⬜ pending | - | flow/stageD_group2_summary.md |
| stageD group3 | 存储与资源 | 4 | ⬜ pending | - | flow/stageD_group3_summary.md |
| stageD group4 | 流控与跨时钟域 | 3 | ⬜ pending | - | flow/stageD_group4_summary.md |
| stageD group5 | PPA、接口与可靠性 | 6 | ⬜ pending | - | flow/stageD_group5_summary.md |

## sub_stage 明细

### stageD group1（架构规划）
| sub_stage | 名称 | 状态 | Q&A 数 | 交付章节 |
|-----------|------|------|--------|----------|
| stageD group1-step1 | 初始架构方案 + RTL行数估算 | ⬜ | ≥4 | §3 |
| stageD group1-step2 | CBB选型与集成 | ⬜ | ≥3 | §13 |
| stageD group1-step3 | 子模块划分细化 | ⬜ | ≥3 | §3.4 |

### stageD group2（数据通路与控制）
| sub_stage | 名称 | 状态 | Q&A 数 | 交付章节 |
|-----------|------|------|--------|----------|
| stageD group2-step1 | 数据通路设计 | ⬜ | ≥3 | §5.1 |
| stageD group2-step2 | 流水线设计 | ⬜ | ≥3 | §5.4 |
| stageD group2-step3 | 性能优化 | ⬜ | ≥3 | §8.1 |
| stageD group2-step4 | 控制逻辑/FSM | ⬜ | ≥4 | §5.2-5.3 |

### stageD group3（存储与资源）
| sub_stage | 名称 | 状态 | Q&A 数 | 交付章节 |
|-----------|------|------|--------|----------|
| stageD group3-step1 | SRAM设计 | ⬜ | ≥4 | §11.1 |
| stageD group3-step2 | FIFO设计 | ⬜ | ≥4 | §11.2 |
| stageD group3-step3 | 链表设计 | ⬜ | ≥3 | §11.3 |
| stageD group3-step4 | 寄存器定义 | ⬜ | ≥3 | §7.1 |

### stageD group4（流控与时钟）
| sub_stage | 名称 | 状态 | Q&A 数 | 交付章节 |
|-----------|------|------|--------|----------|
| stageD group4-step1 | 调度策略 | ⬜ | ≥3 | §12.1 |
| stageD group4-step2 | 流控机制 | ⬜ | ≥3 | §12.2 |
| stageD group4-step3 | CDC方案 | ⬜ | ≥3 | §7.2 |

### stageD group5（PPA、接口与可靠性）
| sub_stage | 名称 | 状态 | Q&A 数 | 交付章节 |
|-----------|------|------|--------|----------|
| stageD group5-step1 | 面积预估 | ⬜ | ≥3 | §8.3 |
| stageD group5-step2 | 时序分析 | ⬜ | ≥3 | §6 |
| stageD group5-step3 | DFX设计 | ⬜ | ≥3 | §9 |
| stageD group5-step4 | 可靠性设计 | ⬜ | ≥3 | §10.1 |
| stageD group5-step5 | 接口定义 | ⬜ | ≥3 | §4 |
| stageD group5-step6 | 功耗设计 | ⬜ | ≥3 | §10.2 |
