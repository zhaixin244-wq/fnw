# 前端设计

> **用途**：芯片前端设计流程参考，供 RTL 设计和综合时检索
> **典型应用**：所有芯片前端设计

---

## 概述

前端设计主要涉及 RTL 编码、功能验证、逻辑综合和形式验证。

### 前端设计流程

```
设计规格
    ↓
RTL 编码
    ↓
功能验证
    ↓
Lint/CDC 检查
    ↓
逻辑综合
    ↓
形式验证
    ↓
DFT 插入
    ↓
门级网表
```

---

## RTL 设计

### 设计语言

| 语言 | 用途 | 特点 |
|------|------|------|
| Verilog | RTL 设计 | 简单、广泛使用 |
| SystemVerilog | RTL + 验证 | 功能强大、面向对象 |
| VHDL | RTL 设计 | 强类型、严谨 |

### 编码规范

```verilog
// 1. 文件头注释
// Module: module_name
// Function: 功能描述
// Author: 作者
// Date: 日期
// Revision: 版本

// 2. 参数定义
parameter DATA_WIDTH = 32;
parameter FIFO_DEPTH = 8;

// 3. 端口声明
module module_name (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire [DATA_WIDTH-1:0]   data_in,
    output reg  [DATA_WIDTH-1:0]   data_out
);

// 4. 内部信号
reg [DATA_WIDTH-1:0] data_reg;

// 5. 时序逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_reg <= {DATA_WIDTH{1'b0}};
    else
        data_reg <= data_in;
end

// 6. 组合逻辑
always @(*) begin
    data_out = data_reg;
end

endmodule
```

### 命名规范

| 类型 | 风格 | 示例 |
|------|------|------|
| 模块名 | 小写下划线 | `data_path` |
| 信号名 | 小写下划线 | `data_valid` |
| 参数名 | 大写下划线 | `DATA_WIDTH` |
| 时钟名 | clk 前缀 | `clk_core` |
| 复位名 | rst 后缀 | `rst_core_n` |

---

## 时钟设计

### 时钟域

```
┌─────────────────────────────────────────────┐
│  时钟域划分                                  │
│  ┌─────────────┐  ┌─────────────┐           │
│  │  clk_core   │  │  clk_bus    │           │
│  │  (1 GHz)    │  │  (500 MHz)  │           │
│  └─────────────┘  └─────────────┘           │
│  ┌─────────────┐  ┌─────────────┐           │
│  │  clk_io     │  │  clk_slow   │           │
│  │  (200 MHz)  │  │  (50 MHz)   │           │
│  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────┘
```

### 跨时钟域（CDC）

| 类型 | 方法 | 说明 |
|------|------|------|
| 单比特 | 双触发器 | 最简单 |
| 多比特 | 异步 FIFO | 数据传输 |
| 多比特 | 格雷码 | 指针同步 |
| 脉冲 | 脉冲同步器 | 脉冲传递 |

### 双触发器同步器

```verilog
// 单比特 CDC 同步器
module cdc_sync (
    input  wire clk_dst,
    input  wire rst_n,
    input  wire sig_src,
    output wire sig_dst
);

reg sig_sync1, sig_sync2;

always @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) begin
        sig_sync1 <= 1'b0;
        sig_sync2 <= 1'b0;
    end else begin
        sig_sync1 <= sig_src;
        sig_sync2 <= sig_sync1;
    end
end

assign sig_dst = sig_sync2;

endmodule
```

---

## 复位设计

### 复位类型

| 类型 | 说明 | 优点 | 缺点 |
|------|------|------|------|
| 同步复位 | 时钟边沿复位 | 无毛刺 | 需要时钟 |
| 异步复位 | 立即复位 | 不需时钟 | 可能有毛刺 |
| 异步复位同步释放 | 结合两者 | 综合优点 | 设计复杂 |

### 异步复位同步释放

```verilog
// 异步复位同步释放
module reset_sync (
    input  wire clk,
    input  wire rst_n_async,
    output wire rst_n_sync
);

reg [1:0] rst_n_reg;

always @(posedge clk or negedge rst_n_async) begin
    if (!rst_n_async)
        rst_n_reg <= 2'b00;
    else
        rst_n_reg <= {rst_n_reg[0], 1'b1};
end

assign rst_n_sync = rst_n_reg[1];

endmodule
```

---

## 逻辑综合

### 综合流程

