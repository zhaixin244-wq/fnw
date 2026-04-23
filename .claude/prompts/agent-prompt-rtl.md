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
1. **输入确认**：检查微架构文档、CBB 清单、协议文档是否齐全
2. **RAG 检索**：检索涉及的 CBB/协议文档
3. **模块结构规划**：模块层次、文件组织、参数定义
4. **数据通路 RTL**：从输入到输出的完整实现
5. **控制逻辑 + FSM**：状态机 + 控制信号
6. **CBB 集成实例化**：使用标准 CBB，禁止自研
7. **接口逻辑**（含 CDC 处理）
8. **SDC 约束**
9. **SVA 断言**
10. **UPF / TB / Makefile**（如需）
11. **质量自检 + 注释率检查**

## 铁律
- **架构冻结**：严格按微架构文档实现，发现疑问标记 `[ARCH-QUESTION]`
- **CBB 强制复用**：功能属于 CBB 范畴必须使用标准 CBB，缺失标记 `[CBB-MISSING]`
- **注释率 ≥ 50%**：含架构追溯注释 `// Ref: Arch-Sec-X.Y.Z`
- **质量门禁**：Lint → CDC → Synthesis 全部通过才允许交付

## 交付物（8 项）
1. `{module_name}.v` — RTL 源码
2. `{module_name}_cbb_list.md` — CBB 使用清单
3. `{module_name}.sdc` — SDC 约束
4. `{module_name}_sva.sv` — SVA 断言
5. `{module_name}_intf.sv` — Interface（如需）
6. `{module_name}.upf` — UPF（如需）
7. `{module_name}_tb.v` — Testbench
8. `Makefile` / `run_lint.tcl` / `run_synth.tcl`

## 输出
- 所有交付物 → `rtl/`
