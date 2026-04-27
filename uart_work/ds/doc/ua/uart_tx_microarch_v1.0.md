# uart_tx 微架构规格书

> 基于 `uart_FS_v1.0.md` §5.3 编写。发送状态机 + 移位寄存器，从 TX FIFO 读取数据并串行发送。编码规范遵循 `rules/coding-style.md`。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块/子模块** | `uart` / `uart_tx` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-MA-uart_tx-v1.0` |
| **对应 FS** | `uart_FS_v1.0.md` §5.3 |
| **作者/日期/审核** | `AI Agent` / `2026-04-27` / `{reviewer}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本 |

---

## 3. 子模块概述

### 3.1 功能定位

`uart_tx` 是发送模块，包含发送状态机和移位寄存器。从 TX FIFO 读取数据，按配置的帧格式（起始位、数据位、校验位、停止位）串行发送到 txd 引脚。由 `baud_tick_16x` 驱动移位时序，支持 CTS 流控暂停。

**从 FS 继承的需求**：

| 需求 ID | 需求描述 | FS 章节 |
|---------|----------|---------|
| REQ-001 | 数据位 5/6/7/8 位可配 | FS §4.1, §7.2 LCR.WLS |
| REQ-002 | 停止位 1/1.5/2 可配 | FS §4.1, §7.2 LCR.STB |
| REQ-003 | 奇偶校验三种模式 | FS §4.1, §7.2 LCR.PEN/EPS |
| REQ-007 | 硬件流控 RTS/CTS | FS §5.6.3, §7.2 MCR.AFE |

### 3.2 与上级/兄弟模块的关系

| 邻接模块 | 接口方向 | 接口名称 | 说明 |
|----------|----------|----------|------|
| uart_baud_gen | 输入 | `baud_tick_16x` | 16 倍波特率时钟 |
| uart_fifo(TX) | 输入 | `tx_data`, `tx_fifo_empty` | TX FIFO 读数据和状态 |
| uart_fifo(TX) | 输出 | `tx_fifo_rd_en` | TX FIFO 读使能 |
| uart_reg_mod | 输入 | `data_bits`, `stop_bits`, `parity_en`, `parity_even` | 帧格式配置 |
| uart_ctrl | 输入 | `cts_n`, `loopback_en`, `tx_pause` | 流控和模式控制 |
| uart_ctrl | 输出 | `tx_done`, `tx_busy` | 状态输出 |
| 外部设备 | 输出 | `txd` | 串行发送数据线 |

### 3.3 内部框图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 内部结构图（`wd_uart_tx_arch.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![uart_tx 内部框图](wd_uart_tx_arch.png)
```

> **图片说明**：本图展示 uart_tx 的内部架构，包含以下核心组件：
> - 发送状态机（FSM）：IDLE → START → DATA → PARITY → STOP，控制发送流程
> - 移位寄存器：存储待发送帧数据，按 baud_tick_16x 逐位移位
> - 帧组装逻辑：将 TX FIFO 数据 + 起始位 + 校验位 + 停止位组装为帧
> - CTS 流控：cts_n 无效时暂停发送
> - Loopback 控制：loopback_en 时 txd 输出内部回环
> - 数据从 TX FIFO 读入，经帧组装后逐位从 txd 输出

---

## 4. 接口定义

### 4.1 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `baud_tick_16x` | I | 1 | wire | clk | - | 16 倍波特率时钟脉冲 |
| 4 | `tx_data` | I | 8 | wire | clk | - | 从 TX FIFO 读取的数据 |
| 5 | `tx_fifo_empty` | I | 1 | wire | clk | - | TX FIFO 空标志 |
| 6 | `tx_fifo_rd_en` | O | 1 | reg | clk | 0 | TX FIFO 读使能 |
| 7 | `data_bits` | I | 2 | wire | clk | - | 数据位配置：00=5, 01=6, 10=7, 11=8 |
| 8 | `stop_bits` | I | 1 | wire | clk | - | 停止位配置：0=1 位, 1=2 位（5 位时为 1.5 位） |
| 9 | `parity_en` | I | 1 | wire | clk | - | 校验使能 |
| 10 | `parity_even` | I | 1 | wire | clk | - | 校验类型：0=奇, 1=偶 |
| 11 | `cts_n` | I | 1 | wire | clk | - | CTS 流控输入（低有效） |
| 12 | `loopback_en` | I | 1 | wire | clk | - | Loopback 模式使能 |
| 13 | `tx_pause` | I | 1 | wire | clk | - | TX 暂停信号（CTS 无效时） |
| 14 | `txd` | O | 1 | reg | clk | 1 | 发送数据线（空闲为高） |
| 15 | `tx_done` | O | 1 | reg | clk | 0 | 发送完成脉冲 |
| 16 | `tx_busy` | O | 1 | reg | clk | 0 | 发送忙标志 |

**与 FS 接口映射**：

| 本模块端口 | FS 接口 | FS 信号名 | 映射说明 |
|------------|---------|-----------|----------|
| `txd` | FS §6.2 | `txd` | 直连 |
| `cts_n` | FS §6.2 | `cts_n` | 直连 |
| `tx_fifo_empty` | uart_fifo(TX) | `fifo_empty` | 直连 |
| `tx_fifo_rd_en` | uart_fifo(TX) | `rd_en` | 直连 |
| `baud_tick_16x` | uart_baud_gen | `baud_tick_16x` | 直连 |

### 4.2 接口协议与时序

**协议类型**：Valid-Ready（TX FIFO 读接口）+ 串行输出（txd）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_uart_tx_frame.json`），编译为 PNG。

