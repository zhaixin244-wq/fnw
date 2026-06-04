# chip-requirement-arch 调试运行器

> 本脚本协调双 Agent 对话，验证需求探索流程与质量。

---

## 调试流程

### 1. 初始化阶段

**输入参数**：
- `scenario_id`: 测试场景 ID（如 `basic_dma`）
- `scenario_config`: 场景配置 JSON 文件路径
- `user_persona`: 用户角色 JSON 文件路径

**执行步骤**：
1. 读取场景配置文件
2. 读取用户角色配置文件
3. 创建调试工作目录：
   ```
   .claude/debug/chip-requirement-arch/debug_output/{scenario_id}_{timestamp}/
   ├── outputs/
   └── flow/
   ```
4. 生成调试会话 ID
5. 记录调试开始时间

**输出**：
- `debug_session_id`: 调试会话 ID
- `work_dir`: 调试工作目录路径
- `start_time`: 调试开始时间

---

### 2. 启动用户 Agent

**Agent 配置**：
```
subagent_type: general-purpose
name: debug-user-agent
mode: default
```

**System Prompt**：
```
你是用户角色模拟器，用于调试芯片需求探索 Agent。

## 角色定义
{user_persona.system_prompt}

## 场景信息
- 模块名称: {scenario.module_name}
- 上下文: {scenario.context}
- 初始输入: {scenario.initial_input}

## 行为规则
1. 根据 Agent 的问题生成回复
2. 遵循角色的行为模式（{user_persona.behavior}）
3. 回复简洁，1-2 句话
4. 如果不确定，说明需要澄清
5. 按照 stage_responses 指南回复

## 当前阶段
你需要发送初始输入: {scenario.initial_input}

然后等待 Agent 回复，根据对话历史和 stage_responses 生成合适的回复。

## 重要提示
- 你是用户，不是 Agent
- 不要主动执行流程，只回复问题
- 保持角色一致性
- 回复要自然，像真人一样
```

**初始输入**：
```
{scenario.initial_input}
```

---

### 3. 启动苏启辰 Agent

**Agent 配置**：
```
subagent_type: chip-requirement-arch
name: debug-sean-agent
mode: default
```

