# UART 功能规格书

> UART（Universal Asynchronous Receiver/Transmitter）模块功能规格书，定义模块功能、接口、寄存器、PPA 及验证策略。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块名称** | `uart` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-FS-uart-v1.0` |
| **作者/日期/审核/批准** | `AI Agent` / `2026-04-27` / `{reviewer}` / `{approver}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本，基于需求汇总和方案文档编写 |

---

## 3. 概述

### 3.1 模块定位

UART 模块作为 SoC 的低速外设通信接口，负责串行异步数据的发送与接收。通过 APB 总线接口连接系统总线，为软件提供配置和数据通路。模块位于 APB 总线下挂外设位置，上接 APB Bridge，下连外部串行设备。

**应用场景**：

| 场景 | 说明 |
|------|------|
| 调试接口 | SoC 调试日志输出至 PC 串口终端 |
| 低速外设通信 | 连接 GPS 模块、蓝牙模块、传感器等 |
| 固件升级 | 通过串口进行 bootloader 数据传输 |
| 系统控制 | AT 指令交互、CLI 命令行接口 |

**关键特性列表**：

| 编号 | 特性 | 说明 |
|------|------|------|
| F-001 | 标准 UART 异步通信 | 数据位 5/6/7/8 位可配，停止位 1/1.5/2 可配，奇偶校验可配 |
| F-002 | 小数波特率发生器 | 16 位整数 + 4 位小数累加器，精度 < 0.1% |
| F-003 | TX/RX FIFO | 深度 16 字节，寄存器阵列实现 |
| F-004 | 硬件流控 | RTS/CTS 硬件流控，防止数据溢出 |
| F-005 | 中断系统 | TX 空、RX 满、帧错误、奇偶校验错误、Break 检测等中断源 |
| F-006 | 16550 兼容寄存器 | 寄存器布局兼容 16550，可复用现有驱动 |
| F-007 | Loopback 自测试 | 支持内部回环测试模式 |
| F-008 | 过采样可配 | 16x/8x 过采样可配置 |
| F-009 | FIFO 触发级别 | 1/4、1/2、3/4 满触发级别可配 |

### 3.2 顶层框图与数据通路

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 架构框图（`uart_arch.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![UART 顶层框图与数据通路](uart_arch.png)
```

> **图片说明**：本图展示 UART 模块的顶层架构，包含 7 个子模块：
> - `uart_reg_mod`：APB 从接口，负责寄存器读写和地址解码
> - `uart_baud_gen`：小数波特率发生器，生成 baud_tick 和 baud_tick_16x
> - `uart_tx`：发送状态机 + 移位寄存器，从 TX FIFO 读取数据并串行发送
> - `uart_rx`：接收状态机 + 过采样 + 移位寄存器，接收串行数据写入 RX FIFO
> - `uart_fifo`：参数化同步 FIFO（TX/RX 各一个实例）
> - `uart_ctrl`：中断逻辑 + 模式控制 + 状态聚合
> - `uart_top`：顶层集成，仅做子模块实例化和信号连接
>
> 数据通路：APB 写入 THR → TX FIFO → uart_tx 移位发送 → txd 输出；rxd 输入 → uart_rx 过采样接收 → RX FIFO → APB 读取 RBR。

---

## 4. 功能描述

### 4.1 功能概述

UART 模块实现标准异步串行通信协议，支持 5~8 位数据位、1/1.5/2 位停止位、奇偶校验可配。通过小数波特率发生器实现 9600~921600 bps 的高精度波特率配置。发送通路和接收通路各含 16 字节 FIFO，支持硬件 RTS/CTS 流控。中断系统支持多种中断源，可通过 IER 寄存器独立使能。寄存器布局兼容 16550 标准，便于软件驱动复用。

**REQ-001**：支持标准 UART 异步串行通信，数据位 5/6/7/8 位可配。通过 LCR 寄存器的 WLS[1:0] 位域配置数据位长度。

**REQ-002**：支持 1/1.5/2 个停止位可配。通过 LCR 寄存器的 STB 位域配置停止位数量。1.5/2 停止位仅在 5 位数据位模式下区分（1.5 位），其余模式下为 2 位。

**REQ-003**：支持奇校验、偶校验、无校验三种模式。通过 LCR 寄存器的 PEN、EPS 位域配置校验模式。

**REQ-004**：支持可编程波特率，由 APB 寄存器配置。通过 DLL/DLH 寄存器设置分频值，配合 FCR_EXT 的小数部分实现高精度波特率。

**REQ-012**：最低支持 9600 bps ~ 921600 bps 波特率范围。50 MHz 时钟下，9600 bps 分频值 = 325.52，921600 bps 分频值 = 3.37，均在 16 位整数 + 4 位小数范围内。

### 4.2 工作模式

UART 模块支持以下工作模式：

**正常模式**：默认工作模式，TX 通路从 TX FIFO 读取数据并串行发送，RX 通路接收串行数据并写入 RX FIFO。

**Loopback 模式**（REQ-010）：内部回环测试模式，txd 输出信号内部连接到 rxd 输入，用于自测试。通过 MCR 寄存器的 LOOP 位使能。

**自动波特率检测模式**（REQ-011）：通过检测接收到的特定字符（如 0x55）自动计算波特率分频值。通过 FCR_EXT 寄存器的 ABRD 位使能。

**模式切换条件**：

| 模式 | 进入条件 | 退出条件 | 异常处理 |
|------|----------|----------|----------|
| 正常模式 | 复位后默认 | - | - |
| Loopback 模式 | MCR.LOOP = 1 | MCR.LOOP = 0 | 退出后 txd/rxd 恢复外部连接 |
| 自动波特率检测 | FCR_EXT.ABRD = 1 | 检测完成或超时 | 超时后 ABRD 自动清零，产生中断 |

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 状态机图（`uart_mode_fsm.d2`），编译为 PNG。

```markdown
![UART 工作模式状态机](uart_mode_fsm.png)
```

> **图片说明**：本图展示 UART 工作模式的状态转移，包含 3 个模式状态：
> - Normal：默认模式，TX/RX 正常工作
> - Loopback：内部回环，txd→rxd 内连
> - AutoBaud：自动波特率检测，检测完成后回到 Normal
>
> 转移条件由 MCR.LOOP 和 FCR_EXT.ABRD 寄存器位控制。

### 4.3 数据流描述

**发送数据流**：

| 阶段 | 输入格式 | 处理操作 | 输出格式 | 延迟(cycles) |
|------|----------|----------|----------|-------------|
| APB 写入 | 32 位 APB 总线写 | 写入 TX FIFO | 8 位 FIFO 存储 | 1 |
| FIFO 读取 | 8 位 FIFO 数据 | 添加起始位、校验位、停止位 | 10~12 位帧 | 1 |
| 移位发送 | 并行帧数据 | 按波特率逐位移位 | 串行 txd | 10~12 × baud_tick |

**接收数据流**：

| 阶段 | 输入格式 | 处理操作 | 输出格式 | 延迟(cycles) |
|------|----------|----------|----------|-------------|
| 过采样 | 串行 rxd | 16x/8x 过采样，多数判决 | 采样数据流 | 16/8 × baud_tick |
| 帧解析 | 采样数据流 | 检测起始位、数据位、校验位、停止位 | 8 位数据 + 状态 | 10~12 × baud_tick |
| FIFO 写入 | 8 位数据 + 状态 | 写入 RX FIFO | FIFO 存储 | 1 |
| APB 读取 | 8 位 FIFO 数据 | APB 总线读取 | 32 位 APB 总线读 | 1 |

### 4.4 控制流描述

**仲裁策略**：本模块无多源竞争场景。TX FIFO 和 RX FIFO 独立操作，无仲裁需求。

