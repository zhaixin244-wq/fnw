# reset_sync — 复位同步器

> **用途**：异步复位同步释放，防止复位释放时的亚稳态传播
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

复位同步器实现"异步复位、同步释放"（Asynchronous Reset, Synchronous Release）。异步复位保证随时可复位，同步释放保证复位释放时与目标时钟域对齐，避免亚稳态和不同时序元件复位释放时间不一致导致的状态混乱。

```
rst_n (异步) ──> ┌─────────────┐ ──> rst_synced_n (同步释放)
                 │ reset_sync   │
clk ───────────> └─────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `STAGES` | parameter | 2 | 同步器级数（推荐 2，高可靠性场景用 3） |
| `POLARITY` | parameter | `"LOW"` | 复位极性：`"LOW"` = 低有效，`"HIGH"` = 高有效 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 目标时钟域 |
| `rst_n` | I | 1 | - | 原始异步复位（低有效） |
| `rst_synced_n` | O | 1 | clk | 同步释放后的复位信号 |
| `rst_synced` | O | 1 | clk | 同步释放后的复位信号（高有效，可选） |

---

## 时序

```
clk          __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
rst_n        ‾‾‾‾‾‾‾‾‾‾‾‾‾|___________________|‾‾‾‾
                          ↑ 异步拉低（立即复位）
rst_sync[0]  ‾‾‾‾‾‾‾‾‾‾‾‾‾|___________________|‾‾‾  (第一级跟随)
rst_sync[1]  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_______________|‾‾‾  (第二级跟随)
rst_synced_n ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_______________|‾‾‾  (同步释放)
                              ↑ 复位释放经过 2 级同步
                              ↑ 与时钟上升沿对齐
```

- **异步复位**：`rst_n` 拉低时，`rst_synced_n` 立即拉低（经过组合逻辑路径）
- **同步释放**：`rst_n` 拉高后，`rst_synced_n` 经过 STAGES 个时钟周期后才拉高
- **释放对齐**：复位释放时刻与 clk 上升沿对齐，避免亚稳态

---

## 用法

### 基本用法

```verilog
// 单时钟域复位同步
reset_sync #(
    .STAGES  (2),
    .POLARITY("LOW")
) u_rst_sync (
    .clk          (clk),
    .rst_n        (ext_rst_n),
    .rst_synced_n (sys_rst_n),
    .rst_synced   (sys_rst)
);

// 使用同步后的复位
always @(posedge clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        data_reg <= {DATA_WIDTH{1'b0}};
    else
        data_reg <= data_next;
end
```

### 多时钟域复位

```verilog
// 每个时钟域独立复位同步
reset_sync u_rst_sync_fast (
    .clk          (clk_fast),
    .rst_n        (ext_rst_n),
    .rst_synced_n (rst_fast_n)
);

reset_sync u_rst_sync_slow (
    .clk          (clk_slow),
    .rst_n        (ext_rst_n),
    .rst_synced_n (rst_slow_n)
);
```

### 与异步 FIFO 配合

```verilog
// 写侧复位同步
reset_sync u_rst_wr (
    .clk          (clk_wr),
    .rst_n        (global_rst_n),
    .rst_synced_n (rst_wr_n)
);

// 读侧复位同步
reset_sync u_rst_rd (
    .clk          (clk_rd),
    .rst_n        (global_rst_n),
    .rst_synced_n (rst_rd_n)
);
```

---

## 关键实现细节

- **同步链**：`STAGES` 级触发器链，级间串联
- **异步复位路径**：`rst_n` 直接连接所有触发器的异步复位端（`CLR` / `PRE`）
- **同步释放路径**：触发器 D 端接高电平，Q 级联，最后一级 Q 输出为 `rst_synced_n`
- **低有效**：`rst_sync[0] <= 1'b0`（复位），`rst_sync[0] <= 1'b1`（释放）
- **高有效模式**：POLARITY="HIGH" 时，D 端接低电平，逻辑取反
- **复位释放顺序**：确保复位释放晚于系统中所有数据寄存器的复位释放
- **DFT 兼容**：异步复位端可接入扫描链的 SE（Scan Enable）控制
- **面积**：STAGES 个触发器，极小开销