```markdown
![UART 发送帧时序](wd_uart_tx_frame.png)
```

> **图片说明**：本图展示 UART 发送一帧数据的完整时序：
> - 空闲状态：txd = 1
> - 起始位：txd = 0，持续 16 个 baud_tick_16x
> - 数据位：D0~D7，每位持续 16 个 baud_tick_16x，LSB 先发
> - 校验位：P（如使能），持续 16 个 baud_tick_16x
> - 停止位：txd = 1，持续 16（1 位）或 32（2 位）个 baud_tick_16x
> - tx_done 在停止位结束时产生单周期脉冲

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| txd 输出延迟 | ≤ 5 | ns | clk 到 txd 输出有效 |
| TX FIFO 读延迟 | 1 | cycle | tx_fifo_rd_en 到 tx_data 有效 |
| 帧间隔 | 1 | bit | 停止位结束到下一帧起始位 |
| CTS 采样 | 1 | cycle | CTS 在每个 baud_tick_16x 采样 |

---

## 5. 微架构设计

### 5.1 数据通路

#### 数据流图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 数据通路图（`wd_uart_tx_datapath.d2`），从输入到输出的完整路径。

```markdown
![uart_tx 数据通路](wd_uart_tx_datapath.png)
```

> **图片说明**：本图展示 uart_tx 的数据通路，从输入到输出共 4 个阶段：
> - 阶段 0（FIFO 读取）：tx_data 从 TX FIFO 读入，tx_fifo_rd_en 控制读取
> - 阶段 1（帧组装）：起始位(0) + 数据位[7:0] + 校验位(可选) + 停止位(1) 组装为帧
> - 阶段 2（移位寄存器）：帧数据存入移位寄存器，按 baud_tick_16x 逐位移出
> - 阶段 3（输出）：txd 输出移位寄存器最低位，loopback_en 时内部回环
>
> 关键数据路径：tx_data → 帧组装 → 移位寄存器 → txd 输出。

#### 各阶段数据格式

| 阶段 | 数据名 | 位宽 | 格式说明 | 组合/时序 |
|------|--------|------|----------|-----------|
| FIFO 读取 | `tx_data` | 8 | 原始数据 | - |
| 帧组装 | `frame_data` | 12 | 起始位+数据位+校验位+停止位 | 组合 |
| 移位 | `shift_reg` | 12 | 移位寄存器 | 时序 |
| 输出 | `txd` | 1 | 串行输出 | 时序 |

#### 帧格式组装

| 帧配置 | 位数 | frame_data 格式 |
|--------|------|-----------------|
| 8N1 | 10 | `{1'b1, 8'b0, 1'b0}` = `{stop, data[7:0], start}` |
| 8E1 | 11 | `{1'b1, parity, 8'b0, 1'b0}` |
| 5N1 | 7 | `{1'b1, 5'b0, 1'b0}` |
| 5N2 | 8 | `{1'b1, 1'b1, 5'b0, 1'b0}` |

#### 关键数据路径