**流控机制**：

| 流控类型 | 接口方向 | 机制 | 背压传播路径 |
|----------|----------|------|-------------|
| 硬件流控（RTS） | 输出 | rts_n 信号 | RX FIFO 接近满 → uart_ctrl 拉低 rts_n → 外部设备停止发送 |
| 硬件流控（CTS） | 输入 | cts_n 信号 | 外部设备拉低 cts_n → uart_tx 暂停发送 → TX FIFO 背压 |
| FIFO 背压 | 内部 | full/empty 标志 | TX FIFO 空 → uart_tx 停止发送；RX FIFO 满 → uart_rx 丢弃数据 + 溢出标志 |

**超时处理**：

| 超时场景 | 超时阈值 | 超时行为 | 恢复方式 | 相关信号 |
|----------|----------|----------|----------|----------|
| RX 接收超时 | 4 个字符时间 | 产生 RTOI 中断 | 软件读取 RBR 清除 | `rx_timeout` |
| 自动波特率检测超时 | 约 1 秒（可配） | ABRD 自动清零，产生中断 | 软件重新使能 ABRD | `abrd_timeout` |
| 握手超时 | 无 | 不适用 | - | - |

---

## 5. 子模块详细设计

### 5.1 uart_reg_mod

#### 5.1.1 功能描述

`uart_reg_mod` 是 APB 从接口模块，负责地址解码和寄存器读写。将 APB 总线事务转换为内部寄存器访问信号，支持 16550 兼容的寄存器布局。

**职责范围**：
- APB 从接口协议处理（PSEL/PENABLE/PREADY 时序）
- 地址解码，将 PADDR 映射到具体寄存器
- 寄存器读写控制，产生 reg_wr_en/reg_rd_en 信号
- DLL/DLH 访问时的 DLAB 位控制

**工作模式**：始终运行，响应 APB 总线事务。PSEL 拉高时进入访问流程，PENABLE 拉高时执行读写。

#### 5.1.2 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟（50 MHz） |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `paddr` | I | ADDR_WIDTH | wire | clk | - | APB 地址总线 |
| 4 | `psel` | I | 1 | wire | clk | - | APB 选择信号 |
| 5 | `penable` | I | 1 | wire | clk | - | APB 使能信号 |
| 6 | `pwrite` | I | 1 | wire | clk | - | APB 写使能 |
| 7 | `pwdata` | I | 32 | wire | clk | - | APB 写数据 |
| 8 | `prdata` | O | 32 | reg | clk | 0 | APB 读数据 |
| 9 | `pready` | O | 1 | reg | clk | 1 | APB 就绪信号 |
| 10 | `pslverr` | O | 1 | reg | clk | 0 | APB 错误信号 |
| 11 | `reg_wr_en` | O | 1 | reg | clk | 0 | 寄存器写使能 |
| 12 | `reg_rd_en` | O | 1 | reg | clk | 0 | 寄存器读使能 |
| 13 | `reg_addr` | O | ADDR_WIDTH | reg | clk | 0 | 寄存器地址 |
| 14 | `reg_wr_data` | O | 32 | reg | clk | 0 | 写数据 |
| 15 | `reg_rd_data` | I | 32 | wire | clk | - | 读数据（各功能模块返回） |
| 16 | `dlab` | O | 1 | reg | clk | 0 | DLAB 位，控制 DLL/DLH 访问 |

**与顶层接口映射**：

| 子模块端口 | 顶层接口 | 信号名 | 映射说明 |
|------------|----------|--------|----------|
| `paddr` | §6.2 | `paddr` | 直连 |
| `psel` | §6.2 | `psel` | 直连 |
| `penable` | §6.2 | `penable` | 直连 |
| `pwrite` | §6.2 | `pwrite` | 直连 |
| `pwdata` | §6.2 | `pwdata` | 直连 |
| `prdata` | §6.2 | `prdata` | 直连 |
| `pready` | §6.2 | `pready` | 直连 |
| `pslverr` | §6.2 | `pslverr` | 直连 |

#### 5.1.3 接口协议与时序

**协议类型**：APB3（PSEL → PENABLE → PREADY 握手）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_apb_write.json`），编译为 PNG。

```markdown
![APB 写事务时序](wd_apb_write.png)
```

> **图片说明**：本图展示 APB 写事务时序，包含 Setup 和 Access 两个阶段：
> - Setup 阶段（T1）：PSEL 拉高，PADDR/PWDATA/PWRITE 有效
> - Access 阶段（T2）：PENABLE 拉高，PREADY 拉高完成写操作
> - 写操作在 PENABLE && PREADY && PWRITE 的上升沿生效

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_apb_read.json`），编译为 PNG。

```markdown
![APB 读事务时序](wd_apb_read.png)
```

> **图片说明**：本图展示 APB 读事务时序：
> - Setup 阶段（T1）：PSEL 拉高，PADDR/PWRITE 有效
> - Access 阶段（T2）：PENABLE 拉高，PREADY 拉高，PRDATA 输出有效数据
> - 读数据在 PENABLE && PREADY && !PWRITE 的上升沿采样

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| 输入 setup | ≤ 10 | ns | 相对 clk 上升沿（50 MHz 下 20 ns 周期） |
| 输出 delay | ≤ 5 | ns | clk 到 PRDATA/PREADY 有效 |
| 握手响应 | 1 | cycles | PENABLE 到 PREADY 固定 1 cycle |
| PREADY 默认值 | 1 | - | 无等待状态，单周期访问 |

#### 5.1.4 流控与背压

| 流控类型 | 接口方向 | 机制 | 背压路径描述 |
|----------|----------|------|-------------|
| APB 就绪 | 输出 | PREADY 固定为 1 | 无背压，单周期访问 |

**背压传播规则**：PREADY 固定为 1，APB 总线无等待状态。若需支持等待状态（如访问未就绪的 FIFO），可在后续版本扩展。

**超时/异常处理**：

| 异常场景 | 触发条件 | 子模块行为 | 恢复方式 | 相关信号 |
|----------|----------|----------|----------|----------|
| 地址越界 | PADDR 超出寄存器范围 | PSLVERR 拉高，PRDATA 返回 0 | 软件修正地址 | `pslverr` |
| DLAB 保护 | DLAB=0 时访问 DLL/DLH | 返回 0，写操作忽略 | 软件先设置 DLAB=1 | `dlab` |

---

### 5.2 uart_baud_gen

#### 5.2.1 功能描述

`uart_baud_gen` 是小数波特率发生器，通过 16 位整数分频 + 4 位小数累加器实现高精度波特率生成。产生 baud_tick（波特率时钟）和 baud_tick_16x（16 倍波特率时钟，用于过采样）。

**职责范围**：
- 根据 DLL/DLH/FCR_EXT 寄存器配置计算分频值
- 生成 baud_tick_16x 时钟脉冲（用于过采样和 TX 移位）
- 生成 baud_tick 时钟脉冲（用于 RX 采样点定位）
- 支持 16x/8x 过采样模式切换

**工作模式**：始终运行，根据分频寄存器值持续产生 tick 脉冲。

#### 5.2.2 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `baud_div_int` | I | 16 | wire | clk | 0 | 整数分频值（DLL+DLH） |
| 4 | `baud_div_frac` | I | 4 | wire | clk | 0 | 小数分频值（FCR_EXT[3:0]） |
| 5 | `oversample_sel` | I | 1 | wire | clk | 0 | 过采样选择：0=16x, 1=8x |
| 6 | `baud_tick_16x` | O | 1 | reg | clk | 0 | 16 倍波特率时钟脉冲 |
| 7 | `baud_tick_8x` | O | 1 | reg | clk | 0 | 8 倍波特率时钟脉冲 |
| 8 | `baud_tick` | O | 1 | reg | clk | 0 | 波特率时钟脉冲 |

