# shaper — 流量整形器

> **用途**：基于令牌桶算法限制数据流速率，实现带宽整形和流量监管
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

流量整形器（Traffic Shaper）基于令牌桶（Token Bucket）算法控制数据流速率。每个数据流配置一个令牌桶，桶以恒定速率填充令牌，每传输一个单位数据消耗一个令牌。当令牌不足时停止传输，从而将突发流量整形为平滑速率。用于网络出口整形（Egress Shaping）、QoS 带宽限制、AXI 总线速率控制等场景。

```
数据流 ──> ┌──────────┐ ──permit──> 允许传输
           │ shaper   │ ──blocked──> 被限速
           └──────────┘
令牌桶 ──> 以 CIR 速率填充令牌，每次传输消耗 token
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_FLOWS` | parameter | 4 | 整形流数量 |
| `TOKEN_WIDTH` | parameter | 24 | 令牌计数器位宽 |
| `RATE_WIDTH` | parameter | 16 | 速率配置位宽（令牌/周期） |
| `BURST_WIDTH` | parameter | 16 | 突发大小位宽 |
| `REFRESH_PERIOD` | parameter | 100 | 令牌刷新周期（时钟周期数） |
| `SHAPING_MODE` | parameter | `"SHAPER"` | 模式：`"SHAPER"` = 整形（排队），`"POLICER"` = 监管（丢弃/标记） |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `data_req` | I | `NUM_FLOWS` | clk | 各流传输请求 |
| `data_bytes` | I | `NUM_FLOWS × 16` | clk | 各流本次传输字节数 |
| `permit` | O | `NUM_FLOWS` | clk | 允许传输（独热或位向量） |
| `blocked` | O | `NUM_FLOWS` | clk | 被限速（令牌不足） |
| `cir` | I | `NUM_FLOWS × RATE_WIDTH` | clk | 承诺信息速率（Committed Information Rate） |
| `cbs` | I | `NUM_FLOWS × BURST_WIDTH` | clk | 承诺突发大小（Committed Burst Size） |
| `token_refresh` | I | 1 | clk | 令牌刷新脉冲（每 REFRESH_PERIOD 周期） |
| `cfg_update` | I | 1 | clk | 配置更新使能 |

---

## 时序

### 单流整形

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
token_cnt   ___|100|200|300|200|100|200|100|___
                   ↑刷新    ↑消耗100   ↑刷新
data_req    _____________|‾‾‾‾‾‾‾‾‾‾‾‾|_________
data_bytes  _____________| 100B       |_________
permit      _____________|‾‾‾‾‾‾‾‾‾‾‾‾|_________  (令牌足够→允许)
blocked     ______________________________________

token_cnt   ___|10|20|30|___
data_req    _________|‾‾‾‾‾|___
permit      ___________________  (令牌不足→阻塞)
blocked     _________|‾‾‾‾‾|___
```

### 多流并行整形

```
clk         __|‾|__|‾|__|‾|__|‾|__
data_req    ___|3'b111___________|
token[0]    ___| 500  (足够)     |
token[1]    ___| 100  (不足)     |
token[2]    ___| 300  (足够)     |
permit      ___|3'b101___________|  (流0和流2允许)
blocked     ___|3'b010___________|  (流1被限速)
```

---

## 用法

### 网络出口整形

```verilog
// 4 个流分别限速
// 流0: CIR=1Gbps, CBS=16KB
// 流1: CIR=500Mbps, CBS=8KB
// 流2: CIR=100Mbps, CBS=4KB
// 流3: CIR=50Mbps, CBS=2KB

shaper #(
    .NUM_FLOWS       (4),
    .TOKEN_WIDTH     (24),
    .REFRESH_PERIOD  (125),      // @125MHz, 每125周期刷新 ≈ 1MHz 刷新率
    .SHAPING_MODE    ("SHAPER")
) u_egress_shaper (
    .clk           (clk),
    .rst_n         (rst_n),
    .data_req      (queue_tx_req),
    .data_bytes    ({q3_bytes, q2_bytes, q1_bytes, q0_bytes}),
    .permit        (tx_permit),
    .blocked       (tx_blocked),
    .cir           ({cir3, cir2, cir1, cir0}),
    .cbs           ({cbs3, cbs2, cbs1, cbs0}),
    .token_refresh (ref_tick),
    .cfg_update    (1'b0)
);

// 整形后传输
assign tx_start = queue_tx_req & tx_permit;
```

### AXI 总线速率控制

```verilog
// 限制 AXI master 突发速率，防止 DDR 控制器过载
shaper #(
    .NUM_FLOWS       (1),
    .TOKEN_WIDTH     (20),
    .REFRESH_PERIOD  (64),
    .SHAPING_MODE    ("SHAPER")
) u_axi_shaper (
    .clk           (clk),
    .rst_n         (rst_n),
    .data_req      (m_axi_arvalid),
    .data_bytes    ({4'd0, m_axi_arlen}),  // arlen+1 = 传输拍数
    .permit        (shaper_permit),
    .blocked       (shaper_blocked),
    .cir           (cfg_cir),
    .cbs           (cfg_cbs),
    .token_refresh (ref_tick),
    .cfg_update    (1'b0)
);

// 被限速时反压 AR 通道
assign m_axi_arready = slave_arready & shaper_permit;
```

### 流量监管（Policer 模式）

```verilog
shaper #(
    .NUM_FLOWS       (2),
    .TOKEN_WIDTH     (16),
    .SHAPING_MODE    ("POLICER")
) u_policer (
    .clk           (clk),
    .rst_n         (rst_n),
    .data_req      (rx_valid),
    .data_bytes    (rx_bytes),
    .permit        (rx_accept),      // 令牌足够→放行
    .blocked       (rx_mark_drop),   // 令牌不足→标记或丢弃
    .cir           ({cir1, cir0}),
    .cbs           ({cbs1, cbs0}),
    .token_refresh (ref_tick),
    .cfg_update    (1'b0)
);
```

---

## 关键实现细节

- **令牌桶**：每个流一个 TOKEN_WIDTH 位有符号/无符号计数器
- **令牌填充**：`token_cnt <= min(token_cnt + cir, cbs)` — 令牌不超过桶容量 CBS
- **令牌消耗**：`token_cnt <= token_cnt - data_bytes` — 传输时扣除
- **permit 判断**：`token_cnt >= data_bytes` 时允许传输
- **SHAPER vs POLICER**：SHAPER 被阻塞时排队等待，POLICER 被阻塞时标记丢弃
- **REFRESH_PERIOD**：决定令牌填充的时钟频率，影响速率精度
- **速率换算**：`实际速率 = cir × (clk_freq / REFRESH_PERIOD) bytes/sec`
- **突发保护**：CBS 限制瞬间突发量，防止令牌累积过多导致突发过大
- **面积**：NUM_FLOWS × (TOKEN_WIDTH + RATE_WIDTH + BURST_WIDTH) 触发器 + 比较器/加法器
