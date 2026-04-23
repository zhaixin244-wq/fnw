# UART 接口协议

> **用途**：异步串行通信接口，点对点全双工
> **规范版本**：事实标准（RS-232/RS-422/RS-485 物理层）
> **典型应用**：调试串口、板间通信、GPS 模块、蓝牙模块、嵌入式控制台

---

## 1. 协议概述

UART（Universal Asynchronous Receiver/Transmitter）是一种异步串行通信协议，核心特征：

- **2 线制**：TX（发送）+ RX（接收），全双工（收发独立）
- **异步通信**：无时钟信号线，收发双方通过预先约定的波特率（Baud Rate）同步
- **点对点**：一对一连接，无寻址机制
- **电平标准**：逻辑电平由物理层决定（TTL/CMOS、RS-232、RS-485）
- **数据流向**：TX → 对端 RX，RX ← 对端 TX（交叉连接）

**与同步串行协议的对比**：

| 特性 | UART | SPI | I2C |
|------|------|-----|-----|
| 信号线数 | 2（TX/RX） | 4（SCLK/MOSI/MISO/CS） | 2（SCL/SDA） |
| 时钟线 | 无（异步） | 有（SCLK） | 有（SCL） |
| 拓扑 | 点对点 | 一主多从 | 多主多从 |
| 全双工 | 是 | 是 | 半双工 |
| 最大速率 | 取决于物理层（通常 ≤ 3 Mbps） | > 50 MHz | 3.4 Mbps（HS mode） |
| 寻址 | 无 | 片选线 | 7/10-bit 地址 |

---

## 2. 信号定义

### 2.1 必需信号

| 信号名 | 方向 | 有效电平 | 功能描述 |
|--------|------|----------|----------|
| `TX` | 输出 | 高/低 | 发送数据线，将并行数据串行输出 |
| `RX` | 输入 | 高/低 | 接收数据线，接收对端串行数据 |

### 2.2 可选硬件流控信号

| 信号名 | 方向 | 有效电平 | 功能描述 |
|--------|------|----------|----------|
| `RTS` | 输出 | 低有效 | Request To Send，本端准备好接收数据 |
| `CTS` | 输入 | 低有效 | Clear To Send，对端允许本端发送 |
| `DTR` | 输出 | 低有效 | Data Terminal Ready，终端就绪 |
| `DSR` | 输入 | 低有效 | Data Set Ready，设备就绪 |
| `DCD` | 输入 | 低有效 | Data Carrier Detect，检测到载波 |
| `RI` | 输入 | 低有效/脉冲 | Ring Indicator，振铃指示 |

> **注**：DTR/DSR/DCD/RI 在现代嵌入式系统中极少使用，主要用于传统调制解调器场景。

### 2.3 信号电平标准

| 标准 | 逻辑 1 | 逻辑 0 | 有效距离 | 典型速率 |
|------|--------|--------|----------|----------|
| TTL/CMOS | 3.3V / 5V | 0V | < 0.5 m | ≤ 1 Mbps |
| RS-232 | -3V ~ -15V | +3V ~ +15V | < 15 m | ≤ 115.2 kbps |
| RS-422 | 差分 +2V ~ +6V | 差分 -2V ~ -6V | < 1200 m | ≤ 10 Mbps |
| RS-485 | 差分 +1.5V ~ +6V | 差分 -1.5V ~ -6V | < 1200 m | ≤ 10 Mbps |

---

## 3. 数据帧格式

### 3.1 帧结构

```
  IDLE    START    D0   D1   D2   D3   D4   D5   D6   D7   PARITY   STOP    IDLE
──────┐  ┌─────┐─────┐─────┐─────┐─────┐─────┐─────┐─────┐  ┌───┐────────────
      │  │     │     │     │     │     │     │     │     │  │   │
      └──┘     └─────┘     └─────┘     └─────┘     └─────┘──┘
  高电平  1b   LSB → MSB（共 5~8 bit）      0/1b    1/1.5/2b
```

**各字段说明**：

| 字段 | 宽度 | 值 | 说明 |
|------|------|----|------|
| IDLE | 1+ bit | 高电平 | 空闲状态，线路保持高电平 |
| START | 1 bit | 低电平 | 起始位，标志帧开始（下降沿触发） |
| DATA | 5~8 bit | 数据位 | 有效数据，LSB（最低位）先发 |
| PARITY | 0~1 bit | 校验位 | 可选，奇偶校验（详见 §5） |
| STOP | 1/1.5/2 bit | 高电平 | 停止位，标志帧结束（详见 §6） |