**与顶层接口映射**：

| 子模块端口 | 源模块 | 信号名 | 映射说明 |
|------------|--------|--------|----------|
| `baud_div_int` | uart_reg_mod | DLL+DLH | 16 位整数分频值 |
| `baud_div_frac` | uart_reg_mod | FCR_EXT[3:0] | 4 位小数分频值 |
| `oversample_sel` | uart_reg_mod | FCR_EXT[4] | 过采样模式选择 |
| `baud_tick_16x` | → uart_tx, uart_rx | `baud_tick_16x` | TX 移位时钟、RX 过采样时钟 |
| `baud_tick` | → uart_rx | `baud_tick` | RX 采样点定位 |

#### 5.2.3 接口协议与时序

**协议类型**：脉冲输出（单周期高电平脉冲）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_baud_tick.json`），编译为 PNG。

```markdown
![波特率发生器时序](wd_baud_tick.png)
```

> **图片说明**：本图展示波特率发生器的 tick 脉冲产生时序：
> - baud_tick_16x：每个分频周期产生一个单周期脉冲，频率 = clk / (div_int + div_frac/16)
> - baud_tick_8x：在 8x 模式下，每 2 个 baud_tick_16x 产生一个脉冲
> - baud_tick：每 16 个 baud_tick_16x（或 8 个 baud_tick_8x）产生一个脉冲
> - 小数累加器在溢出时多计一拍，实现平均分频

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| baud_tick_16x 脉宽 | 1 | cycle | 单周期脉冲 |
| 波特率精度 | < 0.1 | % | @50MHz, 115200bps |
| 分频范围 | 3 ~ 65535 | - | 16 位整数分频值 |
| 小数精度 | 1/16 | - | 4 位小数累加器 |

#### 5.2.4 流控与背压

| 流控类型 | 接口方向 | 机制 | 背压路径描述 |
|----------|----------|------|-------------|
| 无 | - | - | 波特率发生器为纯输出模块，无背压需求 |

**背压传播规则**：无。波特率发生器持续产生 tick 脉冲，不受下游影响。

**超时/异常处理**：无。分频值为 0 时，baud_tick_16x 恒为 0，不产生脉冲。

---

### 5.3 uart_tx

#### 5.3.1 功能描述

`uart_tx` 是发送模块，包含发送状态机和移位寄存器。从 TX FIFO 读取数据，按配置的帧格式（起始位、数据位、校验位、停止位）串行发送到 txd 引脚。

**职责范围**：
- 从 TX FIFO 读取待发送数据
- 按帧格式组装发送数据（起始位 + 数据位 + 校验位 + 停止位）
- 按波特率逐位移位发送
- 监测 CTS 流控信号，暂停发送
- 产生 TX 完成中断和 TX FIFO 空中断

**工作模式**：由 TX FIFO 非空触发，发送完成后检查 FIFO 是否还有数据，有则继续发送，无则进入空闲。

#### 5.3.2 端口列表

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
| 13 | `txd` | O | 1 | reg | clk | 1 | 发送数据线（空闲为高） |
| 14 | `tx_done` | O | 1 | reg | clk | 0 | 发送完成脉冲 |
| 15 | `tx_busy` | O | 1 | reg | clk | 0 | 发送忙标志 |

**与顶层接口映射**：

| 子模块端口 | 顶层接口 | 信号名 | 映射说明 |
|------------|----------|--------|----------|
| `txd` | §6.2 | `txd` | 直连 |
| `cts_n` | §6.2 | `cts_n` | 直连 |
| `tx_fifo_empty` | uart_fifo(TX) | `fifo_empty` | 直连 |
| `tx_fifo_rd_en` | uart_fifo(TX) | `rd_en` | 直连 |
| `baud_tick_16x` | uart_baud_gen | `baud_tick_16x` | 直连 |

#### 5.3.3 接口协议与时序

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

#### 5.3.4 流控与背压

| 流控类型 | 接口方向 | 机制 | 背压路径描述 |
|----------|----------|------|-------------|
| CTS 流控 | 输入 | cts_n 低有效 | 外部设备拉低 cts_n → uart_tx 暂停发送 → TX FIFO 不读取 → TX FIFO 满 → APB 写入等待 |
| FIFO 空 | 输入 | tx_fifo_empty | TX FIFO 空 → uart_tx 停止发送，等待新数据写入 |

**背压传播规则**：CTS 流控优先级高于 FIFO 读取。cts_n 拉高（无效）时，uart_tx 暂停在当前位或等待状态，不读取 FIFO。cts_n 拉低（有效）后，uart_tx 恢复发送。

**超时/异常处理**：

| 异常场景 | 触发条件 | 子模块行为 | 恢复方式 | 相关信号 |
|----------|----------|----------|----------|----------|
| CTS 长时间无效 | cts_n 持续高电平 | TX 暂停，不产生超时 | CTS 恢复后自动继续 | `cts_n` |
| TX FIFO 下溢 | tx_fifo_empty=1 时发送 | 产生 FE 帧错误标志 | 软件写入 TX FIFO | `tx_fifo_empty` |

---

### 5.4 uart_rx

#### 5.3.1 功能描述

`uart_rx` 是接收模块，包含接收状态机、过采样逻辑和移位寄存器。对 rxd 引脚进行过采样，检测起始位，按配置的帧格式接收数据，写入 RX FIFO。

**职责范围**：
- 对 rxd 输入进行 2 级同步器防亚稳态
- 16x/8x 过采样，多数判决采样数据
- 检测起始位、数据位、校验位、停止位
- 帧错误、奇偶校验错误、Break 检测
- 产生 RX 数据可用中断和 RX FIFO 满中断

**工作模式**：始终监测 rxd 线，检测到下降沿（起始位）后进入接收流程。

#### 5.4.2 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `baud_tick_16x` | I | 1 | wire | clk | - | 16 倍波特率时钟脉冲 |
| 4 | `baud_tick_8x` | I | 1 | wire | clk | - | 8 倍波特率时钟脉冲 |
| 5 | `rxd` | I | 1 | wire | clk | - | 接收数据线 |
| 6 | `rx_fifo_full` | I | 1 | wire | clk | - | RX FIFO 满标志 |
| 7 | `rx_fifo_wr_en` | O | 1 | reg | clk | 0 | RX FIFO 写使能 |
| 8 | `rx_data` | O | 8 | reg | clk | 0 | 接收数据 |
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

**与顶层接口映射**：

| 子模块端口 | 顶层接口 | 信号名 | 映射说明 |
|------------|----------|--------|----------|
| `rxd` | §6.2 | `rxd` | 经 2 级同步器后使用 |
| `rts_n` | §6.2 | `rts_n` | 直连 |
| `rx_fifo_full` | uart_fifo(RX) | `fifo_full` | 直连 |
| `rx_fifo_wr_en` | uart_fifo(RX) | `wr_en` | 直连 |
| `baud_tick_16x` | uart_baud_gen | `baud_tick_16x` | 直连 |
| `baud_tick_8x` | uart_baud_gen | `baud_tick_8x` | 直连 |

#### 5.4.2 接口协议与时序

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
| 过采样判决 | 3/5 或 3/5 或 2/3 | - | 中间采样点多数判决 |
| RX FIFO 写延迟 | 1 | cycle | rx_fifo_wr_en 到数据写入 |
| 帧错误检测 | 1 | cycle | 停止位采样后立即判断 |
| Break 检测 | 2 | frames | 连续 2 帧起始位+数据位全 0 |

#### 5.4.3 流控与背压

| 流控类型 | 接口方向 | 机制 | 背压路径描述 |
|----------|----------|------|-------------|
| RTS 流控 | 输出 | rts_n 低有效 | RX FIFO 接近满 → uart_rx 拉高 rts_n → 外部设备停止发送 |
| FIFO 满 | 输入 | rx_fifo_full | RX FIFO 满 → uart_rx 丢弃后续数据 + 溢出标志 |

**背压传播规则**：rts_n 由 RX FIFO 剩余空间决定。当 FIFO 剩余空间 <= 触发级别时，rts_n 拉高（无效），通知外部设备停止发送。

**超时/异常处理**：

| 异常场景 | 触发条件 | 子模块行为 | 恢复方式 | 相关信号 |
|----------|----------|----------|----------|----------|
| 帧错误 | 停止位采样为 0 | frame_err 拉高，数据仍写入 FIFO | 软件读 LSR 清除 | `frame_err` |
| 奇偶校验错误 | 计算校验值不匹配 | parity_err 拉高，数据仍写入 FIFO | 软件读 LSR 清除 | `parity_err` |
| Break 检测 | rxd 持续低电平超过 1 帧 | break_detect 拉高 | rxd 恢复高电平后自动清除 | `break_detect` |
| FIFO 溢出 | rx_fifo_full=1 时接收 | OE 溢出标志拉高，数据丢弃 | 软件读 LSR 清除 | `rx_fifo_full` |

---

### 5.5 uart_fifo

#### 5.5.1 功能描述

`uart_fifo` 是参数化同步 FIFO，作为独立 CBB 设计，可被 TX 和 RX 通路分别实例化。使用寄存器阵列实现，深度和宽度可参数化配置。

**职责范围**：
- 数据缓存，解耦 APB 总线访问和串行通信速率
- 提供满/空/接近满/数据计数等状态标志
- 支持同步读写操作

**工作模式**：始终运行，响应 wr_en/rd_en 信号进行读写操作。

#### 5.5.2 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `wr_en` | I | 1 | wire | clk | - | 写使能 |
| 4 | `wr_data` | I | DATA_WIDTH | wire | clk | - | 写数据 |
| 5 | `rd_en` | I | 1 | wire | clk | - | 读使能 |
| 6 | `rd_data` | O | DATA_WIDTH | reg | clk | 0 | 读数据 |
| 7 | `fifo_full` | O | 1 | reg | clk | 0 | FIFO 满标志 |
| 8 | `fifo_empty` | O | 1 | reg | clk | 1 | FIFO 空标志 |
| 9 | `fifo_almost_full` | O | 1 | reg | clk | 0 | FIFO 接近满标志 |
| 10 | `fifo_count` | O | $clog2(DEPTH)+1 | reg | clk | 0 | FIFO 数据计数 |
| 11 | `fifo_overflow` | O | 1 | reg | clk | 0 | 溢出标志（满时写入） |
| 12 | `fifo_underflow` | O | 1 | reg | clk | 0 | 下溢标志（空时读取） |
| 13 | `almost_full_thresh` | I | $clog2(DEPTH)+1 | wire | clk | - | 接近满阈值配置 |

**参数**：

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `DATA_WIDTH` | 8 | 数据位宽 |
| `DEPTH` | 16 | FIFO 深度（必须为 2 的幂） |

**TX FIFO 实例参数**：DATA_WIDTH=10（8 位数据 + 1 位奇偶校验 + 1 位帧信息），DEPTH=16

**RX FIFO 实例参数**：DATA_WIDTH=11（8 位数据 + 1 位奇偶校验 + 1 位帧错误 + 1 位 Break），DEPTH=16

#### 5.5.3 接口协议与时序

**协议类型**：同步读写（wr_en/rd_en 边沿触发）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_fifo_rw.json`），编译为 PNG。