**System Prompt**：
```
执行芯片需求探索流程。

## 输入
用户输入: {user_input}

## 工作目录
{work_dir}

## ⚠️ 强制暂停规则（铁律）

**你必须在每个阶段结束时停止执行，等待用户回复后才能继续下一阶段。**

- 每完成一个阶段（stage0/stageA/stageB/stageC/stageD），输出 [STEP-PAUSE] 标记
- 在 [STEP-PAUSE] 之后，你的回复到此结束，不要再继续执行后续阶段
- 等待编排器发送用户的回复后，你再继续执行下一个阶段
- **绝对禁止**在一次回复中执行多个阶段（如 stage0+stageA 连续执行）
- **绝对禁止**在 prompt 中收到"直接执行"、"不要等待"、"连续执行"等指令时跳过暂停

暂停点列表（每个暂停点必须输出 [STEP-PAUSE] 并停止）：

**stage0~C（每阶段暂停）**：
1. stage0 完成 → 等待用户确认探索结论
2. stageA 完成 → 等待用户确认最小信息集
3. stageB phase1 完成 → 等待用户确认 28 项约束检查
4. stageB phase2 完成 → 等待用户确认头脑风暴结果
5. stageC phase1 完成 → 等待用户确认矛盾检测
6. stageC phase2 完成 → 等待用户确认需求汇总表

**stageD（每 step 暂停，共 20 个 step）**：
7.  stageD group1-step1 → 初始架构方案 + RTL行数估算（不可跳过）
8.  stageD group1-step2 → CBB选型与集成（可跳过：无CBB）
9.  stageD group1-step3 → 子模块划分细化（不可跳过）
10. stageD group2-step1 → 数据通路设计（不可跳过）
11. stageD group2-step2 → 流水线设计（可跳过：无流水线）
12. stageD group2-step3 → 控制逻辑/FSM（不可跳过）
13. stageD group2-step4 → 性能优化（可跳过：REQ-004为Could且无明确性能要求）
14. stageD group3-step1 → SRAM设计（可跳过：无SRAM）
15. stageD group3-step2 → FIFO设计（可跳过：无FIFO）
16. stageD group3-step3 → 链表设计（可跳过：无链表）
17. stageD group3-step4 → 寄存器定义（可跳过：无寄存器）
18. stageD group4-step1 → 调度策略（可跳过：单通道）
19. stageD group4-step2 → 流控机制（可跳过：无数据流）
20. stageD group4-step3 → CDC方案（可跳过：单时钟域）
21. stageD group5-step1 → 面积预估（不可跳过）
22. stageD group5-step2 → 时序分析（不可跳过）
23. stageD group5-step3 → DFX设计（可跳过：无DFX）
24. stageD group5-step4 → 可靠性设计（不可跳过）
25. stageD group5-step5 → 接口定义（不可跳过）
26. stageD group5-step6 → 功耗设计（可跳过：无低功耗）

**stageE/F**：
27. stageE 每个子模块递归分解完成 → 等待用户确认
28. stageF 完成 → [STAGE-END]，流程结束

**跳过规则**：可跳过的 step 需用户明确确认跳过原因后标注「跳过：{原因}」，然后继续下一个 step。

## 执行规则
1. 遵循 chip-requirement-arch 完整流程
2. **每次只执行一个阶段**，完成后暂停等待
3. 输出所有交付物到 {work_dir}
4. 使用标准阶段标记（[STAGE-START]、[STAGE-END]、[STEP-PAUSE]）
5. **阶段标记必须写入 PR 文件（flow/{module}_pr_v1.0.md）**
6. 生成规范的 REQ 编号（REQ-001~REQ-XXX）
7. 需求汇总表必须包含 schema_version 字段

## 交付物要求

### 流文件（flow/ 目录）— 每个阶段独立文件

| 文件 | 内容 |
|------|------|
| flow/{module}_pr_v1.0.md | PR 索引文件（进度跟踪 + 各阶段文件链接） |
| flow/stage0.md | stage0 模块定位探索完整对话 |
| flow/stageA.md | stageA 最小信息集完整对话 |
| flow/stageB_phase1.md | stageB phase1 约束检查完整对话 |
| flow/stageB_phase2.md | stageB phase2 头脑风暴完整对话 |
| flow/stageC_phase1.md | stageC phase1 矛盾检测完整对话 |
| flow/stageC_phase2.md | stageC phase2 需求汇总完整对话 |
| flow/stageD_group1_step1.md | 初始架构方案 + RTL 行数估算 |
| flow/stageD_group1_step2.md | CBB 选型与集成 |
| flow/stageD_group1_step3.md | 子模块划分细化 |
| flow/stageD_group2_step1.md | 数据通路设计 |
| flow/stageD_group2_step2.md | 流水线设计 |
| flow/stageD_group2_step3.md | 控制逻辑/FSM |
| flow/stageD_group2_step4.md | 性能优化 |
| flow/stageD_group3_step1.md | SRAM 设计 |
| flow/stageD_group3_step2.md | FIFO 设计 |
| flow/stageD_group3_step3.md | 链表设计 |
| flow/stageD_group3_step4.md | 寄存器定义 |
| flow/stageD_group4_step1.md | 调度策略 |
| flow/stageD_group4_step2.md | 流控机制 |
| flow/stageD_group4_step3.md | CDC 方案 |
| flow/stageD_group5_step1.md | 面积预估 |
| flow/stageD_group5_step2.md | 时序分析 |
| flow/stageD_group5_step3.md | DFX 设计 |
| flow/stageD_group5_step4.md | 可靠性设计 |
| flow/stageD_group5_step5.md | 接口定义 |
| flow/stageD_group5_step6.md | 功耗设计 |
| flow/stageE.md | stageE 递归分解完整对话 |
| flow/stageF.md | stageF 顶层集成完整对话 |

### 标准交付物（outputs/ 目录）

| 文件 | 路径 |
|------|------|
| 需求汇总表 | outputs/{module}_requirement_summary_v1.0.md |
| 方案文档 | outputs/{module}_solution_v1.0.md |
| ADR 文档 | outputs/{module}_ADR_v1.0.md |
| 追溯图 | outputs/{module}_trace_graph.yaml |

## ⚠️ 流文件生成规则（强制）

每个阶段完成后必须将完整对话写入对应流文件：

| 阶段 | 流文件 | 写入时机 |
|------|--------|----------|
| stage0 | flow/stage0.md | [STEP-PAUSE] 输出前 |
| stageA | flow/stageA.md | [STEP-PAUSE] 输出前 |
| stageB phase1 | flow/stageB_phase1.md | [STEP-PAUSE] 输出前 |
| stageB phase2 | flow/stageB_phase2.md | [STEP-PAUSE] 输出前 |
| stageC phase1 | flow/stageC_phase1.md | [STEP-PAUSE] 输出前 |
| stageC phase2 | flow/stageC_phase2.md | [STEP-PAUSE] 输出前 |
| stageD group1-step1 | flow/stageD_group1_step1.md | [STEP-PAUSE] 输出前 |
| stageD group1-step2 | flow/stageD_group1_step2.md | [STEP-PAUSE] 输出前 |
| stageD group1-step3 | flow/stageD_group1_step3.md | [STEP-PAUSE] 输出前 |
| stageD group2-step1 | flow/stageD_group2_step1.md | [STEP-PAUSE] 输出前 |
| stageD group2-step2 | flow/stageD_group2_step2.md | [STEP-PAUSE] 输出前 |
| stageD group2-step3 | flow/stageD_group2_step3.md | [STEP-PAUSE] 输出前 |
| stageD group2-step4 | flow/stageD_group2_step4.md | [STEP-PAUSE] 输出前 |
| stageD group3-step1 | flow/stageD_group3_step1.md | [STEP-PAUSE] 输出前 |
| stageD group3-step2 | flow/stageD_group3_step2.md | [STEP-PAUSE] 输出前 |
| stageD group3-step3 | flow/stageD_group3_step3.md | [STEP-PAUSE] 输出前 |
| stageD group3-step4 | flow/stageD_group3_step4.md | [STEP-PAUSE] 输出前 |
| stageD group4-step1 | flow/stageD_group4_step1.md | [STEP-PAUSE] 输出前 |
| stageD group4-step2 | flow/stageD_group4_step2.md | [STEP-PAUSE] 输出前 |
| stageD group4-step3 | flow/stageD_group4_step3.md | [STEP-PAUSE] 输出前 |
| stageD group5-step1 | flow/stageD_group5_step1.md | [STEP-PAUSE] 输出前 |
| stageD group5-step2 | flow/stageD_group5_step2.md | [STEP-PAUSE] 输出前 |
| stageD group5-step3 | flow/stageD_group5_step3.md | [STEP-PAUSE] 输出前 |
| stageD group5-step4 | flow/stageD_group5_step4.md | [STEP-PAUSE] 输出前 |
| stageD group5-step5 | flow/stageD_group5_step5.md | [STEP-PAUSE] 输出前 |
| stageD group5-step6 | flow/stageD_group5_step6.md | [STEP-PAUSE] 输出前 |
| stageE | flow/stageE.md | [STEP-PAUSE] 输出前 |
| stageF | flow/stageF.md | [STAGE-END] 输出前 |

**流文件内容要求**：
- 必须包含完整的用户-Agent 对话记录（每轮问答）
- 必须包含阶段标记（[STAGE-START] / [STEP-PAUSE] / [STAGE-END]）
- 必须包含阶段结论摘要
- 禁止仅记录结论而省略对话过程

## ⚠️ 交付物生成规则（强制）

每个阶段完成后必须生成对应的交付物文件到 outputs/ 目录：

| 阶段 | 交付物 | 路径 |
|------|--------|------|
| stageC phase2 完成后 | 需求汇总表 | outputs/{module}_requirement_summary_v1.0.md |
| stageC phase2 完成后 | 追溯图 | outputs/{module}_trace_graph.yaml |
| stageD 完成后 | 方案文档 | outputs/{module}_solution_v1.0.md |
| stageD 完成后 | ADR 文档 | outputs/{module}_ADR_v1.0.md |

**禁止**：仅生成 PR 文件而跳过标准交付物。outputs/ 目录必须包含上述文件，否则视为流程不完整。
- outputs/{module}_trace_graph.yaml: 追溯图

## 注意事项
- 这是调试模式，专注于流程执行
- 不需要调用外部 Skill（如 wiki-query、search-first）
- 直接基于上下文信息执行
- 如果信息不足，向用户追问
- **每次回复只完成一个阶段，然后暂停**
```

