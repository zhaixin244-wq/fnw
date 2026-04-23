# simulation_advanced

> 高级仿真技术，性能优化、硬件加速、混合仿真

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/verification/simulation_advanced.md |

## 核心特性
- 编译优化：增量编译、并行编译、优化级别
- 硬件加速：Emulator/Palladium 等硬件仿真器
- 混合仿真：RTL+TLM+SystemC 混合建模
- 性能优化：减少波形 dump、优化测试用例

## 关键参数

| 加速技术 | 速度提升 | 精度 | 典型平台 |
|----------|----------|------|----------|
| 硬件仿真器 | 100-1000x | Cycle-accurate | Palladium/Veloce |
| FPGA 原型 | 1000-10000x | Cycle-accurate | HAPS/S2C |
| 混合仿真 | 10-100x | 混合 | SystemC+RTL |
| 云计算仿真 | 线性扩展 | 同单机 | AWS/阿里云 |

## 典型应用场景
- 大规模 SoC 系统级验证
- 软硬件协同验证
- 性能建模与分析
- 早于 RTL 的软件开发

## 与其他实体的关系
- **simulation_basics**：基础仿真流程
- **uvm_advanced**：UVM 高级特性配合加速
- **formal_advanced**：形式验证与仿真互补
- **verification_overview**：验证方法学全局

## 设计注意事项
- 硬件加速需要移植 Testbench
- 混合仿真接口同步是关键
- 云计算仿真需要考虑数据传输开销

## 参考
- 原始文档：`.claude/knowledge/verification/simulation_advanced.md`
