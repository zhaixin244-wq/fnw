# arbiter — 总线仲裁器

> **用途**：多请求者共享单一资源时的仲裁逻辑
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

仲裁器用于多个请求者（requestor）竞争共享资源（如总线、存储端口）时，按照预定义策略选择一个请求者授予访问权。支持两种策略：

- **Fixed Priority（固定优先级）**：固定优先级顺序，编号越小优先级越高
- **Round Robin（轮询）**：公平轮转，每个请求者获得均等机会

```
Req[0] ──┐
Req[1] ──┤──> ┌──────────┐ ──grant──> 被选中的请求者
Req[2] ──┤    │ arbiter  │
Req[N-1]─┘    └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_REQ` | parameter | 4 | 请求者数量 |
| `ARB_TYPE` | parameter | `"RR"` | 仲裁策略：`"FP"` = 固定优先级，`"RR"` = 轮询 |
| `LOCK_EN` | parameter | 0 | 锁定使能：1 = grant 后锁定直到释放 |
| `LOG2_REQ` | localparam | `$clog2(NUM_REQ)` | grant 编码位宽 |

---

## 接口

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `req` | I | `NUM_REQ` | 请求向量，每位对应一个请求者 |
| `grant` | O | `NUM_REQ` | 授权向量（独热码），仅 1 位有效 |
| `grant_idx` | O | `LOG2_REQ` | 授权索引（二进制编码） |
| `grant_valid` | O | 1 | 存在有效授权 |
| `lock` | I | 1 | 锁定当前 grant（`LOCK_EN=1` 时有效） |
| `release` | I | 1 | 释放锁定（`LOCK_EN=1` 时有效） |

---

## 时序

### 固定优先级仲裁

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
req         ___|3'b101___|3'b111___|3'b010___
grant       ___|3'b001___|3'b001___|3'b010___
grant_idx   ___|  0      |  0      |  1      |
grant_valid ___|‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾‾
            ↑ req[0]和req[2]同时请求，grant[0]（优先级最高）
                      ↑ req[0]仍在，仍grant[0]
                                ↑ req[0]释放，grant[1]
```

### 轮询仲裁

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
req         ___|3'b111___|3'b111___|3'b111___
grant       ___|3'b001___|3'b010___|3'b100___
grant_idx   ___|  0      |  1      |  2      |
            ↑ 从 req[0] 开始，轮转到 req[1]，再 req[2]
```

---

## 用法

### 固定优先级仲裁

```verilog
// 4 个 DMA 通道竞争存储端口
arbiter #(
    .NUM_REQ   (4),
    .ARB_TYPE  ("FP"),
    .LOCK_EN   (0)
) u_arbiter (
    .clk         (clk),
    .rst_n       (rst_n),
    .req         ({dma3_req, dma2_req, dma1_req, dma0_req}),
    .grant       (grant),
    .grant_idx   (grant_idx),
    .grant_valid (grant_valid)
);

// 使用仲裁结果
assign dma0_grant = grant[0];
assign dma1_grant = grant[1];
assign dma2_grant = grant[2];
assign dma3_grant = grant[3];

// 将被选中通道的数据送到共享端口
always @(*) begin
    case (grant_idx)
        2'd0: shared_data = dma0_data;
        2'd1: shared_data = dma1_data;
        2'd2: shared_data = dma2_data;
        2'd3: shared_data = dma3_data;
        default: shared_data = {DATA_WIDTH{1'b0}};
    endcase
end
```

### 轮询仲裁（公平访问）

```verilog
// 4 个 master 共享 AXI 总线
arbiter #(
    .NUM_REQ   (4),
    .ARB_TYPE  ("RR"),
    .LOCK_EN   (0)
) u_arbiter (
    .clk         (clk),
    .rst_n       (rst_n),
    .req         ({m3_arvalid, m2_arvalid, m1_arvalid, m0_arvalid}),
    .grant       (grant),
    .grant_idx   (grant_idx),
    .grant_valid (grant_valid)
);
```

### 带锁定的仲裁（事务级锁定）

```verilog
// 突发传输期间锁定仲裁，防止中途切换 master
arbiter #(
    .NUM_REQ   (4),
    .ARB_TYPE  ("RR"),
    .LOCK_EN   (1)
) u_arbiter (
    .clk         (clk),
    .rst_n       (rst_n),
    .req         (req),
    .grant       (grant),
    .grant_idx   (grant_idx),
    .grant_valid (grant_valid),
    .lock        (burst_start),       // 突发开始时锁定
    .release     (burst_last_beat)    // 突发最后一拍释放
);
```

---

## 关键实现细节

- **固定优先级**：使用 `priority_encoder`，`req & (~req + 1)` 提取最低有效位
- **轮询**：使用 `mask` 屏蔽已服务的低位，`req & mask` 找下一个；mask 耗尽后重置
- **锁定机制**：`lock=1` 时冻结 `pointer`，`release=1` 时更新 `pointer` 到 `grant_idx+1`
- **无请求时**：`grant=0`，`grant_valid=0`，`grant_idx` 保持上次值
