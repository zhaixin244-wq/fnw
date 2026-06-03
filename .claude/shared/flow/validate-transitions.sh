#!/bin/bash
# chip-requirement-arch 跳转验证脚本
# 用途：检查 PR 沟通记录中的阶段标记完整性
# 使用：bash validate-transitions.sh <pr_file>

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${RED}错误：请提供 PR 沟通记录文件路径${NC}"
    echo "使用：bash validate-transitions.sh <pr_file>"
    exit 1
fi

PR_FILE="$1"

if [ ! -f "$PR_FILE" ]; then
    echo -e "${RED}错误：文件不存在 - $PR_FILE${NC}"
    exit 1
fi

echo "=========================================="
echo "chip-requirement-arch 跳转验证报告"
echo "=========================================="
echo "文件：$PR_FILE"
echo "时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 初始化计数器
PASS=0
FAIL=0
WARN=0

# 检查函数
check_marker() {
    local marker="$1"
    local description="$2"
    local required="${3:-true}"

    if grep -qF "$marker" "$PR_FILE"; then
        echo -e "${GREEN}✅ PASS${NC} - $description"
        PASS=$((PASS + 1))
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}❌ FAIL${NC} - $description（缺失标记：$marker）"
            FAIL=$((FAIL + 1))
        else
            echo -e "${YELLOW}⚠️ WARN${NC} - $description（可选标记缺失：$marker）"
            WARN=$((WARN + 1))
        fi
        return 1
    fi
}

# 检查阶段标记配对
check_pair() {
    local start_marker="$1"
    local end_marker="$2"
    local stage_name="$3"

    local has_start
    local has_end
    has_start=$(grep -cF "$start_marker" "$PR_FILE" 2>/dev/null) || has_start=0
    has_end=$(grep -cF "$end_marker" "$PR_FILE" 2>/dev/null) || has_end=0

    if [ "$has_start" -gt 0 ] && [ "$has_end" -gt 0 ]; then
        echo -e "${GREEN}✅ PASS${NC} - $stage_name 标记配对完整（START: $has_start, END: $has_end）"
        PASS=$((PASS + 1))
    elif [ "$has_start" -gt 0 ] && [ "$has_end" -eq 0 ]; then
        echo -e "${RED}❌ FAIL${NC} - $stage_name 缺少 END 标记（START: $has_start, END: 0）"
        FAIL=$((FAIL + 1))
    elif [ "$has_start" -eq 0 ] && [ "$has_end" -gt 0 ]; then
        echo -e "${RED}❌ FAIL${NC} - $stage_name 缺少 START 标记（START: 0, END: $has_end）"
        FAIL=$((FAIL + 1))
    else
        echo -e "${YELLOW}⚠️ WARN${NC} - $stage_name 未执行（START: 0, END: 0）"
        WARN=$((WARN + 1))
    fi
}

echo "【1. 阶段标记检查】"
echo "------------------------------------------"

# 检查主要阶段标记
check_pair "\[STAGE-START\] stage0" "\[STAGE-END\] stage0" "stage0"
check_pair "\[STAGE-START\] stageA" "\[STAGE-END\] stageA" "stageA"
check_pair "\[PHASE-START\] stageB phase1" "\[PHASE-END\] stageB phase1" "stageB phase1"
check_pair "\[PHASE-START\] stageB phase2" "\[PHASE-END\] stageB phase2" "stageB phase2"
check_pair "\[PHASE-START\] stageC phase1" "\[PHASE-END\] stageC phase1" "stageC phase1"
check_pair "\[PHASE-START\] stageC phase2" "\[PHASE-END\] stageC phase2" "stageC phase2"

echo ""
echo "【2. stageD step 标记检查】"
echo "------------------------------------------"