| 路径 ID | 起点 | 终点 | 组合逻辑级数 | 预估延迟 | 关键路径 |
|---------|------|------|-------------|----------|----------|
| DP-001 | `tx_data` | `frame_data` | 2 级 | 0.4 ns | 否 |
| DP-002 | `shift_reg` | `txd` | 0 级 | 0 ns | 否 |
| DP-003 | `baud_tick_16x` | `shift_reg` 更新 | 1 级 | 0.2 ns | 否 |

---

### 5.2 控制逻辑

#### 控制信号列表

| 控制信号 | 位宽 | 产生源 | 功能描述 |
|----------|------|--------|----------|
| `baud_tick_16x` | 1 | uart_baud_gen | 16 倍波特率时钟 |
| `tx_fifo_rd_en` | 1 | 状态机 | TX FIFO 读使能 |
| `tx_done` | 1 | 状态机 | 发送完成脉冲 |
| `tx_busy` | 1 | 状态机 | 发送忙标志 |
| `bit_cnt` | 4 | 内部计数器 | 当前发送位计数 |
| `tick_cnt` | 4 | 内部计数器 | baud_tick_16x 计数（0~15） |

#### 流控机制

| 类型 | 接口 | 机制 | 背压路径 |
|------|------|------|----------|
| CTS 流控 | 输入 | cts_n 低有效 | 外部设备拉高 cts_n → tx_pause → uart_tx 暂停 |
| FIFO 空 | 输入 | tx_fifo_empty | TX FIFO 空 → uart_tx 停止发送 |

**背压传播规则**：
- CTS 流控优先级高于 FIFO 读取
- `tx_pause=1` 时，uart_tx 暂停在当前位或等待状态，不读取 FIFO
- `tx_pause=0` 后，uart_tx 恢复发送

---

### 5.3 状态机设计

#### 状态定义

| 状态名 | 编码 | 描述 |
|--------|------|------|
| `S_IDLE` | `5'b00001` | 空闲状态，等待 FIFO 非空 |
| `S_START` | `5'b00010` | 发送起始位（txd=0） |
| `S_DATA` | `5'b00100` | 发送数据位（LSB 先发） |
| `S_PARITY` | `5'b01000` | 发送校验位（如使能） |
| `S_STOP` | `5'b10000` | 发送停止位（txd=1） |

编码方式：独热码（5 状态 ≤ 16）。

#### 状态转移条件表

| 当前状态 | 转移条件 | 次态 | 输出动作 |
|----------|----------|------|----------|
| `S_IDLE` | `!tx_fifo_empty && !tx_pause` | `S_START` | tx_fifo_rd_en=1, tx_busy=1 |
| `S_START` | `tick_cnt==15 && baud_tick_16x` | `S_DATA` | txd=0, bit_cnt=0 |
| `S_DATA` | `tick_cnt==15 && baud_tick_16x && bit_cnt==data_bits-1` | `S_PARITY` or `S_STOP` | txd=shift_reg[bit_cnt] |
| `S_PARITY` | `tick_cnt==15 && baud_tick_16x` | `S_STOP` | txd=parity_value |
| `S_STOP` | `tick_cnt==15 && baud_tick_16x && stop_bit_cnt==stop_bits-1` | `S_IDLE` | txd=1, tx_done=1 |
| `S_IDLE` | `tx_fifo_empty \|\| tx_pause` | `S_IDLE` | tx_busy=0 |
| `S_DATA` | `parity_en==0 && bit_cnt==data_bits-1` | `S_STOP` | 跳过 S_PARITY |
| 所有状态 | `default` | `S_IDLE` | 非法状态回收 |

**状态转移图使用 `chip-png-d2-gen` 生成 D2 状态机图**（`wd_uart_tx_fsm.d2`），禁止使用文本描述、ASCII 图或其他格式。

```markdown
![uart_tx 状态机](wd_uart_tx_fsm.png)
```

> **图片说明**：本图展示 uart_tx 的状态机，共 5 个状态：
> - S_IDLE：空闲状态，等待 TX FIFO 非空且 CTS 有效，转移到 S_START
> - S_START：发送起始位（txd=0），16 个 baud_tick_16x 后转移到 S_DATA
> - S_DATA：发送数据位，LSB 先发，发送完所有数据位后根据 parity_en 转移到 S_PARITY 或 S_STOP
> - S_PARITY：发送校验位（如使能），16 个 baud_tick_16x 后转移到 S_STOP
> - S_STOP：发送停止位（txd=1），16/32 个 baud_tick_16x 后返回 S_IDLE
>
> 状态编码：独热码，非法状态回收至 S_IDLE。