```markdown
![FIFO 读写时序](wd_fifo_rw.png)
```

> **图片说明**：本图展示 FIFO 的读写时序：
> - 写操作：wr_en 拉高，数据在 clk 上升沿写入，fifo_empty 拉低，fifo_count 增加
> - 读操作：rd_en 拉高，数据在 clk 上升沿输出，fifo_full 拉低，fifo_count 减少
> - 同时读写：wr_en 和 rd_en 同时拉高，fifo_count 保持不变
> - 满时写入：fifo_overflow 拉高，数据丢弃
> - 空时读取：fifo_underflow 拉高，rd_data 保持上次值

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| 写延迟 | 1 | cycle | wr_en 到数据写入 |
| 读延迟 | 1 | cycle | rd_en 到 rd_data 有效 |
| 标志更新 | 1 | cycle | 操作后标志在下一周期更新 |

#### 5.5.4 流控与背压

| 流控类型 | 接口方向 | 机制 | 背压路径描述 |
|----------|----------|------|-------------|
| 满标志 | 输出 | fifo_full | fifo_full=1 时写入无效，wr_en 被忽略 |
| 空标志 | 输出 | fifo_empty | fifo_empty=1 时读取无效，rd_en 被忽略 |
| 接近满 | 输出 | fifo_almost_full | 用于 RTS 流控，提前通知外部设备 |

**背压传播规则**：fifo_full 直接控制上游写入；fifo_empty 直接控制下游读取；fifo_almost_full 用于 RTS 流控提前通知。

**超时/异常处理**：

| 异常场景 | 触发条件 | 子模块行为 | 恢复方式 | 相关信号 |
|----------|----------|----------|----------|----------|
| 溢出 | fifo_full=1 时 wr_en | fifo_overflow 拉高，数据丢弃 | 软件读状态清除 | `fifo_overflow` |
| 下溢 | fifo_empty=1 时 rd_en | fifo_underflow 拉高，rd_data 不变 | 软件读状态清除 | `fifo_underflow` |

---

### 5.6 uart_ctrl

#### 5.6.1 功能描述

`uart_ctrl` 是控制模块，负责中断逻辑、模式控制和状态聚合。将各子模块的状态信号聚合为统一的中断输出，控制 Loopback 模式和流控行为。

**职责范围**：
- 中断源聚合和使能控制
- Loopback 模式控制
- RTS/CTS 流控逻辑
- 状态寄存器（LSR/MSR）更新
- 自动波特率检测控制

**工作模式**：始终运行，实时监测各子模块状态并更新中断输出。

#### 5.6.2 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `ier` | I | 4 | wire | clk | - | 中断使能寄存器 |
| 4 | `tx_done` | I | 1 | wire | clk | - | TX 完成标志 |
| 5 | `tx_fifo_empty` | I | 1 | wire | clk | - | TX FIFO 空标志 |
| 6 | `rx_valid` | I | 1 | wire | clk | - | RX 数据有效 |
| 7 | `rx_fifo_full` | I | 1 | wire | clk | - | RX FIFO 满标志 |
| 8 | `frame_err` | I | 1 | wire | clk | - | 帧错误标志 |
| 9 | `parity_err` | I | 1 | wire | clk | - | 奇偶校验错误标志 |
| 10 | `break_detect` | I | 1 | wire | clk | - | Break 检测标志 |
| 11 | `overrun_err` | I | 1 | wire | clk | - | 溢出错误标志 |
| 12 | `rx_fifo_almost_full` | I | 1 | wire | clk | - | RX FIFO 接近满 |
| 13 | `cts_n` | I | 1 | wire | clk | - | CTS 输入 |
| 14 | `loopback_en` | I | 1 | wire | clk | - | Loopback 模式使能 |
| 15 | `flow_ctrl_en` | I | 1 | wire | clk | - | 流控使能 |
| 16 | `irq` | O | 1 | reg | clk | 0 | 中断输出 |
| 17 | `iir` | O | 4 | reg | clk | 1 | 中断标识寄存器（优先级编码） |
| 18 | `lsr` | O | 8 | reg | clk | 0 | 线路状态寄存器 |
| 19 | `msr` | O | 8 | reg | clk | 0 | 调制解调器状态寄存器 |
| 20 | `rts_n_out` | O | 1 | reg | clk | 1 | RTS 输出（流控控制） |
| 21 | `tx_pause` | O | 1 | reg | clk | 0 | TX 暂停信号（CTS 无效时） |

