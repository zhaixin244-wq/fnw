# Wishbone 接口协议

> **用途**：开源总线标准，简洁高效，适合 FPGA 和中小规模 ASIC
> **规范版本**：Wishbone B4 (Rev B4)
> **典型应用**：FPGA SoC、开源处理器核（RISC-V）、IP 集成、教学科研

---

## 1. 协议概述

Wishbone 是 OpenCores 社区维护的开源总线标准，设计哲学是 **简洁、易实现、无版税**。与 ARM AMBA 和 Intel 体系不同，Wishbone 不依赖任何商业授权，可自由用于任何 FPGA 或 ASIC 设计。

**核心特征**：

- 完全开源，无版税（Royalty-Free）
- 信号数量少，实现简单（最小配置仅需约 30 个信号）
- 支持 8/16/32/64-bit 数据宽度
- 支持 Single Transfer 和 Burst 传输
- 支持经典握手（Classic）和流水线（Pipelined）两种时序模式
- 无乱序完成、无 Outstanding 事务、无 QoS —— 一切从简
- 互联拓扑灵活：Point-to-Point、Shared Bus、Crossbar

**与 AXI/AHB 对比定位**：

| 特性 | Wishbone B4 | AXI4 | AHB-Lite | APB |
|------|-------------|------|----------|-----|
| 开源 | 是（完全开源） | 否（ARM IP） | 否（ARM IP） | 否（ARM IP） |
| 设计复杂度 | 低 | 高 | 中 | 低 |
| 突发传输 | 支持（简单） | 支持（丰富） | 支持（INCR/SINGLE） | 不支持 |
| 乱序完成 | 不支持 | 支持（基于 ID） | 不支持 | 不支持 |
| Outstanding | 不支持 | 支持 | 不支持（AHB-Lite） | 不支持 |
| 流水线模式 | 支持（Pipelined） | 支持 | 支持 | 不支持 |
| 典型数据宽度 | 8/16/32/64 | 8~1024 | 8~1024 | 8/16/32 |
| 适用场景 | FPGA、开源 SoC | 高性能 SoC | 中性能 SoC | 低速外设 |
| 版税 | 免费 | 需授权 | 需授权 | 需授权 |

**Wishbone 的定位**：在不需要 AXI 的乱序/Outstanding/QoS 能力时，Wishbone 是面积和实现复杂度最优的选择。

---

## 2. 信号分类

Wishbone 信号分为三类：SYSCON 信号、Master 信号、Slave 信号。

### 2.1 SYSCON 信号（系统控制）

| 信号名 | 说明 |
|--------|------|
| `CLK_I` | 系统时钟输入，所有 Wishbone 信号在 CLK_I 上升沿采样 |
| `RST_I` | 系统复位，高有效异步复位 |

> **注意**：Wishbone 使用 **高有效复位**（RST_I），与 AMBA 的低有效（ARESETn）不同。

### 2.2 Master 输出信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| `ADR_O[MSB:0]` | ADDR_WIDTH | 地址输出 |
| `DAT_O[MSB:0]` | DATA_WIDTH | 数据输出（写数据） |
| `SEL_O[MSB:0]` | DATA_WIDTH/8 | 字节选通输出，每 bit 对应一个字节 |
| `WE_O` | 1 | 写使能：1=写，0=读 |
| `STB_O` | 1 | Strobe 信号，标识一次总线事务的发起 |
| `CYC_O` | 1 | Cycle 信号，标识总线周期有效（仲裁用） |
| `LOCK_O` | 1 | 锁定总线（可选，用于 RMW 操作） |
| `CTI_O[2:0]` | 3 | Cycle Type Identifier（突发类型） |
| `BTE_O[1:0]` | 2 | Burst Type Extension（突发扩展编码） |
| `TGA_O[MSB:0]` | TAG | 地址 TAG（可选，传递附加地址信息） |
| `TGD_O[MSB:0]` | TAG | 数据 TAG（可选，传递附加数据信息） |
| `TGC_O[MSB:0]` | TAG | 周期 TAG（可选，传递总线控制信息） |

### 2.3 Slave 输出信号

