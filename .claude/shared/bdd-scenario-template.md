# BDD 行为场景模板

> 本模板定义芯片设计中行为驱动验证（BDD）的场景格式和编写规范。
> 供 chip-verfi-arch（场景生成）和 chip-env-writer（UVM Sequence 生成）共同引用。

---

## 1. 概述

BDD（Behavior-Driven Development）在芯片设计中的应用：
- 用 **Given-When-Then** 格式描述硬件行为场景
- 每个 FS 需求项（REQ-XXX）分解为可验证的行为场景
- 行为场景直接驱动 UVM 测试用例和 SVA 断言生成

**铁律：每个 REQ 至少有一个 normal 场景和一个 boundary/error 场景。**

---

## 2. 场景命名规则

```
{REQ编号}_{场景类型}_{简述}
```

示例：
- `REQ-001_normal_single_transfer` — 正常单次传输
- `REQ-001_boundary_max_length` — 最大长度边界
- `REQ-001_error_timeout` — 超时异常
- `REQ-002_reset_async_recovery` — 异步复位恢复

---

## 3. Given-When-Then 格式

### 3.1 标准场景模板

```markdown
### 场景：{REQ-XXX}_{类型}_{简述}

**描述**：{一句话描述场景覆盖的行为}

**Given**（前置条件）：
- 寄存器配置：{寄存器名} = {值}
- 接口信号：{信号名} = {初始值}
- 时钟/复位：clk 正常运行，rst_n 已释放（高电平）
- 状态机：处于 {状态名} 状态

**When**（触发动作）：
- {输入信号变化描述}
- {总线事务描述}
- {寄存器写操作描述}

**Then**（预期行为）：
- 输出信号：{信号名} 在 {N} 个周期内变为 {预期值}
- 状态转移：状态机从 {当前状态} 转移到 {目标状态}
- 寄存器变化：{寄存器名} 更新为 {预期值}
- 中断产生：{中断信号} 在 {N} 个周期内拉高

**验证方法**：{UVM Sequence / SVA Assertion / 波形检查}
**优先级**：{P0-basic / P1-normal / P2-boundary / P3-stress}
**覆盖 REQ**：{REQ-XXX}

**Checker**：`chk_{module}_{功能}` — 验证此场景的检查器（L9 追溯）
**Test Case**：`tc_{module}_{层级}_{场景}` — 覆盖此场景的测试用例（L10 追溯）
**Coverage**：`cg_{module}_{维度}` — 采样此场景的覆盖率组（L11 追溯）
```

### 3.2 简化场景模板（用于重复性场景）

```markdown
### 场景：{REQ-XXX}_{类型}_{简述}

**Given**：{前置条件}
**When**：{触发动作}
**Then**：{预期行为}
**验证**：{方法} | **优先级**：{P0-P3}
```

---

## 4. 场景分类

| 场景类型 | 代码 | 描述 | 优先级 | 覆盖目标 |
|----------|------|------|--------|----------|
| 正常路径 | `normal` | 核心功能的正常工作路径 | P0 | 功能正确性 |
| 边界条件 | `boundary` | 最大/最小值、满/空、首尾 | P1 | 边界鲁棒性 |
| 异常处理 | `error` | 超时、协议错误、溢出、非法输入 | P1 | 异常恢复能力 |
| 复位恢复 | `reset` | 异步复位、同步释放、复位后状态 | P1 | 复位正确性 |
| 并发场景 | `concurrent` | 多通道同时请求、仲裁、资源竞争 | P2 | 并发安全性 |
| 功耗状态 | `power` | 时钟门控、功耗域切换、休眠唤醒 | P2 | 功耗管理正确性 |
| 压力测试 | `stress` | 连续高负载、长时间运行、随机注入 | P3 | 系统稳定性 |

---

## 5. 场景编写规则

### 5.1 Given 规则

- **具体化**：寄存器值、信号值必须具体，不能用"默认值"、"初始状态"
- **可复现**：Given 条件必须可在 UVM testbench 中精确重建
- **完整性**：所有影响被测行为的前置条件都要列出

### 5.2 When 规则

