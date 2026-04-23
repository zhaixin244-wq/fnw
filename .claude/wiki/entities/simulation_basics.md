# simulation_basics

> 仿真基础流程、调试技术、波形分析参考

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/verification/simulation_basics.md |

## 核心特性
- RTL 仿真：行为级仿真，速度慢精度高
- 门级仿真：带时序仿真，速度中精度高
- 混合仿真：RTL+门级，灵活性好
- 仿真流程：编译→ elaboration → 运行→ 波形分析

## 关键参数

| 仿真类型 | 速度 | 精度 | 典型工具 |
|----------|------|------|----------|
| RTL 仿真 | 1-10 KHz | Cycle-accurate | VCS/Xcelium/ModelSim |
| 门级仿真 | 0.1-1 KHz | Timing-accurate | VCS/Xcelium |
| 混合仿真 | 0.5-5 KHz | 混合 | VCS/Xcelium |

## 典型应用场景
- RTL 功能验证
- 协议一致性验证
- 边界条件测试
- 回归测试

## 与其他实体的关系
- **simulation_advanced**：高级仿真技术
- **uvm_basics**：UVM 验证环境基础
- **formal_basics**：形式验证补充仿真
- **coverage_analysis**：仿真覆盖率评估

## 设计注意事项
- 波形文件（VCD/FSDB）可能非常大
- 增量编译可加速仿真迭代
- 仿真种子（seed）影响随机激励生成

## 参考
- 原始文档：`.claude/knowledge/verification/simulation_basics.md`