# 检查 stageD step 标记
STAGED_STEPS=(
    "stageD group1-step1"
    "stageD group1-step2"
    "stageD group1-step3"
    "stageD group2-step1"
    "stageD group2-step2"
    "stageD group2-step3"
    "stageD group2-step4"
    "stageD group3-step1"
    "stageD group3-step2"
    "stageD group3-step3"
    "stageD group3-step4"
    "stageD group4-step1"
    "stageD group4-step2"
    "stageD group4-step3"
    "stageD group5-step1"
    "stageD group5-step2"
    "stageD group5-step3"
    "stageD group5-step4"
    "stageD group5-step5"
    "stageD group5-step6"
)

for step in "${STAGED_STEPS[@]}"; do
    check_pair "\[STEP-START\] $step" "\[STEP-END\] $step" "$step" || true
done

echo ""
echo "【3. 特殊标记检查】"
echo "------------------------------------------"

# 检查特殊标记
check_marker "\[STEP-PAUSE\]" "步进暂停标记" "true"
check_marker "\[STAGE-TRANSITION\]" "阶段跳转标记" "false"
check_marker "\[PROGRESS\]" "进度标记" "false"

echo ""
echo "【4. stageE/F 标记检查】"
echo "------------------------------------------"

# 检查 stageE/F 标记
check_pair "\[STAGE-START\] stageE" "\[STAGE-END\] stageE" "stageE" || true
check_pair "\[STAGE-START\] stageF" "\[STAGE-END\] stageF" "stageF" || true

echo ""
echo "【5. 跳转顺序检查】"
echo "------------------------------------------"

# 检查 stageD group2 的执行顺序（step3 应在 step4 之前，自然编号顺序）
if grep -qF "[STEP-START] stageD group2-step3" "$PR_FILE" && grep -qF "[STEP-START] stageD group2-step4" "$PR_FILE"; then
    LINE_STEP3=$(grep -nF "[STEP-START] stageD group2-step3" "$PR_FILE" | head -1 | cut -d: -f1)
    LINE_STEP4=$(grep -nF "[STEP-START] stageD group2-step4" "$PR_FILE" | head -1 | cut -d: -f1)

    if [ "$LINE_STEP3" -lt "$LINE_STEP4" ]; then
        echo -e "${GREEN}✅ PASS${NC} - stageD group2 执行顺序正确（step3 在 step4 之前）"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}❌ FAIL${NC} - stageD group2 执行顺序错误（step3 应在 step4 之前）"
        FAIL=$((FAIL + 1))
    fi
else
    echo -e "${YELLOW}⚠️ WARN${NC} - stageD group2 step3/step4 未完全执行，跳过顺序检查"
    WARN=$((WARN + 1))
fi

# 检查 stageB phase1 → phase2 跳转
if grep -qF "[PHASE-END] stageB phase1" "$PR_FILE" && grep -qF "[PHASE-START] stageB phase2" "$PR_FILE"; then
    LINE_P1_END=$(grep -nF "[PHASE-END] stageB phase1" "$PR_FILE" | tail -1 | cut -d: -f1)
    LINE_P2_START=$(grep -nF "[PHASE-START] stageB phase2" "$PR_FILE" | head -1 | cut -d: -f1)

    if [ "$LINE_P1_END" -lt "$LINE_P2_START" ]; then
        echo -e "${GREEN}✅ PASS${NC} - stageB phase1 → phase2 跳转顺序正确"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}❌ FAIL${NC} - stageB phase1 → phase2 跳转顺序错误"
        FAIL=$((FAIL + 1))
    fi
else
    echo -e "${YELLOW}⚠️ WARN${NC} - stageB phase1/phase2 未完全执行，跳过跳转检查"
    WARN=$((WARN + 1))
fi

echo ""
echo "=========================================="
echo "验证结果汇总"
echo "=========================================="
echo -e "${GREEN}通过：$PASS${NC}"
echo -e "${RED}失败：$FAIL${NC}"
echo -e "${YELLOW}警告：$WARN${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ 验证通过！所有必需标记完整。${NC}"
    exit 0
else
    echo -e "${RED}❌ 验证失败！存在 $FAIL 个问题需要修复。${NC}"
    exit 1
fi
