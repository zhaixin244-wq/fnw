#!/bin/bash
# 变更检测脚本 — 对比微架构文档 git diff，自动识别变更区域并输出影响范围
# 用法: bash change-detect.sh <microarch_doc_path> [base_commit]
# 输出: JSON 格式的变更影响报告

set -euo pipefail

DOC_PATH="${1:?Usage: change-detect.sh <microarch_doc_path> [base_commit_or_mtime_file]}"
BASE_COMMIT="${2:-HEAD~1}"

if [ ! -f "$DOC_PATH" ]; then
    echo '{"error": "File not found: '"$DOC_PATH"'"}'
    exit 1
fi

# 检测是否在 git 仓库中
IS_GIT=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IS_GIT=true
fi

# 获取文件的变更内容
get_diff() {
    if [ "$IS_GIT" = true ]; then
        # Git 模式：对比 commit
        git diff "$BASE_COMMIT" -- "$DOC_PATH" 2>/dev/null || echo ""
    else
        # 非 Git 模式：对比 mtime 文件
        # BASE_COMMIT 此时为旧文件路径或 .mtime 时间戳文件
        local mtime_file="$DOC_PATH.mtime"
        if [ -f "$mtime_file" ]; then
            local old_mtime new_mtime
            old_mtime=$(cat "$mtime_file" 2>/dev/null || echo "0")
            new_mtime=$(stat -c %Y "$DOC_PATH" 2>/dev/null || stat -f %m "$DOC_PATH" 2>/dev/null || echo "0")
            if [ "$new_mtime" -gt "$old_mtime" ]; then
                echo "[MTIME-CHANGED] File modified since last check (old=$old_mtime, new=$new_mtime)"
            else
                echo ""
            fi
        else
            # 首次检测，记录当前 mtime
            local current_mtime
            current_mtime=$(stat -c %Y "$DOC_PATH" 2>/dev/null || stat -f %m "$DOC_PATH" 2>/dev/null || date +%s)
            echo "$current_mtime" > "$mtime_file"
            echo '{"changed": false, "mode": "mtime_init", "message": "First run, mtime baseline set"}'
            exit 0
        fi
    fi
}

DIFF=$(get_diff)

if [ -z "$DIFF" ]; then
    echo '{"changed": false, "message": "No changes detected"}'
    exit 0
fi

# 解析变更的章节
declare -A SECTION_IMPACTS

# 检测 §4.1 端口变更
if echo "$DIFF" | grep -qE '^\+.*§4\.1|^\+.*端口列表|^\+.*信号名.*方向.*位宽'; then
    SECTION_IMPACTS["§4.1"]="critical:RTL端口+SDC+SVA+TB需要重新实现"
fi

# 检测 §5.3 FSM 变更
if echo "$DIFF" | grep -qE '^\+.*§5\.3|^\+.*状态机|^\+.*S_[A-Z]+|^\+.*state_nxt|^\+.*转移条件'; then
    SECTION_IMPACTS["§5.3"]="critical:RTL控制逻辑+SVA需要重新实现"
fi

# 检测 §5.5 FIFO 变更
if echo "$DIFF" | grep -qE '^\+.*§5\.5|^\+.*FIFO.*深度|^\+.*深度.*=|^\+.*wr_ptr|^\+.*rd_ptr'; then
    SECTION_IMPACTS["§5.5"]="critical:RTL FIFO模块需要重新实现"
fi

# 检测 §5.6 CBB 变更
if echo "$DIFF" | grep -qE '^\+.*§5\.6|^\+.*CBB|^\+.*IP.*集成|^\+.*实例化参数'; then
    SECTION_IMPACTS["§5.6"]="critical:RTL CBB实例化需要重新实现"
fi

# 检测 §6 时钟变更
if echo "$DIFF" | grep -qE '^\+.*§6|^\+.*时钟频率|^\+.*create_clock|^\+.*period'; then
    SECTION_IMPACTS["§6"]="major:SDC约束需要更新"
fi

# 检测 §10 验证场景变更
if echo "$DIFF" | grep -qE '^\+.*§10|^\+.*验证场景|^\+.*SVA|^\+.*断言'; then
    SECTION_IMPACTS["§10"]="major:SVA断言需要更新"
fi

# 检测描述性内容变更（无影响）
if echo "$DIFF" | grep -qE '^\+.*§3|^\+.*概述|^\+.*功能定位|^\+.*§8.*PPA'; then
    SECTION_IMPACTS["§3/§8"]="info:描述性内容变更，无需更新RTL"
fi

# 输出 JSON 报告
echo "{"
echo '  "changed": true,'
echo '  "file": "'"$DOC_PATH"'",'
echo '  "mode": "'"$([ "$IS_GIT" = true ] && echo "git" || echo "mtime")"'",'
echo '  "base": "'"$BASE_COMMIT"'",'
echo '  "impacts": ['

FIRST=true
for section in "${!SECTION_IMPACTS[@]}"; do
    IFS=':' read -r severity desc <<< "${SECTION_IMPACTS[$section]}"
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ","
    fi
    echo -n '    {"section": "'"$section"'", "severity": "'"$severity"'", "description": "'"$desc"'"}'
done

echo ""
echo "  ],"

# 汇总
CRITICAL_COUNT=0
MAJOR_COUNT=0
for section in "${!SECTION_IMPACTS[@]}"; do
    severity="${SECTION_IMPACTS[$section]%%:*}"
    case "$severity" in
        critical) CRITICAL_COUNT=$((CRITICAL_COUNT + 1)) ;;
        major) MAJOR_COUNT=$((MAJOR_COUNT + 1)) ;;
    esac
done

echo '  "summary": {'
echo '    "critical": '"$CRITICAL_COUNT"','
echo '    "major": '"$MAJOR_COUNT"','
echo '    "action": "'"$([ $CRITICAL_COUNT -gt 0 ] && echo "强制重新实现" || ([ $MAJOR_COUNT -gt 0 ] && echo "部分更新" || echo "无需更新"))"'"'
echo "  }"
echo "}"
