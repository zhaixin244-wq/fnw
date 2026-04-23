# linked_list_free — 空闲链表管理器

> **用途**：基于链表的空闲资源池管理，用于 buffer/descriptor 动态分配与回收
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

空闲链表管理器维护一个空闲资源链表，支持分配（allocate）和回收（free）操作。使用寄存器阵列实现链表指针，每个节点存储下一个空闲节点的索引。相比位图查找（findfirstone），链表管理在大容量资源池（64-256 项）时面积效率更高，且分配/回收均为 O(1)。用于网络芯片 buffer 管理、DMA 描述符管理、缓存行管理等场景。

```
分配请求 ──> ┌──────────────────┐ ──> 分配的资源索引
             │ linked_list_free │
回收请求 ──> │   (DEPTH=256)    │ ──> 回收完成
             └──────────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DEPTH` | parameter | 256 | 资源池大小（必须为 2 的幂） |
| `ADDR_WIDTH` | localparam | `$clog2(DEPTH)` | 资源索引位宽 |
| `INIT_MODE` | parameter | `"SEQUENTIAL"` | 初始化：`"SEQUENTIAL"` = 顺序初始化，`"FILE"` = 文件加载 |
| `CREDIT_EN` | parameter | 1 | 信用计数使能 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `alloc` | I | 1 | clk | 分配请求（单周期脉冲） |
| `alloc_idx` | O | `ADDR_WIDTH` | clk | 分配到的资源索引 |
| `alloc_valid` | O | 1 | clk | 分配成功（链表非空） |
| `free` | I | 1 | clk | 回收请求（单周期脉冲） |
| `free_idx` | I | `ADDR_WIDTH` | clk | 回收的资源索引 |
| `free_done` | O | 1 | clk | 回收完成 |
| `free_list_empty` | O | 1 | clk | 空闲链表为空 |
| `free_list_full` | O | 1 | clk | 空闲链表满（所有资源空闲） |
| `free_count` | O | `ADDR_WIDTH + 1` | clk | 当前空闲资源数（CREDIT_EN） |

---

## 时序

### 顺序分配

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
alloc       _____|‾|___|‾|___|‾|_______
alloc_idx   _______| 0 | 1 | 2 |_______
alloc_valid _______|‾|___|‾|___|‾|_____
free_list   [0→1→2→3→...→255→NULL]  →  [1→2→3→...→255→NULL]  →  [2→3→...]
             ↑ 分配 idx=0    ↑ 分配 idx=1
```

### 分配 + 回收混合

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
alloc       _____|‾|___|‾|___|___|‾|_________
alloc_idx   _______| 0 | 1 |_______| 3|______
free        _______________|‾|_______________
free_idx    _______________| 1|______________
free_done   _______________________|‾|_______
             ↑ 0,1分配 → 回收1 → 分配到3(链表头已变)
free_count  _________|255|254|253|254|253|__  (CREDIT_EN)
```

### 链表为空

```
clk         __|‾|__|‾|__|‾|__
alloc       _____|‾|___|‾|___
alloc_valid _______|_____|___|  (空链表，分配失败)
alloc_idx   _______| ? | ? |  (无效)
free_list_empty ___|___|‾‾‾‾‾|
```

---

## 用法

### 网络 Buffer 管理

```verilog
linked_list_free #(
    .DEPTH       (256),
    .INIT_MODE   ("SEQUENTIAL"),
    .CREDIT_EN   (1)
) u_pkt_buf (
    .clk             (clk),
    .rst_n           (rst_n),
    // 分配 buffer
    .alloc           (rx_alloc_req && !free_list_empty),
    .alloc_idx       (rx_buf_ptr),
    .alloc_valid     (buf_alloc_ok),
    // 回收 buffer
    .free            (tx_done),
    .free_idx        (tx_buf_ptr),
    .free_done       (),
    // 状态
    .free_list_empty (buf_empty),
    .free_list_full  (),
    .free_count      (buf_free_cnt)
);

// buffer 地址映射
assign buf_base_addr = rx_buf_ptr * BUF_SIZE;
```

### DMA 描述符链表

```verilog
linked_list_free #(
    .DEPTH       (64),
    .INIT_MODE   ("SEQUENTIAL"),
    .CREDIT_EN   (0)
) u_dma_desc (
    .clk             (clk),
    .rst_n           (rst_n),
    .alloc           (dma_start),
    .alloc_idx       (dma_desc_idx),
    .alloc_valid     (desc_available),
    .free            (dma_complete),
    .free_idx        (dma_done_desc_idx),
    .free_done       (),
    .free_list_empty (no_free_desc),
    .free_list_full  (),
    .free_count      ()
);
```

### 缓存行管理

```verilog
linked_list_free #(
    .DEPTH       (128),         // 128 个 cache line
    .CREDIT_EN   (1)
) u_cache_line (
    .clk             (clk),
    .rst_n           (rst_n),
    // 读 miss 时分配新行
    .alloc           (cache_miss_alloc),
    .alloc_idx       (victim_line_idx),
    .alloc_valid     (line_available),
    // 替换时回收被替换的行（已写回后）
    .free            (eviction_done),
    .free_idx        (evicted_line_idx),
    .free_done       (),
    .free_list_empty (cache_full),
    .free_list_full  (),
    .free_count      (free_line_cnt)
);
```

---

## 关键实现细节

- **链表结构**：寄存器阵列 `next_ptr[0:DEPTH-1]`，每项存下一个空闲节点索引
- **头指针**：`head_ptr` 指向当前链表头（下一个可分配节点）
- **分配**：输出 `head_ptr`，更新 `head_ptr <= next_ptr[head_ptr]`，O(1)
- **回收**：`next_ptr[free_idx] <= head_ptr`，`head_ptr <= free_idx`，插入链表头，O(1)
- **初始化**：SEQUENTIAL 模式初始化链表为 0→1→2→...→DEPTH-1→NULL
- **空判断**：`head_ptr == NULL_PTR`（NULL_PTR = DEPTH 的非法值）
- **满判断**：`free_count == DEPTH`
- **同时分配+回收**：支持同周期 alloc+free，回收的资源在下一周期可用
- **面积**：DEPTH × ADDR_WIDTH 个触发器（next_ptr）+ head_ptr + 可选 free_count
