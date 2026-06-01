#!/bin/bash
# Template B: Verible Lint — 编码风格检查
# 由 chip-lint-checker 生成
# 用法: source 本文件，或在 run_lint.sh 中引用

RTL_FILES="$@"
REPORT_DIR="ds/report/lint"
VERIBLE="tools/verible/verible-verilog-lint.exe"
VERIBLE_RULES="tools/verible/verible-lint.rules"

echo "=== Phase B: Verible Lint ==="
$VERIBLE --rules_config=$VERIBLE_RULES \
    $RTL_FILES 2>&1 | tee "$REPORT_DIR/B_verible.log"
VERIBLE_RET=${PIPESTATUS[0]}

if [ $VERIBLE_RET -eq 0 ]; then
    echo "Phase B (Verible): PASS" >> "$REPORT_DIR/lint_summary.log"
else
    echo "Phase B (Verible): FAIL" >> "$REPORT_DIR/lint_summary.log"
fi
exit $VERIBLE_RET
