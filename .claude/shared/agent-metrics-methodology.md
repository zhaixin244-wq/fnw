# Agent 度量与持续改进方法论

> 定义 Agent 效果度量指标、追踪机制和持续改进闭环，驱动 Agent 体系的量化优化。

---

## 1. 度量维度

### 1.1 核心指标

| 指标 ID | 指标名称 | 定义 | 计算方式 | 目标值 |
|---------|---------|------|----------|--------|
| M-001 | **首次通过率** | Agent 输出一次通过评审的比例 | 通过次数 / 总输出次数 × 100% | ≥ 80% |
| M-002 | **返工率** | Agent 输出需要修改重做的比例 | 返工次数 / 总输出次数 × 100% | ≤ 15% |
| M-003 | **需求覆盖率** | Agent 输出覆盖需求的比例 | 覆盖 REQ 数 / 总 REQ 数 × 100% | 100% |
| M-004 | **缺陷逃逸率** | 评审未发现、在下游暴露的缺陷比例 | 逃逸缺陷数 / 总缺陷数 × 100% | ≤ 5% |
| M-005 | **平均迭代次数** | 单个任务从启动到通过的平均轮数 | 总迭代轮数 / 任务数 | ≤ 3 轮 |
| M-006 | **降级触发率** | Agent 降级策略被触发的比例 | 降级次数 / 总执行次数 × 100% | ≤ 10% |

### 1.2 阶段特定指标

| 阶段 | 指标 | 定义 | 目标值 |
|------|------|------|--------|
| FS | QC 清单通过率 | quality-checklist-fs.md 检查项通过比例 | ≥ 90% |
| UA | MC 清单通过率 | quality-checklist-microarch.md 检查项通过比例 | ≥ 85% |
| RTL | IC 清单通过率 | quality-checklist-impl.md 检查项通过比例 | ≥ 90% |
| RTL | Lint 首次通过率 | Verible + Verilator 一次通过比例 | ≥ 70% |
| RTL | 综合首次通过率 | Yosys 综合一次通过比例 | ≥ 80% |
| 评审 | 问题发现率 | 评审发现的 Critical+Major 问题数 / 总问题数 | ≥ 60% |
| 评审 | 误报率 | 评审标记为问题但实际不是的比例 | ≤ 10% |

---

## 2. 度量采集

### 2.1 采集时机

| 采集点 | 采集内容 | 采集方式 |
|--------|----------|----------|
| Agent 输出完成 | 输出文件路径、任务类型、Agent ID | 自动记录 |
| 评审完成 | 问题清单、通过/不通过结论 | 从评审报告提取 |
| 修复完成 | 返工次数、修复内容 | 从修改报告提取 |
| 项目结束 | 所有指标汇总 | metrics-summary.sh 扩展 |

### 2.2 度量记录格式

```json
{
  "project": "data_adpt",
  "agent": "chip-code-writer",
  "task_id": "RTL-data_adpt_req_handler-v1",
  "timestamp": "2026-05-13T10:30:00",
  "metrics": {
    "first_pass": false,
    "iteration_count": 2,
    "requirements_coverage": 1.0,
    "defects_found_by_review": 3,
    "defects_escaped": 0,
    "degradation_triggered": false,
    "quality_checklist_pass_rate": 0.92,
    "lint_first_pass": false,
    "synth_first_pass": true
  },
  "issues": [
    {
      "id": "ISSUE-001",
      "severity": "Major",
      "category": "FSM-ILLEGAL-STATE",
      "description": "FSM 缺少 default 分支",
      "found_by": "chip-arch-reviewer",
      "fix_round": 2
    }
  ]
}
```

### 2.3 度量存储

```
<module>_work/ds/report/metrics/
├── agent_metrics_{YYYYMMDD}.json    — 单次任务度量
├── project_summary.json              — 项目级汇总
└── trend_{agent_id}.json             — Agent 跨项目趋势
```

---

## 3. 度量分析

### 3.1 Agent 效果分析

