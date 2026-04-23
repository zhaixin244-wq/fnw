# SPI 接口协议

> **用途**：同步串行外设接口，全双工主从通信
> **规范版本**：Motorola SPI（无正式标准，事实标准）
> **典型应用**：Flash 存储器、传感器、ADC/DAC、SD 卡、显示屏

---

## 1. 协议概述

SPI（Serial Peripheral Interface）是由 Motorola 在 1980 年代推出的同步串行通信协议。与 I2C 不同，SPI 没有正式的官方标准规范，但已成为嵌入式领域最广泛使用的外设接口之一。

**核心特征**：

| 特征 | 说明 |
|------|------|
| 通信方式 | 同步串行（由 SCLK 提供时钟） |
| 双工模式 | 全双工（MOSI 和 MISO 同时传输） |
| 拓扑结构 | 主从架构，单主机多从机 |
| 信号线数 | 4 线制（SCLK / MOSI / MISO / CS） |
| 寻址方式 | 片选（Chip Select）寻址，无地址字段 |
| 流控机制 | 无硬件流控（CS 为唯一仲裁手段） |
| 应答机制 | 无 ACK/NACK |
| 传输单位 | 通常 8-bit，可扩展至 16/32-bit |
| 最大速率 | 取决于从设备，通常 1~100 MHz |

**与 I2C 对比**：

| 项目 | SPI | I2C |
|------|-----|-----|
| 信号线 | 4 根（最少 3 根半双工） | 2 根（SDA + SCL） |
| 速率 | 高（可达 100 MHz+） | 中（标准 100K / 快速 400K / 高速 3.4M） |
| 全双工 | 是 | 否 |
| 寻址 | 片选线（每从机一根 CS） | 7-bit / 10-bit 地址 |
| 协议开销 | 极低（无地址/ACK） | 中等（地址 + ACK） |
| 从机数量 | 受限于 CS 引脚数 | 受限于地址空间（127 个） |
| 标准化 | 无正式标准 | NXP 正式标准 |

---

## 2. 信号定义

### 2.1 四根信号线

| 信号 | 全称 | 方向（Master 视角） | 说明 |
|------|------|---------------------|------|
| **SCLK** | Serial Clock | Master → Slave | 串行时钟，由 Master 产生 |
| **MOSI** | Master Out Slave In | Master → Slave | 主机发送、从机接收数据 |
| **MISO** | Master In Slave Out | Slave → Master | 从机发送、主机接收数据 |
| **CS/SS** | Chip Select / Slave Select | Master → Slave | 片选信号，低有效，每从机独立一根 |

> **注意**：部分文献使用 SS（Slave Select）代替 CS（Chip Select），含义相同。部分从设备使用 CS_N 或 NSS 命名。

### 2.2 信号极性

| 信号 | 有效电平 | 说明 |
|------|----------|------|
| CS | **低有效** | CS = 0 时从设备被选中，CS = 1 时从设备忽略总线 |
| SCLK | 取决于 CPOL | CPOL=0 时空闲为低，CPOL=1 时空闲为高 |
| MOSI / MISO | 无固定极性 | 数据在 SCLK 边沿驱动和采样 |

### 2.3 可选信号

某些 SPI 变体或特定设备会增加额外信号：

| 信号 | 说明 |
|------|------|
| WP / WP_N | Write Protect，低有效，保护 Flash 状态寄存器 |
| HOLD / HOLD_N | 暂停传输，低有效 |
| D[3:0] | QSPI 模式下的双向数据线 |

---

## 3. SPI 四种模式（CPOL / CPHA）

SPI 的时序由两个参数决定：**CPOL**（Clock Polarity）和 **CPHA**（Clock Phase），共产生四种模式。

### 3.1 参数定义

| 参数 | 全称 | 取值 | 含义 |
|------|------|------|------|
| **CPOL** | Clock Polarity | 0 | SCLK 空闲状态为 **低**（第一个边沿为上升沿） |
| | | 1 | SCLK 空闲状态为 **高**（第一个边沿为下降沿） |
| **CPHA** | Clock Phase | 0 | 数据在第一个时钟边沿 **采样**，第二个边沿 **切换** |
| | | 1 | 数据在第一个时钟边沿 **切换**，第二个时钟边沿 **采样** |

### 3.2 四种模式速查

