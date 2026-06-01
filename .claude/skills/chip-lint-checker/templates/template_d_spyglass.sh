#!/bin/bash
# Template D: SpyGlass Lint — 专业级 CDC/Lint/RDC
# 由 chip-lint-checker 生成
# 用法: source 本文件，或在 run_lint.sh 中引用
# 前置条件: 已安装 Synopsys SpyGlass

TOP=$1
shift
RTL_FILES="$@"
REPORT_DIR="ds/report/lint"
SGDC_FILE="${SGDC:-ds/run/${TOP}.sgdc}"
SPYGLASS="spyglass"

# 自动生成 SGDC 约束文件（如未提供）
if [ ! -f "$SGDC_FILE" ]; then
    cat > "$SGDC_FILE" << SGDC_EOF
# Auto-generated SGDC constraints for ${TOP}
current_design ${TOP}

# Clock definitions — 按实际时钟修改
#create_clock -name clk -period 10 [get_ports clk]
#create_clock -name clk_slow -period 20 [get_ports clk_slow]

# Reset definitions
#set_reset -async rst_n

# CDC false paths
#set_false_path -from [get_clocks clk] -to [get_clocks clk_slow]

# Blackbox modules
#set_blackbox u_ip_block
SGDC_EOF
    echo "[SGDC-AUTO] Generated $SGDC_FILE — 请按实际设计修改时钟和复位定义"
fi

echo "=== Phase E: SpyGlass Lint ==="
$SPYGLASS -project ${TOP}_lint.prj \
    -goal lint/lint_rtl \
    -goal lint/lint_turbo_rtl \
    -sgdc $SGDC_FILE \
    -read_options_file spyglass.opt \
    2>&1 | tee "$REPORT_DIR/E_spyglass.log"
SPYGLASS_RET=${PIPESTATUS[0]}

if [ $SPYGLASS_RET -eq 0 ]; then
    echo "Phase E (SpyGlass): PASS" >> "$REPORT_DIR/lint_summary.log"
else
    echo "Phase E (SpyGlass): FAIL" >> "$REPORT_DIR/lint_summary.log"
fi
exit $SPYGLASS_RET
