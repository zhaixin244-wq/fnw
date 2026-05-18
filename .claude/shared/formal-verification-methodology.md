# 形式验证方法论（共享）

> 本模板定义芯片设计中形式验证（Formal Verification）的方法论。
> 形式验证用数学方法证明 RTL 满足属性，补充仿真覆盖率盲点。
> 供 `chip-sta-analyst`、`chip-arch-reviewer`、`chip-code-writer` 共同引用。

---

## 1. 形式验证模型

```
SVA 断言（属性定义）
    │
    ├─→ 仿真验证（动态）     ← 传统方法，覆盖率依赖测试向量
    │
    └─→ 形式验证（静态）     ← 数学证明，100% 状态空间覆盖
        ├─ 属性检查（ABV）
        ├─ 等价检查（EC）
        ├─ 模型检查（MC）
        └─ 覆盖率分析
```

**铁律：形式验证不是替代仿真，是补充仿真。两者缺一不可。**

---

## 2. 形式验证类型

### 2.1 属性检查（Assertion-Based Verification, ABV）

**用途**：证明 SVA 断言在所有可达状态下都成立。

| 属性类型 | 检查内容 | 工具 |
|----------|----------|------|
| 安全性属性 | 不会发生坏事 | SymbiYosys `prove` |
| 活性属性 | 好事最终会发生 | SymbiYosys `live` |
| 覆盖属性 | 某状态可达 | SymbiYosys `cover` |

**适用场景**：
- 接口协议正确性（握手无死锁）
- 状态机无死锁（所有状态可达）
- FIFO 无溢出（满时禁止写入）
- 数据通路正确性（端到端数据完整性）

### 2.2 等价检查（Equivalence Check, EC）

**用途**：证明两个设计在功能上等价。

| 检查类型 | 比较对象 | 工具 |
|----------|----------|------|
| RTL vs RTL | 重构前后 | Yosys `equiv` |
| RTL vs Netlist | 综合前后 | Yosys `equiv` |
| Netlist vs Netlist | 优化前后 | Yosys `equiv` |

**适用场景**：
- RTL 重构后确认功能不变
- 综合后网表与 RTL 一致
- 物理优化后网表功能不变

### 2.3 模型检查（Model Checking, MC）

**用途**：穷举搜索状态空间，检查属性是否在所有路径上成立。

| 搜索策略 | 适用场景 | 工具 |
|----------|----------|------|
| 有界模型检查（BMC） | 检查 k 步内是否违反 | SymbiYosys `bmc` |
| 无界模型检查 | 检查所有可达状态 | SymbiYosys `prove` |
| 覆盖率分析 | 检查状态可达性 | SymbiYosys `cover` |

**适用场景**：
- 状态机死锁/活锁检查
- 数据通路完整性证明
- 控制逻辑正确性证明

### 2.4 覆盖率分析

**用途**：分析 RTL 中不可达代码，补充仿真覆盖率盲点。

| 分析类型 | 内容 | 工具 |
|----------|------|------|
| 不可达代码 | 永远不会执行的代码 | Yosys `cover` |
| 不可达状态 | 永远不会到达的 FSM 状态 | SymbiYosys `cover` |
| 不可达分支 | 永远不会走的分支 | Yosys `cover` |

---

## 3. 形式验证工作流

### 3.1 标准流程

```
Step 1: SVA 断言准备（来自 SVA-First 方法论）
Step 2: 形式验证约束定义
Step 3: 形式验证执行
Step 4: 结果分析
Step 5: 反馈 RTL 修复
```

### 3.2 约束定义

**输入约束**（assume）：限制输入空间，使形式验证可收敛。

```systemverilog
// 输入约束：valid 信号不依赖 ready（编码规范 §8）
assume_valid_independent: assume property (
    @(posedge clk) (valid && !ready) |=> valid
);

// 输入约束：复位后 valid 为低
assume_reset_valid: assume property (
    @(posedge clk) !rst_n |-> !valid
);
```

**输出约束**：限制输出行为，避免假阳性。

```systemverilog
// 输出约束：ready 信号仅依赖下游状态
assume_ready_downstream: assume property (
    @(posedge clk) ready == !fifo_full
);
```

### 3.3 结果分析

| 结果 | 含义 | 处理方式 |
|------|------|----------|
| PASS | 属性在所有可达状态下成立 | 记录，继续 |
| FAIL | 发现反例（counterexample） | 分析反例，修复 RTL |
| TIMEOUT | 状态空间过大，无法收敛 | 增加约束/减少深度 |
| UNDECIDABLE | 无法判定 | 增加约束或标记 |

