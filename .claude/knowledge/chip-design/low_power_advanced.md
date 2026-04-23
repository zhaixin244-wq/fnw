# 低功耗设计高级

> **用途**：低功耗设计高级概念参考，供复杂低功耗设计时检索
> **典型应用**：高性能低功耗芯片设计

---

## 概述

本节介绍低功耗设计的高级概念，包括动态电压频率调节、自适应电压调节等。

---

## DVFS（动态电压频率调节）

### DVFS 原理

```
DVFS 原理：
┌─────────────────────────────────────────────┐
│  高性能模式：                                │
│  VDD = 1.0V, f = 1GHz                       │
│  功耗 = C × V² × f = C × 1.0 × 1G          │
│                                             │
│  低功耗模式：                                │
│  VDD = 0.8V, f = 500MHz                     │
│  功耗 = C × V² × f = C × 0.64 × 500M       │
│                                             │
│  功耗降低：~68%                              │
└─────────────────────────────────────────────┘
```

### DVFS 系统架构

```
DVFS 系统：
┌─────────────────────────────────────────────┐
│  性能监控器                                  │
│  ┌─────────────────────────────────────┐    │
│  │  性能计数器                         │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  DVFS 控制器                        │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│         ┌───────────┼───────────┐           │
│         ▼           ▼           ▼           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ 电压调节 │ │ 频率调节 │ │ 模式切换 │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────────────────────────────────────┘
```

### DVFS 实现

```verilog
// DVFS 控制器
module dvfs_controller (
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] perf_level,
    output reg  [1:0] voltage_sel,
    output reg  [1:0] freq_sel
);

// 性能级别定义
localparam LOW_POWER  = 2'b00;
localparam MEDIUM     = 2'b01;
localparam HIGH_PERF  = 2'b10;
localparam MAX_PERF   = 2'b11;

// 电压选择
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        voltage_sel <= LOW_POWER;
    else case (perf_level)
        LOW_POWER: voltage_sel <= 2'b00;  // 0.8V
        MEDIUM:    voltage_sel <= 2'b01;  // 0.9V
        HIGH_PERF: voltage_sel <= 2'b10;  // 1.0V
        MAX_PERF:  voltage_sel <= 2'b11;  // 1.1V
    endcase
end

// 频率选择
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        freq_sel <= LOW_POWER;
    else case (perf_level)
        LOW_POWER: freq_sel <= 2'b00;  // 500MHz
        MEDIUM:    freq_sel <= 2'b01;  // 750MHz
        HIGH_PERF: freq_sel <= 2'b10;  // 1GHz
        MAX_PERF:  freq_sel <= 2'b11;  // 1.2GHz
    endcase
end

endmodule
```

---

## AVS（自适应电压调节）

### AVS 原理

```
AVS 原理：
┌─────────────────────────────────────────────┐
│  传统方法：                                  │
│  - 固定电压，考虑最坏情况                    │
│  - 裕量大，功耗高                            │
│                                             │
│  AVS 方法：                                  │
│  - 根据芯片实际状态调节电压                  │
│  - 裕量小，功耗低                            │
└─────────────────────────────────────────────┘
```

### AVS 系统架构

```
AVS 系统：
┌─────────────────────────────────────────────┐
│  关键路径监控器                              │
│  ┌─────────────────────────────────────┐    │
│  │  时序监控器                         │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  AVS 控制器                         │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  电压调节器 (PMU)                   │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  芯片电源                                    │
└─────────────────────────────────────────────┘
```

### AVS 实现

```verilog
// 关键路径监控器
module critical_path_monitor (
    input  wire clk,
    input  wire rst_n,
    input  wire test_en,
    output wire timing_ok,
    output wire [7:0] delay_count
);

reg [7:0] counter;
reg timing_violation;

// 延迟计数
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        counter <= 8'b0;
    else if (test_en)
        counter <= counter + 1;
    else
        counter <= 8'b0;
end

// 时序检查
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        timing_violation <= 1'b0;
    else
        timing_violation <= (counter > THRESHOLD);
end

assign timing_ok = ~timing_violation;
assign delay_count = counter;

endmodule
```

---

## 电源门控高级

### 电源门控策略

| 策略 | 说明 | 应用 |
|------|------|------|
| 硬电源门控 | 硬件控制电源开关 | 长时间睡眠 |
| 软电源门控 | 软件控制电源开关 | 短时间睡眠 |
| 混合电源门控 | 结合软硬件 | 灵活控制 |

### 电源门控时序

```
电源门控时序：
┌─────────────────────────────────────────────┐
│  电源关断序列：                              │
│  1. 保存状态                                 │
│  2. 关断电源                                 │
│  3. 等待稳定                                 │
│                                             │
│  电源开启序列：                              │
│  1. 开启电源                                 │
│  2. 等待稳定                                 │
│  3. 恢复状态                                 │
└─────────────────────────────────────────────┘
```

### 电源门控实现