### 3.2 帧长度计算

| 配置 | 帧长度 | 说明 |
|------|--------|------|
| 8N1（最常用） | 10 bit | START(1) + DATA(8) + STOP(1) |
| 8N2 | 11 bit | START(1) + DATA(8) + STOP(2) |
| 8E1 | 11 bit | START(1) + DATA(8) + PARITY(1) + STOP(1) |
| 7O1 | 10 bit | START(1) + DATA(7) + PARITY(1) + STOP(1) |

> **命名约定**：`{数据位}{校验位}{停止位}`，如 8N1 = 8 data, None parity, 1 stop。

---

## 4. 波特率

### 4.1 波特率定义

波特率 = 每秒传输的 symbol 数。对于 UART（无编码），1 symbol = 1 bit，因此波特率 = 比特率。

**波特率产生公式**：

```
Baud Rate = fclk / divisor

其中：
  fclk   = 系统时钟频率（Hz）
  divisor = 波特率分频值
```

**示例**：fclk = 50 MHz，波特率 = 115200 bps：
```
divisor = 50,000,000 / 115,200 = 434.03 → 取整 434
实际波特率 = 50,000,000 / 434 = 115,207 bps
误差 = (115,207 - 115,200) / 115,200 = 0.006%
```

### 4.2 常用波特率

| 波特率 (bps) | 应用场景 | 1 byte 传输时间 (8N1) | 有效吞吐量 |
|--------------|----------|----------------------|-----------|
| 9600 | 低速调试、GPS NMEA | ~1.042 ms | 960 B/s |
| 19200 | 低速传感器 | ~521 us | 1920 B/s |
| 38400 | 中速通信 | ~260 us | 3840 B/s |
| 57600 | 中速通信 | ~174 us | 5760 B/s |
| 115200 | 标准调试串口、蓝牙 | ~86.8 us | 11520 B/s |
| 230400 | 高速调试 | ~43.4 us | 23040 B/s |
| 460800 | 高速通信 | ~21.7 us | 46080 B/s |
| 921600 | 高速数据传输 | ~10.8 us | 92160 B/s |
| 1500000 | USB-UART 芯片常见 | ~6.67 us | 150000 B/s |
| 3000000 | 最高常见速率 | ~3.33 us | 300000 B/s |

> **注**：实际吞吐量 = 有效数据位 / 帧长度 × 波特率。如 8N1 配置下，有效吞吐 = 8/10 × 波特率。

### 4.3 波特率误差容忍度

收发双方波特率允许存在偏差。当数据位数为 N 时，总容忍度：

```
最大累积误差 ≤ 0.5 bit（保证采样点在 STOP 位中心 ±0.5 bit 范围内）

总位数 = 1(START) + N(DATA) + P(PARITY) + 1(STOP)
每 bit 最大误差 = 0.5 / 总位数

示例 8N1：总位数 = 10，每 bit 误差 ≤ 0.5/10 = 5%
```

| 配置 | 总位数 | 收发双方最大累积误差 | 单方最大偏差 |
|------|--------|---------------------|-------------|
| 8N1 | 10 | 5.0% | ±2.5% |
| 8E1 | 11 | 4.5% | ±2.27% |
| 8N2 | 11 | 4.5% | ±2.27% |

---

## 5. 校验位

### 5.1 校验类型

| 类型 | 计算方法 | 发送值 | 说明 |
|------|----------|--------|------|
| NONE | 无校验 | - | 不发送校验位 |
| ODD | 数据位中 1 的个数为奇数 | 0；为偶数 | 1 | 使得数据+校验位中 1 的总数为奇数 |
| EVEN | 数据位中 1 的个数为偶数 | 0；为奇数 | 1 | 使得数据+校验位中 1 的总数为偶数 |
| MARK | 校验位固定为 1 | 1 | 无校验能力，仅兼容用途 |
| SPACE | 校验位固定为 0 | 0 | 无校验能力，仅兼容用途 |

### 5.2 校验位计算示例

以数据 `0x41`（ASCII 'A'）= `0100_0001` 为例，8-bit 数据：

