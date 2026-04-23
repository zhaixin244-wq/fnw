---
name: chip-impl-self-check
description: 自检 — IC-01~39 + IM-01~08 三阶段自检，验证 RTL 实现与微架构的一致性
---

# 自检 Skill

## 职责
工具化检查通过后，按 quality-checklist-impl.md 执行三阶段自检。

## 输入
- `rtl_files`: RTL 文件列表
- `lint_report`: Lint 报告
- `synth_report`: 综合报告
- `microarch_doc`: 微架构文档

## 三阶段自检

### 第一阶段（自动化）
| IC | 检查项 | 检查方法 |
|----|--------|----------|
| IC-06 | 无不可综合结构 | grep `initial/delay/floating/force-release` |
| IC-07 | 位宽匹配 | grep 常量模式检查位宽 |
| IC-13 | 无 casex/casez | grep `casex\|casez` |
| IC-22 | 子模块名称关联 | grep 实例化是否用 `.` 开头 |
| IC-34 | 扫描使能路径 | grep ICG 实例化 scan_en |
| IC-35 | 注释覆盖率 >30% | 统计非空行注释占比 |
| IC-36 | always 行数 ≤100 | 统计每个 always 块行数 |

### 第二阶段（编码规范）
| IC | 检查项 | 检查方法 |
|----|--------|----------|
| IC-01 | 寄存器有复位值 | grep `always @(posedge clk` 检查 reset 分支 |
| IC-02 | 无 latch | `always @(*)` 所有输出有默认值 |
| IC-03 | 赋值规则 | 时序 `<=`，组合 `=`，不混用 |
| IC-04 | case 有 default | grep `case` 检查 default |
| IC-05 | 无门控时钟 | 仅使用标准 ICG |
| IC-08 | SVA 在 ifdef 内 | 所有 SVA 在 `ifdef ASSERT_ON` 内 |
| IC-09 | Interface 不含逻辑 | 无 always/assign/initial |
| IC-10 | 参数化位宽 | 无硬编码 `[31:0]` |
| IC-11 | generate 有标签 | 所有 generate 块有 begin/end 标签 |
| IC-12 | 文件头完整 | Module/Function/Author/Date/Revision |
| IC-14 | 无组合环路 | valid 不依赖 ready |
| IC-15 | if-else 补全 | 所有 if 有 else |
| IC-16 | 异步信号已同步 | 跨域信号经同步链 |
| IC-17 | 低有效极性 | `if (!rst_n)` |
| IC-18 | FIFO 深度为 2 的幂 | 深度 = 2^n |
| IC-19 | 无未连接端口 | 所有端口已连接 |
| IC-20 | task/function 规范 | 禁止 task |
| IC-21 | always 敏感列表完整 | 组合用 `@(*)` |

### 第三阶段（设计模式+DFT+矛盾检测）
| IC/IM | 检查项 | 检查方法 |
|-------|--------|----------|
| IC-23 | Credit 流控合规 | credit 归零立即反压 |
| IC-24 | 流水线每级有 valid | 无省略的流水级 |
| IC-25 | SRAM 写冲突仲裁 | 同地址同周期写有优先级 |
| IC-26 | flush 可清除所有级 | flush 高于 stall |
| IC-27 | 多通道无耦合 | 通道间无耦合 |
| IC-28 | 握手稳定性 | valid 保持稳定 |
| IC-29 | 数据稳定性 | valid&&ready 时数据稳定 |
| IC-30 | 寄存器可入扫描链 | 无不可扫描结构 |
| IC-31 | 无异步置位 | 仅异步复位 |
| IC-32 | 无门控时钟 | 仅标准 ICG |
| IC-33 | 无组合反馈环 | lint 无反馈环警告 |
| IC-37 | always 信号数 <5 | 单块生成信号 <5 |
| IC-38 | 信号分组 | 语义相近同块 |
| IC-39 | 总线分域赋值 | 按功能域分段赋值 |
| IM-01 | 端口位宽一致 | RTL 与微架构 §4.1 一致 |
| IM-02 | FSM 状态完整 | 微架构 §5.3 状态在 RTL 中存在 |
| IM-03 | FIFO 深度一致 | RTL 与微架构 §5.5 一致 |
| IM-04 | CBB 参数一致 | RTL 与微架构 §5.6 一致 |
| IM-05 | 背压链路完整 | 微架构 §5.2 反压路径在 RTL 中存在 |
| IM-06 | SVA 完整 | 微架构 §10 验证场景已实现 |
| IM-07 | SDC 时钟一致 | RTL SDC 与微架构 §6 一致 |
| IM-08 | CBB 引用标注 | 使用 CBB 有 `// CBB Ref` |

## 输出
- `self_check_report`: 自检报告（通过/失败项列表）

## Gate
IC-01~39 + IM-01~08 全部通过。

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/self_check.json`：
```json
{"stage_id": "self_check", "duration_ms": 0, "iteration_count": 1}
```
`iteration_count` 记录自检修复循环实际迭代次数。

## 失败处理
- 逐项修复后重新执行对应阶段
- 第一阶段失败 → 修复后重新执行第一阶段
- 第二阶段失败 → 修复后重新执行第二阶段
- 第三阶段失败 → 修复后重新执行第三阶段
