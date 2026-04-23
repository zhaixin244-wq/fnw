# LLM Wiki Schema

> 本文件定义 wiki 的结构规范、命名约定和工作流程。所有 Agent 必须遵循本 schema 维护 wiki。

---

## 三层架构

| 层 | 路径 | 所有者 | 说明 |
|----|------|--------|------|
| **Raw Sources** | `.claude/knowledge/` | 人类 | 原始协议/CBB/IP 文档，不可变 |
| **Wiki** | `.claude/wiki/` | LLM | 结构化知识页面，LLM 维护 |
| **Schema** | 本文件 | 共同 | wiki 的规范和工作流 |

---

## Wiki 目录结构

```
.claude/wiki/
├── schema.md              # 本文件：wiki 规范
├── index.md               # 内容索引（按分类）
├── log.md                 # 时间线日志（append-only）
├── entities/              # 实体页面：每个协议/CBB/IP 一个页面
│   ├── axi4.md
│   ├── sync_fifo.md
│   └── ...
├── concepts/              # 概念页面：设计模式、方法论
│   ├── handshake-protocol.md
│   ├── cdc-strategy.md
│   └── ...
├── comparisons/           # 对比页面：选型对比表
│   ├── bus-protocol-selection.md
│   ├── cbb-arbiter-selection.md
│   └── ...
└── guides/                # 指南页面：集成指南、最佳实践
    ├── axi4-integration-guide.md
    ├── cdc-design-guide.md
    └── ...
```

---

## 页面类型与命名

| 类型 | 目录 | 命名规则 | 内容 |
|------|------|----------|------|
| **Entity** | `entities/` | `{name}.md`（小写，下划线） | 单个协议/CBB/IP 的结构化摘要 |
| **Concept** | `concepts/` | `{topic}.md`（小写，连字符） | 跨实体的设计概念/模式 |
| **Comparison** | `comparisons/` | `{domain}-selection.md` | 同类实体的选型对比 |
| **Guide** | `guides/` | `{topic}-guide.md` | 集成/使用指南 |

---

## Entity 页面模板

```markdown
# {实体名称}

> 一句话定位

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 协议/CBB/IP |
| 版本 | {版本} |
| 来源 | {raw source 路径} |

## 核心特性
- 特性 1
- 特性 2

## 接口/信号
| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|

## 关键参数
| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|

## 典型应用场景
- 场景 1：...

## 与其他实体的关系
- 与 {entity} 的关系：...

## 设计注意事项
- 注意 1

## 参考
- 原始文档：`{path}`
```

---

## 工作流

### Ingest（摄入新知识）

1. 新原始文档放入 `.claude/knowledge/{domain}/`
2. LLM 读取原始文档
3. 在 `entities/` 创建/更新 entity 页面
4. 更新 `index.md`（添加条目）
5. 更新相关 `comparisons/` 页面（如涉及选型）
6. 更新相关 `concepts/` 页面（如引入新概念）
7. 在 `log.md` 追加记录

### Query（查询知识）

1. 读取 `index.md` 定位相关页面
2. 读取具体 entity/concept/guide 页面
3. 如需深入，追溯到原始文档（`.claude/knowledge/`）
4. 有价值的查询结果可回写为新页面

### Lint（健康检查）

检查项：
- 孤儿页面（无入链）
- 过时信息（与原始文档矛盾）
- 缺失交叉引用
- 缺失概念页面
- index.md 与实际页面不一致

---

## 索引规则

`index.md` 是 wiki 的入口，必须：
- 按分类组织（实体/概念/对比/指南）
- 每个条目包含：链接、一行摘要、来源数
- 每次 ingest 后更新

---

## 检索优先级

| 优先级 | 操作 | 何时 |
|--------|------|------|
| 1 | 读 `index.md` | 每次查询开始 |
| 2 | 读具体 wiki 页面 | 定位到相关条目后 |
| 3 | 读原始文档 | wiki 信息不足时深入 |
| 4 | 回退 LLM | 知识库无覆盖时 |

---

## 回退规则

知识库无相关文档时，回退到 LLM 并**显式标注**："通用知识，未找到知识库文档"。

## 输出标注

- **设计/评审输出**：标注信息来源（wiki 页面名或原始文档名）
- **代码输出**：注释标注 `// CBB Ref: {wiki_page}` 或 `// CBB Ref: {原始文档}`