**与顶层接口映射**：

| 子模块端口 | 源/目标模块 | 信号名 | 映射说明 |
|------------|------------|--------|----------|
| `irq` | §6.2 | `irq` | 直连 |
| `cts_n` | §6.2 | `cts_n` | 直连 |
| `rts_n_out` | §6.2 | `rts_n` | 直连 |
| `loopback_en` | uart_reg_mod | MCR.LOOP | 直连 |
| `flow_ctrl_en` | uart_reg_mod | MCR.AFE | 直连 |

#### 5.6.3 接口协议与时序

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

#### 5.6.4 流控与背压

| 流控类型 | 接口方向 | 机制 | 背压路径描述 |
|----------|----------|------|-------------|
| RTS 控制 | 输出 | rts_n_out | RX FIFO 接近满 → rts_n_out 拉高 → 外部设备停止 |
| CTS 监测 | 输入 | cts_n | cts_n 拉高 → tx_pause 拉高 → uart_tx 暂停 |

**背压传播规则**：RTS 由 RX FIFO 剩余空间决定；CTS 直接控制 TX 暂停。两者独立，互不影响。

**超时/异常处理**：

| 异常场景 | 触发条件 | 子模块行为 | 恢复方式 | 相关信号 |
|----------|----------|----------|----------|----------|
| RX 超时 | 4 个字符时间无新数据 | RTOI 中断拉高 | 软件读 RBR | `rx_timeout` |

---

### 5.7 uart_top

#### 5.7.1 功能描述

`uart_top` 是顶层集成模块，仅做子模块实例化和信号连接，不包含任何逻辑。

**职责范围**：
- 实例化所有子模块
- 连接子模块间信号
- 对外暴露 APB 接口和 UART 外部信号

**工作模式**：无逻辑，仅连线。

#### 5.7.2 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟（50 MHz） |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `paddr` | I | ADDR_WIDTH | wire | clk | - | APB 地址 |
| 4 | `psel` | I | 1 | wire | clk | - | APB 选择 |
| 5 | `penable` | I | 1 | wire | clk | - | APB 使能 |
| 6 | `pwrite` | I | 1 | wire | clk | - | APB 写使能 |
| 7 | `pwdata` | I | 32 | wire | clk | - | APB 写数据 |
| 8 | `prdata` | O | 32 | wire | clk | - | APB 读数据 |
| 9 | `pready` | O | 1 | wire | clk | - | APB 就绪 |
| 10 | `pslverr` | O | 1 | wire | clk | - | APB 错误 |
| 11 | `txd` | O | 1 | wire | clk | - | 发送数据线 |
| 12 | `rxd` | I | 1 | wire | clk | - | 接收数据线 |
| 13 | `rts_n` | O | 1 | wire | clk | - | 请求发送（低有效） |
| 14 | `cts_n` | I | 1 | wire | clk | - | 清除发送（低有效） |
| 15 | `irq` | O | 1 | wire | clk | - | 中断输出 |

**与顶层接口映射**：

| 子模块端口 | 顶层接口 | 信号名 | 映射说明 |
|------------|----------|--------|----------|
| `clk` | §6.2 | `clk` | 直连 |
| `rst_n` | §6.2 | `rst_n` | 直连 |
| `paddr` | §6.2 | `paddr` | 直连 |
| `psel` | §6.2 | `psel` | 直连 |
| `penable` | §6.2 | `penable` | 直连 |
| `pwrite` | §6.2 | `pwrite` | 直连 |
| `pwdata` | §6.2 | `pwdata` | 直连 |
| `prdata` | §6.2 | `prdata` | 直连 |
| `pready` | §6.2 | `pready` | 直连 |
| `pslverr` | §6.2 | `pslverr` | 直连 |
| `txd` | §6.2 | `txd` | 直连 |
| `rxd` | §6.2 | `rxd` | 直连 |
| `rts_n` | §6.2 | `rts_n` | 直连 |
| `cts_n` | §6.2 | `cts_n` | 直连 |
| `irq` | §6.2 | `irq` | 直连 |

#### 5.7.3 接口协议与时序

不适用——顶层无逻辑，时序由各子模块独立约束。

#### 5.7.4 流控与背压

不适用——顶层无逻辑，流控由各子模块独立处理。

---

### 5.8 子模块间接口

#### 5.8.1 内部接口列表

| 接口名称 | 源子模块 | 目标子模块 | 协议类型 | 位宽 | 说明 |
|----------|----------|------------|----------|------|------|
| `reg_bus` | uart_reg_mod | 各功能模块 | 寄存器读写 | 32 | 寄存器写数据和读数据总线 |
| `baud_tick_bus` | uart_baud_gen | uart_tx, uart_rx | 脉冲 | 2 | baud_tick_16x + baud_tick_8x |
| `tx_fifo_bus` | uart_fifo(TX) | uart_tx | Valid-Ready | 10 | TX FIFO 读数据和控制 |
| `rx_fifo_bus` | uart_rx | uart_fifo(RX) | Valid-Ready | 11 | RX FIFO 写数据和控制 |
| `status_bus` | uart_tx, uart_rx | uart_ctrl | 状态信号 | 多 | TX/RX 状态和错误标志 |
| `ctrl_bus` | uart_ctrl | uart_tx, uart_rx | 控制信号 | 多 | 模式控制和流控信号 |

#### 5.8.2 内部接口信号

| 信号名 | 方向 | 位宽 | 源 | 目标 | 功能描述 |
|--------|------|------|------|--------|----------|
| `reg_wr_en` | → | 1 | uart_reg_mod | 各功能模块 | 寄存器写使能 |
| `reg_rd_en` | → | 1 | uart_reg_mod | 各功能模块 | 寄存器读使能 |
| `reg_addr` | → | 4 | uart_reg_mod | 各功能模块 | 寄存器地址 |
| `reg_wr_data` | → | 32 | uart_reg_mod | 各功能模块 | 写数据 |
| `reg_rd_data` | ← | 32 | 各功能模块 | uart_reg_mod | 读数据（多路 mux） |
| `baud_tick_16x` | → | 1 | uart_baud_gen | uart_tx, uart_rx | 16 倍波特率时钟 |
| `baud_tick_8x` | → | 1 | uart_baud_gen | uart_rx | 8 倍波特率时钟 |
| `baud_tick` | → | 1 | uart_baud_gen | uart_rx | 波特率时钟 |
| `tx_fifo_rd_en` | → | 1 | uart_tx | uart_fifo(TX) | TX FIFO 读使能 |
| `tx_fifo_data` | ← | 10 | uart_fifo(TX) | uart_tx | TX FIFO 读数据 |
| `tx_fifo_empty` | ← | 1 | uart_fifo(TX) | uart_tx | TX FIFO 空标志 |
| `rx_fifo_wr_en` | → | 1 | uart_rx | uart_fifo(RX) | RX FIFO 写使能 |
| `rx_fifo_data` | → | 11 | uart_rx | uart_fifo(RX) | RX FIFO 写数据 |
| `rx_fifo_full` | ← | 1 | uart_fifo(RX) | uart_rx | RX FIFO 满标志 |
| `tx_done` | → | 1 | uart_tx | uart_ctrl | TX 完成标志 |
| `rx_valid` | → | 1 | uart_rx | uart_ctrl | RX 数据有效 |
| `frame_err` | → | 1 | uart_rx | uart_ctrl | 帧错误标志 |
| `parity_err` | → | 1 | uart_rx | uart_ctrl | 奇偶校验错误标志 |
| `break_detect` | → | 1 | uart_rx | uart_ctrl | Break 检测标志 |
| `loopback_en` | → | 1 | uart_ctrl | uart_tx, uart_rx | Loopback 模式使能 |
| `tx_pause` | → | 1 | uart_ctrl | uart_tx | TX 暂停信号 |

