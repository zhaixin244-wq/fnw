# uart_ctrl 微架构规格书

> 基于 `uart_FS_v1.0.md` §5.6 编写。中断聚合 + 模式控制 + 流控逻辑，统一管理 UART 各子模块状态。编码规范遵循 `rules/coding-style.md`。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块/子模块** | `uart` / `uart_ctrl` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-MA-uart_ctrl-v1.0` |
| **对应 FS** | `uart_FS_v1.0.md` §5.6 |
| **作者/日期/审核** | `AI Agent` / `2026-04-27` / `{reviewer}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本 |

---

## 3. 子模块概述

### 3.1 功能定位

`uart_ctrl` 是控制模块，负责中断逻辑、模式控制和状态聚合。将各子模块的状态信号聚合为统一的中断输出，控制 Loopback 模式和流控行为。更新 LSR/MSR 状态寄存器，管理中断优先级。

**从 FS 继承的需求**：

| 需求 ID | 需求描述 | FS 章节 |
|---------|----------|---------|
| REQ-007 | 硬件流控 RTS/CTS | FS §5.6.3, §7.2 MCR.AFE |
| REQ-008 | 中断输出 | FS §5.6.3, §7.2 IER/IIR |
| REQ-010 | Loopback 自测试模式 | FS §4.2, §7.2 MCR.LOOP |

### 3.2 与上级/兄弟模块的关系

| 邻接模块 | 接口方向 | 接口名称 | 说明 |
|----------|----------|----------|------|
| uart_tx | 输入 | `tx_done`, `tx_busy` | TX 状态 |
| uart_tx | 输出 | `tx_pause` | TX 暂停信号 |
| uart_rx | 输入 | `rx_valid`, `frame_err`, `parity_err`, `break_detect`, `rx_busy` | RX 状态 |
| uart_fifo(TX) | 输入 | `tx_fifo_empty` | TX FIFO 空标志 |
| uart_fifo(RX) | 输入 | `rx_fifo_full`, `rx_fifo_almost_full` | RX FIFO 状态 |
| uart_reg_mod | 输入 | `ier`, `mcr_loop`, `mcr_afe`, `fcr_rx_trig` | 配置输入 |
| uart_reg_mod | 输出 | `iir`, `lsr`, `msr` | 状态寄存器 |
| 外部设备 | 输入 | `cts_n` | CTS 流控输入 |
| 外部设备 | 输出 | `rts_n_out` | RTS 流控输出 |
| 系统 | 输出 | `irq` | 中断输出 |

