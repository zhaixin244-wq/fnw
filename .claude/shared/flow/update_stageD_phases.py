import json
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
json_path = os.path.join(script_dir, 'stageD-detail.json')

with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Phase 定义
phases = {
    "D_phase1": {
        "name": "架构规划",
        "description": "从大方向确定模块整体架构、CBB 复用策略和接口定义",
        "sub_stages": ["D_phase1-1", "D_phase1-2", "D_phase1-3"]
    },
    "D_phase2": {
        "name": "数据通路与流水线",
        "description": "细化数据流、流水线架构和控制逻辑",
        "sub_stages": ["D_phase2-1", "D_phase2-2", "D_phase2-3"]
    },
    "D_phase3": {
        "name": "存储与资源管理",
        "description": "设计寄存器、存储结构和面积优化策略",
        "sub_stages": ["D_phase3-1", "D_phase3-2", "D_phase3-3", "D_phase3-4"]
    },
    "D_phase4": {
        "name": "流控与时钟域",
        "description": "设计调度策略、反压机制和跨时钟域处理",
        "sub_stages": ["D_phase4-1", "D_phase4-2", "D_phase4-3"]
    },
    "D_phase5": {
        "name": "优化与可靠性",
        "description": "时序优化、性能分析、DFX 和异常检测",
        "sub_stages": ["D_phase5-1", "D_phase5-2", "D_phase5-3", "D_phase5-4"]
    }
}

# 子阶段 ID 映射（旧 → 新）
id_mapping = {
    "D0": "D_phase1-1",
    "D0b": "D_phase1-2",
    "D1": "D_phase1-3",
    "D2": "D_phase2-1",
    "D2b": "D_phase2-2",
    "D3": "D_phase2-3",
    "D4": "D_phase3-1",
    "D5": "D_phase3-2",
    "D6": "D_phase3-3",
    "D7": "D_phase3-4",
    "D8": "D_phase4-1",
    "D9": "D_phase4-2",
    "D10": "D_phase4-3",
    "D11": "D_phase5-1",
    "D12": "D_phase5-2",
    "D12b": "D_phase5-3",
    "D13": "D_phase5-4",
    "D14": "D_phase5-5"
}

# 更新 sub_stages
for stage in data['sub_stages']:
    old_id = stage['id']
    if old_id in id_mapping:
        new_id = id_mapping[old_id]
        stage['id'] = new_id
        stage['phase'] = new_id.split('-')[0]
        # 更新 depends_on
        if 'depends_on' in stage:
            stage['depends_on'] = [id_mapping.get(d, d) for d in stage['depends_on']]

# 更新 min_qa_pairs
old_overrides = data['adr_brainstorm_record_format']['min_qa_pairs']['overrides']
new_overrides = {}
for k, v in old_overrides.items():
    new_key = id_mapping.get(k, k)
    new_overrides[new_key] = v
data['adr_brainstorm_record_format']['min_qa_pairs']['overrides'] = new_overrides

# 更新 conditional_skip_rules
for rule in data['conditional_skip_rules']['rules']:
    old_stage = rule['stage']
    rule['stage'] = id_mapping.get(old_stage, old_stage)

# 更新 conditional_skip_enhancement
old_ver = data['conditional_skip_enhancement']['verification_rules']
new_ver = {}
for k, v in old_ver.items():
    new_key = id_mapping.get(k, k)
    new_ver[new_key] = v
data['conditional_skip_enhancement']['verification_rules'] = new_ver

# 更新 wiki_brainstorm_mapping
if 'wiki_brainstorm_integration' in data:
    old_mapping = data['wiki_brainstorm_integration']['wiki_search_mapping']
    new_mapping = {}
    for k, v in old_mapping.items():
        new_key = id_mapping.get(k, k)
        new_mapping[new_key] = v
    data['wiki_brainstorm_integration']['wiki_search_mapping'] = new_mapping

# 添加 phases 定义
data['phases'] = phases
data['phase_execution_order'] = ["D_phase1", "D_phase2", "D_phase3", "D_phase4", "D_phase5"]

# 更新 e_stage 中的子阶段引用
if 'e_stage' in data and 'submodule_d_stage_rules' in data['e_stage']:
    rules = data['e_stage']['submodule_d_stage_rules']
    if 'D0' in rules:
        rules['D_phase1-1'] = rules.pop('D0')
    if 'D1~D14' in rules:
        rules['D_phase1-2 ~ D_phase5-5'] = rules.pop('D1~D14')

# 更新 specialist_orchestration_trigger
if 'specialist_orchestration_trigger' in data:
    data['specialist_orchestration_trigger']['trigger_point'] = 'D_phase1-1 完成且用户确认初始架构方案后'

# 更新 adversarial_review_trigger
if 'adversarial_review_trigger' in data:
    data['adversarial_review_trigger']['trigger_point'] = 'D_phase5-5 完成且用户确认方案文档后'

# 更新 f_stage trigger
if 'f_stage' in data:
    data['f_stage']['trigger_condition'] = '所有子模块的 D 阶段完成'

with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK - reorganized D stage into 5 phases")
print("Phase mapping:")
for old, new in id_mapping.items():
    print(f"  {old:4s} -> {new}")