| 信号名 | 位宽 | 说明 |
|--------|------|------|
| `DAT_I[MSB:0]` | DATA_WIDTH | 数据输入（读数据） |
| `ACK_I` | 1 | 确认信号，Slave 应答 Master 请求 |
| `ERR_I` | 1 | 错误信号，标识总线错误（可选） |
| `RTY_I` | 1 | 重试信号，要求 Master 重试（可选） |
| `STALL_I` | 1 | 流水线暂停信号（Pipelined 模式） |
| `TAG_I[MSB:0]` | TAG | TAG 信号（可选） |

### 2.4 交叉连接 vs 共享总线

**交叉连接（Crossbar）**：
- 多个 Master 可同时访问不同 Slave
- 需要仲裁逻辑和数据多路复用
- 带宽高，逻辑复杂

**共享总线（Shared Bus）**：
- 同一时刻只有一个 Master 占用总线
- 仲裁简单（优先级或轮询）
- 实现面积小，适合低速场景

---

## 3. 典型信号表

### 3.1 Master 端信号（输出方向 `_O`）

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| `ADR_O` | Master → Bus | ADDR_WIDTH | 读/写地址 |
| `DAT_O` | Master → Bus | DATA_WIDTH | 写数据 |
| `SEL_O` | Master → Bus | DATA_WIDTH/8 | 字节选通，高有效，指示哪些字节有效 |
| `WE_O` | Master → Bus | 1 | 写使能：1=写事务，0=读事务 |
| `STB_O` | Master → Bus | 1 | Strobe：Master 发起事务请求 |
| `CYC_O` | Master → Bus | 1 | Cycle：Master 声明总线使用权（仲裁关键信号） |
| `TGA_O` | Master → Bus | TAG | 地址 TAG（可选） |
| `TGD_O` | Master → Bus | TAG | 数据 TAG（可选） |
| `TGC_O` | Master → Bus | TAG | 周期 TAG（可选） |

### 3.2 Slave 端信号（输出方向 `_O`，Master 视角为输入 `_I`）

| 信号 | 方向 | 位宽 | 功能 |
|------|------|------|------|
| `DAT_I` | Slave → Bus | DATA_WIDTH | 读返回数据 |
| `ACK_I` | Slave → Bus | 1 | 确认：Slave 完成数据传输 |
| `ERR_I` | Slave → Bus | 1 | 错误：Slave 报告总线错误（可选） |
| `RTY_I` | Slave → Bus | 1 | 重试：Slave 要求 Master 重试（可选） |
| `STALL_I` | Slave → Bus | 1 | 暂停：Slave 未准备好（Pipelined 模式） |

### 3.3 信号握手关系

```
Master                              Slave
  |                                   |
  |--- ADR_O, DAT_O, WE_O, SEL_O --->|
  |--- STB_O = 1 -------------------->|
  |                                   |-- 处理请求
  |<--------------- ACK_I = 1 --------|
  |                                   |
  (握手完成，事务结束)
```

**握手条件**：`STB_O & ACK_I` 同时为高时，数据传输完成（单周期）。

---

## 4. 互联拓扑

### 4.1 Point-to-Point（点对点）

最简单，一个 Master 连一个 Slave。

```
+-----------+                    +-----------+
|           |  ADR/DAT/SEL/WE   |           |
|  Master   |------------------>|   Slave   |
|           |  STB   ACK        |           |
|           |---  -->  ---------|           |
|           |  CYC              |           |
+-----------+                    +-----------+
```

### 4.2 Shared Bus（共享总线）

多个 Master 通过仲裁器共享一条总线，同一时刻只有一个 Master 获得总线。

```
+----------+   +----------+
| Master 0 |   | Master 1 |
+----+-----+   +-----+----+
     |               |
     | REQ/GNT       | REQ/GNT
     v               v
  +--+---------------+--+
  |    Arbiter           |
  +--+----------------+--+
     |                |
     v                v
+----+-----+   +-----+----+   +----------+
| Slave 0  |   | Slave 1  |   | Slave 2  |
+----------+   +----------+   +----------+
```

### 4.3 Crossbar（交叉开关）

