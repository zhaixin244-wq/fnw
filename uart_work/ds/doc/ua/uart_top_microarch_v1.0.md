# uart_top 微架构规格书

> 基于 `uart_FS_v1.0.md` §5.7 编写。顶层集成模块，仅做子模块实例化和信号连接，禁止包含任何逻辑。编码规范遵循 `rules/coding-style.md`。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块/子模块** | `uart` / `uart_top` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-MA-uart_top-v1.0` |
| **对应 FS** | `uart_FS_v1.0.md` §5.7 |
| **作者/日期/审核** | `AI Agent` / `2026-04-27` / `{reviewer}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本 |

---

## 3. 子模块概述

### 3.1 功能定位

`uart_top` 是顶层集成模块，仅做子模块实例化和信号连接，不包含任何逻辑（无 `always` 块）。实例化所有子模块，连接子模块间信号，对外暴露 APB 接口和 UART 外部信号。

**从 FS 继承的需求**：

| 需求 ID | 需求描述 | FS 章节 |
|---------|----------|---------|
| REQ-009 | APB 从接口 32 位 | FS §5.7, §6.2 |
| REQ-013 | 单时钟域 ≥ 50 MHz | FS §9, §8.1 |

### 3.2 与上级/兄弟模块的关系

| 邻接模块 | 接口方向 | 接口名称 | 说明 |
|----------|----------|----------|------|
| APB Master | 双向 | APB 总线信号 | APB3 从接口 |
| 外部设备 | 双向 | txd, rxd, rts_n, cts_n | UART 串行接口 |
| 系统 | 输出 | irq | 中断输出 |