| 校验类型 | 数据中 1 的个数 | 校验位值 | 说明 |
|----------|----------------|----------|------|
| ODD | 2（偶数） | 1 | 使总数为奇数 |
| EVEN | 2（偶数） | 0 | 使总数为偶数 |
| MARK | - | 1 | 固定 1 |
| SPACE | - | 0 | 固定 0 |

---

## 6. 停止位

| 停止位宽度 | 应用场景 | 说明 |
|-----------|----------|------|
| 1 bit | 最常用，8N1 配置 | 标准停止位 |
| 1.5 bit | 部分低速率通信 | 数据位 5-bit 时偶尔使用 |
| 2 bit | 老式设备兼容、某些工业协议 | 提供更长的帧间间隔 |

> **注**：停止位期间线路保持高电平。接收器在 STOP 位期间检测到低电平则视为帧错误。

---

## 7. 流控机制

### 7.1 硬件流控（RTS/CTS）

```
发送方                                    接收方
  TX ─────────────────────────────────────→ RX
  CTS ←───────────────────────────────────  RTS

发送流程：
1. 接收方拉低 RTS（表示"我准备好接收"）
2. 发送方检测 CTS 为低 → 开始发送
3. 接收方缓冲区将满 → 拉高 RTS
4. 发送方检测 CTS 为高 → 停止发送
```

**RTS/CTS 逻辑**：

| RTS（本端输出） | 含义 | CTS（本端输入） | 含义 |
|----------------|------|----------------|------|
| 低电平 | 本端可以接收数据 | 低电平 | 对端允许发送 |
| 高电平 | 本端缓冲区将满，停止发送 | 高电平 | 对端禁止发送 |

### 7.2 软件流控（XON/XOFF）

使用特殊控制字符在数据流中嵌入流控信号：

| 控制字符 | ASCII 码 | 含义 |
|----------|----------|------|
| XON | 0x11（DC1） | 恢复发送 |
| XOFF | 0x13（DC3） | 暂停发送 |

**工作流程**：
1. 接收方缓冲区将满 → 发送 XOFF（0x13）
2. 发送方收到 XOFF → 暂停发送
3. 接收方缓冲区有空 → 发送 XON（0x11）
4. 发送方收到 XON → 恢复发送

**注意**：软件流控仅适用于 ASCII 文本传输。二进制数据中可能包含 0x11/0x13，导致误触发流控。

### 7.3 流控对比

| 特性 | 硬件流控（RTS/CTS） | 软件流控（XON/XOFF） |
|------|---------------------|---------------------|
| 额外信号线 | 需要 2 根 | 不需要 |
| 二进制安全 | 是 | 否 |
| 响应速度 | 即时（硬件信号） | 有延迟（需传输控制字符） |
| 实现复杂度 | 低（GPIO 级别） | 中（需解析控制字符） |
| 推荐场景 | 高速率、二进制数据 | 低速率、文本数据 |

---

## 8. 传输时序

### 8.1 完整帧时序（8N1 配置）

```
         Bit period (T_bit = 1 / Baud Rate)
         ←──────────────────────────────────→

         START    D0    D1    D2    D3    D4    D5    D6    D7   STOP
IDLE ──┐ ┌───┐ ┌─────┐ ┌───┐ ┌───┐ ┌─────┐ ┌───┐ ┌─────┐ ┌───┐ ┌───┐  ──→ IDLE
       │ │   │ │     │ │   │ │   │ │     │ │   │ │     │ │   │ │   │
       └─┘   └─┘     └─┘   └─┘   └─┘     └─┘   └─┘     └─┘   └─┘
        1   0  1      0   0   0   1       0   0       1   0   1
       ←─→ ←→ ←──→   ←→  ←→  ←→  ←──→   ←→  ←──→    ←→  ←→  ←──→
       1b  1b   1b   1b  1b  1b   1b    1b   1b     1b  1b   1b
```

### 8.2 关键时序参数

| 参数 | 定义 | 公式 |
|------|------|------|
| T_bit | 单 bit 持续时间 | 1 / Baud Rate |
| T_frame | 完整帧时间 | (1 + N + P + S) × T_bit |
| T_idle | 帧间最小间隔 | ≥ 1 bit（STOP 已包含） |

**示例**：115200 bps，8N1 配置：
```
T_bit   = 1 / 115200 = 8.68 us
T_frame = 10 × 8.68 us = 86.8 us（单帧时间）
最大有效吞吐 = 1 / 86.8 us × 8 = 92,160 bps（有效数据比特率）
```

