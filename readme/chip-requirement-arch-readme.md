# chip-requirement-arch

> 芯片需求探索 & 方案论证 Agent。从模糊需求收敛到可执行规格，支持多方案比选（trade-off）、约束收敛、DSE。

---

## 1. 概述

| 字段 | 内容 |
|------|------|
| **Agent 名称** | `chip-requirement-arch` |
| **版本** | v6 |
| **定位** | 芯片/模块需求采集、约束收敛、方案比选 |
| **核心模型** | sonnet |
| **测试评分** | 9.3/10（6 场景 40 检查点全通过） |

### 核心能力

- 需求探索：从一句话模糊需求到完整约束规格
- 约束检查：9 维度逐项确认，含执行提示（execution_hint）
- 矛盾检测：5 条自动检测规则，工艺/频率/面积/功耗交叉校验
- 方案设计：2-3 个候选方案，Mermaid 架构框图 + PPA 量化 + 对比表
- 变更处理：变更日志 + 重走流程 + 版本管理

### 铁律

```
需求采集：NO ARCHITECTURE OUTPUT WITHOUT SIGNED REQUIREMENTS
方案设计：NO PPA CLAIMS WITHOUT QUANTITATIVE EVIDENCE
```

---

## 2. 架构设计

### 2.1 JSON+Skill 架构

Agent 采用"流程驱动 + 数据外部化"架构，核心仅 84 行，结构化数据全部存储在 JSON 文件中按需加载。

```
.claude/agents/
  chip-requirement-arch.md    ← Agent 核心定义（84行，流程驱动器）

.claude/shared/
  requirement-template.json   ← 流程定义（stage/路径/规则/输出格式）
  requirement-checklist.json  ← 约束检查清单（9项 + 推断映射 + 规则）
  conflict-detection-rules.json ← 矛盾检测规则（5条 + reference_values）
  solution-template.json      ← 方案设计模板（对比表 + 推荐格式）
  todo-mechanism.md           ← 代办清单门控机制
  skills-registry.md          ← Skills 调用注册表
  rag-mandatory-search.md     ← RAG 检索规范（includes 启动注入）
```

### 2.2 数据加载策略

| 类型 | 加载方式 | 时机 |
|------|----------|------|
| `rag-mandatory-search.md` | includes 启动注入 | Agent 激活时自动加载 |
| `todo-mechanism.md` | Read 按需 | 启动后第一步 |
| `requirement-template.json` | Read 按需 | 启动时获取流程定义 |
| `requirement-checklist.json` | Read 按需 | 阶段 B 开始时 |
| `conflict-detection-rules.json` | Read 按需 | 阶段 C-0 时 |
| `solution-template.json` | Read 按需 | 方案设计时 |

### 2.3 流程概览

```
用户输入
  │
  ▼
代办清单（Read todo-mechanism.md）
  │
  ▼
input_triage（分类：complete / partial / vague）
  │
  ▼
stage0 ──→ stageA ──→ stageB ──→ stageC0 ──→ stageC
 探略       4问确认    9项约束     矛盾检测     汇总确认
  │                                           │
  │          ┌─────────────────────────────────┘
  │          ▼
  │     方案设计（Read solution-template.json）
  │          │
  │          ▼
  └──→ ADR 记录
```

---

## 3. 使用方法

### 3.1 激活方式

在 Claude Code 中通过 subagent 调用：

```
Agent({
  subagent_type: "general-purpose",
  description: "需求探索",
  prompt: "你是 chip_requirement_arch，芯片需求探索专家。按以下流程执行：..."
})
```

或直接在对话中描述芯片/模块需求，Claude Code 会自动匹配 Agent。

### 3.2 输入类型

| 类型 | 触发条件 | 流程路径 |
|------|----------|----------|
| **完整需求** | 独立文档/超 500 字结构化描述且含 ≥6 项约束维度 | stage0 → A → B 核对 → C0 → C |
| **部分需求** | 2-5 项约束维度的具体数值 | stage0 → A → B 补齐 → C0 → C |
| **模糊需求** | 仅模块名或一句话功能描述 | stage0 → A → B 全部 → C0 → C |

