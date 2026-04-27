# uart_rx 微架构规格书

> 基于 `uart_FS_v1.0.md` §5.4 编写。接收状态机 + 过采样 + 移位寄存器，接收串行数据写入 RX FIFO。编码规范遵循 `rules/coding-style.md`。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块/子模块** | `uart` / `uart_rx` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-MA-uart_rx-v1.0` |
| **对应 FS** | `uart_FS_v1.0.md` §5.4 |
| **作者/日期/审核** | `AI Agent` / `2026-04-27` / `{reviewer}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本 |

---

## 3. 子模块概述

### 3.1 功能定位

`uart_rx` 是接收模块，包含接收状态机、过采样逻辑和移位寄存器。对 rxd 引脚进行 16x/8x 过采样，检测起始位，按配置的帧格式接收数据，写入 RX FIFO。支持帧错误、奇偶校验错误和 Break 检测。

**从 FS 继承的需求**：

| 需求 ID | 需求描述 | FS 章节 |
|---------|----------|---------|
| REQ-001 | 数据位 5/6/7/8 位可配 | FS §4.1, §7.2 LCR.WLS |
| REQ-002 | 停止位 1/1.5/2 可配 | FS §4.1, §7.2 LCR.STB |
| REQ-003 | 奇偶校验三种模式 | FS §4.1, §7.2 LCR.PEN/EPS |
| REQ-015 | RX 2 级同步器 | FS §5.4.1 |
| REQ-017 | 16x/8x 过采样可配 | FS §7.2 FCR_EXT.OS_SEL |

### 3.2 与上级/兄弟模块的关系

| 邻接模块 | 接口方向 | 接口名称 | 说明 |
|----------|----------|----------|------|
| uart_baud_gen | 输入 | `baud_tick_16x`, `baud_tick_8x` | 过采样时钟 |
| uart_fifo(RX) | 输入 | `rx_fifo_full` | RX FIFO 满标志 |
| uart_fifo(RX) | 输出 | `rx_fifo_wr_en`, `rx_data` | RX FIFO 写接口 |
| uart_reg_mod | 输入 | `data_bits`, `stop_bits`, `parity_en`, `parity_even` | 帧格式配置 |
| uart_ctrl | 输入 | `oversample_sel`, `loopback_en` | 模式配置 |
| uart_ctrl | 输出 | `rx_valid`, `frame_err`, `parity_err`, `break_detect`, `rx_busy` | 状态输出 |
| 外部设备 | 输入 | `rxd` | 串行接收数据线 |
| 外部设备 | 输出 | `rts_n` | RTS 流控输出 |