### 8.3 数据位发送顺序

- **LSB 先发**：D0（最低位）首先发送，D7（最高位）最后发送
- 无论数据位宽度（5/6/7/8 bit），均从 LSB 开始

**示例**：发送字符 'A'（0x41 = 0100_0001）：

```
发送顺序（LSB → MSB）：D0=1, D1=0, D2=0, D3=0, D4=0, D5=0, D6=1, D7=0

线路波形：
START  D0  D1  D2  D3  D4  D5  D6  D7  STOP
  0     1   0   0   0   0   0   1   0    1
```

---

## 9. 收发器设计要点

### 9.1 过采样（Oversampling）

为正确采样异步数据，接收器使用过采样（通常 16 倍）：

```
过采样时钟 = 波特率 × 16

每 bit 周期采样 16 次，采样点选在 bit 中心（第 7/8 个采样点）：

bit 周期：|←──────────────────────────────────────→|
采样点：  0  1  2  3  4  5  6  [7/8]  9  10  11  12  13  14  15
                                ↑
                          最佳采样点（bit 中心）
```

### 9.2 起始位检测

1. 检测到下降沿（从 IDLE 高电平跳变为低电平）
2. 延迟 8 个过采样时钟（半 bit），确认仍为低电平 → 确认起始位
3. 后续每 16 个过采样时钟采样一次（在 bit 中心）
4. 采样 DATA 位 + PARITY 位 + STOP 位

### 9.3 采样点居中策略

```
状态机中的采样计数器（16x 过采样）：

START bit 检测（下降沿触发）：
  过采样计数器从 0 开始计数
  计数到 7~8 时采样 → 确认 START 为低电平
  计数到 23~24 时采样 → D0 bit 中心
  计数到 39~40 时采样 → D1 bit 中心
  ...
  每 16 个过采样周期采样下一个 bit

容错性：±半个过采样周期的偏差不会影响采样结果
```

### 9.4 波特率误差容忍度（过采样视角）

| 过采样倍数 | 采样偏移容忍 | 说明 |
|-----------|-------------|------|
| 16x | ±0.5 bit（±8 个采样周期） | 标准方案，兼容性好 |
| 8x | ±0.5 bit（±4 个采样周期） | 省资源，精度略低 |
| 4x | ±0.5 bit（±2 个采样周期） | 高速场景，精度低 |

> **设计建议**：通用 UART 推荐 16x 过采样。高波特率场景可降低至 8x。

---

## 10. FIFO 设计

### 10.1 TX FIFO

| 参数 | 典型值 | 说明 |
|------|--------|------|
| 深度 | 16 / 64 / 128 / 256 entries | 缓存待发送数据 |
| 宽度 | 8 bit（或参数化） | 与数据位宽对齐 |
| 接口 | CPU 写入 → UART 发送器读出 | 异步写、同步读 |
| 触发级别 | 1/4, 1/2, 3/4, 将空 | 产生中断/ DMA 请求 |

**TX FIFO 工作流程**：
1. CPU 将数据写入 TX FIFO
2. FIFO 非空 → 发送器自动逐字节串行发送
3. FIFO 达到低水位（almost empty）→ 产生中断/DMA 请求补充数据
4. FIFO 完全空且最后一帧发送完成 → 发送器回到 IDLE

### 10.2 RX FIFO

| 参数 | 典型值 | 说明 |
|------|--------|------|
| 深度 | 16 / 64 / 128 / 256 entries | 缓存已接收数据 |
| 宽度 | 8 bit（或参数化） | 与数据位宽对齐 |
| 接口 | UART 接收器写入 → CPU 读出 | 同步写、同步读 |
| 触发级别 | 1/4, 1/2, 3/4, 将满 | 产生中断/ DMA 请求 |

**RX FIFO 工作流程**：
1. 接收器完成一帧采样 → 将数据写入 RX FIFO
2. FIFO 达到高水位（almost full）→ 产生中断/DMA 请求
3. CPU 从 FIFO 中读取数据
4. FIFO 满时新数据到来 → 溢出错误（Overrun Error）

### 10.3 FIFO 深度计算

