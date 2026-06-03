#!/bin/bash
# ============================================================
# validate-requirement-arch-output.sh
# 校验 chip-requirement-arch Agent 输出完整性
# 版本：v6.0（支持 stage/phase/group/step 编码）
# ============================================================

set -e

MODULE=$1
WORK_DIR="${MODULE}_work"
PR_DIR="${WORK_DIR}/ds/doc/pr"
ERRORS=0
WARNINGS=0

echo "=========================================="
echo "校验 Agent 输出: ${MODULE}"
echo "=========================================="

# ===== 1. 校验顶层 PR 目录结构 =====
echo ""
echo "[1/6] 校验顶层 PR 目录结构..."

check_dir() {
    local dir=$1
    local desc=$2
    if [ -d "$dir" ]; then
        echo "  ✅ $desc"
    else
        echo "  ❌ $desc (缺失)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_dir "${PR_DIR}" "PR 根目录"
check_dir "${PR_DIR}/output" "交付物目录 (output/)"
check_dir "${PR_DIR}/flow" "流程记录目录 (flow/)"

# ===== 2. 校验核心交付物 =====
echo ""
echo "[2/6] 校验核心交付物..."

check_file() {
    local file=$1
    local desc=$2
    if [ -f "$file" ]; then
        echo "  ✅ $desc"
    else
        echo "  ❌ $desc (缺失)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_file "${PR_DIR}/flow/${MODULE}_pr_v1.0.md" "PR 沟通记录"
check_file "${PR_DIR}/output/${MODULE}_requirement_summary_v1.0.md" "需求汇总表 (stageC phase2)"
check_file "${PR_DIR}/output/${MODULE}_solution_v1.0.md" "统一方案文档 (stageD)"
check_file "${PR_DIR}/output/${MODULE}_ADR_v1.0.md" "ADR 文档"

# ===== 3. 校验 stage/phase 完整性 =====
echo ""
echo "[3/6] 校验 stage/phase 完整性..."

PR_FILE="${PR_DIR}/flow/${MODULE}_pr_v1.0.md"

check_phase() {
    local phase=$1
    local desc=$2
    if [ -f "$PR_FILE" ] && grep -q "$phase" "$PR_FILE"; then
        echo "  ✅ $desc: 包含 $phase 记录"
    else
        echo "  ❌ $desc: 缺少 $phase 记录"
        ERRORS=$((ERRORS + 1))
    fi
}

check_phase "stage0" "前置探索"
check_phase "stageA" "最小信息集"
check_phase "stageB phase1" "约束检查（28项）"
check_phase "stageB phase2" "头脑风暴（5维度）"
check_phase "stageC phase1" "矛盾检测"
check_phase "stageC phase2" "需求汇总"

# ===== 4. 校验 stageB phase2 头脑风暴 =====
echo ""
echo "[4/6] 校验 stageB phase2 头脑风暴..."

REQ_FILE="${PR_DIR}/output/${MODULE}_requirement_summary_v1.0.md"
PR_FILE_CHECK="${PR_DIR}/flow/${MODULE}_pr_v1.0.md"

if [ -f "$REQ_FILE" ]; then
    if grep -q "REQ-029" "$REQ_FILE"; then
        echo "  ✅ stageB phase2 追加 REQ: 包含 REQ-029 起始"
        BPLUS_REQ_COUNT=$(grep -c "REQ-0[2-3][0-9]" "$REQ_FILE" || true)
        echo "  ✅ 追加 REQ 数量: ${BPLUS_REQ_COUNT} 项"
    elif grep -q "头脑风暴未发现新需求\|未发现新需求\|无新需求" "$PR_FILE_CHECK" 2>/dev/null; then
        echo "  ✅ stageB phase2 已执行: 头脑风暴未发现新需求（正常）"
    else
        echo "  ❌ stageB phase2: 缺少 REQ-029 且无'未发现新需求'标记"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  ❌ 需求汇总表不存在，无法校验"
    ERRORS=$((ERRORS + 1))
fi

# ===== 5. 校验 stageD 方案文档 =====
echo ""
echo "[5/6] 校验 stageD 方案文档..."

SOLUTION_FILE="${PR_DIR}/output/${MODULE}_solution_v1.0.md"

if [ -f "$SOLUTION_FILE" ]; then
    echo "  ✅ 统一方案文档存在: ${MODULE}_solution_v1.0.md"

    # 检查 group/step 章节（20 个 step）
    STEP_SECTIONS=(
        "group1-step1:初始架构方案"
        "group1-step2:CBB选型"
        "group1-step3:子模块划分"
        "group2-step1:数据通路"
        "group2-step2:流水线"
        "group2-step3:控制逻辑"
        "group2-step4:性能优化"
        "group3-step1:SRAM"
        "group3-step2:FIFO"
        "group3-step3:链表"
        "group3-step4:寄存器"
        "group4-step1:调度"
        "group4-step2:流控"
        "group4-step3:CDC"
        "group5-step1:面积"
        "group5-step2:时序"
        "group5-step3:DFX"
        "group5-step4:可靠性"
        "group5-step5:接口"
        "group5-step6:功耗"
    )

    STEP_COUNT=0
    for item in "${STEP_SECTIONS[@]}"; do
        IFS=':' read -r step desc <<< "$item"
        if grep -q "$desc" "$SOLUTION_FILE"; then
            STEP_COUNT=$((STEP_COUNT + 1))
        fi
    done

    echo "  ℹ️ stageD step 章节: ${STEP_COUNT}/20 个已生成"

    # 检查关键章节
    KEY_SECTIONS=("架构概述" "接口定义" "数据通路" "PPA 预估" "追溯矩阵")

    for desc in "${KEY_SECTIONS[@]}"; do
        if grep -q "$desc" "$SOLUTION_FILE"; then
            echo "    ✅ ${desc}"
        else
            echo "    ⚠️ ${desc} 缺失"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
else
    echo "  ❌ 统一方案文档不存在"
    ERRORS=$((ERRORS + 1))
fi

# ===== 6. 校验 stageE 递归分解 =====
echo ""
echo "[6/6] 校验 stageE 递归分解..."

# 检查子模块 PR 目录（lx_*_pr 格式）
SUBMODULE_PR_DIRS=$(find "${PR_DIR}" -maxdepth 1 -type d -name "level*_*" 2>/dev/null | wc -l || echo "0")

if [ "$SUBMODULE_PR_DIRS" -gt 0 ]; then
    echo "  ✅ 子模块 PR 目录: 发现 ${SUBMODULE_PR_DIRS} 个"

    for subdir in $(find "${PR_DIR}" -maxdepth 1 -type d -name "level*_*"); do
        subname=$(basename "$subdir")
        if [ -d "${subdir}/output" ] && [ -d "${subdir}/flow" ]; then
            echo "    ✅ ${subname}: output/ + flow/ 完整"

            # 检查子模块 todolist
            if [ -f "${subdir}/flow/todolist.md" ]; then
                if grep -q "⬜" "${subdir}/flow/todolist.md"; then
                    echo "      ⚠️ 子模块 todolist 存在未完成项"
                    WARNINGS=$((WARNINGS + 1))
                else
                    echo "      ✅ 子模块 todolist 已完成"
                fi
            fi
        else
            echo "    ❌ ${subname}: 缺少 output/ 或 flow/"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo "  ⚠️ 未发现 level*_* 目录（可能未执行 stageE）"
    WARNINGS=$((WARNINGS + 1))
fi

# ===== 输出统计 =====
echo ""
echo "=========================================="
echo "校验完成"
echo "=========================================="

echo ""
echo "编码规则说明："
echo "  大阶段: stage0, stageA, stageB, stageC, stageD, stageE, stageF"
echo "  子阶段:"
echo "    - stageB phase1: 约束检查（28项）"
echo "    - stageB phase2: 头脑风暴（5维度）"
echo "    - stageC phase1: 矛盾检测"
echo "    - stageC phase2: 需求汇总"
echo "    - stageD group1~group5: 方案细化（5个大阶段）"
echo "    - stageD groupX-stepY: 方案细化（20个子阶段）"
echo "  递归层: level0, level1, level2, ..."

echo ""
echo "目录结构说明："
echo "  ${PR_DIR}/"
echo "  ├── output/           (交付物)"
echo "  │   ├── {module}_requirement_summary.md  (stageC phase2)"
echo "  │   ├── {module}_solution.md             (stageD, 统一方案文档)"
echo "  │   ├── {module}_ADR.md"
echo "  │   └── ..."
echo "  ├── flow/             (流程记录)"
echo "  │   ├── {module}_pr_v1.0.md"
echo "  │   └── todolist.md"
echo "  ├── level1_*/          (level1 子模块)"
echo "  │   ├── output/"
echo "  │   ├── flow/"
echo "  │   └── level2_*/      (level2 子模块)"
echo "  └── ..."

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "结果: ✅ 通过（${ERRORS} 错误, ${WARNINGS} 警告）"
    exit 0
else
    echo "结果: ❌ 失败（${ERRORS} 错误, ${WARNINGS} 警告）"
    exit 1
fi