多个 Master 可同时访问不同 Slave，需要地址解码和仲裁。

```
         Slave 0    Slave 1    Slave 2
            |          |          |
     +------+------+------+------+
     |  Crossbar Switch            |
     +--+------+------+------+--+
        |      |      |      |
   Master 0 Master 1
```

### 4.4 典型 SoC 互联结构

```
                  +------------+
                  |   CPU      |
                  | (Master)   |
                  +-----+------+
                        |
              +---------+---------+
              |   Shared Bus      |
              |   + Arbiter       |
              +--+----+----+----+-+
                 |    |    |    |
              +--+ +--+ +--+ +--+
              |M | |S | |S | |S |
              |em| |P | |G | |U |
              +--+ |I | |PIO| |ART|
                   +--+ +--+ +--+
```

---

## 5. 读事务时序

### 5.1 Classic 模式读时序

Classic 模式是最基础的时序模式，每个事务独立握手。

```
CLK_I   _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
                |       |       |
ADR_O   ------<  addr  >-----------------
DAT_O   ------< xxxxxxx >-----------------
WE_O    -------<  0 (读) >----------------
SEL_O   ------<  sel    >-----------------
STB_O   _______/‾‾‾‾‾‾‾‾\________________
CYC_O   _______/‾‾‾‾‾‾‾‾\________________
                |       |
DAT_I   -------< invalid >---<  rdata  >--
ACK_I   ________________/‾‾‾‾\___________
                |       |       |
                t1      t2      t3

t1: Master 发起读请求（STB_O=1, WE_O=0, ADR_O=addr）
t2: Slave 响应（ACK_I=1），DAT_I 上出现有效读数据
t3: 握手完成，STB_O 拉低，事务结束
```

**时序要点**：
- Master 在时钟上升沿后输出 ADR_O、WE_O、SEL_O、STB_O、CYC_O
- Slave 在 STB_O 有效后（可延迟若干周期）拉高 ACK_I，并将读数据放在 DAT_I 上
- `STB_O & ACK_I` 同时为高时完成一次数据传输
- Master 检测到 ACK_I 后可立即拉低 STB_O

### 5.2 Pipelined 模式读时序

Pipelined 模式允许 Slave 提前给出 STALL 信号，Master 可在 ACK 到来之前发起下一个事务。

```
CLK_I   _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_

ADR_O   -< addr0 >---< addr1 >---< addr2 >-
STB_O   ___/‾‾‾‾‾\__/‾‾‾‾‾‾‾‾‾\__________
CYC_O   ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__________
STALL_I ___/‾‾‾‾‾\_________________________
                |       |       |       |
ACK_I   ________________/‾‾\_______/‾\____
DAT_I   ------< invalid >--< d0 >--< d1 >--
                |       |       |
                发起0    ACK0    ACK1

Pipeline 效果：addr1 的请求可以在 addr0 的 ACK 之前发起
```

**Pipelined 模式要点**：
- `STALL_I` 为低时，Slave 可以接受新请求
- `STALL_I` 为高时，Slave 暂停接受新请求（但不影响正在进行的 ACK）
- 允许请求和响应重叠，提高总线利用率

---

## 6. 写事务时序

### 6.1 Classic 模式写时序

```
CLK_I   _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
                |       |       |
ADR_O   ------<  addr  >-----------------
DAT_O   ------<  wdata  >-----------------
WE_O    -------<  1 (写) >----------------
SEL_O   ------<  sel    >-----------------
STB_O   _______/‾‾‾‾‾‾‾‾\________________
CYC_O   _______/‾‾‾‾‾‾‾‾\________________
                |       |
ACK_I   ________________/‾‾‾‾\___________
                |       |       |
                t1      t2      t3

t1: Master 发起写请求（STB_O=1, WE_O=1, ADR_O=addr, DAT_O=wdata）
t2: Slave 响应（ACK_I=1），写数据被采样
t3: 握手完成，事务结束
```

**写时序要点**：
- Master 在同一周期输出地址、写数据和控制信号
- Slave 拉高 ACK_I 表示写入完成
- 写数据在 `STB_O & ACK_I` 为高的时钟上升沿被 Slave 锁存