| 分析维度 | 分析方法 | 输出 |
|----------|----------|------|
| **Agent 横向对比** | 同一项目内各 Agent 的 M-001~006 对比 | Agent 效果排名 |
| **Agent 纵向趋势** | 同一 Agent 跨项目的 M-001~006 趋势 | 改进/退化趋势 |
| **缺陷模式分析** | 按缺陷类别统计各 Agent 的缺陷分布 | 高频缺陷 Top 5 |
| **阶段瓶颈分析** | 哪个阶段的返工率最高、迭代次数最多 | 瓶颈阶段定位 |

### 3.2 缺陷模式分类

| 缺陷类别 | 编号 | 典型表现 | 高频 Agent |
|----------|------|----------|-----------|
| 协议理解错误 | DEF-PROT | 接口时序不符合协议规范 | chip-code-writer |
| CDC 缺失 | DEF-CDC | 跨域信号未同步 | chip-code-writer |
| 时序违例 | DEF-TIMING | 关键路径过长 | chip-code-writer |
| 功能遗漏 | DEF-FUNC | 需求未实现 | chip-fs-writer, chip-microarch-writer |
| 位宽不匹配 | DEF-WIDTH | 端口位宽不一致 | chip-code-writer |
| 复位不完整 | DEF-RESET | 寄存器未正确复位 | chip-code-writer |
| 流控缺陷 | DEF-FLOW | 背压/信用计算错误 | chip-microarch-writer |
| 文档不一致 | DEF-DOC | FS/UA/RTL 三层不一致 | 所有 Agent |

### 3.3 改进建议生成规则

| 缺陷模式 | 改进目标 | 改进措施 |
|----------|----------|----------|
| DEF-PROT | chip-code-writer | 增强协议 Wiki 检索强制级别 |
| DEF-CDC | chip-code-writer | 增强 CDC 检查清单项 |
| DEF-TIMING | chip-microarch-writer | 强化关键路径分析要求 |
| DEF-FUNC | chip-fs-writer | 增加 BDD 场景完整性检查 |
| DEF-WIDTH | chip-code-writer | 增加位宽一致性自动检查 |
| DEF-RESET | chip-code-writer | 增加复位完整性检查清单项 |
| DEF-FLOW | chip-microarch-writer | 强化 FIFO 深度计算验证 |
| DEF-DOC | 全部 | 强化 cross-agent-consistency 检查 |

---

## 4. 持续改进闭环

### 4.1 改进流程

```
度量采集 → 模式识别 → 根因分析 → 改进措施 → 实施改进 → 效果验证
    ↑                                                          │
    └──────────────────────────────────────────────────────────┘
```

### 4.2 改进触发条件

| 触发条件 | 改进动作 | 目标 |
|----------|----------|------|
| Agent M-001 < 70% 连续 3 个项目 | 分析该 Agent 的高频缺陷模式 | 提升首次通过率 |
| 某缺陷类别占比 > 30% | 针对该类别增强检查规则 | 降低缺陷逃逸率 |
| M-005 > 5 轮 | 分析迭代原因，优化 Agent 指令 | 减少迭代次数 |
| M-006 > 20% | 分析降级触发场景 | 提升 Agent 鲁棒性 |

### 4.3 改进效果验证

| 验证方式 | 标准 |
|----------|------|
| A/B 对比 | 改进前后同一 Agent 的 M-001~006 对比 |
| 回归验证 | 改进后重跑历史项目，确认无退化 |
| 趋势观察 | 连续 2 个项目指标改善视为有效 |

---

## 5. 集成规则

### 5.1 chip-project-lead 集成

- 项目启动时初始化度量采集
- 项目里程碑检查 M-001~006
- 项目结束时生成项目级度量汇总
- 定期（每 3 个项目）生成跨项目趋势报告
- 根据度量结果提出改进建议

### 5.2 chip-arch-reviewer 集成

- 评审时记录缺陷模式分类（DEF-PROT ~ DEF-DOC）
- 评审报告中包含度量数据（问题发现率、误报率）
- 评审完成后更新 Agent 度量记录
- 识别高频缺陷模式，反馈给对应 Agent
