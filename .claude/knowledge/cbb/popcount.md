# popcount — 位计数器（人口计数）

> **用途**：统计位向量中 1 的个数
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

Population Count（popcount）电路统计输入位向量中值为 1 的 bit 数量。使用树形加法结构，每一级将相邻的 2 bit 相加，逐级归约直到输出最终计数。用于资源占用统计、汉明距离计算、条件掩码计数、权重计算等场景。

```
vec[N-1:0] ──> ┌──────────┐ ──count[$clog2(N):0]──> 1 的个数
               │ popcount  │
               └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 输入位向量位宽 |
| `COUNT_WIDTH` | localparam | `$clog2(DATA_WIDTH) + 1` | 输出计数位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `vec` | I | `DATA_WIDTH` | - | 输入位向量 |
| `count` | O | `COUNT_WIDTH` | - | 1 的计数值 |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

---

## 转换表（DATA_WIDTH=8）

| vec[7:0] | count |
|----------|-------|
| 00000000 | 0 |
| 00000001 | 1 |
| 00001111 | 4 |
| 01010101 | 4 |
| 11111111 | 8 |
| 10110010 | 4 |

---

## 用法

### 资源占用统计

```verilog
// 统计 16 个 slot 中被占用的数量
popcount #(.DATA_WIDTH(16)) u_occupancy (
    .vec    (slot_occupied),
    .count  (occupied_count)
);

assign available_count = 16 - occupied_count;
```

### 汉明距离计算

```verilog
// 计算两个向量的汉明距离（不同 bit 数）
popcount #(.DATA_WIDTH(64)) u_hamming (
    .vec    (vector_a ^ vector_b),
    .count  (hamming_distance)
);

// 用于相似度检测、纠错编码验证等
assign similar = (hamming_distance <= THRESHOLD);
```

### 权重投票

```verilog
// N 个投票者，统计赞成票数
popcount #(.DATA_WIDTH(16)) u_vote (
    .vec    (votes),
    .count  (yes_count)
);

assign passed = (yes_count > 8);  // 超过半数
```

### 条件掩码计数

```verilog
// 统计满足条件的通道数
popcount #(.DATA_WIDTH(8)) u_cond_cnt (
    .vec    (ch_valid & ch_ready),
    .count  (active_ch_count)
);

assign all_active = (active_ch_count == 8);
```

### 浮点尾数前导零+尾零计数

```verilog
// 与 findfirstone/findlastone 配合
popcount #(.DATA_WIDTH(64)) u_trailing_zeros (
    .vec    (mantissa & (~mantissa + 1)),  // 提取最低 1
    .count  (trailing_one_pos)              // 实际上不是 popcount
);
// 注意：trailing zeros 更适合用 findfirstone
```

---

## 关键实现细节

- **树形加法**：每一级将相邻 2 bit 用半加器相加，逐级归约
- **级数**：log2(DATA_WIDTH) 级
- **第 1 级**：每 2 bit 相加 → DATA_WIDTH/2 个 2-bit 结果
- **第 k 级**：每 2 个 (k)-bit 数相加 → DATA_WIDTH/2^k 个 (k+1)-bit 结果
- **最终**：所有部分和相加
- **纯组合逻辑**：无寄存器，组合逻辑延迟 = log2(N) × 加法器延迟
- **面积**：DATA_WIDTH/2 个全加器 + DATA_WIDTH/4 个全加器 + ... ≈ DATA_WIDTH × log(N) 门
- **大位宽优化**：DATA_WIDTH=128+ 时可插入寄存器做流水线