### 6.2 写操作中 SEL_O 的使用

```
SEL_O = 4'b1111  → 写全部 4 字节（32-bit 总线）
SEL_O = 4'b0001  → 仅写 byte[0]（最低字节）
SEL_O = 4'b1100  → 写 byte[3:2]（高 2 字节）
SEL_O = 4'b1010  → 写 byte[3] 和 byte[1]
```

---

## 7. 突发传输

### 7.1 CTI 编码（Cycle Type Identifier）

CTI_O[2:0] 指示当前传输在突发中的位置：

| CTI_O[2:0] | 编码名称 | 说明 |
|-------------|---------|------|
| `3'b000` | Classic | 经典模式（无突发，每个事务独立握手） |
| `3'b001` | Constant address burst | 地址不变的突发（FIFO 访问） |
| `3'b010` | Incrementing burst | 地址递增突发 |
| `3'b111` | End-of-burst | 突发最后一个传输 |

**使用规则**：
- 突发中间传输：CTI = `010`（递增）或 `001`（常地址）
- 突发最后一个传输：CTI = `111`（End-of-burst）
- Slave 检测到 CTI = `111` 后，该传输完成即结束突发

### 7.2 BTE 编码（Burst Type Extension）

BTE_O[1:0] 指定突发的地址递增模式（仅在 CTI = `010` 时有效）：

| BTE_O[1:0] | 编码名称 | 地址递增方式 | 突发长度 |
|-------------|---------|-------------|---------|
| `2'b00` | LINEAR | 线性递增：addr + 1, +2, +3... | 不限 |
| `2'b01` | WRAP4 | 4-beat 回环：地址在 4 对齐边界回环 | 4 |
| `2'b10` | WRAP8 | 8-beat 回环：地址在 8 对齐边界回环 | 8 |
| `2'b11` | WRAP16 | 16-beat 回环：地址在 16 对齐边界回环 | 16 |

**WRAP 突发示例（WRAP4, 假设 32-bit 数据宽度）**：
```
起始地址 = 0x10
传输 1: addr = 0x10
传输 2: addr = 0x14
传输 3: addr = 0x18
传输 4: addr = 0x1C
（回环到 4 对齐边界，下一拍回到 0x10 —— 用于 Cache Line 填充）
```

### 7.3 突发传输时序示例（2-beat 增量突发）

```
CLK_I   _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_

ADR_O   -< addr0 >---< addr1 >-----------
CTI_O   -< 010   >---< 111  >-----------   (递增, 然后 End-of-burst)
BTE_O   --< LINEAR >---------------------
DAT_O   -< wdata0 >--< wdata1 >----------
WE_O    -------< 1 (写) >----------------
STB_O   ___/‾‾‾‾‾‾‾‾‾‾‾\________________
ACK_I   _________/‾\_____/‾\_____________
                |       |
              握手1    握手2（突发结束）
```

---

## 8. 仲裁机制

### 8.1 共享总线仲裁

当多个 Master 连接到同一总线时，需要仲裁器（Arbiter）决定哪个 Master 获得总线控制权。

**仲裁信号**：

| 信号 | 说明 |
|------|------|
| `REQ[n:0]` | 各 Master 的总线请求 |
| `GRANT[n:0]` | 仲裁器输出的授权信号（独热码） |

**仲裁依据**：`CYC_O` 信号。Master 拉高 `CYC_O` 表示需要使用总线，仲裁器据此产生 `GRANT`。

### 8.2 仲裁策略

| 策略 | 说明 | 适用场景 |
|------|------|---------|
| 固定优先级 | Master 0 优先级最高 | 实时性要求高的场景 |
| 轮询（Round-Robin） | 各 Master 轮流获得总线 | 公平性要求高的场景 |
| 混合 | 高优先级 Master + 轮询低优先级 | 折中方案 |

### 8.3 仲裁时序

```
CLK_I    _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_

REQ[0]   _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____
REQ[1]   ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____
GRANT[0] _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____
GRANT[1] _____________________________/‾‾
         |       |       |       |
       M0请求  M1请求   M0获授权 M1获授权

仲裁切换时，前一个 Master 必须先释放总线（CYC_O=0），
仲裁器才能将 GRANT 切换到下一个 Master。
```