### 3.3 内部框图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 模块连接图（`wd_uart_top_connect.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![UART 模块连接图](wd_uart_top_connect.png)
```

> **图片说明**：本图展示 UART 顶层模块的子模块连接拓扑，包含 7 个子模块：
> - `uart_reg_mod`：APB 从接口，负责寄存器读写和地址解码
> - `uart_baud_gen`：小数波特率发生器，生成 baud_tick 和 baud_tick_16x
> - `uart_tx`：发送状态机 + 移位寄存器，从 TX FIFO 读取数据并串行发送
> - `uart_rx`：接收状态机 + 过采样 + 移位寄存器，接收串行数据写入 RX FIFO
> - `uart_fifo(TX)`：TX FIFO，深度 16，宽度 10
> - `uart_fifo(RX)`：RX FIFO，深度 16，宽度 11
> - `uart_ctrl`：中断逻辑 + 模式控制 + 流控
>
> 外部接口：APB 总线（左）、UART 串行（右）、中断（上）
> 内部接口：reg_bus（寄存器读写）、baud_tick_bus（波特率时钟）、tx_fifo_bus/rx_fifo_bus（FIFO 接口）、status_bus/ctrl_bus（状态/控制）

---

## 4. 接口定义

### 4.1 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟（50 MHz） |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `paddr` | I | 5 | wire | clk | - | APB 地址 |
| 4 | `psel` | I | 1 | wire | clk | - | APB 选择 |
| 5 | `penable` | I | 1 | wire | clk | - | APB 使能 |
| 6 | `pwrite` | I | 1 | wire | clk | - | APB 写使能 |
| 7 | `pwdata` | I | 32 | wire | clk | - | APB 写数据 |
| 8 | `prdata` | O | 32 | wire | clk | - | APB 读数据 |
| 9 | `pready` | O | 1 | wire | clk | - | APB 就绪 |
| 10 | `pslverr` | O | 1 | wire | clk | - | APB 错误 |
| 11 | `txd` | O | 1 | wire | clk | - | 发送数据线 |
| 12 | `rxd` | I | 1 | wire | - | - | 接收数据线 |
| 13 | `rts_n` | O | 1 | wire | clk | - | 请求发送（低有效） |
| 14 | `cts_n` | I | 1 | wire | - | - | 清除发送（低有效） |
| 15 | `irq` | O | 1 | wire | clk | - | 中断输出 |

**与 FS 接口映射**：

| 本模块端口 | FS 接口 | FS 信号名 | 映射说明 |
|------------|---------|-----------|----------|
| `clk` | FS §6.2 | `clk` | 直连 |
| `rst_n` | FS §6.2 | `rst_n` | 直连 |
| `paddr` | FS §6.2 | `paddr` | 直连 |
| `psel` | FS §6.2 | `psel` | 直连 |
| `penable` | FS §6.2 | `penable` | 直连 |
| `pwrite` | FS §6.2 | `pwrite` | 直连 |
| `pwdata` | FS §6.2 | `pwdata` | 直连 |
| `prdata` | FS §6.2 | `prdata` | 直连 |
| `pready` | FS §6.2 | `pready` | 直连 |
| `pslverr` | FS §6.2 | `pslverr` | 直连 |
| `txd` | FS §6.2 | `txd` | 直连 |
| `rxd` | FS §6.2 | `rxd` | 直连 |
| `rts_n` | FS §6.2 | `rts_n` | 直连 |
| `cts_n` | FS §6.2 | `cts_n` | 直连 |
| `irq` | FS §6.2 | `irq` | 直连 |

### 4.2 接口协议与时序

不适用——顶层无逻辑，时序由各子模块独立约束。

---

## 5. 微架构设计

### 5.1 数据通路

不适用——顶层无逻辑，数据通路由各子模块独立处理。

### 5.2 控制逻辑

不适用——顶层无逻辑，控制由各子模块独立处理。

### 5.3 状态机设计

不适用——顶层无逻辑，无状态机。

### 5.4 流水线设计

不适用——顶层无逻辑，无流水线。

### 5.5 FIFO / 缓冲设计

不适用——顶层无逻辑，FIFO 由 uart_fifo 子模块实现。

### 5.6 子模块实例化列表

#### 子模块实例化

| 实例名 | 模块名 | 参数 | 说明 |
|--------|--------|------|------|
| `u_reg_mod` | uart_reg_mod | ADDR_WIDTH=5, DATA_WIDTH=32 | APB 从接口 + 寄存器 |
| `u_baud_gen` | uart_baud_gen | - | 波特率发生器 |
| `u_tx` | uart_tx | - | 发送模块 |
| `u_rx` | uart_rx | - | 接收模块 |
| `u_tx_fifo` | uart_fifo | DATA_WIDTH=10, DEPTH=16 | TX FIFO |
| `u_rx_fifo` | uart_fifo | DATA_WIDTH=11, DEPTH=16 | RX FIFO |
| `u_ctrl` | uart_ctrl | - | 控制模块 |

#### 子模块端口连接

**uart_reg_mod (u_reg_mod)**：

| 端口 | 连接目标 | 信号名 |
|------|----------|--------|
| clk | 顶层 clk | clk |
| rst_n | 顶层 rst_n | rst_n |
| paddr | 顶层 paddr | paddr |
| psel | 顶层 psel | psel |
| penable | 顶层 penable | penable |
| pwrite | 顶层 pwrite | pwrite |
| pwdata | 顶层 pwdata | pwdata |
| prdata | 顶层 prdata | prdata |
| pready | 顶层 pready | pready |
| pslverr | 顶层 pslverr | pslverr |
| dlab | → u_baud_gen, u_tx, u_rx | dlab |
| ier | → u_ctrl | ier |
| lcr | → u_tx, u_rx | lcr |
| mcr | → u_ctrl | mcr |
| fcr | → u_tx_fifo, u_rx_fifo | fcr |
| dll | → u_baud_gen | dll |
| dlh | → u_baud_gen | dlh |
| fcr_ext | → u_baud_gen, u_ctrl | fcr_ext |
| reg_rd_data | ← u_ctrl.lsr, u_ctrl.msr, u_ctrl.iir, u_rx.rx_data | reg_rd_data |

**uart_baud_gen (u_baud_gen)**：

| 端口 | 连接目标 | 信号名 |
|------|----------|--------|
| clk | 顶层 clk | clk |
| rst_n | 顶层 rst_n | rst_n |
| baud_div_int | u_reg_mod.dl[15:0] | baud_div_int |
| baud_div_frac | u_reg_mod.fcr_ext[3:0] | baud_div_frac |
| oversample_sel | u_reg_mod.fcr_ext[4] | oversample_sel |
| baud_tick_16x | → u_tx, u_rx | baud_tick_16x |
| baud_tick_8x | → u_rx | baud_tick_8x |
| baud_tick | → u_rx | baud_tick |

**uart_tx (u_tx)**：

| 端口 | 连接目标 | 信号名 |
|------|----------|--------|
| clk | 顶层 clk | clk |
| rst_n | 顶层 rst_n | rst_n |
| baud_tick_16x | u_baud_gen.baud_tick_16x | baud_tick_16x |
| tx_data | u_tx_fifo.rd_data[7:0] | tx_data |
| tx_fifo_empty | u_tx_fifo.fifo_empty | tx_fifo_empty |
| tx_fifo_rd_en | → u_tx_fifo.rd_en | tx_fifo_rd_en |
| data_bits | u_reg_mod.lcr[1:0] | data_bits |
| stop_bits | u_reg_mod.lcr[2] | stop_bits |
| parity_en | u_reg_mod.lcr[3] | parity_en |
| parity_even | u_reg_mod.lcr[4] | parity_even |
| cts_n | 顶层 cts_n | cts_n |
| loopback_en | u_ctrl.loopback_en | loopback_en |
| tx_pause | u_ctrl.tx_pause | tx_pause |
| txd | 顶层 txd | txd |
| tx_done | → u_ctrl | tx_done |
| tx_busy | → u_ctrl | tx_busy |

**uart_rx (u_rx)**：

| 端口 | 连接目标 | 信号名 |
|------|----------|--------|
| clk | 顶层 clk | clk |
| rst_n | 顶层 rst_n | rst_n |
| baud_tick_16x | u_baud_gen.baud_tick_16x | baud_tick_16x |
| baud_tick_8x | u_baud_gen.baud_tick_8x | baud_tick_8x |
| rxd | 顶层 rxd（Loopback 时接 u_tx.txd） | rxd |
| rx_fifo_full | u_rx_fifo.fifo_full | rx_fifo_full |
| rx_fifo_wr_en | → u_rx_fifo.wr_en | rx_fifo_wr_en |
| rx_data | → u_rx_fifo.wr_data | rx_data |
| rx_valid | → u_ctrl | rx_valid |
| data_bits | u_reg_mod.lcr[1:0] | data_bits |
| stop_bits | u_reg_mod.lcr[2] | stop_bits |
| parity_en | u_reg_mod.lcr[3] | parity_en |
| parity_even | u_reg_mod.lcr[4] | parity_even |
| oversample_sel | u_reg_mod.fcr_ext[4] | oversample_sel |
| loopback_en | u_ctrl.loopback_en | loopback_en |
| frame_err | → u_ctrl | frame_err |
| parity_err | → u_ctrl | parity_err |
| break_detect | → u_ctrl | break_detect |
| rx_busy | → u_ctrl | rx_busy |
| rts_n | 顶层 rts_n | rts_n |

**uart_fifo TX (u_tx_fifo)**：

| 端口 | 连接目标 | 信号名 |
|------|----------|--------|
| clk | 顶层 clk | clk |
| rst_n | 顶层 rst_n | rst_n |
| wr_en | u_reg_mod.reg_wr_en && addr==THR | tx_fifo_wr_en |
| wr_data | u_reg_mod.reg_wr_data[9:0] | tx_fifo_wr_data |
| rd_en | u_tx.tx_fifo_rd_en | tx_fifo_rd_en |
| rd_data | → u_tx.tx_data | tx_fifo_rd_data |
| fifo_full | → u_reg_mod | tx_fifo_full |
| fifo_empty | → u_tx, u_ctrl | tx_fifo_empty |
| fifo_almost_full | - | tx_fifo_almost_full |
| fifo_count | → u_reg_mod | tx_fifo_count |
| almost_full_thresh | 4'd15 | almost_full_thresh |

**uart_fifo RX (u_rx_fifo)**：

| 端口 | 连接目标 | 信号名 |
|------|----------|--------|
| clk | 顶层 clk | clk |
| rst_n | 顶层 rst_n | rst_n |
| wr_en | u_rx.rx_fifo_wr_en | rx_fifo_wr_en |
| wr_data | u_rx.rx_data | rx_fifo_wr_data |
| rd_en | u_reg_mod.reg_rd_en && addr==RBR | rx_fifo_rd_en |
| rd_data | → u_reg_mod.reg_rd_data | rx_fifo_rd_data |
| fifo_full | → u_rx, u_ctrl | rx_fifo_full |
| fifo_empty | → u_reg_mod | rx_fifo_empty |
| fifo_almost_full | → u_ctrl | rx_fifo_almost_full |
| fifo_count | → u_reg_mod | rx_fifo_count |
| almost_full_thresh | fcr_rx_trig 配置 | almost_full_thresh |

**uart_ctrl (u_ctrl)**：

| 端口 | 连接目标 | 信号名 |
|------|----------|--------|
| clk | 顶层 clk | clk |
| rst_n | 顶层 rst_n | rst_n |
| ier | u_reg_mod.ier | ier |
| tx_done | u_tx.tx_done | tx_done |
| tx_fifo_empty | u_tx_fifo.fifo_empty | tx_fifo_empty |
| rx_valid | u_rx.rx_valid | rx_valid |
| rx_fifo_full | u_rx_fifo.fifo_full | rx_fifo_full |
| rx_fifo_almost_full | u_rx_fifo.fifo_almost_full | rx_fifo_almost_full |
| frame_err | u_rx.frame_err | frame_err |
| parity_err | u_rx.parity_err | parity_err |
| break_detect | u_rx.break_detect | break_detect |
| overrun_err | u_rx_fifo.fifo_overflow | overrun_err |
| cts_n | 顶层 cts_n | cts_n |
| loopback_en | u_reg_mod.mcr[4] | loopback_en |
| flow_ctrl_en | u_reg_mod.mcr[5] | flow_ctrl_en |
| fcr_rx_trig | u_reg_mod.fcr[5:4] | fcr_rx_trig |
| tx_busy | u_tx.tx_busy | tx_busy |
| rx_busy | u_rx.rx_busy | rx_busy |
| irq | 顶层 irq | irq |
| iir | → u_reg_mod.reg_rd_data | iir |
| lsr | → u_reg_mod.reg_rd_data | lsr |
| msr | → u_reg_mod.reg_rd_data | msr |
| rts_n_out | 顶层 rts_n | rts_n |
| tx_pause | → u_tx.tx_pause | tx_pause |

#### Loopback 连接

当 `loopback_en=1` 时，`u_tx.txd` 内部连接到 `u_rx.rxd`：

```verilog
// Loopback 模式
wire rxd_actual = loopback_en ? txd_internal : rxd;
```

#### 寄存器读数据 mux

```verilog
// reg_rd_data 多路选择
always @(*) begin
    reg_rd_data = 0;
    case (reg_addr)
        5'h00: reg_rd_data = dlab ? {24'b0, dll} : {24'b0, rx_fifo_rd_data[7:0]};
        5'h04: reg_rd_data = {28'b0, ier};
        5'h08: reg_rd_data = {24'b0, iir, 2'b11, 2'b0};
        5'h0C: reg_rd_data = {24'b0, lcr};
        5'h10: reg_rd_data = {26'b0, mcr};
        5'h14: reg_rd_data = {24'b0, lsr};
        5'h18: reg_rd_data = {24'b0, msr};
        5'h1C: reg_rd_data = {24'b0, scr};
        5'h20: reg_rd_data = dlab ? {24'b0, dll} : 0;
        5'h24: reg_rd_data = dlab ? {24'b0, dlh} : 0;
        5'h28: reg_rd_data = {24'b0, fcr_ext};
        default: reg_rd_data = 0;
    endcase
