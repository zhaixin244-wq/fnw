#!/bin/bash
# Template: CDC Verify — 执行 SpyGlass CDC 检查
# 由 chip-spyglass-cdc-chk 生成
# 用法: bash template_cdc_verify.sh <module> [sgdc_file]

MODULE=$1
SGDC_FILE="${2:-ds/run/${MODULE}.sgdc}"
REPORT_DIR="ds/report/cdc"
PROJECT_FILE="${MODULE}_cdc.prj"

mkdir -p "$REPORT_DIR"

# 检查 SGDC 文件
if [ ! -f "$SGDC_FILE" ]; then
    echo "[CDC-ERROR] SGDC file not found: $SGDC_FILE"
    echo "[CDC-ERROR] Run template_cdc_setup.sh first"
    exit 1
fi

echo "=== SpyGlass CDC Verification ==="
echo "Module: $MODULE"
echo "SGDC:   $SGDC_FILE"
echo "Report: $REPORT_DIR"
echo ""

# --- Step 1: CDC Setup ---
echo "--- Step 1: CDC Setup ---"
spyglass -project "$PROJECT_FILE" \
    -goal cdc/cdc_setup \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/1_cdc_setup.log"
SETUP_RET=${PIPESTATUS[0]}

if [ $SETUP_RET -ne 0 ]; then
    echo "[CDC-WARN] cdc_setup completed with warnings/errors"
fi

# 检查自动生成的约束
if [ -d "spyglass_reports/clock_reset" ]; then
    echo "[CDC-INFO] Auto-generated constraints in spyglass_reports/clock_reset/"
    echo "[CDC-INFO] Please review autoclocks.sgdc and autoresets.sgdc"
    echo "[CDC-INFO] Merge valid constraints into $SGDC_FILE"
fi

# --- Step 2: CDC Setup Check ---
echo "--- Step 2: CDC Setup Check ---"
spyglass -project "$PROJECT_FILE" \
    -goal cdc/cdc_setup_check \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/2_cdc_setup_check.log"
CHECK_RET=${PIPESTATUS[0]}

if [ $CHECK_RET -ne 0 ]; then
    echo "[CDC-FAIL] cdc_setup_check failed — fix setup errors before proceeding"
    echo "Setup Check: FAIL" >> "$REPORT_DIR/cdc_summary.log"
    # 不退出，继续执行后续检查
else
    echo "Setup Check: PASS" >> "$REPORT_DIR/cdc_summary.log"
fi

# --- Step 3: Clock/Reset Integrity ---
echo "--- Step 3: Clock/Reset Integrity ---"
spyglass -project "$PROJECT_FILE" \
    -goal cdc/clock_reset_integrity \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/3_clock_reset_integrity.log"
INT_RET=${PIPESTATUS[0]}

if [ $INT_RET -ne 0 ]; then
    echo "[CDC-WARN] clock_reset_integrity has issues"
    echo "Reset Integrity: FAIL" >> "$REPORT_DIR/cdc_summary.log"
else
    echo "Reset Integrity: PASS" >> "$REPORT_DIR/cdc_summary.log"
fi

# --- Step 4: CDC Verify (Structural) ---
echo "--- Step 4: CDC Verify (Structural) ---"
spyglass -project "$PROJECT_FILE" \
    -goal cdc/cdc_verify_struct \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/4_cdc_verify_struct.log"
STRUCT_RET=${PIPESTATUS[0]}

# 统计结构检查违例
STRUCT_ERRORS=$(grep -c "^Error" "$REPORT_DIR/4_cdc_verify_struct.log" 2>/dev/null || echo 0)
STRUCT_WARNS=$(grep -c "^Warning" "$REPORT_DIR/4_cdc_verify_struct.log" 2>/dev/null || echo 0)
echo "Struct Verify: $STRUCT_ERRORS errors, $STRUCT_WARNS warnings" >> "$REPORT_DIR/cdc_summary.log"

# --- Step 5: CDC Verify (Functional) ---
echo "--- Step 5: CDC Verify (Functional) ---"
spyglass -project "$PROJECT_FILE" \
    -goal cdc/cdc_verify \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/5_cdc_verify.log"
FUNC_RET=${PIPESTATUS[0]}

# 统计功能检查违例
FUNC_ERRORS=$(grep -c "^Error" "$REPORT_DIR/5_cdc_verify.log" 2>/dev/null || echo 0)
FUNC_WARNS=$(grep -c "^Warning" "$REPORT_DIR/5_cdc_verify.log" 2>/dev/null || echo 0)
echo "Func Verify: $FUNC_ERRORS errors, $FUNC_WARNS warnings" >> "$REPORT_DIR/cdc_summary.log"

# --- 汇总 ---
echo ""
echo "=== CDC Summary ==="
echo "Module: $MODULE" >> "$REPORT_DIR/cdc_summary.log"
echo "Date: $(date +%Y-%m-%d)" >> "$REPORT_DIR/cdc_summary.log"

# 违例分类统计
echo ""
echo "Violation Breakdown:"
for RULE in Ac_unsync01 Ac_unsync02 Ac_conv01 Ac_conv02 Ac_conv03 Ac_conv04 Ac_conv05 \
            Ac_glitch01 Ac_glitch02 Ac_glitch03 Ac_cdc01 Ac_datahold01a Ac_cdc08 \
            Ar_unsync01 Ar_sync01 Ar_asyncdeassert01 Ar_syncdeassert01 Ac_fifo01; do
    COUNT=$(grep -c "$RULE" "$REPORT_DIR/5_cdc_verify.log" 2>/dev/null || echo 0)
    if [ "$COUNT" -gt 0 ]; then
        echo "  $RULE: $COUNT"
        echo "  $RULE: $COUNT" >> "$REPORT_DIR/cdc_summary.log"
    fi
done

# 返回码
OVERALL_RET=$(( SETUP_RET + CHECK_RET + INT_RET + STRUCT_RET + FUNC_RET ))
if [ $OVERALL_RET -ne 0 ]; then
    echo ""
    echo "[CDC-RESULT] HAS VIOLATIONS — run chip-spyglass-cdc-resolver for analysis"
    echo "Overall: HAS VIOLATIONS" >> "$REPORT_DIR/cdc_summary.log"
else
    echo ""
    echo "[CDC-RESULT] PASS — no violations"
    echo "Overall: PASS" >> "$REPORT_DIR/cdc_summary.log"
fi

exit $OVERALL_RET
