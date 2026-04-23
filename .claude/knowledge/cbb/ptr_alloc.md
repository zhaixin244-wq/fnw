# ptr_alloc — 指针分配回收器

> **用途**：基于 bitmap 的指针/槽位动态分配与回收，支持单周期分配和回收
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

指针分配回收器维护一个 bitmap 位图，每个 bit 对应一个资源槽位（1=已占用，0=空闲）。分配时找到第一个 0 的 bit 返回其索引并置 1，回收时将对应 bit 清零。相比链表方案，bitmap 方案分配延迟固定为 1 周期（组合查找+寄存器更新），适合中小规模资源池（8-256 项）。用于 buffer 描述符分配、缓存路分配、虚拟页分配等场景。

```
alloc ──> ┌──────────────┐ ──> alloc_idx（分配到的指针）
          │  ptr_alloc   │ ──> alloc_valid
free  ──> │  (DEPTH=N)   │ ──> free_done
          └──────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DEPTH` | parameter | 64 | 资源槽位数 |
| `ADDR_WIDTH` | localparam | `$clog2(DEPTH)` | 指针索引位宽 |
| `SEARCH_DIR` | parameter | `"LOW"` | 搜索方向：`"LOW"` = 低位优先，`"HIGH"` = 高位优先 |
| `INIT_FILE` | parameter | `""` | 初始 bitmap 文件（空=全空闲） |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `alloc` | I | 1 | clk | 分配请求 |
| `alloc_idx` | O | `ADDR_WIDTH` | clk | 分配到的索引 |
| `alloc_valid` | O | 1 | clk | 分配成功 |
| `alloc_fail` | O | 1 | clk | 分配失败（全部占用） |
| `free` | I | 1 | clk | 回收请求 |
| `free_idx` | I | `ADDR_WIDTH` | clk | 回收的索引 |
| `free_done` | O | 1 | clk | 回收完成 |
| `free_err` | O | 1 | clk | 回收错误（该位本就空闲） |
| `occupied` | O | `DEPTH` | clk | 当前占用 bitmap（调试） |
| `free_count` | O | `ADDR_WIDTH + 1` | clk | 空闲槽位数 |

---

## 时序

### 顺序分配

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
alloc       _____|‾|___|‾|___|‾|_________
alloc_idx   _________| 0 | 1 | 2 |_______  (顺序分配 0, 1, 2)
alloc_valid _________| ‾ | ‾ | ‾ |_______
bitmap      ___|0000__|0001|0011|0111|____
free_count  _________|63 |62 |61 |_______
```

### 分配 + 回收

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
alloc       _____|‾|___|‾|___|___|‾|_________
alloc_idx   _________| 0 | 1 |_______| 0|____  (回收后重新分配 0)
free        _________________|‾|_______________
free_idx    _________________| 0|______________
free_done   _________________________| ‾|______
bitmap      ___|0000|0001|0011|___|0010|______|0010→0010
```

### 分配失败

```
clk         __|‾|__|‾|__|‾|__
alloc       _____|‾|___|‾|___
alloc_valid _________|_______|  (失败)
alloc_fail  _________| ‾ |___|  (全部占用)
```

---

## 用法

### 网络 Buffer 指针池

```verilog
ptr_alloc #(
    .DEPTH       (256),
    .SEARCH_DIR  ("LOW")
) u_buf_ptr (
    .clk         (clk),
    .rst_n       (rst_n),
    // 分配
    .alloc       (rx_alloc && !alloc_fail),
    .alloc_idx   (rx_buf_ptr),
    .alloc_valid (buf_alloc_ok),
    .alloc_fail  (buf_pool_empty),
    // 回收
    .free        (tx_done),
    .free_idx    (tx_buf_ptr),
    .free_done   (),
    .free_err    (double_free_err),
    .occupied    (),
    .free_count  (buf_free_cnt)
);
```

### 虚拟页分配

```verilog
// OS 虚拟内存页分配
ptr_alloc #(
    .DEPTH       (1024),          // 1024 个 4KB 页
    .SEARCH_DIR  ("LOW"),
    .INIT_FILE   ("mem_init.hex") // 初始部分页已占用
) u_vpage (
    .clk         (clk),
    .rst_n       (rst_n),
    .alloc       (page_fault_alloc),
    .alloc_idx   (vpage_num),
    .alloc_valid (page_avail),
    .alloc_fail  (oom),
    .free        (page_release),
    .free_idx    (free_vpage),
    .free_done   (),
    .free_err    (),
    .occupied    (),
    .free_count  (free_pages)
);
```

### 缓存路分配

```verilog
// 4 路组相联缓存，空闲路分配
ptr_alloc #(
    .DEPTH       (4),
    .SEARCH_DIR  ("LOW")
) u_cache_way (
    .clk         (clk),
    .rst_n       (rst_n),
    .alloc       (miss_alloc),
    .alloc_idx   (victim_way),
    .alloc_valid (way_available),
    .alloc_fail  (cache_full),
    .free        (eviction_done),
    .free_idx    (evicted_way),
    .free_done   (),
    .free_err    (),
    .occupied    (),
    .free_count  (free_ways)
);
```

---

## 关键实现细节

- **Bitmap 存储**：DEPTH 个触发器存储占用状态
- **分配搜索**：使用 findfirstone（LOW）或 findlastone（HIGH）组合逻辑扫描 bitmap
- **单周期分配**：组合逻辑搜索 + 寄存器更新，1 周期完成
- **回收**：bitmap[free_idx] <= 1'b0，无搜索开销
- **alloc+free 同周期**：先回收再分配（同周期 free_idx 的 bit 清零后参与搜索）
- **free_err**：free_idx 对应 bit 本就 0 时拉高（重复回收检测）
- **面积**：DEPTH 个触发器 + findfirstone 逻辑，约 O(N × logN) 门
- **相比链表**：bitmap 搜索延迟随 DEPTH 对数增长，链表分配为 O(1) 但需指针存储
- **推荐**：DEPTH ≤ 256 用 bitmap，DEPTH > 256 用链表