### 3.3 内部框图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 内部结构图（`wd_uart_ctrl_arch.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![uart_ctrl 内部框图](wd_uart_ctrl_arch.png)
```

> **图片说明**：本图展示 uart_ctrl 的内部架构，包含以下核心组件：
> - 中断聚合逻辑：收集所有中断源，按优先级编码为 IIR
> - 中断使能控制：根据 IER 寄存器使能/屏蔽中断源
> - LSR 聚合：收集 TX/RX 状态和错误标志，生成 LSR 寄存器
> - MSR 更新：监测 CTS 变化，生成 MSR 寄存器
> - Loopback 控制：loopback_en 时 txd 内连到 rxd
> - RTS 流控：根据 RX FIFO 状态控制 rts_n_out
> - CTS 流控：根据 cts_n 控制 tx_pause

---

## 4. 接口定义

### 4.1 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `ier` | I | 4 | wire | clk | - | 中断使能寄存器 |
| 4 | `tx_done` | I | 1 | wire | clk | - | TX 完成标志 |
| 5 | `tx_fifo_empty` | I | 1 | wire | clk | - | TX FIFO 空标志 |
| 6 | `rx_valid` | I | 1 | wire | clk | - | RX 数据有效 |
| 7 | `rx_fifo_full` | I | 1 | wire | clk | - | RX FIFO 满标志 |
| 8 | `rx_fifo_almost_full` | I | 1 | wire | clk | - | RX FIFO 接近满 |
| 9 | `frame_err` | I | 1 | wire | clk | - | 帧错误标志 |
| 10 | `parity_err` | I | 1 | wire | clk | - | 奇偶校验错误标志 |
| 11 | `break_detect` | I | 1 | wire | clk | - | Break 检测标志 |
| 12 | `overrun_err` | I | 1 | wire | clk | - | 溢出错误标志 |
| 13 | `cts_n` | I | 1 | wire | clk | - | CTS 输入 |
| 14 | `loopback_en` | I | 1 | wire | clk | - | Loopback 模式使能 |
| 15 | `flow_ctrl_en` | I | 1 | wire | clk | - | 流控使能 |
| 16 | `fcr_rx_trig` | I | 2 | wire | clk | - | RX FIFO 触发级别 |
| 17 | `tx_busy` | I | 1 | wire | clk | - | TX 忙标志 |
| 18 | `rx_busy` | I | 1 | wire | clk | - | RX 忙标志 |
| 19 | `irq` | O | 1 | reg | clk | 0 | 中断输出 |
| 20 | `iir` | O | 4 | reg | clk | 1 | 中断标识寄存器（优先级编码） |
| 21 | `lsr` | O | 8 | reg | clk | 0x60 | 线路状态寄存器 |
| 22 | `msr` | O | 8 | reg | clk | 0 | 调制解调器状态寄存器 |
| 23 | `rts_n_out` | O | 1 | reg | clk | 1 | RTS 输出（流控控制） |
| 24 | `tx_pause` | O | 1 | reg | clk | 0 | TX 暂停信号（CTS 无效时） |

**与 FS 接口映射**：

| 本模块端口 | FS 接口 | FS 信号名 | 映射说明 |
|------------|---------|-----------|----------|
| `irq` | FS §6.2 | `irq` | 直连 |
| `cts_n` | FS §6.2 | `cts_n` | 直连 |
| `rts_n_out` | FS §6.2 | `rts_n` | 直连 |
| `loopback_en` | uart_reg_mod | MCR.LOOP | 直连 |
| `flow_ctrl_en` | uart_reg_mod | MCR.AFE | 直连 |

### 4.2 接口协议与时序

**协议类型**：中断输出 + 状态寄存器

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_irq_priority.json`），编译为 PNG。

```markdown
![中断优先级时序](wd_irq_priority.png)
```

> **图片说明**：本图展示中断优先级仲裁时序：
> - 中断源按优先级排列：OE > BI > FE > PE > RxAvailable > TxEmpty > RTOI
> - irq 在任一使能的中断源有效时拉高
> - IIR 编码反映当前最高优先级中断源
> - 软件读 IIR 后，当前中断清除，下一优先级中断（如有）立即生效

**中断优先级**：

| 优先级 | 中断源 | IIR 编码 | 类型 | 清除条件 |
|--------|--------|----------|------|----------|
| 1（最高） | OE 溢出错误 | 4'b0110 | 错误 | 读 LSR |
| 2 | BI Break 检测 | 4'b0100 | 错误 | 读 LSR |
| 3 | FE 帧错误 | 4'b0100 | 错误 | 读 LSR |
| 4 | PE 奇偶校验错误 | 4'b0100 | 错误 | 读 LSR |
| 5 | RxAvailable | 4'b0100 | 数据就绪 | 读 RBR 或 FIFO 低于触发级别 |
| 6 | TxEmpty | 4'b0010 | 发送就绪 | 写 THR 或 读 IIR |
| 7（最低） | RTOI 接收超时 | 4'b0110 | 超时 | 读 RBR |

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| 中断响应延迟 | 1 | cycle | 中断源有效到 irq 输出 |
| IIR 更新延迟 | 1 | cycle | 中断源变化到 IIR 更新 |
| LSR 更新延迟 | 1 | cycle | 状态变化到 LSR 更新 |

---

## 5. 微架构设计

### 5.1 数据通路

#### 数据流图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 数据通路图（`wd_uart_ctrl_datapath.d2`），从输入到输出的完整路径。

