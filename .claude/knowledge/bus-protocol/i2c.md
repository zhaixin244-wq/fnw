# I2C 接口协议

> **用途**：双线制同步串行总线，多主多从半双工通信
> **规范版本**：NXP I2C-bus specification v6.0 (UM10204)
> **典型应用**：传感器、EEPROM、PMIC 配置、板级芯片间通信

---

## 1. 协议概述

I2C（Inter-Integrated Circuit）是由 Philips（现 NXP）开发的双线制同步串行总线协议，用于 IC 之间的短距离通信。

**核心特征**：

| 特性 | 说明 |
|------|------|
| 信号线数量 | 2 根：SCL（Serial Clock Line）和 SDA（Serial Data Line） |
| 通信方向 | 半双工（同一时刻数据单向传输） |
| 拓扑结构 | 多主多从（Multi-Master Multi-Slave） |
| 输出类型 | 开漏（Open-Drain）或开集（Open-Collector），需外部上拉电阻 |
| 寻址方式 | 7 位寻址（最多 112 个从设备）或 10 位寻址（最多 1024 个从设备） |
| 仲裁方式 | 基于线与（Wired-AND）逻辑的无损仲裁 |
| 时钟拉伸 | 从设备可拉低 SCL 暂停通信（Clock Stretching） |
| 最大电容 | 总线电容 ≤ 400 pF（限制总线设备数和走线长度） |

**总线拓扑**：

```
              Vdd          Vdd
               |            |
               R            R        R = 上拉电阻 (典型 4.7kΩ)
               |            |
    SCL -------+---+---+---+---- SCL
                |   |   |
    SDA -------+---+---+---+---- SDA
                |   |   |
             +--+ +--+ +--+
             |MCU| |U1| |U2|
             +--+ +--+ +--+
              Master Slave Slave
```

所有设备的 SCL 和 SDA 引脚均为开漏输出，挂接在同一总线上。上拉电阻将总线默认拉高至 Vdd，任何设备均可通过拉低总线来驱动信号。

---

## 2. 信号表

| 信号名 | 全称 | 方向 | 类型 | 功能描述 |
|--------|------|------|------|----------|
| `SCL` | Serial Clock Line | 双向 | 开漏 | 时钟信号，由 Master 产生；从设备可通过 Clock Stretching 拉低 |
| `SDA` | Serial Data Line | 双向 | 开漏 | 数据信号，Master 和 Slave 均可驱动；传输地址、数据、ACK/NACK |

**方向说明**：
- SCL 和 SDA 均为双向开漏信号，所有设备共享同一线路
- SCL 在标准模式下由 Master 独占驱动，从设备仅在 Clock Stretching 时驱动
- SDA 在数据传输阶段由发送方驱动（Master 发写数据/地址时由 Master 驱动，Slave 发读数据时由 Slave 驱动）
- ACK 阶段由接收方驱动（Master 写时 Slave 发 ACK，Master 读时 Master 发 ACK/NACK）

**地址保留**：

| 地址 (7-bit) | 用途 |
|--------------|------|
| `0000 000` | General Call 地址 |
| `0000 001` | START Byte（CBUS 兼容） |
| `0000 01x` | 保留用于不同总线格式 |
| `0000 1xx` | 高速模式（Hs-mode）Master Code |
| `0000 11x` | 10-bit 寻址的保留地址 |
| `1111 0xx` | 10-bit 寻址的从设备地址前缀 |
| `1111 1xx` | 保留（`1111 111` = 保留，`1111 0xx` 用于 10-bit） |

---

## 3. 电气特性

### 3.1 开漏输出原理

```
         Vdd
          |
          R (上拉电阻)
          |
    SDA --+---> 到其他设备
          |
       +--+--+
       | NMOS |  (设备内部)
       +--+--+
          |
         GND
```

- 设备输出 `0`：NMOS 导通，总线拉低到 GND
- 设备输出 `1`（释放总线）：NMOS 截止，总线由上拉电阻拉高到 Vdd
- 线与逻辑：任何设备拉低 → 总线为低；所有设备释放 → 总线为高

### 3.2 上拉电阻计算

上拉电阻 `Rp` 由总线电容和上升时间要求决定：

```
Rp(min) = (Vdd - Vol(max)) / Iol       — 由灌电流能力决定
Rp(max) = Tr / (0.8473 × Cb)           — 由上升时间要求决定
```

| 参数 | 说明 | 典型值 |
|------|------|--------|
| `Vdd` | 电源电压 | 3.3V 或 5V |
| `Vol(max)` | 最大输出低电平 | 0.4V |
| `Iol` | 灌电流能力 | 3 mA（标准 I/O） |
| `Tr` | 最大上升时间 | 依模式而定 |
| `Cb` | 总线电容 | 典型 50-200 pF，最大 400 pF |

