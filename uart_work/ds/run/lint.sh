#!/bin/bash
# UART RTL Lint Check Script
# Usage: bash lint.sh
# Author: AI Agent
# Date: 2026-04-27

set -e

# ============================================================
# Configuration
# ============================================================
RTL_DIR="../rtl"
WORK_DIR="./lint_work"
TOOL="verilator"

# Create work directory
mkdir -p ${WORK_DIR}

echo "=========================================="
echo "UART RTL Lint Check"
echo "=========================================="
echo "RTL Directory: ${RTL_DIR}"
echo "Work Directory: ${WORK_DIR}"
echo "Tool: ${TOOL}"
echo "=========================================="

# ============================================================
# Individual file lint check
# ============================================================
echo ""
echo "[INFO] Checking individual files..."

FILES=(
    "uart_fifo.v"
    "uart_baud_gen.v"
    "uart_tx.v"
    "uart_rx.v"
    "uart_reg_mod.v"
    "uart_ctrl.v"
    "uart_top.v"
)

PASS_COUNT=0
FAIL_COUNT=0

for FILE in "${FILES[@]}"; do
    echo -n "  Checking ${FILE}... "
    if ${TOOL} --lint-only -Wall ${RTL_DIR}/${FILE} 2>${WORK_DIR}/${FILE%.v}_lint.log; then
        echo "PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "    See ${WORK_DIR}/${FILE%.v}_lint.log for details"
    fi
done

# ============================================================
# Top-level integration lint check
# ============================================================
echo ""
echo "[INFO] Checking top-level integration..."

if ${TOOL} --lint-only -Wall -f uart.f 2>${WORK_DIR}/uart_top_integration_lint.log; then
    echo "  Top-level integration: PASS"
else
    echo "  Top-level integration: FAIL"
    echo "    See ${WORK_DIR}/uart_top_integration_lint.log for details"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=========================================="
echo "Lint Check Summary"
echo "=========================================="
echo "  Total files: ${#FILES[@]}"
echo "  Passed: ${PASS_COUNT}"
echo "  Failed: ${FAIL_COUNT}"
echo "=========================================="

if [ ${FAIL_COUNT} -gt 0 ]; then
    echo "[ERROR] Some files failed lint check!"
    exit 1
else
    echo "[SUCCESS] All files passed lint check!"
    exit 0
fi