- **单一触发**：每个场景只有一个触发动作（多触发拆分为多个场景）
- **时序明确**：多拍操作需标注每拍的信号变化
- **可驱动**：When 动作必须可通过 UVM Sequence 驱动

### 5.3 Then 规则

- **可检查**：每个 Then 条件必须可通过 SVA 或 scoreboard 检查
- **量化**：延迟用具体周期数，值用具体数值
- **独立性**：每个 Then 条件独立可验证

---

## 6. 场景与验证方法映射

| 场景类型 | 首选验证方法 | 备选方法 |
|----------|-------------|----------|
| normal | UVM Sequence + Scoreboard | SVA Assertion |
| boundary | UVM Sequence（约束随机） | SVA Assertion |
| error | UVM Sequence（异常注入） | SVA Assertion |
| reset | UVM Sequence（复位序列） | SVA Assertion |
| concurrent | UVM Sequence（多 driver） | SVA Assertion |
| power | UVM Sequence（功耗控制） | SVA Assertion |
| stress | UVM Sequence（随机长序列） | 覆盖率统计 |

---

## 7. 场景覆盖率模型

| 覆盖维度 | 覆盖点 | 目标 |
|----------|--------|------|
| REQ 覆盖 | 每个 REQ 至少 1 个 normal + 1 个 boundary/error | 100% |
| 场景类型覆盖 | 每种场景类型至少 1 个 | 100% |
| 状态机覆盖 | 每个状态和转移至少 1 个场景 | 100% |
| 接口覆盖 | 每个接口的每种事务类型 | 100% |

---

## 7.1 场景→验证产物追溯映射（L3→L9/L10/L11）

> 每个 BDD 场景必须可追溯到验证环境中的具体产物，形成 L3→L9/L10/L11 的完整追溯链。

| BDD 场景元素 | 验证产物 | 追溯层级 | 说明 |
|-------------|---------|---------|------|
| 场景整体 | Checker/RM (L9) | L3→L9 | 指定验证此场景的检查器 |
| 场景整体 | Test Case (L10) | L3→L10 | 指定覆盖此场景的测试用例 |
| 场景整体 | Coverage (L11) | L3→L11 | 指定采样此场景的覆盖率组 |

**追溯标注规则**：
1. 每个 BDD 场景的 `Checker` 字段填写验证该场景的 Checker ID（`chk_*`）
2. 每个 BDD 场景的 `Test Case` 字段填写覆盖该场景的 Test Case ID（`tc_*`）
3. 每个 BDD 场景的 `Coverage` 字段填写采样该场景的 Coverage ID（`cg_*`）
4. 场景汇总表中 Checker/Test Case/Coverage 列在验证环境实现后回填

---

## 8. 输出格式

### 8.1 行为场景文档

文件命名：`{module}_bdd_scenarios.md`

```markdown
# {模块名} 行为场景文档

> 基于 FS 需求分解的 BDD 行为场景，驱动验证用例生成。

## 场景汇总

| 场景 ID | REQ | 类型 | 描述 | 优先级 | 验证方法 | Checker | Test Case | Coverage | 状态 |
|---------|-----|------|------|--------|----------|---------|-----------|----------|------|
| SCN-001 | REQ-001 | normal | 单次正常传输 | P0 | UVM+SVA | chk_xxx | tc_xxx | cg_xxx | Designed |
| SCN-002 | REQ-001 | boundary | 最大长度传输 | P1 | UVM+SVA | chk_xxx | tc_xxx | cg_xxx | Designed |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

## 详细场景

### SCN-001: REQ-001_normal_single_transfer

{Given-When-Then 格式}

### SCN-002: REQ-001_boundary_max_length

{Given-When-Then 格式}

...
```

### 8.2 与 RTM 的关联

行为场景文档中的场景 ID 引用到 FS §14 RTM 的验证策略列：

| 需求 ID | FS 章节 | 验证策略 | BDD 场景 |
|---------|---------|----------|----------|
| REQ-001 | §4.1 | 功能仿真 | SCN-001~SCN-005 |
| REQ-002 | §4.2 | 接口仿真 | SCN-006~SCN-010 |
