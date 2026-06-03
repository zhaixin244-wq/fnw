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

## 执行规则
1. 遵循 chip-requirement-arch 完整流程
2. 输出所有交付物到 {work_dir}
3. 使用标准阶段标记（[STAGE-START]、[STAGE-END] 等）
4. 生成规范的 REQ 编号（REQ-001~REQ-XXX）
5. 每个 stage 完成后记录到 PR 文件

## 交付物要求
- flow/{module}_pr_v1.0.md: PR 沟通记录
- outputs/{module}_requirement_summary_v1.0.md: 需求汇总表
- outputs/{module}_solution_v1.0.md: 方案文档
- outputs/{module}_ADR_v1.0.md: 架构决策记录
- outputs/{module}_trace_graph.yaml: 追溯图

## 注意事项
- 这是调试模式，专注于流程执行
- 不需要调用外部 Skill（如 wiki-query、search-first）
- 直接基于上下文信息执行
- 如果信息不足，向用户追问
```

---

### 4. 对话循环

**循环逻辑**：
```python
对话历史 = []
轮数 = 0
最大轮数 = scenario.max_dialog_rounds
完成 = False

while (not 完成) and (轮数 < 最大轮数):
    # 苏启辰 Agent 回复
    sean_reply = 调用苏启辰 Agent(
        prompt=f"对话历史:\n{格式化对话历史}\n\n请继续执行需求探索流程。",
        agent_name="debug-sean-agent"
    )
    记录(sean_reply, "sean", 轮数)
    对话历史.append({"role": "sean", "content": sean_reply})

    # 检查是否完成
    if "stageD" 完成标记 in sean_reply:
        完成 = True
        break

    # 用户 Agent 回复
    user_reply = 调用用户 Agent(
        prompt=f"对话历史:\n{格式化对话历史}\n\n请根据角色定义和场景生成回复。",
        agent_name="debug-user-agent"
    )
    记录(user_reply, "user", 轮数)
    对话历史.append({"role": "user", "content": user_reply})

    轮数 += 1

    # 超时检查
    if 当前时间 - start_time > scenario.timeout_minutes * 60:
        break
```

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
/debug chip-requirement-arch basic_dma
```

### 示例 2: 运行模糊输入场景
```
/debug chip-requirement-arch vague_input
```

### 示例 3: 运行所有场景
```
/debug chip-requirement-arch all
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
/debug chip-requirement-arch all --parallel
```

### 4. CI/CD 集成
将调试模式集成到 CI 流程，自动验证 Agent 更新。
