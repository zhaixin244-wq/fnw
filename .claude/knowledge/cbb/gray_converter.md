# gray_converter — Gray 码转换器

> **用途**：二进制码与 Gray 码之间的相互转换，用于异步 FIFO 指针跨域同步
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

Gray 码的特点是相邻两个数值之间仅有 1 bit 变化，因此在跨时钟域同步时不会出现多 bit 同时跳变导致的中间态问题。异步 FIFO 的读写指针必须转换为 Gray 码后才能安全地跨域同步。

```
二进制 ──> ┌────────────────┐ ──> Gray 码
           │ gray_converter  │
Gray 码 ──> └────────────────┘ ──> 二进制
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 4 | 数据位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `bin_in` | I | `DATA_WIDTH` | - | 二进制输入 |
| `gray_out` | O | `DATA_WIDTH` | - | Gray 码输出（组合逻辑） |
| `gray_in` | I | `DATA_WIDTH` | - | Gray 码输入 |
| `bin_out` | O | `DATA_WIDTH` | - | 二进制输出（组合逻辑） |

> **注意**：本模块为纯组合逻辑，无时钟/复位。实际使用时通常嵌入到指针寄存器路径中。

---

## 转换规则

### 二进制 → Gray 码

```
gray[i] = bin[i] ^ bin[i+1]    (最高位 gray[MSB] = bin[MSB])
```

### Gray 码 → 二进制

```
bin[MSB] = gray[MSB]
bin[i]   = gray[i] ^ bin[i+1]  (从高位到低位逐位还原)
```

### 4-bit 转换示例

| 十进制 | 二进制 | Gray 码 |
|--------|--------|---------|
| 0 | 0000 | 0000 |
| 1 | 0001 | 0001 |
| 2 | 0010 | 0011 |
| 3 | 0011 | 0010 |
| 4 | 0100 | 0110 |
| 5 | 0101 | 0111 |
| 6 | 0110 | 0101 |
| 7 | 0111 | 0100 |
| 8 | 1000 | 1100 |
| 9 | 1001 | 1101 |
| 10 | 1010 | 1111 |
| 11 | 1011 | 1110 |
| 12 | 1100 | 1010 |
| 13 | 1101 | 1011 |
| 14 | 1110 | 1001 |
| 15 | 1111 | 1000 |

---

## 用法

### 在异步 FIFO 中使用

```verilog
// 写指针：二进制 → Gray 码 → 跨域同步
wire [PTR_WIDTH-1:0] wr_ptr_bin;
wire [PTR_WIDTH-1:0] wr_ptr_gray;

gray_converter #(.DATA_WIDTH(PTR_WIDTH)) u_wr_bin2gray (
    .bin_in   (wr_ptr_bin),
    .gray_out (wr_ptr_gray)
);

// 写指针 Gray 码通过 2FF 同步器到读域
sync_2ff #(.WIDTH(PTR_WIDTH)) u_sync_wr_ptr (
    .clk_dst   (clk_rd),
    .rst_dst_n (rst_rd_n),
    .data_src  (wr_ptr_gray),
    .data_dst  (wr_ptr_gray_synced)
);

// 读域：同步后的 Gray 码 → 二进制（用于满/空判断）
gray_converter #(.DATA_WIDTH(PTR_WIDTH)) u_wr_gray2bin (
    .gray_in  (wr_ptr_gray_synced),
    .bin_out  (wr_ptr_bin_synced)
);
```

### 独立使用

```verilog
// 二进制转 Gray
gray_converter #(.DATA_WIDTH(8)) u_bin2gray (
    .bin_in   (binary_value),
    .gray_out (gray_value)
);

// Gray 转二进制
gray_converter #(.DATA_WIDTH(8)) u_gray2bin (
    .gray_in  (gray_value),
    .bin_out  (binary_restored)
);
```

---

## 关键实现细节

- **纯组合逻辑**：无寄存器，无流水线延迟
- **bin_to_gray**：`assign gray_out = bin_in ^ (bin_in >> 1)`
- **gray_to_bin**：逐位异或还原，最高位直通
- **面积**：bin→gray 为 N-1 个 XOR 门，gray→bin 为 N-1 个 XOR 门
- **关键用途**：异步 FIFO 指针的跨时钟域同步，确保同步过程中不会采到非法中间值
- **错误检测**：非法 Gray 码（相邻值超过 1 bit 变化）无法被本模块检测，需在上层保证输入合法
