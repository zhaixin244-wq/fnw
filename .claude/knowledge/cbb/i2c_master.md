# i2c_master — I2C 主控制器

> **用途**：I2C（Inter-Integrated Circuit）总线主设备控制器
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

I2C 主控制器实现标准 I2C 协议的主设备端。支持 7 位和 10 位寻址、标准模式（100 kbps）、快速模式（400 kbps）、快速模式+（1 Mbps）。实现 START/STOP 条件生成、地址发送、数据读写、ACK/NACK 检测、时钟拉伸支持。用于访问 I2C EEPROM、传感器、PMIC、GPIO 扩展器等。

```
CPU 寄存器 ──> ┌──────────────┐ ──scl_o──> SCL (时钟)
               │  i2c_master   │ <─scl_i──
               │              │ ──sda_o──> SDA (数据)
               └──────────────┘ <─sda_i──
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `CLK_FREQ` | parameter | 50_000_000 | 系统时钟频率（Hz） |
| `I2C_FREQ` | parameter | 400_000 | I2C 时钟频率（Hz） |
| `ADDR_MODE` | parameter | `"7BIT"` | 地址模式：`"7BIT"` / `"10BIT"` |
| `TEN_BIT_EN` | parameter | 0 | 10 位地址使能 |
| `CLOCK_STRETCH` | parameter | 1 | 时钟拉伸支持 |
| `CMD_FIFO_DEPTH` | parameter | 8 | 命令 FIFO 深度 |

---

## 接口

### CPU 侧

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 系统时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `dev_addr` | I | 10 | clk | 从设备地址 |
| `wr_data` | I | 8 | clk | 写数据 |
| `rd_data` | O | 8 | clk | 读数据 |
| `cmd` | I | 3 | clk | 命令：0=START, 1=WRITE, 2=READ, 3=STOP, 4=RSTART |
| `cmd_valid` | I | 1 | clk | 命令有效 |
| `cmd_ready` | O | 1 | clk | 命令就绪 |
| `done` | O | 1 | clk | 命令完成 |
| `ack` | O | 1 | clk | ACK 状态（0=ACK, 1=NACK） |
| `busy` | O | 1 | clk | 总线忙 |
| `arbitration_lost` | O | 1 | clk | 仲裁丢失 |
| `error` | O | 1 | clk | 总线错误 |

### I2C 物理接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `scl_i` | I | 1 | - | SCL 输入（检测拉伸） |
| `scl_o` | O | 1 | - | SCL 输出（开漏） |
| `scl_oe` | O | 1 | - | SCL 输出使能 |
| `sda_i` | I | 1 | - | SDA 输入 |
| `sda_o` | O | 1 | - | SDA 输出（开漏） |
| `sda_oe` | O | 1 | - | SDA 输出使能 |

---

## 时序

### I2C 字节写（START + Addr + W + Data + STOP）

```
SCL  ‾‾‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|‾‾‾‾‾
SDA  ‾‾|   |A6|A5|A4|A3|A2|A1|A0| 0|ACK|D7|D6|D5|D4|D3|D2|D1|D0|ACK|  |‾‾
     ↑START   7-bit 地址       W  ↑  8-bit 数据       ↑  ↑STOP
```

### I2C 字节读（START + Addr + R + Data + NACK + STOP）

```
SCL  ‾‾‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|‾‾‾‾‾
SDA  ‾‾|   |A6|A5|A4|A3|A2|A1|A0| 1|ACK|D7|D6|D5|D4|D3|D2|D1|D0|NACK| |‾‾
     ↑START   7-bit 地址       R  ↑  读数据(Master NACK)  ↑STOP
```

### CPU 命令序列

```
clk        __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
cmd        ___|START|WRITE___|WRITE___|RSTART|READ___|STOP
cmd_valid  _____|‾|_______|‾|_______|‾|______|‾|_____|‾|__
done       _______|‾|_______|‾|_______|‾|______|‾|_____|‾|__
ack        _________|0_______|0_______|0______|0______|0___
           ↑ 发送START  ↑ 写地址  ↑ 写数据  ↑ 重复START ↑ 读数据  ↑ STOP
```

---

## 用法

### I2C EEPROM 读写

```verilog
i2c_master #(
    .CLK_FREQ  (100_000_000),
    .I2C_FREQ  (400_000),
    .ADDR_MODE ("7BIT")
) u_i2c_eeprom (
    .clk        (clk),
    .rst_n      (rst_n),
    .dev_addr   (7'h50),           // EEPROM 地址
    .wr_data    (tx_byte),
    .rd_data    (rx_byte),
    .cmd        (i2c_cmd),
    .cmd_valid  (i2c_cmd_valid),
    .cmd_ready  (i2c_cmd_ready),
    .done       (i2c_done),
    .ack        (i2c_ack),
    .busy       (i2c_busy),
    .arbitration_lost (),
    .error      (i2c_error),
    .scl_i      (scl_in),
    .scl_o      (scl_out),
    .scl_oe     (scl_oe),
    .sda_i      (sda_in),
    .sda_o      (sda_out),
    .sda_oe     (sda_oe)
);

// 写 EEPROM 序列：START → Addr+W → MemAddr → Data → STOP
// 读 EEPROM 序列：START → Addr+W → MemAddr → RSTART → Addr+R → Data → NACK → STOP
```

### I2C 传感器连续读

```verilog
i2c_master #(
    .CLK_FREQ     (50_000_000),
    .I2C_FREQ     (100_000),
    .CLOCK_STRETCH(1)               // 传感器可能拉伸时钟
) u_i2c_sensor (
    .clk        (clk),
    .rst_n      (rst_n),
    .dev_addr   (7'h48),           // 温度传感器
    .wr_data    (reg_addr),
    .rd_data    (sensor_data),
    .cmd        (cmd),
    .cmd_valid  (cmd_valid),
    .cmd_ready  (cmd_ready),
    .done       (done),
    .ack        (ack),
    .busy       (busy),
    .arbitration_lost (),
    .error      (error),
    .scl_i      (scl), .scl_o(), .scl_oe(scl_oe),
    .sda_i      (sda), .sda_o(), .sda_oe(sda_oe)
);
```

---

## 关键实现细节

- **时钟分频**：`scl_div = CLK_FREQ / (4 × I2C_FREQ)`，四分频产生 SCL 四个相位（低→下降→高→上升）
- **开漏输出**：scl_o/sda_o 为 0 时拉低，1 时释放（高阻），外部上拉电阻拉高
- **START 条件**：SCL 高时 SDA 从高到低
- **STOP 条件**：SCL 高时 SDA 从低到高
- **ACK/NACK**：第 9 个 SCL 时钟时，接收方拉低 SDA = ACK，释放 = NACK
- **时钟拉伸**：CLOCK_STRETCH=1 时，检测 scl_i=0 则暂停 SCL 输出
- **仲裁丢失**：SDA 输出为高但检测到低 = 仲裁失败，立即释放总线
- **状态机**：IDLE → START → ADDR → RW → ACK_CHECK → DATA → ACK → STOP/RSTART
- **面积**：状态机 + 移位寄存器 + 分频计数器 + 可选命令 FIFO，约 2-4K GE
