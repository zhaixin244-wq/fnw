# 低功耗设计基础

> **用途**：低功耗设计基础概念参考，供芯片功耗优化时检索
> **典型应用**：所有芯片低功耗设计

---

## 概述

低功耗设计是现代芯片设计的关键技术，直接影响芯片性能、成本和可靠性。

### 功耗类型

| 类型 | 公式 | 说明 |
|------|------|------|
| 动态功耗 | P = α × C × V² × f | 开关活动引起的功耗 |
| 静态功耗 | P = Ileak × V | 漏电流引起的功耗 |
| 短路功耗 | P = Isc × V | 短路电流引起的功耗 |

### 功耗组成

```
总功耗 = 动态功耗 + 静态功耗 + 短路功耗

动态功耗：~70%
静态功耗：~25%
短路功耗：~5%
```

---

## 动态功耗优化

### 时钟门控

```
时钟门控原理：
┌─────────────────────────────────────────────┐
│  无时钟门控：                                │
│  clk ──────────────────→ FF                 │
│       (始终翻转)                             │
│                                             │
│  有时钟门控：                                │
│  clk ──→ AND ─────────→ FF                  │
│              ↑                               │
│         enable                              │
│       (使能时翻转)                           │
└─────────────────────────────────────────────┘
```

### 时钟门控实现

```verilog
// ICG 单元（集成时钟门控）
module ICG (
    input  wire CLK,
    input  wire EN,
    input  wire TE,  // 测试使能
    output wire Q
);

reg en_latch;

always @(*) begin
    if (!CLK)
        en_latch <= EN | TE;
end

assign Q = CLK & en_latch;

endmodule

// 使用 ICG
module design_with_icg (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    input  wire [7:0] data_in,
    output reg  [7:0] data_out
);

wire gated_clk;

ICG u_icg (
    .CLK(clk),
    .EN(en),
    .TE(1'b0),
    .Q(gated_clk)
);

always @(posedge gated_clk or negedge rst_n) begin
    if (!rst_n)
        data_out <= 8'b0;
    else
        data_out <= data_in;
end

endmodule
```

### 操作数隔离

```
操作数隔离原理：
┌─────────────────────────────────────────────┐
│  无操作数隔离：                              │
│  data ──→ ALU ──→ result                    │
│       (始终计算)                             │
│                                             │
│  有操作数隔离：                              │
│  data ──→ MUX ──→ ALU ──→ result            │
│              ↑                               │
│         enable                              │
│       (使能时计算)                           │
└─────────────────────────────────────────────┘
```

### 操作数隔离实现

```verilog
// 操作数隔离
module operand_isolation (
    input  wire en,
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [7:0] result
);

wire [7:0] a_gated, b_gated;

assign a_gated = en ? a : 8'b0;
assign b_gated = en ? b : 8'b0;

assign result = a_gated + b_gated;

endmodule
```

---

## 静态功耗优化

### 电源门控

```
电源门控原理：
┌─────────────────────────────────────────────┐
│  无电源门控：                                │
│  VDD ──────────────────→ 逻辑               │
│       (始终供电)                             │
│                                             │
│  有电源门控：                                │
│  VDD ──→ Header/Footer ──→ 逻辑             │
│              ↑                               │
│         enable                              │
│       (使能时供电)                           │
└─────────────────────────────────────────────┘
```

### 电源门控实现

```verilog
// Header 单元（PMOS 开关）
module header_cell (
    input  wire en,
    inout  wire vdd,
    inout  wire vdd_gated
);

// PMOS 开关
assign vdd_gated = en ? vdd : 1'bz;

endmodule

// Footer 单元（NMOS 开关）
module footer_cell (
    input  wire en,
    inout  wire vss,
    inout  wire vss_gated
);

// NMOS 开关
assign vss_gated = en ? vss : 1'bz;

endmodule
```

### 多阈值电压

```
多阈值电压原理：
┌─────────────────────────────────────────────┐
│  HVT（高阈值电压）：                         │
│  - 漏电流小                                 │
│  - 速度慢                                   │
│  - 用于非关键路径                           │
│                                             │
│  LVT（低阈值电压）：                         │
│  - 漏电流大                                 │
│  - 速度快                                   │
│  - 用于关键路径                             │
│                                             │
│  SVT（标准阈值电压）：                       │
│  - 漏电流中                                 │
│  - 速度中                                   │
│  - 用于一般路径                             │
└─────────────────────────────────────────────┘
```