| 模式 | CPOL | CPHA | 空闲状态 | 采样边沿 | 数据切换边沿 |
|------|------|------|----------|----------|-------------|
| **Mode 0** | 0 | 0 | SCLK = 0 | 上升沿采样 | 下降沿切换 |
| **Mode 1** | 0 | 1 | SCLK = 0 | 下降沿采样 | 上升沿切换 |
| **Mode 2** | 1 | 0 | SCLK = 1 | 下降沿采样 | 上升沿切换 |
| **Mode 3** | 1 | 1 | SCLK = 1 | 上升沿采样 | 下降沿切换 |

> **记忆口诀**：CPOL 决定空闲电平，CPHA 决定采样边沿。Mode 0 和 Mode 3 最常用。

### 3.3 ASCII 波形对比

以下展示四种模式下 8-bit 数据传输（以 Master 发送 8'b10110011 为例）。

#### Mode 0（CPOL=0, CPHA=0）— 最常用

```
CS_N    _____                                                     ___________
             |___________________________________________________|
SCLK    ______     ___     ___     ___     ___     ___     ___     ___________
                    |  |    |  |    |  |    |  |    |  |    |  |
MOSI    -----|  D7  |D6 |  D5  |D4 |  D3  |D2 |  D1  |D0 |------
             |  1   |0  |  1   |1  |  0   |0  |  1   |1  |
             |<--- MSB first --->|  |<--- LSB --->|
             采样↑     切换↓    采样↑    切换↓

边沿:        ↑采样  ↓切换  ↑采样  ↓切换  ↑采样  ↓切换  ↑采样  ↓切换
```

#### Mode 1（CPOL=0, CPHA=1）

```
CS_N    _____                                                     ___________
             |___________________________________________________|
SCLK    ______     ___     ___     ___     ___     ___     ___     ___________
                    |  |    |  |    |  |    |  |    |  |    |  |
MOSI    -----|  D7  |D6 |  D5  |D4 |  D3  |D2 |  D1  |D0 |------
                    |  1   |0  |  1   |1  |  0   |0  |  1   |1  |
             切换↑    采样↓   切换↑    采样↓

边沿:          ↑切换  ↓采样  ↑切换  ↓采样  ↑切换  ↓采样  ↑切换  ↓采样
```

#### Mode 2（CPOL=1, CPHA=0）

```
CS_N    _____                                                     ___________
             |___________________________________________________|
SCLK    --------     ___     ___     ___     ___     ___     ___  ---
                    |  |    |  |    |  |    |  |    |  |    |  |
MOSI    -----|  D7  |D6 |  D5  |D4 |  D3  |D2 |  D1  |D0 |------
             |  1   |0  |  1   |1  |  0   |0  |  1   |1  |

边沿:          ↓采样  ↑切换  ↓采样  ↑切换  ↓采样  ↑切换  ↓采样  ↑切换
```

#### Mode 3（CPOL=1, CPHA=1）

```
CS_N    _____                                                     ___________
             |___________________________________________________|
SCLK    --------     ___     ___     ___     ___     ___     ___  ---
                    |  |    |  |    |  |    |  |    |  |    |  |
MOSI    -----|  D7  |D6 |  D5  |D4 |  D3  |D2 |  D1  |D0 |------
                    |  1   |0  |  1   |1  |  0   |0  |  1   |1  |

边沿:        ↓切换  ↑采样  ↓切换  ↑采样  ↓切换  ↑采样  ↓切换  ↑采样
```

### 3.4 Mode 选择指南

| 从设备类型 | 常用模式 | 说明 |
|-----------|----------|------|
| SPI Flash（Winbond） | Mode 0 或 Mode 3 | W25Q 系列支持两种 |
| SPI Flash（Micron） | Mode 0 | M25P 系列 |
| 传感器（Bosch） | Mode 0 或 Mode 3 | BMI160 等 |
| ADC（ADS1292） | Mode 1 | CPHA=1 |
| OLED（SSD1306） | Mode 0 或 Mode 3 | 部分仅 Mode 3 |
| MicroSD | Mode 0 | 初始化后切换到 SD 模式 |

---

## 4. 传输时序

### 4.1 标准 8-bit 传输时序

以下为 Mode 0 下的标准 8-bit 全双工传输波形：