### 3.3 内部框图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 内部结构图（`wd_uart_rx_arch.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![uart_rx 内部框图](wd_uart_rx_arch.png)
```

> **图片说明**：本图展示 uart_rx 的内部架构，包含以下核心组件：
> - 2 级同步器：对 rxd 输入进行 CDC 同步，防止亚稳态
> - 过采样逻辑：16x/8x 过采样，中间 3 点多数判决
> - 接收状态机（FSM）：IDLE → START → DATA → PARITY → STOP，控制接收流程
> - 移位寄存器：逐位接收数据位，LSB 先收
> - 错误检测：帧错误、奇偶校验错误、Break 检测
> - RTS 流控：根据 RX FIFO 剩余空间控制 rts_n
> - 数据从 rxd 输入，经同步、过采样、帧解析后写入 RX FIFO

---

## 4. 接口定义

### 4.1 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `baud_tick_16x` | I | 1 | wire | clk | - | 16 倍波特率时钟脉冲 |
| 4 | `baud_tick_8x` | I | 1 | wire | clk | - | 8 倍波特率时钟脉冲 |
| 5 | `rxd` | I | 1 | wire | - | - | 接收数据线（异步输入） |
| 6 | `rx_fifo_full` | I | 1 | wire | clk | - | RX FIFO 满标志 |
| 7 | `rx_fifo_wr_en` | O | 1 | reg | clk | 0 | RX FIFO 写使能 |
| 8 | `rx_data` | O | 11 | reg | clk | 0 | 接收数据（8位数据+校验+帧错误+Break） |
| 9 | `rx_valid` | O | 1 | reg | clk | 0 | 接收数据有效 |
| 10 | `data_bits` | I | 2 | wire | clk | - | 数据位配置 |
| 11 | `stop_bits` | I | 1 | wire | clk | - | 停止位配置 |
| 12 | `parity_en` | I | 1 | wire | clk | - | 校验使能 |
| 13 | `parity_even` | I | 1 | wire | clk | - | 校验类型 |
| 14 | `oversample_sel` | I | 1 | wire | clk | - | 过采样选择 |
| 15 | `loopback_en` | I | 1 | wire | clk | - | Loopback 模式使能 |
| 16 | `frame_err` | O | 1 | reg | clk | 0 | 帧错误标志 |
| 17 | `parity_err` | O | 1 | reg | clk | 0 | 奇偶校验错误标志 |
| 18 | `break_detect` | O | 1 | reg | clk | 0 | Break 检测标志 |
| 19 | `rx_busy` | O | 1 | reg | clk | 0 | 接收忙标志 |
| 20 | `rts_n` | O | 1 | reg | clk | 1 | RTS 流控输出（低有效） |

**与 FS 接口映射**：

| 本模块端口 | FS 接口 | FS 信号名 | 映射说明 |
|------------|---------|-----------|----------|
| `rxd` | FS §6.2 | `rxd` | 经 2 级同步器后使用 |
| `rts_n` | FS §6.2 | `rts_n` | 直连 |
| `rx_fifo_full` | uart_fifo(RX) | `fifo_full` | 直连 |
| `rx_fifo_wr_en` | uart_fifo(RX) | `wr_en` | 直连 |
| `baud_tick_16x` | uart_baud_gen | `baud_tick_16x` | 直连 |
| `baud_tick_8x` | uart_baud_gen | `baud_tick_8x` | 直连 |

### 4.2 接口协议与时序

**协议类型**：串行输入（rxd）+ Valid-Ready（RX FIFO 写接口）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_uart_rx_frame.json`），编译为 PNG。

```markdown
![UART 接收帧时序](wd_uart_rx_frame.png)
```

> **图片说明**：本图展示 UART 接收一帧数据的完整时序：
> - 空闲状态：rxd = 1
> - 起始位检测：rxd 下降沿，过采样确认起始位有效（中间 3 个采样点取多数判决）
> - 数据位采样：D0~D7，每位中间点采样，LSB 先收
> - 校验位校验：P（如使能），计算并比较校验值
> - 停止位检测：检查 rxd = 1，若为 0 则帧错误
> - rx_valid 在停止位结束时产生单周期脉冲，rx_data 有效
> - 2 级同步器在 rxd 输入处增加 2 cycle 延迟

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| rxd 同步延迟 | 2 | cycles | 2 级同步器延迟 |
| 过采样判决 | 3/5 或 2/3 | - | 中间采样点多数判决 |
| RX FIFO 写延迟 | 1 | cycle | rx_fifo_wr_en 到数据写入 |
| 帧错误检测 | 1 | cycle | 停止位采样后立即判断 |
| Break 检测 | 2 | frames | 连续 2 帧起始位+数据位全 0 |

---

## 5. 微架构设计

### 5.1 数据通路

#### 数据流图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 数据通路图（`wd_uart_rx_datapath.d2`），从输入到输出的完整路径。

```markdown
![uart_rx 数据通路](wd_uart_rx_datapath.png)
```

> **图片说明**：本图展示 uart_rx 的数据通路，从输入到输出共 5 个阶段：
> - 阶段 0（CDC 同步）：rxd 异步输入 → 2 级同步器 → rxd_sync
> - 阶段 1（过采样）：rxd_sync 按 16x/8x 过采样，中间 3 点多数判决
> - 阶段 2（起始位检测）：检测下降沿，确认起位有效
> - 阶段 3（数据接收）：逐位采样数据位 + 校验位 + 停止位
> - 阶段 4（输出）：rx_data + 错误标志写入 RX FIFO
>
> 关键数据路径：rxd → 同步器 → 过采样 → 移位寄存器 → rx_data。

