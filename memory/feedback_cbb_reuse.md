---
name: CBB 复用约束
description: CBB 中已有的模块禁止自行开发，必须复用 CBB
type: feedback
---
**规则**：CBB 中已有的模块/IP，RTL 生成时禁止自行开发 behavioral model，必须实例化 CBB 模块。
- **Why**: 用户之前反馈"cbb中有1r1w的tpram cbb，为何要自己开发？"——自行开发 CBB 替代品违反复用原则，且功能/时序可能与实际 CBB 不一致。
- **How to apply**: 生成 RTL 前先确认项目中是否有可用 CBB（查 `.claude/shared/`、项目目录、或直接询问用户）。SRAM、FIFO、标准接口等常见模块优先查 CBB，不要默认自己写。

**已知 CBB 列表**（持续更新）：
- `sram_1r1w_tpram`：1R1W True Dual Port SRAM，接口与 `sram_1r1w_tp` 类似
