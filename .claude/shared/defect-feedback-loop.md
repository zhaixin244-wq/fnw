# 缺陷反馈闭环（共享）

> 本模板定义芯片设计中缺陷的系统性反馈机制，确保验证发现的缺陷能持续改进设计流程。
> 供 `chip-arch-reviewer`、`chip-project-lead` 共同引用。

---

## 1. 缺陷反馈模型

```
缺陷发现 → 根因分类 → 规则更新 → Agent 检查增强 → 回归验证 → 闭环确认
    ↑                                                        │
    └────────────────── 反馈循环 ──────────────────────────────┘
```

**铁律：每个缺陷必须追溯根因，并更新对应的检查规则，防止同类问题再发生。**

---

## 2. 缺陷根因分类

### 2.1 缺陷来源

| 来源 | 阶段 | 典型缺陷 |
|------|------|----------|
| 仿真发现 | RTL 验证 | 功能错误、协议违规、边界溢出 |
| 综合发现 | 综合阶段 | 未解析模块、位宽不匹配、组合环路 |
| 形式验证 | 形式检查 | 属性违反、死锁、不可达状态 |
| 评审发现 | 架构评审 | 设计缺陷、接口不一致、方案遗漏 |
| 硅后发现 | 芯片测试 | 时序违例、CDC 缺陷、功耗超标 |

### 2.2 根因分类矩阵

| 根因类别 | 子类 | 示例 | 反馈目标 |
|----------|------|------|----------|
| **协议违规** | 握手错误 | valid 依赖 ready | coding-style.md §8 |
| | 数据不稳定 | valid 期间 data 变化 | coding-style.md §8 |
| | 背压错误 | ready 组合依赖 valid | coding-style.md §8 |
| **CDC 缺陷** | 未同步 | 跨域信号直接采样 | cdc-methodology.md |
| | 同步链组合 | 同步器间插入组合逻辑 | cdc-methodology.md |
| | 复位不同步 | 复位释放未同步 | cdc-methodology.md |
| **时序缺陷** | 关键路径 | 组合逻辑级数过多 | microarchitecture-template.md §6 |
| | 时序违例 | Tslack < 0 | coding-style.md §9 |
| **功能缺陷** | 状态机错误 | 非法状态未回收 | coding-style.md §7 |
| | FIFO 溢出 | 深度不足 | coding-style.md §9 |
| | 位宽不匹配 | 截位/扩展错误 | cross-agent-consistency.md |
| **接口缺陷** | 端口不一致 | FS 与 RTL 端口不一致 | cross-agent-consistency.md |
| | 参数不一致 | 参数名/值不一致 | cross-agent-consistency.md |
| **复位缺陷** | 复位遗漏 | 寄存器未复位 | coding-style.md §5 |
| | 复位值错误 | 复位值不符合 FS | coding-style.md §5 |

---

## 3. 反馈流程

### 3.1 标准流程

```
Step 1: 缺陷发现
    └→ 记录缺陷：现象、位置、严重级别

Step 2: 根因分析
    └→ 分类到 §2.2 根因矩阵

Step 3: 规则更新
    └→ 更新对应的检查规则/模板

Step 4: Agent 检查增强
    └→ 在 Agent 工作流中增加对应检查项

Step 5: 回归验证
    └→ 重跑验证，确认缺陷已修复且无新增

Step 6: 闭环确认
    └→ 确认规则更新有效，关闭缺陷
```

### 3.2 规则更新映射

| 根因类别 | 更新文件 | 更新内容 |
|----------|----------|----------|
| 协议违规 | `coding-style.md` | 增强握手检查规则 |
| CDC 缺陷 | `cdc-methodology.md` | 增强 CDC 检查清单 |
| 时序缺陷 | `microarchitecture-template.md` | 增强时序分析要求 |
| 功能缺陷 | `coding-style.md` | 增强 FSM/FIFO 检查规则 |
| 接口缺陷 | `cross-agent-consistency.md` | 增强一致性检查 |
| 复位缺陷 | `coding-style.md` | 增强复位检查规则 |
| 验证盲点 | `verification-convergence.md` | 增强覆盖率要求 |
| 场景遗漏 | `bdd-scenario-template.md` | 补充 BDD 场景 |

---

## 4. 缺陷统计与趋势分析

### 4.1 缺陷统计指标

