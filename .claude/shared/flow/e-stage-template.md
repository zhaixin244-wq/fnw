# E 阶段：子模块需求与功能点梳理

> **触发条件**：D0 子模块划分后，任意子模块预估行数 > 3000 行，或总行数 > 8000 行
> **输入**：D0 子模块列表 + stageC phase2 需求汇总表
> **输出**：子模块需求矩阵 + 子模块功能点列表

---

## 1. 子模块总览

| # | 子模块名 | 职责 | 预估行数 | 全局 REQ 映射 | 独立 REQ 范围 |
|---|----------|------|----------|---------------|---------------|
| 1 | {name} | {职责} | {行数} | REQ-XXX, REQ-YYY | REQ-001 ~ E-XXX |
| 2 | {name} | {职责} | {行数} | REQ-XXX, REQ-YYY | E-XXX+1 ~ E-YYY |

---

## 2. 子模块需求矩阵

### 2.1 {子模块名 1}

**全局 REQ 映射**：

| 全局 REQ | 子模块功能点 | 优先级 |
|----------|-------------|--------|
| REQ-002 | AXI4 Master 接口 | Must |
| REQ-003 | 数据搬运功能 | Must |

**独立需求（REQ）**：

| REQ | 需求描述 | 来源 | 优先级 |
|-------|----------|------|--------|
| REQ-001 | {需求描述} | {来源} | Must/Should/Could |

**子模块功能点**：
1. {功能点 1}
2. {功能点 2}

**接口定义**：

| 端口名 | 方向 | 位宽 | 功能 |
|--------|------|------|------|
| {端口} | I/O | {位宽} | {功能} |

---

### 2.2 {子模块名 2}

（同上格式）

---

## 3. 子模块间依赖关系

| 源子模块 | 目标子模块 | 接口 | 依赖类型 |
|----------|-----------|------|----------|
| {src} | {dst} | {接口} | 数据/控制/配置 |

---

## 4. 用户确认

请逐个子模块确认：
- [ ] {子模块名 1}：确认/修改
- [ ] {子模块名 2}：确认/修改

确认后，请选择先细化哪个子模块：___

---

## 5. 子模块 D 阶段执行计划

> **铁律：Agent 必须按 todolist 中定义的递归流程和执行顺序逐步执行，不得跳过或乱序。**

### 5.1 标准化 Todolist 模板

生成到 `<module>_work/ds/doc/pr/e_stage_tree_todolist.md`，格式如下：

```markdown
# E 阶段树形 Todolist

> 本文件是 E 阶段递归分解的执行指南。Agent 必须按本文件定义的流程和顺序逐步执行。

---

## 1. 递归分解结果

| ID | 名称 | 层级 | 父节点 | 预估行数 | 状态 | 执行顺序 | 依赖 | 全局 REQ | REQ |
|----|------|------|--------|----------|------|----------|------|----------|-------|
| 1 | {子模块A} | 1 | 顶层 | {N} | pending | 1 | - | REQ-XXX | REQ-001~REQ-005 |
| 1.1 | {孙模块A1} | 2 | A | {N} | pending | 1.1 | - | REQ-XXX | REQ-001~REQ-003 |
| 1.2 | {孙模块A2} | 2 | A | {N} | pending | 1.2 | 1.1 | REQ-XXX | REQ-004~REQ-005 |
| 2 | {子模块B} | 1 | 顶层 | {N} | pending | 2 | - | REQ-XXX | REQ-006~REQ-010 |

## 2. 递归分解流程

### 步骤 1：D0 估算 RTL 行数
- ≤3000 行 → 跳过 E 阶段
- >3000 行 → 进入步骤 2

### 步骤 2：头脑风暴划分原则
- 调用 brainstorming skill 与用户确认
- **用户未确认不得进入步骤 3**

### 步骤 3：划分子模块
- 按确认的划分原则划分
- 为每个子模块估算行数
- 记录到 §1 表格

### 步骤 4：递归检查
for each 子模块:
  if 行数 > 3000 → 递归执行步骤 2~4
  else → 标记为叶子节点

### 步骤 5：生成执行顺序
- 按依赖关系排序
- 分配执行顺序编号

### 步骤 6：创建目录结构
mkdir -p <module>_work/ds/doc/pr/{子模块名}/
mkdir -p <module>_work/ds/doc/pr/{父模块名}/{孙模块名}/

### 步骤 7：验证目录
- 目录未创建不得进入子模块 D 阶段

## 3. 子模块 D 阶段执行流程

按 execution_order 顺序：
1. 选择 pending 状态的叶子节点
2. 更新为 in_progress
3. 执行 D1~D14（D0 跳过）
4. 生成 5 个交付文件
5. 规格自检 5 项
6. 更新为 completed
7. 全部 completed → 进入 §4

## 4. 完成检查

| # | 检查项 | 阻断条件 |
|---|--------|----------|
| 1 | 目录存在 | 缺失 → 阻断 F 阶段 |
| 2 | 5 文件齐全 | <3 → 阻断 F 阶段 |
| 3 | 目录结构统一 | 不符合 → 阻断 |
| 4 | REQ 连续 | 跳号 → 阻断 |
| 5 | 全部 completed | pending → 阻断 |

## 5. 执行进度跟踪

| 阶段 | 总数 | completed | 进度 |
|------|------|-----------|------|
| 子模块 D 阶段 | {N} | {N} | {N}% |
| 交付文件 | {N×5} | {N} | {N}% |
```

