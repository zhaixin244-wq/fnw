# priority_encoder — 优先编码器

> **用途**：将独热请求编码为二进制索引，支持可配置优先级方向
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

优先编码器将多位请求信号编码为二进制索引，当多个请求同时有效时按优先级选择一个。与 findfirstone/findlastone 类似，但接口更完整，支持 grant 独热码输出、优先级可编程、锁定模式等。广泛用于仲裁器、中断控制器、MUX 选择等。

```
req[N-1:0] ──> ┌──────────────────┐ ──grant──> 独热授权
               │ priority_encoder │ ──index──> 二进制索引
               └──────────────────┘ ──valid──> 有效标志
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_REQ` | parameter | 8 | 请求者数量 |
| `PRIORITY` | parameter | `"LOW"` | 优先级方向：`"LOW"` = 编号小优先，`"HIGH"` = 编号大优先 |
| `LOCK_EN` | parameter | 0 | 锁定使能 |
| `GRANT_OUT` | parameter | 1 | 是否输出独热 grant |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `req` | I | `NUM_REQ` | clk | 请求向量 |
| `grant` | O | `NUM_REQ` | clk | 独热授权 |
| `index` | O | `$clog2(NUM_REQ)` | clk | 二进制索引 |
| `valid` | O | 1 | clk | 存在有效请求 |
| `lock` | I | 1 | clk | 锁定当前 grant |
| `release` | I | 1 | clk | 释放锁定 |

---

## 时序

### LOW 优先级

```
clk       __|‾|__|‾|__|‾|__|‾|__
req       ___|4'b1100___________|  (req[2], req[3] 同时)
grant     ___|4'b0100___________|  (req[2] 优先)
index     _________| 2         |
valid     _________| ‾ ‾ ‾ ‾ ‾ _
```

### HIGH 优先级

```
clk       __|‾|__|‾|__|‾|__|‾|__
req       ___|4'b0110___________|
grant     ___|4'b0100___________|  (req[2] 高于 req[1])
index     _________| 2         |
valid     _________| ‾ ‾ ‾ ‾ ‾ _
```

### 锁定模式

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__
req       ___|4'b1111___|4'b1110___|
lock      _________|‾‾‾‾‾‾‾‾‾‾‾‾‾|___
grant     ___|4'b0001___|4'b0001___|___  (锁定后不切换)
release   _____________________|‾|_____
grant     _______________________|4'b0010  (释放后重新仲裁)
```

---

## 用法

### DMA 通道仲裁

```verilog
priority_encoder #(
    .NUM_REQ  (8),
    .PRIORITY ("LOW"),
    .LOCK_EN  (0)
) u_dma_arb (
    .clk    (clk),
    .rst_n  (rst_n),
    .req    (dma_ch_req),
    .grant  (dma_ch_grant),
    .index  (dma_ch_sel),
    .valid  (dma_any_req),
    .lock   (1'b0),
    .release(1'b0)
);
```

### 带锁定的总线仲裁

```verilog
priority_encoder #(
    .NUM_REQ  (4),
    .PRIORITY ("HIGH"),
    .LOCK_EN  (1)
) u_bus_arb (
    .clk      (clk),
    .rst_n    (rst_n),
    .req      ({m3_req, m2_req, m1_req, m0_req}),
    .grant    (grant),
    .index    (grant_idx),
    .valid    (grant_valid),
    .lock     (burst_start),        // 突发开始锁定
    .release  (burst_last)          // 突发结束释放
);
```

### MUX 选择

```verilog
priority_encoder #(
    .NUM_REQ  (4),
    .PRIORITY ("LOW"),
    .GRANT_OUT(0)                    // 只需要 index
) u_mux_sel (
    .clk    (clk),
    .rst_n  (rst_n),
    .req    (mux_select_req),
    .grant  (),
    .index  (mux_sel_idx),
    .valid  (mux_sel_valid),
    .lock   (1'b0),
    .release(1'b0)
);

always @(*) begin
    case (mux_sel_idx)
        2'd0: mux_out = data_0;
        2'd1: mux_out = data_1;
        2'd2: mux_out = data_2;
        2'd3: mux_out = data_3;
        default: mux_out = {DATA_WIDTH{1'b0}};
    endcase
end
```

---

## 关键实现细节

- **LOW 优先级**：`req & (~req + 1)` 提取最低有效位，再编码
- **HIGH 优先级**：从最高位向下扫描，或翻转后用 LOW 逻辑
- **grant 输出**：`(1 << index)` 或直接从优先级逻辑生成
- **锁定**：lock=1 时冻结 grant，release=1 时释放并重新仲裁
- **纯组合/时序**：可配置为纯组合输出或寄存器输出
- **面积**：log2(NUM_REQ) × NUM_REQ 个门 + 可选锁定触发器
- **与 findfirstone 区别**：priority_encoder 额外提供 grant 独热码和锁定机制
