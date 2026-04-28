import os, re

skills_dir = '.claude/skills'
all_skills = sorted([d for d in os.listdir(skills_dir) if d.startswith('chip-') and os.path.isdir(os.path.join(skills_dir, d))])

print(f'Total chip-* skills: {len(all_skills)}\n')
print(f'{"Skill":<35} {"D3":>4} {"D4":>4} {"D5":>4} {"D2":>4} {"Words":>6} {"Missing"}')
print('=' * 100)

total_ok = 0
for skill in all_skills:
    path = os.path.join(skills_dir, skill, 'SKILL.md')
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    has_boundary = '## 异常处理' in content or '## 异常' in content
    has_checkpoint = '## 检查点' in content
    has_examples = bool(re.search(r'示例|example|用户[:：]|预期行为|使用示例', content))
    step_count = len(re.findall(r'^\d+\.', content, re.MULTILINE))
    has_steps = step_count >= 3
    wc = len(content.split())

    d3 = 'OK' if has_boundary else '--'
    d4 = 'OK' if has_checkpoint else '--'
    d5 = 'OK' if has_examples else '--'
    d2 = 'OK' if has_steps else '--'

    gaps = []
    if not has_boundary: gaps.append('D3')
    if not has_checkpoint: gaps.append('D4')
    if not has_examples: gaps.append('D5')
    if not has_steps: gaps.append('D2')

    if not gaps:
        total_ok += 1

    print(f'{skill:<35} {d3:>4} {d4:>4} {d5:>4} {d2:>4} {wc:>6} {",".join(gaps) if gaps else "ALL OK"}')

print('=' * 100)
print(f'Complete (all 4 dims): {total_ok}/{len(all_skills)}')
