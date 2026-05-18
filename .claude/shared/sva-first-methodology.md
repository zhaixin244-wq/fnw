# SVA-First 方法论（共享）

> 本模板定义断言驱动开发（Assertion-Driven Development）的方法论。
> 核心思想：SVA 断言是可执行的规格说明，先于 RTL 编写，驱动 RTL 实现。
> 供 `chip-code-writer`、`chip-env-writer`、`chip-verfi-arch` 共同引用。

---

## 1. SVA-First 模型

```
FS 功能描述（自然语言）
    │
    ├─→ BDD 场景（Given-When-Then）
    │     │
    │     ├─→ SVA 断言（可执行规格）  ← RED 阶段
    │     │     │
    │     │     ├─→ RTL 实现          ← GREEN 阶段
    │     │     │     │
    │     │     │     └─→ 断言通过    ← 验证
    │     │     │
    │     │     └─→ 断言失败          ← 发现 RTL Bug
    │     │
    │     └─→ TB 测试（补充验证）
    │
    └─→ 覆盖率（验证完整性）
```

**铁律：SVA 断言 = 可执行的规格说明。没有断言的功能 = 没有规格的功能。**

---

## 2. SVA 分类体系

### 2.1 按来源分类

| SVA 类型 | 来源 | 生成时机 | 示例 |
|----------|------|----------|------|
| 接口协议断言 | FS §6 接口定义 | 接口设计完成后 | 握手稳定性、数据稳定性 |
| 功能断言 | BDD 场景 Then 条件 | BDD 场景生成后 | 功能正确性 |
| 安全断言 | 架构评审发现 | 评审完成后 | 不应发生的条件 |
| 覆盖断言 | 覆盖率模型 | 验证收敛阶段 | 功能覆盖率补充 |

### 2.2 按强度分类

| 强度 | 关键字 | 用途 | 失败行为 |
|------|--------|------|----------|
| 必须满足 | `assert` | 功能正确性 | `$error`，阻塞 |
| 假设条件 | `assume` | 输入约束 | 工具报告 |
| 覆盖检查 | `cover` | 功能覆盖率 | 工具统计 |

### 2.3 按时序分类

| 时序类型 | 语法 | 适用场景 |
|----------|------|----------|
| 即时断言 | `assert (expr)` | 组合逻辑检查 |
| 并发断言 | `assert property (prop)` | 时序行为检查 |
| 多时钟断言 | `@(posedge clk1) ... @(posedge clk2)` | CDC 检查 |

---

## 3. SVA 生成规则

### 3.1 从 BDD 场景生成 SVA

**映射规则**：

| BDD 元素 | SVA 元素 | 生成规则 |
|----------|----------|----------|
| Given（前置条件） | `disable iff` | 复位/使能条件 |
| Given（状态条件） | 前置序列 | 初始状态 |
| When（触发动作） | 前件（antecedent） | `src_valid && src_ready` |
| Then（即时行为） | 后件（consequent） | `dst_valid` |
| Then（延迟行为） | `##[1:N]` | `##[1:3] dst_valid` |
| Then（稳定行为） | `$stable` | `$stable(data)` |

### 3.2 接口协议断言（自动生成）

**规则**：每个接口的握手信号必须生成以下标准断言。

```systemverilog
// 握手稳定性：valid 拉高后保持直到 ready
property p_valid_stable;
    @(posedge clk) disable iff (!rst_n)
    (valid && !ready) |=> valid;
endproperty
assert_valid_stable: assert property (p_valid_stable);

// 数据稳定性：valid 期间数据不变
property p_data_stable;
    @(posedge clk) disable iff (!rst_n)
    (valid && !ready) |=> $stable(data);
endproperty
assert_data_stable: assert property (p_data_stable);

// 无组合环路：ready 不依赖 valid（在同一周期）
// 由编码规范 §8 保证，SVA 可选检查
```

### 3.3 功能断言（从 BDD 生成）

**规则**：每个 BDD 场景的 Then 条件生成至少 1 个功能断言。

```systemverilog
// BDD: REQ-001_normal_single_transfer
// Given: 复位完成，通道使能
// When: 输入端发送单拍数据
// Then: 3 个周期内输出端有效数据
property p_REQ001_normal;
    @(posedge clk) disable iff (!rst_n)
    (src_valid && src_ready) |-> ##[1:3] dst_valid;
endproperty
assert_REQ001_normal: assert property (p_REQ001_normal);

// BDD: REQ-002_boundary_max_data
// Given: 复位完成
// When: 输入端发送最大值数据
// Then: 输出端数据等于最大值
property p_REQ002_boundary_max;
    @(posedge clk) disable iff (!rst_n)
    (src_valid && src_ready && src_data == {DATA_WIDTH{1'b1}})
    |-> ##[1:3] (dst_valid && dst_data == {DATA_WIDTH{1'b1}});
endproperty
assert_REQ002_boundary_max: assert property (p_REQ002_boundary_max);
```

### 3.4 安全断言（评审后补充）

**规则**：架构评审发现的风险点必须补充安全断言。