### 5.2 执行规则

- todolist 生成后，Agent 按 §2 递归分解流程逐步执行
- 每完成一个子模块，更新 §1 表格中的状态
- 所有叶子节点 completed 后，执行 §4 完成检查
- 检查全部通过后，触发 F 阶段

---

## 6. 执行说明

### 6.1 E 阶段执行步骤

1. 读取 D0 子模块列表，提取每个子模块的基本信息
2. 读取 stageC phase2 需求汇总表，提取全局 REQ
3. 为每个子模块梳理独立的需求与功能点
4. 输出 E 阶段文档：子模块需求矩阵
5. 用户逐个子模块确认
6. 用户选择先细化哪个子模块
7. 对选中的子模块独立执行 D1~D14 流程（D0 跳过）
8. 重复步骤 6-7，直到所有子模块完成

### 6.2 子模块执行规则（v6.6：多级递归 + todolist 强制执行）

- **子模块起始阶段**：子模块从 **stageB phase2**（头脑风暴 Feature Discovery）开始，而非直接跳到 D0
- **B+ 多轮头脑风暴**：
  - 第 1 轮：按 5 个维度（功能扩展/性能优化/兼容性/可测试性/可维护性）探索子模块特有 feature，参考 Wiki 知识库
  - 用户确认第 1 轮结果 → 追加 REQ → 进入第 2 轮
  - 用户不确认 → 根据反馈调整 → 重新探索
  - 第 2 轮：基于已追加的 REQ，深入探索子 feature
  - 重复直到：用户明确「没有更多需求」或连续 2 轮无新 feature（最多 5 轮）
- **多级递归**（v6.6）：递归不限于两级，持续到所有叶子节点 <3000 行。目录为 level{N}_{name}/ 逐级嵌套
- **逐级执行**（v6.6）：每级独立执行，通过该级 todolist 跟踪状态。先生成顶层 outputs+todolist，再逐个子模块执行
- **todolist 强制执行**（v6.6）：
  - 每级 todolist 必须明确定义下级子模块的 flow（B+/C0/C/D/E 各阶段）
  - 子模块**严格按上级 todolist 定义的 flow 执行**
  - **如果 todolist 缺失 → 立即报错 `[TODOLIST-ERROR]` → 通知用户 → 停止 Agent 所有后续执行**
- **全局完成检查**（v6.6）：所有流程完成后，扫描所有层级 todolist，确认全部 completed → 才进入 F 阶段
- **stageB phase2 后续流程**：stageC phase1 → stageC phase2 → stageD（D0 估算 + D1~D14）→ stageE（如有下级模块）
- **完整交付文档**：每个子模块产出 6 个文件（PR/需求汇总/方案/ADR/追溯图/todolist）+ flow/ 记录

### 6.3 子模块交付文档要求

**铁律：E 阶段分解出的每个子模块，其交付文档必须等同于主模块，不可简化或省略。**

每个子模块完成后，必须在统一目录结构下产出交付文件（v6.6：多级递归，每级 outputs/ + flow/，直到 <3000 行）。