### 3.3 输入示例

**完整需求示例**：
> AXI4-Lite CRC 校验模块，28nm 工艺，200MHz，64bit 数据位宽，延迟 ≤5cycles，面积 ≤30kGates，功耗 ≤10mW

**模糊需求示例**：
> 帮我做一个 DMA 模块

**部分需求示例**：
> 28nm 工艺，200MHz，AXI4-Lite 接口，数据速率和延迟不确定

---

## 4. 流程详解

### 4.1 代办清单（启动门控）

Agent 激活后第一步必须输出代办清单，获得用户确认后才继续执行。支持两种模式：

| 模式 | 适用场景 | 行为 |
|------|----------|------|
| **步进模式** | 方案比选、架构探索、首次接触模块 | 每步暂停等待确认 |
| **连续模式** | 路径清晰、有模板、纯文档编写 | 组内连续执行，组间暂停 |

**强制暂停点**（两种模式均适用）：方案选择、输入缺失、架构疑问、范围变更。

### 4.2 stage0 — 前置探索

| 项目 | 说明 |
|------|------|
| **目的** | 定性探索模块定位、核心功能、关键约束、初步架构方向 |
| **深度** | 中等。2-3 个澄清提问，不做定量 PPA 分析 |
| **输出** | 探索结论表 + 待确认项 |

### 4.3 stageA — 最小信息集

按序确认 4 个核心问题：

| # | 问题 | 映射到 |
|---|------|--------|
| 1 | 模块在 SoC 中的位置？上下游模块？ | stageB REQ-002 |
| 2 | 核心功能一句话描述？ | stageB REQ-003 |
| 3 | PPA 优先级排序？（性能/功耗/面积） | stageB REQ-004/005 |
| 4 | 阶段 0 探索结论是否需要调整？ | stageB/方案设计 |

### 4.4 stageB — 约束检查清单

逐项确认 9 个约束维度：

| REQ | 约束项 | 分类 | 执行策略 |
|-----|--------|------|----------|
| REQ-001 | 工艺与频率 | independent | 直接询问 |
| REQ-002 | 接口协议 | infer_from_position | 按位置推断 + 确认 |
| REQ-003 | 数据流特征 | partial_coverage | 追问遗漏项 |
| REQ-004 | 延迟与吞吐 | priority_dependent | 按优先级分级追问 |
| REQ-005 | 面积与功耗 | priority_dependent | 按优先级分级追问 |
| REQ-006 | 时钟与复位 | independent | 直接询问 |
| REQ-007 | 低功耗 | independent | 直接询问 |
| REQ-008 | DFT/可靠性 | independent | 直接询问 |
| REQ-009 | 其他约束 | independent | 兜底项 |

**追问分级规则**（基于 stageA PPA 优先级）：

| stageA 状态 | stageB 行为 |
|-------------|-------------|
| 选为最高优先级 | 必须追问具体数值 |
| 未选但也未说不关心 | 询问预算参考值，无则用行业默认值 |
| 明确说不关心 | 直接用行业默认值，标注"用户未指定" |

### 4.5 stageC0 — 矛盾检测

自动执行 5 项检测：

| 编号 | 检测项 | 涉及 REQ | 逻辑 |
|------|--------|----------|------|
| CD-001 | 频率 vs 工艺节点 | REQ-001 | 目标频率是否超出工艺典型 Fmax |
| CD-002 | 延迟 vs 频率 | REQ-001 + REQ-004 | 延迟 cycles 是否与功能复杂度匹配 |
| CD-003 | 面积 vs 功能复杂度 | REQ-002 + REQ-005 | 接口/功能数量是否超出面积预算 |
| CD-004 | 功耗 vs 工艺/频率 | REQ-001 + REQ-005 | 功耗预算是否合理 |
| CD-005 | 低功耗 vs DFT | REQ-007 + REQ-008 | 功耗域划分与扫描链约束是否冲突 |

