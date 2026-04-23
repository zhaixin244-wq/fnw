# findfirstone — 优先编码器（找最低有效 1）

> **用途**：在位向量中找到最低位的 1 的位置，输出索引和有效标志
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

Find-First-One（FFO）电路扫描输入位向量，找到最低位（最低有效位）为 1 的位置，输出其二进制索引。本质是低位优先编码器。常与仲裁器、中断控制器、空闲 slot 检测等配合使用。

```
vec[7:0] ──> ┌──────────────┐ ──index[2:0]──> 最低位 1 的索引
             │ findfirstone  │ ──valid──> 存在有效位
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
| `index` | O | `INDEX_WIDTH` | - | 最低位 1 的索引 |
| `valid` | O | 1 | - | 存在有效位（vec != 0） |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

---

## 转换表（DATA_WIDTH=8）

| vec[7:0] | index[2:0] | valid |
|----------|-----------|-------|
| 00000000 | 000 | 0 |
| 00000001 | 000 | 1 |
| 00000010 | 001 | 1 |
| 00000100 | 010 | 1 |
| 00001100 | 010 | 1 |
| 10000000 | 111 | 1 |
| 11111111 | 000 | 1 |

---

## 用法

### 空闲 slot 检测

```verilog
// 找到第一个空闲的 buffer slot
findfirstone #(.DATA_WIDTH(16)) u_find_free (
    .vec    (slot_occupied),       // 1=占用，0=空闲
    .index  (free_slot_idx),
    .valid  (has_free_slot)
);

assign free_slot_idx_inv = free_slot_idx;  // 直接用
// 或取反逻辑：找 0 的位置
// findfirstone #(.DATA_WIDTH(16)) u_find_free_inv (
//     .vec    (~slot_occupied),   // 找第一个 0
//     .index  (free_slot_idx),
//     .valid  (has_free_slot)
// );
```

### 仲裁器低位优先

```verilog
// 最低优先级仲裁：找到 req 中最低位的 1
findfirstone #(.DATA_WIDTH(8)) u_rr_arb (
    .vec    (req_vector),
    .index  (grant_idx),
    .valid  (grant_valid)
);

assign grant = (1 << grant_idx);  // 转为独热码
```

### 中断优先级（编号越小优先级越高）

```verilog
findfirstone #(.DATA_WIDTH(32)) u_irq_prio (
    .vec    (irq_pending & irq_enable),
    .index  (active_irq_id),
    .valid  (irq_valid)
);
```

### 跳转表地址查找

```verilog
// 在 64 项跳转表中找第一个有效项
findfirstone #(.DATA_WIDTH(64)) u_jmp_find (
    .vec    (jmp_table_valid),
    .index  (first_jmp_idx),
    .valid  (has_jmp_entry)
);
```

---

## 关键实现细节

- **核心算法**：`vec & (~vec + 1)` 提取最低有效 1，再编码
- **纯组合逻辑**：无时钟延迟，延迟取决于 DATA_WIDTH
- **级联结构**：大位宽可分段处理降低关键路径
- **valid**：`|vec` — 至少 1 bit 为 1
- **全 0 处理**：vec=0 时 valid=0，index 输出无意义
- **面积**：INDEX_WIDTH × DATA_WIDTH 级优先逻辑，约 O(N × logN) 门
- **与 onehot2bin 区别**：onehot2bin 要求恰好 1 bit 有效，findfirstone 接受任意数量的 1
