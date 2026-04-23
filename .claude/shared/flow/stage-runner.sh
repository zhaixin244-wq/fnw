#!/bin/bash
# Stage Runner — 执行前校验 inputs 类型，执行后记录 metrics
# 用法: source stage-runner.sh && validate_inputs <stage_id> && run_stage <stage_id>

set -euo pipefail

FLOW_JSON="$(dirname "$0")/impl-flow-stages.json"
METRICS_DIR=""

# ============================================================
# jq 可用性检测 + fallback
# ============================================================
HAS_JQ=false
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=true
fi

# JSON 解析 fallback（无 jq 时用 grep/sed 提取字段）
# 参数: $1=json_file $2=stage_id $3=field
json_get() {
    local json_file="$1" stage_id="$2" field="$3"
    if [ "$HAS_JQ" = true ]; then
        jq -r ".stages[] | select(.id==\"$stage_id\") | .$field // empty" "$json_file" 2>/dev/null
    else
        # fallback: 用 sed 提取 "id": "stage_id" 后的 field 值
        sed -n "/\"id\": *\"$stage_id\"/,/\"id\":/{ s/.*\"$field\": *\"\([^\"]*\)\".*/\1/p }" "$json_file" 2>/dev/null
    fi
}

# 提取 input 的 type 字段
# 参数: $1=json_file $2=stage_id $3=input_id
json_get_input_type() {
    local json_file="$1" stage_id="$2" input_id="$3"
    if [ "$HAS_JQ" = true ]; then
        jq -r ".stages[] | select(.id==\"$stage_id\") | .required_inputs[]? // .inputs[]? | select(.id==\"$input_id\") | .type" "$json_file" 2>/dev/null
    else
        # fallback: 在 stage 块内查找 input_id 的 type
        sed -n "/\"id\": *\"$stage_id\"/,/\"id\":/{ /\"id\": *\"$input_id\"/,/\}/{ s/.*\"type\": *\"\([^\"]*\)\".*/\1/p } }" "$json_file" 2>/dev/null
    fi
}

if [ "$HAS_JQ" = false ]; then
    echo "[STAGE-RUNNER] WARN: jq not found, using grep/sed fallback (limited functionality)"
fi

# ============================================================
# 类型校验函数
# ============================================================

# 校验单个 input 的类型
# 参数: $1=input_id $2=type $3=value
validate_type() {
    local input_id="$1" type="$2" value="$3"

    case "$type" in
        file_path)
            if [ ! -f "$value" ] && [ ! -d "$value" ]; then
                echo "[TYPE-ERROR] $input_id: file_path '$value' not found"
                return 1
            fi
            ;;
        array)
            # 检查是否为非空（值以逗号分隔或为 JSON 数组）
            if [ -z "$value" ] || [ "$value" = "[]" ]; then
                echo "[TYPE-ERROR] $input_id: array is empty"
                return 1
            fi
            ;;
        object)
            # 检查是否为非空 JSON 对象
            if [ -z "$value" ] || [ "$value" = "{}" ]; then
                echo "[TYPE-ERROR] $input_id: object is empty"
                return 1
            fi
            ;;
        string)
            # 检查是否为非空字符串
            if [ -z "$value" ]; then
                echo "[TYPE-ERROR] $input_id: string is empty"
                return 1
            fi
            ;;
        *)
            echo "[TYPE-WARN] $input_id: unknown type '$type', skipping validation"
            ;;
    esac
    return 0
}

