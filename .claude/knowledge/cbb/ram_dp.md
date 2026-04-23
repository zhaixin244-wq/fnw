# ram_dp — 双端口 RAM

> **用途**：双端口同步读写存储器，支持同时读写操作
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

双端口 RAM（Dual-Port RAM）提供两个独立的读写端口（Port A 和 Port B），允许在同一时钟周期内同时进行两个独立的读写操作。常用于异步 FIFO 的存储介质、CPU 寄存文件、双访问缓冲区等场景。

```
clk ──> ┌──────────────┐
addr_a ─> │              │ ──rdata_a──> 端口 A 读数据
wdata_a ─> │   ram_dp     │
we_a ───> │   (D×W)      │
addr_b ─> │              │ ──rdata_b──> 端口 B 读数据
wdata_b ─> │              │
we_b ───> └──────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽（bit） |
| `ADDR_WIDTH` | parameter | 8 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | parameter | `""` | 初始化文件路径（空=不初始化） |
| `CLOCKING` | parameter | `"COMMON"` | 时钟模式：`"COMMON"` = 同时钟，`"INDEPENDENT"` = 独立时钟 |

---

## 接口

### 端口 A

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_a` | I | 1 | - | 端口 A 时钟 |
| `addr_a` | I | `ADDR_WIDTH` | clk_a | 端口 A 地址 |
| `wdata_a` | I | `DATA_WIDTH` | clk_a | 端口 A 写数据 |
| `we_a` | I | 1 | clk_a | 端口 A 写使能 |
| `rdata_a` | O | `DATA_WIDTH` | clk_a | 端口 A 读数据 |

### 端口 B

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_b` | I | 1 | - | 端口 B 时钟 |
| `addr_b` | I | `ADDR_WIDTH` | clk_b | 端口 B 地址 |
| `wdata_b` | I | `DATA_WIDTH` | clk_b | 端口 B 写数据 |
| `we_b` | I | 1 | clk_b | 端口 B 写使能 |
| `rdata_b` | O | `DATA_WIDTH` | clk_b | 端口 B 读数据 |

> CLOCKING="COMMON" 时，`clk_a` 和 `clk_b` 连接同一时钟。

---

## 时序

### 独立读写

```
clk_a   __|‾|__|‾|__|‾|__|‾|__
addr_a  ___| A0  | A1  | A2  |
wdata_a ___| D0  | D1  |___
we_a    ___|‾‾‾‾‾|‾‾‾‾‾|_____
rdata_a _________| Q(A0)| Q(A1)|  (读延迟 1 cycle)

clk_b   __|‾|__|__|‾|__|‾|__
addr_b  ___| B0  | B1  |
we_b    ____________________
rdata_b _________| Q(B0)| Q(B1)|
```

### 同地址冲突（CLOCKING=COMMON）

```
clk     __|‾|__|‾|__|‾|__
addr_a  ___| X   | X   |
we_a    ___|‾‾‾‾‾|_____
addr_b  ___| X   | X   |
we_b    ___|‾‾‾‾‾|_____
rdata_a _________| ??? |  (写冲突：内容未定义)
rdata_b _________| ??? |
```

- 双端口同时写同地址时行为未定义
- 一端写一端读同地址时，读端看到旧数据

---

## 用法

### 异步 FIFO 存储介质

```verilog
// 写端口（clk_wr 域），读端口（clk_rd 域）
ram_dp #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .CLOCKING   ("INDEPENDENT")
) u_fifo_mem (
    // 写端口
    .clk_a   (clk_wr),
    .addr_a  (wr_ptr[ADDR_WIDTH-1:0]),
    .wdata_a (push_data),
    .we_a    (push && !full),
    .rdata_a (),
    // 读端口
    .clk_b   (clk_rd),
    .addr_b  (rd_ptr[ADDR_WIDTH-1:0]),
    .wdata_b ({DATA_WIDTH{1'b0}}),
    .we_b    (1'b0),
    .rdata_b (pop_data)
);
```

### CPU 寄存器文件

```verilog
// 两个读端口、一个写端口（使用 2 个 DP RAM 实现 3 端口）
ram_dp #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (5)        // 32 个寄存器
) u_regfile (
    .clk_a   (clk),
    .addr_a  (rs1_addr),   // 读端口 1
    .wdata_a (wb_data),
    .we_a    (wb_en),
    .rdata_a (rs1_data),
    .clk_b   (clk),
    .addr_b  (rs2_addr),   // 读端口 2
    .wdata_b (32'd0),
    .we_b    (1'b0),
    .rdata_b (rs2_data)
);
```

### 双访问缓冲区

```verilog
// 生产者写端口 + 消费者读端口（同时钟）
ram_dp #(
    .DATA_WIDTH (64),
    .ADDR_WIDTH (6),
    .CLOCKING   ("COMMON")
) u_buf (
    .clk_a   (clk),
    .addr_a  (wr_addr),
    .wdata_a (wr_data),
    .we_a    (wr_en),
    .rdata_a (),
    .clk_b   (clk),
    .addr_b  (rd_addr),
    .wdata_b (64'd0),
    .we_b    (1'b0),
    .rdata_b (rd_data)
);
```

---

## 关键实现细节

- **独立端口**：两个端口完全独立，可同时读或写
- **同步写**：每个端口在时钟上升沿写入（we=1）
- **寄存器读**：读地址寄存一拍，rdata 延迟 1 周期
- **冲突处理**：双写同地址行为未定义，综合工具通常实现为 write-first 或 read-first
- **FPGA 映射**：自动推断为 True Dual-Port Block RAM
- **ASIC 映射**：需 SRAM compiler 生成双端口 SRAM macro
- **CLOCKING=INDEPENDENT**：两个独立时钟，适合异步 FIFO，但地址变化需满足 SRAM 时序要求
- **面积**：与单端口 RAM 相同（2^ADDR_WIDTH × DATA_WIDTH bit），但端口电路面积翻倍
