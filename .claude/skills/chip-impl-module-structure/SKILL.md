---
name: chip-impl-module-structure
description: 模块结构规划 — 从微架构文档提取端口列表、子模块划分、文件清单，创建工作目录
---

# 模块结构规划 Skill

## 职责
从微架构文档提取结构信息，规划 RTL 实现所需的端口、子模块、文件清单。

## 输入
- `microarch_doc`: 微架构文档路径
- `cbb_docs`: CBB 文档（来自 RAG 检索）

## 执行步骤
1. 从微架构 §4.1 提取端口列表（信号名/方向/位宽/类型/时钟域/复位值）
2. 从微架构 §5 确定子模块实例化列表
3. 确定文件清单：`.v` / `_sva.sv` / `_intf.sv` / `.sdc` / `_tb.v`
4. 创建工作目录结构 `{module}_work/`
5. 验证端口与微架构 §4.1 一致性

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
