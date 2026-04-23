# ram_tp — 真双端口 RAM

> **用途**：两个端口均可独立读写的真双端口存储器
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

真双端口 RAM（True Dual-Port RAM）提供两个完全独立的读写端口，每个端口都有独立的地址、写数据、写使能和读数据端口，两个端口可以同时进行读或写操作。与 `ram_dp`（一个端口专写、一个端口专读）不同，真双端口 RAM 的两个端口是对称的，灵活度更高。常用于 CPU 寄存器文件（两个读端口+一个写端口）、共享缓存、乒乓缓冲等场景。

```
clk_a ──> ┌──────────────┐
addr_a ─> │              │ ──rdata_a──> 端口 A
wdata_a ─> │   ram_tp     │
we_a ───> │   (D×W)      │
rd_a ───> │              │
clk_b ──> │              │
addr_b ─> │              │ ──rdata_b──> 端口 B
wdata_b ─> │              │
we_b ───> │              │
rd_b ───> └──────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽（bit） |
| `ADDR_WIDTH` | parameter | 8 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | parameter | `""` | 初始化文件路径（空=不初始化） |
| `CLOCKING` | parameter | `"COMMON"` | 时钟模式：`"COMMON"` = 同时钟，`"INDEPENDENT"` = 独立时钟 |
| `READ_LATENCY` | parameter | 1 | 读延迟（1=寄存器输出，0=组合输出） |
| `WRITE_MODE` | parameter | `"READ_FIRST"` | 写冲突模式：`"READ_FIRST"` / `"WRITE_FIRST"` / `"NO_CHANGE"` |

---

## 接口

### 端口 A

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_a` | I | 1 | - | 端口 A 时钟 |
| `addr_a` | I | `ADDR_WIDTH` | clk_a | 端口 A 地址 |
| `wdata_a` | I | `DATA_WIDTH` | clk_a | 端口 A 写数据 |
| `we_a` | I | 1 | clk_a | 端口 A 写使能 |
| `rd_a` | I | 1 | clk_a | 端口 A 读使能 |
| `rdata_a` | O | `DATA_WIDTH` | clk_a | 端口 A 读数据 |

### 端口 B

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_b` | I | 1 | - | 端口 B 时钟 |
| `addr_b` | I | `ADDR_WIDTH` | clk_b | 端口 B 地址 |
| `wdata_b` | I | `DATA_WIDTH` | clk_b | 端口 B 写数据 |
| `we_b` | I | 1 | clk_b | 端口 B 写使能 |
| `rd_b` | I | 1 | clk_b | 端口 B 读使能 |
| `rdata_b` | O | `DATA_WIDTH` | clk_b | 端口 B 读数据 |

---

## 时序

### 双端口独立读写（不同地址）

```
clk_a   __|‾|__|‾|__|‾|__|‾|__
addr_a  ___| A0  | A1  | A2  |
wdata_a ___| D0  | D1  |___
we_a    ___|‾‾‾‾‾|‾‾‾‾‾|_____
rdata_a _________| Q(A0)| Q(A1)|  (读延迟 1 cycle)