---

### 4. 对话循环（双 Agent 交互模式）

**核心原则**：两个独立 subagent 通过编排器（主会话）交替通信，每个 agent 每次只执行一步。

**Agent 启动方式**：
```
Agent 1: subagent_type=chip-requirement-arch, run_in_background=true, name=debug-sean-agent
Agent 2: subagent_type=general-purpose,              run_in_background=true, name=debug-user-agent
```

**循环逻辑**：
```python
对话历史 = []
轮数 = 0
最大轮数 = scenario.max_dialog_rounds
完成 = False

# 第 0 轮：用户 Agent 发送初始输入
user_reply = scenario.initial_input
对话历史.append({"role": "user", "content": user_reply})

while (not 完成) and (轮数 < 最大轮数):
    # ── Step A: 发送用户回复给苏启辰 Agent ──
    # 用 SendMessage(agent_id, message=user_reply) 发送
    # 苏启辰 Agent 收到后执行一个阶段，输出 [STEP-PAUSE] 或 [STAGE-END]
    # 等待苏启辰 Agent 返回（用 TaskOutput block=true）

    sean_reply = 等待苏启辰 Agent 回复
    记录(sean_reply, "sean", 轮数)
    对话历史.append({"role": "sean", "content": sean_reply})

    # ── Step B: 检查是否完成 ──
    if "[STAGE-END]" in sean_reply:
        完成 = True
        break

    # ── Step C: 发送苏启辰回复给用户 Agent ──
    # 用 SendMessage(agent_id, message=sean_reply) 发送
    # 用户 Agent 收到后根据角色定义生成回复
    # 等待用户 Agent 返回（用 TaskOutput block=true）

    user_reply = 等待用户 Agent 回复
    记录(user_reply, "user", 轮数)
    对话历史.append({"role": "user", "content": user_reply})

    轮数 += 1

    # ── 超时检查 ──
    if 当前时间 - start_time > scenario.timeout_minutes * 60:
        break
```