**典型值**：Vdd = 3.3V，Cb ≈ 100 pF 时，Rp 典型 4.7 kΩ。

### 3.3 工作模式与速率

| 模式 | 最大速率 | 最大上升时间 Tr | 最大下降时间 Tf | 驱动能力 |
|------|----------|----------------|----------------|----------|
| Standard Mode (Sm) | 100 kbit/s | 1000 ns | 300 ns | 3 mA |
| Fast Mode (Fm) | 400 kbit/s | 300 ns | 300 ns | 3 mA |
| Fast Mode Plus (Fm+) | 1 Mbit/s | 120 ns | 120 ns | 20 mA |
| High-speed Mode (Hs) | 3.4 Mbit/s | 80 ns | 80 ns | 20 mA (mA 级) |
| Ultra-fast Mode (UFm) | 5 Mbit/s | - | 120 ns | 单向推挽，无 SCL |

### 3.4 电气参数（3.3V 系统）

| 参数 | 符号 | 最小值 | 典型值 | 最大值 | 单位 |
|------|------|--------|--------|--------|------|
| 输入高电平 | Vih | 0.7 × Vdd | - | Vdd + 0.5 | V |
| 输入低电平 | Vil | -0.5 | - | 0.3 × Vdd | V |
| 输出低电平 @ 3mA | Vol | - | - | 0.4 | V |
| 输出低电平 @ 20mA (Fm+) | Vol | - | - | 0.4 | V |
| 噪声容限 | Vn | 0.1 × Vdd | - | - | V |

---

## 4. 起始和停止条件

I2C 通信由 START 条件发起，由 STOP 条件结束。

**定义**：
- **START (S)**：SCL 为高电平期间，SDA 从高到低的跳变（下降沿）
- **STOP (P)**：SCL 为高电平期间，SDA 从低到高的跳变（上升沿）
- **Repeated START (Sr)**：在不产生 STOP 的情况下，再次产生 START 条件，用于组合读写事务

**ASCII 波形**：

```
START 条件:                        STOP 条件:

SCL  ----------+        +---       SCL  ----------+        +---
               |        |                       |        |
               +--------+                       +--------+

SDA  -------+     +-----           SDA  ---+          +-------
            |     |                        |          |
            +-----+                        +----------+

       SDA 在 SCL=1       SDA 在 SCL=1
       时下降 → START     时上升 → STOP
```

**注意事项**：
- SDA 必须在 SCL 为高电平期间保持稳定（数据有效窗口）
- 仅在 START/STOP 条件时，SDA 才允许在 SCL 高电平时变化
- 如果 SDA 在 SCL 高电平期间变化但不构成 START/STOP，则属于异常情况

---

## 5. 数据传输格式

### 5.1 位传输规则

- **数据采样**：接收方在 SCL 为高电平期间采样 SDA
- **数据变化**：发送方仅在 SCL 为低电平期间改变 SDA
- **MSB 优先**：每个字节的最高位（bit[7]）先发送

```
SCL     +---+   +---+   +---+   +---+
        |   |   |   |   |   |   |   |
    ----+   +---+   +---+   +---+   +---
           1       0       1       0

SDA     +-------+       +-------+
        |       |       |       |
    ----+       +-------+       +-------
           bit7=1  bit6=0  bit5=1  bit4=0
```

### 5.2 字节格式

每个传输的字节为 8 bit，后面跟随 1 bit 的 ACK/NACK：

```
+---+---+---+---+---+---+---+---+---+
| B7| B6| B5| B4| B3| B2| B1| B0|ACK|
+---+---+---+---+---+---+---+---+---+
|<-------- 8 bit 数据 ------->|1 bit|
```

- **ACK (Acknowledge)**：接收方在第 9 个时钟脉冲期间将 SDA 拉低，表示成功接收
- **NACK (Not Acknowledge)**：接收方在第 9 个时钟脉冲期间释放 SDA（保持高电平），表示拒绝或结束

**ACK/NACK 驱动方**：
- Master 发送地址/数据 → Slave 发 ACK/NACK
- Master 读取数据 → Master 发 ACK（继续读）或 NACK（读结束）

### 5.3 ACK/NACK 时序

```
SCL   ---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+  +---+
          | |   | |   | |   | |   | |   | |   | |   | |   |  |
      ----+ +---+ +---+ +---+ +---+ +---+ +---+ +---+ +---+  +---
            B7    B6    B5    B4    B3    B2    B1    B0    ACK

SDA   ---+ +-----+     +-----+     +-----+     +-----+    +------
          | |     |     |     |     |     |     |     |    |
      ----+ +     +-----+     +-----+     +-----+     +----+      ← Slave 拉低 ACK
```