### 8.4 总线锁定

`LOCK_O` 信号用于 Read-Modify-Write（RMW）操作，防止仲裁器在操作中途切换 Master。

---

## 9. 数据宽度适配

### 9.1 SEL_O 字节选通

`SEL_O` 信号的位宽 = `DATA_WIDTH / 8`，每个 bit 对应一个字节：

| 数据宽度 | SEL_O 位宽 | 说明 |
|----------|-----------|------|
| 8-bit | 1 bit | `SEL_O[0]` 选通 byte[0] |
| 16-bit | 2 bit | `SEL_O[1:0]` 选通 byte[1:0] |
| 32-bit | 4 bit | `SEL_O[3:0]` 选通 byte[3:0] |
| 64-bit | 8 bit | `SEL_O[7:0]` 选通 byte[7:0] |

### 9.2 地址对齐

- 地址总线的最低位（LSB）根据数据宽度决定对齐：
  - 32-bit 数据宽度：`ADR_O[1:0]` 应为 `2'b00`（4 字节对齐）
  - 64-bit 数据宽度：`ADR_O[2:0]` 应为 `3'b000`（8 字节对齐）
- 使用 `SEL_O` 选择部分字节，实现子字（sub-word）访问

### 9.3 不同宽度 Master/Slave 互联

当 Master 和 Slave 数据宽度不同时，需要 **Bus Resize Bridge**：

```
Master (32-bit) → Resize Bridge → Slave (8-bit)

写 32-bit 数据拆分为 4 次 8-bit 写
读 8-bit 数据拼接为 1 次 32-bit 读
```

---

## 10. 与 AXI4-Lite 对比表

| 对比项 | Wishbone B4 | AXI4-Lite |
|--------|-------------|-----------|
| **信号总数** | ~15（最小配置） | ~20（5 通道） |
| **通道数** | 单通道（地址/数据复用） | 5 通道（AW/W/B/AR/R 独立） |
| **读写分离** | 共享通道，WE_O 区分 | 通道级分离 |
| **复位极性** | 高有效（RST_I） | 低有效（ARESETn） |
| **字节选通** | SEL_O | WSTRB |
| **握手信号** | STB / ACK | VALID / READY |
| **突发传输** | 支持（CTI/BTE） | AXI4-Lite 不支持 |
| **乱序完成** | 不支持 | AXI4-Lite 不支持（AXI4 支持） |
| **Outstanding** | 不支持 | AXI4-Lite 不支持（AXI4 支持） |
| **保护属性** | 无（可选 TAG） | AWPROT / ARPROT |
| **错误响应** | ERR_I / RTY_I | BRESP / RRESP |
| **实现面积** | 小（~500 gates） | 中（~2000 gates） |
| **版税** | 免费 | 需 ARM 授权 |
| **生态系统** | OpenCores、RISC-V | ARM 生态、商业 IP |

**选型建议**：
- 需要与 ARM IP 互联 → AXI4-Lite
- 开源 RISC-V / FPGA 自主 SoC → Wishbone
- 需要高性能（Outstanding、乱序） → AXI4 Full

---

## 11. 与 AHB 对比表

| 对比项 | Wishbone B4 | AHB-Lite | AHB Full |
|--------|-------------|----------|----------|
| **信号总数** | ~15 | ~25 | ~35+ |
| **突发传输** | CTI/BTE（简单） | SINGLE/INCR/WRAP4/8/16 | 同 AHB-Lite |
| **仲裁** | 外部 Arbiter（CYC/GRANT） | 内置 HGRANT/HBUSREQ | 内置 |
| **流水线** | Pipelined 模式 | 地址/数据流水 | 同 AHB-Lite |
| **Split/Retry** | RTY_I（简单重试） | HSPLIT/HRETRY（复杂） | 同 AHB-Lite |
| **数据宽度** | 8/16/32/64 | 8/16/32/64/128/256/512/1024 | 同 AHB-Lite |
| **多 Master** | 外部仲裁 | AHB-Lite 不支持，AHB Full 支持 | 支持 |
| **HBUSREQ 级信号** | 无（用 CYC_O） | HGRANT/HBUSREQ/HSPLIT | 同 |
| **错误响应** | ERR_I | HRESP[1:0]（OKAY/ERROR） | 同 |
| **实现面积** | 最小 | 中 | 较大 |
| **版税** | 免费 | ARM 授权 | ARM 授权 |