```
1. 读入 RTL
   read_verilog design.v

2. 设置库
   set_target_library tcbn28hpcpluswc.lib

3. 设置约束
   create_clock -period 1.0 [get_ports clk]
   set_input_delay 0.5 [get_ports data_in]

4. 编译
   compile_ultra

5. 报告
   report_timing
   report_area
   report_power

6. 输出
   write -format verilog -hierarchy -output netlist.v
```

### 时序约束

```tcl
# 时钟定义
create_clock -name clk -period 1.0 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_latency 0.5 [get_clocks clk]

# 输入延迟
set_input_delay -clock clk -max 0.5 [get_ports data_in]
set_input_delay -clock clk -min 0.1 [get_ports data_in]

# 输出延迟
set_output_delay -clock clk -max 0.5 [get_ports data_out]
set_output_delay -clock clk -min 0.1 [get_ports data_out]

# 负载
set_load 0.1 [get_ports data_out]

# 驱动
set_drive 0 [get_ports clk]
set_drive 0 [get_ports rst_n]

# 伪路径
set_false_path -from [get_ports rst_n]

# 多周期路径
set_multicycle_path 2 -setup -from [get_pins reg1/Q] -to [get_pins reg2/D]
set_multicycle_path 1 -hold -from [get_pins reg1/Q] -to [get_pins reg2/D]
```

### 综合优化

| 优化类型 | 方法 | 说明 |
|----------|------|------|
| 时序优化 | 重定时 | 移动寄存器位置 |
| 时序优化 | 逻辑复制 | 复制关键路径逻辑 |
| 时序优化 | 引脚交换 | 优化引脚连接 |
| 面积优化 | 逻辑共享 | 共享相同逻辑 |
| 面积优化 | 资源复用 | 时分复用 |
| 功耗优化 | 时钟门控 | 关闭空闲时钟 |
| 功耗优化 | 操作数隔离 | 隔离无效信号 |

---

## 形式验证

### 等价性检查

```
RTL 网表  ←→  门级网表
    ↓              ↓
  逻辑锥        逻辑锥
    ↓              ↓
  比较相等性
    ↓
  验证结果
```

### 形式验证工具

| 工具 | 供应商 | 用途 |
|------|--------|------|
| Formality | Synopsys | 等价性检查 |
| Conformal | Cadence | 等价性检查 |
| JasperGold | Cadence | 属性检查 |

### 形式验证流程

```tcl
# Synopsys Formality
read_verilog -container r [list rtl.v]
read_verilog -container i [list netlist.v]

set_top r:/WORK/top
set_top i:/WORK/top

match
verify

report_failing > failing.rpt
```

---

## 门级仿真

### 门级仿真目的

- **时序验证**：验证时序约束正确性
- **功能验证**：验证综合后功能正确性
- **X 态传播**：检查 X 态传播问题

### 门级仿真流程

```
门级网表 + SDF
    ↓
仿真工具
    ↓
激励输入
    ↓
功能检查
    ↓
时序检查
```

### SDF（标准延迟格式）

```
(DELAYFILE
  (SDFVERSION "3.0")
  (DESIGN "top")
  (DATE "2024-01-01")
  (VENDOR "TSMC")
  (PROGRAM "PrimeTime")
  (VERSION "1.0")
  (DIVIDER /)
  (TIMESCALE 1ps)
  (CELL
    (CELLTYPE "AND2X1")
    (INSTANCE u1)
    (DELAY
      (ABSOLUTE
        (IOPATH A Y (0.1:0.2:0.3) (0.1:0.2:0.3))
        (IOPATH B Y (0.1:0.2:0.3) (0.1:0.2:0.3))
      )
    )
  )
)
```

---

## 常见问题

### 时序不满足

1. **分析关键路径**：report_timing
2. **优化 RTL**：增加流水线
3. **调整约束**：放松非关键路径
4. **手动优化**：关键路径手动优化

### CDC 问题

1. **识别 CDC 路径**：CDC 检查工具
2. **添加同步器**：双触发器/FIFO
3. **验证 CDC**：CDC 形式验证

### 功耗超标

1. **时钟门控**：增加时钟门控
2. **操作数隔离**：减少无效翻转
3. **多电压域**：降低非关键模块电压

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys DC User Guide | 综合工具 |
| REF-002 | Synopsys VCS User Guide | 仿真工具 |
| REF-003 | Synopsys Formality User Guide | 形式验证工具 |
| REF-004 | Cadence Genus User Guide | 综合工具 |