```markdown
![uart_ctrl 数据通路](wd_uart_ctrl_datapath.png)
```

> **图片说明**：本图展示 uart_ctrl 的数据通路，分为中断路径和状态路径：
> - 中断路径：各中断源 → IER 使能 → 优先级编码 → IIR → irq 输出
> - 状态路径：TX/RX 状态 → LSR 聚合 → lsr 输出
> - 流控路径：RX FIFO 状态 → RTS 控制 → rts_n_out 输出
> - 模式路径：loopback_en → txd/rxd 内连控制

#### 各阶段数据格式

| 阶段 | 数据名 | 位宽 | 格式说明 | 组合/时序 |
|------|--------|------|----------|-----------|
| 中断源 | `int_pending` | 7 | 7 个中断源挂起状态 | 组合 |
| 使能 | `int_enabled` | 7 | 使能后的中断源 | 组合 |
| 编码 | `iir` | 4 | 中断标识编码 | 时序 |
| 输出 | `irq` | 1 | 中断输出 | 时序 |

#### 关键数据路径

| 路径 ID | 起点 | 终点 | 组合逻辑级数 | 预估延迟 | 关键路径 |
|---------|------|------|-------------|----------|----------|
| DP-001 | 中断源 | `irq` | 3 级 | 0.6 ns | 是 |
| DP-002 | 状态信号 | `lsr` | 2 级 | 0.4 ns | 否 |
| DP-003 | `rx_fifo_almost_full` | `rts_n_out` | 1 级 | 0.2 ns | 否 |

---

### 5.2 控制逻辑

#### 控制信号列表

| 控制信号 | 位宽 | 产生源 | 功能描述 |
|----------|------|--------|----------|
| `int_pending` | 7 | 组合逻辑 | 中断源挂起状态 |
| `int_enabled` | 7 | 组合逻辑 | 使能后的中断源 |
| `iir` | 4 | 优先级编码 | 中断标识寄存器 |
| `irq` | 1 | 组合逻辑 | 中断输出 |
| `lsr` | 8 | 状态聚合 | 线路状态寄存器 |
| `msr` | 8 | 状态聚合 | 调制解调器状态寄存器 |
| `rts_n_out` | 1 | 流控逻辑 | RTS 输出 |
| `tx_pause` | 1 | 流控逻辑 | TX 暂停信号 |

#### 中断源定义

| 中断源 | 条件 | IER 位 | 优先级 |
|--------|------|--------|--------|
| OE | overrun_err | IER[2] (ELSI) | 1 |
| BI | break_detect | IER[2] (ELSI) | 2 |
| FE | frame_err | IER[2] (ELSI) | 3 |
| PE | parity_err | IER[2] (ELSI) | 4 |
| RxAvailable | rx_valid && (fifo_count >= trigger_level) | IER[0] (ERBFI) | 5 |
| TxEmpty | tx_fifo_empty | IER[1] (ETBEI) | 6 |
| RTOI | rx_timeout (4 char time) | IER[0] (ERBFI) | 7 |

#### LSR 位域定义

| Bit | 名称 | 来源 | 说明 |
|-----|------|------|------|
| [0] | DR | rx_fifo !empty | 数据就绪 |
| [1] | OE | overrun_err | 溢出错误 |
| [2] | PE | parity_err | 奇偶校验错误 |
| [3] | FE | frame_err | 帧错误 |
| [4] | BI | break_detect | Break 检测 |
| [5] | THRE | tx_fifo_empty | 发送保持寄存器空 |
| [6] | TEMT | tx_fifo_empty && !tx_busy | 发送器空 |
| [7] | RX_FIFO_ERR | rx_fifo 中有错误数据 | RX FIFO 错误 |

#### MSR 位域定义

| Bit | 名称 | 来源 | 说明 |
|-----|------|------|------|
| [0] | DCTS | cts_n 变化检测 | CTS 变化标志 |
| [4] | CTS | cts_n 取反 | CTS 当前状态 |

#### 流控机制

