# uvm_basics

> UVM 验证方法学基础，框架组件与验证环境搭建

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/verification/uvm_basics.md |

## 核心特性
- UVM（Universal Verification Methodology）是业界标准验证方法学
- 可重用性、可扩展性、标准化、自动化
- 核心组件：Test → Env → Agent → Driver/Monitor/Sequencer
- 基于 SystemVerilog 的面向对象编程

## 关键参数

| UVM 组件 | 功能 | 数量 |
|----------|------|------|
| uvm_test | 测试用例顶层 | 每个测试 1 个 |
| uvm_env | 验证环境 | 每个 DUT 1 个 |
| uvm_agent | 接口代理 | 每个接口 1 个 |
| uvm_driver | 驱动激励 | 每个 Agent 1 个 |
| uvm_monitor | 监控采样 | 每个 Agent 1 个 |
| uvm_sequencer | 序列调度 | 每个 Agent 1 个 |
| uvm_scoreboard | 结果比对 | 可选 |

## 典型应用场景
- 所有标准 UVM 验证环境
- IP 级验证
- 子系统级验证
- 可重用验证组件开发

## 与其他实体的关系
- **uvm_advanced**：UVM 高级特性
- **simulation_basics**：UVM 基于仿真运行
- **formal_basics**：SVA 属性可在 UVM 中使用
- **coverage_analysis**：UVM 功能覆盖率

## 设计注意事项
- Factory 机制支持组件替换
- Config_db 机制管理配置
- Phase 机制控制仿真阶段
- Sequence 机制生成激励

## 参考
- 原始文档：`.claude/knowledge/verification/uvm_basics.md`
