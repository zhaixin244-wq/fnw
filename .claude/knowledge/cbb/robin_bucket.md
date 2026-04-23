# robin_bucket — 轮询桶调度器

> **用途**：基于令牌桶 + 轮询机制的公平调度，适合变长事务场景
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

轮询桶调度器（Robin Bucket Scheduler）结合轮询和令牌桶两种机制。每个通道维护一个令牌桶，调度器轮询所有通道，选择令牌充足的通道进行传输。令牌不足的通道被跳过，等到下一轮令牌补充后继续。相比纯轮询更公平（大事务不会阻塞小通道），相比 DWRR 实现更简单。适用于 DMA 突发调度、NoC 路由仲裁、内存控制器调度等。

```
Ch0 (tokens=4) ──┐
Ch1 (tokens=2) ──┤──> ┌──────────────┐ ──grant──> 被调度通道
Ch2 (tokens=1) ──┤    │ robin_bucket │
Ch3 (tokens=0) ──┘    └──────────────┘
                轮询 + 令牌桶
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_CH` | parameter | 4 | 通道数量 |
| `TOKEN_WIDTH` | parameter | 8 | 令牌计数器位宽 |
| `COST_WIDTH` | parameter | 4 | 单次消耗令牌数位宽 |
| `REFILL_VALUE` | parameter | 4 | 每轮补充令牌数 |
| `TOKEN_MAX` | parameter | 15 | 令牌桶容量上限 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `req` | I | `NUM_CH` | clk | 通道请求 |
| `cost` | I | `NUM_CH × COST_WIDTH` | clk | 各通道单次传输消耗令牌数 |
| `grant` | O | `NUM_CH` | clk | 授权（独热码） |
| `grant_idx` | O | `$clog2(NUM_CH)` | clk | 授权索引 |
| `grant_valid` | O | 1 | clk | 授权有效 |
| `tx_done` | I | 1 | clk | 传输完成（扣除令牌） |
| `refill` | I | 1 | clk | 令牌补充脉冲 |
| `tokens` | O | `NUM_CH × TOKEN_WIDTH` | clk | 各通道当前令牌数（调试） |

---

## 时序

### 轮询调度

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
req         ___|4'b1111____________________|
tokens      _|C0=4|C1=2|C2=1|C3=0__________|
grant_idx   ___| 0       | 1    | 2       |  (跳过 Ch3，令牌为 0)
tx_done     _________|‾|_______|‾|___________|  (Ch0 完成扣 1 令牌)
tokens      _|C0=3|C1=2|C2=0|C3=0__________|  (Ch2 令牌耗尽)
```

### 令牌补充

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
refill      _________|‾|_______________
tokens      _|C0=1|C1=0|C2=0|C3=0______|
             ↑ refill: C0+=4, C1+=4, C2+=4, C3+=4 → 但上限 TOKEN_MAX
tokens      _|C0=5|C1=4|C2=4|C3=4______|  (补充后)
```

---

## 用法

### DMA 突发调度

```verilog
robin_bucket #(
    .NUM_CH       (4),
    .TOKEN_WIDTH  (8),
    .REFILL_VALUE (8),
    .TOKEN_MAX    (15)
) u_dma_sched (
    .clk        (clk),
    .rst_n      (rst_n),
    .req        ({dma3_req, dma2_req, dma1_req, dma0_req}),
    .cost       ({4'd1, 4'd1, 4'd1, 4'd1}),    // 每次消耗 1 令牌
    .grant      (dma_grant),
    .grant_idx  (dma_sel),
    .grant_valid(dma_valid),
    .tx_done    (dma_burst_done),
    .refill     (refill_tick),         // 定时补充
    .tokens     ()
);

// 定时器：每 256 周期补充一次令牌
always @(posedge clk) begin
    if (!rst_n)
        refill_cnt <= 8'd0;
    else
        refill_cnt <= refill_cnt + 1'b1;
end
assign refill_tick = (refill_cnt == 8'd255);
```

### NoC 路由仲裁

```verilog
robin_bucket #(
    .NUM_CH       (5),         // 5 个方向输入端口
    .TOKEN_WIDTH  (6),
    .REFILL_VALUE (4),
    .TOKEN_MAX    (7)
) u_noc_arb (
    .clk        (clk),
    .rst_n      (rst_n),
    .req        ({local_req, south_req, north_req, east_req, west_req}),
    .cost       ({2'd1, 2'd1, 2'd1, 2'd1, 2'd1}),
    .grant      (port_grant),
    .grant_idx  (sel_port),
    .grant_valid(sched_valid),
    .tx_done    (flit_sent),
    .refill     (cycle_refill),
    .tokens     ()
);
```

### 带差异化消耗的调度

```verilog
// 不同通道消耗不同令牌数，实现差异化带宽
robin_bucket #(
    .NUM_CH       (3),
    .TOKEN_WIDTH  (8),
    .COST_WIDTH   (4),
    .REFILL_VALUE (8),
    .TOKEN_MAX    (15)
) u_diff_sched (
    .clk        (clk),
    .rst_n      (rst_n),
    .req        (ch_req),
    .cost       ({4'd2, 4'd1, 4'd1}),  // Ch2 每次消耗 2 令牌（带宽减半）
    .grant      (ch_grant),
    .grant_idx  (ch_sel),
    .grant_valid(ch_valid),
    .tx_done    (ch_tx_done),
    .refill     (refill_pulse),
    .tokens     (ch_tokens)
);
```

---

## 关键实现细节

- **轮询指针**：从上一轮胜出者的下一个位置开始扫描
- **令牌检查**：轮询时跳过 tokens < cost 的通道
- **令牌扣除**：tx_done 时 tokens -= cost
- **令牌补充**：refill 脉冲时 tokens = min(tokens + REFILL_VALUE, TOKEN_MAX)
- **全部耗尽**：所有通道 tokens < cost 时，等待 refill 后重新调度
- **公平性**：轮询保证每个令牌充足的通道都有机会
- **与 WRR 区别**：robin_bucket 按事务计数而非按权重，实现更简单
- **面积**：NUM_CH × TOKEN_WIDTH 触发器 + 轮询逻辑 + 比较器
