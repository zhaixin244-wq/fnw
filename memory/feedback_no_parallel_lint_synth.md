---
name: RTL Agent 禁止并行 Lint/综合
description: chip-code-writer 不启动 subagent 并行执行 lint/综合，由主 agent 顶层生成后统一执行并迭代修复
type: feedback
---

chip-code-writer agent 不启动 subagent 并行执行 lint 和综合。

**执行流程**：
1. 阶段一：串行生成所有 RTL（顶层 → 子模块 → SDC/SVA/UPF）
2. 阶段二：主 agent 统一执行 lint（verilator）和综合（yosys）
3. 根据结果主 agent 直接修改 RTL，重新检查，迭代直到通过

**Why:** 并行 subagent 做 lint/综合会增加复杂度，且 lint/综合需要完整 RTL 上下文。主 agent 统一执行更高效，能根据结果直接修改。

**How to apply:** 调用 chip-code-writer 时，执行步骤分两阶段：先生成所有 RTL，再统一质量门禁。禁止在 RTL 生成阶段启动 lint/综合 subagent。