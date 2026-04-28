---
name: chip-cbb-exception-confirm
description: "Use when standard CBB cannot fully meet requirements and user confirmation is needed. Triggers on 'CBB例外', 'CBB差异', '复用还是自研', 'CBB exception', 'CBB confirm'. Lists differences item by item and confirms reuse vs custom development with user."
---

# CBB 例外确认 Skill

## 任务
当标准 CBB 与需求存在差异时，逐项与用户确认，决定是否接受 CBB 能力或自研替代。

## 触发条件
Wiki 检索 CBB → 找到候选 → 对比需求 vs CBB 能力 → CBB 部分满足时触发。

## 输入
- `cbb_name`: CBB 名称
- `cbb_spec`: CBB 能力规格（来自 Wiki）
- `requirement`: 需求要求

## 执行步骤

1. **差异识别**：逐项对比 CBB spec vs 需求，输出差异表：

| # | 对比项 | CBB 能力 | 需求要求 | 差异描述 | 影响 |
|---|--------|----------|----------|----------|------|
| 1 | {参数} | {CBB值} | {需求值} | {差异} | {功能/性能/面积影响} |

2. **逐项确认**：每条差异单独询问用户：
```
[CBB-DIFF-CONFIRM]
CBB：{cbb_name}
差异项 #N：{对比项}
CBB 能力：{CBB值}
需求要求：{需求值}
影响：{影响描述}

请确认：
1. 是否可接受 CBB 的能力？（接受 → 使用 CBB，放弃该需求项）
2. 还是需要自研替代？（自研 → 进入 Step 3）
```

3. **自研类 CBB 模块**：用户确认需自研后，按以下规则生成：

| 规则 | 说明 |
|------|------|
| **独立文件** | 单独一个 `.v` 文件，不混入主模块 |
| **独立 module** | 文件内只有一个 module，命名 `{top_module}_{cbb_type}_custom.v` |
| **接口对齐 CBB** | 尽量保持与 CBB 相同的接口风格，便于后续替换 |
| **标注来源** | 文件头标注 `// [CBB-CUSTOM] 替代 CBB: {cbb_name}，原因: {差异摘要}` |
| **注释 CBB Ref** | `// CBB Ref: wiki/entities/{cbb_name}.md（不满足，已自研替代）` |
| **纳入 filelist** | 自动加入 `run/{module}.f` 文件列表 |
| **Lint 覆盖** | 自研模块必须通过 Lint 检查 |

## 输出
- `decision`: 每条差异的用户决策（accept/custom）
- `custom_files`: 自研模块文件路径列表（如有）
- `cbb_list_updated`: 更新后的 CBB 清单

## Gate
所有差异项均已确认，无待定项。

## 使用示例

**示例 1**：
- 用户：「标准 sync_fifo CBB 深度只支持 16，我需要 32，怎么办」
- 行为：输出差异表（CBB 深度 16 vs 需求 32），逐项询问用户是否接受 CBB 或自研，用户选择自研后生成 `{module}_sync_fifo_custom.v`

**示例 2**：
- 用户：「arbiter CBB 不支持 WRR 策略，帮我确认是否需要自研」
- 行为：对比 CBB（Fixed/RR）vs 需求（WRR），列出差异影响，等待用户逐项确认决策

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| CBB 文档缺失 | Wiki 检索无结果 | 暂停，提示用户确认 CBB 名称或提供文档 |
| 差异项过多 | 超过 5 条差异 | 先确认影响最大的 3 条，其余批量确认 |
| 用户未响应 | 确认请求超时 | 重复提示，标注 `[CBB-WAITING]` |
| 自研模块 Lint 失败 | 自研替代代码不合规 | 进入 quality-gate 修复循环 |

## 检查点

**检查前**：
- 确认 CBB 名称和能力规格已获取
- 确认需求要求已明确

**检查后**：
- 确认所有差异项均已逐项确认（accept/custom）
- 确认自研模块文件已生成（如有）
- 确认 CBB 清单已更新

## 降级策略
Skill 调用失败时，agent 内联执行：直接输出差异表，等待用户逐项确认。