```
场景：DMA 传输，每次搬运 N 字节

RX FIFO 深度 ≥ (DMA 响应延迟 × 波特率 / 帧长度) + 1

示例：
  波特率 = 115200 bps，8N1
  DMA 响应延迟 ≈ 2 us
  每 byte 时间 ≈ 86.8 us
  DMA 期间可接收 = 2 / 86.8 ≈ 0 byte（几乎不影响）
  → 16 深度 FIFO 即可满足

高波特率场景（3 Mbps）：
  每 byte 时间 ≈ 3.33 us
  DMA 响应延迟 ≈ 2 us
  → 需要 ≥ 64 深度 FIFO 才安全
```

---

## 11. 错误检测

UART 提供三种基本错误检测机制，通过状态寄存器上报：

### 11.1 帧错误（Framing Error）

| 条件 | 说明 |
|------|------|
| 触发条件 | STOP 位期间采样到低电平（应为高电平） |
| 常见原因 | 波特率不匹配、信号干扰、线路断开 |
| 处理方式 | 丢弃该帧，记录错误标志 |

```
正常帧 STOP：   ──────┐   ┌──────
                      │   │
                      └───┘  （高电平）

帧错误 STOP：   ──────┐   ┌──┐
                      │   │  │
                      └───┘  └──── （低电平，检测为帧错误）
```

### 11.2 校验错误（Parity Error）

| 条件 | 说明 |
|------|------|
| 触发条件 | 接收到的校验位与计算值不匹配 |
| 常见原因 | 传输噪声、波特率偏差导致采样错误 |
| 处理方式 | 通过重传机制恢复（如需可靠传输） |

### 11.3 溢出错误（Overrun Error）

| 条件 | 说明 |
|------|------|
| 触发条件 | 新一帧数据到达时，RX FIFO/寄存器中前一帧尚未被读取 |
| 常见原因 | CPU/DMA 读取速度跟不上接收速度 |
| 处理方式 | 旧数据被覆盖，记录溢出标志 |

### 11.4 错误类型汇总

| 错误类型 | 寄存器位名 | 检测位置 | 可恢复性 |
|----------|-----------|----------|---------|
| 帧错误（Framing Error） | `FE` | STOP 位采样 | 丢帧后恢复 |
| 校验错误（Parity Error） | `PE` | PARITY 位校验 | 可通过重传恢复 |
| 溢出错误（Overrun Error） | `OE` | FIFO 写入时 | 丢帧后恢复 |
| 中断错误（Break Error）[可选] | `BI` | 全帧检测为低 | 线路恢复后自动 |

---

## 12. 与 RS-232 / RS-485 的区别

### 12.1 物理层对比

| 特性 | TTL UART | RS-232 | RS-422 | RS-485 |
|------|----------|--------|--------|--------|
| 信号类型 | 单端 | 单端 | 差分 | 差分 |
| 逻辑 1 | 3.3V/5V | -3V ~ -15V | A > B（+2V ~ +6V） | A > B（+1.5V ~ +6V） |
| 逻辑 0 | 0V | +3V ~ +15V | A < B（-2V ~ -6V） | A < B（-1.5V ~ -6V） |
| 信号线数 | 2（TX/RX） | 2 + GND | 2 对差分 + GND | 2 线（半双工）或 4 线（全双工） |
| 最大距离 | < 0.5 m | < 15 m | < 1200 m | < 1200 m |
| 最大速率 | 取决于芯片 | 115.2 kbps（典型） | 10 Mbps | 10 Mbps |
| 节点数 | 1:1 | 1:1 | 1:10（1 发 10 收） | 1:32（多点） |
| 抗干扰 | 差 | 差 | 好 | 好 |
| 典型芯片 | MCU 内置 UART | MAX3232, SP3232 | MAX488, SN65LVDS | MAX485, SN75176 |

### 12.2 协议层差异

| 层面 | UART | RS-232 | RS-485 |
|------|------|--------|--------|
| 协议帧格式 | 定义（START/DATA/PARITY/STOP） | 继承 UART 帧格式 | 继承 UART 帧格式 |
| 流控 | 可选（RTS/CTS） | 标准支持（RTS/CTS/DTR/DSR） | 无硬件流控 |
| 方向控制 | 不需要（全双工） | 不需要（全双工） | 需要（DE/RE 引脚控制收发方向） |
| 多节点 | 不支持 | 不支持 | 支持（需地址帧/协议） |

### 12.3 RS-485 方向控制

