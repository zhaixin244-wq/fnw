# Phase 5 — RTL 代码实现 Prompt 模板

## 任务
根据微架构文档为模块 `{module_name}` 实现 RTL 代码。

## 输入
- 微架构文档：{microarch_doc_path}
- 编码规范：`.claude/rules/coding-style.md`
- CBB 文档：{cbb_docs}
- 接口协议：{protocol_specs}
- 关键约束：频率={freq}, 复位={reset}, DFT={dft}

## 执行步骤

### 阶段一：RTL 生成（串行执行，不启动 subagent）
1. **输入确认**：检查微架构文档、CBB 清单、协议文档是否齐全
2. **RAG 检索**：检索涉及的 CBB/协议文档
3. **模块结构规划**：模块层次、文件组织、参数定义
4. **顶层模块生成**：先生成 `{module_name}_top.v`，确定子模块划分和接口
5. **子模块 RTL 逐个生成**：按依赖顺序逐个生成子模块 RTL
6. **CBB 集成实例化**：使用标准 CBB，禁止自研
7. **接口逻辑**（含 CDC 处理）
8. **SDC 约束**
9. **SVA 断言**
10. **UPF / Makefile**（如需）
11. **注释率自检**：确保 ≥ 50%

### 阶段二：统一质量门禁（主 agent 执行，不启动 subagent）
12. **统一 Lint 检查**：对所有生成的 RTL 文件执行 `verilator --lint-only -Wall`
13. **统一综合检查**：对顶层执行 `yosys` 综合，检查是否有综合错误
14. **问题修复迭代**：根据 lint/综合结果，主 agent 直接修改 RTL，然后重新检查
15. **门禁通过确认**：Lint 和综合全部通过后，输出最终交付物

## 铁律
- **架构冻结**：严格按微架构文档实现，发现疑问标记 `[ARCH-QUESTION]`
- **CBB 强制复用**：功能属于 CBB 范畴必须使用标准 CBB，缺失标记 `[CBB-MISSING]`
- **注释率 ≥ 50%**：含架构追溯注释 `// Ref: Arch-Sec-X.Y.Z`
- **质量门禁**：Lint + Synthesis 全部通过才允许交付
- **禁止并行 subagent**：Lint 和综合由主 agent 在顶层生成完成后统一执行，不启动 subagent 并行
- **迭代修复**：Lint/综合报错后，主 agent 直接修改 RTL，重新检查，直到通过

## 交付物（7 项）
1. `{module_name}.v` — RTL 源码
2. `{module_name}_cbb_list.md` — CBB 使用清单
3. `{module_name}.sdc` — SDC 约束
4. `{module_name}_sva.sv` — SVA 断言
5. `{module_name}_intf.sv` — Interface（如需）
6. `{module_name}.upf` — UPF（如需）
7. `Makefile` / `run_lint.tcl` / `run_synth.tcl`

> **注意**：Testbench（`_tb.v`）由验证团队独立编写，RTL Agent 不生成。

## 输出
- 所有交付物 → `rtl/`
