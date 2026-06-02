import json

with open('stageD-detail.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 1. 新增 D0b: CBB模块使用专题
d0b = {
    "id": "D0b",
    "name": "CBB 模块使用规划",
    "description": "通过头脑风暴与用户沟通，确定是否有可复用的 CBB 模块，评估集成方案。",
    "trigger_condition": "默认触发",
    "depends_on": ["D0"],
    "input_analysis": {
        "source": ["D0 子模块列表", "stageC 需求汇总表", "Wiki 知识库 CBB 索引"],
        "analysis_steps": [
            "1. 回顾 D0 子模块列表，识别可复用的功能单元",
            "2. 检索 Wiki 知识库中的 CBB 选型指南",
            "3. 评估已有 CBB 是否满足需求（功能/接口/PPA）",
            "4. 识别需要新设计的模块"
        ]
    },
    "brainstorm_focus": [
        "已有 CBB 模块清单（FIFO/SRAM/仲裁器/CDC/寄存器模块等）",
        "每个 CBB 的功能匹配度评估",
        "CBB 集成的接口适配方案",
        "CBB 的 PPA 特性与需求对比",
        "CBB 使用的约束和限制",
        "自研 vs 复用的 trade-off 分析"
    ],
    "wiki_integration": {
        "required": True,
        "search_queries": ["CBB 选型指南", "FIFO IP", "SRAM IP", "仲裁器 IP", "CDC IP"],
        "wiki_pages": ["wiki/cbb-selection-guide.md", "wiki/fifo-design-patterns.md", "wiki/arbiter-patterns.md"]
    },
    "output": {
        "solution_section": "S3.2 CBB 集成规划",
        "deliverables": [
            "CBB 使用清单（名称/版本/功能/接口/PPA）",
            "CBB 集成方案（接口适配/配置初始化）",
            "自研模块清单（无可用 CBB 时）"
        ]
    },
    "skip_condition": "无可用 CBB 或用户明确不使用 CBB 时跳过"
}

# 2. 新增 D2b: 流水线设计专题
d2b = {
    "id": "D2b",
    "name": "流水线设计",
    "description": "通过头脑风暴与用户沟通，细化模块的流水线架构设计。",
    "trigger_condition": "默认触发",
    "depends_on": ["D2"],
    "input_analysis": {
        "source": ["D2 数据流图", "stageC REQ-001 频率约束", "stageC REQ-003 数据流特征"],
        "analysis_steps": [
            "1. 回顾 D2 数据流中的各级处理阶段",
            "2. 分析 REQ-001 频率约束对流水线深度的要求",
            "3. 识别关键路径和潜在瓶颈"
        ]
    },
    "brainstorm_focus": [
        "流水线级数确定（基于频率/面积/延迟权衡）",
        "每级流水线的功能划分",
        "流水线寄存器的位宽和复位值",
        "流水线冒险处理（数据冒险/控制冒险/结构冒险）",
        "Forwarding/Bypass 路径设计",
        "Stall/Flush 机制设计",
        "流水线握手协议（valid/ready）",
        "包边界（last/eop）在流水线中的传播"
    ],
    "wiki_integration": {
        "required": True,
        "search_queries": ["流水线设计模式", "pipeline hazard", "forwarding bypass", "stall flush 机制"],
        "wiki_pages": ["wiki/pipeline-design-patterns.md", "wiki/fsm-design-patterns.md"]
    },
    "output": {
        "solution_section": "S5.4 流水线设计",
        "deliverables": [
            "流水线级数和功能划分表",
            "每级流水线的数据格式和位宽",
            "冒险处理方案（Forwarding/Stall/Flush）",
            "流水线时序图（Wavedrom）"
        ]
    },
    "skip_condition": "纯组合逻辑模块或单周期模块可跳过"
}

# 3. 新增 D12b: 性能专题
d12b = {
    "id": "D12b",
    "name": "性能分析与优化",
    "description": "通过头脑风暴与用户沟通，分析模块的性能瓶颈并制定优化方案。",
    "trigger_condition": "默认触发",
    "depends_on": ["D2", "D3", "D10", "D12"],
    "input_analysis": {
        "source": ["D2 数据流图", "D3 控制逻辑", "D10 反压方案", "D12 时序分析", "stageC REQ-004 延迟与吞吐"],
        "analysis_steps": [
            "1. 回顾 REQ-004 确认的延迟和吞吐要求",
            "2. 分析 D2 数据流中的关键路径延迟",
            "3. 分析 D10 反压方案对性能的影响",
            "4. 识别性能瓶颈点"
        ]
    },
    "brainstorm_focus": [
        "端到端延迟分析（每级 cycles 求和）",
        "吞吐量分析（瓶颈级的吞吐限制）",
        "性能瓶颈识别（数据通路/控制逻辑/存储/反压）",
        "并行度优化（多通道/流水线/展开循环）",
        "存储带宽优化（多端口 SRAM/bank 交织）",
        "反压对性能的影响分析",
        "性能 vs 面积/功耗 trade-off",
        "性能监控计数器设计"
    ],
    "wiki_integration": {
        "required": True,
        "search_queries": ["性能优化模式", "吞吐量分析", "延迟优化", "并行度优化"],
        "wiki_pages": ["wiki/performance-optimization.md", "wiki/pipeline-design-patterns.md"]
    },
    "output": {
        "solution_section": "S8.1 性能指标",
        "deliverables": [
            "端到端延迟分析表",
            "吞吐量分析表",
            "性能瓶颈清单",
            "优化策略和预期效果",
            "性能监控计数器定义"
        ]
    },
    "skip_condition": "无明确性能要求（REQ-004 为 Could 级）时可简化"
}

# 插入新子阶段
sub_stages = data["sub_stages"]
ids = [s["id"] for s in sub_stages]

d0_idx = ids.index("D0")
sub_stages.insert(d0_idx + 1, d0b)

ids = [s["id"] for s in sub_stages]
d2_idx = ids.index("D2")
sub_stages.insert(d2_idx + 1, d2b)

ids = [s["id"] for s in sub_stages]
d12_idx = ids.index("D12")
sub_stages.insert(d12_idx + 1, d12b)

data["sub_stages"] = sub_stages

# 更新 min_qa_pairs
data["adr_brainstorm_record_format"]["min_qa_pairs"]["overrides"]["D0b"] = 3
data["adr_brainstorm_record_format"]["min_qa_pairs"]["overrides"]["D2b"] = 4
data["adr_brainstorm_record_format"]["min_qa_pairs"]["overrides"]["D12b"] = 3

# 更新 conditional_skip_rules
data["conditional_skip_rules"]["rules"].append({
    "stage": "D0b",
    "condition": "无可用 CBB 或用户明确不使用 CBB",
    "action": "skip"
})
data["conditional_skip_rules"]["rules"].append({
    "stage": "D2b",
    "condition": "纯组合逻辑模块或单周期模块",
    "action": "skip"
})
data["conditional_skip_rules"]["rules"].append({
    "stage": "D12b",
    "condition": "REQ-004 为 Could 级且无明确性能要求",
    "action": "skip"
})

# 更新 conditional_skip_enhancement
data["conditional_skip_enhancement"]["verification_rules"]["D0b"] = "检查 Wiki CBB 索引是否有可用 CBB"
data["conditional_skip_enhancement"]["verification_rules"]["D2b"] = "检查 D0 架构是否涉及流水线"
data["conditional_skip_enhancement"]["verification_rules"]["D12b"] = "检查 REQ-004 优先级"

# 新增 Wiki 集成头脑风暴规则
data["wiki_brainstorm_integration"] = {
    "description": "D 阶段每轮头脑风暴必须结合 Wiki 知识库相关知识与用户展开讨论",
    "rule": "每个 D 子阶段的头脑风暴前，必须先检索 Wiki 知识库获取相关协议/CBB/设计模式/行业实践",
    "execution_steps": [
        "1. 读取 wiki/index.md 获取知识库索引",
        "2. 按当前 D 子阶段主题检索相关 Wiki 页面",
        "3. 提取 Wiki 中的关键知识点（协议要求/设计模式/参数约束/最佳实践）",
        "4. 将 Wiki 知识作为头脑风暴的输入参考",
        "5. 头脑风暴中引用 Wiki 内容作为方案决策的依据",
        "6. ADR 记录中标注 Wiki 引用来源"
    ],
    "wiki_search_mapping": {
        "D0": ["架构设计模式", "SoC 架构", "模块划分原则"],
        "D0b": ["CBB 选型指南", "FIFO IP", "SRAM IP", "仲裁器 IP", "CDC IP"],
        "D1": ["接口协议规范", "AXI/APB/AHB 协议", "Valid-Ready 握手"],
        "D2": ["数据通路设计", "数据流模式", "缓冲策略"],
        "D2b": ["流水线设计模式", "pipeline hazard", "forwarding bypass"],
        "D3": ["FSM 设计模式", "状态机编码", "控制逻辑设计"],
        "D4": ["寄存器设计", "APB 寄存器映射", "W1C/W0C 行为"],
        "D5": ["面积优化", "资源共享", "逻辑压缩"],
        "D6": ["SRAM 设计", "存储器选型", "读写策略"],
        "D7": ["FIFO 设计", "异步 FIFO", "深度计算"],
        "D8": ["链表设计", "描述符管理", "缓冲区管理"],
        "D9": ["调度算法", "仲裁策略", "公平性分析"],
        "D10": ["流控机制", "Credit 流控", "反压设计"],
        "D11": ["CDC 设计", "跨时钟域", "同步器"],
        "D12": ["时序优化", "关键路径", "流水线重定时"],
        "D12b": ["性能优化", "吞吐量分析", "延迟优化"],
        "D13": ["DFT 设计", "扫描链", "MBIST"],
        "D14": ["异常检测", "错误处理", "可靠性设计"]
    },
    "adr_wiki_citation_format": "**Wiki 引用**：{wiki_page} - {关键知识点}",
    "blocking_rule": "未完成 Wiki 检索不得开始头脑风暴"
}

with open('stageD-detail.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("OK - added D0b, D2b, D12b + wiki_brainstorm_integration")
