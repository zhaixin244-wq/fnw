# 文件修改权限规则

> 所有芯片架构 Agent 的文件修改权限隔离机制。

---

## 核心原则

1. **权限隔离**：每个 Agent 只能修改自己职责范围内的输出文件
2. **越权上报**：需要修改其他文件时，必须向 chip-project-lead（顾衡之）提出需求
3. **协调分配**：顾衡之负责分析需求合理性，再分配给对应的 Agent 执行
4. **影（Shadow）专属**：`.claude/` 目录仅影可修改，所有芯片 Agent 禁止触碰

---

## 影（Shadow）专属权限

> **铁律：`.claude/` 目录（含 agents/、rules/、shared/、wiki/、tools/）仅影（Shadow）可修改。所有芯片 Agent 无权修改 `.claude/` 下的任何文件。**

| 身份 | 允许修改的范围 | 说明 |
|------|---------------|------|
| **影（Shadow）** | `.claude/**`（全部）、`memory/**`（全部）、所有项目文件 | Jacky 的专属助手，唯一拥有 `.claude/` 修改权的身份 |
| 芯片 Agent（12个） | 仅限 `ds/`、`run/`、`dv/` 等项目输出目录 | 禁止修改 `.claude/` 和 `memory/` |

**触发场景**：当芯片 Agent 需要修改 `.claude/` 下的文件（如优化自身 Agent 定义、更新规则、修改模板）时，必须暂停并请求影来执行。

---

## 权限矩阵

| Agent | 角色 | 允许修改的文件范围 |
|-------|------|-------------------|
| chip-requirement-arch | 需求探索 | `ds/doc/pr/*requirement*`, `ds/doc/pr/*solution*`, `ds/doc/pr/*ADR*` |
| chip-fs-writer | FS 编写 | `ds/doc/fs/*.md`, `ds/doc/fs/tmp/*` |
| chip-microarch-writer | 微架构编写 | `ds/doc/ua/*.md`, `ds/doc/ua/tmp/*` |
| chip-code-writer | RTL 实现 | `ds/rtl/*.v`, `ds/rtl/*.sv`, `run/*`, `ds/report/lint/*`, `ds/report/syn/*` |
| chip-arch-reviewer | 架构评审 | `ds/report/*review*`, `ds/report/*check*` |
| chip-verfi-arch | 验证架构 | `ds/doc/va/*`, `ds/report/va/*` |
| chip-env-writer | 验证环境 | `ds/tb/*.v`, `ds/tb/*.sv`, `ds/tb/uvm/*` |
| chip-sta-analyst | 综合时序 | `ds/report/syn/*`, `ds/report/timing/*`, `run/*.sdc` |
| chip-top-integrator | 顶层集成 | `ds/rtl/*_top.v`, `ds/report/integration/*`, `ds/doc/ua/*connect*` |
| chip-lowpower-designer | 低功耗 | `ds/rtl/*.upf`, `ds/doc/ua/*power*`, `ds/report/power/*` |
| chip-dft-engineer | DFT 设计 | `ds/doc/ua/*dft*`, `ds/report/dft/*` |
| chip-project-lead | 项目管理 | `ds/doc/pr/*project*`, `ds/doc/pr/*risk*`, `ds/doc/pr/*progress*`, `ds/doc/pr/*gate*`（**协调者，可读所有文件**） |

---

## 越权处理流程

当 Agent 需要修改权限范围外的文件时：

```
1. 暂停当前操作
2. 输出越权请求：
   [CROSS-AGENT-REQUEST]
   请求者：{Agent 名称}
   目标文件：{需要修改的文件路径}
   修改原因：{为什么要修改}
   修改内容：{具体修改什么}
3. 等待顾衡之（chip-project-lead）审批
4. 顾衡之分析后：
   - 批准 → 分配给对应 Agent 执行
   - 拒绝 → 说明原因，请求者调整方案
```

**目标文件在 `.claude/` 下时**：顾衡之无权执行，需转交影（Shadow）执行修改。

---

## 顾衡之的协调职责

作为 chip-project-lead，顾衡之在权限协调中的角色：

1. **接收越权请求**：从任何 Agent 接收 `[CROSS-AGENT-REQUEST]`
2. **分析合理性**：判断修改是否必要、是否影响其他模块
3. **风险评估**：修改是否引入新的风险或依赖
4. **分配执行**：将批准的修改分配给对应的 Agent
5. **跟踪结果**：确认修改完成且符合预期

---

## 强制规则

- **禁止静默越权**：Agent 发现需要修改其他文件时，必须暂停并上报，禁止直接修改
- **禁止绕过协调**：不得通过任何方式绕过顾衡之的协调机制
- **保持职责边界**：即使技术上可以修改，也必须遵守权限规则
- **`.claude/` 专属权限**：所有芯片 Agent 禁止修改 `.claude/` 下的任何文件，仅影（Shadow）有权修改

---

## 例外情况

以下场景允许 Agent 直接修改，无需上报：

1. **读取任何文件**：所有 Agent 可以读取任何文件（只读）
2. **临时文件**：写入 `/tmp/` 或 `run/tmp/` 下的临时文件
3. **日志文件**：写入自己的日志文件

---

## 配置说明

本规则通过各 Agent 的 `includes` 字段加载，确保每次 Agent 激活时都读取到权限限制。
