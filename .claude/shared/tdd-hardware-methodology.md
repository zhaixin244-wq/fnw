# TDD 硬件方法论（共享）

> 本模板定义芯片 RTL 设计的测试驱动开发（Test-Driven Development）方法论。
> 核心思想：先写测试（SVA + TB），再写 RTL 实现，最后重构优化。
> 供 `chip-code-writer`、`chip-env-writer`、`chip-verfi-arch` 共同引用。

---

## 1. 硬件 TDD 模型

```
传统流程：RTL → TB → 发现 Bug → 修复 RTL → 再测
                    ↑ 被动发现，修复成本高

TDD 流程：SVA/TB（RED）→ RTL（GREEN）→ 重构（REFACTOR）→ 回归
                    ↑ 主动预防，Bug 在萌芽时被捕获
```

**铁律：没有失败的测试，就不写 RTL 实现。**

---

## 2. TDD 三阶段

### 2.1 RED 阶段：先写测试

**目标**：定义预期行为，运行测试 → 期望失败（因为 RTL 还不存在）。

| 测试类型 | 来源 | 生成时机 | 负责 Agent |
|----------|------|----------|-----------|
| SVA 断言 | BDD 场景 Then 条件 | FS/BDD 完成后 | `chip-code-writer` |
| TB 基础测试 | BDD 场景 When 动作 | UA 完成后 | `chip-env-writer` |
| 覆盖率模型 | BDD 场景覆盖点 | 验证方案完成后 | `chip-verfi-arch` |

**RED 阶段输出**：
- `_sva.sv`：SVA 断言文件（从 BDD 场景自动生成）
- `_tb.v`：基础 testbench（验证接口协议和基本功能）
- 覆盖率 covergroup 定义

**RED 阶段验证**：
```bash
# 断言应该失败（RTL 不存在）
verilator --lint-only -Wall {module}_sva.sv  # 语法检查通过
# 仿真应该失败（RTL 行为不符合预期）
# 预期：assertion failure 或 testbench check 失败
```

### 2.2 GREEN 阶段：编写最少 RTL

**目标**：编写最少的 RTL 代码让所有测试通过。

| 约束 | 说明 |
|------|------|
| 最少代码 | 只实现测试覆盖的功能，不提前实现未测试的功能 |
| 先通后优 | 先让测试通过，不在 GREEN 阶段优化 |
| 断言驱动 | SVA 断言通过 = 功能正确 |

**GREEN 阶段验证**：
```bash
# Lint 检查
verilator --lint-only -Wall {module}.v
# 仿真通过
# 预期：所有 assertion pass，所有 testbench check pass
```

### 2.3 REFACTOR 阶段：优化重构

**目标**：优化时序/面积/可读性，重跑测试确认仍通过。

| 优化类型 | 说明 | 验证方式 |
|----------|------|----------|
| 时序优化 | 插入流水线/重定时 | 综合时序分析 |
| 面积优化 | 资源复用/逻辑简化 | 综合面积报告 |
| 可读性优化 | 信号重命名/注释补充 | Lint + 回归 |
| 编码规范 | 符合 coding-style.md | Verible lint |

**REFACTOR 阶段验证**：
```bash
# 全量回归
# 预期：所有测试仍通过，无回归
# 综合验证
# 预期：时序/面积满足 PPA 目标
```

---

## 3. TDD 与 BDD 的映射

```
BDD 场景（Given-When-Then）
    │
    ├─→ RED 阶段
    │   ├─ Given → 测试前置条件（TB 初始化、寄存器配置）
    │   ├─ When  → 测试激励（TB 驱动事务）
    │   └─ Then  → 测试检查（SVA 断言 + TB 比较）
    │
    ├─→ GREEN 阶段
    │   └─ RTL 实现满足所有 Then 条件
    │
    └─→ REFACTOR 阶段
        └─ 优化后 Then 条件仍满足
```

| BDD 元素 | TDD 映射 | 生成规则 |
|----------|----------|----------|
| Given（前置条件） | TB 初始化序列 | 寄存器后门写、接口初始值 |
| When（触发动作） | TB 激励序列 | `uvm_do_with` 驱动事务 |
| Then（预期行为） | SVA 后件 + TB 检查 | `assert property` + `check` 函数 |

---

## 4. TDD 生成规则

### 4.1 从 BDD 场景生成 SVA 断言（RED 阶段）

**规则**：每个 BDD 场景的 Then 条件必须生成至少 1 个 SVA 断言。