end
```

---

## 6. 关键时序分析

不适用——顶层无逻辑，时序由各子模块独立约束，顶层无关键路径。

---

## 7. 时钟与复位

### 时钟域归属

| 信号 | 时钟域 | 说明 |
|------|--------|------|
| 所有信号 | clk | 主时钟域，所有子模块使用同一时钟 |

### 复位策略

异步复位同步释放，低有效 `rst_n`，2 级同步器。复位由各子模块独立处理。

### CDC 处理

CDC 由 uart_rx 子模块内部处理（rxd 2 级同步器），顶层无 CDC 信号。

---

## 8. PPA 预估

### 子模块 PPA 汇总

| 子模块 | 面积(kGates) | 功耗(mW) | 说明 |
|--------|-------------|----------|------|
| uart_reg_mod | 1.0 | 0.4 | APB 接口 + 寄存器 |
| uart_baud_gen | 0.5 | 0.25 | 波特率发生器 |
| uart_tx | 1.5 | 1.2 | 发送模块 |
| uart_rx | 1.7 | 1.2 | 接收模块 |
| uart_fifo(TX) | 0.9 | 0.4 | TX FIFO |
| uart_fifo(RX) | 1.0 | 0.4 | RX FIFO |
| uart_ctrl | 1.0 | 0.4 | 控制模块 |
| uart_top | 0.0 | 0.0 | 仅连线 |
| **合计** | **7.6** | **4.25** | |

注：合计面积 7.6 kGates < FS 预算 10 kGates，满足要求。合计功耗 4.25 mW < FS 预算 5 mW，满足要求。

---

## 9. RTL 实现指导

### 文件结构
```
uart_top.v               — 主模块 RTL
uart_top_sva.sv          — SVA 断言
uart_top_tb.v            — 仿真 testbench
```

### 编码规范

遵循 `rules/coding-style.md`。**铁律：顶层模块仅做子模块实例化和信号连接，禁止包含任何逻辑。**

| 高风险项 | 关注点 |
|----------|--------|
| 禁止 always 块 | 顶层仅允许 assign 和子模块实例化 |
| 禁止组合逻辑 | 顶层不允许任何组合逻辑 |
| 名称关联 | 子模块实例化必须名称关联，禁止位置关联 |
| Loopback 连接 | loopback_en 时 txd 内连到 rxd |

### RTL 伪代码框架

```verilog
module uart_top #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // APB 接口
    input  wire [ADDR_WIDTH-1:0] paddr,
    input  wire                  psel,
    input  wire                  penable,
    input  wire                  pwrite,
    input  wire [DATA_WIDTH-1:0] pwdata,
    output wire [DATA_WIDTH-1:0] prdata,
    output wire                  pready,
    output wire                  pslverr,
    // UART 接口
    output wire                  txd,
    input  wire                  rxd,
    output wire                  rts_n,
    input  wire                  cts_n,
    // 中断
    output wire                  irq
);