#### 各阶段数据格式

| 阶段 | 数据名 | 位宽 | 格式说明 | 组合/时序 |
|------|--------|------|----------|-----------|
| CDC | `rxd_sync1` | 1 | 第 1 级同步 | 时序 |
| CDC | `rxd_sync2` | 1 | 第 2 级同步 | 时序 |
| 过采样 | `sample_cnt` | 4 | 采样计数器 | 时序 |
| 过采样 | `sample_val` | 3 | 中间 3 点采样值 | 时序 |
| 接收 | `shift_reg` | 8 | 数据位移位寄存器 | 时序 |
| 接收 | `parity_rx` | 1 | 接收到的校验位 | 时序 |
| 输出 | `rx_data` | 11 | 数据+校验+帧错误+Break | 时序 |

#### 2 级同步器

```verilog
// CDC: rxd 异步输入 → 2 级同步器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rxd_sync1 <= 1;
        rxd_sync2 <= 1;
    end else begin
        rxd_sync1 <= rxd;
        rxd_sync2 <= rxd_sync1;
    end
end
```

#### 过采样多数判决

| 过采样模式 | 采样点 | 判决逻辑 |
|------------|--------|----------|
| 16x | 中间 3 点（tick 7,8,9） | 3 点中 ≥ 2 点为 1 则判决为 1 |
| 8x | 中间 3 点（tick 3,4,5） | 3 点中 ≥ 2 点为 1 则判决为 1 |

#### 关键数据路径

| 路径 ID | 起点 | 终点 | 组合逻辑级数 | 预估延迟 | 关键路径 |
|---------|------|------|-------------|----------|----------|
| DP-001 | `rxd` | `rxd_sync2` | 0 级 | 2 cycles | CDC 路径 |
| DP-002 | `rxd_sync2` | `sample_val` | 1 级 | 0.2 ns | 否 |
| DP-003 | `shift_reg` | `rx_data` | 2 级 | 0.4 ns | 是 |

---

### 5.2 控制逻辑

#### 控制信号列表

| 控制信号 | 位宽 | 产生源 | 功能描述 |
|----------|------|--------|----------|
| `baud_tick_16x` | 1 | uart_baud_gen | 16 倍波特率时钟 |
| `baud_tick_8x` | 1 | uart_baud_gen | 8 倍波特率时钟 |
| `sample_cnt` | 4 | 内部计数器 | 采样计数器 |
| `bit_cnt` | 4 | 内部计数器 | 数据位计数 |
| `rx_fifo_wr_en` | 1 | 状态机 | RX FIFO 写使能 |
| `rts_n` | 1 | 流控逻辑 | RTS 流控输出 |

#### 流控机制

| 类型 | 接口 | 机制 | 背压路径 |
|------|------|------|----------|
| RTS 流控 | 输出 | rts_n 低有效 | RX FIFO 接近满 → rts_n 拉高 → 外部设备停止 |
| FIFO 满 | 输入 | rx_fifo_full | RX FIFO 满 → 丢弃数据 + 溢出标志 |

**背压传播规则**：
- `rts_n` 由 RX FIFO 剩余空间决定
- 当 FIFO 剩余空间 <= 触发级别时，`rts_n` 拉高（无效），通知外部设备停止发送
- FIFO 满时，新接收的数据被丢弃，产生溢出标志

---

### 5.3 状态机设计

#### 状态定义

| 状态名 | 编码 | 描述 |
|--------|------|------|
| `S_IDLE` | `5'b00001` | 空闲状态，等待起始位 |
| `S_START` | `5'b00010` | 确认起始位（过采样判决） |
| `S_DATA` | `5'b00100` | 接收数据位 |
| `S_PARITY` | `5'b01000` | 接收校验位（如使能） |
| `S_STOP` | `5'b10000` | 接收停止位 |