```
        ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
SCLK    │     │ │     │ │     │ │     │ │     │ │     │ │     │ │     │
    ────┘     └─┘     └─┘     └─┘     └─┘     └─┘     └─┘     └─┘     └────
        bit7    bit6    bit5    bit4    bit3    bit2    bit1    bit0

CS_N    __________________________________________________________________
        |
        |  ┌───┐       ┌───┐       ┌───┐       ┌───┐
MOSI    ──┘   └───────┘   └───────┘   └───────┘   └──────
        |   1     0       1     1     0     0     1     1
        |  D7          D6          D5          D4   ... D0

MISO    ─────┐   ┌───────────┐   ┌───────────┐   ┌────────
             └───┘           └───┘           └───┘
        |   0     1       1     0     1     1     0     0   (Slave 发送)
```

### 4.2 完整事务时序（CS 拉低 → 数据交换 → CS 拉高）

```
时间轴 →

        |<- CS建立 ->|<-------- 8-bit 数据传输 -------->|<- CS保持 ->|
                   |                                      |
CS_N    ───────────┐                                      ┌─────────────
                   |______________________________________|
                   |                                      |
                   bit7  bit6  bit5  bit4  bit3  bit2  bit1  bit0

SCLK    ───────────┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌─────
                   └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

MOSI    ───────────┤<D7 ><D6 ><D5 ><D4 ><D3 ><D2 ><D1 ><D0 >├─────────
                                                         ↑
MISO    ───────────┤<S7 ><S6 ><S5 ><S4 ><S3 ><S2 ><S1 ><S0 >├─────────

                   |<---->|                                |<---->|
                   tCSS                                     tCSH
                   CS建立时间                                CS保持时间
```

### 4.3 连续多字节传输

```
CS_N    __________________________________________________________________
        |                                                                |
        |  Byte 0                      |  Byte 1                      |
SCLK    ──┐┌┐┌┐┌┐┌┐┌┐┌┐┌──────────────┐┌┐┌┐┌┐┌┐┌┐┌┐┌────────────────────
         └┘└┘└┘└┘└┘└┘└┘               └┘└┘└┘└┘└┘└┘└┘
MOSI    ──┤D7..D0 ├────────────────────┤D7..D0 ├─────────────────────────
MISO    ──┤D7..D0 ├────────────────────┤D7..D0 ├─────────────────────────

        |<--- 8 SCLK cycles --->|idle|<--- 8 SCLK cycles --->|
```

> **注意**：CS 在多字节传输期间保持拉低，字节之间可有也可没有间隔。大多数 SPI Flash 要求 CS 在整个命令序列期间保持低电平。

---

## 5. 时钟极性与相位详解

### 5.1 CPOL — 时钟极性

```
CPOL = 0：SCLK 空闲为低
                    ___     ___     ___
SCLK    ___________|   |___|   |___|   |_____________
          idle=0    ↑     ↑     ↑     ↑
                  上升  下降  上升  下降
                  (第1) (第2) (第1) (第2)

CPOL = 1：SCLK 空闲为高
          _________     ___     ___     _____________
SCLK              |___|   |___|   |___|
          idle=1    ↑     ↑     ↑     ↑
                  下降  上升  下降  上升
                  (第1) (第2) (第1) (第2)
```

### 5.2 CPHA — 时钟相位

**CPHA = 0**：数据在第一个时钟边沿被**采样**，在第二个边沿**切换**。
- Master 和 Slave 在 CS 拉低时立即输出第一个数据位（D7）。
- 第一个 SCLK 边沿采样 D7，第二个边沿切换到 D6。

**CPHA = 1**：数据在第一个时钟边沿**切换**，在第二个边沿被**采样**。
- Master 和 Slave 在 CS 拉低时不立即输出数据，等待第一个 SCLK 边沿切换后才输出 D7。
- 第二个 SCLK 边沿采样 D7。

### 5.3 采样与切换关系表

| 模式 | SCLK 边沿编号 | CPOL=0 时边沿类型 | CPOL=1 时边沿类型 | 动作 |
|------|--------------|-------------------|-------------------|------|
| CPHA=0 | 第 1 个 | 上升沿 | 下降沿 | **采样** |
| | 第 2 个 | 下降沿 | 上升沿 | 切换 |
| | 第 3 个 | 上升沿 | 下降沿 | **采样** |
| | 第 4 个 | 下降沿 | 上升沿 | 切换 |
| CPHA=1 | 第 1 个 | 上升沿 | 下降沿 | 切换 |
| | 第 2 个 | 下降沿 | 上升沿 | **采样** |
| | 第 3 个 | 上升沿 | 下降沿 | 切换 |
| | 第 4 个 | 下降沿 | 上升沿 | **采样** |

