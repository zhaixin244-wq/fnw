# linked_list_queue — 链表队列管理器

> **用途**：基于链表实现的 FIFO 队列，支持随机插入/删除和优先级排序
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

链表队列管理器使用双向链表实现有序队列。与固定深度 FIFO 不同，链表队列支持按优先级插入（保持排序）、任意位置删除、遍历等高级操作。每个节点包含 data 和 next/prev 指针。用于网络 QoS 优先级队列、乱序重组缓冲、任务调度队列等场景。

```
入队请求 ──> ┌──────────────────────┐ ──> 出队数据
             │ linked_list_queue     │
             │ (DEPTH=N, 按优先级排序) │
             └──────────────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DEPTH` | parameter | 64 | 最大队列深度 |
| `DATA_WIDTH` | parameter | 32 | 队列数据位宽 |
| `PRIO_WIDTH` | parameter | 4 | 优先级位宽（0=最高优先级） |
| `ORDER_MODE` | parameter | `"PRIORITY"` | 排序模式：`"PRIORITY"` = 按优先级，`"FIFO"` = 按到达顺序 |
| `ADDR_WIDTH` | localparam | `$clog2(DEPTH)` | 节点地址位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `enqueue` | I | 1 | clk | 入队请求 |
| `enq_data` | I | `DATA_WIDTH` | clk | 入队数据 |
| `enq_prio` | I | `PRIO_WIDTH` | clk | 入队优先级 |
| `enq_done` | O | 1 | clk | 入队完成 |
| `enq_full` | O | 1 | clk | 队列满 |
| `dequeue` | I | 1 | clk | 出队请求 |
| `deq_data` | O | `DATA_WIDTH` | clk | 出队数据 |
| `deq_valid` | O | 1 | clk | 出队有效 |
| `deq_empty` | O | 1 | clk | 队列空 |
| `remove` | I | 1 | clk | 删除指定节点 |
| `remove_node` | I | `ADDR_WIDTH` | clk | 删除的节点索引 |
| `remove_done` | O | 1 | clk | 删除完成 |
| `count` | O | `ADDR_WIDTH + 1` | clk | 当前队列长度 |
| `head_node` | O | `ADDR_WIDTH` | clk | 队列头节点索引（调试） |

---

## 时序

### 优先级排序入队

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
enqueue     _____|‾|___|‾|___|‾|_______
enq_data    _____| A |___| B |___| C |__
enq_prio    _____| 3 |___| 1 |___| 2 |__
deq_data    _______________________| B |__  (出队顺序: B(p1)→C(p2)→A(p3))
count       _________| 1 | 2 | 3 |_______
              ↑ 优先级排序插入，出队按优先级
```

### FIFO 模式

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
enqueue     _____|‾|___|‾|___|_________
enq_data    _____| A |___| B |__________
dequeue     ___________________|‾|______
deq_data    ___________________| A |____  (先进先出)
```

### 删除中间节点

```
clk         __|‾|__|‾|__|‾|__|‾|__
enqueue     _____|‾|___|‾|___|‾|___
enq_data    _____| A |___| B |___| C
remove      _________________|‾|___
remove_node _________________| B |
remove_done _____________________|‾|_
deq_data    _________________| A |___  (出队跳过已删除的 B)
```

---

## 用法

### 网络 QoS 优先级队列

```verilog
linked_list_queue #(
    .DEPTH      (128),
    .DATA_WIDTH (128),          // 网络包描述符
    .PRIO_WIDTH (3),            // 8 个优先级
    .ORDER_MODE ("PRIORITY")
) u_qos_queue (
    .clk         (clk),
    .rst_n       (rst_n),
    // 入队
    .enqueue     (rx_enqueue),
    .enq_data    (rx_pkt_desc),
    .enq_prio    (rx_pkt_prio),
    .enq_done    (),
    .enq_full    (queue_full),
    // 出队
    .dequeue     (tx_dequeue),
    .deq_data    (tx_pkt_desc),
    .deq_valid   (tx_pkt_valid),
    .deq_empty   (queue_empty),
    // 删除（丢弃低优先级包）
    .remove      (drop_en),
    .remove_node (drop_node),
    .remove_done (),
    .count       (queue_depth),
    .head_node   ()
);
```

### 乱序重组缓冲

```verilog
// TCP 乱序段重组：按序号插入，删除已确认段
linked_list_queue #(
    .DEPTH      (64),
    .DATA_WIDTH (64),           // 段描述符
    .PRIO_WIDTH (16),           // 序号作为优先级
    .ORDER_MODE ("PRIORITY")
) u_reorder_buf (
    .clk         (clk),
    .rst_n       (rst_n),
    .enqueue     (rx_segment),
    .enq_data    (seg_desc),
    .enq_prio    (seg_seq_num),     // 序号越小越先出
    .enq_done    (),
    .enq_full    (reorder_full),
    .dequeue     (deliver_seg),
    .deq_data    (in_order_desc),
    .deq_valid   (has_in_order),
    .deq_empty   (reorder_empty),
    .remove      (1'b0),
    .remove_node ({ADDR_WIDTH{1'b0}}),
    .remove_done (),
    .count       (),
    .head_node   ()
);
```

### 任务调度队列

```verilog
linked_list_queue #(
    .DEPTH      (32),
    .DATA_WIDTH (16),           // 任务 ID + 参数
    .PRIO_WIDTH (4),
    .ORDER_MODE ("PRIORITY")
) u_task_queue (
    .clk         (clk),
    .rst_n       (rst_n),
    .enqueue     (task_submit),
    .enq_data    (task_info),
    .enq_prio    (task_priority),
    .enq_done    (task_queued),
    .enq_full    (task_queue_full),
    .dequeue     (task_schedule),
    .deq_data    (next_task),
    .deq_valid   (task_ready),
    .deq_empty   (no_tasks),
    .remove      (task_cancel),
    .remove_node (cancel_task_node),
    .remove_done (task_cancelled),
    .count       (task_count),
    .head_node   ()
);
```

---

## 关键实现细节

- **双向链表**：每个节点包含 `{data, priority, next_ptr, prev_ptr, valid}`
- **空闲池**：内部使用 `linked_list_free` 管理空闲节点
- **优先级插入**：遍历链表找到第一个 priority > enq_prio 的节点，插入其前
- **FIFO 模式**：ORDER_MODE="FIFO" 时，插入链表尾部（不做排序）
- **删除**：断开节点的前后连接，将节点归还空闲池
- **出队**：输出链表头节点数据，移动 head_ptr 到 next
- **面积**：DEPTH × (DATA_WIDTH + PRIO_WIDTH + 2×ADDR_WIDTH + 1) 触发器
- **延迟**：优先级插入需要链表遍历，最坏 O(DEPTH) 周期
- **优化**：可限制遍历深度或使用分段链表降低最坏延迟