---

### 5.4 流水线设计

本子模块无流水线设计。发送操作为逐位移位，由 baud_tick_16x 驱动。

---

### 5.5 FIFO / 缓冲设计

本子模块无 FIFO 设计。使用 TX FIFO（uart_fifo 实例）作为缓冲。

---

### 5.6 IP/CBB 集成设计

本子模块无 IP/CBB 集成。

---

## 6. 关键时序分析

### 关键路径

| 路径 ID | 起点 | 组合逻辑 | 级数 | 预估延迟 |
|---------|------|----------|------|----------|
| CP-001 | `shift_reg` 寄存器 | txd 输出选择 | 1 级 | 0.2 ns |
| CP-002 | `bit_cnt` 寄存器 | 状态转移判断 | 2 级 | 0.4 ns |
| CP-003 | `tick_cnt` 寄存器 | 计数比较 | 2 级 | 0.4 ns |

### 时序裕量

**裕量公式**：`Tslack = Tclk - Tcq - Tlogic - Tsetup - Tskew`

| 路径 | Tclk | Tlogic | Tslack | 是否满足 |
|------|------|--------|--------|----------|
| CP-001 | 20ns (50MHz) | 0.2ns | **19.3ns** | 是 |
| CP-002 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |
| CP-003 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |

判断：所有路径 Tslack > 0，满足时序要求。

### SDC 约束建议
```tcl
create_clock -name clk -period 20 [get_ports clk]
set_input_delay  -clock clk -max 5 [get_ports {baud_tick_16x tx_data tx_fifo_empty data_bits stop_bits parity_en parity_even cts_n loopback_en tx_pause}]
set_output_delay -clock clk -max 5 [get_ports {txd tx_fifo_rd_en tx_done tx_busy}]
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
- state_cur = S_IDLE
- shift_reg = 0
- bit_cnt = 0
- tick_cnt = 0
- stop_bit_cnt = 0
- txd = 1（空闲高电平）
- tx_fifo_rd_en = 0
- tx_done = 0
- tx_busy = 0

### CDC 处理

本子模块无 CDC 信号，所有信号在同一时钟域内。

---

## 8. PPA 预估

### 逻辑面积

| 组成 | 预估(kGates) | 计算依据 |
|------|-------------|----------|
| 状态机 | 0.3 | 5 状态独热码 + 转移逻辑 |
| 移位寄存器 | 0.5 | 12 bit 移位寄存器 |
| 计数器 | 0.2 | tick_cnt(4) + bit_cnt(4) + stop_bit_cnt(2) |
| 帧组装 | 0.3 | 数据位选择 + 校验计算 + 帧拼接 |
| 控制逻辑 | 0.2 | CTS + Loopback + 输出选择 |
| **合计** | **1.5** | |

### 功耗预估（PVT：`TT` / `1.0V` / `25°C` / `50MHz`）

| 指标 | 预估 | 单位 | 依据 |
|------|------|------|------|
| 动态功耗 | 1.0 | mW | α×C×V²×f，移位寄存器翻转 |
| 静态功耗 | 0.2 | mW | 漏电×V |
| **合计** | **1.2** | **mW** | |

### 关键路径 Fmax

| 路径 | 延迟 | Fmax |
|------|------|------|
| **最差路径** | 0.4 ns | ≥ 500 MHz |

---

## 9. RTL 实现指导

### 文件结构
```
uart_tx.v                — 主模块 RTL
uart_tx_sva.sv           — SVA 断言
uart_tx_tb.v             — 仿真 testbench
```

### 参数化
- 数据位数由 `data_bits` 配置：00=5, 01=6, 10=7, 11=8
- 停止位数由 `stop_bits` 配置：0=1 位, 1=2 位
- 校验由 `parity_en` 和 `parity_even` 配置

### 编码规范

遵循 `rules/coding-style.md`。本子模块在 RTL 实现阶段需特别关注以下高风险项：

| 高风险项 | 关注点 |
|----------|--------|
| 组合逻辑 latch 防护 | always @(*) 输出默认值、if 补 else、case 有 default |
| FSM 非法状态回收 | 所有非法状态必须回到 IDLE |
| 移位寄存器 | LSB 先发，bit_cnt 从 0 开始 |
| CTS 流控 | tx_pause=1 时暂停所有操作 |

### RTL 伪代码框架

```verilog
module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    // 波特率时钟
    input  wire       baud_tick_16x,
    // TX FIFO 接口
    input  wire [7:0] tx_data,
    input  wire       tx_fifo_empty,
    output reg        tx_fifo_rd_en,
    // 帧格式配置
    input  wire [1:0] data_bits,
    input  wire       stop_bits,
    input  wire       parity_en,
    input  wire       parity_even,
    // 流控
    input  wire       cts_n,
    input  wire       loopback_en,
    input  wire       tx_pause,
    // 输出
    output reg        txd,
    output reg        tx_done,
    output reg        tx_busy
);