**关键差异**：
- AHB 内置仲裁逻辑，Wishbone 需外部实现
- AHB 的 Split 事务机制复杂，Wishbone 用简单的 RTY_I 重试替代
- Wishbone 实现面积更小，适合资源受限场景

---

## 12. 设计注意事项

### 12.1 简洁性优势

- **信号少**：最小配置仅需 ADR_O、DAT_O/I、WE_O、SEL_O、STB_O、CYC_O、ACK_I，约 15 个信号
- **无状态**：Master 和 Slave 无需维护复杂的事务状态
- **易调试**：握手逻辑简单（STB & ACK），波形可直接人工阅读
- **综合友好**：无复杂的流水线控制逻辑，综合工具容易优化

### 12.2 无乱序

Wishbone 严格保证事务按发起顺序完成。如果 Slave 需要不同延迟（如访问不同地址映射的存储），Master 必须等待前一事务完成才能发起下一事务。

**设计影响**：不需要 ID 排序逻辑，不需要 Reorder Buffer，面积和功耗显著降低。

### 12.3 无 Outstanding

Wishbone 不支持 Outstanding（即 Master 发出请求后必须等待 ACK 才能发起下一请求，Pipelined 模式除外）。

**设计影响**：
- 适合延迟固定的 Slave（如片上 SRAM）
- 对于延迟不确定的 Slave（如 DDR 控制器），吞吐受限
- 解决方案：使用 Pipelined 模式或 Burst 传输

### 12.4 典型应用场景

| 场景 | 说明 |
|------|------|
| RISC-V 处理器核 | OpenRISC、VexRiscv、PicoRV32 等开源核常用 Wishbone |
| FPGA SoC | Zynq、iCE40 等 FPGA 上的自定义 SoC |
| 外设控制器 | GPIO、SPI、I2C、UART、Timer 等低速外设 |
| 教学与科研 | 总线协议教学、SoC 设计实验 |
| IP 集成 | OpenCores 社区 IP 之间的标准互联 |

### 12.5 常见设计错误

| 错误 | 说明 | 正确做法 |
|------|------|---------|
| 忘记 CYC_O | CYC_O 未拉高导致仲裁失败 | 事务期间始终保持 CYC_O = 1 |
| STB_O 提前拉低 | ACK 之前拉低 STB_O 导致事务丢失 | STB_O 必须保持到 ACK_I 采样 |
| ACK_I 多周期脉冲 | Slave 在 ACK 后未及时拉低 | ACK_I 只在 STB_O 有效时拉高一周期 |
| SEL_O 全零 | 无字节被选通，写入无意义 | 确保 SEL_O 至少一个 bit 为 1 |
| 复位后信号不归零 | 可能触发虚假事务 | RST_I 期间所有输出信号归零 |
| RST_I 极性搞错 | Wishbone 是高有效复位 | 注意与 AMBA 低有效复位区分 |

---

## 13. 典型实例化

### 13.1 Wishbone Master 简化示例

