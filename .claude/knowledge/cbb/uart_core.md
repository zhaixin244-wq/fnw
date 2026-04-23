# uart_core — UART 收发器核心

> **用途**：通用异步收发传输器（UART）核心，支持可配置波特率和数据格式
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

UART 核心实现全双工异步串行通信的收发功能。发送端将并行数据串行化并加上起始位、停止位，接收端通过过采样检测起始位并恢复数据。支持 5-8 位数据位、1-2 位停止位、奇/偶/无校验、可配置过采样率。用于 SoC 调试串口、外设通信、低速设备接口等。

```
CPU ──tx_data──> ┌──────────┐ ──txd──> 串行输出
                 │uart_core  │
CPU <──rx_data── │          │ <──rxd── 串行输入
                 └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `CLK_FREQ` | parameter | 50_000_000 | 系统时钟频率（Hz） |
| `BAUD_RATE` | parameter | 115200 | 波特率 |
| `DATA_BITS` | parameter | 8 | 数据位数（5-8） |
| `STOP_BITS` | parameter | 1 | 停止位数（1-2） |
| `PARITY` | parameter | `"NONE"` | 校验：`"NONE"` / `"EVEN"` / `"ODD"` |
| `OVERSAMPLE` | parameter | 16 | 接收过采样率（推荐 16） |
| `TX_FIFO_DEPTH` | parameter | 16 | 发送 FIFO 深度 |
| `RX_FIFO_DEPTH` | parameter | 16 | 接收 FIFO 深度 |

---

## 接口

### CPU 侧

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 系统时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `tx_data` | I | `DATA_BITS` | clk | 发送数据 |
| `tx_valid` | I | 1 | clk | 发送有效 |
| `tx_ready` | O | 1 | clk | 发送就绪（FIFO 未满） |
| `rx_data` | O | `DATA_BITS` | clk | 接收数据 |
| `rx_valid` | O | 1 | clk | 接收有效 |
| `rx_ready` | I | 1 | clk | 接收就绪 |
| `tx_busy` | O | 1 | clk | 正在发送中 |
| `rx_busy` | O | 1 | clk | 正在接收中 |
| `frame_err` | O | 1 | clk | 帧错误 |
| `parity_err` | O | 1 | clk | 校验错误 |
| `overrun_err` | O | 1 | clk | 溢出错误（RX FIFO 满） |

### UART 物理接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `txd` | O | 1 | - | 串行发送输出 |
| `rxd` | I | 1 | - | 串行接收输入 |

---

## 时序

### UART 帧格式（8N1）

```
         起始位    数据位 (LSB first)            停止位
         ┌──┐                              ┌──────┐
   idle ‾‾|  | D0 D1 D2 D3 D4 D5 D6 D7    |      ‾‾ idle
         └──┘                              └──────┘
         1 bit   8 bits (可配置)          1-2 bit
```

### 发送时序

```
clk      __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
tx_data  ___|0x55__________|0xAA_______________
tx_valid _____|‾|_______________________________
tx_ready _______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
txd      ‾‾‾‾‾‾‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾‾‾‾
          ↑起始  0 1 0 1 0 1 0 1  ↑停止
tx_busy  _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
```

### 接收时序（16 倍过采样）

```
rxd      ‾‾‾‾‾‾‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|‾‾‾‾‾
          ↑起始  D0-D7          ↑停止
采样点           ↑第8个采样点（中间采样）
rx_data  ____________________________|0x55|____
rx_valid ________________________________|‾|___
rx_busy  _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
```

---

## 用法

### 调试串口

```verilog
uart_core #(
    .CLK_FREQ     (100_000_000),
    .BAUD_RATE    (115200),
    .DATA_BITS    (8),
    .STOP_BITS    (1),
    .PARITY       ("NONE"),
    .TX_FIFO_DEPTH(16),
    .RX_FIFO_DEPTH(16)
) u_debug_uart (
    .clk         (clk),
    .rst_n       (rst_n),
    // CPU 接口
    .tx_data     (dbg_tx_data),
    .tx_valid    (dbg_tx_valid),
    .tx_ready    (dbg_tx_ready),
    .rx_data     (dbg_rx_data),
    .rx_valid    (dbg_rx_valid),
    .rx_ready    (dbg_rx_ready),
    .tx_busy     (),
    .rx_busy     (),
    .frame_err   (uart_frame_err),
    .parity_err  (),
    .overrun_err (uart_overrun),
    // 物理接口
    .txd         (uart_txd_pin),
    .rxd         (uart_rxd_pin)
);
```

### 带流控的通信链路

```verilog
uart_core #(
    .CLK_FREQ     (50_000_000),
    .BAUD_RATE    (921600),
    .DATA_BITS    (8),
    .PARITY       ("EVEN"),
    .OVERSAMPLE   (8),
    .TX_FIFO_DEPTH(32),
    .RX_FIFO_DEPTH(32)
) u_highspeed_uart (
    .clk         (clk),
    .rst_n       (rst_n),
    .tx_data     (link_tx_data),
    .tx_valid    (link_tx_valid && !link_rx_busy),  // 软件流控
    .tx_ready    (link_tx_ready),
    .rx_data     (link_rx_data),
    .rx_valid    (link_rx_valid),
    .rx_ready    (link_rx_ready),
    .tx_busy     (link_tx_busy),
    .rx_busy     (link_rx_busy),
    .frame_err   (link_frame_err),
    .parity_err  (link_parity_err),
    .overrun_err (link_overrun),
    .txd         (link_txd),
    .rxd         (link_rxd)
);
```

---

## 关键实现细节

- **波特率生成**：`baud_div = CLK_FREQ / BAUD_RATE`，内部计数器分频
- **发送**：FIFO 缓存 → 移位寄存器串行输出，加上起始位/校验位/停止位
- **接收**：过采样检测起始位下降沿 → 采样点定位 → 移位寄存器接收 → 校验 → 存入 FIFO
- **过采样**：在每位中间采样（第 OVERSAMPLE/2 个采样点），抗噪声
- **起始位检测**：rxd 持续低电平超过半个位宽确认为有效起始位
- **帧错误**：停止位位置检测到低电平（期望高）
- **校验**：EVEN = 数据位异或结果，ODD = 取反
- **FIFO**：TX 侧和 RX 侧各一个同步 FIFO 缓冲
- **面积**：收发移位寄存器 + 2 个 FIFO + 波特率发生器，约 2-5K GE
