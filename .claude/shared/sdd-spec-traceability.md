# SDD 规格驱动追溯规范（共享）

>
> **精简版说明**：chip-requirement-arch 仅需本文件 §1~§5（概述+追溯模型+标注格式+职责+完整性检查）和 §10 L1 层级定义。§6~§9、§10 L2~L11、§11~§12 由下游 Agent（chip-fs-writer、chip-microarch-writer 等）使用。
>
> **快速定位**：
> - 需求 Agent（L1）：仅需 §1~§5 + §10.1 L1 行
> - FS Agent（L2/L3）：需 §1~§7 + §10.1 L2/L3 行
> - 微架构 Agent（L4）：需 §1~§7 + §10.1 L4 行
> - 全链路视图：需 §1~§12 全文

> 本模板定义芯片设计中规格驱动开发（Specification-Driven Development）的全链路追溯规范。
> 供所有芯片 Agent 共同引用，确保从需求到验证的每一步都可追溯到唯一真相源。

---

## 1. 概述

SDD（Specification-Driven Development）在芯片设计中的应用：
- 以 **FS 功能规格书**为唯一真相源（Single Source of Truth）
- 每个设计决策、实现代码、验证场景都必须可追溯到具体 REQ
- 追溯链路贯穿全流程：REQ → FS → BDD → UA → RTL → SVA → UVM

**铁律：不可追溯的设计决策 = 不存在的设计决策。**

---

## 2. 全链路追溯模型

```
REQ-XXX (需求)
  │
  ├─→ FS §4.x (功能描述)        ← 需求到规格
  │     │
  │     ├─→ BDD 场景 (Given-When-Then)  ← 规格到行为
  │     │     │
  │     │     ├─→ UVM Sequence   ← 行为到测试
  │     │     └─→ SVA Assertion  ← 行为到断言
  │     │
  │     ├─→ UA §5.x (微架构)     ← 规格到实现
  │     │     │
  │     │     └─→ RTL 代码       ← 实现到代码
  │     │
  │     └─→ FS §14 RTM (追溯矩阵) ← 全局追溯
  │
  └─→ 验证覆盖率                  ← 需求到验证闭环
```

---

## 3. 追溯标注格式

### 3.1 FS 层标注

FS 文档中每条功能描述必须标注 REQ 编号：

```markdown
**REQ-001**：数据适配器支持单拍数据传输，输入有效时在 3 个周期内输出有效数据。
```

### 3.2 BDD 场景层标注

BDD 场景文件名和内容必须标注 REQ 编号：

```markdown
### 场景：REQ-001_normal_single_transfer

**覆盖 REQ**：REQ-001
**FS 章节**：§4.1
```

### 3.3 UA 微架构层标注

UA 文档中每个设计决策必须标注来源：

```markdown
<!-- Ref: FS §4.1 REQ-001 -->
<!-- Ref: BDD REQ-001_normal_single_transfer -->
```

### 3.4 RTL 代码层标注

RTL 代码中关键逻辑块必须标注来源：

```verilog
// Ref: UA §5.1 数据通路
// Ref: FS §4.1 REQ-001
// BDD: REQ-001_normal_single_transfer
```

### 3.5 SVA 断言层标注

SVA 断言必须标注来源 BDD 场景：

```systemverilog
// BDD: REQ-001_normal_single_transfer
// Ref: FS §4.1 REQ-001
property p_data_valid_after_sop;
    @(posedge clk) disable iff (!rst_n)
    (src_valid && src_sop) |-> ##[1:3] dst_valid;
endproperty
```

### 3.6 UVM Sequence 层标注

UVM Sequence 必须标注来源 BDD 场景：

```systemverilog
// BDD: REQ-001_normal_single_transfer
// Ref: FS §4.1 REQ-001
class seq_REQ001_normal_single_transfer extends uvm_sequence;
```

---

## 4. 各 Agent 追溯职责

| Agent | 追溯输入 | 追溯输出 | 追溯检查 |
|-------|----------|----------|----------|
| chip-fs-writer | REQ 汇总表 | FS §4.x + §14 RTM + BDD 场景 | 每个 REQ 有 FS 章节 + BDD 场景 |
| chip-verfi-arch | FS + BDD 场景 | 测试点 + 用例规划 | 每个 BDD 场景有对应测试点 |
| chip-microarch-writer | FS + BDD 场景 | UA §5.x | 每个设计决策标注 FS/BDD 来源 |
| chip-code-writer | UA + BDD 场景 | RTL + SVA | 关键逻辑标注 UA/BDD 来源 |
| chip-env-writer | BDD 场景 + 验证方案 | UVM Sequence | 每个 Sequence 标注 BDD 来源 |