> **约束**：内部接口信号不暴露到顶层端口，仅用于子模块间互联。

---

## 6. 顶层接口定义

### 6.1 接口列表

| 接口名称 | 协议类型 | 方向 | 位宽 | 时钟域 | 说明 |
|----------|----------|------|------|--------|------|
| `apb_if` | APB3 Slave | 双向 | 32 | clk | APB 总线从接口 |
| `uart_if` | UART 串行 | 双向 | 1 | - | UART 串行通信接口 |
| `irq_if` | 中断 | 输出 | 1 | clk | 中断输出 |

### 6.2 信号详细列表

| 信号名 | 方向 | 位宽 | 时钟域 | 复位值 | 功能描述 |
|--------|------|------|--------|--------|----------|
| `clk` | I | 1 | - | - | 主时钟（50 MHz） |
| `rst_n` | I | 1 | - | - | 低有效异步复位 |
| `paddr` | I | 5 | clk | - | APB 地址总线 |
| `psel` | I | 1 | clk | - | APB 选择信号 |
| `penable` | I | 1 | clk | - | APB 使能信号 |
| `pwrite` | I | 1 | clk | - | APB 写使能 |
| `pwdata` | I | 32 | clk | - | APB 写数据 |
| `prdata` | O | 32 | clk | 0 | APB 读数据 |
| `pready` | O | 1 | clk | 1 | APB 就绪信号 |
| `pslverr` | O | 1 | clk | 0 | APB 错误信号 |
| `txd` | O | 1 | clk | 1 | 发送数据线（空闲高电平） |
| `rxd` | I | 1 | - | - | 接收数据线 |
| `rts_n` | O | 1 | clk | 1 | 请求发送（低有效，RX 流控） |
| `cts_n` | I | 1 | - | - | 清除发送（低有效，TX 流控） |
| `irq` | O | 1 | clk | 0 | 中断输出 |