---

## 6. 7 位寻址格式

7 位寻址是最常用的 I2C 寻址方式，地址空间为 `0x00 ~ 0x7F`（128 个地址，其中 16 个保留，实际可用 112 个）。

### 6.1 完整帧格式

```
 START | A6 A5 A4 A3 A2 A1 A0 R/W | ACK | D7 D6 D5 D4 D3 D2 D1 D0 | ACK | ... | STOP
  S    |<------ 7-bit 地址 ------>|  a  |<------- 8-bit 数据 ----->|  a  | ... |  P
```

| 字段 | 位数 | 说明 |
|------|------|------|
| START | 1 bit | 起始条件 |
| Slave Address | 7 bit | 从设备地址，MSB 先发 |
| R/W | 1 bit | 0 = Write，1 = Read |
| ACK | 1 bit | 从设备应答（SDA 拉低 = ACK） |
| Data | 8 bit | 数据字节，可连续发送多个 |
| ACK/NACK | 1 bit | 每个数据字节后的应答 |
| STOP | 1 bit | 停止条件 |

### 6.2 读/写位

- **R/W = 0 (Write)**：Master 向 Slave 写入数据
- **R/W = 1 (Read)**：Master 从 Slave 读取数据

---

## 7. 10 位寻址格式

10 位寻址扩展了地址空间到 1024 个从设备地址，使用两个字节传输地址。

### 7.1 10 位写事务

```
 START | 1 1 1 1 0 A9 A8 0 | ACK | A7 A6 A5 A4 A3 A2 A1 A0 | ACK | Data | ACK | ... | STOP
  S    |<--- 第一字节 ----->|  a  |<----- 第二字节 --------->|  a  |      |  a  | ... |  P
```

- 第一字节：固定前缀 `11110` + 10 位地址的高 2 位 (A9:A8) + R/W=0
- 第二字节：10 位地址的低 8 位 (A7:A0)
- 后续数据字节正常传输

### 7.2 10 位读事务

读事务需要先用写操作设置地址指针，然后用 Repeated START 切换为读：

```
 START | 1 1 1 1 0 A9 A8 0 | ACK | A7 A6 A5 A4 A3 A2 A1 A0 | ACK |
  S    |<--- 写地址字节 --->|  a  |<----- 地址低 8 位 ------->|  a  |

  Sr   | 1 1 1 1 0 A9 A8 1 | ACK | Data | ACK | Data | NACK | STOP
  Sr   |<--- 读地址字节 --->|  a  |      |  a  |      |  n   |  P
```

- 第一段：写模式发送完整 10 位地址（设置从设备地址指针）
- Repeated START：不发 STOP，直接发 Sr
- 第二段：R/W=1 切换为读模式，从设备返回数据

---

## 8. 读写事务完整流程

### 8.1 写事务（Master → Slave）

```
Master:  S  | A6..A0 W | a | D7..D0 | a | D7..D0 | a | P
         ---+----------+---+--------+---+--------+---+---
SDA:    _| | |_|||_| |_| |_|||_|  |_| |_|||_|  |_| |_
         S   Addr  W  ACK  Data   ACK  Data   ACK  P

时序：   S  | Addr(7b) R/W | ACK | Data(8b) | ACK | Data(8b) | ACK | P
         |--+--+--+--+--+--+--+---+--+--+--+--+---+--+--+--+--+---+--|
```

**详细流程**：

| 步骤 | SCL | SDA | 说明 |
|------|-----|-----|------|
| 1 | 高→低 | 高→低 | Master 产生 START 条件 |
| 2 | 8 个脉冲 | Master 驱动 | Master 发送 7-bit 地址 + W(0) |
| 3 | 第 9 个脉冲 | Slave 拉低 | Slave 发送 ACK |
| 4 | 8 个脉冲 | Master 驱动 | Master 发送数据字节 1 |
| 5 | 第 9 个脉冲 | Slave 拉低 | Slave 发送 ACK |
| 6 | 重复 | 重复 | 继续发送更多数据字节... |
| N | 低→高 | 低→高 | Master 产生 STOP 条件 |

### 2.2 读事务（Slave → Master）

```
Master:  S  | A6..A0 R | a |      | a |      | n | P
         ---+----------+---+------+---+------+---+---
SDA:    _| |_|||_|  |_|  |_|||_|  |_|||_|  _| |_
         S   Addr  R  ACK  Data  ACK  Data NACK P

时序：   S  | Addr(7b) R/W | ACK | Data(8b) | ACK | Data(8b) | NACK | P
```