// 内部信号声明
wire        dlab;
wire [3:0]  ier;
wire [7:0]  lcr;
wire [5:0]  mcr;
wire [7:0]  fcr;
wire [7:0]  dll;
wire [7:0]  dlh;
wire [7:0]  fcr_ext;
wire [7:0]  scr;
wire        reg_wr_en, reg_rd_en;
wire [ADDR_WIDTH-1:0] reg_addr;
wire [DATA_WIDTH-1:0] reg_wr_data;
wire [DATA_WIDTH-1:0] reg_rd_data;

wire        baud_tick_16x, baud_tick_8x, baud_tick;

wire [7:0]  tx_data;
wire        tx_fifo_empty;
wire        tx_fifo_rd_en;
wire        tx_done, tx_busy;
wire        tx_pause;

wire [10:0] rx_fifo_wr_data;
wire        rx_fifo_wr_en;
wire        rx_fifo_full, rx_fifo_empty;
wire        rx_valid, frame_err, parity_err, break_detect;
wire        rx_busy;

wire [9:0]  tx_fifo_rd_data;
wire [10:0] rx_fifo_rd_data;

wire        loopback_en = mcr[4];
wire        flow_ctrl_en = mcr[5];

// Loopback 连接
wire rxd_actual = loopback_en ? txd : rxd;

