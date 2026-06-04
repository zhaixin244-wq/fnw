#!/bin/bash
# select_module.sh — 从 50 个复杂模块池中随机选择测试模块
# 用法: bash select_module.sh [模式] [数量]
# 模式: single | batch | full | balanced
# 数量: batch 模式下选择的模块数（默认 5）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POOL_FILE="${SCRIPT_DIR}/module_pool.json"
MATRIX_FILE="${SCRIPT_DIR}/coverage_matrix.json"

MODE="${1:-single}"
COUNT="${2:-5}"

if [ ! -f "$POOL_FILE" ]; then
    echo "ERROR: module_pool.json not found at $POOL_FILE"
    exit 1
fi

# 获取模块总数
TOTAL=$(grep -c '"id": "CM-' "$POOL_FILE")

echo "=========================================="
echo " chip-requirement-arch 复杂模块测试选择器"
echo "=========================================="
echo ""
echo "模块池: ${TOTAL} 个复杂模块 (40k+ RTL)"
echo "选择模式: ${MODE}"
echo ""

case "$MODE" in
    single)
        # 随机选择 1 个模块
        IDX=$((RANDOM % TOTAL + 1))
        MODULE=$(grep -m1 "\"id\": \"CM-$(printf '%02d' $IDX)\"" "$POOL_FILE" | sed 's/.*"id": "\(CM-[0-9]*\)".*/\1/')
        if [ -z "$MODULE" ]; then
            # fallback: 按行号取
            MODULE=$(grep '"id": "CM-' "$POOL_FILE" | sed -n "${IDX}p" | sed 's/.*"id": "\(CM-[0-9]*\)".*/\1/')
        fi
        echo "随机选中: ${MODULE}"
        echo ""
        # 输出模块详情
        python3 -c "
import json, sys
with open('${POOL_FILE}') as f:
    data = json.load(f)
for m in data['modules']:
    if m['id'] == '${MODULE}':
        print(f\"模块: {m['display_name']}\")
        print(f\"领域: {m['domain']}\")
        print(f\"RTL 预估: {m['rtl_estimate']:,} 行\")
        print(f\"用户角色: {m['user_persona']}\")
        print(f\"测试维度: {', '.join(m['test_focus'])}\")
        print(f\"复杂度标签: {', '.join(m['complexity_tags'])}\")
        print(f\"预期 REQ 数: {m['expected_req_count']}\")
        print(f\"超时: {m['timeout_minutes']} min\")
        print(f\"最大轮数: {m['max_dialog_rounds']}\")
        print()
        print(f\"初始输入: {m['initial_input']}\")
        break
" 2>/dev/null || echo "(python3 不可用，请手动查看 module_pool.json)"
        ;;

    batch)
        # 随机选择 N 个模块，确保覆盖所有测试维度
        echo "批量选择 ${COUNT} 个模块（维度覆盖优化）..."
        echo ""
        python3 -c "
import json, random

with open('${POOL_FILE}') as f:
    data = json.load(f)

modules = data['modules']
count = min(${COUNT}, len(modules))

# 贪心覆盖：优先选择覆盖最多未覆盖维度的模块
all_dims = set(['D1','D2','D3','D4','D5','D6','D7','D8','D9','D10'])
selected = []
covered = set()
remaining = list(range(len(modules)))
random.shuffle(remaining)

while len(selected) < count and remaining:
    best_idx = None
    best_new = -1
    for idx in remaining:
        new_dims = set(modules[idx]['test_focus']) - covered
        if len(new_dims) > best_new:
            best_new = len(new_dims)
            best_idx = idx
    if best_idx is not None:
        selected.append(best_idx)
        covered |= set(modules[best_idx]['test_focus'])
        remaining.remove(best_idx)

print(f'选中 {len(selected)} 个模块:')
print()
for i, idx in enumerate(selected, 1):
    m = modules[idx]
    print(f'{i:2d}. [{m[\"id\"]}] {m[\"display_name\"]}')
    print(f'    领域={m[\"domain\"]} | RTL={m[\"rtl_estimate\"]:,}行 | 角色={m[\"user_persona\"]} | 维度={\",\".join(m[\"test_focus\"])}')

print()
uncovered = all_dims - covered
if uncovered:
    print(f'⚠️  未覆盖维度: {uncovered}')
else:
    print('✅ 所有 D1~D10 维度已覆盖')
" 2>/dev/null || echo "(python3 不可用)"
        ;;

    full)
        echo "全量模式: 将执行全部 ${TOTAL} 个模块"
        echo ""
        echo "模块清单:"
        python3 -c "
import json
with open('${POOL_FILE}') as f:
    data = json.load(f)
for m in data['modules']:
    print(f\"  {m['id']}: {m['display_name']} ({m['domain']}, {m['rtl_estimate']:,}行)\")
" 2>/dev/null || grep '"id": "CM-' "$POOL_FILE" | sed 's/.*"id": "\(CM-[0-9]*\)".*/  \1/'
        echo ""
        echo "预计耗时: $((TOTAL * 55)) 分钟 (平均 55 min/module)"
        ;;

    balanced)
        # 角色均衡模式：每个角色至少选 2 个
        echo "角色均衡模式..."
        echo ""
        python3 -c "
import json, random

with open('${POOL_FILE}') as f:
    data = json.load(f)

modules = data['modules']
by_persona = {'E': [], 'C': [], 'V': []}
for i, m in enumerate(modules):
    p = m['user_persona']
    if p in by_persona:
        by_persona[p].append(i)

selected = []
# 每个角色至少 2 个
for p in ['E', 'C']:
    pool = by_persona[p]
    random.shuffle(pool)
    selected.extend(pool[:2])

# V 角色从 E/C 中随机替换
v_count = max(1, len(selected) // 5)
v_indices = random.sample(range(len(selected)), min(v_count, len(selected)))
for vi in v_indices:
    modules[selected[vi]]['_temp_persona'] = 'V'

# 补充到总数 8
remaining = [i for i in range(len(modules)) if i not in selected]
random.shuffle(remaining)
while len(selected) < 8 and remaining:
    selected.append(remaining.pop(0))

print(f'选中 {len(selected)} 个模块（角色均衡）:')
print()
for i, idx in enumerate(selected, 1):
    m = modules[idx]
    persona = m.get('_temp_persona', m['user_persona'])
    tag = ' [角色替换→V]' if '_temp_persona' in m else ''
    print(f'{i:2d}. [{m[\"id\"]}] {m[\"display_name\"]}')
    print(f'    角色={persona}{tag} | 领域={m[\"domain\"]} | 维度={\",\".join(m[\"test_focus\"])}')
" 2>/dev/null || echo "(python3 不可用)"
        ;;

    *)
        echo "用法: bash select_module.sh [single|batch|full|balanced] [count]"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "使用选中模块运行测试:"
echo "  /test-chip-requirement-arch complex_{module_id}"
echo "=========================================="
