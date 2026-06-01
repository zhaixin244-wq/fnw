#!/bin/bash
# Wiki Lint — 知识库健康检查
# 用法: bash .claude/shared/wiki-lint.sh [--fix]
# 检查项: 孤立页面、死链接、缺失交叉引用、索引不一致、空页面、过期声明、格式不一致、来源追溯缺失

WIKI_DIR="tools/claude-obsidian/wiki"
INDEX_FILE="$WIKI_DIR/index.md"
REPORT_FILE="$WIKI_DIR/meta/lint-report.md"
FIX_MODE=false
[[ "$1" == "--fix" ]] && FIX_MODE=true

ERRORS=0
WARNINGS=0
FIXED=0

# 颜色
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log_error() { ((ERRORS++)); echo -e "${RED}[ERROR]${NC} $1"; }
log_warn()  { ((WARNINGS++)); echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fix()   { ((FIXED++)); echo -e "${GREEN}[FIXED]${NC} $1"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }

# 开始报告
cat > "$REPORT_FILE" << EOF
# Wiki Lint Report

> 生成时间：$(date '+%Y-%m-%d %H:%M')
> 模式：$( $FIX_MODE && echo "自动修复" || echo "仅检查" )

---

EOF

echo "=== Wiki Lint 开始 ==="
echo ""

# ─────────────────────────────────────────────
# 检查 1: 索引不一致 — index.md 条目 vs 实际文件
# ─────────────────────────────────────────────
echo "--- 检查 1: 索引一致性 ---"
if [[ -f "$INDEX_FILE" ]]; then
    # 提取 index.md 中引用的所有 .md 文件路径（支持 [text](path.md) 和 [[wikilink]] 两种格式）
    {
        grep -oP '\(([^)]+\.md)\)' "$INDEX_FILE" | tr -d '()'
        grep -oP '\[\[([^\]]+\.md)\]\]' "$INDEX_FILE" | sed 's/\[\[//;s/\]\]//'
        # 也匹配不带 .md 后缀的 wikilink（Obsidian 可省略后缀），排除已有其他后缀的
        grep -oP '\[\[([^\]]+)\]\]' "$INDEX_FILE" | sed 's/\[\[//;s/\]\]//' | grep -v '\.' | sed 's/$/.md/'
    } | sort -u > /tmp/wiki_index_refs.txt
    # 提取实际存在的 wiki 页面（排除 index.md 自身和 hot.md/lint-report.md）
    find "$WIKI_DIR" -name "*.md" ! -name "index.md" ! -name "hot.md" ! -name "lint-report.md" | sed "s|^$WIKI_DIR/||" | sort -u > /tmp/wiki_actual_files.txt

    # 在 index 中但不存在的文件
    while IFS= read -r ref; do
        # 对于带路径分隔符的引用，直接检查；对于纯文件名，递归查找
        if [[ "$ref" == *"/"* ]]; then
            if [[ ! -f "$WIKI_DIR/$ref" ]]; then
                log_error "索引引用不存在: $ref"
            fi
        else
            # 递归查找 .md 文件；如果没找到，也尝试不带后缀的匹配（如 .canvas）
            if ! find "$WIKI_DIR" -name "$ref" -print -quit 2>/dev/null | grep -q .; then
                ref_noext="${ref%.md}"
                if ! find "$WIKI_DIR" -name "${ref_noext}.*" -print -quit 2>/dev/null | grep -q .; then
                    log_error "索引引用不存在: $ref"
                fi
            fi
        fi
    done < /tmp/wiki_index_refs.txt

    # 存在但不在 index 中的文件
    while IFS= read -r file; do
        # 检查多种格式：完整路径、不带后缀的路径、纯文件名 wikilink
        path_noext="${file%.md}"
        basename_noext=$(basename "$file" .md)
        if ! grep -qF "$file" "$INDEX_FILE" 2>/dev/null && \
           ! grep -qF "[[$path_noext]]" "$INDEX_FILE" 2>/dev/null && \
           ! grep -qF "[[$basename_noext]]" "$INDEX_FILE" 2>/dev/null; then
            log_warn "文件未在索引中: $file"
        fi
    done < /tmp/wiki_actual_files.txt

    log_pass "索引一致性检查完成"
else
    log_error "index.md 不存在"
fi

# ─────────────────────────────────────────────
# 检查 2: 死链接 — markdown 链接目标不存在
# ─────────────────────────────────────────────
echo "--- 检查 2: 死链接 ---"
DEAD_LINKS=0
find "$WIKI_DIR" -name "*.md" | while read -r file; do
    # 提取 [text](path) 格式的本地文件链接（排除 URL 和学术引用）
    # 只匹配包含 / 或 . 的链接目标（文件路径特征），排除纯文本引用如 "2025"
    grep -oP '\[[^\]]*\]\(([^)]+)\)' "$file" | grep -oP '\(([^)]+)\)' | tr -d '()' | while read -r link; do
        # 跳过 URL 和锚点
        [[ "$link" == http* ]] && continue
        [[ "$link" == "#"* ]] && continue
        # 只检查含路径分隔符的本地文件引用，跳过纯文本（学术引用误匹配）
        [[ "$link" != *"/"* ]] && continue
        # 跳过含反斜杠的转义引用
        [[ "$link" == *\\* ]] && continue
        # 解析相对路径
        target="$(dirname "$file")/$link"
        target="${target%#*}"  # 去掉锚点
        # 如果相对路径不存在，尝试 vault root（Obsidian _attachments/ 路径）
        if [[ ! -f "$target" && "$link" == _attachments/* ]]; then
            target="$WIKI_DIR/../$link"
            target="${target%#*}"
        fi
        if [[ ! -f "$target" ]]; then
            log_error "死链接: $file -> $link"
            ((DEAD_LINKS++))
        fi
    done
done
[[ $DEAD_LINKS -eq 0 ]] && log_pass "死链接检查完成，无问题"

# ─────────────────────────────────────────────
# 检查 3: 空页面 — 内容过少
# ─────────────────────────────────────────────
echo "--- 检查 3: 空页面 ---"
MIN_LINES=20
find "$WIKI_DIR" -name "*.md" ! -name "index.md" ! -name "hot.md" ! -name "lint-report.md" | while read -r file; do
    lines=$(wc -l < "$file")
    if [[ $lines -lt $MIN_LINES ]]; then
        log_warn "页面内容过少 ($lines 行): $(basename "$file")"
    fi
done
log_pass "空页面检查完成"

# ─────────────────────────────────────────────
# 检查 4: 过期声明 — TODO/待补充/占位符
# ─────────────────────────────────────────────
echo "--- 检查 4: 过期声明 ---"
STALE_COUNT=0
STALE_PATTERNS="TODO|FIXME|待补充|待完善|占位|TBD|placeholder"
find "$WIKI_DIR" -name "*.md" | while read -r file; do
    matches=$(grep -ciP "($STALE_PATTERNS)" "$file" 2>/dev/null || true)
    if [[ $matches -gt 0 ]]; then
        log_warn "过期声明 ($matches 处): $(basename "$file")"
        ((STALE_COUNT += matches))
    fi
done
log_pass "过期声明检查完成"

# ─────────────────────────────────────────────
# 检查 5: 格式一致性 — 实体页面缺少标准章节
# ─────────────────────────────────────────────
echo "--- 检查 5: 格式一致性 ---"
REQUIRED_SECTIONS=("基本信息" "核心特征" "关键信号\|关键参数\|关键概念")
find "$WIKI_DIR/entities" -name "*.md" 2>/dev/null | while read -r file; do
    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -qiP "^#+\s*.*($section)" "$file" 2>/dev/null; then
            log_warn "缺少章节: $(basename "$file") — $section"
        fi
    done
done
log_pass "格式一致性检查完成"

# ─────────────────────────────────────────────
# 检查 6: 来源追溯 — 无知识来源标注
# ─────────────────────────────────────────────
echo "--- 检查 6: 来源追溯 ---"
find "$WIKI_DIR" -name "*.md" ! -name "index.md" ! -name "hot.md" ! -name "lint-report.md" | while read -r file; do
    if ! grep -qiP "(来源|source|参考|reference)" "$file" 2>/dev/null; then
        log_warn "来源追溯缺失: $(basename "$file")"
    fi
done
log_pass "来源追溯检查完成"

# ─────────────────────────────────────────────
# 检查 7: 孤立页面 — 无任何引用
# ─────────────────────────────────────────────
echo "--- 检查 7: 孤立页面 ---"
find "$WIKI_DIR" -name "*.md" ! -name "index.md" ! -name "hot.md" ! -name "lint-report.md" | while read -r file; do
    basename_noext=$(basename "$file" .md)
    # 检查是否被其他文件引用（排除自身）
    ref_count=$(grep -rl "$basename_noext" "$WIKI_DIR" --include="*.md" | grep -v "$file" | wc -l)
    if [[ $ref_count -eq 0 ]]; then
        log_warn "孤立页面（无引用）: $(basename "$file")"
    fi
done
log_pass "孤立页面检查完成"

# ─────────────────────────────────────────────
# 检查 8: 交叉引用完整性 — 相关实体间双向链接
# ─────────────────────────────────────────────
echo "--- 检查 8: 交叉引用完整性 ---"
# 检查比较页面中引用的实体是否也有反向引用
find "$WIKI_DIR/comparisons" -name "*.md" 2>/dev/null | while read -r file; do
    grep -oP '\(([^)]+\.md)\)' "$file" | tr -d '()' | while read -r ref; do
        target="$(dirname "$file")/$ref"
        [[ -f "$target" ]] || continue
        # 检查目标是否引用了当前比较页面
        if ! grep -q "$(basename "$file")" "$target" 2>/dev/null; then
            log_warn "单向引用: $(basename "$file") -> $(basename "$target")（无反向链接）"
        fi
    done
done
log_pass "交叉引用检查完成"

# ─────────────────────────────────────────────
# 生成报告摘要
# ─────────────────────────────────────────────
echo ""
echo "=== Wiki Lint 完成 ==="
echo "错误: $ERRORS | 警告: $WARNINGS | 已修复: $FIXED"

cat >> "$REPORT_FILE" << EOF
## 检查结果摘要

| 检查类型 | 错误 | 警告 | 状态 |
|----------|------|------|------|
| 索引一致性 | - | - | 已检查 |
| 死链接 | - | - | 已检查 |
| 空页面 | - | - | 已检查 |
| 过期声明 | - | - | 已检查 |
| 格式一致性 | - | - | 已检查 |
| 来源追溯 | - | - | 已检查 |
| 孤立页面 | - | - | 已检查 |
| 交叉引用 | - | - | 已检查 |

**总计**: 错误 $ERRORS | 警告 $WARNINGS | 已修复 $FIXED

## 建议

1. 优先修复死链接和索引不一致问题
2. 孤立页面考虑添加到 index.md 或删除
3. 过期声明页面应补充完整内容
4. 来源追溯有助于知识可信度
EOF

echo "报告已生成: $REPORT_FILE"
