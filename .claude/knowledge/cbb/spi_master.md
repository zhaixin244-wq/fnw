# spi_master — SPI 主控制器

> **用途**：SPI（Serial Peripheral Interface）主设备控制器，支持全双工串行通信
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

SPI 主控制器实现标准 SPI 协议的主设备端。支持 4 种 SPI 模式（CPOL/CPHA 组合）、可配置数据宽度（4-32 bit）、可配置时钟分频、可选片选管理。用于访问 SPI Flash、SPI DAC/ADC、传感器、外设芯片等。

```
                ┌──────────────┐
CPU 寄存器 ───> │  spi_master   │ ──SCLK──> 时钟
                │              │ ──MOSI──> 主出从入
                │              │ <─MISO── 主入从出
                └──────────────┘ ──CS_N──> 片选
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 8 | 数据位宽（4-32） |
| `CLK_DIV` | parameter | 4 | 时钟分频比（SCLK = clk / CLK_DIV） |
| `CPOL` | parameter | 0 | 时钟极性：0=空闲低，1=空闲高 |
| `CPHA` | parameter | 0 | 时钟相位：0=第一边沿采样，1=第二边沿采样 |
| `CS_DELAY` | parameter | 1 | 片选建立/保持延迟（SCLK 周期数） |
| `LSB_FIRST` | parameter | 0 | 位序：0=MSB 先发，1=LSB 先发 |
| `NUM_CS` | parameter | 1 | 片选数量 |

---

## 接口

### CPU 侧

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 系统时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `tx_data` | I | `DATA_WIDTH` | clk | 发送数据 |
| `rx_data` | O | `DATA_WIDTH` | clk | 接收数据 |
| `start` | I | 1 | clk | 启动传输（单周期脉冲） |
| `done` | O | 1 | clk | 传输完成（单周期脉冲） |
| `busy` | O | 1 | clk | 正在传输中 |
| `cs_sel` | I | `$clog2(NUM_CS)` | clk | 片选选择 |

### SPI 物理接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `spi_sclk` | O | 1 | - | SPI 时钟 |
| `spi_mosi` | O | 1 | - | 主出从入 |
| `spi_miso` | I | 1 | - | 主入从出 |
| `spi_cs_n` | O | `NUM_CS` | - | 片选（低有效） |

---

## 时序

### SPI Mode 0（CPOL=0, CPHA=0）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
start       _____|‾|_________________________________
busy        _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
tx_data     _____|0xB7________________________________
spi_cs_n    _______|__________________________________|‾‾‾
spi_sclk    _____________|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|_
spi_mosi    _____|1 | 0 | 1 | 1 | 0 | 1 | 1 | 1 |______
spi_miso    ___________|D7|D6|D5|D4|D3|D2|D1|D0|________
done        ______________________________________________|‾|
rx_data     ______________________________________________|D|
              ↑ CS 建立  ↑ CLK 输出               ↑ CS 保持
```

### SPI Mode 3（CPOL=1, CPHA=1）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
spi_cs_n    _______|__________________________|‾‾‾
spi_sclk    ‾‾‾‾‾‾‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__
spi_mosi    _____|D7|D6|D5|D4|D3|D2|D1|D0|____
spi_miso    _______|D7|D6|D5|D4|D3|D2|D1|D0|__
              ↑ 空闲高    ↑ 下降沿输出，上升沿采样
```

---

## 用法

### SPI Flash 读取

```verilog
spi_master #(
    .DATA_WIDTH (8),
    .CLK_DIV    (2),        // SCLK = clk/2
    .CPOL       (0),
    .CPHA       (0),
    .LSB_FIRST (0)
) u_spi_flash (
    .clk       (clk),
    .rst_n     (rst_n),
    .tx_data   (flash_cmd),     // 0x03 = Read
    .rx_data   (flash_rdata),
    .start     (flash_start),
    .done      (flash_done),
    .busy      (flash_busy),
    .cs_sel    (1'b0),
    .spi_sclk  (flash_sclk),
    .spi_mosi  (flash_mosi),
    .spi_miso  (flash_miso),
    .spi_cs_n  (flash_cs_n)
);

// 连续读取：发送地址+dummy 后连续读数据
always @(posedge clk) begin
    if (flash_done && !addr_done)
        tx_data <= next_addr_byte;
    else if (flash_done && addr_done)
        tx_data <= 8'hFF;       // dummy
end
```

### 多设备 SPI 总线

```verilog
spi_master #(
    .DATA_WIDTH (16),
    .CLK_DIV    (8),
    .CPOL       (1),
    .CPHA       (1),
    .NUM_CS     (3)             // Flash, DAC, ADC
) u_spi_multi (
    .clk       (clk),
    .rst_n     (rst_n),
    .tx_data   (tx_data),
    .rx_data   (rx_data),
    .start     (start),
    .done      (done),
    .busy      (busy),
    .cs_sel    (dev_sel),       // 0=Flash, 1=DAC, 2=ADC
    .spi_sclk  (spi_sclk),
    .spi_mosi  (spi_mosi),
    .spi_miso  (spi_miso),
    .spi_cs_n  ({adc_cs_n, dac_cs_n, flash_cs_n})
);
```

---

## 关键实现细节

- **时钟生成**：CLK_DIV 分频，使用计数器在上升/下降沿翻转 SCLK
- **移位寄存器**：TX 移位寄存器在输出边沿移出 MOSI，RX 移位寄存器在采样边沿锁存 MISO
- **CPOL/CPHA**：
  - Mode 0 (CPOL=0, CPHA=0)：空闲低，上升沿采样，下降沿输出
  - Mode 1 (CPOL=0, CPHA=1)：空闲低，下降沿采样，上升沿输出
  - Mode 2 (CPOL=1, CPHA=0)：空闲高，下降沿采样，上升沿输出
  - Mode 3 (CPOL=1, CPHA=1)：空闲高，上升沿采样，下降沿输出
- **CS 管理**：start 前拉低 CS_N（延迟 CS_DELAY 周期），done 后拉高（延迟 CS_DELAY）
- **全双工**：同时发送和接收，每个 SCLK 周期完成 1 bit 双向传输
- **状态机**：IDLE → CS_SETUP → SHIFT(DATA_WIDTH cycles) → CS_HOLD → DONE → IDLE
- **面积**：2 × DATA_WIDTH 移位寄存器 + 计数器 + 状态机，约 1-2K GE