| 类型 | 接口 | 机制 | 背压路径 |
|------|------|------|----------|
| RTS 控制 | 输出 | rts_n_out | RX FIFO 接近满 → rts_n_out 拉高 → 外部设备停止 |
| CTS 监测 | 输入 | cts_n | cts_n 拉高 → tx_pause 拉高 → uart_tx 暂停 |

**背压传播规则**：
- RTS 由 RX FIFO 剩余空间决定，`flow_ctrl_en` 使能时生效
- CTS 直接控制 TX 暂停，`flow_ctrl_en` 使能时生效
- 两者独立，互不影响

---

### 5.3 状态机设计

本子模块无状态机设计。控制模块为纯组合+寄存器逻辑，无状态转移。

---

### 5.4 流水线设计

本子模块无流水线设计。

---

### 5.5 FIFO / 缓冲设计

本子模块无 FIFO 设计。

---

### 5.6 IP/CBB 集成设计

本子模块无 IP/CBB 集成。

---

## 6. 关键时序分析

### 关键路径

| 路径 ID | 起点 | 组合逻辑 | 级数 | 预估延迟 |
|---------|------|----------|------|----------|
| CP-001 | 中断源寄存器 | 优先级编码 + irq | 3 级 | 0.6 ns |
| CP-002 | 状态信号 | LSR 聚合 | 2 级 | 0.4 ns |

### 时序裕量

**裕量公式**：`Tslack = Tclk - Tcq - Tlogic - Tsetup - Tskew`

| 路径 | Tclk | Tlogic | Tslack | 是否满足 |
|------|------|--------|--------|----------|
| CP-001 | 20ns (50MHz) | 0.6ns | **18.9ns** | 是 |
| CP-002 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |

判断：所有路径 Tslack > 0，满足时序要求。

### SDC 约束建议
```tcl
create_clock -name clk -period 20 [get_ports clk]
set_input_delay  -clock clk -max 5 [get_ports {ier tx_done tx_fifo_empty rx_valid rx_fifo_full rx_fifo_almost_full frame_err parity_err break_detect overrun_err cts_n loopback_en flow_ctrl_en fcr_rx_trig tx_busy rx_busy}]
set_output_delay -clock clk -max 5 [get_ports {irq iir lsr msr rts_n_out tx_pause}]
set_false_path   -from [get_ports rst_n]
```

---

## 7. 时钟与复位

### 时钟域归属

| 信号 | 时钟域 | 说明 |
|------|--------|------|
| 所有信号 | clk | 主时钟域，无跨时钟域信号 |

### 复位策略

异步复位同步释放，低有效 `rst_n`，2 级同步器。

复位时：
- irq = 0
- iir = 4'b0001（无中断）
- lsr = 8'h60（THRE=1, TEMT=1）
- msr = 0
- rts_n_out = 1（无效）
- tx_pause = 0
- cts_prev = 1

### CDC 处理

本子模块无 CDC 信号，所有信号在同一时钟域内。

---

## 8. PPA 预估

### 逻辑面积

| 组成 | 预估(kGates) | 计算依据 |
|------|-------------|----------|
| 中断逻辑 | 0.3 | 7 个中断源 + 优先级编码 |
| LSR 聚合 | 0.2 | 8 bit 状态聚合 |
| MSR 更新 | 0.1 | CTS 变化检测 |
| 流控逻辑 | 0.2 | RTS/CTS 控制 |
| 控制逻辑 | 0.2 | Loopback + 触发级别 |
| **合计** | **1.0** | |

### 功耗预估（PVT：`TT` / `1.0V` / `25°C` / `50MHz`）

| 指标 | 预估 | 单位 | 依据 |
|------|------|------|------|
| 动态功耗 | 0.3 | mW | α×C×V²×f，低翻转率 |
| 静态功耗 | 0.1 | mW | 漏电×V |
| **合计** | **0.4** | **mW** | |

### 关键路径 Fmax

| 路径 | 延迟 | Fmax |
|------|------|------|
| **最差路径** | 0.6 ns | ≥ 300 MHz |

---

## 9. RTL 实现指导