clk_b   __|‾|__|‾|__|‾|__|‾|__
addr_b  ___| B0  | B1  | B2  |
we_b    ___|‾‾‾‾‾|_____|‾‾‾‾‾|
wdata_b ___| E0  |___  | E2  |
rdata_b _________| Q(B0)| Q(B1)|
```

### 同地址冲突

#### WRITE_MODE = "READ_FIRST"

```
clk     __|‾|__|‾|__|‾|__
addr_a  ___| X   | X   |
we_a    ___|‾‾‾‾‾|_____
wdata_a ___| Dnew|___
addr_b  ___| X   | X   |
rd_b    ___|‾‾‾‾‾|‾‾‾‾‾|
rdata_b _________| Dold|  (读到旧数据，写操作在读之后生效)
```

#### WRITE_MODE = "WRITE_FIRST"

```
clk     __|‾|__|‾|__|‾|__
addr_a  ___| X   | X   |
we_a    ___|‾‾‾‾‾|_____
wdata_a ___| Dnew|___
addr_b  ___| X   | X   |
rd_b    ___|‾‾‾‾‾|‾‾‾‾‾|
rdata_b _________| Dnew|  (读到新数据，写操作立即生效)
```

---

## 用法

### CPU 寄存器文件（2 读 1 写）

```verilog
ram_tp #(
    .DATA_WIDTH  (32),
    .ADDR_WIDTH  (5),          // 32 个寄存器
    .WRITE_MODE  ("READ_FIRST"),
    .CLOCKING    ("COMMON")
) u_regfile (
    // 端口 A：读 rs1 + 写回
    .clk_a   (clk),
    .addr_a  (wb_en ? wb_addr : rs1_addr),
    .wdata_a (wb_data),
    .we_a    (wb_en),
    .rd_a    (!wb_en),
    .rdata_a (rs1_data),
    // 端口 B：读 rs2
    .clk_b   (clk),
    .addr_b  (rs2_addr),
    .wdata_b (32'd0),
    .we_b    (1'b0),
    .rd_b    (1'b1),
    .rdata_b (rs2_data)
);
```

### 乒乓缓冲

```verilog
// 两个 RAM，读写交替
ram_tp #(
    .DATA_WIDTH  (64),
    .ADDR_WIDTH  (10),
    .CLOCKING    ("INDEPENDENT")
) u_ping (
    .clk_a   (clk_wr),
    .addr_a  (wr_addr),
    .wdata_a (wr_data),
    .we_a    (wr_en && !ping_pong_sel),
    .rd_a    (1'b0),
    .rdata_a (),
    .clk_b   (clk_rd),
    .addr_b  (rd_addr),
    .wdata_b (64'd0),
    .we_b    (1'b0),
    .rd_b    (1'b1),
    .rdata_b (ping_data)
);

ram_tp #(
    .DATA_WIDTH  (64),
    .ADDR_WIDTH  (10),
    .CLOCKING    ("INDEPENDENT")
) u_pong (
    .clk_a   (clk_wr),
    .addr_a  (wr_addr),
    .wdata_a (wr_data),
    .we_a    (wr_en && ping_pong_sel),
    .rd_a    (1'b0),
    .rdata_a (),
    .clk_b   (clk_rd),
    .addr_b  (rd_addr),
    .wdata_b (64'd0),
    .we_b    (1'b0),
    .rd_b    (1'b1),
    .rdata_b (pong_data)
);

assign rd_data = ping_pong_sel ? ping_data : pong_data;
```

### 共享数据缓冲

```verilog
// 两个处理器共享数据区
ram_tp #(
    .DATA_WIDTH  (16),
    .ADDR_WIDTH  (12),       // 4K 深度
    .CLOCKING    ("INDEPENDENT"),
    .WRITE_MODE  ("WRITE_FIRST")
) u_shared_mem (
    // CPU A 端口
    .clk_a   (clk_a),
    .addr_a  (cpu_a_addr),
    .wdata_a (cpu_a_wdata),
    .we_a    (cpu_a_we),
    .rd_a    (cpu_a_re),
    .rdata_a (cpu_a_rdata),
    // CPU B 端口
    .clk_b   (clk_b),
    .addr_b  (cpu_b_addr),
    .wdata_b (cpu_b_wdata),
    .we_b    (cpu_b_we),
    .rd_b    (cpu_b_re),
    .rdata_b (cpu_b_rdata)
);
```

---

## 关键实现细节

- **双端口对称**：两个端口功能完全一致，均可独立读写
- **同步写**：每个端口在时钟上升沿写入（we=1）
- **寄存器读**：读使能 rd=1 时，数据在下一周期输出
- **写冲突模式**：
  - `READ_FIRST`：同地址写+读时，读到旧数据（推荐，最常见）
  - `WRITE_FIRST`：读到新数据
  - `NO_CHANGE`：写操作期间读输出保持不变
- **双写同地址**：两个端口同时写同地址时行为未定义，需上层仲裁避免
- **FPGA 映射**：自动推断为 True Dual-Port Block RAM（如 Xilinx RAMB36E1）
- **ASIC 映射**：SRAM compiler 生成双端口 SRAM macro
- **面积**：2^ADDR_WIDTH × DATA_WIDTH bit 存储 + 双端口读写电路
- **与 ram_dp 区别**：ram_dp 一个端口只写、一个端口只读；ram_tp 两个端口均可读写