---

## 5. 追溯完整性检查

### 5.1 正向追溯（REQ → 实现）

```
REQ-001 → FS §4.1 → BDD REQ-001_* → UA §5.1 → RTL → SVA/UVM
```

检查规则：
- 每个 REQ 在 FS 中有对应章节
- 每个 REQ 在 BDD 中有至少 1 个 normal + 1 个 boundary/error 场景
- 每个 BDD 场景在验证中有对应测试用例

### 5.2 反向追溯（实现 → REQ）

```
RTL 代码 → UA §5.x → FS §4.x → REQ-XXX
```

检查规则：
- RTL 中每个关键逻辑块可追溯到 UA
- UA 中每个设计决策可追溯到 FS
- FS 中每条功能描述可追溯到 REQ

### 5.3 追溯覆盖率

| 维度 | 计算公式 | 目标 |
|------|----------|------|
| REQ→FS 覆盖率 | 有 FS 章节的 REQ 数 / 总 REQ 数 | 100% |
| REQ→BDD 覆盖率 | 有 BDD 场景的 REQ 数 / 总 REQ 数 | 100% |
| BDD→测试覆盖率 | 有测试用例的 BDD 场景数 / 总 BDD 场景数 | 100% |
| 反向追溯覆盖率 | 可追溯到 REQ 的 RTL 逻辑块数 / 总逻辑块数 | ≥ 90% |

---

## 6. 追溯断裂处理

当发现追溯断裂（某步骤无法追溯到上游）时：

| 断裂位置 | 处理方式 |
|----------|----------|
| RTL 无法追溯到 UA | 标注 `// UNTRACEABLE: {原因}`，提交评审 |
| UA 无法追溯到 FS | 标注 `<!-- UNTRACEABLE: {原因} -->`，必须评审确认 |
| FS 无法追溯到 REQ | 标注为未分配需求，必须补充 REQ 或删除功能 |
| BDD 场景无对应测试 | 标注为验证缺口，必须补充测试或降级为 Could |

---

## 7. 追溯矩阵扩展

### 7.1 全链路追溯矩阵（Full Traceability Matrix）

在 FS §14 RTM 基础上扩展，增加 BDD/UA/RTL/验证列：

| REQ ID | FS 章节 | BDD 场景 | UA 章节 | RTL 文件 | SVA 断言 | UVM Sequence | 状态 |
|--------|---------|----------|---------|----------|----------|-------------|------|
| REQ-001 | §4.1 | SCN-001~003 | §5.1 | data_adpt_input_if_mod.v | p_001_* | seq_REQ001_* | Designed |
| REQ-002 | §4.2 | SCN-004~006 | §5.2 | data_adpt_reg_mod.v | p_002_* | seq_REQ002_* | Designed |

### 7.2 BDD→验证映射矩阵

| BDD 场景 ID | 场景类型 | 优先级 | UVM Sequence | SVA Assertion | 覆盖率组 | 状态 |
|-------------|----------|--------|-------------|---------------|----------|------|
| SCN-001 | normal | P0 | seq_REQ001_normal | p_001_normal | cg_REQ001 | Designed |
| SCN-002 | boundary | P1 | seq_REQ001_boundary | p_001_boundary | cg_REQ001 | Designed |

---

## 8. 与现有规范的关系

| 现有规范 | SDD 追溯增强 |
|----------|-------------|
| FS 模板 §4.1 | 每条功能描述强制标注 REQ 编号 |
| FS 模板 §14 RTM | 扩展为全链路追溯矩阵 |
| UA 模板 §5.x | 设计决策强制标注 FS/BDD 来源 |
| coding-style.md §12 | 关键逻辑块强制标注 UA/BDD 来源 |
| BDD 场景模板 | 场景强制标注 REQ + FS 章节 |
| quality-checklist-fs.md | 新增追溯完整性检查项 |
| quality-checklist-impl.md | 新增 RTL 追溯检查项 |

---

## 9. 追溯图数据格式（Trace Graph）

> 追溯图是 SDD 的结构化核心产物，将分散在注释中的追溯关系集中存储为可查询的图结构。