### 文件结构
```
uart_ctrl.v              — 主模块 RTL
uart_ctrl_sva.sv         — SVA 断言
uart_ctrl_tb.v           — 仿真 testbench
```

### 参数化
- 中断优先级固定，不参数化
- RTS/CTS 流控由 `flow_ctrl_en` 使能

### 编码规范

遵循 `rules/coding-style.md`。本子模块在 RTL 实现阶段需特别关注以下高风险项：

| 高风险项 | 关注点 |
|----------|--------|
| 组合逻辑 latch 防护 | always @(*) 输出默认值、if 补 else、case 有 default |
| 中断优先级 | 优先级编码必须正确，OE 最高 |
| LSR 更新 | 状态变化后 LSR 必须立即更新 |
| 流控时序 | RTS/CTS 控制必须正确，防止数据丢失 |

### RTL 伪代码框架

```verilog
module uart_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    // 配置输入
    input  wire [3:0] ier,
    input  wire       loopback_en,
    input  wire       flow_ctrl_en,
    input  wire [1:0] fcr_rx_trig,
    // TX 状态
    input  wire       tx_done,
    input  wire       tx_fifo_empty,
    input  wire       tx_busy,
    // RX 状态
    input  wire       rx_valid,
    input  wire       rx_fifo_full,
    input  wire       rx_fifo_almost_full,
    input  wire       frame_err,
    input  wire       parity_err,
    input  wire       break_detect,
    input  wire       overrun_err,
    input  wire       rx_busy,
    // 流控
    input  wire       cts_n,
    // 输出
    output reg        irq,
    output reg  [3:0] iir,
    output reg  [7:0] lsr,
    output reg  [7:0] msr,
    output reg        rts_n_out,
    output reg        tx_pause
);

// 中断源挂起
wire int_oe = overrun_err;
wire int_bi = break_detect;
wire int_fe = frame_err;
wire int_pe = parity_err;
wire int_rx = rx_valid;
wire int_tx = tx_fifo_empty;
wire int_rto = 0; // TODO: 接收超时检测

// 中断使能
wire int_oe_en  = ier[2] && int_oe;
wire int_bi_en  = ier[2] && int_bi;
wire int_fe_en  = ier[2] && int_fe;
wire int_pe_en  = ier[2] && int_pe;
wire int_rx_en  = ier[0] && int_rx;
wire int_tx_en  = ier[1] && int_tx;
wire int_rto_en = ier[0] && int_rto;

// 任意中断
wire any_int = int_oe_en || int_bi_en || int_fe_en || int_pe_en ||
               int_rx_en || int_tx_en || int_rto_en;

// 优先级编码
always @(*) begin
    iir = 4'b0001; // 无中断
    if (int_oe_en)       iir = 4'b0110; // 优先级 1
    else if (int_bi_en)  iir = 4'b0100; // 优先级 2
    else if (int_fe_en)  iir = 4'b0100; // 优先级 3
    else if (int_pe_en)  iir = 4'b0100; // 优先级 4
    else if (int_rx_en)  iir = 4'b0100; // 优先级 5
    else if (int_tx_en)  iir = 4'b0010; // 优先级 6
    else if (int_rto_en) iir = 4'b0110; // 优先级 7
end

// irq 输出
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) irq <= 0;
    else        irq <= any_int;
end

// LSR 聚合
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) lsr <= 8'h60;
    else begin
        lsr[0] <= !rx_fifo_empty;                    // DR
        lsr[1] <= overrun_err;                        // OE
        lsr[2] <= parity_err;                         // PE
        lsr[3] <= frame_err;                          // FE
        lsr[4] <= break_detect;                       // BI
        lsr[5] <= tx_fifo_empty;                      // THRE
        lsr[6] <= tx_fifo_empty && !tx_busy;          // TEMT
        lsr[7] <= 0;                                  // RX_FIFO_ERR
    end
end

// MSR 更新
reg cts_prev;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        msr     <= 0;
        cts_prev <= 1;
    end else begin
        cts_prev <= cts_n;
        msr[0] <= (cts_n != cts_prev);  // DCTS
        msr[4] <= !cts_n;               // CTS
    end
end

// RTS 流控
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) rts_n_out <= 1;
    else if (flow_ctrl_en) rts_n_out <= !rx_fifo_almost_full;
    else rts_n_out <= 1;
end

// CTS 流控
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) tx_pause <= 0;
    else if (flow_ctrl_en) tx_pause <= cts_n; // cts_n 高时暂停
    else tx_pause <= 0;
end

endmodule
```

