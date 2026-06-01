#!/bin/bash
# Template: RDC Verify — 执行 SpyGlass RDC 检查
# 由 chip-spyglass-rdc-chk 生成
# 用法: bash template_rdc_verify.sh <module> [rdc_file] [sgdc_file]

MODULE=$1
RDC_FILE="${2:-ds/run/${MODULE}.rdc.tcl}"
SGDC_FILE="${3:-ds/run/${MODULE}.sgdc}"
REPORT_DIR="ds/report/rdc"
PROJECT_FILE="${MODULE}_rdc.prj"

mkdir -p "$REPORT_DIR"

# 检查 RDC 约束文件
if [ ! -f "$RDC_FILE" ]; then
    echo "[RDC-ERROR] RDC constraint file not found: $RDC_FILE"
    echo "[RDC-ERROR] Run template_rdc_setup.sh first"
    exit 1
fi

echo "=== SpyGlass RDC Verification ==="
echo "Module: $MODULE"
echo "RDC:    $RDC_FILE"
echo "SGDC:   $SGDC_FILE"
echo "Report: $REPORT_DIR"
echo ""

# --- Step 1: RDC Setup ---
echo "--- Step 1: RDC Setup ---"
spyglass -project "$PROJECT_FILE" \
    -goal rdc/rdc_setup \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/1_rdc_setup.log"
SETUP_RET=${PIPESTATUS[0]}

if [ $SETUP_RET -ne 0 ]; then
    echo "[RDC-WARN] rdc_setup completed with warnings/errors"
fi

# --- Step 2: RDC Setup Check ---
echo "--- Step 2: RDC Setup Check ---"
spyglass -project "$PROJECT_FILE" \
    -goal rdc/rdc_setup_check \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/2_rdc_setup_check.log"
CHECK_RET=${PIPESTATUS[0]}

if [ $CHECK_RET -ne 0 ]; then
    echo "[RDC-FAIL] rdc_setup_check failed — fix setup errors before proceeding"
    echo "Setup Check: FAIL" >> "$REPORT_DIR/rdc_summary.log"
else
    echo "Setup Check: PASS" >> "$REPORT_DIR/rdc_summary.log"
fi

# --- Step 3: RDC Verify（亚稳态检查） ---
echo "--- Step 3: RDC Verify (Metastability) ---"
spyglass -project "$PROJECT_FILE" \
    -goal rdc/rdc_verify \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/3_rdc_verify.log"
META_RET=${PIPESTATUS[0]}

# 统计亚稳态违例
META_ERRORS=$(grep -c "^Error" "$REPORT_DIR/3_rdc_verify.log" 2>/dev/null || echo 0)
META_WARNS=$(grep -c "^Warning" "$REPORT_DIR/3_rdc_verify.log" 2>/dev/null || echo 0)
echo "Metastability Verify: $META_ERRORS errors, $META_WARNS warnings" >> "$REPORT_DIR/rdc_summary.log"

# --- Step 4: RDC Verify Corrupt（数据损坏检查） ---
echo "--- Step 4: RDC Verify (Corruption) ---"
spyglass -project "$PROJECT_FILE" \
    -goal rdc/rdc_verify_corrupt \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/4_rdc_verify_corrupt.log"
CORRUP_RET=${PIPESTATUS[0]}

# 统计数据损坏违例
CORRUP_ERRORS=$(grep -c "^Error" "$REPORT_DIR/4_rdc_verify_corrupt.log" 2>/dev/null || echo 0)
CORRUP_WARNS=$(grep -c "^Warning" "$REPORT_DIR/4_rdc_verify_corrupt.log" 2>/dev/null || echo 0)
echo "Corruption Verify: $CORRUP_ERRORS errors, $CORRUP_WARNS warnings" >> "$REPORT_DIR/rdc_summary.log"

# --- 汇总 ---
echo ""
echo "=== RDC Summary ==="
echo "Module: $MODULE" >> "$REPORT_DIR/rdc_summary.log"
echo "Date: $(date +%Y-%m-%d)" >> "$REPORT_DIR/rdc_summary.log"

# 违例分类统计
echo ""
echo "Violation Breakdown:"
for RULE in Ar_asyncreset01 Ar_resetcross01 Rdc_metastab01 Rdc_corrupt01 \
            Rdc_clockpath01 Rdc_converge01 Rdc_power01; do
    COUNT=$(grep -c "$RULE" "$REPORT_DIR/3_rdc_verify.log" "$REPORT_DIR/4_rdc_verify_corrupt.log" 2>/dev/null || echo 0)
    if [ "$COUNT" -gt 0 ]; then
        echo "  $RULE: $COUNT"
        echo "  $RULE: $COUNT" >> "$REPORT_DIR/rdc_summary.log"
    fi
done

# 返回码
OVERALL_RET=$(( SETUP_RET + CHECK_RET + META_RET + CORRUP_RET ))
if [ $OVERALL_RET -ne 0 ]; then
    echo ""
    echo "[RDC-RESULT] HAS VIOLATIONS — run chip-spyglass-rdc-resolver for analysis"
    echo "Overall: HAS VIOLATIONS" >> "$REPORT_DIR/rdc_summary.log"
else
    echo ""
    echo "[RDC-RESULT] PASS — no violations"
    echo "Overall: PASS" >> "$REPORT_DIR/rdc_summary.log"
fi

exit $OVERALL_RET