**详细流程**：

| 步骤 | SCL | SDA | 说明 |
|------|-----|-----|------|
| 1 | 高→低 | 高→低 | Master 产生 START 条件 |
| 2 | 8 个脉冲 | Master 驱动 | Master 发送 7-bit 地址 + R(1) |
| 3 | 第 9 个脉冲 | Slave 拉低 | Slave 发送 ACK |
| 4 | 8 个脉冲 | Slave 驱动 | Slave 返回数据字节 1 |
| 5 | 第 9 个脉冲 | Master 拉低 | Master 发送 ACK（继续读） |
| 6 | 8 个脉冲 | Slave 驱动 | Slave 返回数据字节 2 |
| 7 | 第 9 个脉冲 | Master 释放 | Master 发送 NACK（读结束） |
| 8 | 低→高 | 低→高 | Master 产生 STOP 条件 |

### 8.3 组合读写事务（使用 Repeated START）

```
写地址 → 读数据（典型场景：先发寄存器地址，再读数据）

Master:  S | A6..A0 W | a | RegAddr | a | Sr | A6..A0 R | a |      | n | P
         --+----------+---+---------+---+----+----------+---+------+---+---
SDA:    _| |_|||_|  |_| |_|||_|  |_|  |_|||_|  |_|  |_|||_|  _| |_
         S   Addr   W  ACK  Reg   ACK  Sr   Addr   R  ACK Data NACK P
```

---

## 9. 仲裁机制

### 9.1 线与逻辑

I2C 总线基于开漏输出和上拉电阻实现"线与"（Wired-AND）：
- 所有设备释放总线 → 总线为高（1）
- 任何设备拉低总线 → 总线为低（0）

### 9.2 仲裁过程

当多个 Master 同时发起通信时，通过逐位仲裁决定总线归属：

```
Master 1 发送:  1    1    0    1    ...
Master 2 发送:  1    1    1    0    ...
SDA 实际值:     1    1    0    (Master 2 失去仲裁)

                ^    ^    ^
                |    |    |--- Master 2 发 1，总线为 0 → Master 2 检测到冲突，退出
                |    |--------- 均发 1，无冲突
                |-------------- 均发 1，无冲突
```

**仲裁规则**：
- Master 每发送一位后，回读 SDA 检查是否与自身发送值一致
- 若 Master 发送 `1`，但回读到 `0` → 说明其他 Master 正在发送 `0`，该 Master 失去仲裁
- 失去仲裁的 Master 必须立即停止驱动总线，转为 Slave 模式或等待
- 仲裁过程无损：获胜的 Master 不会感知到仲裁发生

### 9.3 仲裁时序

```
       +---+   +---+   +---+   +---+
SCL    |   |   |   |   |   |   |   |
   ----+   +---+   +---+   +---+   +---

M1     +-------+       +-------+
SDA    |       |       |       |      ← Master 1: 发送 1 1 0 1
   ----+       +-------+       +---

M2     +-------+               +-------
SDA    |       |               |       ← Master 2: 发送 1 1 1 0
   ----+       +-------+-------+

实际   +-------+       +
SDA    |       |       |               ← 实际总线: 1 1 0 (M2 回读到 0 ≠ 发送的 1)
   ----+       +-------+
                                M2 退出仲裁，M1 继续
```

---

## 10. 时钟拉伸（Clock Stretching）

### 10.1 原理

Clock Stretching 允许从设备通过拉低 SCL 来暂停 Master 的时钟，为从设备争取处理时间。

```
正常时钟:
       +---+   +---+   +---+   +---+
SCL    |   |   |   |   |   |   |   |
   ----+   +---+   +---+   +---+   +---

Slave 时钟拉伸:
       +---+   +---+       +---+   +---+
SCL    |   |   |   |       |   |   |   |
   ----+   +---+   +-------+   +---+   +---
                       ^
                       | Slave 拉低 SCL，Master 无法产生下一个时钟沿
                       | Slave 释放 SCL 后，时钟恢复
```

### 10.2 实现方式

- SCL 为开漏输出，Slave 可在 Master 释放 SCL（高电平）后继续将其拉低
- Master 在每个 SCL 高电平阶段检测 SCL 是否真正到达高电平
- 若 Slave 拉低 SCL，Master 必须等待 SCL 被释放后再继续

### 10.3 应用场景

| 场景 | 说明 |
|------|------|
| 中断处理 | 从设备正在处理中断，无法立即响应数据请求 |
| 数据准备 | ADC 正在转换，EEPROM 正在写入页 |
| 缓冲管理 | 从设备 FIFO 已满/空，需要时间处理 |

