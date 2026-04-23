# 静态时序分析（STA）基础

> **用途**：静态时序分析基础概念参考，供前端/后端设计时检索
> **典型应用**：所有芯片时序分析

---

## 概述

静态时序分析（Static Timing Analysis, STA）是芯片设计中验证时序正确性的关键技术。

### STA 优势

- **无需仿真**：不需要测试向量
- **穷举分析**：分析所有时序路径
- **快速高效**：比仿真快几个数量级
- **精确可靠**：基于单元延迟模型

---

## 时序路径

### 时序路径类型

```
1. 寄存器到寄存器（Reg2Reg）
   ┌─────────┐     ┌─────────┐
   │  Launch │────→│ Capture │
   │  FF     │     │  FF     │
   └─────────┘     └─────────┘

2. 输入到寄存器（In2Reg）
   ┌─────────┐     ┌─────────┐
   │  Input  │────→│ Capture │
   │  Port   │     │  FF     │
   └─────────┘     └─────────┘

3. 寄存器到输出（Reg2Out）
   ┌─────────┐     ┌─────────┐
   │  Launch │────→│ Output  │
   │  FF     │     │  Port   │
   └─────────┘     └─────────┘

4. 输入到输出（In2Out）
   ┌─────────┐     ┌─────────┐
   │  Input  │────→│ Output  │
   │  Port   │     │  Port   │
   └─────────┘     └─────────┘
```

### 时序路径组成

```
时序路径 = 启动时钟路径 + 数据路径 + 捕获时钟路径

┌─────────────────────────────────────────────────────────────┐
│  时钟源 → 时钟网络 → Launch FF → 逻辑锥 → Capture FF       │
└─────────────────────────────────────────────────────────────┘
```

---

## 时序弧

### 单元时序弧

| 时序弧类型 | 说明 | 示例 |
|------------|------|------|
| 组合延迟 | 输入到输出延迟 | AND2: A→Y, B→Y |
| 时序延迟 | 时钟到输出延迟 | FF: CLK→Q |
| 建立时间 | 数据建立时间 | FF: D setup to CLK |
| 保持时间 | 数据保持时间 | FF: D hold from CLK |

### 线网时序弧

| 时序弧类型 | 说明 | 计算 |
|------------|------|------|
| RC 延迟 | 线网延迟 | RC 模型计算 |
| 耦合延迟 | 串扰延迟 | SI 分析计算 |

---

## 延迟计算

### 单元延迟

```
单元延迟 = f(输入转换时间, 输出负载电容)

其中：
- 输入转换时间：输入信号的上升/下降时间
- 输出负载电容：输出引脚的负载电容

延迟模型：
- NLDM（非线性延迟模型）：查表法
- CCS（复合电流源）：电流源模型
- ECSM（有效电流源）：电流源模型
```

### 线网延迟

```
线网延迟 = f(线网长度, 线网宽度, 金属层, 耦合)

延迟模型：
- 集总 RC 模型：简单，精度低
- Elmore 延迟：中等精度
- RC 树模型：精度高
- 传输线模型：高频精度高
```

### 时序报告示例

```
Path 1: MET (WNS = 0.05)
  Startpoint: u1/reg1 (rising edge-triggered flip-flop)
  Endpoint: u1/reg2 (rising edge-triggered flip-flop)
  Path Group: clk
  Path Type: max

  Delay    Time   Description
  ------------------------------------------------------------
  0.00     0.00   clock clk (rise edge)
  0.50     0.50   clock source latency
  0.00     0.50   clock network delay (propagated)
  0.00     0.50   u1/reg1/CLK (DFF_X1)
  0.15     0.65   u1/reg1/Q (DFF_X1)
  0.20     0.85   u1/g1/Y (AND2_X1)
  0.10     0.95   u1/g2/Y (OR2_X1)
  0.00     0.95   u1/reg2/D (DFF_X1)
  -0.05    0.90   library setup time
  ------------------------------------------------------------
  0.95     0.95   data arrival time

  1.00     1.00   clock clk (rise edge)
  0.50     1.50   clock source latency
  0.00     1.50   clock network delay (propagated)
  -0.10    1.40   clock uncertainty
  -0.05    1.35   library setup time
  ------------------------------------------------------------
  1.35     1.35   data required time

  ------------------------------------------------------------
  1.35     1.35   data required time
  -0.95    0.95   data arrival time
  ------------------------------------------------------------
  0.40            slack (MET)
```

---

## 时钟定义

### 时钟创建