编码方式：独热码（5 状态 ≤ 16）。

#### 状态转移条件表

| 当前状态 | 转移条件 | 次态 | 输出动作 |
|----------|----------|------|----------|
| `S_IDLE` | `rxd_sync2==0`（下降沿） | `S_START` | sample_cnt=0, rx_busy=1 |
| `S_START` | `sample_cnt==7/15 && 判决为 0` | `S_DATA` | bit_cnt=0 |
| `S_START` | `sample_cnt==7/15 && 判决为 1` | `S_IDLE` | 假起始位，回到空闲 |
| `S_DATA` | `sample_cnt==7/15 && bit_cnt==data_bits-1` | `S_PARITY` or `S_STOP` | shift_reg 移位 |
| `S_PARITY` | `sample_cnt==7/15` | `S_STOP` | parity_rx 采样 |
| `S_STOP` | `sample_cnt==7/15` | `S_IDLE` | rx_valid=1, 写入 FIFO |
| 所有状态 | `default` | `S_IDLE` | 非法状态回收 |

**状态转移图使用 `chip-png-d2-gen` 生成 D2 状态机图**（`wd_uart_rx_fsm.d2`），禁止使用文本描述、ASCII 图或其他格式。

```markdown
![uart_rx 状态机](wd_uart_rx_fsm.png)
```

> **图片说明**：本图展示 uart_rx 的状态机，共 5 个状态：
> - S_IDLE：空闲状态，监测 rxd 下降沿，检测到后转移到 S_START
> - S_START：过采样确认起始位有效（中间 3 点判决为 0），有效则转移到 S_DATA，无效则回到 S_IDLE
> - S_DATA：接收数据位，LSB 先收，接收完所有数据位后根据 parity_en 转移到 S_PARITY 或 S_STOP
> - S_PARITY：接收校验位（如使能），采样后转移到 S_STOP
> - S_STOP：接收停止位，检查帧错误，写入 RX FIFO，返回 S_IDLE
>
> 状态编码：独热码，非法状态回收至 S_IDLE。

---

### 5.4 流水线设计

本子模块无流水线设计。接收操作为逐位采样，由 baud_tick_16x/8x 驱动。

---

### 5.5 FIFO / 缓冲设计

本子模块无 FIFO 设计。使用 RX FIFO（uart_fifo 实例）作为缓冲。

---

### 5.6 IP/CBB 集成设计

本子模块无 IP/CBB 集成。

---

## 6. 关键时序分析

### 关键路径

| 路径 ID | 起点 | 组合逻辑 | 级数 | 预估延迟 |
|---------|------|----------|------|----------|
| CP-001 | `rxd` | 2 级同步器 | 0 级 | 2 cycles（CDC） |
| CP-002 | `sample_cnt` 寄存器 | 多数判决 | 2 级 | 0.4 ns |
| CP-003 | `shift_reg` 寄存器 | rx_data 输出 | 2 级 | 0.4 ns |

### 时序裕量

**裕量公式**：`Tslack = Tclk - Tcq - Tlogic - Tsetup - Tskew`

| 路径 | Tclk | Tlogic | Tslack | 是否满足 |
|------|------|--------|--------|----------|
| CP-001 | 20ns (50MHz) | 0 ns | **N/A** | CDC 路径，需 CDC 验证 |
| CP-002 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |
| CP-003 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |

判断：除 CDC 路径外，所有路径 Tslack > 0，满足时序要求。CDC 路径需通过 CDC 形式验证。

### SDC 约束建议
```tcl
create_clock -name clk -period 20 [get_ports clk]
set_input_delay  -clock clk -max 5 [get_ports {baud_tick_16x baud_tick_8x rx_fifo_full data_bits stop_bits parity_en parity_even oversample_sel loopback_en}]
set_output_delay -clock clk -max 5 [get_ports {rx_fifo_wr_en rx_data rx_valid frame_err parity_err break_detect rx_busy rts_n}]
set_false_path   -from [get_ports rst_n]
set_false_path   -from [get_ports rxd]  ;# CDC 路径，由同步器处理
```

