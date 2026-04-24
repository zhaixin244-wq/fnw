---
name: wiki-query
description: 从 LLM Wiki 知识库查询协议/CBB/架构信息。基于预编译的结构化知识页面，比传统 RAG 更高效。
version: 2.0.0
model: sonnet
triggers:
  - /wiki-query
  - /rag-query
  - wiki query
  - 查询wiki
  - 查找协议
  - 查找CBB
---

# Wiki Query — LLM Wiki 结构化知识检索

基于 LLM Wiki 系统的结构化知识检索。Wiki 是预编译的知识页面集合，存储在 `.claude/wiki/` 目录。

## 检索流程

### Step 1：读取索引

```bash
Read .claude/wiki/index.md
```

在索引中定位相关条目（实体/概念/对比/指南）。

### Step 2：读取 Wiki 页面

```bash
Read .claude/wiki/{category}/{name}.md
```

Wiki 页面包含预编译的结构化知识：核心特性、接口信号、关键参数、应用场景、设计注意事项。

### Step 3：深入原始文档（按需）

仅当 wiki 信息不足时：

```bash
Read .claude/knowledge/{domain}/{name}.md
```

## 查询模式

| 模式 | 命令示例 | 说明 |
|------|----------|------|
| **实体查询** | `/wiki-query AXI4` | 读取 entities/axi4.md |
| **选型对比** | `/wiki-query 仲裁器选型` | 读取 comparisons/arbiter-selection.md |
| **概念查询** | `/wiki-query CDC 策略` | 读取 concepts/cdc-strategy.md |
| **指南查询** | `/wiki-query AXI4 集成` | 读取 guides/axi4-integration-guide.md |

## 快速定位表

| 关键词 | Wiki 页面路径 |
|--------|--------------|
| AXI4 / AXI / 总线 | entities/axi4.md |
| APB / 外设总线 | entities/apb.md |
| SPI / I2C / UART | entities/spi.md / i2c.md / uart.md |
| PCIe / USB / MIPI | entities/pcie.md / usb.md / mipi.md |
| FIFO / 同步FIFO | entities/sync_fifo.md |
| 异步FIFO / CDC | entities/async_fifo.md |
| 仲裁器 / arbiter | entities/arbiter.md |
| 交叉开关 / crossbar | entities/crossbar.md |
| 选型 / 对比 | comparisons/*.md |
| 设计模式 / 概念 | concepts/*.md |
| 集成指南 | guides/*.md |

## 响应格式

- 摘要而非原始内容
- 标注信息来源（wiki 页面名或原始文档路径）
- 过时信息标记（wiki 页面 >30 天未更新）
- 无结果时明确说明，不编造

## Token 节约原则

1. **必须先读 index.md**，禁止无差别 Glob 全目录
2. **Wiki 页面优先**，仅在信息不足时读原始文档
3. **已读过的页面不重复读取**（同一对话内）
4. **对比页面已包含选型信息**，无需逐一读取实体页面

## Wiki 维护

当查询产生有价值的结果时，考虑回写为新 wiki 页面：
- 新的对比分析 → comparisons/
- 新的设计概念 → concepts/
- 新的集成经验 → guides/