# 校验 stage 的所有 required_inputs
# 参数: $1=stage_id $2...=input_id=value pairs
validate_inputs() {
    local stage_id="$1"
    shift
    local errors=0

    echo "[STAGE-RUNNER] Validating inputs for stage: $stage_id"

    for pair in "$@"; do
        local input_id="${pair%%=*}"
        local value="${pair#*=}"
        local type

        # 从 JSON 中提取 type
        type=$(json_get_input_type "$FLOW_JSON" "$stage_id" "$input_id" || echo "unknown")

        if [ "$type" = "null" ] || [ -z "$type" ]; then
            type="unknown"
        fi

        if ! validate_type "$input_id" "$type" "$value"; then
            errors=$((errors + 1))
        fi
    done

    if [ $errors -gt 0 ]; then
        echo "[STAGE-RUNNER] Validation FAILED: $errors input(s) have type errors"
        return 1
    fi

    echo "[STAGE-RUNNER] Validation PASSED"
    return 0
}

# ============================================================
# Metrics 记录函数
# ============================================================

# 初始化 metrics 目录
init_metrics() {
    local work_dir="$1"
    METRICS_DIR="$work_dir/ds/report/metrics"
    mkdir -p "$METRICS_DIR"
}

# 记录 stage 开始时间
stage_start() {
    local stage_id="$1"
    local start_file="${METRICS_DIR}/${stage_id}.start"
    date +%s%3N > "$start_file"
    echo "[METRICS] Stage $stage_id started at $(date -Iseconds)"
}

# 记录 stage 结束并输出 metrics
stage_end() {
    local stage_id="$1"
    local iteration_count="${2:-1}"
    local start_file="${METRICS_DIR}/${stage_id}.start"
    local metrics_file="${METRICS_DIR}/${stage_id}.json"

    if [ ! -f "$start_file" ]; then
        echo "[METRICS] WARN: no start time for $stage_id"
        return 1
    fi

    local start_ms end_ms duration_ms
    start_ms=$(cat "$start_file")
    end_ms=$(date +%s%3N)
    duration_ms=$((end_ms - start_ms))

    cat > "$metrics_file" <<EOF
{
  "stage_id": "$stage_id",
  "start_time": $(date -d "@$((start_ms / 1000))" +%s 2>/dev/null || echo "$start_ms"),
  "end_time": $(date -d "@$((end_ms / 1000))" +%s 2>/dev/null || echo "$end_ms"),
  "duration_ms": $duration_ms,
  "iteration_count": $iteration_count
}
EOF

    echo "[METRICS] Stage $stage_id completed: ${duration_ms}ms, ${iteration_count} iteration(s)"
    rm -f "$start_file"
}

# ============================================================
# Gate 检查函数
# ============================================================

# 检查 stage 的 gate
# 参数: $1=stage_id $2=gate_result (pass/fail)
check_gate() {
    local stage_id="$1"
    local gate_result="$2"

    local on_failure
    on_failure=$(json_get "$FLOW_JSON" "$stage_id" "on_failure" || echo "pause")

    if [ "$gate_result" = "pass" ]; then
        echo "[GATE] Stage $stage_id: PASS"
        return 0
    fi

    echo "[GATE] Stage $stage_id: FAIL (on_failure=$on_failure)"
    case "$on_failure" in
        pause) echo "[GATE] Action: PAUSE — waiting for user confirmation" ;;
        self_heal) echo "[GATE] Action: SELF_HEAL — entering fix loop" ;;
        degrade) echo "[GATE] Action: DEGRADE — falling back to degraded mode" ;;
    esac
    return 1
}

# ============================================================
# 主流程：按 stage 顺序执行
# ============================================================

# 获取 stage 的 next
get_next_stage() {
    local stage_id="$1"
    json_get "$FLOW_JSON" "$stage_id" "next"
}

# 获取所有 stage ID 列表
get_stage_ids() {
    if [ "$HAS_JQ" = true ]; then
        jq -r '.stages[].id' "$FLOW_JSON" 2>/dev/null
    else
        grep -o '"id": *"[^"]*"' "$FLOW_JSON" | sed 's/"id": *"//;s/"//' | grep -v '^$'
    fi
}

echo "[STAGE-RUNNER] Loaded. Flow stages: $(get_stage_ids | tr '\n' ' ')"