---

## 6. 多从设备连接

### 6.1 方案一：独立片选（Independent CS）

每个从设备有独立的 CS 线，所有从设备共享 SCLK、MOSI、MISO。

```
                        ┌───────────┐
                   CS0──┤           │
              ┌────SCLK─┤  Slave 0  │
              │    MOSI─┤           │
              │    MISO─┤           │
              │         └───────────┘
              │         ┌───────────┐
              │    CS1──┤           │
  ┌───────┐   ├────SCLK─┤  Slave 1  │
  │       │   │    MOSI─┤           │
  │ Master├───┤    MISO─┤           │
  │       │   │         └───────────┘
  └───────┘   │         ┌───────────┐
              │    CS2──┤           │
              └────SCLK─┤  Slave 2  │
                   MOSI─┤           │
                   MISO─┤           │
                        └───────────┘
```

**优缺点**：

| 项目 | 说明 |
|------|------|
| 优点 | 任意时刻只选中一个从设备，MISO 无冲突；可对不同从设备使用不同 SPI 模式和速率 |
| 缺点 | CS 引脚数 = 从设备数，N 个从设备需要 N 根 CS 线 |
| 适用场景 | 从设备数量少（通常 ≤ 8），各设备 SPI 模式/速率不同 |

> **MISO 三态注意**：未被选中的从设备必须将 MISO 引脚置为高阻态（Hi-Z），否则会发生总线冲突。部分从设备自动实现此功能，部分需要外部上拉。

### 6.2 方案二：菊花链（Daisy Chain）

所有从设备串联，MOSI → Slave0 → Slave1 → Slave2 → MISO。

```
  ┌───────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐
  │       │CS──►│           │CS──►│           │CS──►│           │
  │ Master├SCLK►┤  Slave 0  ├SCLK►┤  Slave 1  ├SCLK►┤  Slave 2  │
  │       ├MOSI►┤           ├────►┤           ├────►┤           │
  │       │◄MISO┤           │◄────┤           │◄────┤           │
  └───────┘     └───────────┘     └───────────┘     └───────────┘
                  shift reg          shift reg          shift reg
```

**优缺点**：

| 项目 | 说明 |
|------|------|
| 优点 | 只需 1 根 CS，引脚开销低 |
| 缺点 | 数据必须穿过所有从设备，传输延迟 = 从设备数 × 数据宽度；所有从设备必须支持相同的 SPI 模式和数据宽度 |
| 适用场景 | LED 驱动器链（如 74HC595）、需要级联的同类设备 |

**菊花链传输原理**：

```
Master 发送 24-bit 数据到 3 个 8-bit 从设备：

SCLK:    ═══════════════════════════════════════════════
         |<-- 8 bits -->|<-- 8 bits -->|<-- 8 bits -->|

MOSI:    [A7...A0]──────► Slave 0 shift reg

Slave 0: [A7...A0]──────►[B7...B0]──► Slave 1 shift reg

Slave 1: [B7...B0]──────►[C7...C0]──► Slave 2 shift reg

Slave 2: [C7...C0]──────► MISO ──► Master

CS 拉高后，所有从设备锁存当前 shift reg 内容。
```

### 6.3 方案三：译码扩展（Decoder）

使用地址译码器（如 74HC138）将少量 Master CS 引脚扩展为多个 CS 输出。

```
  ┌───────┐   CS[1:0]   ┌──────────┐
  │       ├────────────►┤          ├──► CS0
  │ Master│   SCLK──────┤ 3-to-8   ├──► CS1
  │       │   MOSI──────┤ Decoder  ├──► CS2
  │       │   MISO◄─────┤ (74HC138)├──► CS3
  └───────┘             │          ├──► CS4
                        └──────────┘    ...
```

**2 根 CS 线可选 4 个从设备，3 根可选 8 个。**

---

## 7. 典型 SPI Flash 读写序列

以 Winbond W25Q 系列为例。

### 7.1 常用命令表