### 10.4 注意事项

- 并非所有 I2C 设备都支持 Clock Stretching
- 部分 Master IP（特别是 FPGA 软核）可能不正确处理 Clock Stretching
- I2C v5.0+ 规定 Clock Stretching 可发生在 ACK 周期之后（SCL 低电平阶段）

---

## 11. 重复起始（Repeated START）

### 11.1 定义

Repeated START（Sr）是指在没有产生 STOP 条件的情况下，Master 再次发送 START 条件。其电气波形与 START 完全相同。

**用途**：
- 组合读写事务：先写寄存器地址，再读数据
- 维持总线所有权：不释放总线，防止其他 Master 介入
- 同一事务中切换数据方向

### 11.2 与 START 的区别

| 条件 | START (S) | Repeated START (Sr) |
|------|-----------|---------------------|
| 前置条件 | 总线空闲（SCL=1, SDA=1） | 前一帧数据传输完成（ACK 之后） |
| 前一事件 | STOP 或总线空闲 | 无 STOP，直接生成 |
| 电气波形 | 完全相同 | 完全相同 |
| 总线状态 | 未锁定 | Master 保持总线所有权 |

### 11.3 典型使用场景

```
场景：读取 EEPROM 某地址的数据

  S | DevAddr W | ACK | MemAddr | ACK | Sr | DevAddr R | ACK | Data | NACK | P
    | 0xA0    0 |  a  | 0x10    |  a  |    | 0xA0    1 |  a  | 0x55 |  n   |
```

---

## 12. SMBus 扩展

SMBus（System Management Bus）是基于 I2C 的子集扩展，增加了系统管理功能。

### 12.1 SMBus 与 I2C 的主要差异

| 特性 | I2C | SMBus |
|------|-----|-------|
| 最低速率 | 无限制 | 10 kHz（超时检测需要） |
| 最高速率 | 3.4 Mbit/s (Hs) | 400 kbit/s (Fm) |
| 电压电平 | 无限制（可 5V） | 固定 3.3V（或 5V，v1.x） |
| 逻辑低阈值 | 0.3 × Vdd | 固定 0.8V |
| 逻辑高阈值 | 0.7 × Vdd | 固定 2.1V |
| 超时 | 无 | 有（Clock 低 ≤ 25 ms，数据低 ≤ 35 ms） |
| 地址 | 7-bit / 10-bit | 仅 7-bit |
| ALERT | 无 | 有（专用中断线，可选） |
| PEC | 无 | 可选 CRC-8 校验 |

### 12.2 SMBus 超时机制

| 超时类型 | 最大时间 | 说明 |
|----------|----------|------|
| Clock Low Timeout | 25 ms | SCL 被拉低超过此时间视为超时 |
| Data Low Timeout | 35 ms | SDA 被拉低超过此时间视为超时 |
| Cumulative Clock Low | 25 ms | 单次传输中 SCL 低电平累计时间 |

超时后 Master 必须产生 9 个时钟脉冲来恢复总线。

### 12.3 PEC（Packet Error Code）

PEC 使用 CRC-8 校验，覆盖整个消息（地址 + 数据）：

```
 S | Addr W | ACK | Command | ACK | Data | ACK | PEC | ACK | P
   | 0xA0 0 |  a  | 0x10    |  a  | 0x55 |  a  | CRC |  a  |
```

- CRC 多项式：`X^8 + X^2 + X^1 + 1`（即 0x07）
- 初始化值：`0x00`
- PEC 覆盖：从 START 之后的第一个字节到数据的最后一个字节（不含 PEC 本身）
- PEC 为可选特性，通过 SMBus Host 支持

### 12.4 ALERT 信号

- ALERT 是可选的第三根信号线，低电平有效
- 从设备通过拉低 ALERT 通知主机有事件发生
- 主机通过 SMBus 的 ALERT Response Address (0x0C) 轮询识别告警设备

---

## 13. 设计注意事项

### 13.1 数字滤波与毛刺抑制

**问题**：总线上的毛刺（Glitch）可能导致错误的 START/STOP 检测或数据误采样。

**解决方案**：

| 方法 | 实现 | 适用场景 |
|------|------|----------|
| 数字滤波器 | 对 SCL/SDA 进行 N 次采样（典型 3-5 次），取多数表决 | FPGA/ASIC 实现 |
| 模拟滤波 | RC 低通滤波器，截止频率 ≥ 5 × SCL 频率 | PCB 设计 |
| Spike 抑制 | 规范规定 Hs-mode 下 ≤ 50 ns 的毛刺可忽略 | Hs-mode |

**RTL 数字滤波器示意**：

