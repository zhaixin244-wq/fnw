---
name: 叫名字必须调用 Agent
description: 用户叫任意 Agent 小名时，必须通过 Agent 工具调用对应 subagent，禁止主会话直接执行
type: feedback
---
叫名字时必须调用对应 Agent，不能主会话直接干活。

**Why：** 2026-04-23 发现，用户叫 agent 名字写 RTL 时，主会话直接编写代码，绕过了 chip-code-writer 的 8 stage 流程、quality-checklist 自检、Lint/Synthesis 门禁。结果产生大量编码规范违反（位宽不匹配、未驱动信号、未使用信号、端口遗漏等），需要事后手动修复。

**How to apply：**
1. 用户消息中出现任意 Agent 小名（小几/小成/小微/芯研/晶瑶/闻哲/灵犀/衡之/未央/映川/若水/青萝）或对应全称/英文名时，立即调用 `Agent(subagent_type=对应类型)`
2. 即使用户说"继续执行"、"优化一下"等看似简单的指令，只要涉及 Agent 职责范围，就必须调用 Agent
3. 主会话只做：接收用户请求 → 调用 Agent → 汇总 Agent 结果 → 呈现给用户
4. 主会话不做：直接编写 RTL、直接写微架构文档、直接写 FS 文档、直接做需求分析
