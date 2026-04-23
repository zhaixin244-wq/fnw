# low_power_advanced

> 低功耗设计高级概念，涵盖 DVFS、AVS、高级电源门控、功耗感知验证

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 方法论 |
| 来源 | .claude/knowledge/chip-design/low_power_advanced.md |

## 核心特性
- DVFS（动态电压频率调节）：根据负载动态调整电压和频率，功耗降低可达 68%
- AVS（自适应电压调节）：根据芯片实际状态调节电压，减小设计裕量
- 高级电源门控：硬/软/混合三种策略，状态保存与恢复
- 多电压域高级：功能/性能/功耗三种划分策略
- 功耗感知验证：UPF 仿真、功耗分析、功耗预算分配

## 典型应用场景
- 高性能低功耗 SoC 设计
- 移动处理器 DVFS 设计
- 数据中心芯片功耗优化

## 与其他实体的关系
- **low_power_basics**：基础概念延伸
- **signoff**：功耗签核（IR Drop/EM/功耗分析）
- **power_gating_controller**：电源门控控制器实现

## 设计注意事项
- DVFS 切换需配合 PLL 重锁和电压稳定等待
- AVS 需要关键路径监控器（Critical Path Monitor）
- 电源门控时序：保存状态 → 关断电源 → 等待稳定
- 功耗预算分配需覆盖所有功耗域

## 参考
- 原始文档：`.claude/knowledge/chip-design/low_power_advanced.md`
