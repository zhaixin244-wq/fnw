#!/bin/bash
# Template: RDC SoC Level — SoC 级 RDC 验证（层次化流程）
# 由 chip-spyglass-rdc-chk 生成
# 用法: bash template_rdc_soc.sh <top_module> <block_abstracts...>

TOP=$1
shift
BLOCK_ABSTRACTS="$@"
REPORT_DIR="ds/report/rdc_soc"
RDC_FILE="ds/run/${TOP}_soc.rdc.tcl"

mkdir -p "$REPORT_DIR"

echo "=== SoC-Level RDC Verification ==="
echo "Top: $TOP"
echo "Block Abstracts: $BLOCK_ABSTRACTS"
echo ""

# --- Step 1: 收集 Block Abstract Views ---
echo "--- Step 1: Collect Block Abstract Views ---"
for ABS in $BLOCK_ABSTRACTS; do
    if [ -f "$ABS" ]; then
        echo "[RDC-SOC] Including block abstract: $ABS"
    else
        echo "[RDC-SOC-WARN] Block abstract not found: $ABS"
    fi
done

# --- Step 2: RDC Setup ---
echo "--- Step 2: RDC Setup ---"
spyglass -project "${TOP}_soc_rdc.prj" \
    -goal rdc/rdc_setup \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/2_rdc_setup.log"

# --- Step 3: RDC Setup Check ---
echo "--- Step 3: RDC Setup Check ---"
spyglass -project "${TOP}_soc_rdc.prj" \
    -goal rdc/rdc_setup_check \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/3_rdc_setup_check.log"

# --- Step 4: Abstract View Validation ---
echo "--- Step 4: Abstract View Validation ---"
spyglass -project "${TOP}_soc_rdc.prj" \
    -goal rdc/rdc_abstract_validate \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/4_abstract_validate.log"

# --- Step 5: SoC-Level RDC Verify ---
echo "--- Step 5: SoC-Level RDC Verify ---"
spyglass -project "${TOP}_soc_rdc.prj" \
    -goal rdc/rdc_verify \
    -rdc "$RDC_FILE" \
    2>&1 | tee "$REPORT_DIR/5_rdc_verify.log"

# --- 汇总 ---
echo ""
echo "=== SoC RDC Summary ==="
META_ERRORS=$(grep -c "^Error" "$REPORT_DIR/5_rdc_verify.log" 2>/dev/null || echo 0)
META_WARNS=$(grep -c "^Warning" "$REPORT_DIR/5_rdc_verify.log" 2>/dev/null || echo 0)

cat > "$REPORT_DIR/rdc_soc_summary.log" << EOF
=== SoC RDC Summary ===
Top: $TOP
Date: $(date +%Y-%m-%d)
Block Abstracts: $BLOCK_ABSTRACTS

Setup Check:     $(grep -c "Error" "$REPORT_DIR/3_rdc_setup_check.log" 2>/dev/null | \
                   xargs -I{} sh -c '[ {} -eq 0 ] && echo PASS || echo FAIL')
Abstract Valid:  $(grep -c "Error" "$REPORT_DIR/4_abstract_validate.log" 2>/dev/null | \
                   xargs -I{} sh -c '[ {} -eq 0 ] && echo PASS || echo FAIL')
RDC Verify:      $META_ERRORS errors, $META_WARNS warnings

Next: Run chip-spyglass-rdc-resolver to analyze SoC-level violations
EOF

echo ""
cat "$REPORT_DIR/rdc_soc_summary.log"
