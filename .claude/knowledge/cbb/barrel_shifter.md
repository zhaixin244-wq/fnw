# barrel_shifter — 桶形移位器

> **用途**：单周期可变位数移位/旋转操作，用于 ALU、数据对齐、浮点运算
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

桶形移位器（Barrel Shifter）在单周期内完成任意位数的移位操作，无需多周期循环移位。使用多级 MUX 级联实现，每级处理一个 bit 位的移位。支持逻辑左移、逻辑右移、算术右移、循环移位（Rotate）。用于 ALU 移位指令、数据对齐、浮点尾数移位等场景。

```
data_in[N-1:0] ──> ┌────────────────┐ ──data_out[N-1:0]──> 移位结果
shift_amt[M-1:0] ─> │ barrel_shifter  │
shift_type[1:0] ──> └────────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽 |
| `SHIFT_WIDTH` | localparam | `$clog2(DATA_WIDTH)` | 移位量位宽 |
| `ROTATE_EN` | parameter | 1 | 循环移位使能 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `data_in` | I | `DATA_WIDTH` | - | 输入数据 |
| `shift_amt` | I | `SHIFT_WIDTH` | - | 移位量 |
| `shift_type` | I | 2 | - | 移位类型：00=SLL, 01=SRL, 10=SRA, 11=ROR |
| `data_out` | O | `DATA_WIDTH` | - | 移位结果 |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

---

## 移位类型说明

| shift_type | 名称 | 说明 |
|-----------|------|------|
| 2'b00 | SLL | 逻辑左移（Shift Left Logical）：低位补 0 |
| 2'b01 | SRL | 逻辑右移（Shift Right Logical）：高位补 0 |
| 2'b10 | SRA | 算术右移（Shift Right Arithmetic）：高位补符号位 |
| 2'b11 | ROR | 循环右移（Rotate Right）：移出的低位循环到高位 |

---

## 转换示例（DATA_WIDTH=8）

### SLL（左移）

| data_in | shift_amt | data_out |
|---------|-----------|----------|
| 00001111 | 0 | 00001111 |
| 00001111 | 1 | 00011110 |
| 00001111 | 3 | 01111000 |
| 00001111 | 7 | 10000000 |

### SRA（算术右移，符号扩展）

| data_in | shift_amt | data_out |
|---------|-----------|----------|
| 10000000 | 1 | 11000000 |
| 10000000 | 3 | 11110000 |
| 01000000 | 1 | 00100000 |

### ROR（循环移位）

| data_in | shift_amt | data_out |
|---------|-----------|----------|
| 10000001 | 1 | 11000000 |
| 10000001 | 4 | 00011000 |

---

## 用法

### ALU 移位指令

```verilog
barrel_shifter #(
    .DATA_WIDTH (32),
    .ROTATE_EN  (1)
) u_alu_shift (
    .data_in    (rs1_value),
    .shift_amt  (rs2_value[4:0]),
    .shift_type (alu_shift_type),    // 00=SLL, 01=SRL, 10=SRA
    .data_out   (shift_result)
);

// alu_shift_type 来自指令译码
// SLL: shift_type = 2'b00
// SRL: shift_type = 2'b01
// SRA: shift_type = 2'b10
```

### 浮点尾数对齐

```verilog
// 浮点加法前，较小指数的尾数需要右移对齐
barrel_shifter #(
    .DATA_WIDTH (53),          // 双精度尾数 52+1 隐含位
    .ROTATE_EN  (0)
) u_fp_align (
    .data_in    (smaller_mantissa),
    .shift_amt  (exp_diff[5:0]),
    .shift_type (2'b01),       // 逻辑右移
    .data_out   (aligned_mantissa)
);
```

### AXI 数据对齐

```verilog
// 非对齐地址数据重排
barrel_shifter #(
    .DATA_WIDTH (64),
    .ROTATE_EN  (1)
) u_align_shift (
    .data_in    (aligned_data),
    .shift_amt  ({addr_offset[2:0], 3'b0}),  // 字节偏移 × 8 = bit 偏移
    .shift_type (2'b01),                       // 逻辑右移
    .data_out   (shifted_data)
);
```

### CRC 计算（位反射）

```verilog
// CRC 输入数据位反射（LSB first → MSB first）
barrel_shifter #(
    .DATA_WIDTH (8),
    .ROTATE_EN  (1)
) u_bit_reverse (
    .data_in    (byte_in),
    .shift_amt  (3'd0),          // 旋转量=0 时
    .shift_type (2'b11),         // 循环移位
    .data_out   (byte_reversed)
);
// 注意：位反转更高效的实现是直接 wire 翻转
```

---

## 关键实现细节

- **log2(N) 级 MUX**：每级处理 2^i 位移位，i = 0, 1, ..., log2(N)-1
- **第 i 级**：shift_amt[i]=1 时数据移 2^i 位，=0 时直通
- **SLL**：每级左移，低位补 0
- **SRL**：每级右移，高位补 0
- **SRA**：每级右移，高位补 data_in[MSB]（符号位）
- **ROR**：每级右移，高位补移出的低位
- **单周期完成**：无流水线，组合逻辑延迟 = log2(N) × MUX 延迟
- **面积**：log2(N) × N × 3:1 MUX（含旋转）≈ 3 × N × log2(N) 个门
- **关键路径**：大位宽（64+）时可插入流水线或分段处理
