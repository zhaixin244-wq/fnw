#!/bin/bash
# Template A: Verilator Lint — 综合级检查
# 由 chip-lint-checker 生成
# 用法: source 本文件，或在 run_lint.sh 中引用

TOP=$1
shift
RTL_FILES="$@"
REPORT_DIR="ds/report/lint"
VERILATOR="tools/oss-cad-suite/bin/verilator"

echo "=== Phase A: Verilator Lint ==="
$VERILATOR --lint-only -Wall \
    -Wno-DECLFILENAME \
    -Wno-UNUSED \
    --top-module $TOP \
    $RTL_FILES 2>&1 | tee "$REPORT_DIR/A_verilator.log"
VERILATOR_RET=${PIPESTATUS[0]}

if [ $VERILATOR_RET -eq 0 ]; then
    echo "Phase A (Verilator): PASS" >> "$REPORT_DIR/lint_summary.log"
else
    echo "Phase A (Verilator): FAIL" >> "$REPORT_DIR/lint_summary.log"
fi
exit $VERILATOR_RET
