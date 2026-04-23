# onehot2bin — 独热码转二进制

> **用途**：将独热码（One-Hot）编码转换为二进制编码，用于优先编码器
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

独热码转二进制转换器将 2^N 位独热码转换为 N 位二进制数。支持最高优先级（Priority）模式：多个 bit 同时有效时输出最高位对应的索引。常与仲裁器、中断控制器配合，将独热 grant/pending 信号转为二进制索引。

```
onehot[7:0] ──> ┌────────────┐ ──bin[2:0]──> 二进制编码
                │ onehot2bin │
                └────────────┘
  8'b00000100 → 3'b010
  8'b00100100 → 3'b101 (优先级模式)
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `ONEHOT_WIDTH` | parameter | 8 | 独热码输入位宽 |
| `BIN_WIDTH` | localparam | `$clog2(ONEHOT_WIDTH)` | 二进制输出位宽 |
| `PRIORITY` | parameter | `"HIGH"` | 优先级：`"HIGH"` = 高位优先，`"LOW"` = 低位优先 |
| `VALID_CHECK` | parameter | 1 | 是否检查输入有效性（恰好 1 bit 或 0 bit） |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `onehot_in` | I | `ONEHOT_WIDTH` | - | 独热码输入 |
| `bin_out` | O | `BIN_WIDTH` | - | 二进制编码输出 |
| `valid_out` | O | 1 | - | 有效输出（至少 1 bit 输入有效） |
| `error` | O | 1 | - | 输入无效（多 bit 或 0 bit，VALID_CHECK=1） |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

---

## 转换表（ONEHOT_WIDTH=8）

| 输入独热码 | 二进制输出（LOW 优先） | 二进制输出（HIGH 优先） |
|-----------|---------------------|---------------------|
| 00000001 | 000 | 000 |
| 00000010 | 001 | 001 |
| 00000100 | 010 | 010 |
| 00001000 | 011 | 011 |
| 00010000 | 100 | 100 |
| 00100000 | 101 | 101 |
| 01000000 | 110 | 110 |
| 10000000 | 111 | 111 |
| 00100100 | 010（低位优先） | 101（高位优先） |
| 00000000 | 000, error=1 | 000, error=1 |

---

## 用法

### 仲裁器结果编码

```verilog
// 独热 grant 信号转二进制索引，用于数据 MUX
onehot2bin #(
    .ONEHOT_WIDTH (8),
    .PRIORITY     ("LOW"),
    .VALID_CHECK  (1)
) u_grant_enc (
    .onehot_in (grant),
    .bin_out   (grant_idx),
    .valid_out (grant_valid),
    .error     (grant_error)
);

// grant_idx 选择对应通道的数据
always @(*) begin
    case (grant_idx)
        3'd0: mux_data = ch0_data;
        3'd1: mux_data = ch1_data;
        3'd2: mux_data = ch2_data;
        3'd3: mux_data = ch3_data;
        3'd4: mux_data = ch4_data;
        3'd5: mux_data = ch5_data;
        3'd6: mux_data = ch6_data;
        3'd7: mux_data = ch7_data;
        default: mux_data = {DATA_WIDTH{1'b0}};
    endcase
end
```

### 中断优先级编码

```verilog
// 16 个中断 pending 转最高优先级中断号
onehot2bin #(
    .ONEHOT_WIDTH (16),
    .PRIORITY     ("HIGH"),       // 编号越大优先级越高
    .VALID_CHECK  (1)
) u_irq_enc (
    .onehot_in (irq_pending & irq_enable),
    .bin_out   (active_irq_id),
    .valid_out (irq_valid),
    .error     ()
);
```

### 与 bin2onehot 互逆验证

```verilog
bin2onehot   #(.BIN_WIDTH(3)) u_enc (.bin_in(bin), .onehot_out(onehot));
onehot2bin   #(.ONEHOT_WIDTH(8)) u_dec (.onehot_in(onehot), .bin_out(bin_restored));
// bin == bin_restored（正常情况下）
```

---

## 关键实现细节

- **低位优先**：`bin_out` 使用 `for` 循环从 bit 0 开始扫描，找到第一个 1 即停止
- **高位优先**：从 bit ONEHOT_WIDTH-1 开始向下扫描
- **优先级编码**：多个 bit 有效时，按优先级选择一个输出
- **valid_out**：`|onehot_in` — 至少 1 bit 有效
- **error**：`~(|onehot_in) | (onehot_in & (onehot_in - 1))` — 0 bit 或多 bit 时报警
- **纯组合逻辑**：无寄存器，仅逻辑门延迟
- **面积**：BIN_WIDTH 个 OR 树 + 优先级逻辑，约 BIN_WIDTH × ONEHOT_WIDTH/2 个门
- **与 bin2onehot 互逆**：bin2onehot 是解码器，onehot2bin 是编码器
