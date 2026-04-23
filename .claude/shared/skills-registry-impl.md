# Skills 注册表 — RTL 实现专用（v2.0）

> chip-code-writer 使用的 Skills。流程阶段 Skill 由 impl-flow-stages.json 调度。
> **调用方式**：通过 `Skill` 工具调用。调用失败时按降级策略内化执行。

---

## 流程阶段 Skills（按执行顺序）

| Skill | 阶段 | 用途 | 调用时机 |
|-------|------|------|----------|
| `chip-impl-input-triage` | input_triage | 输入分类、缺失检测 | 激活后第一步 |
| `rag-query` | rag_retrieval | 检索 CBB/协议文档 | CBB/协议涉及时 |
| `chip-impl-module-structure` | module_structure | 端口提取、子模块划分、文件清单 | 输入确认后 |
| `chip-impl-rtl-coding` | rtl_impl | RTL 编码（数据通路+控制+CBB+接口） | 结构规划后 |
| `chip-impl-sdc-sva` | sdc_sva | SDC/SVA/TB 编写 | RTL 完成后 |
| `chip-impl-quality-gate` | quality_check | Lint+综合门禁+自愈循环 | SDC/SVA 完成后 |
| `chip-impl-self-check` | self_check | IC-01~39 + IM-01~08 自检 | 质量门禁通过后 |
| `chip-impl-delivery` | delivery | 交付物清单验证+打包 | 自检通过后 |

## 并行开发 Skills

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `chip-impl-parallel-dev` | 并行 subagent 调度+冲突检测 | 多模块开发时 |

## 通用 Skills

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `smart-explore` | AST 结构化分析已有代码 | 修改现有 RTL 时 |
| `verification-before-completion` | 逐项验证 | 每个子模块完成时 |

## 芯片专用 Skills（按需调用）

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `chip-cdc-architect` | CDC 信号表 + 同步策略 | 跨时钟域设计时 |
| `chip-low-power-architect` | Power Domain + Isolation + UPF | 低功耗设计时 |
| `chip-reliability-architect` | ECC/Parity/TMR + 老化裕量 | 可靠性设计时 |
| `chip-interface-contractor` | 精确接口契约 | 定义接口时 |
| `chip-rtl-guideline-generator` | 5 维编码规范 | 生成 RTL 实现指导时 |
| `chip-protocol-compliance-checker` | 协议合规逐条核对 | 检查总线接口合规性时 |
| `chip-traceability-linker` | RTM 需求追溯矩阵 | 编写 CBB 清单时 |
| `chip-lint-checker` | iverilog + yosys 三阶段 Lint | Lint 检查时 |
| `chip-synthesis-runner` | yosys 综合验证 + 面积估计 | 综合检查时 |

## 上下文管理 Skills

| Skill | 用途 | 调用时机 |
|-------|------|----------|
| `strategic-compact` | 逻辑阶段边界手动 compact | 长对话接近 context 上限时 |
| `code-tour` | 代码架构导览 | RTL 评审/理解已有设计时 |

---

## 降级策略

| 场景 | 行为 |
|------|------|
| Skill 调用失败 | 将该功能**内化执行**，输出中注明 "内化执行" |
| 知识库无相关文档 | 回退到 LLM 通用知识，标注来源缺失 |
