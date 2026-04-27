---
name: chip-cbb-exception-confirm
description: CBB 例外确认 — 当标准 CBB 无法完全满足需求时，逐项与用户确认差异，决定复用或自研
---

# CBB 例外确认 Skill

## 职责
当标准 CBB 与需求存在差异时，逐项与用户确认，决定是否接受 CBB 能力或自研替代。

## 触发条件
Wiki 检索 CBB → 找到候选 → 对比需求 vs CBB 能力 → CBB 部分满足时触发。

## 输入
- `cbb_name`: CBB 名称
- `cbb_spec`: CBB 能力规格（来自 Wiki）
- `requirement`: 需求要求

## 执行步骤

### Step 1：差异识别
逐项对比 CBB spec vs 需求，输出差异表：

| # | 对比项 | CBB 能力 | 需求要求 | 差异描述 | 影响 |
|---|--------|----------|----------|----------|------|
| 1 | {参数} | {CBB值} | {需求值} | {差异} | {功能/性能/面积影响} |

### Step 2：逐项确认
每条差异单独询问用户：
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

### Step 3：自研类 CBB 模块
用户确认需自研后，按以下规则生成：

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

## 降级处理
Skill 调用失败时，agent 内联执行：直接输出差异表，等待用户逐项确认。