**统一目录结构规则（v6.6）**：

```
<module>_work/ds/doc/                       # L0 主模块根目录
├── outputs/                                # L0 交付物目录
│   ├── {module}_pr_v1.0.md
│   ├── {module}_requirement_summary_v1.0.md
│   ├── {module}_solution_v1.0.md
│   ├── {module}_ADR_v1.0.md
│   ├── {module}_trace_graph.yaml
│   └── e_stage_tree_todolist.md
├── flow/                                   # L0 流程记录目录
│   ├── stage0.md ~ stageF.md（9 个文件）
│
├── level1_subA/                            # L1 子模块
│   ├── outputs/                            # L1 交付物（6 文件）
│   ├── flow/                               # L1 流程（5+ 文件，从 B+ 开始）
│   ├── level2_subA1/                       # L2 子模块
│   │   ├── outputs/
│   │   ├── flow/
│   │   ├── level3_subA1a/                  # L3 子模块（继续递归直到 <3000 行）
│   │   │   ├── outputs/
│   │   │   └── flow/
│   │   └── level3_subA1b/
│   │       ├── outputs/
│   │       └── flow/
│   └── level2_subA2/
│       ├── outputs/
│       └── flow/
│
└── level1_subB/
    ├── outputs/
    └── flow/
```

**目录创建命令（v6.6：先顶层，再逐级递归）**：
```bash
# 步骤 1：创建顶层目录
mkdir -p <module>_work/ds/doc/{outputs,flow}/

# 步骤 2：生成顶层 outputs/ 和 flow/ 文件 + todolist

# 步骤 3：递归创建子模块目录（按 todolist 定义）
for each 子模块 in todolist:
  mkdir -p <parent>/level{N}_{name}/{outputs,flow}/
  if 子模块.预估行数 > 3000:
    递归执行步骤 3（创建下级目录）
```

**文件命名规则**：`{模块名}_{文件类型}_v{版本}.md`

| # | outputs/ 文件 | flow/ 文件 | 说明 |
|---|--------------|------------|------|
| 1 | `{name}_pr_v1.0.md` | `stageB_phase2.md` | PR / 头脑风暴（必须） |
| 2 | `{name}_requirement_summary_v1.0.md` | `stageC_phase1.md` | 需求汇总 / 矛盾检测 |
| 3 | `{name}_solution_v1.0.md` | `stageC_phase2.md` | 方案 / 需求确认 |
| 4 | `{name}_ADR_v1.0.md` | `stageD.md` | ADR / 方案细化 |
| 5 | `{name}_trace_graph.yaml` | `stageE.md` | 追溯图 / 递归分解 |
| 6 | `{name}_todolist.md` | - | todolist（如有下级） |

**质量标准**：
- 需求汇总表：REQ 编号连续无跳号，每个 REQ 对应一个可验证功能点，优先级分级
- 方案文档：覆盖 §3~§14 所有章节，PPA 必须量化或标注"待综合验证"
- ADR：跳过的 D 子阶段必须标注原因+影响+替代方案
- 追溯图：节点数 = REQ 总数，每个节点有 title/ref/upstream/downstream
- 规格自检：每个子模块完成后执行 5 项自检（占位符/一致性/范围/模糊性/REQ覆盖度）

**目录结构示例**：
```
<module>_work/ds/doc/pr/
├── {module}_requirement_summary_v1.0.md    # 主模块需求汇总
├── {module}_solution_v1.0.md               # 主模块方案文档
├── {module}_ADR_v1.0.md                    # 主模块 ADR
├── {module}_trace_graph.yaml               # 主模块追溯图
├── submodule_A_work/ds/doc/pr/             # 子模块 A 工作目录
│   ├── submodule_A_pr_v1.0.md
│   ├── submodule_A_requirement_summary_v1.0.md
│   ├── submodule_A_solution_v1.0.md
│   ├── submodule_A_ADR_v1.0.md
│   └── submodule_A_trace_graph.yaml
├── submodule_B_work/ds/doc/pr/             # 子模块 B 工作目录
│   └── ... (同上 5 个文件)
└── e_stage_tree_todolist.md                # E 阶段树形 todolist
```

### 6.3 F 阶段触发条件

所有子模块的 D 阶段完成后，自动触发 F 阶段（顶层集成）。
