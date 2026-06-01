#!/bin/bash
# Template: CDC SoC Level — SoC 级 CDC 验证（层次化流程）
# 由 chip-spyglass-cdc-chk 生成
# 用法: bash template_cdc_soc.sh <top_module> <block_abstracts...>

TOP=$1
shift
BLOCK_ABSTRACTS="$@"
REPORT_DIR="ds/report/cdc_soc"
SGDC_FILE="ds/run/${TOP}_soc.sgdc"

mkdir -p "$REPORT_DIR"

echo "=== SoC-Level CDC Verification ==="
echo "Top: $TOP"
echo "Block Abstracts: $BLOCK_ABSTRACTS"
echo ""

# --- Step 1: 收集 Block Abstract Views ---
echo "--- Step 1: Collect Block Abstract Views ---"
for ABS in $BLOCK_ABSTRACTS; do
    if [ -f "$ABS" ]; then
        echo "[CDC-SOC] Including block abstract: $ABS"
    else
        echo "[CDC-SOC-WARN] Block abstract not found: $ABS"
    fi
done

# --- Step 2: CDC Setup ---
echo "--- Step 2: CDC Setup ---"
spyglass -project "${TOP}_soc_cdc.prj" \
    -goal cdc/cdc_setup \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/2_cdc_setup.log"

# --- Step 3: CDC Setup Check ---
echo "--- Step 3: CDC Setup Check ---"
spyglass -project "${TOP}_soc_cdc.prj" \
    -goal cdc/cdc_setup_check \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/3_cdc_setup_check.log"

# --- Step 4: Clock/Reset Integrity ---
echo "--- Step 4: Clock/Reset Integrity ---"
spyglass -project "${TOP}_soc_cdc.prj" \
    -goal cdc/clock_reset_integrity \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/4_clock_reset_integrity.log"

# --- Step 5: Abstract View Validation ---
echo "--- Step 5: Abstract View Validation ---"
spyglass -project "${TOP}_soc_cdc.prj" \
    -goal cdc/cdc_abstract_validate \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/5_abstract_validate.log"

# --- Step 6: SoC-Level CDC Verify ---
echo "--- Step 6: SoC-Level CDC Verify ---"
spyglass -project "${TOP}_soc_cdc.prj" \
    -goal cdc/cdc_verify_struct \
    -sgdc "$SGDC_FILE" \
    2>&1 | tee "$REPORT_DIR/6_cdc_verify_struct.log"

# --- 汇总 ---
echo ""
echo "=== SoC CDC Summary ==="
STRUCT_ERRORS=$(grep -c "^Error" "$REPORT_DIR/6_cdc_verify_struct.log" 2>/dev/null || echo 0)
STRUCT_WARNS=$(grep -c "^Warning" "$REPORT_DIR/6_cdc_verify_struct.log" 2>/dev/null || echo 0)

cat > "$REPORT_DIR/cdc_soc_summary.log" << EOF
=== SoC CDC Summary ===
Top: $TOP
Date: $(date +%Y-%m-%d)
Block Abstracts: $BLOCK_ABSTRACTS

Setup Check:     $(grep -c "Error" "$REPORT_DIR/3_cdc_setup_check.log" 2>/dev/null | \
                   xargs -I{} sh -c '[ {} -eq 0 ] && echo PASS || echo FAIL')
Reset Integrity: $(grep -c "Error" "$REPORT_DIR/4_clock_reset_integrity.log" 2>/dev/null | \
                   xargs -I{} sh -c '[ {} -eq 0 ] && echo PASS || echo FAIL')
Abstract Valid:  $(grep -c "Error" "$REPORT_DIR/5_abstract_validate.log" 2>/dev/null | \
                   xargs -I{} sh -c '[ {} -eq 0 ] && echo PASS || echo FAIL')
Struct Verify:   $STRUCT_ERRORS errors, $STRUCT_WARNS warnings

Next: Run chip-spyglass-cdc-resolver to analyze SoC-level violations
EOF

echo ""
cat "$REPORT_DIR/cdc_soc_summary.log"
