import os, re

skills_dir = '.claude/skills'
already_done = [
    'chip-create-dir', 'chip-png-interface-gen', 'chip-traceability-linker',
    'chip-rtl-bug-checker', 'chip-budget-allocator', 'chip-cdc-architect',
    'chip-design-space-explorer', 'chip-ppa-formatter', 'chip-reliability-architect',
    'chip-version-diff-generator'
]

all_skills = []
for d in sorted(os.listdir(skills_dir)):
    if d.startswith('chip-') and os.path.isdir(os.path.join(skills_dir, d)):
        if d not in already_done:
            all_skills.append(d)

print(f'Remaining skills to optimize: {len(all_skills)}\n')
print(f'{"Skill":<35} {"D3":>4} {"D4":>4} {"D5":>4} {"D2":>4} {"Words":>6} {"Gaps"}')
print('=' * 100)

for skill in all_skills:
    path = os.path.join(skills_dir, skill, 'SKILL.md')
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # D3: boundary conditions
    boundary_kw = r'fallback|降级|异常|错误恢复|超时|失败时|如果.*失败|error.*handling|timeout|边界|exception|异常处理'
    boundary_matches = len(re.findall(boundary_kw, content, re.IGNORECASE))
    has_boundary = '## 异常处理' in content or '## 异常' in content or boundary_matches >= 2

    # D4: checkpoints
    checkpoint_kw = r'确认|检查点|checkpoint|用户确认|暂停|确认后再|展示.*确认|confirm|gate|门控'
    checkpoint_matches = len(re.findall(checkpoint_kw, content, re.IGNORECASE))
    has_checkpoint = '## 检查点' in content or checkpoint_matches >= 2

    # D5: usage examples
    example_kw = r'示例|example|例如|用户[:：]|预期行为|调用方式|使用示例'
    example_matches = len(re.findall(example_kw, content, re.IGNORECASE))
    has_examples = example_matches >= 2

    # D2: numbered steps
    step_count = len(re.findall(r'^\d+\.', content, re.MULTILINE))
    has_steps = step_count >= 3

    wc = len(content.split())

    d3 = 'OK' if has_boundary else 'MISS'
    d4 = 'OK' if has_checkpoint else 'MISS'
    d5 = 'OK' if has_examples else 'MISS'
    d2 = 'OK' if has_steps else 'MISS'

    gaps = []
    if not has_boundary: gaps.append('D3')
    if not has_checkpoint: gaps.append('D4')
    if not has_examples: gaps.append('D5')
    if not has_steps: gaps.append('D2')

    print(f'{skill:<35} {d3:>4} {d4:>4} {d5:>4} {d2:>4} {wc:>6} {",".join(gaps) if gaps else "ALL OK"}')
