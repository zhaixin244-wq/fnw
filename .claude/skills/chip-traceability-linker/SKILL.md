---
name: chip-traceability-linker
description: "Use when building requirements traceability matrix (RTM). Triggers on 'RTM', '追溯矩阵', 'traceability', '需求追溯', '需求覆盖', '追溯矩阵'. Builds traceability from requirements to architecture, interface, PPA and verification."
---

# Chip Traceability Linker

## 任务
建立并输出需求追溯矩阵（Requirements Traceability Matrix, RTM）。

## 执行步骤
1. 用 `Glob` 搜索 `{module}_work/ds/doc/fs/*.md` 获取 FS 文档列表，用 `Glob` 搜索 `{module}_work/ds/doc/ua/*.md` 获取 UA 文档列表。若文件不存在，暂停并提示用户
2. 收集需求 ID（如 SysReq-001）及其描述。
3. 为每条需求映射到：
   - 架构决策 ID（Arch-XXX）
   - 接口/信号（Intf-XXX）
   - PPA 指标（PPA-XXX）
   - 验证策略（Verify-XXX）
   - 状态（Allocated / Designed / Verified / Waived）
4. 识别未被覆盖的需求或没有上游需求的孤儿架构项。
5. 若涉及版本变更，标注新增/删除/修改的追溯链。

## 输出格式
Markdown 表格：
| 需求 ID | 需求描述 | 架构决策 | 接口/信号 | PPA 指标 | 验证策略 | 状态 | 备注 |

随后输出：
- 覆盖率统计（X/Y = Z%）
- 遗漏项清单（如有）

## 使用示例

**示例 1：从 FS 和 UA 构建 RTM**
```
用户：帮我为公共模块建立需求追溯矩阵，FS 在 ds/doc/fs/{module}_FS_v1.0.md，UA 在 ds/doc/ua/
```
预期行为：
1. 读取 FS 中所有 REQ-XXX 需求
2. 扫描 UA 文档，匹配每条需求的架构决策、接口信号、PPA 指标
3. 输出完整 RTM 表格 + 覆盖率统计

**示例 2：检查遗漏项**
```
用户：检查公共模块的 RTM 有没有未覆盖的需求
```
预期行为：扫描 RTM，列出所有状态为"未分配"或"待设计"的需求项

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 需求 ID 缺失 | FS 中无 REQ 编号 | 暂停，提示用户先补充需求编号 |
| 架构文档不完整 | UA 缺少对应章节 | 标注"待设计"，继续追溯其他项 |
| 覆盖率过低 | < 70% | 高亮警告，列出所有未覆盖需求 |
| 版本变更 | 新旧版本差异大 | 逐项标注新增/删除/修改，用户确认后更新 RTM |

## 检查点

- **追溯前**：展示需求 ID 列表和可用架构文档，确认追溯范围
- **追溯后**：展示覆盖率统计和遗漏项，用户确认后输出最终 RTM
