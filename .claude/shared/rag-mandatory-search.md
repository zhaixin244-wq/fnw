# Wiki 知识检索协议

> **铁律：每次涉及协议/接口/CBB/选型/编码前，必须先完成检索。未完成检索不得输出任何设计内容、代码或评审意见。**

---

## 架构：三层知识系统

| 层 | 路径 | 说明 |
|----|------|------|
| **Wiki**（首选） | `.claude/wiki/` | LLM 预编译的结构化知识页面 |
| **Raw Sources**（深入） | `.claude/knowledge/` | 原始协议/CBB 文档 |
| **Schema** | `.claude/wiki/schema.md` | wiki 的规范和工作流 |

---

## 检索流程（3 阶段）

### 阶段 1：定位（读 index.md）

**每次检索必须从 `index.md` 开始。**

```
Read .claude/wiki/index.md
```

根据任务类型在索引中定位相关页面：

| 任务类型 | 索引区域 | 示例 |
|----------|----------|------|
| CBB 选型/集成 | §1.1 CBB 模块 | 需要 arbiter → 定位到 entities/arbiter.md |
| 协议选型/接口定义 | §1.2~1.4 协议 | 需要 AXI4 → 定位到 entities/axi4.md |
| 设计模式/方法论 | §2 概念页面 | CDC 设计 → concepts/cdc-strategy.md |
| 同类对比选型 | §3 对比页面 | 仲裁器选型 → comparisons/arbiter-selection.md |
| 集成最佳实践 | §4 指南页面 | AXI4 集成 → guides/axi4-integration-guide.md |

### 阶段 2：读取 Wiki 页面

读取阶段 1 定位到的 wiki 页面。Wiki 页面是**预编译的结构化知识**，包含：
- 核心特性摘要
- 接口/信号表
- 关键参数
- 典型应用场景
- 与其他实体的关系
- 设计注意事项

```
Read .claude/wiki/entities/{name}.md
```

### 阶段 3：深入原始文档（按需）

**仅当 wiki 页面信息不足时**，追溯到原始文档获取完整细节：

```
Read .claude/knowledge/{domain}/{name}.md
```

触发条件：
- 需要完整的信号时序图
- 需要详细的参数配置表
- wiki 页面标注"详见原始文档"
- 涉及实现细节（RTL 代码示例等）

---

## 检索策略（按任务阶段）

| 任务阶段 | 检索目标 | 优先级 |
|----------|----------|--------|
| **选型阶段** | index.md → comparisons/*.md → entities/*.md | Wiki 优先 |
| **接口定义阶段** | entities/{protocol}.md → 原始文档（如需时序细节） | Wiki + Raw |
| **CBB 集成阶段** | entities/{cbb}.md → guides/{cbb}-guide.md | Wiki 优先 |
| **编码阶段** | coding-style.md + entities/{cbb}.md | Wiki + Rules |
| **评审阶段** | entities/*.md + comparisons/*.md → 原始文档核对 | Wiki + Raw |

---

## 回退规则

| 情况 | 操作 |
|------|------|
| Wiki 页面存在 | 直接使用，标注来源 wiki 页面名 |
| Wiki 页面不存在但原始文档存在 | 读取原始文档，标注来源 |
| 两者都不存在 | 回退 LLM，标注"通用知识，未找到知识库文档" |

---

## 输出标注要求

- **设计/评审输出**：标注 `// Ref: wiki/{page}.md` 或 `// Ref: {原始文档路径}`
- **代码输出**：注释标注 `// CBB Ref: wiki/entities/{name}.md`
- **缺失标注**：`[WIKI-MISSING]` 或 `[CBB-MISSING]`

---

## Token 节约原则

1. **必须先读 index.md**，禁止无差别 Glob 全目录
2. **Wiki 页面优先**，仅在信息不足时读原始文档
3. **已读过的页面不重复读取**（同一对话内）
4. **对比页面已包含选型信息**，无需逐一读取实体页面

---

## Wiki 维护规则

当以下情况发生时，**必须更新 wiki**：

| 触发 | 更新内容 |
|------|----------|
| 新增原始文档 | 创建 entity 页面，更新 index.md，更新 comparisons/ |
| 发现 wiki 与原始文档矛盾 | 修正 wiki 页面 |
| 有价值的查询结果 | 回写为新页面（concept/guide/comparison） |
| 定期 lint | 检查孤儿页面、过时信息、缺失交叉引用 |

---

## 适用范围

所有芯片架构 Agent（chip-arch、chip-requirement-arch、chip-fs-writer、chip-microarch-writer、chip-code-writer、chip-arch-reviewer）。