RS-485 半双工模式下，发送器和接收器共享差分对，需要方向控制：

```
发送使能（DE）= 1 → 发送器驱动总线
接收使能（RE）= 0 → 接收器使能

通常 DE 和 RE 连接在一起，由同一个 GPIO 控制：
  GPIO = 1 → 发送模式
  GPIO = 0 → 接收模式
```

---

## 13. RTL 实现要点

### 13.1 顶层模块框图

```
                    ┌─────────────────────────────────────────┐
                    │              UART Top                    │
                    │                                         │
  APB/AXI Bus ────→│  ┌──────────┐    ┌──────────────────┐   │──→ TX
                    │  │ Register │    │ TX Shift Register │   │
                    │  │ File     │───→│ + Baud Generator  │   │
                    │  │          │    └──────────────────┘   │
                    │  │          │                           │
  RX ─────────────→│  │          │    ┌──────────────────┐   │──→ Interrupt
                    │  │          │←───│ RX Shift Register │   │
                    │  └──────────┘    │ + Oversampler    │   │
                    │                  └──────────────────┘   │
                    │  ┌──────────┐    ┌──────────────────┐   │
                    │  │ TX FIFO  │    │ RX FIFO          │   │
                    │  │          │    │                  │   │
                    │  └──────────┘    └──────────────────┘   │
                    └─────────────────────────────────────────┘
```

### 13.2 波特率发生器

```verilog
module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,   // 系统时钟频率
    parameter BAUD_RATE = 115200,        // 目标波特率
    parameter OVERSAMPLE = 16            // 过采样倍数
)(
    input  wire clk,
    input  wire rst_n,
    input  wire baud_en,                 // 波特率发生器使能
    output reg  baud_tick,               // 波特率时钟脉冲
    output reg  baud_tick_x16            // 16x 过采样时钟脉冲
);

    localparam DIVISOR      = CLK_FREQ / BAUD_RATE;
    localparam DIVISOR_X16  = CLK_FREQ / (BAUD_RATE * OVERSAMPLE);

    reg [15:0] cnt_baud;
    reg [15:0] cnt_x16;

    // 波特率时钟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_baud  <= 16'd0;
            baud_tick <= 1'b0;
        end else if (baud_en) begin
            if (cnt_baud == DIVISOR - 1) begin
                cnt_baud  <= 16'd0;
                baud_tick <= 1'b1;
            end else begin
                cnt_baud  <= cnt_baud + 1'b1;
                baud_tick <= 1'b0;
            end
        end else begin
            cnt_baud  <= 16'd0;
            baud_tick <= 1'b0;
        end
    end

    // 16x 过采样时钟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_x16        <= 16'd0;
            baud_tick_x16  <= 1'b0;
        end else if (baud_en) begin
            if (cnt_x16 == DIVISOR_X16 - 1) begin
                cnt_x16       <= 16'd0;
                baud_tick_x16 <= 1'b1;
            end else begin
                cnt_x16       <= cnt_x16 + 1'b1;
                baud_tick_x16 <= 1'b0;
            end
        end else begin
            cnt_x16       <= 16'd0;
            baud_tick_x16 <= 1'b0;
        end
    end

endmodule
```

### 13.3 发送器状态机

```verilog
// TX 状态机（两段式）
localparam [2:0] S_TX_IDLE  = 3'b001,
                 S_TX_START = 3'b010,
                 S_TX_DATA  = 3'b100,
                 S_TX_PARITY= 3'b011,
                 S_TX_STOP  = 3'b110;

reg [2:0]  tx_state_cur, tx_state_nxt;
reg [3:0]  tx_bit_cnt;          // 已发送 bit 计数
reg [7:0]  tx_shift_reg;        // 移位寄存器
reg        tx_parity_bit;

// 组合逻辑：次态 + 输出
always @(*) begin
    tx_state_nxt  = tx_state_cur;
    tx_serial_out = 1'b1;       // 默认高电平（IDLE）

    case (tx_state_cur)
        S_TX_IDLE: begin
            tx_serial_out = 1'b1;
            if (tx_start && !tx_fifo_empty)
                tx_state_nxt = S_TX_START;
        end
        S_TX_START: begin
            tx_serial_out = 1'b0;     // 起始位 = 0
            if (baud_tick)
                tx_state_nxt = S_TX_DATA;
        end
        S_TX_DATA: begin
            tx_serial_out = tx_shift_reg[0];   // LSB 先发
            if (baud_tick) begin
                if (tx_bit_cnt == DATA_WIDTH - 1)
                    tx_state_nxt = PARITY_EN ? S_TX_PARITY : S_TX_STOP;
            end
        end
        S_TX_PARITY: begin
            tx_serial_out = tx_parity_bit;
            if (baud_tick)
                tx_state_nxt = S_TX_STOP;
        end
        S_TX_STOP: begin
            tx_serial_out = 1'b1;     // 停止位 = 1
            if (baud_tick)
                tx_state_nxt = S_TX_IDLE;
        end
        default: tx_state_nxt = S_TX_IDLE;
    endcase
end
```