| 命令 | 编码 | 全称 | 说明 |
|------|------|------|------|
| `0x06` | Write Enable | WREN | 写使能，擦除/写入前必须发送 |
| `0x04` | Write Disable | WRDI | 写禁止 |
| `0x03` | Read Data | READ | 标准读，地址 24-bit，连续读 |
| `0x0B` | Fast Read | FREAD | 快速读，含 8-bit dummy |
| `0x02` | Page Program | PP | 页编程（写入），最多 256 字节/页 |
| `0x20` | Sector Erase | SE | 扇区擦除（4 KB） |
| `0x52` | Block Erase 32KB | BE32 | 32 KB 块擦除 |
| `0xD8` | Block Erase 64KB | BE64 | 64 KB 块擦除 |
| `0x05` | Read Status Register-1 | RDSR | 读状态寄存器，检查 BUSY 位 |
| `0x9F` | Read JEDEC ID | RDID | 读取制造商 ID 和设备 ID |

### 7.2 标准读操作（0x03）

```
CS_N    _________________________________________________
        |                                               |
        |  CMD        ADDR[23:16]  ADDR[15:8]  ADDR[7:0]  | D0    D1    D2  ...
SCLK    ──┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌──┐┌┐┌┐┌──
         └┘└┘└┘└┘└┘  └┘└┘└┘└┘└┘  └┘└┘└┘└┘└┘  └┘└┘└┘└┘└┘  └┘└┘└┘  └┘└┘└┘

MOSI    ──┤0 0 0 0 0 0 1 1├──┤A23..A16 ├──┤A15..A8  ├──┤A7..A0  ├──  (停止驱动)
                                                                  ↓
MISO    ──┤  (Hi-Z)  ├──────────────────────────────────┤D7..D0  ├──┤D7..D0 ├──
          Slave 输出数据 ─────────────────────────────────────────────►
```

**时序说明**：
1. CS 拉低
2. Master 在 MOSI 上发送 8-bit 命令（0x03）
3. Master 在 MOSI 上发送 24-bit 地址（3 字节，MSB first）
4. Slave 在 MISO 上输出数据字节，地址自动递增，可连续读取
5. CS 拉高，传输结束

### 7.3 页编程操作（写入，0x02）

```
步骤：

1. 发送 WREN（0x06）：CS拉低 → 发送0x06 → CS拉高
2. 发送 PP（0x02）+ 地址 + 数据：CS拉低 → 发送0x02 → 发送24-bit地址 → 发送1~256字节数据 → CS拉高
3. 轮询 RDSR（0x05）等待 BUSY=0：
   CS拉低 → 发送0x05 → 读取Status Reg → 检查Bit0（BUSY）→ CS拉高
   重复直到 BUSY=0
```

```
WREN 命令：
CS_N    _______________________________
        |                             |
MOSI    ──┤0 0 0 0 0 1 1 0├────────────  (0x06)
SCLK    ──┐┌┐┌┐┌┐┌┐┌┐┌┐┌──────────────

Page Program：
CS_N    __________________________________________________________________________
        |                                                                       |
MOSI    ──┤0 0 0 0 0 0 1 0├──┤A23..A16├──┤A15..A8 ├──┤A7..A0 ├──┤D0 ├──┤D1 ├──...
SCLK    ──┐┌┐┌┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌┐┌┐┌──┐┌┐┌──┐┌┐┌──
          (CMD=0x02)        (3-byte addr)               (data bytes, up to 256)
```

### 7.4 扇区擦除操作（0x20）

```
1. WREN（0x06）
2. CS拉低 → 发送0x20 → 发送24-bit扇区地址 → CS拉高
3. 等待 BUSY=0（典型擦除时间：45~400 ms）
```

### 7.5 读状态寄存器（0x05）

```
CS_N    ___________________________________________
        |                                         |
MOSI    ──┤0 0 0 0 0 1 0 1├────────────────────────  (0x05)
MISO    ──────────────────┤S7  S6  S5 ... S1  S0├─  (Status Register)
SCLK    ──┐┌┐┌┐┌┐┌┐┌┐┌┐┌──┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌────

Status Register 1 位域：
Bit 7: SRP    (Status Register Protect)
Bit 6: SEC    (Sector/Block Protect)
Bit 5: TB     (Top/Bottom Protect)
Bit 4: BP2    (Block Protect Bit 2)
Bit 3: BP1    (Block Protect Bit 1)
Bit 2: BP0    (Block Protect Bit 0)
Bit 1: WEL    (Write Enable Latch)
Bit 0: BUSY   (1=忙，0=空闲)
```

---

## 8. 时钟频率限制

### 8.1 SCLK 频率约束

