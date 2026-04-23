# dwrr — 差异化加权轮询调度器

> **用途**：基于信用值（Credit）的加权轮询，支持变长包的精确带宽比例分配
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

DWRR（Deficit Weighted Round Robin）解决了标准 WRR 在变长包场景下的不公平问题。传统 WRR 按包计数轮询，大包会占用更多带宽。DWRR 引入"信用额度"（Quantum/Deficit Counter）概念，每轮给每个队列分配固定字节数的传输额度，传输完毕或额度用完后切换。适用于网络交换芯片出口调度、变长突发 DMA 调度等场景。

```
队列0 (Q=1500B) ──┐
队列1 (Q=750B)  ──┤──> ┌──────────┐ ──grant──> 被调度队列
队列2 (Q=375B)  ──┤    │   dwrr   │
队列3 (Q=375B)  ──┘    └──────────┘
         Quantum ──> 带宽比例 = 4:2:1:1（按字节）
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_QUEUES` | parameter | 4 | 队列数量 |
| `QUANTUM_WIDTH` | parameter | 16 | 量子位宽（字节），最大量子 = 2^16-1 |
| `CREDIT_WIDTH` | parameter | 17 | 信用计数器位宽（需容纳负值） |
| `QUANTUM_MODE` | parameter | `"STATIC"` | 量子模式：`"STATIC"` / `"DYNAMIC"` |
| `PKT_MODE` | parameter | `"BYTE"` | 计量模式：`"BYTE"` = 按字节，`"BEAT"` = 按传输拍数 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `queue_req` | I | `NUM_QUEUES` | clk | 队列非空指示 |
| `queue_len` | I | `NUM_QUEUES × 16` | clk | 各队列头部包长度（字节） |
| `grant` | O | `NUM_QUEUES` | clk | 调度授权（独热码） |
| `grant_idx` | O | `$clog2(NUM_QUEUES)` | clk | 被调度队列索引 |
| `grant_valid` | O | 1 | clk | 调度有效 |
| `tx_bytes` | I | 16 | clk | 本次实际传输字节数（传输完成时输入） |
| `tx_done` | I | 1 | clk | 传输完成脉冲 |
| `quantum` | I | `NUM_QUEUES × QUANTUM_WIDTH` | clk | 各队列量子值（DYNAMIC 模式） |

---

## 时序

### 变长包调度（Q0=1500B, Q1=750B, Q2=375B, Q3=375B）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
queue_req   ___|4'b1111___________________________|
queue_len   ___|L0=2000|L1=500|L2=800|L3=200____|

grant_idx   ___| 0       | 1    | 2       | 3   |
tx_bytes    ___| 1500    | 500  | 375     | 200 |
tx_done     ___|_____|‾|_______|‾|_________|‾|__|

credit[0]   _-1500|500 ← 剩余credit继续下轮
credit[1]   ___-750|250|
credit[2]   ___-375|425 ← 超出额度，分两轮
credit[3]   ___-375|175|
```

- 每队列 credit += quantum（每轮开始）
- 传输 credit -= tx_bytes（传输完成时）
- credit < 0 时停止调度，等待下轮恢复

---

## 用法

### 网络出口调度

```verilog
// 4 个优先级队列，精确字节级带宽分配
dwrr #(
    .NUM_QUEUES   (4),
    .QUANTUM_WIDTH(16),
    .QUANTUM_MODE ("STATIC"),
    .PKT_MODE     ("BYTE")
) u_egress_dwrr (
    .clk         (clk),
    .rst_n       (rst_n),
    .queue_req   ({q3_not_empty, q2_not_empty, q1_not_empty, q0_not_empty}),
    .queue_len   ({q3_hdr_len, q2_hdr_len, q1_hdr_len, q0_hdr_len}),
    .grant       (grant),
    .grant_idx   (sched_queue),
    .grant_valid (sched_valid),
    .tx_bytes    (tx_byte_cnt),
    .tx_done     (tx_complete)
);
```

### DMA 带宽分配（动态量子）

```verilog
dwrr #(
    .NUM_QUEUES   (8),
    .QUANTUM_WIDTH(12),
    .QUANTUM_MODE ("DYNAMIC")
) u_dma_dwrr (
    .clk         (clk),
    .rst_n       (rst_n),
    .queue_req   (dma_ch_req),
    .queue_len   (dma_ch_burst_len),
    .grant       (dma_ch_grant),
    .grant_idx   (dma_ch_sel),
    .grant_valid (dma_sched_valid),
    .tx_bytes    (dma_beat_bytes),
    .tx_done     (dma_burst_done),
    .quantum     ({ch7_q, ch6_q, ch5_q, ch4_q, ch3_q, ch2_q, ch1_q, ch0_q})
);
```

---

## 关键实现细节

- **信用计数器**：有符号计数器（CREDIT_WIDTH 位），每轮初 +quantum，传输时 -tx_bytes
- **调度逻辑**：轮询所有队列，选择 queue_req=1 且 credit > 0 的队列
- **一轮结束**：所有队列 credit < 0（额度耗尽）或无请求时，重新加量子
- **包长信息**：queue_len 输入当前包头长度，用于预判是否足够额度
- **跨包处理**：一个量子不足以传完一个大包时，credit 累积到下一轮
- **公平性保证**：长期来看带宽比例 = quantum 比例，即使包长差异大
- **面积**：NUM_QUEUES × CREDIT_WIDTH 触发器 + 比较器 + 轮询逻辑
- **相比 WRR 优势**：大包场景不会饿死小包队列，字节级精确带宽控制
