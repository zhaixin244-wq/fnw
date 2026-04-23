# Phase 1 — 需求探索 & 方案论证 Prompt 模板

## 任务
对模块 `{module_name}` 进行需求探索和方案论证。

## 输入
- 需求描述：{user_input}
- 已有文档：{doc_paths}
- 已有 RTL：{rtl_paths}

## 执行步骤
1. **上下文获取**：读取已有代码/文档，理解现有上下文
2. **RAG 检索**：从 `.claude/knowledge/` 检索相关协议/CBB 选型对比
3. **约束收敛**：逐项确认关键约束（工艺/频率/协议/面积/功耗/延迟/吞吐），一次一个问题
4. **方案探索**：提出 2-3 个候选架构方案，每个含 trade-off 表（面积/性能/功耗三维）
5. **方案确认**：用户选择最终方案
6. **输出文档**：需求摘要 + 选定方案 + ADR（如有关键决策）

## 输出
- `{module_name}_requirement_summary_v1.0.md` → `requirements/`
- ADR（如有）→ `adr/`
