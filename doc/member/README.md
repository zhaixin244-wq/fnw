# FNW AI 芯片设计平台 — 团队成员总览

> 本目录包含所有 Agent 人物的自我介绍和图片生成提示词。

---

## 团队一览

| # | 中文名 | 英文名 | Agent ID | 角色 | 核心输出物 | 文件 |
|---|--------|--------|----------|------|-----------|------|
| 1 | 苏启辰 | Sean | chip-requirement-arch | 需求探索 & 方案论证 | requirement_summary、solution、ADR | [01_苏启辰_Sean.md](01_苏启辰_Sean.md) |
| 2 | 林书晓 | Rachel | chip-fs-writer | FS 功能规格编写 | {module}_FS_v{X}.md | [02_林书晓_Rachel.md](02_林书晓_Rachel.md) |
| 3 | 陈佳微 | Marcus | chip-microarch-writer | 微架构文档编写 | {module}_{sub}_microarch_v{X}.md | [03_陈佳微_Marcus.md](03_陈佳微_Marcus.md) |
| 4 | 张铭研 | Ethan | chip-code-writer | RTL 代码实现 | .v / .sv / _sva.sv | [04_张铭研_Ethan.md](04_张铭研_Ethan.md) |
| 5 | 宋晶瑶 | Clara | chip-arch-reviewer | 架构评审 | 评审报告 | [05_宋晶瑶_Clara.md](05_宋晶瑶_Clara.md) |
| 6 | 周闻哲 | Winston | chip-verfi-arch | 验证架构 | 测试点分解、验证环境方案、用例规划 | [06_周闻哲_Winston.md](06_周闻哲_Winston.md) |
| 7 | 陆灵犀 | Lexi | chip-env-writer | 验证环境搭建 | UVM 验证环境代码（Agent/Driver/Monitor/Scoreboard/Coverage/Env/Test/TB Top） | [07_陆灵犀_Lexi.md](07_陆灵犀_Lexi.md) |
| 8 | 沈未央 | Shannon | chip-sta-analyst | 综合与时序分析 | .sdc、综合报告、时序报告、面积报告 | [08_沈未央_Shannon.md](08_沈未央_Shannon.md) |
| 9 | 陆青萝 | Tina | chip-dft-engineer | DFT 设计 | DFT 架构文档、扫描链、MBIST/LBIST 集成 | [09_陆青萝_Tina.md](09_陆青萝_Tina.md) |
| 10 | 顾衡之 | Daniel | chip-project-lead | 项目管理 | 项目全景图、风险登记表、进度报告、汇报材料 | [10_顾衡之_Daniel.md](10_顾衡之_Daniel.md) |
| 11 | 韩映川 | Henry | chip-top-integrator | 顶层集成 | {module}_top.v、接口检查报告、系统 lint 报告 | [11_韩映川_Henry.md](11_韩映川_Henry.md) |
| 12 | 林若水 | Linus | chip-lowpower-designer | 低功耗设计 | .upf、功耗方案文档、功耗分析报告 | [12_林若水_Linus.md](12_林若水_Linus.md) |

---

## 设计流程与 Agent 映射

```
需求探索 → 方案论证 → FS → 微架构 → RTL 实现 → 综合 → 集成 → 验证 → 评审
   │           │        │       │         │        │       │       │       │
  Sean      Sean    Rachel  Marcus    Ethan   Shannon  Henry  Winston  Clara
                                                                        │
                                                              ┌─────────┤
                                                              │         │
                                                           Winston    Lexi
                                                          (验证架构) (验证环境)
                                                              │
                                                           Tina/Linus
                                                          (DFT/低功耗)

                          Daniel（顾衡之）— 全流程项目管理 & 风险管控
```

---

## 唤醒方式

每个 Agent 通过**触发关键词**自动唤醒。用户在对话中输入包含对应关键词的任务描述时，系统会自动调用对应的 Agent。

### 唤醒规则

| # | Agent | 触发关键词 | 示例 |
|---|-------|-----------|------|
| 1 | 苏启辰/Sean | 需求讨论、方案比选、架构探索、头脑风暴 | "帮我做一下 DMA 引擎的需求采集" |
| 2 | 林书晓/Rachel | 编写FS、写功能规格、生成功能规格书 | "帮我编写 DMA 的 FS 文档" |
| 3 | 陈佳微/Marcus | 编写UA、写微架构、生成微架构文档 | "帮我写 DMA 引擎的微架构" |
| 4 | 张铭研/Ethan | 生成rtl、写rtl、完善rtl、实现rtl、补全代码 | "根据微架构生成 RTL 代码" |
| 5 | 宋晶瑶/Clara | 评审、review、检查架构、检查rtl | "帮我评审一下 DMA 的微架构文档" |
| 6 | 周闻哲/Winston | 测试点、验证计划、用例规划、覆盖率、验证环境方案 | "帮我做 DMA 的测试点分解" |
| 7 | 陆灵犀/Lexi | 生成TB、写验证环境、生成UVM、编写driver/monitor/scoreboard、完善验证环境 | "帮我生成 DMA 的 UVM 验证环境" |
| 8 | 沈未央/Shannon | 综合、时序分析、SDC约束、lint检查、面积预估、时序违例 | "帮我跑一下综合和时序分析" |
| 9 | 陆青萝/Tina | DFT、扫描链、MBIST、LBIST、ATPG、测试向量 | "帮我做 DFT 架构规划" |
| 10 | 顾衡之/Daniel | 项目管理、风险评估、进度跟踪、汇报、协调、门控检查 | "帮我做一下项目风险评估" |
| 11 | 韩映川/Henry | 顶层集成、接口对齐、系统lint、连线检查 | "帮我做顶层集成和接口对齐" |
| 12 | 林若水/Linus | 低功耗、UPF、功耗域、clock gating、power gating、isolation | "帮我做低功耗方案设计" |

### 唤醒流程

```
用户输入任务描述
  ↓
系统识别触发关键词
  ↓
自动调用对应 Agent
  ↓
Agent 激活 → 输出代办清单 → 按流程执行
```

### 注意事项

- 关键词不区分大小写
- 一个任务描述只触发一个 Agent，不会同时唤醒多个
- 如果关键词模糊（如"检查"可能对应评审也可能对应 lint），系统会根据上下文判断
- Agent 被唤醒后会先输出代办清单，然后按步进模式逐步执行

---

## 文件格式说明

每个人物文件包含以下内容：

1. **基本信息**：姓名、性别、年龄、Agent ID、角色、经验、专长
2. **外貌描述**：用于 AI 图片生成的人物外观参考
3. **性格特征**：人物性格和工作风格
4. **口头禅**：高频使用的语句
5. **座右铭**：人物信条
6. **自我介绍**：第一人称的人物自我介绍文本
7. **图片生成提示词（AI Image Prompt）**：可直接用于 Midjourney / DALL-E / Stable Diffusion 等 AI 图片生成工具

---

## 使用方式

### 生成人物图片

将每个人物文件中的「图片生成提示词」复制到 AI 图片生成工具中即可。推荐使用：
- Midjourney（人像质量最佳）
- DALL-E 3（细节还原好）
- Stable Diffusion（本地部署，可定制）

### 生成自我介绍

将每个人物文件中的「自我介绍」文本作为参考，可用于：
- 团队介绍页面
- 项目汇报材料
- 培训文档