---

## 7. 时钟与复位

### 时钟域归属

| 信号 | 时钟域 | 说明 |
|------|--------|------|
| `rxd` | 异步 | 外部输入，需 2 级同步器 |
| 其他信号 | clk | 主时钟域 |

### 复位策略

异步复位同步释放，低有效 `rst_n`，2 级同步器。

复位时：
- state_cur = S_IDLE
- rxd_sync1 = 1
- rxd_sync2 = 1
- shift_reg = 0
- sample_cnt = 0
- bit_cnt = 0
- rx_data = 0
- rx_fifo_wr_en = 0
- rx_valid = 0
- frame_err = 0
- parity_err = 0
- break_detect = 0
- rx_busy = 0
- rts_n = 1（无效）

### CDC 处理

| 信号 | 位宽 | 源域 | 目标域 | 同步策略 | 风险 |
|------|------|------|--------|----------|------|
| `rxd` | 1 | 异步 | clk | 双触发器 | M |

---

## 8. PPA 预估

### 逻辑面积

| 组成 | 预估(kGates) | 计算依据 |
|------|-------------|----------|
| 状态机 | 0.3 | 5 状态独热码 + 转移逻辑 |
| 同步器 | 0.05 | 2 bit 寄存器 |
| 过采样逻辑 | 0.3 | 采样计数器 + 多数判决 |
| 移位寄存器 | 0.3 | 8 bit 移位寄存器 |
| 错误检测 | 0.3 | 校验计算 + 帧错误 + Break 检测 |
| 流控逻辑 | 0.2 | RTS 控制 |
| 控制逻辑 | 0.2 | 计数器 + 输出选择 |
| **合计** | **1.7** | |

### 功耗预估（PVT：`TT` / `1.0V` / `25°C` / `50MHz`）

| 指标 | 预估 | 单位 | 依据 |
|------|------|------|------|
| 动态功耗 | 1.0 | mW | α×C×V²×f，过采样+移位翻转 |
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
uart_rx.v                — 主模块 RTL
uart_rx_sva.sv           — SVA 断言
uart_rx_tb.v             — 仿真 testbench
```

### 参数化
- 数据位数由 `data_bits` 配置：00=5, 01=6, 10=7, 11=8
- 停止位数由 `stop_bits` 配置：0=1 位, 1=2 位
- 过采样由 `oversample_sel` 配置：0=16x, 1=8x

### 编码规范

遵循 `rules/coding-style.md`。本子模块在 RTL 实现阶段需特别关注以下高风险项：

| 高风险项 | 关注点 |
|----------|--------|
| 组合逻辑 latch 防护 | always @(*) 输出默认值、if 补 else、case 有 default |
| FSM 非法状态回收 | 所有非法状态必须回到 IDLE |
| CDC 处理 | rxd 2 级同步器，防止亚稳态 |
| 过采样判决 | 中间 3 点多数判决，非简单采样 |

### RTL 伪代码框架

```verilog
module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    // 波特率时钟
    input  wire       baud_tick_16x,
    input  wire       baud_tick_8x,
    // 串行输入
    input  wire       rxd,
    // RX FIFO 接口
    input  wire       rx_fifo_full,
    output reg        rx_fifo_wr_en,
    output reg [10:0] rx_data,
    output reg        rx_valid,
    // 帧格式配置
    input  wire [1:0] data_bits,
    input  wire       stop_bits,
    input  wire       parity_en,
    input  wire       parity_even,
    input  wire       oversample_sel,
    input  wire       loopback_en,
    // 错误标志
    output reg        frame_err,
    output reg        parity_err,
    output reg        break_detect,
    output reg        rx_busy,
    // 流控
    output reg        rts_n
);