// 子模块实例化
uart_reg_mod #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) u_reg_mod (
    .clk(clk),
    .rst_n(rst_n),
    .paddr(paddr),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .pwdata(pwdata),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr),
    .reg_wr_en(reg_wr_en),
    .reg_rd_en(reg_rd_en),
    .reg_addr(reg_addr),
    .reg_wr_data(reg_wr_data),
    .reg_rd_data(reg_rd_data),
    .dlab(dlab),
    .ier(ier),
    .lcr(lcr),
    .mcr(mcr),
    .fcr(fcr),
    .dll(dll),
    .dlh(dlh),
    .fcr_ext(fcr_ext),
    .scr(scr)
);

uart_baud_gen u_baud_gen (
    .clk(clk),
    .rst_n(rst_n),
    .baud_div_int({dlh, dll}),
    .baud_div_frac(fcr_ext[3:0]),
    .oversample_sel(fcr_ext[4]),
    .baud_tick_16x(baud_tick_16x),
    .baud_tick_8x(baud_tick_8x),
    .baud_tick(baud_tick)
);

uart_tx u_tx (
    .clk(clk),
    .rst_n(rst_n),
    .baud_tick_16x(baud_tick_16x),
    .tx_data(tx_fifo_rd_data[7:0]),
    .tx_fifo_empty(tx_fifo_empty),
    .tx_fifo_rd_en(tx_fifo_rd_en),
    .data_bits(lcr[1:0]),
    .stop_bits(lcr[2]),
    .parity_en(lcr[3]),
    .parity_even(lcr[4]),
    .cts_n(cts_n),
    .loopback_en(loopback_en),
    .tx_pause(tx_pause),
    .txd(txd),
    .tx_done(tx_done),
    .tx_busy(tx_busy)
);

