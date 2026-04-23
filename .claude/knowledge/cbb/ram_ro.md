# ram_ro — 只读存储器（ROM）

> **用途**：预初始化只读存储器，用于查找表、微码、系数表等
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

只读存储器（ROM）在综合或仿真初始化时从文件加载内容，运行时只支持读操作。写端口被禁用或不存在。用于常量查找表（LUT）、微码存储、三角函数/对数系数表、中断向量表等只读场景。

```
clk ──> ┌──────────┐
addr ─> │  ram_ro  │ ──rdata──> 读数据
        │ (D×W)    │
        └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽（bit） |
| `ADDR_WIDTH` | parameter | 8 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | parameter | `""` | 初始化文件路径（HEX 格式） |
| `READ_LATENCY` | parameter | 1 | 读延迟（1=寄存器输出，0=组合输出） |
| `ROM_STYLE` | parameter | `"AUTO"` | 综合风格：`"AUTO"` / `"BLOCK"` / `"DISTRIBUTED"` |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `en` | I | 1 | clk | 读使能（可选，低功耗控制） |
| `addr` | I | `ADDR_WIDTH` | clk | 读地址 |
| `rdata` | O | `DATA_WIDTH` | clk | 读数据 |

---

## 时序

### 寄存器输出（READ_LATENCY=1）

```
clk     __|‾|__|‾|__|‾|__|‾|__
en      ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
addr    ___| A0  | A1  | A2  |
rdata   _________| D(A0)| D(A1)|  (延迟 1 cycle)
```

### 组合输出（READ_LATENCY=0）

```
clk     __|‾|__|‾|__|‾|__
addr    ___| A0  | A1  |
rdata   ___| D(A0)| D(A1)|  (无延迟，直接输出)
```

---

## 初始化文件格式

```hex
// rom_init.hex（每行一个数据，地址递增）
0000_0001
0000_0002
0000_0004
0000_0008
// ...
```

---

## 用法

### 三角函数查找表

```verilog
// sin(x) 查找表，256 点，16-bit 精度
ram_ro #(
    .DATA_WIDTH (16),
    .ADDR_WIDTH (8),
    .INIT_FILE  ("sin_lut.hex"),
    .ROM_STYLE  ("DISTRIBUTED")     // 小容量用分布式 RAM
) u_sin_lut (
    .clk   (clk),
    .en    (1'b1),
    .addr  (angle_index),
    .rdata (sin_value)
);
```

### 微码存储

```verilog
// 微控制器指令 ROM
ram_ro #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (12),              // 4K 深度
    .INIT_FILE  ("firmware.hex"),
    .ROM_STYLE  ("BLOCK")          // 大容量用 Block RAM
) u_code_rom (
    .clk   (clk),
    .en    (fetch_en),
    .addr  (pc[13:2]),
    .rdata (instruction)
);
```

### 中断向量表

```verilog
ram_ro #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (5),               // 32 个中断向量
    .INIT_FILE  ("vectors.hex"),
    .READ_LATENCY(0)               // 组合输出，快速跳转
) u_ivt (
    .clk   (clk),
    .en    (1'b1),
    .addr  (irq_id),
    .rdata (irq_handler_addr)
);
```

---

## 关键实现细节

- **无写逻辑**：存储内容由 INIT_FILE 在仿真/综合时加载
- **综合推断**：ROM_STYLE="BLOCK" 推断为 Block RAM，"DISTRIBUTED" 推断为 LUT ROM
- **无 INIT_FILE**：内容全 0（综合工具默认行为）
- **FPGA 实现**：小容量（≤64×32）用分布式 RAM 省 BRAM 资源
- **ASIC 实现**：编译为 ROM macro，面积 = 2^ADDR_WIDTH × DATA_WIDTH
- **组合输出风险**：READ_LATENCY=0 时 addr 到 rdata 为纯组合路径，大深度 ROM 可能成关键路径
- **面积**：同 RAM，但无写电路，略小于同容量 RAM
