#!/bin/bash
# Metrics 汇总脚本 — 汇总所有 stage 的 metrics 为一站式性能报告
# 用法: bash metrics-summary.sh <work_dir>
# 输出: 汇总表 + JSON 报告

set -euo pipefail

WORK_DIR="${1:?Usage: metrics-summary.sh <work_dir>}"
METRICS_DIR="$WORK_DIR/ds/report/metrics"

if [ ! -d "$METRICS_DIR" ]; then
    echo "[METRICS-SUMMARY] No metrics directory found at $METRICS_DIR"
    exit 1
fi

# ============================================================
# 汇总所有 stage metrics
# ============================================================

TOTAL_DURATION=0
TOTAL_ITERATIONS=0
STAGE_COUNT=0
HAS_JQ=false
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=true
fi

echo "=========================================="
echo "  RTL 实现流程 Metrics 汇总报告"
echo "  工作目录: $WORK_DIR"
echo "  生成时间: $(date -Iseconds)"
echo "=========================================="
echo ""
printf "%-20s %12s %10s\n" "Stage" "Duration(ms)" "Iterations"
printf "%-20s %12s %10s\n" "-----" "------------" "----------"

METRICS_FILES=$(find "$METRICS_DIR" -name "*.json" -type f 2>/dev/null | sort)

if [ -z "$METRICS_FILES" ]; then
    echo "[METRICS-SUMMARY] No metrics files found"
    exit 1
fi

for metrics_file in $METRICS_FILES; do
    stage_id=$(basename "$metrics_file" .json)

    if [ "$HAS_JQ" = true ]; then
        duration=$(jq -r '.duration_ms // 0' "$metrics_file" 2>/dev/null || echo "0")
        iterations=$(jq -r '.iteration_count // 0' "$metrics_file" 2>/dev/null || echo "0")
    else
        duration=$(grep -o '"duration_ms": *[0-9]*' "$metrics_file" | grep -o '[0-9]*' || echo "0")
        iterations=$(grep -o '"iteration_count": *[0-9]*' "$metrics_file" | grep -o '[0-9]*' || echo "0")
    fi

    printf "%-20s %12s %10s\n" "$stage_id" "$duration" "$iterations"
    TOTAL_DURATION=$((TOTAL_DURATION + duration))
    TOTAL_ITERATIONS=$((TOTAL_ITERATIONS + iterations))
    STAGE_COUNT=$((STAGE_COUNT + 1))
done

echo ""
printf "%-20s %12s %10s\n" "-----" "------------" "----------"
printf "%-20s %12s %10s\n" "TOTAL" "$TOTAL_DURATION" "$TOTAL_ITERATIONS"
echo ""

# ============================================================
# 性能分析
# ============================================================

echo "--- 性能分析 ---"

# 找出最慢的 stage
SLOWEST_STAGE=""
SLOWEST_DURATION=0
for metrics_file in $METRICS_FILES; do
    stage_id=$(basename "$metrics_file" .json)
    if [ "$HAS_JQ" = true ]; then
        duration=$(jq -r '.duration_ms // 0' "$metrics_file" 2>/dev/null || echo "0")
    else
        duration=$(grep -o '"duration_ms": *[0-9]*' "$metrics_file" | grep -o '[0-9]*' || echo "0")
    fi
    if [ "$duration" -gt "$SLOWEST_DURATION" ]; then
        SLOWEST_DURATION=$duration
        SLOWEST_STAGE=$stage_id
    fi
done

# 找出迭代最多的 stage
MOST_ITERATIONS_STAGE=""
MOST_ITERATIONS=0
for metrics_file in $METRICS_FILES; do
    stage_id=$(basename "$metrics_file" .json)
    if [ "$HAS_JQ" = true ]; then
        iterations=$(jq -r '.iteration_count // 0' "$metrics_file" 2>/dev/null || echo "0")
    else
        iterations=$(grep -o '"iteration_count": *[0-9]*' "$metrics_file" | grep -o '[0-9]*' || echo "0")
    fi
    if [ "$iterations" -gt "$MOST_ITERATIONS" ]; then
        MOST_ITERATIONS=$iterations
        MOST_ITERATIONS_STAGE=$stage_id
    fi
done

echo "  最慢 stage:    $SLOWEST_STAGE (${SLOWEST_DURATION}ms)"
echo "  最多次迭代:    $MOST_ITERATIONS_STAGE (${MOST_ITERATIONS} iterations)"
echo "  平均 stage 耗时: $((TOTAL_DURATION / STAGE_COUNT))ms"
echo ""

# ============================================================
# 输出 JSON 汇总报告
# ============================================================

SUMMARY_FILE="$METRICS_DIR/summary.json"
cat > "$SUMMARY_FILE" <<EOF
{
  "work_dir": "$WORK_DIR",
  "generated_at": "$(date -Iseconds)",
  "stage_count": $STAGE_COUNT,
  "total_duration_ms": $TOTAL_DURATION,
  "total_iterations": $TOTAL_ITERATIONS,
  "avg_duration_ms": $((TOTAL_DURATION / STAGE_COUNT)),
  "slowest_stage": "$SLOWEST_STAGE",
  "slowest_duration_ms": $SLOWEST_DURATION,
  "most_iterations_stage": "$MOST_ITERATIONS_STAGE",
  "most_iterations_count": $MOST_ITERATIONS
}
EOF

echo "  JSON 报告已保存: $SUMMARY_FILE"
