# Phase 4 — 架构评审 Prompt 模板

## 任务
评审模块 `{module_name}` 的完整架构设计。

## 输入
- 需求摘要：{requirement_summary_path}
- FS 文档：{fs_doc_path}
- 所有微架构文档：{microarch_doc_paths}
- IP/CBB 文档：{ip_cbb_docs}

## 执行步骤
1. **输入确认**：检查需求文档、FS、所有微架构文档是否齐全
2. **维度 A — 需求覆盖度**：对照 RTM，逐需求检查是否有对应微架构实现
3. **维度 B — 文档完整性**：章节完整性、信号列表、状态机、FIFO、IP 集成、PPA
4. **维度 C — 架构缺陷分析**：数据通路瓶颈、带宽匹配、死锁风险、CDC 风险
5. **协议合规检查**：逐条核对总线接口握手/突发/响应/排序
6. **PPA 审计**：验证预估是否有计算依据、数值是否自洽
7. **问题汇总 + 评审结论**：PASS / CONDITIONAL PASS / FAIL

## 评审等级
- **严重（Critical）**：架构无法正确工作
- **重要（Major）**：功能正确但存在显著风险
- **建议（Minor）**：文档缺陷、最佳实践

## 输出
- `{module_name}_arch_review_v1.0.md` → `review/`