| 条件 | 典型最大 SCLK 频率 | 说明 |
|------|-------------------|------|
| SPI Flash 读取 | 50~133 MHz | W25Q128 标准读 50 MHz，Fast Read 133 MHz |
| SPI Flash 写入/擦除 | 通常由命令本身决定 | 时钟只用于移入命令和数据 |
| 传感器（如 BMI160） | 10 MHz | 数据手册明确上限 |
| ADC（如 MCP3201） | 1.6~5 MHz | 取决于电源电压和温度 |
| MicroSD（SPI 模式） | 25 MHz（初始化 400 KHz） | 初始化阶段必须低速 |
| EEPROM（如 25LC256） | 10~20 MHz | |

### 8.2 Master 时钟分频

Master 时钟分频公式：

```
SCLK 频率 = F_master_clk / (2 × 分频系数)

示例（100 MHz 系统时钟）：
- 分频系数 = 1   → SCLK = 50 MHz
- 分频系数 = 2   → SCLK = 25 MHz
- 分频系数 = 5   → SCLK = 10 MHz
- 分频系数 = 125 → SCLK = 400 KHz（SD 卡初始化）
```

> **注意**：分频系数通常必须为偶数，以确保 SCLK 占空比为 50%。部分 SPI Master IP 支持奇数分频但占空比不均匀。

---

## 9. 设计注意事项

### 9.1 CS 建立时间与保持时间

```
CS_N    ─────────┐                                         ┌─────────
                 |_________________________________________|
                 |<--->|                                 |<--->|
                  tCSS                                    tCSH
                  CS 建立                                CS 保持

SCLK    ──────────┐ ┌──┐ ┌──┐                       ┌──┐ ┌─────────
                  └─┘  └─┘  ...                    └─┘  └─┘
```

| 参数 | 符号 | 典型值 | 说明 |
|------|------|--------|------|
| CS 建立时间 | tCSS | 5~50 ns | CS 拉低到第一个 SCLK 边沿的最小间隔 |
| CS 保持时间 | tCSH | 5~50 ns | 最后一个 SCLK 边沿到 CS 拉高的最小间隔 |
| CS 高电平时间 | tCSH | ≥ 50 ns | 两次传输之间 CS 必须保持高电平的最短时间 |

> **设计要点**：Master RTL 中必须确保 CS 拉低后延迟足够多的时钟周期再开始发送 SCLK。不满足 tCSS/tCSH 会导致从设备无法正确识别传输边界。

### 9.2 MOSI / MISO 时序裕量

| 参数 | 说明 | 关注点 |
|------|------|--------|
| Master 输出延迟 | SCLK 边沿到 MOSI 稳定的延迟 | 必须小于从设备的采样窗口 |
| Slave 输出延迟 | SCLK 边沿到 MISO 稳定的延迟 | Master 必须在延迟后采样 |
| Master 采样窗口 | Master 在 SCLK 边沿附近的采样时间 | 需考虑 MISO 延迟 + PCB 走线延迟 |
| 建立时间裕量 | MISO 数据在 SCLK 采样边沿前稳定的时间 | Tsetup_margin = Tclk/2 - Tmiso_delay - Tsetup |
| 保持时间裕量 | MISO 数据在 SCLK 采样边沿后保持的时间 | Thold_margin = Tmiso_hold - Thold |

### 9.3 CPOL / CPHA 一致性验证

**最重要的设计规则**：Master 和所有 Slave 的 CPOL / CPHA 必须一致。

**验证方法**：
1. 上电后读取从设备 ID 寄存器（通常对 SPI 模式最不敏感）
2. 尝试读取已知值的寄存器
3. 用逻辑分析仪抓取实际波形，确认采样边沿

**常见错误**：
- Master 用 Mode 0，Slave 配置为 Mode 3 → 数据错位或全 0/全 1
- 不同从设备使用不同模式 → 需要在切换从设备时重新配置 Master

### 9.4 MISO 总线冲突

当多个从设备共享 MISO 时，未被选中的从设备必须释放 MISO（高阻态）。

```
CS_N=0 (Slave 0 选中)          CS_N=1 (Slave 0 未选中)
MISO ← Slave 0 驱动            MISO ← Hi-Z（高阻）
                               需要外部上拉电阻确保确定电平
```

**推荐做法**：
- 在 MISO 上加 10K~100K 上拉电阻
- 确认从设备数据手册中 MISO 在未选中时的行为

### 9.5 PCB 布线注意事项