| 指标 | 计算公式 | 目标 |
|------|----------|------|
| 缺陷密度 | 缺陷数 / KLOC | < 0.1 |
| 缺陷逃逸率 | 下游发现的上游应覆盖缺陷 / 总缺陷 | < 5% |
| 缺陷修复时间 | 发现→修复→验证的平均时间 | Critical < 24h |
| 规则更新覆盖率 | 有规则更新的缺陷 / 总缺陷 | ≥ 80% |

### 4.2 趋势分析

```
缺陷数
    |  *
    | * *
    |*   *  *
    |        *  *
    |             *  *  *  *
    +-----------------------------→ 版本
       v1    v2    v3    v4
```

**趋势判定**：
- 缺陷数逐版本下降 → 设计流程改进有效
- 缺陷数不降反升 → 需要审查规则更新是否生效
- 某类缺陷反复出现 → 需要加强对应检查规则

---

## 5. 缺陷预防机制

### 5.1 设计阶段预防

| 预防措施 | 实施方式 | 负责 Agent |
|----------|----------|-----------|
| SVA-First | 先写断言再写 RTL | `chip-code-writer` |
| TDD 流程 | 先写测试再写 RTL | `chip-code-writer` |
| 评审前置 | 设计阶段就做架构评审 | `chip-arch-reviewer` |
| 检查清单 | 每个阶段执行检查清单 | 所有 Agent |

### 5.2 验证阶段预防

| 预防措施 | 实施方式 | 负责 Agent |
|----------|----------|-----------|
| 覆盖率驱动 | 从覆盖率目标反推测试场景 | `chip-verfi-arch` |
| 形式验证 | 数学证明属性成立 | `chip-sta-analyst` |
| 随机验证 | 约束随机发现边界问题 | `chip-env-writer` |
| 回归测试 | 每次变更重跑全量回归 | `chip-env-writer` |

---

## 6. 缺陷知识库

### 6.1 典型缺陷模式

| 编号 | 缺陷模式 | 根因 | 预防规则 | 检查方式 |
|------|----------|------|----------|----------|
| DEF-001 | valid 依赖 ready | 握手协议违规 | coding-style §8 | SVA 断言 |
| DEF-002 | 跨域信号未同步 | CDC 遗漏 | cdc-methodology | SVA + 形式验证 |
| DEF-003 | FIFO 溢出 | 深度计算错误 | coding-style §9 | SVA 断言 |
| DEF-004 | 状态机死锁 | 非法状态未回收 | coding-style §7 | SVA + 形式验证 |
| DEF-005 | 复位遗漏 | 寄存器未赋复位值 | coding-style §5 | Lint 检查 |
| DEF-006 | 位宽不匹配 | 截位/扩展错误 | cross-agent-consistency | Lint 检查 |
| DEF-007 | 组合环路 | ready 依赖 valid | coding-style §8 | 形式验证 |
| DEF-008 | 时序违例 | 组合逻辑级数过多 | microarch §6 | 综合分析 |

### 6.2 缺陷模式扩展规则

当发现新的缺陷模式时：
1. 记录缺陷现象和根因
2. 分类到 §2.2 根因矩阵
3. 更新 §6.1 典型缺陷模式表
4. 更新对应的检查规则
5. 在 Agent 工作流中增加检查项

---

## 7. 各 Agent 缺陷反馈职责

| Agent | 缺陷反馈职责 |
|-------|-------------|
| `chip-arch-reviewer` | 缺陷根因分析、规则更新建议、闭环确认 |
| `chip-project-lead` | 规则更新审批、缺陷趋势跟踪、流程改进协调 |
| `chip-code-writer` | RTL 缺陷修复、检查规则执行 |
| `chip-env-writer` | 验证缺陷发现、回归验证 |
| `chip-verfi-arch` | 验证盲点分析、场景补充建议 |

---

## 8. 与现有规范的关系

| 现有规范 | 缺陷反馈增强 |
|----------|-------------|
| coding-style.md | 增加缺陷模式驱动的检查规则 |
| cdc-methodology.md | 增加 CDC 缺陷模式和预防规则 |
| verification-convergence.md | 增加缺陷收敛标准 |
| cross-agent-consistency.md | 增加接口缺陷模式和检查规则 |
| chip-arch-reviewer.md | 增加缺陷根因分析职责 |
| chip-project-lead.md | 增加缺陷趋势跟踪职责 |
