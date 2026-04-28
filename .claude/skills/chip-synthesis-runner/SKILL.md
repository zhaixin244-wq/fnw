---
name: chip-synthesis-runner
description: "Use when running Yosys synthesis on Verilog/RTL code. Triggers on '综合', 'synthesis', 'yosys', 'synth', '面积', 'timing', 'Fmax', '综合报告', '面积估计'. Runs Yosys and generates synthesis report with area and critical path info."
---

# Chip Synthesis Runner

## 任务
使用 yosys 对 RTL 代码执行综合，验证可综合性并输出面积/资源估计。使用 oss-cad-suite 工具链。

## 目录约定

| 项目 | 路径 |
|------|------|
| Syn 脚本 | `{module}_work/ds/run/run_synth.sh` |
| 报告目录 | `{module}_work/ds/report/syn/` |
| oss-cad-suite | `.claude/tools/oss-cad-suite/` |

## 工具路径

| 工具 | 路径 | 用途 |
|------|------|------|
| yosys | `.claude/tools/oss-cad-suite/bin/yosys` | RTL 综合、面积估计、资源分析 |

## 执行步骤

1. **前置条件**：确认 chip-lint-checker 全部阶段通过。若未执行 Lint，暂停并提示先运行 `chip-lint-checker`。
2. **确定输入**：
   - 顶层模块名
   - RTL 文件列表：用 `Glob` 搜索 `{module}_work/ds/rtl/*.v` 获取所有 RTL 文件
   - **文件存在性检查**：验证 RTL 文件存在，不存在则暂停并列出候选文件
3. **生成脚本**：在 `{module}_work/ds/run/` 下生成 `run_synth.sh`（脚本模板见下方）
4. **创建报告目录**：`mkdir -p {module}_work/ds/report/syn/`
5. **执行**：`cd {module}_work && bash ds/run/run_synth.sh {top} {rtl_files}`
6. **解析报告**：读取 `ds/report/syn/` 下的日志文件，与微架构 §8 PPA 预估对比

## run_synth.sh 脚本模板

```bash
#!/bin/bash
# 综合脚本 — 由 chip-synthesis-runner 生成
# 用法: bash run_synth.sh <top_module> <rtl_file1> [rtl_file2] ...

TOP=$1
shift
RTL_FILES="$@"
REPORT_DIR="ds/report/syn"
TOOL_DIR=".claude/tools/oss-cad-suite/bin"

mkdir -p "$REPORT_DIR"

echo "=== Phase 1: 综合验证 ==="
$TOOL_DIR/yosys -p "
  read_verilog -I. $RTL_FILES;
  synth -top $TOP;
  stat;
  check;
" 2>&1 | tee "$REPORT_DIR/1_synth_verify.log"

# 提取面积统计
grep -A 20 "Printing statistics" "$REPORT_DIR/1_synth_verify.log" > "$REPORT_DIR/1_synth_check.log" 2>/dev/null

echo "=== Phase 2: Flatten 综合 ==="
$TOOL_DIR/yosys -p "
  read_verilog -I. $RTL_FILES;
  synth -top $TOP;
  flatten;
  stat;
  opt_clean -purge;
" 2>&1 | tee "$REPORT_DIR/2_synth_flat.log"

# 提取面积统计
grep -A 20 "Printing statistics" "$REPORT_DIR/2_synth_flat.log" > "$REPORT_DIR/2_area_stat.log" 2>/dev/null

# 汇总
echo "=== Synthesis Summary ===" > "$REPORT_DIR/synth_summary.log"
if grep -q "ERROR" "$REPORT_DIR/1_synth_verify.log"; then
  echo "Phase 1: FAIL" >> "$REPORT_DIR/synth_summary.log"
else
  echo "Phase 1: PASS" >> "$REPORT_DIR/synth_summary.log"
fi
if grep -q "ERROR" "$REPORT_DIR/2_synth_flat.log"; then
  echo "Phase 2: FAIL" >> "$REPORT_DIR/synth_summary.log"
else
  echo "Phase 2: PASS" >> "$REPORT_DIR/synth_summary.log"
fi
cat "$REPORT_DIR/2_area_stat.log" >> "$REPORT_DIR/synth_summary.log"
```

## 两阶段输出报告

| 文件 | 阶段 | 内容 |
|------|------|------|
| `1_synth_verify.log` | 阶段 1 | 综合验证日志 |
| `1_synth_check.log` | 阶段 1 | stat（cmos 通用面积） |
| `2_synth_flat.log` | 阶段 2 | flatten 综合日志 |
| `2_area_stat.log` | 阶段 2 | 面积统计 |
| `synth_summary.log` | 汇总 | PASS/FAIL + 面积汇总 |

## PPA 对比规则

```
综合面积 vs 微架构预估：
  差异 < 20%  → Pass
  差异 20~50% → Major，需分析原因
  差异 > 50%  → Critical，暂停确认
```

## 使用示例

**示例 1**：
- 用户：「公共模块 Lint 已通过，跑综合」
- 行为：生成 `run_synth.sh`，执行两阶段综合（验证 + flatten），输出 `synth_summary.log`，与微架构 §8 PPA 预估对比面积差异

**示例 2**：
- 用户：「帮我估算 buf_mgr 的面积」
- 行为：执行 yosys 综合，读取 `2_area_stat.log` 面积统计，与微架构预估对比，差异 >20% 时分析原因

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| yosys 不可用 | 不在 PATH 且无本地安装 | 暂停，标注 `[ENV-MISSING]`，提示安装 oss-cad-suite |
| 综合失败 | RTL 有不可综合结构 | 保留 yosys 日志，逐条分析 error，标注 `[SYNTH-FAIL]` |
| 面积差异 >50% | 综合面积远超微架构预估 | Critical 暂停，等待用户确认 |
| 无工艺库 | 未指定目标工艺 | 使用 `-tech cmos` 通用估计，标注 `[SYNTH-NO-TECH]` |

## 检查点

**检查前**：
- 确认 Lint 检查已全部通过
- 确认 RTL 文件列表非空
- 确认 yosys 工具可用

**检查后**：
- 确认 `synth_summary.log` 已生成
- 确认面积与微架构预估对比结果已输出
- 确认降级状态已标注（如有）

## 降级策略

| 场景 | 行为 |
|------|------|
| yosys 不可用 | 内化执行面积估算，标注 `[SYNTH-MANUAL]` |
| 综合失败 | 保留 yosys 日志，逐条分析 error，标注 `[SYNTH-FAIL]` |
| 无工艺库 | 使用 `-tech cmos` 通用估计，标注无目标工艺 |

## 调用时机

| 时机 | 触发条件 | 与 chip-code-writer 流程的关系 |
|------|----------|-------------------------------|
| Lint 通过后 | chip-lint-checker 全部阶段通过 | quality_check 阶段，Lint 之后 |
| 面积评估 | 需要验证 PPA 预估 | quality_check 或 sdc_sva 阶段 |
| 修复后复检 | 面积差异 > 50% | 优化后重新执行 |

## CBB Ref
- oss-cad-suite: `.claude/tools/oss-cad-suite/`（yosys v0.64+68）