```verilog
// ============================================================================
// Module   : wb_master_simple
// Function : 简化 Wishbone Master，支持单拍读写
// ============================================================================
module wb_master_simple #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    localparam SEL_WIDTH = DATA_WIDTH / 8
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // CPU 接口
    input  wire                  cpu_req,
    input  wire                  cpu_wr,
    input  wire [ADDR_WIDTH-1:0] cpu_addr,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    input  wire [SEL_WIDTH-1:0]  cpu_sel,
    output reg  [DATA_WIDTH-1:0] cpu_rdata,
    output wire                  cpu_ack,

    // Wishbone Master 接口
    output reg  [ADDR_WIDTH-1:0] wb_adr_o,
    output reg  [DATA_WIDTH-1:0] wb_dat_o,
    input  wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg  [SEL_WIDTH-1:0]  wb_sel_o,
    output reg                   wb_we_o,
    output reg                   wb_stb_o,
    output reg                   wb_cyc_o,
    input  wire                  wb_ack_i
);

    // Wishbone 高有效复位
    wire wb_rst = !rst_n;

    // 状态定义
    localparam S_IDLE = 1'b0;
    localparam S_WAIT = 1'b1;

    reg state_cur, state_nxt;

    // 组合逻辑：次态 + 输出
    always @(*) begin
        state_nxt  = state_cur;
        wb_adr_o   = {ADDR_WIDTH{1'b0}};
        wb_dat_o   = {DATA_WIDTH{1'b0}};
        wb_sel_o   = {SEL_WIDTH{1'b0}};
        wb_we_o    = 1'b0;
        wb_stb_o   = 1'b0;
        wb_cyc_o   = 1'b0;
        cpu_rdata  = {DATA_WIDTH{1'b0}};

        case (state_cur)
            S_IDLE: begin
                if (cpu_req) begin
                    wb_adr_o  = cpu_addr;
                    wb_dat_o  = cpu_wdata;
                    wb_sel_o  = cpu_sel;
                    wb_we_o   = cpu_wr;
                    wb_stb_o  = 1'b1;
                    wb_cyc_o  = 1'b1;
                    state_nxt = S_WAIT;
                end
            end
            S_WAIT: begin
                wb_adr_o = cpu_addr;
                wb_dat_o = cpu_wdata;
                wb_sel_o = cpu_sel;
                wb_we_o  = cpu_wr;
                wb_stb_o = 1'b1;
                wb_cyc_o = 1'b1;
                if (wb_ack_i) begin
                    cpu_rdata = wb_dat_i;
                    state_nxt = S_IDLE;
                end
            end
            default: state_nxt = S_IDLE;
        endcase
    end

    // 时序逻辑
    always @(posedge clk or posedge wb_rst) begin
        if (wb_rst)
            state_cur <= S_IDLE;
        else
            state_cur <= state_nxt;
    end

    assign cpu_ack = (state_cur == S_WAIT) && wb_ack_i;

endmodule
```

### 13.2 Wishbone Slave 简化示例（寄存器文件）

```verilog
// ============================================================================
// Module   : wb_slave_regfile
// Function : 简化 Wishbone Slave，4 个 32-bit 寄存器
// ============================================================================
module wb_slave_regfile #(
    parameter ADDR_WIDTH = 4,   // 4 地址空间
    parameter DATA_WIDTH = 32,
    localparam SEL_WIDTH = DATA_WIDTH / 8,
    localparam NUM_REGS  = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Wishbone Slave 接口
    input  wire [ADDR_WIDTH-1:0] wb_adr_i,
    input  wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg  [DATA_WIDTH-1:0] wb_dat_o,
    input  wire [SEL_WIDTH-1:0]  wb_sel_i,
    input  wire                  wb_we_i,
    input  wire                  wb_stb_i,
    input  wire                  wb_cyc_i,
    output reg                   wb_ack_o
);

    wire wb_rst = !rst_n;

    // 寄存器数组
    reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    // 地址解码（字节地址 → 寄存器索引）
    wire [1:0] reg_idx = wb_adr_i[3:2];  // 4 字节对齐

    // 读逻辑（组合）
    always @(*) begin
        wb_dat_o = {DATA_WIDTH{1'b0}};
        if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
            wb_dat_o = regs[reg_idx];
        end
    end

    // ACK 生成：收到 STB 后下一周期拉高
    always @(posedge clk or posedge wb_rst) begin
        if (wb_rst) begin
            wb_ack_o <= 1'b0;
        end else begin
            wb_ack_o <= wb_cyc_i && wb_stb_i && !wb_ack_o;
        end
    end

    // 写逻辑（时序）
    integer i;
    always @(posedge clk or posedge wb_rst) begin
        if (wb_rst) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {DATA_WIDTH{1'b0}};
        end else if (wb_cyc_i && wb_stb_i && wb_we_i && !wb_ack_o) begin
            // 按字节写入
            if (wb_sel_i[0]) regs[reg_idx][ 7: 0] <= wb_dat_i[ 7: 0];
            if (wb_sel_i[1]) regs[reg_idx][15: 8] <= wb_dat_i[15: 8];
            if (wb_sel_i[2]) regs[reg_idx][23:16] <= wb_dat_i[23:16];
            if (wb_sel_i[3]) regs[reg_idx][31:24] <= wb_dat_i[31:24];
        end
    end

endmodule
```