| 注意项 | 建议 |
|--------|------|
| SCLK 走线 | 尽量短，避免与其他信号平行走线（减少串扰） |
| MOSI/MISO 走线 | 长度匹配（差异 < 1 inch） |
| CS 走线 | 每根独立走线，避免菊花链走线（除非使用菊花链拓扑） |
| 高速 SPI（> 25 MHz） | 需要阻抗匹配，考虑串联端接电阻 |
| 多层板 | SPI 信号线下方有完整参考地平面 |

---

## 10. Master RTL 实现要点

### 10.1 模块结构

```
spi_master
├── 时钟分频器（产生 SCLK）
├── 移位寄存器（MOSI 发送 / MISO 接收）
├── 位计数器（跟踪传输进度）
├── CS 控制逻辑
└── 状态机（IDLE → ACTIVE → DONE → IDLE）
```

### 10.2 时钟分频

```verilog
// SCLK 生成：系统时钟分频
reg [CLK_DIV_WIDTH-1:0] clk_cnt;
reg sclk_int;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt  <= {CLK_DIV_WIDTH{1'b0}};
        sclk_int <= CPOL;  // 空闲电平 = CPOL
    end else if (spi_active) begin
        if (clk_cnt == clk_div - 1'b1) begin
            clk_cnt  <= {CLK_DIV_WIDTH{1'b0}};
            sclk_int <= ~sclk_int;
        end else begin
            clk_cnt <= clk_cnt + 1'b1;
        end
    end else begin
        clk_cnt  <= {CLK_DIV_WIDTH{1'b0}};
        sclk_int <= CPOL;  // 空闲时恢复 CPOL 电平
    end
end

assign sclk = sclk_int;
```

### 10.3 移位寄存器

```verilog
reg [DATA_WIDTH-1:0] tx_shift_reg;  // 发送移位寄存器
reg [DATA_WIDTH-1:0] rx_shift_reg;  // 接收移位寄存器
reg [$clog2(DATA_WIDTH):0] bit_cnt;

// 发送：MSB first
assign mosi = tx_shift_reg[DATA_WIDTH-1];

// 采样边沿检测（Mode 0：上升沿采样）
wire sample_edge = (CPHA == 0) ? (sclk_int && !sclk_prev)   // 上升沿
                               : (!sclk_int && sclk_prev);   // 下降沿

wire shift_edge  = (CPHA == 0) ? (!sclk_int && sclk_prev)   // 下降沿
                               : (sclk_int && !sclk_prev);   // 上升沿

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_shift_reg <= {DATA_WIDTH{1'b0}};
        rx_shift_reg <= {DATA_WIDTH{1'b0}};
        bit_cnt      <= {($clog2(DATA_WIDTH)+1){1'b0}};
    end else if (spi_active) begin
        if (sample_edge) begin
            rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], miso};
            bit_cnt      <= bit_cnt - 1'b1;
        end
        if (shift_edge) begin
            tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
        end
    end else if (spi_start) begin
        tx_shift_reg <= tx_data;
        rx_shift_reg <= {DATA_WIDTH{1'b0}};
        bit_cnt      <= DATA_WIDTH[$clog2(DATA_WIDTH):0];
    end
end
```

### 10.4 CS 控制

```verilog
// CS 控制：传输开始前拉低，传输结束后拉高
reg cs_n_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs_n_reg <= 1'b1;  // 默认未选中
    end else if (spi_start) begin
        cs_n_reg <= 1'b0;  // 选中
    end else if (spi_done) begin
        cs_n_reg <= 1'b1;  // 释放
    end
end

assign cs_n = cs_n_reg;
```

### 10.5 状态机

```verilog
localparam [1:0] S_IDLE   = 2'd0,
                 S_SETUP  = 2'd1,  // CS 建立延迟
                 S_ACTIVE = 2'd2,  // 数据传输
                 S_HOLD   = 2'd3;  // CS 保持延迟

reg [1:0] state_cur, state_nxt;

// 状态转移
always @(*) begin
    state_nxt = state_cur;
    case (state_cur)
        S_IDLE: begin
            if (spi_start)
                state_nxt = S_SETUP;
        end
        S_SETUP: begin
            if (setup_done)       // CS 建立时间满足
                state_nxt = S_ACTIVE;
        end
        S_ACTIVE: begin
            if (bit_cnt == 0 && sample_edge)
                state_nxt = S_HOLD;
        end
        S_HOLD: begin
            if (hold_done)        // CS 保持时间满足
                state_nxt = S_IDLE;
        end
        default: state_nxt = S_IDLE;
    endcase
end
```