```systemverilog
// 安全：FIFO 不应溢出
property p_fifo_no_overflow;
    @(posedge clk) disable iff (!rst_n)
    !(fifo_full && fifo_wr_en);
endproperty
assert_fifo_no_overflow: assert property (p_fifo_no_overflow);

// 安全：状态机不应进入非法状态
property p_fsm_no_illegal;
    @(posedge clk) disable iff (!rst_n)
    state_cur inside {S_IDLE, S_WORK, S_DONE};
endproperty
assert_fsm_no_illegal: assert property (p_fsm_no_illegal);

// 安全：复位后状态机回到 IDLE
property p_reset_idle;
    @(posedge clk) !rst_n |-> (state_cur == S_IDLE);
endproperty
assert_reset_idle: assert property (p_reset_idle);
```

### 3.5 覆盖断言（验证收敛补充）

**规则**：关键功能点必须有覆盖断言，确保被验证过。

```systemverilog
// 覆盖：正常传输被触发
cover_REQ001_normal: cover property (
    @(posedge clk) disable iff (!rst_n)
    (src_valid && src_ready) ##[1:3] dst_valid
);

// 覆盖：所有 FSM 状态被访问
cover_fsm_idle: cover property (
    @(posedge clk) (state_cur == S_IDLE)
);
cover_fsm_work: cover property (
    @(posedge clk) (state_cur == S_WORK)
);
```

---

## 4. SVA 文件组织

### 4.1 文件结构

```
{module}_sva.sv          — SVA 断言文件
├── 接口协议断言          — 自动从 FS §6 生成
├── 功能断言              — 从 BDD 场景生成
├── 安全断言              — 从评审发现生成
└── 覆盖断言              — 从覆盖率模型生成
```

### 4.2 绑定方式

```systemverilog
// SVA 文件通过 bind 绑定到 RTL
bind {module} {module}_sva u_sva (
    .clk(clk),
    .rst_n(rst_n),
    .src_valid(src_valid),
    .src_ready(src_ready),
    .src_data(src_data),
    .dst_valid(dst_valid),
    .dst_data(dst_data)
);
```

### 4.3 条件编译

```systemverilog
`ifdef ASSERT_ON
// 所有 SVA 断言放在 ASSERT_ON 宏内
`endif
```

---

## 5. SVA-First 工作流

### 5.1 完整流程

```
Step 1: FS §6 接口定义完成 → 生成接口协议断言（自动）
Step 2: BDD 场景生成完成 → 生成功能断言（自动）
Step 3: SVA 语法检查 → Lint 0 Error（门禁）
Step 4: RTL 实现阶段 → 断言驱动实现
Step 5: 架构评审完成 → 补充安全断言
Step 6: 验证收敛阶段 → 补充覆盖断言
Step 7: 全量回归 → 所有断言通过（签核）
```

### 5.2 断言失败处理

| 失败类型 | 根因分析 | 处理方式 |
|----------|----------|----------|
| 接口断言失败 | RTL 握手实现错误 | 修复 RTL 握手逻辑 |
| 功能断言失败 | RTL 功能实现错误 | 修复 RTL 功能逻辑 |
| 安全断言失败 | RTL 存在安全隐患 | 修复 RTL 安全逻辑 |
| 覆盖断言未触发 | 验证场景缺失 | 补充 TB 测试 |

---

## 6. SVA 质量标准

### 6.1 覆盖率目标

| SVA 类型 | 覆盖率目标 | 计算方式 |
|----------|-----------|----------|
| 接口协议断言 | 100% | 所有接口都有协议断言 |
| 功能断言 | ≥ 90% | 有断言的 BDD 场景 / 总 BDD 场景 |
| 安全断言 | 100% | 所有评审风险点都有断言 |
| 覆盖断言 | ≥ 80% | 有覆盖断言的功能点 / 总功能点 |

### 6.2 断言质量检查

| # | 检查项 | 标准 |
|---|--------|------|
| SVA-Q01 | 所有断言有 `disable iff` | 必须 |
| SVA-Q02 | 并发断言使用 `assert property` | 必须 |
| SVA-Q03 | 断言命名：`assert_` / `assume_` / `cover_` | 必须 |
| SVA-Q04 | property 命名：`p_` 前缀 | 必须 |
| SVA-Q05 | 断言标注 BDD 来源 | 必须 |
| SVA-Q06 | 无死锁断言（`always` 可触发） | 必须 |

---

## 7. 各 Agent SVA-First 职责

| Agent | 职责 | 输出 |
|-------|------|------|
| `chip-code-writer` | 生成 SVA 文件、SVA 驱动 RTL 实现 | `{module}_sva.sv` |
| `chip-env-writer` | TB 测试与 SVA 断言对齐 | TB 测试覆盖 SVA 断言 |
| `chip-verfi-arch` | 定义覆盖率模型、覆盖断言规划 | 覆盖率模型 |
| `chip-arch-reviewer` | 安全断言补充、断言质量审查 | 安全断言列表 |

---

## 8. 与现有规范的关系

| 现有规范 | SVA-First 增强 |
|----------|---------------|
| coding-style.md §11 | SVA 编写规范扩展为 SVA-First 工作流 |
| bdd-scenario-template.md | BDD Then 条件 → SVA 断言自动生成规则 |
| tdd-hardware-methodology.md | SVA-First 是 TDD RED 阶段的核心 |
| verification-convergence.md | 断言覆盖率纳入签核条件 |
| sdd-spec-traceability.md | SVA 断言追溯到 BDD 场景和 REQ |
