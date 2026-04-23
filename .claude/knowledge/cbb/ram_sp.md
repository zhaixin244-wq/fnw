# ram_sp — 单端口 RAM

> **用途**：单端口同步读写存储器，用于 FIFO 存储阵列、缓冲区、查找表
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

单端口 RAM（Single-Port RAM）在同一时钟下通过单一地址端口进行读写操作。写操作在时钟上升沿生效，读操作为寄存器输出（延迟 1 周期）。综合工具会自动映射到 FPGA Block RAM 或 ASIC SRAM。

```
clk ──> ┌──────────┐
addr ──> │ ram_sp   │ ──rdata──> 读数据
wdata ─> │ (D×W)    │
we ────> └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽（bit） |
| `ADDR_WIDTH` | parameter | 8 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | parameter | `""` | 初始化文件路径（空=不初始化） |
| `READ_LATENCY` | parameter | 1 | 读延迟（1=寄存器输出，0=组合输出） |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `addr` | I | `ADDR_WIDTH` | clk | 读写地址 |
| `wdata` | I | `DATA_WIDTH` | clk | 写数据 |
| `we` | I | 1 | clk | 写使能 |
| `rdata` | O | `DATA_WIDTH` | clk | 读数据 |

---

## 时序

### 写操作

```
clk     __|‾|__|‾|__|‾|__|‾|__
addr    ___| A0  | A1  | A2  |
wdata   ___| D0  | D1  | D2  |
we      ___|‾‾‾‾‾|‾‾‾‾‾|‾‾‾‾‾|
                ↑ 写入 A0=D0   ↑ 写入 A1=D1
```

### 读操作（寄存器输出）

```
clk     __|‾|__|‾|__|‾|__|‾|__
addr    ___| A0  | A1  | A2  |
we      _______________________
rdata   _________| D(A0)| D(A1)|  (延迟 1 周期)
```

### 读写同地址

```
clk     __|‾|__|‾|__|‾|__
addr    ___| A0  | A0  |
wdata   ___| Dnew|___
we      ___|‾‾‾‾‾|_____
rdata   _________| Dold|  (读到旧数据，下周期才看到新数据)
```

---

## 用法

### 基本使用

```verilog
ram_sp #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (10)      // 1024 深度
) u_ram (
    .clk   (clk),
    .addr  (mem_addr),
    .wdata (mem_wdata),
    .we    (mem_we),
    .rdata (mem_rdata)
);
```

### 带初始化

```verilog
// 从文件初始化 ROM 内容
ram_sp #(
    .DATA_WIDTH (16),
    .ADDR_WIDTH (8),
    .INIT_FILE  ("rom_init.hex")
) u_rom (
    .clk   (clk),
    .addr  (rom_addr),
    .wdata (16'd0),
    .we    (1'b0),        // 只读模式
    .rdata (rom_data)
);
```

### FIFO 存储阵列

```verilog
// 作为同步 FIFO 的存储介质
ram_sp #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH)
) u_fifo_mem (
    .clk   (clk),
    .addr  (wr_en ? wr_ptr : rd_ptr),  // 写优先
    .wdata (push_data),
    .we    (wr_en),
    .rdata (pop_data)
);
```

---

## 关键实现细节

- **同步写**：`always @(posedge clk)` 写入，we=1 时更新
- **寄存器读**：读地址寄存一拍，rdata 为寄存器输出
- **综合映射**：FPGA 自动推断为 Block RAM，ASIC 映射到 SRAM compiler
- **读写同地址**：写优先（new data），读出为旧数据
- **初始化**：`INIT_FILE` 非空时在仿真初始化阶段 `$readmemh` 加载
- **面积**：2^ADDR_WIDTH × DATA_WIDTH bit 存储
- **时序**：单端口限制，每周期只能读或写，不能同时
