# bin2onehot — 二进制转独热码

> **用途**：将二进制编码转换为独热码（One-Hot），用于 grant/选择信号生成
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

二进制转独热码转换器将 N 位二进制数转换为 2^N 位独热码。常与仲裁器、编码器配合使用：仲裁器输出 grant_idx（二进制），经本模块转换为独热 grant 信号。

```
bin[1:0] ──> ┌────────────┐ ──onehot[3:0]──> 独热码
             │ bin2onehot  │
             └────────────┘
  2'b01 → 4'b0010
  2'b10 → 4'b0100
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `BIN_WIDTH` | parameter | 4 | 二进制输入位宽 |
| `ONEHOT_WIDTH` | localparam | `1 << BIN_WIDTH` | 独热码输出位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `bin_in` | I | `BIN_WIDTH` | - | 二进制编码输入 |
| `onehot_out` | O | `ONEHOT_WIDTH` | - | 独热码输出 |
| `valid_in` | I | 1 | - | 输入有效（可选） |
| `valid_out` | O | 1 | - | 输出有效（可选） |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

---

## 转换表（BIN_WIDTH=3）

| 十进制 | 二进制 | 独热码 |
|--------|--------|--------|
| 0 | 000 | 00000001 |
| 1 | 001 | 00000010 |
| 2 | 010 | 00000100 |
| 3 | 011 | 00001000 |
| 4 | 100 | 00010000 |
| 5 | 101 | 00100000 |
| 6 | 110 | 01000000 |
| 7 | 111 | 10000000 |

---

## 用法

### 仲裁器 grant 生成

```verilog
// 仲裁器输出 grant_idx（二进制），转为独热 grant
bin2onehot #(.BIN_WIDTH(3)) u_grant_dec (
    .bin_in    (grant_idx),
    .onehot_out(grant)
);

// 连接到各通道
assign ch0_grant = grant[0];
assign ch1_grant = grant[1];
assign ch2_grant = grant[2];
```

### 多路选择器地址

```verilog
// 4 选 1 MUX 的选择信号
bin2onehot #(.BIN_WIDTH(2)) u_mux_sel (
    .bin_in    (sel_idx),
    .onehot_out(sel_onehot)
);

assign out = (sel_onehot[0] & data_0) |
             (sel_onehot[1] & data_1) |
             (sel_onehot[2] & data_2) |
             (sel_onehot[3] & data_3);
```

### 与 valid 配合

```verilog
bin2onehot #(.BIN_WIDTH(3)) u_with_valid (
    .bin_in    (idx),
    .onehot_out(onehot),
    .valid_in  (idx_valid),
    .valid_out (onehot_valid)
);
```

---

## 关键实现细节

- **核心逻辑**：`assign onehot_out = (1 << bin_in)` — 移位操作
- **纯组合逻辑**：无寄存器，零延迟（仅组合逻辑延迟）
- **无效输入**：bin_in 超出范围时 onehot_out 对应位仍会置位
- **valid 传递**：valid_in 直连 valid_out（可选端口）
- **面积**：ONEHOT_WIDTH 个连线，综合后为移位网络，极小开销
- **与 onehot2bin 互逆**：onehot2bin 是优先编码器，bin2onehot 是解码器
