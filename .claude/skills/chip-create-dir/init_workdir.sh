#!/bin/bash
# ============================================================================
# Script   : init_workdir.sh
# Function : 初始化芯片模块工作目录结构
# Usage    : bash init_workdir.sh <module_name> [parent_dir]
# ============================================================================

set -e

MODULE_NAME="${1:?用法: bash init_workdir.sh <module_name> [parent_dir]}"
PARENT_DIR="${2:-.}"
WORK_DIR="${PARENT_DIR}/${MODULE_NAME}_work"

if [ -d "$WORK_DIR" ]; then
    echo "[WARN] 目录已存在: $WORK_DIR"
    exit 1
fi

echo "=== 初始化模块工作目录: ${MODULE_NAME} ==="
echo "根目录: ${WORK_DIR}"

# ds/doc 3级目录
DS_DOC_PR="${WORK_DIR}/ds/doc/pr"
DS_DOC_FS="${WORK_DIR}/ds/doc/fs"
DS_DOC_UA="${WORK_DIR}/ds/doc/ua"
DS_DOC_REPORT="${WORK_DIR}/ds/doc/report"

# ds 2级目录
DS_RTL="${WORK_DIR}/ds/rtl"
DS_LIB="${WORK_DIR}/ds/lib"
DS_COMMON="${WORK_DIR}/ds/common"
DS_RUN="${WORK_DIR}/ds/run"

# dv/doc 3级目录
DV_DOC_CHK="${WORK_DIR}/dv/doc/chk_point"
DV_DOC_PLAN="${WORK_DIR}/dv/doc/plan"
DV_DOC_REPORT="${WORK_DIR}/dv/doc/report"

# dv 2级目录
DV_ENV="${WORK_DIR}/dv/env"
DV_TB="${WORK_DIR}/dv/tb"
DV_CASE="${WORK_DIR}/dv/case"
DV_RAL="${WORK_DIR}/dv/ral"
DV_RUN="${WORK_DIR}/dv/run"

# 创建所有目录
mkdir -p \
    "$DS_DOC_PR" \
    "$DS_DOC_FS" \
    "$DS_DOC_UA" \
    "$DS_DOC_REPORT" \
    "$DS_RTL" \
    "$DS_LIB" \
    "$DS_COMMON" \
    "$DS_RUN" \
    "$DV_DOC_CHK" \
    "$DV_DOC_PLAN" \
    "$DV_DOC_REPORT" \
    "$DV_ENV" \
    "$DV_TB" \
    "$DV_CASE" \
    "$DV_RAL" \
    "$DV_RUN"

# 输出目录树
echo ""
echo "目录结构:"
echo "${MODULE_NAME}_work/"
echo "├── ds/"
echo "│   ├── doc/"
echo "│   │   ├── pr/          # PR 原始资料"
echo "│   │   ├── fs/          # 功能规格书"
echo "│   │   ├── ua/          # 微架构规格书"
echo "│   │   └── report/      # 设计报告"
echo "│   ├── rtl/             # RTL 源码"
echo "│   ├── lib/             # IP/CBB 库"
echo "│   ├── common/          # 公共头文件 (.vh) / Interface (.sv)"
echo "│   └── run/             # 综合/实现运行目录"
echo "└── dv/"
echo "    ├── doc/"
echo "    │   ├── chk_point/   # 验证检查点"
echo "    │   ├── plan/        # 验证计划"
echo "    │   └── report/      # 验证报告"
echo "    ├── env/             # 验证环境"
echo "    ├── tb/              # Testbench"
echo "    ├── case/            # 测试用例"
echo "    ├── ral/             # 寄存器抽象层"
echo "    └── run/             # 仿真运行目录"
echo ""
echo "=== 初始化完成 ==="