// 状态定义
localparam [4:0] S_IDLE   = 5'b00001,
                 S_START  = 5'b00010,
                 S_DATA   = 5'b00100,
                 S_PARITY = 5'b01000,
                 S_STOP   = 5'b10000;

// CDC: 2 级同步器
reg rxd_sync1, rxd_sync2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rxd_sync1 <= 1;
        rxd_sync2 <= 1;
    end else begin
        rxd_sync1 <= rxd;
        rxd_sync2 <= rxd_sync1;
    end
end

// 过采样时钟选择
wire baud_tick_os = oversample_sel ? baud_tick_8x : baud_tick_16x;

// 采样计数器
reg [3:0] sample_cnt;

// 多数判决（中间 3 点）
reg [2:0] sample_bits;
wire sample_majority = (sample_bits[0] + sample_bits[1] + sample_bits[2]) >= 2;

// 状态机
reg [4:0] state_cur, state_nxt;
reg [3:0] bit_cnt;
reg [7:0] shift_reg;
reg       parity_rx;
reg       parity_calc;

// 实际数据位数
wire [3:0] data_bits_actual = data_bits + 5;

// 状态机 - 时序逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_cur <= S_IDLE;
    else        state_cur <= state_nxt;
end

// 状态机 - 组合逻辑
always @(*) begin
    state_nxt = S_IDLE;
    case (state_cur)
        S_IDLE: if (rxd_sync2 == 0) state_nxt = S_START;
                else state_nxt = S_IDLE;
        S_START: if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15)) begin
                     state_nxt = sample_majority ? S_DATA : S_IDLE;
                 end else state_nxt = S_START;
        S_DATA: if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15)) begin
                    if (bit_cnt == data_bits_actual - 1) begin
                        state_nxt = parity_en ? S_PARITY : S_STOP;
                    end else begin
                        state_nxt = S_DATA;
                    end
                end else state_nxt = S_DATA;
        S_PARITY: if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15))
                      state_nxt = S_STOP;
                  else state_nxt = S_PARITY;
        S_STOP: if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15))
                    state_nxt = S_IDLE;
                else state_nxt = S_STOP;
        default: state_nxt = S_IDLE;
    endcase
end

// 数据通路
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sample_cnt    <= 0;
        bit_cnt       <= 0;
        shift_reg     <= 0;
        parity_rx     <= 0;
        parity_calc   <= 0;
        sample_bits   <= 0;
        rx_data       <= 0;
        rx_fifo_wr_en <= 0;
        rx_valid      <= 0;
        frame_err     <= 0;
        parity_err    <= 0;
        break_detect  <= 0;
        rx_busy       <= 0;
        rts_n         <= 1;
    end else begin
        rx_fifo_wr_en <= 0;
        rx_valid      <= 0;

        // 采样计数器
        if (baud_tick_os) begin
            if (sample_cnt == (oversample_sel ? 7 : 15))
                sample_cnt <= 0;
            else
                sample_cnt <= sample_cnt + 1;
        end

        // 多数判决采样
        if (baud_tick_os) begin
            // 中间 3 点采样
            if (sample_cnt == (oversample_sel ? 3 : 7))
                sample_bits[0] <= rxd_sync2;
            if (sample_cnt == (oversample_sel ? 4 : 8))
                sample_bits[1] <= rxd_sync2;
            if (sample_cnt == (oversample_sel ? 5 : 9))
                sample_bits[2] <= rxd_sync2;
        end

        case (state_cur)
            S_IDLE: begin
                rx_busy <= 0;
                if (rxd_sync2 == 0) begin
                    rx_busy    <= 1;
                    sample_cnt <= 0;
                end
            end

            S_START: begin
                if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15)) begin
                    if (!sample_majority) begin
                        // 无效起始位，回到空闲
                    end else begin
                        bit_cnt     <= 0;
                        parity_calc <= parity_even ? 0 : 1; // 初始化校验
                    end
                end
            end

            S_DATA: begin
                if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15)) begin
                    shift_reg[bit_cnt] <= sample_majority;
                    parity_calc <= parity_calc ^ sample_majority;
                    bit_cnt <= bit_cnt + 1;
                end
            end

            S_PARITY: begin
                if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15)) begin
                    parity_rx <= sample_majority;
                end
            end

            S_STOP: begin
                if (baud_tick_os && sample_cnt == (oversample_sel ? 7 : 15)) begin
                    // 帧错误检测
                    frame_err <= !sample_majority;
                    // 校验错误检测
                    parity_err <= parity_en && (parity_rx != parity_calc);
                    // Break 检测
                    break_detect <= (shift_reg == 0) && !sample_majority;
                    // 写入 RX FIFO
                    rx_data <= {break_detect, frame_err, parity_rx, shift_reg};
                    rx_fifo_wr_en <= !rx_fifo_full;
                    rx_valid <= 1;
                end
            end

            default: ;
        endcase

        // RTS 流控
        rts_n <= !rx_fifo_full; // 简化：FIFO 满时拉高 rts_n
    end