---

## 4. 形式验证工具链

### 4.1 工具选型

| 工具 | 类型 | 适用场景 | 命令 |
|------|------|----------|------|
| SymbiYosys | ABV/MC | SVA 属性检查 | `sby -f {config}` |
| Yosys equiv | EC | 等价检查 | `yosys -p "equiv {args}"` |
| Yosys cover | 覆盖率 | 不可达分析 | `yosys -p "cover {args}"` |

### 4.2 SymbiYosys 配置模板

```ini
# {module}_formal.sby
[tasks]
prove bmc cover

[options]
prove: mode prove
bmc: mode bmc
bmc: depth 20
cover: mode cover
cover: depth 20

[engines]
smtbmc

[script]
read -formal {module}_sva.sv
read {module}.v
prep -top {module}

[files]
{module}_sva.sv
{module}.v
```

### 4.3 执行命令

```bash
# 属性检查（无界证明）
sby -f {module}_formal.sby prove

# 有界模型检查（20 步）
sby -f {module}_formal.sby bmc

# 覆盖率分析
sby -f {module}_formal.sby cover

# 等价检查
yosys -p "read_verilog {module}_old.v; read_verilog {module}_new.v; equiv_make {module} {module} equiv; equiv_status"
```

---

## 5. 形式验证适用范围

### 5.1 适合形式验证的模块

| 模块类型 | 理由 | 形式验证重点 |
|----------|------|-------------|
| 状态机 | 状态空间有限 | 死锁/活锁检查 |
| 握手协议 | 协议规则明确 | 协议正确性 |
| 仲裁器 | 公平性可形式化 | 公理性证明 |
| FIFO | 满/空条件明确 | 溢出/下溢检查 |
| 编解码器 | 编解码规则明确 | 编解码正确性 |
| 寄存器模块 | 读写规则明确 | 读写正确性 |

### 5.2 不适合形式验证的模块

| 模块类型 | 理由 | 替代方案 |
|----------|------|----------|
| 数据通路（宽位宽） | 状态空间过大 | 仿真 + 覆盖率 |
| 存储器（大容量） | 状态空间过大 | 仿真 + MBIST |
| 模拟电路 | 非数字逻辑 | SPICE 仿真 |
| 时序逻辑（长流水线） | 状态空间爆炸 | 仿真 + SVA |

### 5.3 状态空间控制

**状态空间爆炸应对策略**：

| 策略 | 说明 | 效果 |
|------|------|------|
| 参数降级 | 形式验证时使用小参数 | 减少状态空间 |
| 黑盒化 | 将大模块黑盒化 | 隔离状态空间 |
| 切割验证 | 分模块独立形式验证 | 分而治之 |
| 增加约束 | 限制输入空间 | 收敛加速 |

---

## 6. 形式验证门禁

| # | 检查项 | 标准 | 适用阶段 |
|---|--------|------|----------|
| FV-01 | 接口协议断言 PASS | 所有接口断言 | GREEN 后 |
| FV-02 | 状态机无死锁 | 所有状态可达 | GREEN 后 |
| FV-03 | FIFO 无溢出 | 满时禁止写入 | GREEN 后 |
| FV-04 | 等价检查 PASS | 重构前后一致 | REFACTOR 后 |
| FV-05 | 不可达代码分析 | 无功能不可达代码 | 签核前 |

---

## 7. 各 Agent 形式验证职责

| Agent | 职责 | 输出 |
|-------|------|------|
| `chip-code-writer` | SVA 断言准备、形式验证执行 | 形式验证结果 |
| `chip-sta-analyst` | 综合后等价检查、覆盖率分析 | EC 报告、覆盖率报告 |
| `chip-arch-reviewer` | 形式验证结果审查、适用范围判定 | 形式验证审查报告 |

---

## 8. 与现有规范的关系

| 现有规范 | 形式验证增强 |
|----------|-------------|
| sva-first-methodology.md | SVA 断言复用于形式验证 |
| tdd-hardware-methodology.md | 形式验证纳入 REFACTOR 阶段门禁 |
| verification-convergence.md | 形式验证覆盖率纳入签核条件 |
| chip-sta-analyst.md | 综合后增加等价检查职责 |
| chip-arch-reviewer.md | 评审增加形式验证结果审查 |
