# bit_reverse — 位序反转器

> **用途**：将数据位序完全翻转（MSB↔LSB），用于 CRC 输入位反射、SPI LSB-first 转换
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

位序反转器将输入数据的 bit 顺序完全翻转：bit[0] ↔ bit[N-1]，bit[1] ↔ bit[N-2]，以此类推。纯连线操作，无逻辑门。用于 CRC 位反射输入、SPI LSB-first/MSB-first 转换、FFT 位反转地址生成等场景。

```
data_in[N-1:0] ──> ┌──────────────┐ ──> data_out[N-1:0]
                   │ bit_reverse   │
                   └──────────────┘
  8'b10110010 → 8'b01001101
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 8 | 数据位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `data_in` | I | `DATA_WIDTH` | - | 输入数据 |
| `data_out` | O | `DATA_WIDTH` | - | 位序反转后的数据 |

> **注意**：本模块为纯连线逻辑（assign），无门延迟，无时钟/复位。

---

## 转换表

| DATA_WIDTH | data_in | data_out |
|-----------|---------|----------|
| 8 | 10110010 | 01001101 |
| 8 | 00001111 | 11110000 |
| 8 | 10000001 | 10000001 |
| 16 | A5A5 (1010_0101_1010_0101) | A5A5 (自反) |
| 32 | 12345678 | 1E6A2C48 |

---

## 用法

### CRC 位反射输入

```verilog
// CRC-32 (Ethernet) 要求输入数据位反射
bit_reverse #(.DATA_WIDTH(8)) u_byte_reverse (
    .data_in  (tx_byte),
    .data_out (tx_byte_reflected)
);

// 反射后的字节送入 CRC 计算
crc_gen #(
    .DATA_WIDTH(8), .REFLECT_IN(0)   // 已手动反射，CRC 不再反射
) u_crc (.data_in(tx_byte_reflected), ...);
```

### SPI LSB-first 转换

```verilog
// SPI 默认 MSB-first，设备要求 LSB-first 时
bit_reverse #(.DATA_WIDTH(8)) u_spi_reverse (
    .data_in  (spi_tx_data_msb),
    .data_out (spi_tx_data_lsb)
);

spi_master #(.LSB_FIRST(0)) u_spi (.tx_data(spi_tx_data_lsb), ...);
```

### FFT 蝶形地址生成

```verilog
// FFT 基-2 时间抽取需要位反转地址排列
bit_reverse #(.DATA_WIDTH(8)) u_fft_rev (
    .data_in  (linear_index),
    .data_out (bit_reversed_index)
);

assign permuted_data[bit_reversed_index] = input_data[linear_index];
```

### 字节序转换

```verilog
// 大端/小端 32-bit 字节序转换
bit_reverse #(.DATA_WIDTH(32)) u_endian (
    .data_in  (big_endian_word),
    .data_out (little_endian_word)
);
// 注意：这只是 bit 反转，字节序转换需要 byte 反转
// 字节反转：assign le = {be[7:0], be[15:8], be[23:16], be[31:24]};
```

---

## 关键实现细节

- **纯连线**：`genvar i; for (i=0; i<DATA_WIDTH; i=i+1) assign data_out[i] = data_in[DATA_WIDTH-1-i];`
- **零延迟**：无逻辑门，仅连线翻转
- **零面积**：综合工具优化掉，不占用任何门
- **对称性**：反转两次恢复原值：`bit_reverse(bit_reverse(x)) == x`
- **自反数据**：某些数据（如 0xA5 = 10100101）反转后不变
- **与 barrel_shifter 区别**：barrel_shifter 按位移位，bit_reverse 完全翻转所有 bit 顺序
