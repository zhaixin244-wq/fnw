# linked_list_circular — 循环链表管理器

> **用途**：循环链表实现轮转访问、时间片轮转、环形缓冲管理
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

循环链表管理器维护一个首尾相连的环形链表，支持插入、删除和轮转遍历操作。尾节点的 next 指向头节点，形成闭环。用于时间片轮转调度、环形 DMA 描述符链、令牌环访问、Round Robin 遍历等场景。

```
         ┌──> Node0 ──> Node1 ──> Node2 ──┐
         │                                 │
         └─────────────────────────────────┘
    ┌──────────────────────┐
    │ linked_list_circular  │ ──current──> 当前轮转节点
    │     (DEPTH=N)         │
    └──────────────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DEPTH` | parameter | 16 | 最大节点数 |
| `DATA_WIDTH` | parameter | 32 | 节点数据位宽 |
| `ADDR_WIDTH` | localparam | `$clog2(DEPTH)` | 节点地址位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `insert` | I | 1 | clk | 插入请求 |
| `insert_data` | I | `DATA_WIDTH` | clk | 插入数据 |
| `insert_node` | O | `ADDR_WIDTH` | clk | 分配的节点索引 |
| `insert_done` | O | 1 | clk | 插入完成 |
| `remove` | I | 1 | clk | 删除当前节点请求 |
| `remove_done` | O | 1 | clk | 删除完成 |
| `advance` | I | 1 | clk | 轮转前进（当前指针后移） |
| `current_node` | O | `ADDR_WIDTH` | clk | 当前节点索引 |
| `current_data` | O | `DATA_WIDTH` | clk | 当前节点数据 |
| `ring_empty` | O | 1 | clk | 环为空 |
| `ring_count` | O | `ADDR_WIDTH + 1` | clk | 环中节点数 |

---

## 时序

### 轮转遍历

```
clk          __|‾|__|‾|__|‾|__|‾|__|‾|__
insert       _____|‾|___|‾|___|‾|________  (插入 A, B, C)
advance      _________________|‾|___|‾|___
current_node _________| A | B | C | A | B |  (循环回到 A)
current_data _________|DA |DB |DC |DA |DB |_
ring_count   _________| 1 | 2 | 3 |________
```

### 插入与删除

```
clk          __|‾|__|‾|__|‾|__|‾|__
insert       _____|‾|___|‾|________  (插入 A, B)
advance      _______________|‾|___
remove       ___________________|‾|_  (删除当前节点 B)
current_node _________| A | B | A |_  (删除后回到 A)
ring_count   _________| 1 | 2 | 1 |_
```

---

## 用法

### 时间片轮转调度

```verilog
linked_list_circular #(
    .DEPTH      (8),
    .DATA_WIDTH (16)            // 任务 ID + 参数
) u_rr_sched (
    .clk          (clk),
    .rst_n        (rst_n),
    // 任务管理
    .insert       (task_arrive),
    .insert_data  (task_info),
    .insert_node  (task_node),
    .insert_done  (),
    .remove       (task_finish),
    .remove_done  (),
    // 轮转调度
    .advance      (time_slice_expired),
    .current_node (current_task_node),
    .current_data (current_task_info),
    .ring_empty   (no_tasks),
    .ring_count   (task_count)
);

// 当前任务执行，时间片到期后 advance 到下一个
assign task_execute = current_task_info;
assign time_slice_expired = (slice_cnt == 0) && !ring_empty;
```

### 环形 DMA 描述符链

```verilog
// DMA 引擎循环遍历描述符链
linked_list_circular #(
    .DEPTH      (4),
    .DATA_WIDTH (64)            // 描述符信息：地址+长度+控制
) u_dma_ring (
    .clk          (clk),
    .rst_n        (rst_n),
    .insert       (desc_add),
    .insert_data  (desc_info),
    .insert_node  (),
    .insert_done  (),
    .remove       (desc_remove),
    .remove_done  (),
    .advance      (dma_desc_done),      // 当前描述符完成后前进
    .current_node (),
    .current_data (current_desc),
    .ring_empty   (no_desc),
    .ring_count   ()
);

// DMA 引擎读取 current_desc 执行传输
```

### 令牌环仲裁

```verilog
// 4 个端口轮转获取令牌
linked_list_circular #(
    .DEPTH      (4),
    .DATA_WIDTH (4)             // 端口使能掩码
) u_token_ring (
    .clk          (clk),
    .rst_n        (rst_n),
    .insert       (1'b0),
    .insert_data  (4'd0),
    .insert_node  (),
    .insert_done  (),
    .remove       (1'b0),
    .remove_done  (),
    .advance      (token_pass),          // 令牌传递
    .current_node (token_holder),
    .current_data (token_port_mask),
    .ring_empty   (),
    .ring_count   ()
);

assign port_grant = token_port_mask & port_req;
assign token_pass = port_grant_done;
```

---

## 关键实现细节

- **循环结构**：尾节点 next = 头节点，头节点 prev = 尾节点
- **current_ptr**：指向当前轮转位置，advance 后移动到 next
- **插入**：在 current 后插入新节点（或链表尾），更新前后指针
- **删除**：断开 current 节点连接，current 移动到 next（或 prev）
- **空闲池**：内部 linked_list_free 管理空闲节点
- **单节点删除**：删除后环变空，ring_empty 拉高
- **面积**：DEPTH × (DATA_WIDTH + 2×ADDR_WIDTH + 1) 触发器
- **与链表队列区别**：队列有方向（头出尾进），循环链表无固定方向，轮转访问