uart_rx u_rx (
    .clk(clk),
    .rst_n(rst_n),
    .baud_tick_16x(baud_tick_16x),
    .baud_tick_8x(baud_tick_8x),
    .rxd(rxd_actual),
    .rx_fifo_full(rx_fifo_full),
    .rx_fifo_wr_en(rx_fifo_wr_en),
    .rx_data(rx_fifo_wr_data),
    .rx_valid(rx_valid),
    .data_bits(lcr[1:0]),
    .stop_bits(lcr[2]),
    .parity_en(lcr[3]),
    .parity_even(lcr[4]),
    .oversample_sel(fcr_ext[4]),
    .loopback_en(loopback_en),
    .frame_err(frame_err),
    .parity_err(parity_err),
    .break_detect(break_detect),
    .rx_busy(rx_busy),
    .rts_n(rts_n)
);

uart_fifo #(
    .DATA_WIDTH(10),
    .DEPTH(16)
) u_tx_fifo (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(reg_wr_en && (reg_addr == 5'h00) && !dlab),
    .wr_data({1'b0, 1'b0, reg_wr_data[7:0]}),
    .rd_en(tx_fifo_rd_en),
    .rd_data(tx_fifo_rd_data),
    .fifo_full(),
    .fifo_empty(tx_fifo_empty),
    .fifo_almost_full(),
    .fifo_count(),
    .fifo_overflow(),
    .fifo_underflow(),
    .almost_full_thresh(4'd15)
);

uart_fifo #(
    .DATA_WIDTH(11),
    .DEPTH(16)
) u_rx_fifo (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(rx_fifo_wr_en),
    .wr_data(rx_fifo_wr_data),
    .rd_en(reg_rd_en && (reg_addr == 5'h00) && !dlab),
    .rd_data(rx_fifo_rd_data),
    .fifo_full(rx_fifo_full),
    .fifo_empty(rx_fifo_empty),
    .fifo_almost_full(rx_fifo_almost_full),
    .fifo_count(),
    .fifo_overflow(overrun_err),
    .fifo_underflow(),
    .almost_full_thresh({1'b0, fcr[5:4], 1'b1})
);

uart_ctrl u_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .ier(ier),
    .tx_done(tx_done),
    .tx_fifo_empty(tx_fifo_empty),
    .rx_valid(rx_valid),
    .rx_fifo_full(rx_fifo_full),
    .rx_fifo_almost_full(rx_fifo_almost_full),
    .frame_err(frame_err),
    .parity_err(parity_err),
    .break_detect(break_detect),
    .overrun_err(overrun_err),
    .cts_n(cts_n),
    .loopback_en(loopback_en),
    .flow_ctrl_en(flow_ctrl_en),
    .fcr_rx_trig(fcr[5:4]),
    .tx_busy(tx_busy),
    .rx_busy(rx_busy),
    .irq(irq),
    .iir(),
    .lsr(),
    .msr(),
    .rts_n_out(),
    .tx_pause(tx_pause)
);

endmodule
```

### 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "顶层加个 always 没事" | 顶层禁止任何逻辑，仅连线 |
| "位置关联省事" | 必须名称关联，否则集成时易出错 |
| "Loopback 直接改 txd" | 必须通过 mux 选择，不能直接改端口 |
| "不用检查连接完整性" | 必须检查所有子模块端口连接完整 |

---

## 10. 验证要点

### 关键验证场景

| 场景 ID | 描述 | 覆盖需求 | 方法 | 优先级 |
|---------|------|----------|------|--------|
| VS-001 | 子模块连接完整性 | REQ-009 | 系统 lint | High |
| VS-002 | Loopback 模式 | REQ-010 | 功能仿真 | High |
| VS-003 | 端到端数据通路 | REQ-001 | 功能仿真 | High |
| VS-004 | APB 读写所有寄存器 | REQ-009 | 功能仿真 | High |

### SVA 断言要点
- 子模块连接：所有子模块端口无悬空
- Loopback：`loopback_en |-> rxd_actual == txd`

### 覆盖率模型

| 覆盖组 | 覆盖点 | 目标 |
|--------|--------|------|
| 子模块连接 | 所有端口连接 | 100% |
| 寄存器访问 | 所有寄存器 | 100% |

---

## 11. 风险与缓解

### 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | 子模块连接错误 | 集成 | L | 名称关联 + lint 检查 |
| R-002 | Loopback 连接遗漏 | 功能 | L | 明确 mux 选择 |

### 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | 连接覆盖不全 | 系统 lint + 端到端仿真 |

---

## 12. 架构决策记录

无。

---

## 13. 附录

### 需求追溯矩阵（RTM）

| 需求 ID | FS 章节 | 微架构章节 | 实现方式 | 验证场景 | 状态 |
|---------|---------|-----------|----------|----------|------|
| REQ-009 | FS §5.7 | §5.6 子模块实例化 | APB 接口直连 | VS-001/004 | Designed |
| REQ-010 | FS §4.2 | §5.6 Loopback 连接 | txd 内连 rxd | VS-002 | Designed |
| REQ-013 | FS §9 | §7 时钟与复位 | 单时钟域 50MHz | VS-001 | Designed |

### 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_FS_v1.0.md` | 功能规格书 |
| REF-002 | `rules/coding-style.md` | RTL 编码规范 |

### 缩略语

| 缩写 | 全称 |
|------|------|
| UART | Universal Asynchronous Receiver/Transmitter |
| APB | Advanced Peripheral Bus |
| FIFO | First In First Out |
| PPA | Performance, Power, Area |
| SVA | SystemVerilog Assertion |