### 9.1 存储格式

每个模块在工作目录下维护一个追溯图文件：

```
outputs/{module}_trace_graph.yaml
```

### 9.2 YAML Schema

```yaml
# {module} 追溯图 - 由各 Agent 自动追加
# 查询：任意 id 字段可 grep 定位，upstream/downstream 可遍历全链路
metadata:
  module: {module_name}
  version: {version}
  last_updated: {YYYY-MM-DD}

nodes:
  - id: {节点ID}          # 唯一标识，见 §10 ID 规范
    layer: {L1~L11}       # 层级
    type: {节点类型}       # 见 §10 类型表
    title: "{标题}"        # 人类可读描述
    ref: "{文件路径}"       # 产物文件路径
    upstream: [{上游ID列表}]   # 来源节点
    downstream: [{下游ID列表}] # 消费节点
```

### 9.3 追溯图更新规则

| 规则 | 说明 |
|------|------|
| **追加式写入** | 每个 Agent 只能追加自己负责层级的节点，不能修改其他层级 |
| **双向边完整** | 追加节点时必须同时更新上下游节点的 downstream/upstream |
| **原子性** | 一次追加操作包含：新节点 + 上游节点 downstream 更新 + 下游节点 upstream 更新 |
| **不可删除** | 节点只能标记废弃（`status: deprecated`），不能物理删除 |

### 9.4 追溯图查询方式

```bash
# 正向查询：从 REQ 找所有下游
grep "REQ-001" {module}_trace_graph.yaml

# 反向查询：从 RTL 找上游
grep "{file}:{line}" {module}_trace_graph.yaml

# 叶子节点：哪些节点无下游（验证覆盖终点）
grep "downstream: \[\]" {module}_trace_graph.yaml

# 孤立节点：非 L1 节点 upstream 为空 → 追溯断裂
# 由 chip-arch-reviewer 自动检测
```

---

## 10. L1~L11 全层级 ID 规范

### 10.1 层级定义

| 层级 | 节点类型 | ID 格式 | 示例 | 产生 Agent |
|------|---------|---------|------|-----------|
| L1 | 需求 REQ | `REQ-{NNN}（三位数字，001~999。超过 999 时扩展为 REQ-{NNNN}）` | `REQ-001` | chip-requirement-arch |
| L2 | FS 章节 | `FS-{mod}-§{N.N}` | `FS-data_adpt-§4.1` | chip-fs-writer |
| L3 | BDD 场景 | `SCN-{NNN}` | `SCN-001` | chip-fs-writer |
| L4 | UA 章节 | `UA-{mod}_{sub}-§{N.N}` | `UA-data_adpt_input_if-§5.1` | chip-microarch-writer |
| L5 | Test Point | `TP-{类别}-{REQ}-{NNN}` | `TP-FUNC-REQ001-001` | chip-verfi-arch |
| L6 | RTL 代码块 | `{file}:{line}` | `data_adpt_input_if_mod.v:15` | chip-code-writer |
| L7 | SVA 断言 | `p_{REQ}_{场景}` | `p_REQ001_normal` | chip-code-writer |
| L8 | UVM Sequence | `seq_{REQ}_{场景}` | `seq_REQ001_normal` | chip-env-writer |
| L9 | RM/Checker | `chk_{module}_{功能}` | `chk_data_adpt_data_compare` | chip-env-writer |
| L10 | Test Case | `tc_{module}_{层级}_{场景}` | `tc_data_adpt_l1_basic_rw` | chip-env-writer |
| L11 | Coverage | `cg_{module}_{维度}` | `cg_data_adpt_func` | chip-env-writer |

### 10.2 节点类型枚举

| type 值 | 含义 | 对应层级 |
|---------|------|---------|
| `requirement` | 需求项 | L1 |
| `fs_section` | FS 文档章节 | L2 |
| `bdd_scenario` | BDD 行为场景 | L3 |
| `ua_section` | UA 微架构章节 | L4 |
| `test_point` | 测试点 | L5 |
| `rtl_block` | RTL 代码块 | L6 |
| `sva_assertion` | SVA 断言 | L7 |
| `uvm_sequence` | UVM Sequence | L8 |
| `checker` | RM/Checker/Scoreboard | L9 |
| `test_case` | 测试用例 | L10 |
| `coverage` | 覆盖率组 | L11 |

