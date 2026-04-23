# findlastone — 优先编码器（找最高有效 1）

> **用途**：在位向量中找到最高位的 1 的位置，输出索引和有效标志
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

Find-Last-One（FLO）电路扫描输入位向量，找到最高位（最高有效位）为 1 的位置，输出其二进制索引。与 findfirstone 互补，适用于高位优先仲裁、最高优先级中断检测、前导零计数（Leading Zero Count）等场景。

```
vec[7:0] ──> ┌──────────────┐ ──index[2:0]──> 最高位 1 的索引
             │ findlastone   │ ──valid──> 存在有效位
             └──────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 输入位向量位宽 |
| `INDEX_WIDTH` | localparam | `$clog2(DATA_WIDTH)` | 输出索引位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `vec` | I | `DATA_WIDTH` | - | 输入位向量 |
| `index` | O | `INDEX_WIDTH` | - | 最高位 1 的索引 |
| `valid` | O | 1 | - | 存在有效位（vec != 0） |
| `lz_count` | O | `INDEX_WIDTH + 1` | - | 前导零计数（可选） |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

---

## 转换表（DATA_WIDTH=8）

| vec[7:0] | index[2:0] | valid | lz_count |
|----------|-----------|-------|----------|
| 00000000 | 000 | 0 | 8 |
| 00000001 | 000 | 1 | 7 |
| 00000010 | 001 | 1 | 6 |
| 00001100 | 011 | 1 | 4 |
| 01010000 | 110 | 1 | 1 |
| 10000000 | 111 | 1 | 0 |
| 11111111 | 111 | 1 | 0 |

---

## 用法

### 高位优先仲裁

```verilog
// 编号越大优先级越高
findlastone #(.DATA_WIDTH(8)) u_hi_prio_arb (
    .vec    (req_vector),
    .index  (grant_idx),
    .valid  (grant_valid)
);

assign grant = (1 << grant_idx);
```

### 最高中断检测

```verilog
// 32 个中断，编号越大优先级越高
findlastone #(.DATA_WIDTH(32)) u_max_irq (
    .vec    (irq_pending & irq_enable),
    .index  (highest_irq_id),
    .valid  (irq_valid),
    .lz_count()
);
```

### 前导零计数（浮点归一化）

```verilog
// 浮点运算中归一化需要前导零计数
findlastone #(.DATA_WIDTH(64)) u_lzc (
    .vec    (mantissa_raw),
    .index  (),
    .valid  (has_nonzero),
    .lz_count(leading_zeros)
);

// 归一化：左移 leading_zeros 位
assign mantissa_norm = mantissa_raw << leading_zeros;
assign exponent_adj  = original_exp - leading_zeros;
```

### 大小比较器

```verilog
// 找到最大值所在通道
findlastone #(.DATA_WIDTH(4)) u_max_ch (
    .vec    (ch_greater_than_threshold),
    .index  (max_channel),
    .valid  (has_valid_channel)
);
```

---

## 关键实现细节

- **核心算法**：从最高位向下扫描，使用二分查找树降低逻辑级数
- **前导零**：`lz_count = DATA_WIDTH - 1 - index`（valid=1 时），全 0 时 lz_count = DATA_WIDTH
- **纯组合逻辑**：无时钟延迟
- **二分优化**：对于 DATA_WIDTH = 2^n，分 n 级二分查找，每级判断半区是否有 1
- **面积**：与 findfirstone 相当，仅优先级顺序不同
- **与 CLZ 关系**：Leading Zero Count 是 findlastone 的副产品，浮点运算常用