**⚠️ 关键约束**：
1. 编排器（主会话）**禁止代替**任何 agent 生成回复
2. 编排器**禁止**把多个用户回复打包发送给苏启辰 Agent
3. 每次 SendMessage 只传递**一轮**对话内容
4. 苏启辰 Agent 的回复必须包含 `[STEP-PAUSE]` 或 `[STAGE-END]`，否则视为异常

**对话记录格式**：
```markdown
## 轮 {N}

**苏启辰 Agent**:
{sean_reply}

**用户 Agent**:
{user_reply}

---
```

---

### 5. 质量评估

**评估检查项**：

#### 5.1 流程完整性检查
```bash
# 检查阶段标记
grep -c "[STAGE-START]" {work_dir}/flow/*_pr_v1.0.md
grep -c "[STAGE-END]" {work_dir}/flow/*_pr_v1.0.md

# 检查阶段完成数
stages_completed = 统计完成的阶段数
```

#### 5.2 交付物检查
```bash
# 检查文件存在性
ls {work_dir}/outputs/*_requirement_summary_v1.0.md
ls {work_dir}/outputs/*_solution_v1.0.md
ls {work_dir}/outputs/*_ADR_v1.0.md
ls {work_dir}/outputs/*_trace_graph.yaml

# 检查文件大小
wc -l {work_dir}/outputs/*.md
```

#### 5.3 REQ 编号检查
```bash
# 检查 REQ 编号连续性
grep -oP "REQ-\d+" {work_dir}/outputs/*_requirement_summary_v1.0.md | sort -t- -k2 -n

# 检查 REQ 编号唯一性
grep -oP "REQ-\d+" {work_dir}/outputs/*_requirement_summary_v1.0.md | sort | uniq -d
```

#### 5.4 阶段标记检查
```bash
# 检查标记格式
grep -c "\[STAGE-START\]" {work_dir}/flow/*_pr_v1.0.md
grep -c "\[STAGE-END\]" {work_dir}/flow/*_pr_v1.0.md
grep -c "\[PHASE-START\]" {work_dir}/flow/*_pr_v1.0.md
grep -c "\[PHASE-END\]" {work_dir}/flow/*_pr_v1.0.md
```

#### 5.5 门控检查
```bash
# 门控 1: 流程完整性
G_01 = 检查 stageB phase1 完成率 >= 70%
G_02 = 检查 stageB phase2 已执行
G_03 = 检查 stageC phase1 已执行
G_04 = 检查 stageC phase2 已执行
G_05 = 检查 stageD 已执行

# 门控 2: 文档质量
G_10 = 检查 REQ 编号连续
G_11 = 检查汇总表含 schema_version
G_12 = 检查方案文档章节完整
```

**评估标准**：
- 复用 `.claude/evaluation_criteria/chip-requirement-arch-eva.md`

---

### 6. 生成报告

**报告文件**：

#### 6.1 对话记录 (dialog.md)
```markdown
# {scenario_name} 对话记录

> 调试时间：{timestamp}
> 场景：{scenario_id}
> 用户角色：{user_persona}
> 对话轮数：{dialog_rounds}
> 耗时：{duration}

---

{完整对话记录}

---

## 统计信息

| 统计项 | 数值 |
|--------|------|
| 总轮数 | {rounds} |
| Agent 回复平均长度 | {avg_length} |
| 用户追问次数 | {follow_ups} |
| 阶段切换次数 | {stage_switches} |
```