检测到矛盾时输出调和方案（≥2 个），由用户选择。

### 4.6 stageC — 需求确认汇总

输出完整汇总表（REQ-001 ~ REQ-NNN），等待用户确认。确认规则：

| 类型 | 示例 | 判定 |
|------|------|------|
| 明确确认 | "确认"、"正确"、"OK" | ✅ 确认 |
| 附带转折 | "好的，但是..." | ❌ 追问转折项 |
| 犹豫确认 | "嗯...好吧" | ❌ 再确认一次 |
| 部分确认 | "大部分没问题，XX有点疑问" | ❌ 追问疑问项 |

### 4.7 方案设计

确认后进入方案设计，按 `solution-template.json` 执行：

1. 确定方案数量（2-3 个）
2. 每个方案包含：架构框图（Mermaid）+ PPA 预估 + 需求覆盖 + 风险点 + 接口假设
3. 输出对比表（延迟/面积/功耗/复杂度/风险/适用场景）
4. 推荐方案，理由必须回溯到具体 REQ

**Skill 调用**：

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `chip-design-space-explorer` | 多方案 DSE | 方案生成阶段 |
| `chip-ppa-formatter` | 结构化 PPA 表 | PPA 预估输出时 |
| `architecture-decision-records` | Nygard ADR 文档 | 用户选择方案后 |
| `rag-query` | 协议/CBB 检索 | 协议选型时 |

调用失败时内化执行，注明"内化执行"。

### 4.8 变更处理

任何阶段用户变更约束时：

1. 记录变更日志（版本/变更项/原值/新值/原因）
2. 重走变更项 stageB
3. 重新输出 stageC 汇总表
4. 重新确认
5. 如已在方案设计阶段，确认后重新生成方案

---

## 5. 与其他 Agent 的协作

| 上游 Agent | 输出给本 Agent | 本 Agent 输出给下游 |
|-----------|---------------|-------------------|
| — | 用户原始需求 | 需求确认汇总表 |
| — | — | 候选方案 + 对比表 |
| — | — | ADR 文档 |

**下游可对接的 Agent**：

| Agent | 输入 |
|-------|------|
| `chip-fs-writer` | 需求确认汇总表 → 功能规格书 |
| `chip-arch` | 候选方案 → 微架构设计 |
| `chip-code-writer` | 微架构文档 → RTL 实现 |

---

## 6. 测试报告

完整测试报告见 `agent_test_report/chip-requirement-arch.md`。

| 场景 | 输入类型 | 检查点 | 判定 |
|------|----------|--------|------|
| 场景 1 | 完整需求（AXI4-Lite CRC） | 11/11 | PASS |
| 场景 2 | 模糊需求（"DMA模块"） | 2/2 | PASS |
| 场景 3 | 部分需求+不确定 | 10/10 | PASS |
| 场景 4 | 需求矛盾场景 | 9/9 | PASS |
| 场景 5 | 变更处理 | 5/5 | PASS |
| 场景 6 | 犹豫确认 | 3/3 | PASS |
| **总计** | - | **40/40** | **ALL PASS** |

---

## 7. 文件清单

| 文件 | 行数 | 用途 |
|------|------|------|
| `.claude/agents/chip-requirement-arch.md` | 84 | Agent 核心定义 |
| `.claude/shared/requirement-template.json` | 175 | 流程定义 |
| `.claude/shared/requirement-checklist.json` | 140 | 约束检查清单 |
| `.claude/shared/conflict-detection-rules.json` | 84 | 矛盾检测规则 |
| `.claude/shared/solution-template.json` | 50 | 方案设计模板 |
| `.claude/shared/todo-mechanism.md` | ~110 | 代办清单门控机制 |
| `.claude/shared/skills-registry.md` | ~82 | Skills 调用注册表 |
| `.claude/shared/rag-mandatory-search.md` | ~60 | RAG 检索规范 |
