# wrr — 加权轮询调度器

> **用途**：按照配置权重在多个请求者之间轮询调度，实现带宽比例分配
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

WRR（Weighted Round Robin）调度器在多个请求者之间按权重轮转调度。每个请求者分配一个权重值，每轮调度中被选中的次数等于其权重。相比固定优先级更公平，相比纯轮询可差异化带宽分配。适用于多端口 QoS 调度、DMA 带宽分配、网络出口队列调度等场景。

```
Req[0] (W=4) ──┐
Req[1] (W=2) ──┤──> ┌──────────┐ ──grant──> 被选中端口
Req[2] (W=1) ──┤    │   wrr    │
Req[3] (W=1) ──┘    └──────────┘
          权重配置 ──> 调度比例 = 4:2:1:1
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_REQ` | parameter | 4 | 请求者数量 |
| `WEIGHT_WIDTH` | parameter | 4 | 权重位宽（最大权重 = 2^WEIGHT_WIDTH - 1） |
| `MAX_WEIGHT` | parameter | 15 | 单端口最大权重值 |
| `WEIGHT_MODE` | parameter | `"STATIC"` | 权重模式：`"STATIC"` = 参数固定，`"DYNAMIC"` = 运行时配置 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `req` | I | `NUM_REQ` | clk | 请求向量 |
| `grant` | O | `NUM_REQ` | clk | 授权向量（独热码） |
| `grant_idx` | O | `$clog2(NUM_REQ)` | clk | 授权索引 |
| `grant_valid` | O | 1 | clk | 存在有效授权 |
| `weight` | I | `NUM_REQ × WEIGHT_WIDTH` | clk | 各端口权重值（DYNAMIC 模式） |
| `weight_update` | I | 1 | clk | 权重更新使能（DYNAMIC 模式） |

---

## 时序

### 静态权重（W0=4, W1=2, W2=1, W3=1）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
req         ___|4'b1111______________________________|
grant_idx   ___| 0 | 0 | 0 | 0 | 1 | 1 | 2 | 3 | 0 |
grant       ___|0001|0001|0001|0001|0010|0010|0100|1000|
            ↑ 一轮完成: 端口0被选4次，端口1被选2次，端口2、3各1次
```

- 一轮调度 = Σ(所有活跃端口权重) 个周期
- 如果某端口无请求（req[i]=0），其权重被跳过

### 权重运行时修改

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
weight      ___|W0=2,W1=2_____|W0=4,W1=1
weight_up   _____________|‾|___________
grant_idx   ___| 0 | 1 | 0 | 1 | 0 | 0 |  (更新后生效)
            ↑ 原来 2:2  → 更新后 4:1
```

---

## 用法

### QoS 带宽分配

```verilog
// 4 个优先级队列，带宽比例 4:2:1:1
wrr #(
    .NUM_REQ      (4),
    .WEIGHT_WIDTH (4),
    .WEIGHT_MODE  ("STATIC")
) u_qos_wrr (
    .clk         (clk),
    .rst_n       (rst_n),
    .req         ({q3_req, q2_req, q1_req, q0_req}),
    .grant       (grant),
    .grant_idx   (sel_queue),
    .grant_valid (grant_valid)
);
```

### 动态权重 DMA 调度

```verilog
// DMA 端口权重可通过寄存器配置
wrr #(
    .NUM_REQ      (4),
    .WEIGHT_WIDTH (8),
    .WEIGHT_MODE  ("DYNAMIC")
) u_dma_wrr (
    .clk           (clk),
    .rst_n         (rst_n),
    .req           (dma_req),
    .grant         (dma_grant),
    .grant_idx     (dma_grant_idx),
    .grant_valid   (dma_grant_valid),
    .weight        ({cfg_w3, cfg_w2, cfg_w1, cfg_w0}),
    .weight_update (cfg_update)
);
```

---

## 关键实现细节

- **计数器法**：每个端口维护一个递减计数器，当前端口计数器归零后切换到下一个
- **跳过机制**：权重为 0 或无请求（req=0）的端口直接跳过
- **一轮结束**：所有活跃端口权重消耗完后重新加载
- **公平性**：同一权重下严格轮询，不会饿死任何端口
- **DYNAMIC 模式**：权重更新在当前轮次结束后生效（避免中断进行中的调度）
- **面积**：NUM_REQ × WEIGHT_WIDTH 个触发器 + 状态控制逻辑