```systemverilog
// BDD: REQ-001_normal_single_transfer
// Given: 系统复位完成，通道使能
// When: 输入端发送单拍数据
// Then: 3 个周期内输出端有效数据
property p_REQ001_normal_single_transfer;
    @(posedge clk) disable iff (!rst_n)
    (src_valid && src_ready) |-> ##[1:3] dst_valid;
endproperty
assert_REQ001_normal: assert property (p_REQ001_normal_single_transfer);
```

### 4.2 从 BDD 场景生成 TB 测试（RED 阶段）

**规则**：每个 BDD 场景生成 1 个 TB 测试任务。

```verilog
// BDD: REQ-001_normal_single_transfer
task test_REQ001_normal_single_transfer;
    // Given: 复位 + 通道使能
    rst_n = 0; #20; rst_n = 1;
    ch_en = 1;
    // When: 发送单拍数据
    @(posedge clk);
    src_valid = 1;
    src_data = 32'hDEAD_BEEF;
    @(posedge clk iff src_ready);
    src_valid = 0;
    // Then: 检查输出
    repeat(3) @(posedge clk);
    if (!dst_valid) $error("REQ-001: dst_valid not asserted within 3 cycles");
    if (dst_data !== 32'hDEAD_BEEF) $error("REQ-001: data mismatch");
endtask
```

### 4.3 RTL 实现阶段（GREEN 阶段）

**规则**：按 SVA 断言和 TB 测试逐个实现 RTL 功能。

| 优先级 | 实现顺序 | 理由 |
|--------|----------|------|
| P0 | 接口协议（握手） | 所有测试依赖握手正确 |
| P1 | 数据通路 | 核心功能 |
| P2 | 控制逻辑 | 状态机、仲裁 |
| P3 | 异常处理 | 边界条件 |

---

## 5. TDD 门禁

### 5.1 RED 阶段门禁

| # | 检查项 | 标准 |
|---|--------|------|
| TDD-R01 | SVA 断言语法正确 | Lint 0 Error |
| TDD-R02 | TB 测试语法正确 | Lint 0 Error |
| TDD-R03 | 断言/测试可运行 | 仿真可执行（预期失败） |
| TDD-R04 | 覆盖率模型已注册 | covergroup 语法正确 |

### 5.2 GREEN 阶段门禁

| # | 检查项 | 标准 |
|---|--------|------|
| TDD-G01 | RTL Lint 0 Error | Verilator 通过 |
| TDD-G02 | 所有 SVA 断言通过 | assertion pass |
| TDD-G03 | 所有 TB 测试通过 | testbench check pass |
| TDD-G04 | 覆盖率可采集 | covergroup 采样有效 |

### 5.3 REFACTOR 阶段门禁

| # | 检查项 | 标准 |
|---|--------|------|
| TDD-F01 | 回归全部通过 | 无新增失败 |
| TDD-F02 | 时序满足 | Tslack > 0 |
| TDD-F03 | 面积满足 | ≤ 预算 |
| TDD-F04 | 编码规范符合 | Verible lint 通过 |

---

## 6. 各 Agent TDD 职责

| Agent | TDD 阶段 | 职责 |
|-------|----------|------|
| `chip-code-writer` | RED + GREEN + REFACTOR | 生成 SVA（RED）、实现 RTL（GREEN）、优化（REFACTOR） |
| `chip-env-writer` | RED | 生成 TB 测试（从 BDD 场景） |
| `chip-verfi-arch` | RED | 定义覆盖率模型、验证策略 |
| `chip-arch-reviewer` | 门禁审查 | 检查 TDD 门禁合规性 |

---

## 7. TDD 例外情况

| 场景 | 处理方式 |
|------|----------|
| 纯组合逻辑（assign only） | 可跳过 TB 先写，RTL 完成后立即补充 TB |
| IP/CBB 集成 | IP 行为由 IP 文档定义，TB 验证集成正确性 |
| 顶层模块（仅连线） | 跳过 TDD，直接实例化 + 系统 Lint |
| 寄存器模块（纯配置） | SVA 验证寄存器读写，跳过 TB |

---

## 8. 与现有规范的关系

| 现有规范 | TDD 增强 |
|----------|----------|
| coding-style.md | SVA 断言编写规范（§11）与 TDD RED 阶段对齐 |
| bdd-scenario-template.md | BDD Then 条件 → SVA 断言生成规则 |
| verification-convergence.md | TDD 门禁与验证收敛标准对齐 |
| chip-code-writer.md | RTL 实现阶段强制 TDD 流程 |
| chip-env-writer.md | TB 生成阶段强制 RED 先行 |