### 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "中断优先级随便排" | 必须按 16550 规范排列，OE 最高 |
| "LSR 不用实时更新" | 必须实时更新，软件依赖 LSR 判断状态 |
| "RTS/CTS 不用特殊处理" | 流控必须正确实现，否则数据丢失 |
| "MSR 变化检测无所谓" | DCTS 标志必须检测，软件需要知道 CTS 变化 |

---

## 10. 验证要点

### 关键验证场景

| 场景 ID | 描述 | 覆盖需求 | 方法 | 优先级 |
|---------|------|----------|------|--------|
| VS-001 | 中断优先级 | REQ-008 | 功能仿真 | High |
| VS-002 | 中断使能/屏蔽 | REQ-008 | 功能仿真 | High |
| VS-003 | LSR 状态更新 | REQ-008 | 功能仿真 | High |
| VS-004 | RTS 流控 | REQ-007 | 功能仿真 | High |
| VS-005 | CTS 流控 | REQ-007 | 功能仿真 | High |
| VS-006 | Loopback 模式 | REQ-010 | 功能仿真 | Medium |
| VS-007 | MSR 变化检测 | REQ-007 | 功能仿真 | Medium |

### SVA 断言要点
- 中断优先级：`int_oe_en |-> iir == 4'b0110`
- irq 与中断源：`any_int |-> irq`
- LSR 更新：`overrun_err |=> lsr[1]`
- RTS 流控：`flow_ctrl_en && rx_fifo_almost_full |=> !rts_n_out`

### 覆盖率模型

| 覆盖组 | 覆盖点 | 目标 |
|--------|--------|------|
| 中断源 | 所有 7 个中断源 | 100% |
| 优先级 | 所有优先级组合 | 100% |
| 流控 | RTS/CTS 有效/无效 | 100% |
| 模式 | 正常/Loopback | 100% |

---

## 11. 风险与缓解

### 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | 中断优先级错误 | 功能 | L | 严格按 16550 规范实现 |
| R-002 | LSR 更新延迟 | 功能 | L | 组合逻辑实时更新 |
| R-003 | 流控时序错误 | 功能 | L | 在时钟边沿更新 RTS/CTS |

### 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | 中断组合覆盖不全 | 遍历所有中断源组合 |

---

## 12. 架构决策记录

无。

---

## 13. 附录

### 需求追溯矩阵（RTM）

| 需求 ID | FS 章节 | 微架构章节 | 实现方式 | 验证场景 | 状态 |
|---------|---------|-----------|----------|----------|------|
| REQ-007 | FS §5.6.3 | §5.2 流控机制 | RTS/CTS 控制 | VS-004/005 | Designed |
| REQ-008 | FS §5.6.3 | §5.1 数据通路 | 中断优先级编码 | VS-001/002 | Designed |
| REQ-010 | FS §4.2 | §5.2 控制逻辑 | loopback_en 控制 | VS-006 | Designed |

### 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_FS_v1.0.md` | 功能规格书 |
| REF-002 | `rules/coding-style.md` | RTL 编码规范 |

### 缩略语

| 缩写 | 全称 |
|------|------|
| UART | Universal Asynchronous Receiver/Transmitter |
| IER | Interrupt Enable Register |
| IIR | Interrupt Identification Register |
| LSR | Line Status Register |
| MSR | Modem Status Register |
| RTS | Request To Send |
| CTS | Clear To Send |
| PPA | Performance, Power, Area |
| SVA | SystemVerilog Assertion |
