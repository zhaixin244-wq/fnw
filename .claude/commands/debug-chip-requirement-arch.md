# 调试 chip-requirement-arch

调试芯片需求探索 Agent 的流程与质量。通过双 Agent 自动对话验证流程完整性。

## 用法

```
/debug chip-requirement-arch [scenario_id]
```

## 可用场景

| 场景 ID | 名称 | 描述 | 用户角色 |
|---------|------|------|----------|
| `basic_dma` | 基础 DMA | 标准流程测试 | clear_expert |
| `complex_pcie` | 复杂 PCIe | 高级场景测试 | clear_expert |
| `vague_input` | 模糊输入 | 边界测试 | vague_beginner |
| `edge_cases` | 边界条件 | 异常处理测试 | challenging_reviewer |

## 执行流程

1. **初始化**：读取场景配置和用户角色
2. **启动对话**：用户 Agent 发送初始输入
3. **循环执行**：双 Agent 交替对话直到完成
4. **质量评估**：检查流程完整性和交付物质量
5. **生成报告**：输出对话记录和评估报告

## 输出位置

```
.claude/debug/chip-requirement-arch/debug_output/{scenario}_{timestamp}/
├── dialog.md           # 完整对话记录
├── evaluation.md       # 质量评估报告
├── summary.md          # 调试摘要
└── outputs/            # 生成的交付物
```

## 示例

```bash
# 运行基础 DMA 场景
/debug chip-requirement-arch basic_dma

# 运行模糊输入场景
/debug chip-requirement-arch vague_input
```

## 评估标准

复用 `.claude/evaluation_criteria/chip-requirement-arch-eva.md` 中的评估标准。

---

## 执行指令

当用户调用此命令时，执行以下步骤：

### 1. 解析参数
```
scenario_id = $1 (默认: basic_dma)
```

### 2. 加载配置
```
场景配置: .claude/debug/chip-requirement-arch/scenarios/{scenario_id}.json
用户角色: .claude/debug/chip-requirement-arch/user-personas/{user_persona}.json
```

### 3. 创建调试会话
```
timestamp = 当前时间戳
work_dir = .claude/debug/chip-requirement-arch/debug_output/{scenario_id}_{timestamp}
mkdir -p {work_dir}/outputs
mkdir -p {work_dir}/flow
```

### 4. 启动双 Agent 对话

使用 Agent 工具启动两个 subagent：

**用户 Agent**：
```
subagent_type: general-purpose
name: debug-user-agent
prompt: |
  你是用户角色模拟器。

  ## 角色定义
  {user_persona.system_prompt}

  ## 场景信息
  模块名称: {scenario.module_name}
  上下文: {scenario.context}

  ## 行为规则
  - 根据 Agent 的问题生成回复
  - 遵循角色的行为模式
  - 回复简洁，1-2 句话
  - 如果不确定，说明需要澄清

  ## 当前任务
  发送初始输入: {scenario.initial_input}

  等待 Agent 回复后，根据场景和角色生成合适的回复。
```

**苏启辰 Agent**：
```
subagent_type: chip-requirement-arch
name: debug-sean-agent
prompt: |
  执行需求探索流程。

  ## 输入
  用户输入: {user_input}

  ## 工作目录
  {work_dir}

  ## 执行规则
  - 遵循 chip-requirement-arch 完整流程
  - 输出所有交付物到 {work_dir}
  - 使用标准阶段标记
  - 生成规范的 REQ 编号
```

### 5. 对话循环

```
对话历史 = []
轮数 = 0
最大轮数 = {scenario.max_dialog_rounds}

while (未完成 && 轮数 < 最大轮数):
    # 苏启辰 Agent 回复
    sean_reply = 调用苏启辰 Agent(对话历史)
    记录 sean_reply 到对话历史

    # 用户 Agent 回复
    user_reply = 调用用户 Agent(对话历史)
    记录 user_reply 到对话历史

    轮数 += 1

    # 检查是否完成
    if 包含 "stageD" 完成标记:
        完成 = true
```

### 6. 质量评估

```
检查项:
- 流程完整性（门控检查）
- 交付物存在性
- REQ 编号规范
- 阶段标记正确性

评估标准:
- 复用 .claude/evaluation_criteria/chip-requirement-arch-eva.md
```

### 7. 生成报告

使用报告模板生成：
- `dialog.md`: 完整对话记录
- `evaluation.md`: 质量评估报告
- `summary.md`: 调试摘要

### 8. 输出结果

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
```
