---
name: RTL Agent 不生成 Testbench
description: chip-code-writer agent 交付物不含 tb 文件，验证用 tb 由验证团队独立编写
type: feedback
---

chip-code-writer agent 不生成 `{module_name}_tb.v`（Testbench）。

**Why:** Testbench 属于验证范畴，应由验证团队根据验证计划独立编写，RTL 实现 Agent 不负责。

**How to apply:** 调用 chip-code-writer agent 时，交付物清单排除 `_tb.v`，执行步骤中移除 TB 相关项。