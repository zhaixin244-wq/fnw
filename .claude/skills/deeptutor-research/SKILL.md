---
name: deeptutor-research
description: "通过 DeepTutor CLI 进行体系化知识研究。触发词：'DeepTutor 研究'、'深度研究'、'知识库检索'、'RAG 检索'、'deeptutor search'、'deeptutor research'。封装 kb create/add、deep_research、kb search、deep_solve、chat 等 CLI 调用，输出结构化 JSON。"
---

# DeepTutor Research

## 任务

通过 DeepTutor CLI 进行体系化知识研究，包括知识库管理、深度研究、细节检索、问题求解。所有输出为结构化 JSON，供 wiki-compiler 等 Agent 消费。

## 前置条件

| 条件 | 检测方式 | 说明 |
|------|----------|------|
| DeepTutor 已部署 | 调用 `deeptutor-setup` Skill | CLI 可用 + API key 已配置 |
| 知识库已创建 | `deeptutor kb list` | 首次使用需创建 |

## CLI 路径

```
.claude/tools/DeepTutor/deeptutor.bat
```

所有命令加 `-f json` 获取结构化输出。

## 操作集

### 1. 知识库管理

#### 1.1 列出知识库

```bash
.claude/tools/DeepTutor/deeptutor.bat kb list -f json
```

#### 1.2 创建知识库

```bash
.claude/tools/DeepTutor/deeptutor.bat kb create {kb_name} --doc {file1} --doc {file2} -f json
```

- **命名规范**：`chip-{主题小写}`，如 `chip-axi4stream`、`chip-chi`
- **支持格式**：PDF、Markdown、TXT
- **可重复执行**：已存在时会报错，需先检查

#### 1.3 添加文档（增量）

```bash
.claude/tools/DeepTutor/deeptutor.bat kb add {kb_name} --doc {new_file} -f json
```

#### 1.4 删除知识库

```bash
.claude/tools/DeepTutor/deeptutor.bat kb delete {kb_name} --force -f json
```

### 2. 深度研究（核心能力）

对一个主题进行多 Agent 协作研究，输出带引用的结构化报告。

```bash
.claude/tools/DeepTutor/deeptutor.bat run deep_research "{研究主题描述}" --kb {kb_name} -f json
```

**参数说明**：

| 参数 | 必填 | 说明 |
|------|------|------|
| 研究主题 | 是 | 自然语言描述，越具体越好 |
| --kb | 否 | 指定知识库，不指定则用默认 |
| -t | 否 | 启用工具：`rag`、`web_search`、`paper_search`、`reason` |
| -f json | 是 | 结构化输出 |

**使用示例**：

```bash
# 基于知识库研究
.claude/tools/DeepTutor/deeptutor.bat run deep_research \
  "CHI 协议 Snoop Filter 设计策略，包括目录式和广播式对比" \
  --kb chip-chi -f json

# 启用多工具研究
.claude/tools/DeepTutor/deeptutor.bat run deep_research \
  "PCIe Gen5/Gen6 链路训练与均衡策略" \
  -t rag -t web_search -t paper_search -f json
```

**输出处理**：

提取 JSON 结果中的：
- `findings` → 核心发现，用于 entity 页面的"核心特性"
- `sources` → 引用来源，用于页面"参考"章节
- `subtopics` → 子主题，用于决定是否需要额外页面

### 3. 知识库检索（细节补充）

针对具体问题进行语义搜索。

```bash
.claude/tools/DeepTutor/deeptutor.bat kb search {kb_name} "{查询内容}" -f json
```

**使用示例**：

```bash
.claude/tools/DeepTutor/deeptutor.bat kb search chip-chi \
  "Retry mechanism and P-Credit flow control" -f json

.claude/tools/DeepTutor/deeptutor.bat kb search chip-axi4 \
  "write data channel handshake timing" -f json
```

**输出处理**：

提取 JSON 结果中的：
- `results[].content` → 检索到的文本片段
- `results[].source` → 来源文档
- `results[].score` → 相似度分数

### 4. 深度解题（复杂问题）

多步推理解决复杂技术问题。

```bash
.claude/tools/DeepTutor/deeptutor.bat run deep_solve "{问题描述}" -t reason -f json
```

**使用示例**：

