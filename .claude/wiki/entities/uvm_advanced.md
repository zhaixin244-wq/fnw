# uvm_advanced

> UVM 高级特性，寄存器模型、高级序列、回调机制

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/verification/uvm_advanced.md |

## 核心特性
- 寄存器模型：自动化寄存器读写验证
- 高级序列：嵌套序列、虚拟序列、序列仲裁
- 回调机制：运行时行为修改
- Factory 高级用法：类型覆盖、参数化

## 关键参数

| 高级特性 | 说明 | 典型应用 |
|----------|------|----------|
| uvm_reg_block | 寄存器模型顶层 | 寄存器验证 |
| uvm_reg_map | 地址映射 | 多总线映射 |
| virtual sequence | 虚拟序列 | 多接口协调 |
| callback | 回调机制 | 可配置行为 |
| type override | 类型覆盖 | 组件替换 |

## 典型应用场景
- 复杂 SoC 多协议验证
- 寄存器验证自动化
- 多接口协调验证
- 可配置验证环境

## 与其他实体的关系
- **uvm_basics**：UVM 基础组件
- **simulation_advanced**：UVM 高级仿真技术
- **formal_advanced**：形式验证集成
- **coverage_analysis**：高级覆盖率模型

## 设计注意事项
- 寄存器模型需要与 RTL 寄存器描述同步
- 虚拟序列需要多 Sequencer 协调
- 过度使用回调会降低可读性
- Factory 覆盖需要合理使用

## 参考
- 原始文档：`.claude/knowledge/verification/uvm_advanced.md`
