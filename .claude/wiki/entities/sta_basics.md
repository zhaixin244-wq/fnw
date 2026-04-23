# sta_basics

> 静态时序分析（STA）基础概念，涵盖时序路径、延迟计算、时钟定义、约束编写

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 方法论 |
| 来源 | .claude/knowledge/chip-design/sta_basics.md |

## 核心特性
- 4 种时序路径：Reg2Reg、In2Reg、Reg2Out、In2Out
- 延迟模型：单元延迟（NLDM/CCS/ECSM）+ 线网延迟（RC/Elmore/传输线）
- 时钟定义：create_clock / create_generated_clock / uncertainty / latency
- 时序例外：伪路径（false_path）、多周期路径（multicycle_path）、最大/最小延迟
- STA 工具：Synopsys PrimeTime / Cadence Tempus

## 关键参数

| 约束类型 | SDC 命令 | 说明 |
|----------|----------|------|
| 时钟定义 | create_clock | 周期、波形 |
| 时钟不确定性 | set_clock_uncertainty | setup/hold |
| 输入延迟 | set_input_delay | max/min |
| 输出延迟 | set_output_delay | max/min |
| 伪路径 | set_false_path | CDC/复位 |
| 多周期路径 | set_multicycle_path | setup/hold |

## 典型应用场景
- 综合后时序验证
- 物理设计时序优化
- 签核时序分析

## 与其他实体的关系
- **sta_advanced**：AOCV/SOCV/SI/多角分析
- **frontend_design**：SDC 约束编写
- **physical_design**：时钟树综合与布线优化
- **signoff**：时序签核

## 设计注意事项
- Setup 裕量 = Tclk - Tck2q - Tlogic - Tsetup - Tskew
- Hold 裕量 = Tck2q + Tlogic - Thold - Tskew
- 复位路径必须设为 false_path
- 生成时钟必须声明 source pin 和分频比

## 参考
- 原始文档：`.claude/knowledge/chip-design/sta_basics.md`