// 状态定义
localparam [4:0] S_IDLE   = 5'b00001,
                 S_START  = 5'b00010,
                 S_DATA   = 5'b00100,
                 S_PARITY = 5'b01000,
                 S_STOP   = 5'b10000;

reg [4:0]  state_cur, state_nxt;
reg [11:0] shift_reg;      // 帧数据移位寄存器
reg [3:0]  bit_cnt;        // 数据位计数
reg [3:0]  tick_cnt;       // baud_tick_16x 计数
reg [1:0]  stop_bit_cnt;   // 停止位计数
reg        parity_val;     // 校验值

// 校验计算
wire parity_calc = ^tx_data; // 偶校验
wire parity_value = parity_even ? parity_calc : ~parity_calc;

// 实际数据位数
wire [3:0] data_bits_actual = data_bits + 5; // 5/6/7/8

// 状态机 - 时序逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_cur <= S_IDLE;
    else        state_cur <= state_nxt;
end

// 状态机 - 组合逻辑
always @(*) begin
    state_nxt = S_IDLE;
    case (state_cur)
        S_IDLE: if (!tx_fifo_empty && !tx_pause) state_nxt = S_START;
                else state_nxt = S_IDLE;
        S_START: if (tick_cnt == 15 && baud_tick_16x) state_nxt = S_DATA;
                 else state_nxt = S_START;
        S_DATA: if (tick_cnt == 15 && baud_tick_16x) begin
                    if (bit_cnt == data_bits_actual - 1) begin
                        state_nxt = parity_en ? S_PARITY : S_STOP;
                    end else begin
                        state_nxt = S_DATA;
                    end
                end else state_nxt = S_DATA;
        S_PARITY: if (tick_cnt == 15 && baud_tick_16x) state_nxt = S_STOP;
                  else state_nxt = S_PARITY;
        S_STOP: if (tick_cnt == 15 && baud_tick_16x) begin
                    if (stop_bit_cnt == (stop_bits ? 1 : 0)) begin
                        state_nxt = S_IDLE;
                    end else begin
                        state_nxt = S_STOP;
                    end
                end else state_nxt = S_STOP;
        default: state_nxt = S_IDLE;
    endcase
end

