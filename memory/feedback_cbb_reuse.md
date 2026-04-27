---
name: CBB 复用约束（含例外确认流程）
description: CBB 优先复用；不满足时逐项与用户确认，确认后可自研独立模块文件
type: feedback
---
**规则**：CBB 中已有的模块优先复用，禁止默认自研。CBB 无法满足需求时，逐项与用户确认差异，确认后可自研类 CBB 模块。
- **Why**: 用户之前反馈"cbb中有1r1w的tpram cbb，为何要自己开发？"——自行开发 CBB 替代品违反复用原则，且功能/时序可能与实际 CBB 不一致。但实际项目中存在 CBB 无法满足的场景（如非 2^n 深度 FIFO、双源分配链表），需要允许例外。
- **How to apply**:
  1. 生成 RTL 前先查 CBB（Wiki 检索 entities/{cbb}.md）
  2. CBB 完全满足 → 直接复用
  3. CBB 部分满足 → 逐项输出差异表，每条差异单独询问用户确认
  4. 用户确认需自研 → 生成独立文件 `{top_module}_{cbb_type}_custom.v`，标注 `[CBB-CUSTOM]`
  5. 自研模块必须通过 Lint 检查

**已知 CBB 列表**（持续更新）：
- `sram_1r1w_tpram`：1R1W True Dual Port SRAM，接口与 `sram_1r1w_tp` 类似

**已确认自研案例**（供参考）：
- `data_adpt_input_if_mod.v` 中的 48 项 free list：CBB linked_list_free 不支持双源分配+组合输出，用户已确认自研
- `data_adpt_output_if_mod.v` 中的 1800 行 free list + 48 deep ready_q：CBB 不支持批量回收+非 2^n 深度
