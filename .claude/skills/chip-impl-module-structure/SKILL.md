---
name: chip-impl-module-structure
description: "Use when planning RTL module structure from microarchitecture docs. Triggers on '模块结构', '端口列表', '子模块划分', '文件清单', 'module structure', 'port list'. Extracts ports, submodule partitioning and file list from microarch docs."
---

# 模块结构规划 Skill

## 任务
从微架构文档提取结构信息，规划 RTL 实现所需的端口、子模块、文件清单。

## 输入
- `microarch_doc`: 微架构文档路径
- `cbb_docs`: CBB 文档（来自 RAG 检索）

## 执行步骤
1. 用 `Glob` 搜索 `{module}_work/ds/doc/ua/*.md` 获取微架构文档列表。若文件不存在，暂停并提示用户
2. 从微架构 §4.1 提取端口列表（信号名/方向/位宽/类型/时钟域/复位值）
3. 从微架构 §5 确定子模块实例化列表
4. 确定文件清单：`.v` / `_sva.sv` / `_intf.sv` / `.sdc` / `_tb.v`
5. 创建工作目录结构 `{module}_work/`
6. 验证端口与微架构 §4.1 一致性

## 输出
- `port_list`: 端口列表（信号名/方向/位宽/类型）
- `submodule_list`: 子模块列表（模块名/功能/依赖）
- `file_list`: 文件清单
- `work_dir`: 工作目录路径

## 工作目录结构
```
{module}_work/
├── rtl/           — RTL 源码
├── syn/           — SDC + Makefile
├── ds/
│   ├── doc/       — CBB 清单
│   ├── run/       — 运行脚本
│   └── report/    — Lint/综合报告
```

## Gate
端口列表必须与微架构 §4.1 完全一致。

## 架构冻结
本 Skill 不涉及架构决策，仅从微架构提取结构信息。

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/module_structure.json`：
```json
{"stage_id": "module_structure", "duration_ms": 0, "iteration_count": 1}
```

## 使用示例

**示例 1**：
- 用户：「根据公共模块微架构文档规划模块结构」
- 行为：读取微架构 §4.1 提取端口列表，§5 确定子模块实例化，生成文件清单（.v/_sva.sv/_intf.sv/.sdc/_tb.v），创建工作目录

**示例 2**：
- 用户：「buf_mgr 有几个子模块，帮我列出端口和文件清单」
- 行为：从微架构文档提取各子模块端口（信号名/方向/位宽/类型），确认子模块依赖关系，输出 `port_list`、`submodule_list`、`file_list`

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 微架构端口列表缺失 | §4.1 无端口表格 | 暂停，提示用户补充微架构端口定义 |
| 子模块定义不完整 | §5 无子模块实例化列表 | 暂停，提示用户补充子模块设计 |
| 工作目录创建失败 | 路径权限或磁盘问题 | 提示用户检查路径权限 |
| 端口与微架构不一致 | 提取结果与 §4.1 矛盾 | 以微架构为准，标注差异项 |

## 检查点

**检查前**：
- 确认微架构文档路径有效且包含 §4.1 和 §5
- 确认目标工作目录可写

**检查后**：
- 确认 `port_list` 与微架构 §4.1 完全一致
- 确认 `submodule_list` 包含所有子模块
- 确认工作目录 `{module}_work/` 已创建且结构正确
- 确认 metrics 已写入 `{work_dir}/ds/report/metrics/module_structure.json`
