---
name: chip-lint-checker
description: "Use when running RTL lint checks with Verilator or iverilog. Triggers on 'lint', 'verilator', '语法检查', '可综合性', '组合环路', 'latch检查', 'rtl lint', 'lint检查'. Detects syntax errors, synthesis issues, combinational loops, and latches."
---

# Chip Lint Checker

## 任务
对 RTL 代码执行 Lint 检查，覆盖语法、可综合性、组合环路和 latch 检测。使用 oss-cad-suite 工具链。

## 目录约定

| 项目 | 路径 |
|------|------|
| Lint 脚本 | `{module}_work/ds/run/run_lint.sh` |
| 报告目录 | `{module}_work/ds/report/lint/` |
| oss-cad-suite | `.claude/tools/oss-cad-suite/` |

## 工具路径

| 工具 | 路径 | 用途 |
|------|------|------|
| iverilog | `.claude/tools/oss-cad-suite/bin/iverilog` | Verilog-2005 语法 + 可综合性 Lint |
| yosys | `.claude/tools/oss-cad-suite/bin/yosys` | 综合感知 Lint（组合环路、驱动冲突） |

## 执行步骤

1. **确定输入**：
   - 从微架构文档提取顶层模块名和 RTL 文件列表
   - 若用户指定单个文件，推导模块名（去掉 `.v` 后缀）
   - **文件存在性检查**：用 `Glob` 验证 RTL 文件存在，不存在则暂停并列出候选文件
2. **生成脚本**：在 `{module}_work/ds/run/` 下生成 `run_lint.sh`（脚本模板见下方）
3. **创建报告目录**：`mkdir -p {module}_work/ds/report/lint/`
4. **执行**：`cd {module}_work && bash ds/run/run_lint.sh {top} {rtl_files}`
5. **解析报告**：读取 `ds/report/lint/` 下的日志文件

## run_lint.sh 脚本模板

```bash
#!/bin/bash
# Lint 检查脚本 — 由 chip-lint-checker 生成
# 用法: bash run_lint.sh <top_module> <rtl_file1> [rtl_file2] ...

TOP=$1
shift
RTL_FILES="$@"
REPORT_DIR="ds/report/lint"
TOOL_DIR=".claude/tools/oss-cad-suite/bin"

mkdir -p "$REPORT_DIR"

echo "=== Phase 1: iverilog 语法检查 ==="
$TOOL_DIR/iverilog -g2005 -Wall -tnull $RTL_FILES 2>&1 | tee "$REPORT_DIR/1_iverilog.log"
IVERILOG_RET=${PIPESTATUS[0]}

echo "=== Phase 2: yosys 组合环路/多驱动检测 ==="
$TOOL_DIR/yosys -p "read_verilog -I. $RTL_FILES; proc; opt; check" 2>&1 | tee "$REPORT_DIR/2_yosys_lint.log"
YOSYS_LINT_RET=${PIPESTATUS[0]}

echo "=== Phase 3: yosys 综合可行性 ==="
$TOOL_DIR/yosys -p "read_verilog -I. $RTL_FILES; synth -top $TOP; stat" 2>&1 | tee "$REPORT_DIR/3_yosys_synth.log"
YOSYS_SYNTH_RET=${PIPESTATUS[0]}

# 提取面积统计
grep -A 20 "Printing statistics" "$REPORT_DIR/3_yosys_synth.log" > "$REPORT_DIR/3_yosys_synth_stat.log" 2>/dev/null

# 汇总
echo "=== Lint Summary ===" > "$REPORT_DIR/lint_summary.log"
[ $IVERILOG_RET -eq 0 ] && echo "Phase 1 (iverilog): PASS" >> "$REPORT_DIR/lint_summary.log" || echo "Phase 1 (iverilog): FAIL" >> "$REPORT_DIR/lint_summary.log"
[ $YOSYS_LINT_RET -eq 0 ] && echo "Phase 2 (yosys_lint): PASS" >> "$REPORT_DIR/lint_summary.log" || echo "Phase 2 (yosys_lint): FAIL" >> "$REPORT_DIR/lint_summary.log"
[ $YOSYS_SYNTH_RET -eq 0 ] && echo "Phase 3 (yosys_synth): PASS" >> "$REPORT_DIR/lint_summary.log" || echo "Phase 3 (yosys_synth): FAIL" >> "$REPORT_DIR/lint_summary.log"

FAILURES=$((IVERILOG_RET + YOSYS_LINT_RET + YOSYS_SYNTH_RET))
[ $FAILURES -eq 0 ] && echo "ALL PASS" >> "$REPORT_DIR/lint_summary.log" || echo "HAS FAILURES ($FAILURES/3)" >> "$REPORT_DIR/lint_summary.log"

exit $FAILURES
```