### 13.4 接收器状态机（16x 过采样）

```verilog
// RX 状态机
localparam [2:0] S_RX_IDLE  = 3'b001,
                 S_RX_START = 3'b010,
                 S_RX_DATA  = 3'b100,
                 S_RX_PARITY= 3'b011,
                 S_RX_STOP  = 3'b110;

reg [2:0]  rx_state_cur, rx_state_nxt;
reg [3:0]  rx_bit_cnt;
reg [7:0]  rx_shift_reg;
reg [3:0]  rx_sample_cnt;       // 过采样计数器（0~15）

// 组合逻辑
always @(*) begin
    rx_state_nxt = rx_state_cur;

    case (rx_state_cur)
        S_RX_IDLE: begin
            if (rx_synced == 1'b0)    // 检测到下降沿
                rx_state_nxt = S_RX_START;
        end
        S_RX_START: begin
            if (baud_tick_x16) begin
                if (rx_sample_cnt == 4'd7) begin
                    // 半 bit，居中采样
                    if (rx_synced == 1'b0)
                        rx_state_nxt = S_RX_DATA;   // 确认起始位
                    else
                        rx_state_nxt = S_RX_IDLE;   // 噪声，回 IDLE
                end
            end
        end
        S_RX_DATA: begin
            if (baud_tick_x16 && rx_sample_cnt == 4'd7) begin
                // 每 16 个过采样周期采样 1 bit
                if (rx_bit_cnt == DATA_WIDTH - 1)
                    rx_state_nxt = PARITY_EN ? S_RX_PARITY : S_RX_STOP;
            end
        end
        S_RX_PARITY: begin
            if (baud_tick_x16 && rx_sample_cnt == 4'd7)
                rx_state_nxt = S_RX_STOP;
        end
        S_RX_STOP: begin
            if (baud_tick_x16 && rx_sample_cnt == 4'd7) begin
                // 检查 STOP 位
                rx_state_nxt = S_RX_IDLE;
            end
        end
        default: rx_state_nxt = S_RX_IDLE;
    endcase
end
```

### 13.5 RTL 实现检查清单

| 检查项 | 说明 |
|--------|------|
| 波特率发生器参数化 | `CLK_FREQ` 和 `BAUD_RATE` 使用 parameter，禁止硬编码 |
| 过采样倍数参数化 | `OVERSAMPLE` 可配置（8x / 16x） |
| 发送器 LSB 先发 | 移位寄存器右移，`shift_reg >> 1` |
| 接收器采样点居中 | 过采样计数器到 7~8 时采样 |
| 帧错误检测 | STOP 位采样值为 0 时置帧错误标志 |
| 溢出检测 | RX FIFO 满且新数据到达时置溢出标志 |
| FIFO 状态信号 | `full`, `empty`, `almost_full`, `almost_empty` |
| 中断输出 | TX 空、RX 非空、帧错误、溢出等中断源 |
| 低功耗 | 空闲时波特率发生器可关闭 |
| 复位行为 | 所有寄存器异步复位，TX 输出高电平（IDLE） |

---

## 14. 参考资料

| 文档 | 说明 |
|------|------|
| TIA/EIA-232-F | RS-232 物理层标准 |
| TIA/EIA-422-B | RS-422 差分传输标准 |
| TIA/EIA-485-A | RS-485 多点总线标准 |
| 16550 UART Datasheet | 经典 UART 芯片，定义 FIFO 寄存器模型 |
| ARM PL011 (PrimeCell UART) | ARM 标准 UART IP |
| ARM PL011 Technical Reference Manual | ARM UART 寄存器定义和时序规范 |