### 多阈值电压优化

```tcl
# 综合时使用多阈值电压
set_multi_vth_constraint -lvt_percentage 20 -lvt_threshold LVT

# 报告多阈值电压使用
report_multi_vth_usage > multi_vth.rpt
```

---

## 电压域

### 电压域概念

```
多电压域设计：
┌─────────────────────────────────────────────┐
│  电压域 1 (1.0V)    │  电压域 2 (0.8V)      │
│  ┌─────────────┐    │  ┌─────────────┐      │
│  │  高性能模块  │    │  │  低功耗模块  │      │
│  └─────────────┘    │  └─────────────┘      │
│                     │                        │
│  电平转换器          │                        │
└─────────────────────────────────────────────┘
```

### 电压域类型

| 类型 | 说明 | 应用 |
|------|------|------|
| 固定电压域 | 固定电压 | 一般模块 |
| 可变电压域 | 可调电压 | 动态电压调节 |
| 关断电压域 | 可关断 | 睡眠模式 |

### 电平转换器

```
电平转换器：
┌─────────────────────────────────────────────┐
│  低电压 → 高电压：                          │
│  ┌─────────────────────────────────────┐    │
│  │  L2H Level Shifter                  │    │
│  │  (低电压到高电压转换)                │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  高电压 → 低电压：                          │
│  ┌─────────────────────────────────────┐    │
│  │  H2L Level Shifter                  │    │
│  │  (高电压到低电压转换)                │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## UPF（统一功耗格式）

### UPF 概念

UPF 是描述低功耗设计意图的标准格式。

### UPF 命令

```tcl
# 创建电源域
create_power_domain PD1 -include_scope

# 创建电源端口
create_power_port VDD -domain PD1
create_power_port VSS -domain PD1

# 创建电源网络
create_power_net VDD -domain PD1
create_power_net VSS -domain PD1

# 设置电源状态
set_port_state VDD -state {ON 0.9v}
set_port_state VDD -state {OFF 0.0v}

# 创建电平转换器
create_level_shifter LS1 -domain PD1 -from PD0 -to PD1

# 创建隔离单元
create_isolation ISO1 -domain PD1 -from PD1 -to PD0

# 创建保持寄存器
create_retention RET1 -domain PD1
```

### UPF 流程

```
RTL 设计
    ↓
UPF 文件
    ↓
综合工具
    ↓
低功耗网表
    ↓
物理设计
    ↓
低功耗版图
```

---

## 功耗分析

### 功耗分析流程

```
门级网表 + 仿真波形
    ↓
功耗分析工具
    ↓
功耗报告
    ↓
功耗优化
```

### 功耗报告

```tcl
# Synopsys PrimePower
read_power_activities -format VCD design.vcd

# 功耗报告
report_power > power.rpt

报告内容：
- 动态功耗
- 静态功耗
- 开关功耗
- 内部功耗
- 漏电功耗
```

### 功耗优化

| 优化方法 | 效果 | 应用 |
|----------|------|------|
| 时钟门控 | 减少动态功耗 20-30% | 所有设计 |
| 操作数隔离 | 减少动态功耗 10-20% | 运算单元 |
| 电源门控 | 减少静态功耗 50-90% | 睡眠模式 |
| 多阈值电压 | 减少静态功耗 20-50% | 所有设计 |
| 多电压域 | 减少动态功耗 20-40% | 多性能需求 |

---

## 低功耗设计检查清单

### RTL 设计

- [ ] 时钟门控插入
- [ ] 操作数隔离插入
- [ ] 电源域划分
- [ ] UPF 文件编写

### 综合

- [ ] 时钟门控优化
- [ ] 多阈值电压优化
- [ ] 功耗目标满足

### 物理设计

- [ ] 电源网络设计
- [ ] 电源门控单元布局
- [ ] 电平转换器布局
- [ ] IR Drop 满足

### 签核

- [ ] 功耗分析通过
- [ ] IR Drop 分析通过
- [ ] EM 分析通过

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys PrimePower User Guide | 功耗分析工具 |
| REF-002 | Synopsys UPF User Guide | UPF 标准 |
| REF-003 | IEEE 1801 | UPF 标准 |
| REF-004 | Cadence Voltus User Guide | 功耗分析工具 |