### 10.6 关键设计检查项

| 检查项 | 要求 |
|--------|------|
| SCLK 空闲电平 | 必须等于 CPOL 参数 |
| 采样边沿 | 必须匹配 CPHA 参数 |
| CS 建立时间 | CS 拉低到第一个 SCLK ≥ tCSS |
| CS 保持时间 | 最后一个 SCLK 到 CS 拉高 ≥ tCSH |
| CS 高电平时间 | 两次传输之间 ≥ tCSH_min |
| 数据位序 | MSB first（大多数设备），确认是否需要 LSB first |
| 位宽 | 默认 8-bit，可参数化支持 16/32-bit |
| 连续传输 | 支持 CS 持续拉低的多字节传输 |

---

## 11. QSPI / Dual-SPI 与标准 SPI 的区别

### 11.1 标准 SPI vs Dual-SPI vs QSPI

| 特性 | 标准 SPI | Dual-SPI | QSPI |
|------|----------|----------|------|
| 数据线 | MOSI + MISO（2 根单向） | IO0 + IO1（2 根双向） | IO0 + IO1 + IO2 + IO3（4 根双向） |
| 每时钟传输位数 | 1-bit（半双工/全双工） | 2-bit | 4-bit |
| 全双工 | 是 | 否（半双工） | 否（半双工） |
| 引脚数 | 4 | 4（复用） | 6 |
| 典型速率 | 50 MHz | 100 MHz | 100~133 MHz |
| 等效带宽 @100MHz | 6.25 MB/s | 25 MB/s | 50 MB/s |
| 命令阶段 | 1-bit | 1-bit（部分支持 2-bit） | 1-bit（部分支持 2/4-bit） |
| 地址阶段 | 1-bit | 可切换到 2-bit | 可切换到 2/4-bit |
| 数据阶段 | 1-bit | 2-bit | 4-bit |
| 典型应用 | 通用外设 | 中速 Flash | 高速 Flash（XiP） |

### 11.2 QSPI 信号复用

QSPI 使用 4 根双向数据线（IO0~IO3），在不同阶段切换方向：

```
标准 SPI 模式（命令阶段）：
  MOSI = IO0（Master → Slave）
  MISO = IO1（Slave → Master）
  IO2, IO3 = 未使用（或 WP/HOLD）

QSPI 模式（数据阶段）：
  IO0 = D0（双向）
  IO1 = D1（双向）
  IO2 = D2（双向）
  IO3 = D3（双向）
```

### 11.3 QSPI 读操作示例（Winbond W25Q）

```
阶段          IO0    IO1    IO2    IO3    说明
─────────────────────────────────────────────────
Command       0xEB   Hi-Z   Hi-Z   Hi-Z   1-bit 模式发送命令
Dummy         -      -      -      -      6 个时钟周期（可配置）
Address       A0     A1     A2     A3     4-bit 模式发地址（2-bit 也行）
Mode          M0     M1     M2     M3     指示是否连续读
Dummy         -      -      -      -      2 个时钟周期
Data          D0     D1     D2     D3     4-bit 模式读数据 ──►
```

### 11.4 选择建议

| 场景 | 推荐方案 | 理由 |
|------|----------|------|
| 低速传感器/EEPROM | 标准 SPI | 简单，引脚少 |
| 中速 Flash（≤ 50 MB/s） | Dual-SPI | 兼顾速度和引脚 |
| 高速 Flash（XiP 执行） | QSPI | 最高带宽，可映射到内存空间 |
| SD 卡 | 标准 SPI（初始化）→ SD 模式 | SD 模式有专用协议 |
| 多从设备混合 | 标准 SPI | 兼容性最好 |

---

## 附录：缩略语

| 缩写 | 全称 |
|------|------|
| SPI | Serial Peripheral Interface |
| SCLK | Serial Clock |
| MOSI | Master Out Slave In |
| MISO | Master In Slave Out |
| CS/SS | Chip Select / Slave Select |
| CPOL | Clock Polarity |
| CPHA | Clock Phase |
| QSPI | Quad SPI |
| XiP | Execute in Place |
| Hi-Z | High Impedance |
| WREN | Write Enable |
| RDSR | Read Status Register |