```bash
# FIFO 深度计算
.claude/tools/DeepTutor/deeptutor.bat run deep_solve \
  "Calculate FIFO depth: burst=16 beats, producer rate=1 beat/2cycles, consumer rate=1 beat/3cycles, feedback latency=5 cycles. Include 50% margin." \
  -t reason -f json

# 时序裕量分析
.claude/tools/DeepTutor/deeptutor.bat run deep_solve \
  "Analyze timing slack for a 2-stage pipeline at 500MHz with Tcq=0.15ns, Tsetup=0.05ns, stage1 logic=0.8ns, stage2 logic=0.6ns" \
  -t reason -f json
```

### 5. 基于知识库的问答

```bash
.claude/tools/DeepTutor/deeptutor.bat run chat "{问题}" --kb {kb_name} -t rag -f json
```

## 执行流程

当 Agent 调用此 Skill 时，按以下流程执行：

```
输入：研究主题 + 参考文档（可选）
  │
  ├─ 1. 检查 DeepTutor 部署状态
  │   └─ 调用 deeptutor-setup（如未部署）
  │
  ├─ 2. 知识库准备
  │   ├─ 检查是否有对应知识库
  │   ├─ 无 → 创建知识库（如有参考文档）
  │   └─ 有 → 检查是否需要更新
  │
  ├─ 3. 深度研究
  │   ├─ deep_research 主题级研究
  │   └─ kb search 细节补充（按需）
  │
  └─ 4. 结果整理
      ├─ 提取核心发现
      ├─ 提取引用来源
      └─ 输出结构化笔记
```

## 结果输出格式

Skill 执行后输出结构化笔记，格式如下：

```markdown
## DeepTutor 研究结果：{主题}

### 研究概要
- **知识库**：{kb_name}
- **研究命令**：{deeptutor 命令}
- **执行状态**：✅ 成功 / ⚠️ 部分成功 / ❌ 失败

### 核心发现

| # | 发现 | 来源 | 可信度 |
|---|------|------|--------|
| 1 | {发现内容} | {来源文档} | High/Medium/Low |
| 2 | {发现内容} | {来源文档} | High/Medium/Low |

### 关键参数/信号

| 参数/信号 | 值 | 说明 | 来源 |
|-----------|-----|------|------|
| {name} | {value} | {说明} | {来源} |

### 引用来源

| # | 来源 | 类型 | 引用内容摘要 |
|---|------|------|-------------|
| 1 | {文档名} | RAG/Web/Paper | {摘要} |

### 待补充/待验证

| 项目 | 说明 |
|------|------|
| {项目} | {原因} |
```

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| CLI 不可用 | `deeptutor --help` 失败 | 自动调用 `deeptutor-setup` 部署 |
| API key 未配置 | `.env` 含占位符 | 提示用户配置，降级为 LLM 知识 |
| 知识库创建失败 | 文件不存在/格式不支持 | 跳过知识库，用纯 LLM 研究 |
| deep_research 超时 | > 120s 无响应 | 降级为 kb search + LLM 推理 |
| JSON 解析失败 | 输出格式异常 | 用正则提取关键信息，标注解析错误 |
| 知识库已存在 | `kb create` 报错 | 改用 `kb add` 添加新文档 |

## 降级策略

```
DeepTutor 完全可用
  → deep_research + kb search + deep_solve

DeepTutor CLI 可用但 API key 未配置
  → 提示配置 key，降级为 LLM 知识编译

DeepTutor CLI 不可用
  → 降级为 LLM 自身知识，标注"基于通用知识"
```

## 使用示例

```
Agent：调用 Skill("deeptutor-research", args="CHI 协议 Snoop Filter 设计")

# Skill 输出：
## DeepTutor 研究结果：CHI Snoop Filter

### 研究概要
- **知识库**：chip-chi
- **研究命令**：deeptutor run deep_research "CHI Snoop Filter" --kb chip-chi -f json
- **执行状态**：✅ 成功

### 核心发现
| # | 发现 | 来源 |
|---|------|------|
| 1 | Snoop Filter 用 SRAM 记录地址→RN 映射，减少无效 Snoop | CHI Spec Issue C |
| 2 | 目录式 SF 查找延迟 1 周期，广播式无需查找但带宽开销大 | CHI Spec Issue C |
| 3 | CHI-D 支持 SF 与 HN 分离部署，提升扩展性 | CHI Spec Issue D |
...
```