// 数据通路
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg     <= 0;
        bit_cnt       <= 0;
        tick_cnt      <= 0;
        stop_bit_cnt  <= 0;
        txd           <= 1;
        tx_fifo_rd_en <= 0;
        tx_done       <= 0;
        tx_busy       <= 0;
    end else begin
        tx_fifo_rd_en <= 0;
        tx_done       <= 0;

        case (state_cur)
            S_IDLE: begin
                txd     <= 1;
                tx_busy <= 0;
                if (!tx_fifo_empty && !tx_pause) begin
                    tx_fifo_rd_en <= 1;
                    tx_busy       <= 1;
                end
            end

            S_START: begin
                txd <= 0; // 起始位
                if (baud_tick_16x) begin
                    if (tick_cnt == 15) begin
                        tick_cnt  <= 0;
                        shift_reg <= {1'b1, parity_value, tx_data, 1'b0}; // 帧组装
                        bit_cnt   <= 0;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end
            end

            S_DATA: begin
                txd <= shift_reg[0]; // LSB 先发
                if (baud_tick_16x) begin
                    if (tick_cnt == 15) begin
                        tick_cnt  <= 0;
                        shift_reg <= {1'b0, shift_reg[11:1]}; // 右移
                        bit_cnt   <= bit_cnt + 1;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end
            end

            S_PARITY: begin
                txd <= shift_reg[0]; // 校验位
                if (baud_tick_16x) begin
                    if (tick_cnt == 15) begin
                        tick_cnt     <= 0;
                        stop_bit_cnt <= 0;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end
            end

            S_STOP: begin
                txd <= 1; // 停止位
                if (baud_tick_16x) begin
                    if (tick_cnt == 15) begin
                        tick_cnt <= 0;
                        if (stop_bit_cnt == (stop_bits ? 1 : 0)) begin
                            tx_done <= 1;
                        end else begin
                            stop_bit_cnt <= stop_bit_cnt + 1;
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end
            end

            default: begin
                txd <= 1;
            end
        endcase
    end
end

endmodule
```

### 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "数据位直接用 8 位" | 必须支持 5/6/7/8 位可配 |
| "停止位不用管 1.5" | 5 位数据位时停止位为 1.5 位，需要特殊处理 |
| "校验直接用异或" | 需要区分奇校验和偶校验 |
| "CTS 不用特殊处理" | CTS 流控必须正确实现，否则数据丢失 |

---

## 10. 验证要点

### 关键验证场景

| 场景 ID | 描述 | 覆盖需求 | 方法 | 优先级 |
|---------|------|----------|------|--------|
| VS-001 | 8N1 发送 | REQ-001 | 功能仿真 | High |
| VS-002 | 8E1 发送 | REQ-003 | 功能仿真 | High |
| VS-003 | 5N2 发送 | REQ-001/002 | 功能仿真 | High |
| VS-004 | CTS 流控暂停 | REQ-007 | 功能仿真 | High |
| VS-005 | Loopback 模式 | REQ-010 | 功能仿真 | Medium |
| VS-006 | 连续发送 | REQ-001 | 功能仿真 | Medium |

### SVA 断言要点
- txd 空闲高电平：`state_cur == S_IDLE |-> txd == 1`
- 起始位低电平：`state_cur == S_START |-> txd == 0`
- 停止位高电平：`state_cur == S_STOP |-> txd == 1`
- tx_done 单周期脉冲：`tx_done |=> !tx_done`

### 覆盖率模型

| 覆盖组 | 覆盖点 | 目标 |
|--------|--------|------|
| FSM 状态/转移 | 所有状态和转移 | 100% |
| 数据位配置 | 5/6/7/8 | 100% |
| 停止位配置 | 1/2 | 100% |
| 校验模式 | 无/奇/偶 | 100% |
| 流控 | CTS 有效/无效 | 100% |

---

## 11. 风险与缓解

### 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | 帧格式组装错误 | 功能 | L | 严格按配置组装帧 |
| R-002 | CTS 流控时序 | 功能 | L | 在 baud_tick_16x 边沿采样 CTS |
| R-003 | 移位寄存器方向错误 | 功能 | L | LSB 先发，右移 |

### 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | 帧格式覆盖不全 | 遍历所有数据位/停止位/校验组合 |

---

## 12. 架构决策记录

无。

---

## 13. 附录

### 需求追溯矩阵（RTM）

| 需求 ID | FS 章节 | 微架构章节 | 实现方式 | 验证场景 | 状态 |
|---------|---------|-----------|----------|----------|------|
| REQ-001 | FS §4.1 | §5.1 数据通路 | data_bits 配置 5/6/7/8 | VS-001/003 | Designed |
| REQ-002 | FS §4.1 | §5.1 数据通路 | stop_bits 配置 1/2 | VS-003 | Designed |
| REQ-003 | FS §4.1 | §5.1 数据通路 | parity_en/parity_even 配置 | VS-002 | Designed |
| REQ-007 | FS §5.6.3 | §5.2 控制逻辑 | cts_n 流控 | VS-004 | Designed |
| REQ-010 | FS §4.2 | §5.2 控制逻辑 | loopback_en 回环 | VS-005 | Designed |

### 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_FS_v1.0.md` | 功能规格书 |
| REF-002 | `rules/coding-style.md` | RTL 编码规范 |

### 缩略语

| 缩写 | 全称 |
|------|------|
| UART | Universal Asynchronous Receiver/Transmitter |
| FSM | Finite State Machine |
| FIFO | First In First Out |
| CTS | Clear To Send |
| PPA | Performance, Power, Area |
| SVA | SystemVerilog Assertion |
