#!/bin/bash
# RTL 综合 Lint — Verilator + Verible 双重检查
# 用法: bash .claude/shared/rtl-lint.sh <file.v> [--fix]

FILE="$1"
FIX_MODE=false
[[ "$2" == "--fix" ]] && FIX_MODE=true

VERILATOR=".claude/tools/oss-cad-suite/bin/verilator"
VERIBLE_LINT=".claude/tools/verible/verible-verilog-lint.exe"
VERIBLE_FMT=".claude/tools/verible/verible-verilog-format.exe"
VERIBLE_SYNTAX=".claude/tools/verible/verible-verilog-syntax.exe"
RULES=".claude/tools/verible/verible-lint.rules"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -z "$FILE" ]]; then
    echo "用法: bash .claude/shared/rtl-lint.sh <file.v> [--fix]"
    echo "  --fix  自动格式化（仅 Verible）"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    echo -e "${RED}[ERROR]${NC} 文件不存在: $FILE"
    exit 1
fi

echo -e "${BLUE}=== RTL Lint: $FILE ===${NC}"
echo ""

# ─────────────────────────────────────────────
# Step 1: Verible 语法检查
# ─────────────────────────────────────────────
echo -e "${BLUE}--- Step 1: Verible 语法检查 ---${NC}"
SYNTAX_OUT=$("$VERIBLE_SYNTAX" "$FILE" 2>&1)
SYNTAX_EXIT=$?
if [[ $SYNTAX_EXIT -eq 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} 语法检查通过"
else
    echo -e "${RED}[FAIL]${NC} 语法错误："
    echo "$SYNTAX_OUT"
fi
echo ""

# ─────────────────────────────────────────────
# Step 2: Verible 风格 lint
# ─────────────────────────────────────────────
echo -e "${BLUE}--- Step 2: Verible 风格检查 ---${NC}"
LINT_OUT=$("$VERIBLE_LINT" --rules_config="$RULES" "$FILE" 2>&1)
LINT_EXIT=$?
if [[ $LINT_EXIT -eq 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} 风格检查通过"
else
    echo -e "${YELLOW}[WARN]${NC} 风格问题："
    echo "$LINT_OUT"
fi
echo ""

# ─────────────────────────────────────────────
# Step 3: Verilator 功能 lint
# ─────────────────────────────────────────────
echo -e "${BLUE}--- Step 3: Verilator 功能检查 ---${NC}"
if [[ -f "$VERILATOR" ]]; then
    VERILATOR_OUT=$("$VERILATOR" --lint-only -Wall "$FILE" 2>&1)
    VERILATOR_EXIT=$?
    if [[ $VERILATOR_EXIT -eq 0 ]]; then
        echo -e "${GREEN}[PASS]${NC} Verilator lint 通过"
    else
        # 检查是否是 Perl 模块问题（环境依赖）
        if echo "$VERILATOR_OUT" | grep -q "Pod/Usage.pm"; then
            echo -e "${YELLOW}[SKIP]${NC} Verilator 环境依赖缺失（Pod::Usage）"
            VERILATOR_EXIT=0
        else
            echo -e "${RED}[FAIL]${NC} Verilator 问题："
            echo "$VERILATOR_OUT"
        fi
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} Verilator 不可用（路径: $VERILATOR）"
    VERILATOR_EXIT=0
fi
echo ""

# ─────────────────────────────────────────────
# Step 4: 自动格式化（可选）
# ─────────────────────────────────────────────
if [[ "$FIX_MODE" == "true" ]]; then
    echo -e "${BLUE}--- Step 4: Verible 自动格式化 ---${NC}"
    FMT_OUT=$("$VERIBLE_FMT" --inplace "$FILE" 2>&1)
    FMT_EXIT=$?
    if [[ $FMT_EXIT -eq 0 ]]; then
        echo -e "${GREEN}[FIXED]${NC} 格式化完成"
    else
        echo -e "${RED}[ERROR]${NC} 格式化失败："
        echo "$FMT_OUT"
    fi
    echo ""
fi

# ─────────────────────────────────────────────
# 总结
# ─────────────────────────────────────────────
echo -e "${BLUE}=== 检查总结 ===${NC}"
[[ $SYNTAX_EXIT -eq 0 ]] && echo -e "  语法检查: ${GREEN}PASS${NC}" || echo -e "  语法检查: ${RED}FAIL${NC}"
[[ $LINT_EXIT -eq 0 ]] && echo -e "  风格检查: ${GREEN}PASS${NC}" || echo -e "  风格检查: ${YELLOW}WARN${NC}"
[[ $VERILATOR_EXIT -eq 0 ]] && echo -e "  功能检查: ${GREEN}PASS${NC}" || echo -e "  功能检查: ${RED}FAIL${NC}"

# 如果有任何失败，返回非零
if [[ $SYNTAX_EXIT -ne 0 || $VERILATOR_EXIT -ne 0 ]]; then
    exit 1
fi