```verilog
// 电源门控控制器
module power_gating_controller (
    input  wire clk,
    input  wire rst_n,
    input  wire sleep_req,
    input  wire wake_req,
    output reg  power_en,
    output reg  isolation_en,
    output reg  retention_en
);

// 状态定义
localparam AWAKE     = 3'b001;
localparam SLEEPING  = 3'b010;
localparam SLEEP     = 3'b100;

reg [2:0] state;
reg [3:0] counter;

// 状态机
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= AWAKE;
        counter <= 4'b0;
    end else case (state)
        AWAKE: begin
            if (sleep_req) begin
                state <= SLEEPING;
                counter <= 4'b0;
            end
        end
        SLEEPING: begin
            if (counter == 4'b1111)
                state <= SLEEP;
            else
                counter <= counter + 1;
        end
        SLEEP: begin
            if (wake_req) begin
                state <= AWAKE;
                counter <= 4'b0;
            end
        end
    endcase
end

// 控制信号
always @(*) begin
    case (state)
        AWAKE: begin
            power_en = 1'b1;
            isolation_en = 1'b0;
            retention_en = 1'b0;
        end
        SLEEPING: begin
            power_en = (counter < 4'b1000);
            isolation_en = (counter >= 4'b0100);
            retention_en = (counter >= 4'b0100);
        end
        SLEEP: begin
            power_en = 1'b0;
            isolation_en = 1'b1;
            retention_en = 1'b1;
        end
    endcase
end

endmodule
```

---

## 多电压域高级

### 电压域划分策略

| 策略 | 说明 | 应用 |
|------|------|------|
| 功能划分 | 按功能划分电压域 | 模块化设计 |
| 性能划分 | 按性能需求划分 | 多性能需求 |
| 功耗划分 | 按功耗需求划分 | 低功耗设计 |

### 电压域交互

```
电压域交互：
┌─────────────────────────────────────────────┐
│  电压域 1 (1.0V)    │  电压域 2 (0.8V)      │
│  ┌─────────────┐    │  ┌─────────────┐      │
│  │  模块 A     │    │  │  模块 B     │      │
│  └──────┬──────┘    │  └──────┬──────┘      │
│         │           │         │              │
│         └───────────┼─────────┘              │
│                     │                        │
│              电平转换器                       │
└─────────────────────────────────────────────┘
```

### 电压域接口

```verilog
// 跨电压域接口
module cross_voltage_interface (
    input  wire clk_1v,
    input  wire rst_n_1v,
    input  wire data_1v,
    input  wire clk_0v8,
    input  wire rst_n_0v8,
    output wire data_0v8
);

// 电平转换器
level_shifter_l2h u_ls (
    .in(data_1v),
    .out(data_0v8)
);

// 同步器
cdc_sync u_sync (
    .clk_dst(clk_0v8),
    .rst_n(rst_n_0v8),
    .sig_src(data_0v8),
    .sig_dst(data_synced)
);

endmodule
```

---

## 功耗感知设计

### 功耗感知验证

```
功耗感知验证：
┌─────────────────────────────────────────────┐
│  RTL 仿真                                   │
│  ┌─────────────────────────────────────┐    │
│  │  功耗估算                           │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  门级仿真                           │    │
│  │  (带功耗信息)                       │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  功耗分析                           │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### 功耗预算分配

```
功耗预算分配：
┌─────────────────────────────────────────────┐
│  总功耗预算：1W                              │
│  ┌─────────────────────────────────────┐    │
│  │  CPU 核心：400mW (40%)              │    │
│  ├─────────────────────────────────────┤    │
│  │  缓存：200mW (20%)                  │    │
│  ├─────────────────────────────────────┤    │
│  │  I/O：150mW (15%)                   │    │
│  ├─────────────────────────────────────┤    │
│  │  存储器：150mW (15%)                │    │
│  ├─────────────────────────────────────┤    │
│  │  其他：100mW (10%)                  │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## 低功耗物理设计

### 电源网络设计

```
低功耗电源网络：
┌─────────────────────────────────────────────┐
│  多电压电源网络                              │
│  ┌─────────────────────────────────────┐    │
│  │  VDD1 (1.0V) 电源环                 │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  VDD2 (0.8V) 电源环                 │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  VSS 电源环                         │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### 电源门控单元布局

```
电源门控单元布局：
┌─────────────────────────────────────────────┐
│  电源门控单元布局策略                        │
│  ┌─────────────────────────────────────┐    │
│  │  Header 单元放置在电源条带上         │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  Footer 单元放置在地条带上           │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  电平转换器放置在电压域边界          │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## 低功耗验证

### 低功耗验证方法

| 方法 | 说明 | 工具 |
|------|------|------|
| UPF 仿真 | 基于 UPF 仿真 | VCS/Questa |
| 形式验证 | 低功耗形式验证 | Formality |
| 功耗分析 | 功耗仿真分析 | PrimePower |

### UPF 仿真流程

```tcl
# UPF 仿真
read_upf design.upf
simulate -power

# 功耗报告
report_power > power_sim.rpt
```

### 低功耗检查清单

- [ ] UPF 文件正确
- [ ] 电源域划分正确
- [ ] 电平转换器正确
- [ ] 隔离单元正确
- [ ] 保持寄存器正确
- [ ] 电源门控时序正确
- [ ] 功耗分析通过

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys UPF User Guide | UPF 标准 |
| REF-002 | Synopsys PrimePower User Guide | 功耗分析工具 |
| REF-003 | IEEE 1801 | UPF 标准 |
| REF-004 | Cadence Voltus User Guide | 功耗分析工具 |