#### 6.2 评估报告 (evaluation.md)
```markdown
# {scenario_name} 评估报告

> 评估时间：{timestamp}
> 场景：{scenario_id}
> 用户角色：{user_persona}
> 对话轮数：{dialog_rounds}

---

## §0 门控检查结果

| # | 门控条件 | 结果 | 说明 |
|---|----------|------|------|
| G-01 | stageB phase1 >= 70% | PASS/FAIL | {N}/28 |
| G-02 | stageB phase2 已执行 | PASS/FAIL | {detail} |
| ... | ... | ... | ... |

**门控结论**: {PASS/FAIL}

---

## §1 流程检查

| 阶段 | 状态 | 标记正确 | 交付物 |
|------|------|----------|--------|
| stage0 | ✅/❌ | ✅/❌ | ✅/❌ |
| stageA | ✅/❌ | ✅/❌ | ✅/❌ |
| ... | ... | ... | ... |

---

## §2 质量评估

| 维度 | 得分 | 满分 | 说明 |
|------|------|------|------|
| 流程完整性 | {score} | {max} | {detail} |
| REQ 编号规范 | {score} | {max} | {detail} |
| 交付物质量 | {score} | {max} | {detail} |
| **总分** | **{total}** | **{max}** | |

**等级**: {S/A/B/C/D}

---

## §3 问题与建议

### 发现的问题
1. {problem_1}
2. {problem_2}

### 优化建议
1. {suggestion_1}
2. {suggestion_2}
```

#### 6.3 调试摘要 (summary.md)
```markdown
# {scenario_name} 调试摘要

> 调试时间：{timestamp}
> 场景：{scenario_id}
> 用户角色：{user_persona}

---

## 结果概览

| 指标 | 结果 |
|------|------|
| 完成状态 | {completed/timeout/incomplete} |
| 完成阶段数 | {stages_completed}/{expected_stages} |
| 生成 REQ 数 | {req_count} |
| 交付物完整度 | {deliverables_complete}/{deliverables_expected} |
| 对话轮数 | {dialog_rounds} |
| 耗时 | {duration} |

---

## 评估结果

| 维度 | 得分 |
|------|------|
| 流程完整性 | {score}/100 |
| REQ 编号规范 | {score}/100 |
| 交付物质量 | {score}/100 |
| **总分** | **{total}/100** |

**等级**: {S/A/B/C/D}

---

## 关键发现

1. {finding_1}
2. {finding_2}
3. {finding_3}

---

## 文件清单

- 对话记录: dialog.md
- 评估报告: evaluation.md
- 调试摘要: summary.md
- 交付物目录: outputs/
```

---

### 7. 输出结果

**最终输出**：
```
调试完成！

场景: {scenario_id}
状态: {completed/timeout/incomplete}
轮数: {dialog_rounds}
耗时: {duration}

报告位置:
- 对话记录: {work_dir}/dialog.md
- 评估报告: {work_dir}/evaluation.md
- 调试摘要: {work_dir}/summary.md

评估结果:
- 总分: {total}/100
- 等级: {S/A/B/C/D}
```

---

## 使用示例

### 示例 1: 运行基础 DMA 场景
```
/test-chip-requirement-arch basic_dma
```

### 示例 2: 运行模糊输入场景
```
/test-chip-requirement-arch vague_input
```

### 示例 3: 运行所有场景
```
/test-chip-requirement-arch all
```

---

## 错误处理

### 超时处理
```
if 当前时间 - start_time > scenario.timeout_minutes * 60:
    记录超时状态
    生成部分报告
    输出超时警告
```

### Agent 错误处理
```
if Agent 调用失败:
    记录错误信息
    重试 3 次
    如果仍然失败，记录错误并继续
```

### 交付物缺失处理
```
if 交付物缺失:
    记录缺失文件
    在评估报告中标注
    继续评估其他部分
```

---

## 扩展点

### 1. 自定义场景
用户可以创建自己的场景配置文件，放在 `scenarios/` 目录下。

### 2. 自定义角色
用户可以创建自己的用户角色配置文件，放在 `user-personas/` 目录下。

### 3. 并行调试
支持同时运行多个场景：
```
/test-chip-requirement-arch all --parallel
```

### 4. CI/CD 集成
将调试模式集成到 CI 流程，自动验证 Agent 更新。
