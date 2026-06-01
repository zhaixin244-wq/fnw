#!/bin/bash
# Template C: Yosys Lint — 组合环路/多驱动检测 + 综合可行性
# 由 chip-lint-checker 生成
# 用法: source 本文件，或在 run_lint.sh 中引用

TOP=$1
shift
RTL_FILES="$@"
REPORT_DIR="ds/report/lint"
YOSYS="tools/oss-cad-suite/bin/yosys"

echo "=== Phase C: Yosys Lint ==="
$YOSYS -p "read_verilog -I. $RTL_FILES; proc; opt; check" 2>&1 | tee "$REPORT_DIR/C_yosys_lint.log"
YOSYS_LINT_RET=${PIPESTATUS[0]}

echo "=== Phase D: Yosys 综合可行性 ==="
$YOSYS -p "read_verilog -I. $RTL_FILES; synth -top $TOP; stat" 2>&1 | tee "$REPORT_DIR/D_yosys_synth.log"
YOSYS_SYNTH_RET=${PIPESTATUS[0]}

grep -A 20 "Printing statistics" "$REPORT_DIR/D_yosys_synth.log" > "$REPORT_DIR/D_yosys_synth_stat.log" 2>/dev/null

if [ $YOSYS_LINT_RET -eq 0 ]; then
    echo "Phase C (Yosys Lint): PASS" >> "$REPORT_DIR/lint_summary.log"
else
    echo "Phase C (Yosys Lint): FAIL" >> "$REPORT_DIR/lint_summary.log"
fi

if [ $YOSYS_SYNTH_RET -eq 0 ]; then
    echo "Phase D (Yosys Synth): PASS" >> "$REPORT_DIR/lint_summary.log"
else
    echo "Phase D (Yosys Synth): FAIL" >> "$REPORT_DIR/lint_summary.log"
fi

FAILURES=$((YOSYS_LINT_RET + YOSYS_SYNTH_RET))
exit $FAILURES