## 三阶段输出报告

| 文件 | 阶段 | 内容 |
|------|------|------|
| `1_iverilog.log` | 阶段 1 | 语法 error/warning |
| `2_yosys_lint.log` | 阶段 2 | 组合环路/多驱动检测 |
| `3_yosys_synth.log` | 阶段 3 | 综合可行性检查 |
| `3_yosys_synth_stat.log` | 阶段 3 | 面积统计 |
| `lint_summary.log` | 汇总 | 三阶段 PASS/FAIL |

## Warning 分级处理

| 级别 | 处理 | 典型场景 |
|------|------|----------|
| **Critical** | 必须修复，阻断交付 | 组合环路、多驱动、语法 error |
| **Major** | 必须修复或标注 waive 理由 | 未声明信号、位宽截断、隐式 latch |
| **Minor** | 建议修复 | 端口未连接（内部信号）、敏感列表冗余 |
| **Info** | 仅记录 | 参数未使用、信号仅赋值未读取 |

## 使用示例

**示例 1**：
- 用户：「公共模块 RTL 写完了，跑一下 Lint」
- 行为：生成 `run_lint.sh`，依次执行 iverilog 语法检查、yosys 组合环路检测、yosys 综合可行性检查，输出三阶段报告和 `lint_summary.log`

**示例 2**：
- 用户：「buf_mgr 有 latch 警告，帮我定位」
- 行为：读取 `2_yosys_lint.log` 中 `inferred latch` 行，定位到具体文件和行号，给出修复建议（补默认值+else+default）

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 工具不可用 | iverilog/yosys 均不在 PATH | 暂停，标注 `[ENV-MISSING]`，提示安装 oss-cad-suite |
| Critical 错误 | 组合环路/多驱动/语法 error | 标注 FAIL，逐条分析并给出修复建议 |
| 文件列表为空 | 无 RTL 文件可检查 | 暂停，提示先完成 RTL 实现 |
| 文件不存在 | 用户指定的文件路径无效 | 用 Glob 搜索相近文件名，列出候选，提示用户确认 |
| 报告目录创建失败 | 路径权限问题 | 提示用户检查目录权限 |

## 检查点

**检查前**：
- 确认 RTL 文件列表非空
- 确认 iverilog 或 yosys 至少一个可用
- 确认报告目录已创建

**检查后**：
- 确认 `lint_summary.log` 已生成
- 确认 Critical/Major 错误已逐条列出
- 确认降级状态已标注（如有）

## 降级策略

| 场景 | 行为 |
|------|------|
| iverilog 不可用 | 仅执行 yosys 阶段 2+3，标注 `[LINT-DEGRADED]` |
| yosys 不可用 | 仅执行 iverilog 阶段 1，标注 `[LINT-DEGRADED]` |
| 均不可用 | 内化执行人工 Lint，标注 `[LINT-MANUAL]` |

## 调用时机

| 时机 | 触发条件 | 与 chip-code-writer 流程的关系 |
|------|----------|-------------------------------|
| 子模块 RTL 完成 | 每个子模块写完后 | rtl_impl 阶段内，CBB 集成之后 |
| 所有子模块完成 | 全部 RTL 写完后 | quality_check 阶段入口 |
| 修复后复检 | Lint 报告有 Critical/Major | 修复后重新执行对应阶段 |

## CBB Ref
- oss-cad-suite: `.claude/tools/oss-cad-suite/`（iverilog v14.0, yosys v0.64+68）
