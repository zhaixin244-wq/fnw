# crc_gen — CRC 生成器

> **用途**：循环冗余校验（CRC）计算，用于数据完整性校验
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

CRC 生成器实现可配置的 CRC 计算，支持常见 CRC 多项式（CRC-8, CRC-16, CRC-32 等）。数据按 bit 或 byte 流式输入，每周期计算一步 CRC 值。用于通信协议校验（Ethernet, USB, PCIe）、存储保护、数据链路完整性验证等场景。

```
data_in ──> ┌──────────┐ ──crc_out──> CRC 校验值
             │ crc_gen  │ ──crc_match──> 校验通过标志
clk ───────> └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 8 | 每周期输入数据位宽 |
| `CRC_WIDTH` | parameter | 32 | CRC 位宽 |
| `POLY` | parameter | `32'h04C11DB7` | CRC 多项式（CRC-32） |
| `INIT` | parameter | `{CRC_WIDTH{1'b1}}` | CRC 初始值 |
| `REFLECT_IN` | parameter | 1 | 输入数据位序反转 |
| `REFLECT_OUT` | parameter | 1 | 输出 CRC 位序反转 |
| `XOR_OUT` | parameter | `{CRC_WIDTH{1'b1}}` | 输出异或值 |

---

## 常用 CRC 配置

| CRC 类型 | CRC_WIDTH | POLY | INIT | XOR_OUT | 用途 |
|----------|-----------|------|------|---------|------|
| CRC-8 | 8 | `8'h07` | `8'h00` | `8'h00` | SMBus |
| CRC-8/ITU | 8 | `8'h07` | `8'h00` | `8'h55` | ATM HEC |
| CRC-16 | 16 | `16'h8005` | `16'h0000` | `16'h0000` | Modbus |
| CRC-16/CCITT | 16 | `16'h1021` | `16'hFFFF` | `16'h0000` | X.25, HDLC |
| CRC-32 | 32 | `32'h04C11DB7` | `32'hFFFFFFFF` | `32'hFFFFFFFF` | Ethernet, ZIP |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `data_in` | I | `DATA_WIDTH` | clk | 输入数据 |
| `data_valid` | I | 1 | clk | 数据有效 |
| `crc_init` | I | 1 | clk | CRC 初始化（拉高一周期复位 CRC 值） |
| `crc_out` | O | `CRC_WIDTH` | clk | 当前 CRC 值 |
| `crc_final` | O | `CRC_WIDTH` | clk | 最终 CRC 值（应用 XOR_OUT） |

---

## 时序

### 流式 CRC 计算

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
data_valid  ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
data_in     ___| D0  | D1  | D2  | D3  |
crc_init    ___|‾|______________________  (第一拍初始化)
crc_out     ___|INIT| CRC0 | CRC1 | CRC2|  (逐步更新)
                          ↑ 每周期更新一次
```

### CRC 校验（含校验码输入）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
data_valid  ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
data_in     ___| D0  | D1  | D2  |CRC码|
crc_init    ___|‾|______________________
crc_out     ___|INIT| CRC0 | CRC1 | 0  |  (输入含校验码 → 结果为 0 = 校验通过)
```

---

## 用法

### CRC-32（以太网）

```verilog
crc_gen #(
    .DATA_WIDTH  (8),
    .CRC_WIDTH   (32),
    .POLY        (32'h04C11DB7),
    .INIT        (32'hFFFFFFFF),
    .REFLECT_IN  (1),
    .REFLECT_OUT (1),
    .XOR_OUT     (32'hFFFFFFFF)
) u_crc32 (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (eth_payload_byte),
    .data_valid (byte_valid),
    .crc_init   (frame_start),
    .crc_out    (crc_running),
    .crc_final  (crc_result)
);

// 校验：将接收到的 CRC 字节也输入，最终结果应为 CRC 残留值
// Ethernet CRC 残留 = 0xDEBB20E3
assign frame_ok = (crc_result == 32'hDEBB20E3);
```

### CRC-16/CCITT（HDLC）

```verilog
crc_gen #(
    .DATA_WIDTH  (1),
    .CRC_WIDTH   (16),
    .POLY        (16'h1021),
    .INIT        (16'hFFFF),
    .REFLECT_IN  (0),
    .REFLECT_OUT (0),
    .XOR_OUT     (16'h0000)
) u_crc16 (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (serial_bit),
    .data_valid (bit_valid),
    .crc_init   (frame_start),
    .crc_out    (crc_value),
    .crc_final  (crc_fcs)
);
```

### CRC-8（SMBus）

```verilog
crc_gen #(
    .DATA_WIDTH  (8),
    .CRC_WIDTH   (8),
    .POLY        (8'h07),
    .INIT        (8'h00),
    .REFLECT_IN  (0),
    .REFLECT_OUT (0),
    .XOR_OUT     (8'h00)
) u_crc8 (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (smbus_byte),
    .data_valid (byte_valid),
    .crc_init   (packet_start),
    .crc_out    (crc_calc),
    .crc_final  (crc_fcs)
);
```

---

## 关键实现细节

- **核心算法**：LFSR（线性反馈移位寄存器），每个数据 bit 与最高位异或后反馈到多项式定义的位
- **逐 bit 计算**：`for (i = 0; i < DATA_WIDTH; i = i + 1)` 逐步更新 CRC
- **REFLECT_IN**：输入数据 bit 序反转（MSB↔LSB），用于协议要求低位先发的场景
- **REFLECT_OUT**：输出 CRC bit 序反转
- **XOR_OUT**：最终 CRC 值异或操作（通常全 1 或全 0）
- **流水线**：单周期完成所有 DATA_WIDTH bit 计算，无流水线延迟
- **crc_init 优先级最高**：拉高时 CRC 复位为 INIT 值
- **面积**：CRC_WIDTH 个触发器 + DATA_WIDTH × CRC_WIDTH 个 XOR 门
- **综合优化**：DATA_WIDTH=1 时为串行 CRC，DATA_WIDTH=8/32 时综合工具会优化为并行 CRC
