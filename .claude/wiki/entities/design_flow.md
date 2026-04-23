# design_flow

> 芯片设计全流程参考，涵盖规格定义到流片制造的完整阶段

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 方法论 |
| 来源 | .claude/knowledge/chip-design/design_flow.md |

## 核心特性
- 7 个主要阶段：规格定义 → RTL 设计 → 逻辑综合 → DFT 插入 → 物理设计 → 签核验证 → 流片制造
- 每阶段有明确的输入/输出和签核检查项
- 设计迭代覆盖时序不收敛、功耗超标、面积超标三种常见场景

## 典型应用场景
- 所有芯片设计项目的流程管理
- 设计阶段划分和进度跟踪
- 设计质量检查清单定义

## 与其他实体的关系
- **frontend_design**：design_flow 阶段 2-3 对应前端设计
- **physical_design**：design_flow 阶段 5 对应物理设计
- **signoff**：design_flow 阶段 6 对应签核验证
- **dft_basics**：design_flow 阶段 4 对应 DFT 插入

## 设计注意事项
- RTL 签核必须通过 Lint/CDC/形式验证
- 综合签核要求 WNS > 0、面积功耗满足预算
- 物理设计签核要求 STA/DRC/LVS/IR Drop/EM 全部通过

## 参考
- 原始文档：`.claude/knowledge/chip-design/design_flow.md`