```tcl
# 基本时钟
create_clock -name clk -period 1.0 [get_ports clk]

# 带波形的时钟
create_clock -name clk -period 1.0 -waveform {0.0 0.5} [get_ports clk]

# 生成时钟
create_generated_clock -name clk_div -source [get_ports clk] -divide_by 2 [get_pins div_reg/Q]
```

### 时钟属性

```tcl
# 时钟不确定性
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]

# 时钟延迟
set_clock_latency -source 0.5 [get_clocks clk]
set_clock_latency 0.2 [get_clocks clk]

# 时钟转换时间
set_clock_transition 0.1 [get_clocks clk]
```

### 时钟域

```
多时钟域设计：
┌─────────────────────────────────────────────┐
│  clk1 (1 GHz)     │  clk2 (500 MHz)        │
│  ┌─────────────┐  │  ┌─────────────┐       │
│  │  模块 A     │  │  │  模块 B     │       │
│  └─────────────┘  │  └─────────────┘       │
│                   │                         │
│        CDC 同步器  │                         │
└─────────────────────────────────────────────┘
```

---

## 时序约束

### 输入延迟

```tcl
# 最大输入延迟（Setup）
set_input_delay -clock clk -max 0.5 [get_ports data_in]

# 最小输入延迟（Hold）
set_input_delay -clock clk -min 0.1 [get_ports data_in]

# 相对于时钟边沿
set_input_delay -clock clk -clock_fall -max 0.5 [get_ports data_in]
```

### 输出延迟

```tcl
# 最大输出延迟（Setup）
set_output_delay -clock clk -max 0.5 [get_ports data_out]

# 最小输出延迟（Hold）
set_output_delay -clock clk -min 0.1 [get_ports data_out]
```

### 负载和驱动

```tcl
# 输出负载
set_load 0.1 [get_ports data_out]

# 输入驱动
set_drive 0 [get_ports clk]
set_drive 0 [get_ports rst_n]

# 输入转换时间
set_input_transition 0.1 [get_ports data_in]
```

---

## 时序例外

### 伪路径

```tcl
# 跨时钟域伪路径
set_false_path -from [get_clocks clk1] -to [get_clocks clk2]

# 复位伪路径
set_false_path -from [get_ports rst_n]

# 异步路径
set_false_path -from [get_pins async_reg/Q]
```

### 多周期路径

```tcl
# 2 周期路径（Setup）
set_multicycle_path 2 -setup -from [get_pins reg1/Q] -to [get_pins reg2/D]

# 1 周期路径（Hold）
set_multicycle_path 1 -hold -from [get_pins reg1/Q] -to [get_pins reg2/D]
```

### 最大/最小延迟

```tcl
# 最大延迟约束
set_max_delay 2.0 -from [get_pins reg1/Q] -to [get_pins reg2/D]

# 最小延迟约束
set_min_delay 0.5 -from [get_pins reg1/Q] -to [get_pins reg2/D]
```

---

## STA 工具

### Synopsys PrimeTime

```tcl
# 读入设计
read_verilog netlist.v
read_sdc constraints.sdc

# 读入寄生参数
read_parasitics design.spef

# 更新时序
update_timing

# 报告时序
report_timing -delay_type max -max_paths 10 > setup.rpt
report_timing -delay_type min -max_paths 10 > hold.rpt

# 报告违规
report_constraint -all_violators > violations.rpt
```

### Cadence Tempus

```tcl
# 读入设计
read_netlist netlist.v
read_sdc constraints.sdc

# 读入寄生参数
read_parasitics design.spef

# 更新时序
update_timing

# 报告时序
report_timing -late > setup.rpt
report_timing -early > hold.rpt
```

---

## 常见时序问题

### Setup 违规

**原因**：
- 逻辑延迟过大
- 时钟周期过短
- 时钟偏移过大

**修复方法**：
1. 优化关键路径逻辑
2. 插入流水线
3. 减小时钟偏移
4. 放松时序约束

### Hold 违规

**原因**：
- 逻辑延迟过小
- 时钟偏移过大
- 组合逻辑过短

**修复方法**：
1. 插入延迟单元
2. 减小时钟偏移
3. 增加组合逻辑

### 时钟偏移过大

**原因**：
- 时钟树不平衡
- 时钟网络负载不均

**修复方法**：
1. 优化时钟树
2. 平衡时钟负载
3. 插入缓冲器

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys PrimeTime User Guide | STA 工具 |
| REF-002 | Cadence Tempus User Guide | STA 工具 |
| REF-003 | STA Concepts | 时序分析概念 |