### 13.3 顶层互联示例

```verilog
// 1 个 Master 连接 2 个 Slave，地址解码 + 简单互联
wb_master_simple #(
    .ADDR_WIDTH (32),
    .DATA_WIDTH (32)
) u_master (
    .clk      (clk),
    .rst_n    (rst_n),
    .cpu_req  (cpu_req),
    .cpu_wr   (cpu_wr),
    .cpu_addr (cpu_addr),
    .cpu_wdata(cpu_wdata),
    .cpu_sel  (cpu_sel),
    .cpu_rdata(cpu_rdata),
    .cpu_ack  (cpu_ack),
    .wb_adr_o (wb_adr),
    .wb_dat_o (wb_dat_m2s),
    .wb_dat_i (wb_dat_s2m),
    .wb_sel_o (wb_sel),
    .wb_we_o  (wb_we),
    .wb_stb_o (wb_stb),
    .wb_cyc_o (wb_cyc),
    .wb_ack_i (wb_ack)
);

// 地址解码
wire sel0 = (wb_adr[31:4] == 28'h0000_000);  // Slave 0: 0x00~0x0F
wire sel1 = (wb_adr[31:4] == 28'h0000_001);  // Slave 1: 0x10~0x1F

// Slave 0
wb_slave_regfile #(.ADDR_WIDTH(4), .DATA_WIDTH(32)) u_slave0 (
    .clk       (clk),
    .rst_n     (rst_n),
    .wb_adr_i  (wb_adr[3:0]),
    .wb_dat_i  (wb_dat_m2s),
    .wb_dat_o  (wb_dat0),
    .wb_sel_i  (wb_sel),
    .wb_we_i   (wb_we),
    .wb_stb_i  (wb_stb & sel0),
    .wb_cyc_i  (wb_cyc & sel0),
    .wb_ack_o  (wb_ack0)
);

// Slave 1
wb_slave_regfile #(.ADDR_WIDTH(4), .DATA_WIDTH(32)) u_slave1 (
    .clk       (clk),
    .rst_n     (rst_n),
    .wb_adr_i  (wb_adr[3:0]),
    .wb_dat_i  (wb_dat_m2s),
    .wb_dat_o  (wb_dat1),
    .wb_sel_i  (wb_sel),
    .wb_we_i   (wb_we),
    .wb_stb_i  (wb_stb & sel1),
    .wb_cyc_i  (wb_cyc & sel1),
    .wb_ack_o  (wb_ack1)
);

// 数据/ACK 多路复用
assign wb_dat_s2m = sel0 ? wb_dat0 : wb_dat1;
assign wb_ack     = sel0 ? wb_ack0 : wb_ack1;
```

---

## 14. 附录

### A. 缩略语

| 缩写 | 全称 |
|------|------|
| WB | Wishbone |
| ADR | Address |
| DAT | Data |
| STB | Strobe |
| ACK | Acknowledge |
| CYC | Cycle |
| WE | Write Enable |
| SEL | Select (Byte Select) |
| CTI | Cycle Type Identifier |
| BTE | Burst Type Extension |
| GRANT | Bus Grant |
| RMW | Read-Modify-Write |
| FIFO | First In First Out |
| RTL | Register Transfer Level |

### B. 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | Wishbone B4 Specification (Rev B4) | OpenCores 官方规范 |
| REF-002 | AMBA AXI4-Lite Protocol Spec (ARM IHI 0022E) | AXI4-Lite 对比参考 |
| REF-003 | AMBA AHB Protocol Spec (ARM IHI 0011) | AHB 对比参考 |