### 6.3 接口时序要求

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_uart_serial.json`），编译为 PNG。

```markdown
![UART 串行接口时序](wd_uart_serial.png)
```

> **图片说明**：本图展示 UART 串行接口的时序：
> - 空闲状态：txd/rxd = 1
> - 起始位：1 位低电平
> - 数据位：5~8 位，LSB 先发
> - 校验位：0 或 1 位（可配）
> - 停止位：1、1.5 或 2 位高电平
> - 帧间隔：至少 1 位高电平

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| 波特率范围 | 9600 ~ 921600 | bps | 可编程配置 |
| 波特率精度 | < 0.1 | % | @50MHz, 115200bps |
| 数据位 | 5/6/7/8 | bit | 可配置 |
| 停止位 | 1/1.5/2 | bit | 可配置 |
| 校验 | 无/奇/偶 | - | 可配置 |

### 6.4 异常行为处理

| 异常场景 | 触发条件 | 模块行为 | 恢复方式 | 相关信号 |
|----------|----------|----------|----------|----------|
| APB 地址越界 | PADDR 超出寄存器范围 | PSLVERR 拉高 | 软件修正地址 | `pslverr` |
| RX FIFO 溢出 | FIFO 满时接收新数据 | OE 标志拉高，数据丢弃 | 软件读 LSR 清除 | `lsr[1]` |
| 帧错误 | 停止位为 0 | FE 标志拉高，数据写入 FIFO | 软件读 LSR 清除 | `lsr[3]` |
| 奇偶校验错误 | 校验值不匹配 | PE 标志拉高，数据写入 FIFO | 软件读 LSR 清除 | `lsr[2]` |
| Break 检测 | rxd 持续低电平超 1 帧 | BI 标志拉高 | rxd 恢复后自动清除 | `lsr[4]` |

---

## 7. 寄存器定义

### 7.1 地址映射表

| 偏移地址 | 名称 | 访问类型 | 复位值 | 描述 |
|----------|------|----------|--------|------|
| `0x00` | RBR/THR | RO/WO | `0x0000_0000` | 接收缓冲/发送保持（DLAB=0） |
| `0x04` | IER | RW | `0x0000_0000` | 中断使能 |
| `0x08` | IIR/FCR | RO/WO | `0x0000_00C1` | 中断标识/FIFO 控制 |
| `0x0C` | LCR | RW | `0x0000_0000` | 线路控制 |
| `0x10` | MCR | RW | `0x0000_0000` | 调制解调器控制 |
| `0x14` | LSR | RO | `0x0000_0060` | 线路状态 |
| `0x18` | MSR | RO | `0x0000_0000` | 调制解调器状态 |
| `0x1C` | SCR | RW | `0x0000_0000` | 暂存寄存器 |
| `0x20` | DLL | RW | `0x0000_0000` | 波特率分频低字节（DLAB=1） |
| `0x24` | DLH | RW | `0x0000_0000` | 波特率分频高字节（DLAB=1） |
| `0x28` | FCR_EXT | RW | `0x0000_0000` | 扩展 FIFO 控制（触发级别、小数分频、过采样） |

### 7.2 寄存器位域定义

**`RBR`（偏移 `0x00`，DLAB=0，RO）**：接收缓冲寄存器，读取 RX FIFO 最早的数据。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [7:0] | `RBR` | RO | `0x00` | 接收数据（读取后 FIFO 弹出） |
| [31:8] | `RSVD` | RO | `0` | 保留 |

**`THR`（偏移 `0x00`，DLAB=0，WO）**：发送保持寄存器，写入数据到 TX FIFO。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [7:0] | `THR` | WO | - | 发送数据（写入 TX FIFO） |
| [31:8] | `RSVD` | WO | - | 保留 |

**`IER`（偏移 `0x04`，RW）**：中断使能寄存器，控制各中断源的使能。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | `ERBFI` | RW | `0` | 接收数据可用中断使能 |
| [1] | `ETBEI` | RW | `0` | 发送 FIFO 空中断使能 |
| [2] | `ELSI` | RW | `0` | 接收线路状态中断使能（FE/PE/BI/OE） |
| [3] | `EDSSI` | RW | `0` | 调制解调器状态中断使能 |
| [7:4] | `RSVD` | RO | `0` | 保留 |

**`IIR`（偏移 `0x08`，RO）**：中断标识寄存器，指示当前最高优先级中断。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | `IP` | RO | `1` | 中断挂起：0=有中断，1=无中断 |
| [3:1] | `IID` | RO | `0` | 中断标识编码 |
| [5:4] | `FIFO_EN` | RO | `11` | FIFO 使能标志（总是 11） |
| [7:6] | `RSVD` | RO | `0` | 保留 |

**中断标识编码（IID[3:1]）**：

| IID | 优先级 | 中断类型 | 清除条件 |
|-----|--------|----------|----------|
| 011 | 1（最高） | OE/BI/FE/PE | 读 LSR |
| 010 | 2 | RxAvailable | 读 RBR 或 FIFO 低于触发级别 |
| 110 | 3 | RTOI 接收超时 | 读 RBR |
| 001 | 4（最低） | TxEmpty | 写 THR 或 读 IIR |

**`FCR`（偏移 `0x08`，WO）**：FIFO 控制寄存器。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | `FIFO_EN` | WO | - | FIFO 使能（写 1 使能） |
| [1] | `RX_FIFO_RST` | WO | - | RX FIFO 复位（写 1 复位，自动清零） |
| [2] | `TX_FIFO_RST` | WO | - | TX FIFO 复位（写 1 复位，自动清零） |
| [3] | `DMA_MODE` | WO | - | DMA 模式选择 |
| [5:4] | `RX_TRIG` | WO | - | RX FIFO 触发级别：00=1/4, 01=1/2, 10=3/4, 11=7/8 |
| [7:6] | `RSVD` | WO | - | 保留 |

**`LCR`（偏移 `0x0C`，RW）**：线路控制寄存器，配置帧格式。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [1:0] | `WLS` | RW | `00` | 数据位长度：00=5, 01=6, 10=7, 11=8 |
| [2] | `STB` | RW | `0` | 停止位选择：0=1 位, 1=2 位（5 位时为 1.5 位） |
| [3] | `PEN` | RW | `0` | 校验使能：0=无校验, 1=有校验 |
| [4] | `EPS` | RW | `0` | 校验类型：0=奇校验, 1=偶校验 |
| [5] | `SP` | RW | `0` | 附加奇偶位（Stick Parity） |
| [6] | `BC` | RW | `0` | Break 控制：0=正常, 1=强制 txd 为 0 |
| [7] | `DLAB` | RW | `0` | 分频锁存访问位：0=访问 RBR/THR/IER, 1=访问 DLL/DLH |

**`MCR`（偏移 `0x10`，RW）**：调制解调器控制寄存器。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | `DTR` | RW | `0` | 数据终端就绪（保留） |
| [1] | `RTS` | RW | `0` | 请求发送（保留） |
| [2] | `OUT1` | RW | `0` | 输出 1（保留） |
| [3] | `OUT2` | RW | `0` | 输出 2（保留） |
| [4] | `LOOP` | RW | `0` | Loopback 模式使能 |
| [5] | `AFE` | RW | `0` | 自动流控使能（RTS/CTS） |
| [7:6] | `RSVD` | RO | `0` | 保留 |

**`LSR`（偏移 `0x14`，RO）**：线路状态寄存器。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | `DR` | RO | `0` | 数据就绪：RX FIFO 非空 |
| [1] | `OE` | RO | `0` | 溢出错误：RX FIFO 满时收到新数据 |
| [2] | `PE` | RO | `0` | 奇偶校验错误 |
| [3] | `FE` | RO | `0` | 帧错误：停止位为 0 |
| [4] | `BI` | RO | `0` | Break 检测：rxd 持续低电平 |
| [5] | `THRE` | RO | `1` | 发送保持寄存器空：TX FIFO 空 |
| [6] | `TEMT` | RO | `1` | 发送器空：TX FIFO 空且无正在发送的数据 |
| [7] | `RX_FIFO_ERR` | RO | `0` | RX FIFO 中有错误数据 |

**`MSR`（偏移 `0x18`，RO）**：调制解调器状态寄存器。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | `DCTS` | RO | `0` | CTS 变化标志（写 0 清除） |
| [1] | `DDSR` | RO | `0` | DSR 变化标志（保留） |
| [2] | `TERI` | RO | `0` | RI 下降沿检测（保留） |
| [3] | `DDCD` | RO | `0` | DCD 变化标志（保留） |
| [4] | `CTS` | RO | - | CTS 当前状态 |
| [5] | `DSR` | RO | - | DSR 当前状态（保留） |
| [6] | `RI` | RO | - | RI 当前状态（保留） |
| [7] | `DCD` | RO | - | DCD 当前状态（保留） |

**`SCR`（偏移 `0x1C`，RW）**：暂存寄存器，供软件自由使用。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [7:0] | `SCR` | RW | `0x00` | 暂存数据 |
| [31:8] | `RSVD` | RO | `0` | 保留 |

**`DLL`（偏移 `0x20`，DLAB=1，RW）**：波特率分频低字节。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [7:0] | `DLL` | RW | `0x00` | 分频值低 8 位 |
| [31:8] | `RSVD` | RO | `0` | 保留 |

**`DLH`（偏移 `0x24`，DLAB=1，RW）**：波特率分频高字节。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [7:0] | `DLH` | RW | `0x00` | 分频值高 8 位 |
| [31:8] | `RSVD` | RO | `0` | 保留 |

**波特率计算公式**：

```
baud_rate = clk_freq / (16 × (DLH:DLL + FRAC/16))
```

其中 `DLH:DLL` 为 16 位整数分频值，`FRAC` 为 FCR_EXT[3:0] 的 4 位小数。

**`FCR_EXT`（偏移 `0x28`，RW）**：扩展 FIFO 控制寄存器。

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [3:0] | `FRAC` | RW | `0x0` | 波特率小数分频值（4 位） |
| [4] | `OS_SEL` | RW | `0` | 过采样选择：0=16x, 1=8x |
| [5] | `ABRD` | RW | `0` | 自动波特率检测使能 |
| [6] | `RX_TRIG_EXT` | RW | `0` | RX 触发级别扩展位 |
| [7] | `RSVD` | RO | `0` | 保留 |

---

## 8. PPA 规格

### 8.1 性能指标

| 指标 | 数值 | 单位 | 约束类型 | 条件 |
|------|------|------|----------|------|
| 最大波特率 | 921600 | bps | Target | 50 MHz 时钟 |
| 最小波特率 | 9600 | bps | Target | 50 MHz 时钟 |
| 波特率精度 | < 0.1 | % | Target | @50MHz, 115200bps |
| APB 访问延迟 | 1 | cycles | Target | 单周期访问 |
| TX FIFO 到 txd | 10~12 | baud_tick | Target | 取决于帧配置 |
| RX FIFO 到 APB 读 | 1 | cycles | Target | FIFO 读延迟 |
| 最大频率 | ≥ 50 | MHz | Target | Fmax |

### 8.2 功耗指标（PVT Corner：`TT` / `1.0V` / `25°C`）

| 指标 | 数值 | 单位 | 约束类型 |
|------|------|------|----------|
| 动态功耗 | < 5 | mW | Budget |
| 静态功耗 | < 0.5 | mW | Budget |

### 8.3 面积指标

| 指标 | 数值 | 单位 | 约束类型 |
|------|------|------|----------|
| 逻辑面积 | < 10 | kGates | Estimated |
| TX FIFO (16×10) | 160 | bit | Estimated |
| RX FIFO (16×11) | 176 | bit | Estimated |
| 总 SRAM 等效 | 336 | bit | Estimated |

### 8.4 子模块 PPA 预算分配

| 子模块 | 延迟(cycles) | 面积(kGates) | 功耗(mW) |
|--------|-------------|-------------|----------|
| uart_reg_mod | 1 | 1.0 | 0.5 |
| uart_baud_gen | 1 | 0.5 | 0.3 |
| uart_tx | 10~12×baud | 2.0 | 1.5 |
| uart_rx | 10~12×baud | 2.5 | 1.5 |
| uart_fifo(TX) | 1 | 1.0 | 0.5 |
| uart_fifo(RX) | 1 | 1.0 | 0.5 |
| uart_ctrl | 1 | 1.0 | 0.5 |
| uart_top | 0 | 0.0 | 0.0 |
| **合计** | - | **9.0** | **5.3** |

---

## 9. 时钟与复位

| 时钟域 | 频率 | 来源 | 说明 |
|--------|------|------|------|
| `clk` | 50 MHz | PLL/晶振 | 主时钟，所有逻辑使用同一时钟域 |

复位策略：异步复位同步释放，低有效 `rst_n`，2 级同步器。复位时所有寄存器清零，FIFO 清空，txd 输出高电平，rts_n 输出高电平（无效）。

---

## 10. 低功耗设计

使用全局 Clock Gating 方案，本模块不涉及特殊低功耗设计。

UART 作为低速外设，功耗本身较低（< 5 mW），无需独立的功耗域划分。软件可通过以下方式降低功耗：
- 禁用不需要的中断源（IER 寄存器）
- 在不使用时关闭波特率发生器（后续版本可增加 clock gating 使能位）

---

## 11. DFT 设计

遵循项目通用 DFT 规则（扫描链、标准 ICG），本模块不涉及特殊 DFT 设计。

DFT 要点：
- 所有寄存器可入扫描链
- 异步复位通过 rst_n 控制，不使用异步置位
- 无门控时钟，所有逻辑使用 clk 直接驱动
- Loopback 模式可作为 DFT 自测试辅助手段

---

## 12. 可靠性设计

遵循项目通用可靠性规则，本模块不涉及特殊可靠性设计。

可靠性要点：
- RX 输入 2 级同步器防止亚稳态（REQ-015）
- 过采样多数判决提高抗噪声能力
- FIFO 溢出/下溢检测，防止数据丢失
- 硬件流控（RTS/CTS）防止数据溢出

---

## 13. 约束与假设

### 设计约束

| 约束项 | 约束值 | 说明 |
|--------|--------|------|
| 工艺节点 | 28nm | 基于通用 28nm 工艺库 |
| 频率 | 50 MHz | 主时钟频率 |
| APB 数据宽度 | 32 bit | 标准 APB3 |
| APB 地址宽度 | 5 bit | 11 个寄存器，偏移 0x00~0x28 |
| 波特率范围 | 9600 ~ 921600 bps | 覆盖常见应用场景 |
| FIFO 深度 | 16 字节 | TX/RX FIFO 深度 |

### 假设条件与依赖项

| 编号 | 描述 | 验证方式/版本 |
|------|------|--------------|
| A-001 | APB 总线时钟与 UART 主时钟同频同相 | 系统集成验证 |
| A-002 | 外部设备支持 RTS/CTS 硬件流控 | 外部设备规格 |
| A-003 | rxd 输入信号上升/下降时间 < 5 ns | PCB 设计约束 |
| A-004 | 28nm 工艺库支持标准 ICG 和扫描链 | 工艺库文档 |

---

## 14. 需求追溯矩阵（RTM）

| 需求 ID | 优先级 | 需求描述 | FS 章节 | 接口/信号 | PPA 指标 | 验证策略 | 状态 |
|---------|--------|----------|---------|-----------|----------|----------|------|
| REQ-001 | Must | 数据位 5/6/7/8 位可配 | §4.1, §7.2 LCR.WLS | `data_bits[1:0]` | - | 功能仿真：遍历所有数据位配置 | Allocated |
| REQ-002 | Must | 停止位 1/1.5/2 可配 | §4.1, §7.2 LCR.STB | `stop_bits` | - | 功能仿真：遍历所有停止位配置 | Allocated |
| REQ-003 | Must | 奇偶校验三种模式 | §4.1, §7.2 LCR.PEN/EPS | `parity_en`, `parity_even` | - | 功能仿真：遍历所有校验模式 | Allocated |
| REQ-004 | Must | 可编程波特率 | §4.1, §7.2 DLL/DLH/FCR_EXT | `baud_div_int[15:0]`, `baud_div_frac[3:0]` | 波特率精度 < 0.1% | 功能仿真：遍历标准波特率 | Allocated |
| REQ-005 | Must | TX FIFO 深度 ≥ 16 字节 | §5.5, §8.3 | `tx_fifo_*` | TX FIFO 160 bit | 功能仿真：FIFO 满/空/溢出 | Allocated |
| REQ-006 | Must | RX FIFO 深度 ≥ 16 字节 | §5.5, §8.3 | `rx_fifo_*` | RX FIFO 176 bit | 功能仿真：FIFO 满/空/溢出 | Allocated |
| REQ-007 | Should | 硬件流控 RTS/CTS | §5.6.3, §7.2 MCR.AFE | `rts_n`, `cts_n` | - | 功能仿真：流控使能/禁用 | Allocated |
| REQ-008 | Must | 中断输出 | §5.6.3, §7.2 IER/IIR | `irq` | - | 功能仿真：遍历所有中断源 | Allocated |
| REQ-009 | Must | APB 从接口 32 位 | §5.1, §6.2 | `paddr/psel/penable/pwrite/pwdata/prdata/pready/pslverr` | APB 访问 1 cycle | 功能仿真：APB 读写 | Allocated |
| REQ-010 | Should | Loopback 自测试模式 | §4.2, §7.2 MCR.LOOP | `loopback_en` | - | 功能仿真：Loopback 模式收发 | Allocated |
| REQ-011 | Could | 自动波特率检测 | §4.2, §7.2 FCR_EXT.ABRD | `abrd` | - | 功能仿真：自动波特率检测流程 | Allocated |
| REQ-012 | Must | 波特率 9600~921600 bps | §8.1 | `baud_div_int[15:0]` | 9600~921600 bps | 功能仿真：边界波特率 | Allocated |
| REQ-013 | Must | 单时钟域 ≥ 50 MHz | §9, §8.1 | `clk` | Fmax ≥ 50 MHz | 综合验证 | Allocated |
| REQ-014 | Must | 异步复位同步释放 | §9 | `rst_n` | - | 功能仿真：复位序列 | Allocated |
| REQ-015 | Must | RX 2 级同步器 | §5.4.1 | `rxd_sync1`, `rxd_sync2` | - | CDC 形式验证 | Allocated |
| REQ-016 | Should | FIFO 触发级别配置 | §7.2 FCR.RX_TRIG | `rx_trig[1:0]` | - | 功能仿真：遍历触发级别 | Allocated |
| REQ-017 | Should | 16x/8x 过采样可配 | §7.2 FCR_EXT.OS_SEL | `oversample_sel` | - | 功能仿真：两种过采样模式 | Allocated |

**追溯覆盖率**：

| 统计项 | 数值 |
|--------|------|
| REQ 总数 | 17 |
| 已覆盖 | 17 (100%) |
| 未覆盖 | 0 (0%) |
| 未覆盖项 | 无 |

---

## 15. 附录

### 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_requirement_summary_v1.0.md` | 需求汇总表 |
| REF-002 | `uart_solution_v1.0.md` | 架构方案文档 |
| REF-003 | `uart_ADR_v1.0.md` | 架构决策记录 |
| REF-004 | `APB Protocol Specification` | AMBA APB 协议规范 |
| REF-005 | `16550 UART Datasheet` | 16550 兼容寄存器参考 |

### 缩略语

| 缩写 | 全称 |
|------|------|
| UART | Universal Asynchronous Receiver/Transmitter |
| APB | Advanced Peripheral Bus |
| FIFO | First In First Out |
| RTS | Request To Send |
| CTS | Clear To Send |
| DLAB | Divisor Latch Access Bit |
| RBR | Receiver Buffer Register |
| THR | Transmitter Holding Register |
| IER | Interrupt Enable Register |
| IIR | Interrupt Identification Register |
| FCR | FIFO Control Register |
| LCR | Line Control Register |
| MCR | Modem Control Register |
| LSR | Line Status Register |
| MSR | Modem Status Register |
| SCR | Scratch Register |
| DLL | Divisor Latch Low |
| DLH | Divisor Latch High |
| FE | Framing Error |
| PE | Parity Error |
| BI | Break Interrupt |
| OE | Overrun Error |
| RTOI | Receiver Time-Out Interrupt |
| CDC | Clock Domain Crossing |
| PPA | Performance, Power, Area |
| RTM | Requirements Traceability Matrix |
| SVA | SystemVerilog Assertion |
| GE | Gate Equivalent |