end

endmodule
```

### 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "rxd 不用同步" | 必须 2 级同步器，否则亚稳态 |
| "过采样只采一个点" | 必须中间 3 点多数判决，提高抗噪声 |
| "帧错误不用检测" | 必须检测并报告，软件需要知道 |
| "Break 检测无所谓" | Break 是重要错误标志，必须检测 |

---

## 10. 验证要点

### 关键验证场景

| 场景 ID | 描述 | 覆盖需求 | 方法 | 优先级 |
|---------|------|----------|------|--------|
| VS-001 | 8N1 接收 | REQ-001 | 功能仿真 | High |
| VS-002 | 8E1 接收 | REQ-003 | 功能仿真 | High |
| VS-003 | 5N2 接收 | REQ-001/002 | 功能仿真 | High |
| VS-004 | 帧错误检测 | REQ-001 | 功能仿真 | High |
| VS-005 | 校验错误检测 | REQ-003 | 功能仿真 | High |
| VS-006 | Break 检测 | REQ-001 | 功能仿真 | High |
| VS-007 | 16x 过采样 | REQ-017 | 功能仿真 | Medium |
| VS-008 | 8x 过采样 | REQ-017 | 功能仿真 | Medium |
| VS-009 | CDC 亚稳态 | REQ-015 | CDC 形式验证 | High |

### SVA 断言要点
- rx_valid 单周期脉冲：`rx_valid |=> !rx_valid`
- 帧错误：`state_cur == S_STOP && !sample_majority |=> frame_err`
- 校验错误：`parity_en && parity_rx != parity_calc |=> parity_err`
- CDC 同步器：`$stable(rxd_sync2) || $rose(rxd_sync1) || $fell(rxd_sync1)`

### 覆盖率模型

| 覆盖组 | 覆盖点 | 目标 |
|--------|--------|------|
| FSM 状态/转移 | 所有状态和转移 | 100% |
| 过采样模式 | 16x/8x | 100% |
| 错误场景 | 帧错误/校验错误/Break | 100% |
| 数据位配置 | 5/6/7/8 | 100% |

---

## 11. 风险与缓解

### 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | CDC 亚稳态 | 可靠性 | M | 2 级同步器，CDC 形式验证 |
| R-002 | 过采样判决错误 | 功能 | L | 中间 3 点多数判决 |
| R-003 | 假起始位误触发 | 功能 | L | 起始位过采样确认 |

### 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | CDC 验证不充分 | CDC 形式验证 + 仿真 |

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
| REQ-003 | FS §4.1 | §5.1 数据通路 | parity_en/parity_even 配置 | VS-002/005 | Designed |
| REQ-015 | FS §5.4.1 | §7 CDC 处理 | 2 级同步器 | VS-009 | Designed |
| REQ-017 | FS §7.2 | §5.1 数据通路 | oversample_sel 配置 | VS-007/008 | Designed |

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
| CDC | Clock Domain Crossing |
| RTS | Request To Send |
| PPA | Performance, Power, Area |
| SVA | SystemVerilog Assertion |