---

## 11. 各 Agent 追溯图输出职责

| Agent | 负责层级 | 追溯图输出 | 上游引用方式 |
|-------|---------|-----------|-------------|
| chip-requirement-arch | L1 | 创建 trace_graph.yaml 骨架 + L1 节点 | 无（源头） |
| chip-fs-writer | L2, L3 | 追加 L2(FS) + L3(BDD) 节点 | 引用 L1(REQ) |
| chip-microarch-writer | L4 | 追加 L4(UA) 节点 | 引用 L2(FS) |
| chip-verfi-arch | L5 | 追加 L5(TP) 节点 | 引用 L3(BDD) + L2(FS) |
| chip-code-writer | L6, L7 | 追加 L6(RTL) + L7(SVA) 节点 | 引用 L4(UA) + L3(BDD) |
| chip-env-writer | L8, L9, L10, L11 | 追加 L8(Seq) + L9(Chk) + L10(TC) + L11(Cov) 节点 | 引用 L3(BDD) + L5(TP) |
| chip-arch-reviewer | 检查 | 不产出节点，检查追溯图完整性 | 读取全部层级 |
| chip-sta-analyst | 附属 | SDC 约束追溯到 L4(UA) | 引用 L4(UA) |
| chip-top-integrator | 附属 | 顶层连线追溯到 L2(FS §6) | 引用 L2(FS) |
| chip-lowpower-designer | 附属 | UPF 追溯到 L2(FS §10) | 引用 L2(FS) |
| chip-dft-engineer | 附属 | DFT 追溯到 L2(FS §11) | 引用 L2(FS) |
| chip-sw-driver | 附属 | 驱动架构追溯到 L2(FS §7) | 引用 L2(FS) |
| chip-project-lead | 视图 | 追溯图全景视图 + 覆盖率统计 | 读取全部层级 |

### 11.1 Agent 追溯标注格式（代码级）

每个 Agent 在产出物中标注追溯关系，格式统一为：

```markdown
<!-- TRACE: id={本节点ID} upstream={上游ID1,上游ID2} layer={Lx} -->
```

RTL/SV 代码中：

```verilog
// TRACE: id={file}:{line} upstream={UA-xxx-§5.1} layer=L6
// TRACE: id=p_REQ001_normal upstream={SCN-001} layer=L7
```

UVM 代码中：

```systemverilog
// TRACE: id=seq_REQ001_normal upstream={SCN-001} layer=L8
// TRACE: id=chk_data_adpt_data_compare upstream={SCN-001} layer=L9
// TRACE: id=tc_data_adpt_l1_basic_rw upstream={TP-FUNC-REQ001-001,seq_REQ001_normal} layer=L10
// TRACE: id=cg_data_adpt_func upstream={tc_data_adpt_l1_basic_rw} layer=L11
```

---

## 12. 追溯图完整性检查（chip-arch-reviewer 执行）

| # | 检查项 | 通过条件 | 严重级别 |
|---|--------|----------|----------|
| TG-01 | L1 节点 downstream 非空 | 每个 REQ 至少有 1 个 L2(FS) 下游 | Critical |
| TG-02 | L2→L1 追溯完整 | 每个 FS 章节的 upstream 有 REQ | Critical |
| TG-03 | L3→L1 追溯完整 | 每个 BDD 场景的 upstream 有 REQ | Critical |
| TG-04 | L4→L2 追溯完整 | 每个 UA 章节的 upstream 有 FS | Major |
| TG-05 | L6→L4 追溯完整 | 关键 RTL 代码块的 upstream 有 UA | Major |
| TG-06 | L7→L3 追溯完整 | 每个 SVA 断言的 upstream 有 BDD 场景 | Major |
| TG-07 | L8→L3 追溯完整 | 每个 Sequence 的 upstream 有 BDD 场景 | Major |
| TG-08 | L10→L5 追溯完整 | 每个 Test Case 的 upstream 有 Test Point | Major |
| TG-09 | L3→L10 覆盖 | 每个 BDD 场景有对应 Test Case | Major |
| TG-10 | L5→L11 覆盖 | 每个 Test Point 有对应 Coverage | Minor |
| TG-11 | 无孤立节点 | L2~L11 节点 upstream 均非空 | Critical |
| TG-12 | 双向边一致 | A.downstream 包含 B ↔ B.upstream 包含 A | Major |