```verilog
// SCL/SDA 同步 + 滤波
reg [2:0] scl_sync, sda_sync;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scl_sync <= 3'b111;
        sda_sync <= 3'b111;
    end else begin
        scl_sync <= {scl_sync[1:0], scl_i};
        sda_sync <= {sda_sync[1:0], sda_i};
    end
end
wire scl_filt = &scl_sync;   // 连续 3 周期高才认为高
wire sda_filt = &sda_sync;
```

### 13.2 总线挂死恢复（Bus Recovery）

**场景**：从设备在传输中途复位或异常，导致 SDA 被持续拉低（总线挂死）。

**恢复方法**：

1. Master 检测到 SDA 持续低电平超时
2. Master 产生额外的时钟脉冲（9 个以上），使 Slave 释放 SDA
3. Master 产生 STOP 条件复位总线

```
挂死恢复时序：
SCL   _  _  _  _  _  _  _  _  _
     | || || || || || || || || |
      _  _  _  _  _  _  _  _  _  ___
                                    |
SDA   _____________________________|
      <-- Slave 拉低 --> | Master 产生 9 个时钟后 SDA 释放
```

**FPGA 实现**：在 Master IP 中加入 Bus Timeout 检测，超时后执行总线恢复序列。

### 13.3 仲裁失败处理

| 处理方式 | 说明 |
|----------|------|
| 自动重试 | 仲裁失败后等待随机延迟，重新尝试 |
| 错误上报 | 向软件层报告仲裁失败事件 |
| 优先级策略 | 给高优先级事务配置更短的重试间隔 |

### 13.4 上电初始化

| 步骤 | 操作 |
|------|------|
| 1 | 检测 SCL 和 SDA 是否均为高（总线空闲） |
| 2 | 若 SDA 为低，产生 9 个时钟脉冲释放总线 |
| 3 | 产生 STOP 条件 |
| 4 | 正常开始通信 |

### 13.5 PCB 设计要点

| 要点 | 说明 |
|------|------|
| 上拉电阻位置 | 靠近总线物理中心，减小反射 |
| 走线长度 | 尽量短，< 30 cm（标准模式），< 10 cm（Fm+） |
| 总线电容 | 每个设备 ≤ 10 pF，总计 ≤ 400 pF |
| ESD 保护 | TVS 二极管，电容 < 5 pF |
| 信号完整性 | 避免 Stub，使用 daisy-chain 拓扑 |

---

## 14. Master RTL 实现要点

### 14.1 模块架构

```
+----------------------------------------------+
|              i2c_master                       |
|  +---------+  +----------+  +--------------+ |
|  | Clock   |  | Bit      |  | FSM          | |
|  | Divider |→ | Counter  |→ | (Idle/Start/ | |
|  |         |  |          |  |  Addr/Data/  | |
|  +---------+  +----------+  |  Ack/Stop)   | |
|                             +--------------+ |
|  +---------+  +----------+                   |
|  | SCL/SDA |  | Shift    |                   |
|  | Driver  |← | Register |                   |
|  +---------+  +----------+                   |
|  +---------+                                  |
|  | Filter  |  (SCL/SDA 同步 + 滤波)          |
|  +---------+                                  |
+----------------------------------------------+
```

### 14.2 状态机设计

```
          +---------+
          | S_IDLE  |←──────────────────────────┐
          +---------+                            |
             | start_i                           |
             v                                   |
          +---------+                            |
          | S_START |                            |
          +---------+                            |
             | start_done                        |
             v                                   |
          +---------+   nack_i (无应答)          |
          | S_ADDR  |───────────────────────────→|→ S_IDLE (报错)
          +---------+                            |
             | addr_ack                          |
             v                                   |
          +---------+                            |
          | S_WRITE |                            |
          +---------+                            |
             | byte_done && last_byte            |
             v                                   |
          +---------+                            |
          | S_READ  |                            |
          +---------+                            |
             | byte_done && last_byte            |
             v                                   |
          +---------+                            |
          | S_ACK   |  (Master 发 ACK/NACK)      |
          +---------+                            |
             | ack_done                          |
             v                                   |
          +---------+   要发 Sr                  |
          | S_STOP  |────────────→ S_START       |
          +---------+                            |
             | stop_done                         |
             +───────────────────────────────────→
```

### 14.3 时钟分频器

I2C Master 需要将系统时钟分频到目标 SCL 频率。SCL 占空比通常为 50%。

```verilog
// 分频参数计算
// CLK_FREQ = 100 MHz, SCL_FREQ = 400 kHz (Fast Mode)
// DIVISOR = CLK_FREQ / (4 × SCL_FREQ) = 100M / 1.6M = 62
// SCL 每个 1/4 周期 = 62 个 clk 周期

parameter DIV_HF = CLK_FREQ / (4 * SCL_FREQ);  // 1/4 周期计数值

reg [15:0] clk_cnt;
reg [1:0]  scl_phase;  // 00=高前半 01=高后半 10=低前半 11=低后半

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt   <= 16'd0;
        scl_phase <= 2'b00;
    end else if (clk_cnt == DIV_HF - 1) begin
        clk_cnt   <= 16'd0;
        scl_phase <= scl_phase + 2'b01;
    end else begin
        clk_cnt <= clk_cnt + 16'd1;
    end
end
```

### 14.4 位计数器

```verilog
reg [3:0] bit_cnt;  // 0~8 (8 data + 1 ACK)

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        bit_cnt <= 4'd0;
    else if (state_cur == S_IDLE || bit_done)
        bit_cnt <= 4'd0;
    else if (scl_rising)  // 每个 SCL 上升沿计数
        bit_cnt <= bit_cnt + 4'd1;
end

assign bit_done = (bit_cnt == 4'd8) && scl_rising;
```

### 14.5 移位寄存器

```verilog
reg [7:0] tx_shift;
reg [7:0] rx_shift;

// 发送移位（SCL 下降沿移出）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tx_shift <= 8'd0;
    else if (load_shift)
        tx_shift <= tx_data_i;
    else if (scl_falling && state_cur == S_ADDR)
        tx_shift <= {tx_shift[6:0], 1'b0};
end

// 接收移位（SCL 上升沿采样）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        rx_shift <= 8'd0;
    else if (scl_rising && (state_cur == S_READ))
        rx_shift <= {rx_shift[6:0], sda_filt};
end

assign sda_o = tx_shift[7];  // MSB 先出
```

### 14.6 SCL/SDA 驱动控制

```verilog
// SCL 驱动（开漏：0=拉低，1=释放/高阻）
reg scl_oe;
always @(*) begin
    case (state_cur)
        S_IDLE:  scl_oe = 1'b0;  // 释放 SCL
        S_START: scl_oe = (scl_phase != 2'b01);  // START: SCL 高时拉低 SDA
        S_ADDR,
        S_WRITE,
        S_READ,
        S_ACK:   scl_oe = (scl_phase[1] == 1'b0);  // 低半周期拉低 SCL
        S_STOP:  scl_oe = (scl_phase != 2'b01);  // STOP: SCL 高时释放 SDA
        default: scl_oe = 1'b0;
    endcase
end

// SDA 驱动
reg sda_oe;
always @(*) begin
    case (state_cur)
        S_IDLE:  sda_oe = 1'b0;
        S_START: sda_oe = 1'b1;  // 拉低 SDA 产生 START
        S_ADDR,
        S_WRITE: sda_oe = (scl_phase[1] || !scl_phase[0]); // SCL 低时驱动数据
        S_READ:  sda_oe = 1'b0;  // 读模式释放 SDA
        S_ACK:   sda_oe = send_nack;  // Master ACK/NACK
        S_STOP:  sda_oe = 1'b1;  // 拉低 SDA 再释放产生 STOP
        default: sda_oe = 1'b0;
    endcase
end
```

### 14.7 SCL 同步与 Clock Stretching 检测

```verilog
// SCL 输入同步（防止亚稳态）
reg [1:0] scl_in_sync;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        scl_in_sync <= 2'b11;
    else
        scl_in_sync <= {scl_in_sync[0], scl_io};
end

// Clock Stretching 检测
wire scl_stretched = scl_oe && !scl_in_sync[1];  // Master 释放但 SCL 仍为低

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        stretch_cnt <= 16'd0;
    else if (scl_stretched)
        stretch_cnt <= stretch_cnt + 16'd1;
    else
        stretch_cnt <= 16'd0;
end

assign stretch_timeout = (stretch_cnt >= STRETCH_MAX);
```

### 14.8 关键设计参数

| 参数 | 典型值 | 说明 |
|------|--------|------|
| 系统时钟频率 | 50-200 MHz | FPGA 主时钟 |
| SCL 分频比 | 125-500 | 依目标 SCL 频率而定 |
| 滤波采样数 | 3-5 次 | 数字滤波深度 |
| Stretch 超时 | 25 ms | 对应 SMBus 规范 |
| FIFO 深度 | 8-16 byte | TX/RX 缓冲 |

### 14.9 仲裁检测逻辑

```verilog
// SDA 回读仲裁检测
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        arb_lost <= 1'b0;
    else if (state_cur == S_IDLE)
        arb_lost <= 1'b0;
    else if (scl_rising && sda_oe && !sda_filt)
        arb_lost <= 1'b1;  // Master 发 1 但总线读到 0 → 仲裁失败
end

// 仲裁失败后立即退出
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state_cur <= S_IDLE;
    else if (arb_lost)
        state_cur <= S_IDLE;  // 仲裁失败，立即释放总线
    else
        state_cur <= state_nxt;
end
```

### 14.10 接口信号建议

```verilog
module i2c_master #(
    parameter CLK_FREQ   = 100_000_000,  // 系统时钟 100 MHz
    parameter SCL_FREQ   = 400_000,       // I2C SCL 400 kHz
    parameter FILTER_CNT = 3,             // 数字滤波深度
    parameter STRETCH_MAX = 2_500_000     // Clock Stretch 超时 (25ms @ 100MHz)
)(
    // Clock & Reset
    input  wire        clk,
    input  wire        rst_n,

    // Control Interface
    input  wire        start_i,       // 启动传输
    input  wire [6:0]  dev_addr_i,    // 从设备地址
    input  wire        rw_i,          // 0=Write, 1=Read
    input  wire [7:0]  tx_data_i,     // 发送数据
    input  wire        tx_valid_i,    // 发送数据有效
    output wire        tx_ready_o,    // 可接收发送数据
    output wire [7:0]  rx_data_o,     // 接收数据
    output wire        rx_valid_o,    // 接收数据有效
    input  wire        rx_ready_i,    // 接收方就绪
    output wire        done_o,        // 传输完成
    output wire        arb_lost_o,    // 仲裁失败
    output wire        nack_o,        // 收到 NACK

    // I2C Bus (开漏，需外部上拉)
    inout  wire        scl_io,
    inout  wire        sda_io
);
```

### 14.11 SVA 断言建议

```systemverilog
// SCL 频率检查
property p_scl_period;
    @(posedge clk) disable iff (!rst_n)
    $rose(scl_io) |-> ##[MIN_DIV-1:MAX_DIV+1] $fell(scl_io);
endproperty
assert_scl_period: assert property (p_scl_period);

// SDA 在 SCL 高电平期间稳定（数据有效窗口）
property p_sda_stable_when_scl_high;
    @(posedge clk) disable iff (!rst_n)
    $rose(scl_io) |-> $stable(sda_io) throughout scl_io [*1:$] ##1 !scl_io;
endproperty
assert_sda_stable: assert property (p_sda_stable_when_scl_high);

// 仲裁失败后总线释放
property p_release_on_arb_lost;
    @(posedge clk) disable iff (!rst_n)
    $rose(arb_lost_o) |=> !sda_oe && !scl_oe;
endproperty
assert_release_on_arb: assert property (p_release_on_arb_lost);
```

---

## 附录

### A. 常见 I2C 设备地址表

| 设备类型 | 典型地址 (7-bit) | 常见型号 |
|----------|-----------------|----------|
| EEPROM | 0x50 ~ 0x57 | AT24C02/04/08/16 |
| 温度传感器 | 0x48 ~ 0x4B | LM75, TMP102 |
| 加速度计 | 0x1C / 0x1D | MMA8452, ADXL345 |
| 陀螺仪 | 0x68 / 0x69 | MPU6050, L3GD20 |
| 环境光传感器 | 0x29 / 0x39 / 0x49 | TSL2561, BH1750 |
| OLED 显示器 | 0x3C / 0x3D | SSD1306 |
| IO 扩展器 | 0x20 ~ 0x27 | MCP23017 |
| RTC | 0x68 | DS1307, DS3231 |
| ADC | 0x48 ~ 0x4B | ADS1115 |
| DAC | 0x60 ~ 0x67 | MCP4725 |

### B. 缩略语

| 缩写 | 全称 |
|------|------|
| I2C | Inter-Integrated Circuit |
| SCL | Serial Clock Line |
| SDA | Serial Data Line |
| ACK | Acknowledge |
| NACK | Not Acknowledge |
| SMBus | System Management Bus |
| PEC | Packet Error Code |
| Hs-mode | High-speed Mode |
| Fm+ | Fast Mode Plus |
| RTL | Register Transfer Level |
| FSM | Finite State Machine |
| MSB | Most Significant Bit |
| LSB | Least Significant Bit |

### C. 参考文档

| 编号 | 文档名 | 版本 | 说明 |
|------|--------|------|------|
| REF-001 | NXP I2C-bus specification (UM10204) | v6.0 | I2C 官方规范 |
| REF-002 | SMBus Specification | v3.2 | SMBus 规范 |
| REF-003 | I2C Bus FAQ - NXP | - | 常见问题解答 |
