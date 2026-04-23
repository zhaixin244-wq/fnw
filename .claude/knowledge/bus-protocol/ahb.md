# AHB 接口协议

> **用途**：高性能系统总线，支持突发传输和流水线操作
> **规范版本**：AMBA AHB5 (ARM IHI 0033E)
> **典型应用**：CPU 系统总线、DMA 控制器、SRAM 控制器

---

## 协议概述

AHB（Advanced High-performance Bus）是 ARM AMBA 总线家族中的高性能系统总线，定位于处理器与高带宽外设之间的片上互连。

**在 AMBA 总线体系中的定位**：

```
┌─────────────────────────────────────────────────┐
│  AMBA 总线层次                                   │
│                                                 │
│  高性能层：  AXI4 / AXI5        ← 高带宽互连    │
│  系统层：    AHB5 / AHB-Lite    ← 系统总线      │
│  外设层：    APB4 / APB5        ← 低速外设寄存器 │
│                                                 │
│  AHB = AXI4 的前身/简化版                       │
│  AHB → APB 桥连接外设总线                       │
└─────────────────────────────────────────────────┘
```

**核心特性**：

- **流水线架构**：地址阶段和数据阶段重叠，提高总线吞吐率
- **突发传输**：支持增量（INCR）和回绕（WRAP）突发，最大 16 拍
- **单 Master 多 Slave**：基本配置为单主设备仲裁，通过地址译码选择从设备
- **多 Master 仲裁**：可扩展为多主设备，通过仲裁器分配总线权限
- **非三态总线**：AHB5 去除了三态驱动，使用多路复用器互连（DFT 友好）
- **单周期总线移交**：无等待状态的主设备切换，仅需 1 个时钟周期

**适用场景**：

- 嵌入式处理器系统总线（Cortex-M / Cortex-R 系列内部总线）
- 中等带宽 DMA 控制器
- SRAM / ROM 控制器
- AHB-to-APB 桥接（连接外设总线）
- 需要简化仲裁的 SoC 互连

**AHB-Lite 变体**：

AHB-Lite 是 AHB 的简化版本，仅支持单 Master，去除了仲裁逻辑，广泛用于 Cortex-M 系列处理器内部。AHB-Lite = AHB 总线去仲裁器。

---

## AHB 流水线架构

AHB 采用两阶段流水线：**地址阶段**和**数据阶段**，两个阶段在时间上重叠。

### 流水线原理

```
时钟周期：   T1        T2        T3        T4        T5
           ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐
HCLK       │    │    │    │    │    │    │    │    │    │
           └────┘    └────┘    └────┘    └────┘    └────┘

地址阶段：  [Txn A ]  [Txn B ]  [Txn C ]  [Txn D ]
            addr_A    addr_B    addr_C    addr_D

数据阶段：            [Txn A ]  [Txn B ]  [Txn C ]  [Txn D ]
                      data_A    data_B    data_C    data_D
```

- T1：Master 发送事务 A 的地址和控制信息
- T2：事务 A 的数据阶段开始（Slave 返回数据或接收写数据），同时 Master 发送事务 B 的地址
- T3：事务 B 的数据阶段，同时 Master 发送事务 C 的地址
- 以此类推...

### 流水线优势

| 优势 | 说明 |
|------|------|
| 提高吞吐 | 地址译码与数据传输重叠，无等待开销 |
| 降低延迟 | 连续传输时每个事务仅占 1 个时钟周期（无等待时） |
| 简化仲裁 | 地址阶段完成后仲裁器可立即为下一事务分配总线 |

### 流水线的代价

如果 Slave 需要插入等待状态（HREADY 拉低），整个流水线会暂停，后续所有事务都会被延迟。这是 AHB 与 AXI4 的关键区别：AXI4 的读写通道独立，一个通道的等待不会阻塞另一个通道。

---

## 信号表

### 系统信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `HCLK` | - | 1 | 总线时钟，所有 AHB 信号在 HCLK 上升沿采样 |
| `HRESETn` | - | 1 | 低有效异步复位，复位期间 HTRANS = IDLE |

### 主设备输出信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `HADDR[ADDR_WIDTH-1:0]` | M→S | 10~64 | 传输地址，通常 32 位 |
| `HWDATA[DATA_WIDTH-1:0]` | M→S | 8~1024 | 写数据，通常 32/64/128/256 位 |
| `HWRITE` | M→S | 1 | 传输方向：0=读，1=写 |
| `HSIZE[2:0]` | M→S | 3 | 传输大小（见传输大小章节） |
| `HBURST[2:0]` | M→S | 3 | 突发类型（见突发传输章节） |
| `HTRANS[1:0]` | M→S | 2 | 传输类型（见传输类型章节） |
| `HPROT[3:0]` | M→S | 4 | 保护控制：[0]=操作类型(0=Opcode/1=Data)，[1]=用户/特权，[2]=可缓存/不可缓存，[3]=可缓冲/不可缓冲 |
| `HMASTLOCK` | M→S | 1 | 锁定总线访问（Locked Transfer），原子操作时拉高 |
| `HREADYOUT` | S→M | 1 | 从设备就绪输出（AHB5 多 Slave 使用） |

### 从设备输出信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `HRDATA[DATA_WIDTH-1:0]` | S→M | 8~1024 | 读数据 |
| `HREADY` | S→M | 1 | 传输完成：0=插入等待，1=传输完成 |
| `HRESP` | S→M | 1 | 传输响应：0=OKAY，1=ERROR（AHB5 简化为 1 位） |

### 译码器信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `HSELx` | DEC→S | 1 | 从设备选择信号，每个从设备一个，由地址译码器产生 |
| `HREADY` | →S | 1 | 全局 HREADY，所有从设备的 HREADYOUT 线与 |

### 多路复用器信号（多 Slave 系统）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `HRDATA` | MUX→M | DATA_WIDTH | 读数据多路复用输出 |
| `HRESP` | MUX→M | 1 | 响应多路复用输出 |
| `HREADY` | MUX→M | 1 | 全局 HREADY（所有从设备 AND） |

### AHB-Lite vs AHB5 信号差异

| 差异点 | AHB-Lite | AHB5 |
|--------|----------|------|
| HRESP 位宽 | 2 位（OKAY/ERROR/RETRY/SPLIT） | 1 位（OKAY/ERROR） |
| HREADYOUT | 每个从设备独立输出 | 每个从设备独立输出 |
| 三态总线 | 不使用 | 不使用 |
| HNONSEC | 无 | 有（TrustZone 安全扩展） |

> **注意**：AHB5 删除了 RETRY 和 SPLIT 响应（简化设计），仅保留 OKAY 和 ERROR。旧版 AHB 使用 2 位 HRESP。

---

## 传输类型（HTRANS）

HTRANS[1:0] 指示当前地址阶段的传输类型。

| 编码 | 名称 | 说明 |
|------|------|------|
| `2'b00` | **IDLE** | 主设备无有效传输，从设备忽略当前地址阶段并返回 OKAY |
| `2'b01` | **BUSY** | 主设备在突发传输中插入空闲周期，从设备忽略当前地址阶段 |
| `2'b10` | **NONSEQ** | 单次传输或突发传输的第一拍，地址和控制信号与前一传输无关 |
| `2'b11` | **SEQ** | 突发传输中的后续拍，地址与前一传输相关（递增或回绕） |

### HTRANS 状态机

```
                  ┌──────────┐
                  │          │
                  ▼          │
              ┌───────┐     │
         ┌───►│ IDLE  │─────┘ (无传输或复位后)
         │    └───────┘
         │         │ start
         │         ▼
         │    ┌────────┐
         │    │ NONSEQ │ ◄─── 突发第一拍 / 单次传输
         │    └────────┘
         │         │ burst 继续
         │         ▼
         │    ┌───────┐     ┌───────┐
         │    │  SEQ  │────►│ BUSY  │ (Master 暂停)
         │    └───────┘     └───────┘
         │         │              │
         │         │ burst 结束   │ resume
         │         └──────┬───────┘
         │                │
         └────────────────┘ (回到 IDLE 或开始新 NONSEQ)
```

### HTRANS 使用示例

```
突发传输 4 拍 INCR：
Cycle:    1        2        3        4        5
HTRANS:   NONSEQ   SEQ      SEQ      SEQ      IDLE
HADDR:    0x1000   0x1004   0x1008   0x100C   (无效)

单次传输：
Cycle:    1        2
HTRANS:   NONSEQ   IDLE
HADDR:    0x2000   (无效)
```

---

## 突发传输（HBURST）

HBURST[2:0] 定义突发传输的类型和长度。

### 突发类型表

| 编码 | 名称 | 类型 | 长度（拍） | 说明 |
|------|------|------|-----------|------|
| `3'b000` | **SINGLE** | 单次 | 1 | 单次传输，无突发 |
| `3'b001` | **INCR** | 递增 | 未定义 | 递增突发，长度由 HTRANS 决定 |
| `3'b010` | **WRAP4** | 回绕 | 4 | 4 拍回绕突发 |
| `3'b011` | **INCR4** | 递增 | 4 | 4 拍递增突发 |
| `3'b100` | **WRAP8** | 回绕 | 8 | 8 拍回绕突发 |
| `3'b101` | **INCR8** | 递增 | 8 | 8 拍递增突发 |
| `3'b110` | **WRAP16** | 回绕 | 16 | 16 拍回绕突发 |
| `3'b111` | **INCR16** | 递增 | 16 | 16 拍递增突发 |

### 递增突发（INCR）

地址逐拍递增，递增量 = 传输大小（HSIZE）。

```
INCR4，HSIZE=WORD（4 字节）：
拍数：     1        2        3        4
HADDR：   0x1000   0x1004   0x1008   0x100C
```

### 回绕突发（WRAP）

地址递增到回绕边界后回到起始边界，常用于 Cache Line 填充。

回绕边界 = 突发长度 × 传输大小。

```
WRAP4，HSIZE=WORD（4 字节），起始地址 0x100C：
回绕边界 = 4 × 4 = 16 字节（0x1000 ~ 0x100F）

拍数：     1        2        3        4
HADDR：   0x100C   0x1010   0x1014   0x1018
                                      ↑ 超出边界，回绕到 0x1000

实际效果：地址在 0x1000~0x100F 范围内回绕
HADDR：   0x100C   0x1000   0x1004   0x1008
```

### INCR（未定义长度）

INCR（非 INCR4/8/16）为未定义长度的递增突发：
- 主设备通过在最后一拍将 HTRANS 设为 NONSEQ（或 IDLE）来结束突发
- 最大长度受 Slave 限制（通常不超过 1KB 地址边界）
- 不能跨越 1KB 地址边界

---

## 传输大小（HSIZE）

HSIZE[2:0] 定义每拍传输的数据宽度。

| 编码 | 名称 | 字节数 | 说明 |
|------|------|--------|------|
| `3'b000` | **BYTE** | 1 | 字节传输 |
| `3'b001` | **HWORD** | 2 | 半字传输（Halfword） |
| `3'b010` | **WORD** | 4 | 字传输 |
| `3'b011` | **DWORD** | 8 | 双字传输（64 位） |
| `3'b100` | - | 16 | 128 位传输 |
| `3'b101` | - | 32 | 256 位传输 |
| `3'b110` | - | 64 | 512 位传输 |
| `3'b111` | - | 128 | 1024 位传输 |

**约束**：HSIZE 的值不能超过总线数据宽度。例如 32 位数据总线，HSIZE 最大为 WORD（3'b010）。

---

## 写事务时序

### 基本写事务（流水线）

```
时钟周期：  T1        T2        T3        T4        T5
           ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
HCLK       │   │    │   │    │   │    │   │    │   │
           └───┘    └───┘    └───┘    └───┘    └───┘

HADDR：    |<-A0-->| |<-A1-->| |<-A2-->| |xxxxxxx| |xxxxxxx|
           0x1000    0x1004    0x1008

HWDATA：              |<-D0-->| |<-D1-->| |<-D2-->|
                      data_A0   data_A1   data_A2

HWRITE：    1         1         1         x         x

HTRANS：   NONSEQ    SEQ       SEQ      IDLE      IDLE

HSIZE：    WORD      WORD      WORD

HREADY：    1         1         1         1         1

时序说明：
T1: Master 发送地址 A0, HTRANS=NONSEQ（写突发开始）
T2: 地址阶段 T2 发送 A1, 同时数据阶段将 D0 放到 HWDATA
T3: 地址阶段 T3 发送 A2, 同时数据阶段将 D1 放到 HWDATA
T4: 数据阶段将 D2 放到 HWDATA, 无新地址（HTRANS=IDLE）
```

### 带等待状态的写事务

```
时钟周期：  T1        T2        T3        T4        T5
           ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
HCLK       │   │    │   │    │   │    │   │    │   │
           └───┘    └───┘    └───┘    └───┘    └───┘

HADDR：    |<-A0-->| |<-A0-->| |<-A1-->| |xxxxxxx| |xxxxxxx|
           0x1000    (保持)    0x1004

HWDATA：              |<-D0-->| |<-D0-->| |<-D1-->|
                      (保持)    (保持)

HWRITE：    1         1         1         1         x

HTRANS：   NONSEQ   NONSEQ    SEQ      IDLE      IDLE
           (保持不变，因为 Slave 未就绪)

HREADY：    1         0    ─┐   1         1         1
                      ↑      │
                      Slave  │
                      等待   │
                      T2 地址阶段重新开始

时序说明：
T1: Master 发送地址 A0
T2: Slave 拉低 HREADY=0，插入等待周期，Master 保持地址和控制信号不变
T3: Slave 拉高 HREADY=1，传输完成。地址 A0 的数据在 T3 完成
T3: 同时 Master 发送地址 A1（新的 SEQ 传输）
```

---

## 读事务时序

### 基本读事务（无等待）

```
时钟周期：  T1        T2        T3        T4        T5
           ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
HCLK       │   │    │   │    │   │    │   │    │   │
           └───┘    └───┘    └───┘    └───┘    └───┘

HADDR：    |<-A0-->| |<-A1-->| |<-A2-->| |xxxxxxx|
           0x1000    0x1004    0x1008

HRDATA：              |<-Q0-->| |<-Q1-->| |<-Q2-->|
                      data_A0   data_A1   data_A2

HWRITE：    0         0         0         x

HTRANS：   NONSEQ    SEQ       SEQ      IDLE

HREADY：    1         1         1         1

时序说明：
T1: Master 发送读地址 A0, HTRANS=NONSEQ
T2: 地址阶段发送 A1, 同时 Slave 在 HRDATA 上返回 A0 的数据 Q0
T3: 地址阶段发送 A2, 同时 Slave 返回 A1 的数据 Q1
T4: Slave 返回 A2 的数据 Q2
```

### 带等待状态的读事务

```
时钟周期：  T1        T2        T3        T4        T5
           ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
HCLK       │   │    │   │    │   │    │   │    │   │
           └───┘    └───┘    └───┘    └───┘    └───┘

HADDR：    |<-A0-->| |<-A0-->| |<-A0-->| |xxxxxxx|
           0x1000    (保持)    (保持)

HRDATA：                        |<-Q0-->|
                                data_A0

HWRITE：    0         0         0         x

HTRANS：   NONSEQ   NONSEQ   NONSEQ    IDLE
           (保持不变)

HREADY：    1         0         1         1
                      ↑         ↑
                      Slave     Slave
                      等待      就绪

时序说明：
T1: Master 发送读地址 A0
T2: Slave 拉低 HREADY=0，插入 1 个等待周期
T3: Slave 准备好数据，拉高 HREADY=1，数据 Q0 出现在 HRDATA 上
T3: 读事务完成
```

### 读写混合事务

```
时钟周期：  T1        T2        T3        T4        T5
           ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
HCLK       │   │    │   │    │   │    │   │    │   │
           └───┘    └───┘    └───┘    └───┘    └───┘

HADDR：    |<-WrA->| |<-RdA->| |<-WrB->| |xxxxxxx|
           0x1000    0x2000    0x3000

HWDATA：              |<-D_A->|                      (写数据延迟 1 周期)
                      wr_data

HRDATA：                        |<-Q_A->|            (读数据延迟 1 周期)
                                rd_data

HWRITE：    1         0         1         x

HTRANS：   NONSEQ   NONSEQ   NONSEQ    IDLE

时序说明：
T1: 写事务 WrA 的地址阶段
T2: WrA 的数据阶段（HWDATA 放写数据），同时发送 RdA 的读地址
T3: RdA 的数据阶段（HRDATA 返回读数据），同时发送 WrB 的写地址
```

---

## 从设备响应

### HREADY + HRESP 组合

Slave 通过 HREADY 和 HRESP 信号向 Master 报告传输状态。

| HREADY | HRESP | 含义 | 说明 |
|--------|-------|------|------|
| 1 | 0 (OKAY) | 传输成功 | 正常完成 |
| 0 | 0 (OKAY) | 等待中 | Slave 需要更多时间，插入等待状态 |
| 1 | 1 (ERROR) | 传输错误 | 仅 1 周期，错误完成 |
| 0 → 1 | 1 → 1 (ERROR) | 两周期错误 | AHB5 之前的双周期错误响应 |

### AHB5 错误响应（单周期）

AHB5 简化了错误响应为单周期：

```
时钟周期：  T1        T2        T3
           ┌───┐    ┌───┐    ┌───┐
HCLK       │   │    │   │    │   │
           └───┘    └───┘    └───┘

HADDR：    |<-A0-->|
HRESP：              |ERROR|    |OKAY  |
HREADY：              1          1

T1: 地址阶段
T2: HREADY=1, HRESP=ERROR（错误在单周期内完成）
T3: 恢复 OKAY
```

### 旧版 AHB 两周期错误响应

旧版 AHB（非 AHB5）的 RETRY/SPLIT/ERROR 需要两个周期：

```
时钟周期：  T1        T2        T3        T4
           ┌───┐    ┌───┐    ┌───┐    ┌───┐
HCLK       │   │    │   │    │   │    │   │
           └───┘    └───┘    └───┘    └───┘

HADDR：    |<-A0-->| |<-A0-->|
HRESP：              |ERROR | |ERROR |
HREADY：              0        1

T1: 地址阶段
T2: HREADY=0, HRESP=ERROR（第一周期：插入等待 + 指示错误）
T3: HREADY=1, HRESP=ERROR（第二周期：错误完成）
T4: Master 重新发起传输
```

### 旧版 HRESP 编码（2 位）

| 编码 | 名称 | 说明 |
|------|------|------|
| `2'b00` | OKAY | 传输成功 |
| `2'b01` | ERROR | 传输错误（地址越界、权限错误等） |
| `2'b10` | RETRY | Slave 无法完成，Master 需重新发送（重试优先级高于 SPLIT） |
| `2'b11` | SPLIT | Slave 暂时无法响应，总线释放给其他 Master |

> RETRY 与 SPLIT 区别：RETRY 时仲裁器保持当前 Master 优先级不变；SPLIT 时仲裁器将该 Master 从仲裁中移除，直到 Slave 发出完成信号，提高了总线效率。

---

## 仲裁

AHB 支持多 Master 共享总线，由仲裁器（Arbiter）控制总线分配。

### 仲裁信号（旧版 AHB）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `HMASTER[3:0]` | Arbiter→ | 4 | 当前获得总线的 Master 编号 |
| `HMASTLOCK` | M→Arbiter | 1 | 锁定信号，当前 Master 需要原子操作 |
| `HBUSREQx` | M→Arbiter | 1 | Master x 的总线请求 |
| `HGRANTx` | Arbiter→M | 1 | Master x 获得总线授权 |

> **注意**：AHB-Lite 无仲裁信号（单 Master），AHB5 通常也使用 AHB-Lite 配置。

### 仲裁流程

```
         Master 0          Master 1          Arbiter
            │                  │                 │
            │  HBUSREQ0=1     │                 │
            ├────────────────────────────────────►
            │                  │  HBUSREQ1=1    │
            │                  ├───────────────►│
            │                  │                 │
            │  HGRANT0=1      │                 │
            │◄──────────────────────────────────┤
            │                  │  HGRANT1=0     │
            │                  │◄───────────────┤
            │                  │                 │
            │  (Master0 使用总线)                 │
            │                  │                 │
            │  HGRANT0=0      │  HGRANT1=1     │
            │◄────────────────┤◄───────────────┤
            │                  │                 │
            │                  │  (Master1 使用总线)
```

### 仲裁规则

1. **无等待仲裁切换**：AHB 支持单周期总线切换（当前 Master 传输完成后的下一个周期）
2. **Locked Transfer**：Master 拉高 HMASTLOCK 后，仲裁器必须保持该 Master 的总线权限直到锁定释放
3. **默认 Master**：仲裁器必须指定一个默认 Master，当无请求时由默认 Master 占用总线（HTRANS=IDLE）
4. **优先级**：可配置固定优先级或轮询（Round-Robin）仲裁

---

## 与 AXI4 对比表

| 特性 | AHB | AXI4 |
|------|-----|------|
| **通道数** | 地址/数据共享总线 | 5 个独立通道（AW/W/B/AR/R） |
| **流水线深度** | 2 级（地址+数据） | 多级 Outstanding |
| **最大突发长度** | 16 拍（INCR16） | 256 拍（INCR256） |
| **Outstanding** | 不支持 | 支持多个未完成事务 |
| **乱序完成** | 不支持 | 支持（通过 ID） |
| **字节选通（Write Strobe）** | 不支持（AHB5 新增 HWSTRB） | 支持（WSTRB） |
| **读写分离** | 共享总线，交替进行 | 读写通道独立，可并行 |
| **Slave 响应** | 1 位（AHB5）/ 2 位（旧版） | 2 位（OKAY/EXOKAY/SLVERR/DECERR） |
| **原子操作** | HMASTLOCK（Locked Transfer） | AxLOCK（Exclusive / Locked） |
| **QoS** | 无 | 有（AxQOS） |
| **区域映射** | 无 | 有（AxREGION） |
| **缓存属性** | HPROT[3:0] | AxCACHE[3:0] |
| **信号极性** | HRESETn（低有效） | ARESETn（低有效） |
| **总线拓扑** | 典型 Crossbar 或共享总线 | Crossbar / Mesh |
| **复杂度** | 低 | 高 |
| **典型频率** | 100~400 MHz | 200~1000+ MHz |
| **面积开销** | 小 | 大（多通道 + 仲裁 + 排序逻辑） |
| **适用场景** | 嵌入式系统、MCU、中等带宽 | 高性能 SoC、大数据通路 |

### 选择指南

| 场景 | 推荐 | 理由 |
|------|------|------|
| MCU 系统总线 | AHB-Lite | 单 Master，简单高效 |
| 中等带宽 DMA | AHB | 突发传输足够，面积小 |
| DDR 控制器接口 | AXI4 | 高带宽，多 Outstanding |
| GPU/NPU 数据通路 | AXI4 | 乱序 + Outstanding |
| 低速外设 | APB | 寄存器访问，无需 AHB |
| 多核共享内存 | AXI4 | 仲裁 + 乱序 + 缓存一致性 |

---

## 设计注意事项

### 1. 流水线 Hazard

AHB 流水线虽简单（仅 2 级），但仍需注意：

- **地址-数据相关**：当 Slave 用等待状态延迟数据阶段时，地址阶段可能已经被接收，需要 Slave 正确处理内部缓冲
- **HREADY 全局线**：所有 Slave 的 HREADY 输出需线与（wired-AND），任何一个 Slave 拉低 HREADY 都会暂停整个总线流水线

### 2. 等待状态插入

Slave 插入等待状态时的规则：

- **地址和控制信号必须保持稳定**：当 HREADY=0 时，Master 不能改变 HADDR、HWRITE、HSIZE、HBURST、HTRANS、HPROT
- **写数据必须保持稳定**：HWDATA 在 HREADY=0 期间不能变化
- **Slave 必须在合理时间内拉高 HREADY**：避免死锁（建议 ≤ 16 等待周期，有超时机制）

### 3. 地址边界约束

- **1KB 边界**：突发传输不能跨越 1KB 地址边界，否则需要拆分为两次传输
- **回绕边界对齐**：WRAP 突发的起始地址必须对齐到突发长度 × 传输大小
- **未对齐访问**：AHB 原生不支持字节选通（AHB5 除外），未对齐传输需要 Master 拆分

### 4. 复位行为

| 信号 | 复位值 | 说明 |
|------|--------|------|
| HTRANS | IDLE | 复位期间无传输 |
| HADDR | 任意 | 复位后 Master 应发 NONSEQ |
| HWRITE | 任意 | - |
| HSIZE | 任意 | - |
| HBURST | SINGLE | - |
| HREADY | 1 | 复位期间 Slave 应就绪 |
| HRESP | OKAY | - |

### 5. DFT 注意事项

- AHB5 去除了三态总线，使用多路复用器，DFT 更友好
- HRESETn 使用异步复位同步释放
- 地址译码器应有默认从设备（Default Slave），处理未映射地址

### 6. 跨 1KB 边界的突发拆分

```
起始地址 0x0FF0, HSIZE=WORD, INCR4：
原始地址序列：0x0FF0, 0x0FF4, 0x0FF8, 0x0FFC
                        ↑ 跨越 0x1000 边界！

需要拆分为：
突发 1：0x0FF0, 0x0FF4, 0x0FF8, 0x0FFC（4 拍，边界内）
突发 2：0x1000（新突发，跨边界后的剩余地址）
```

---

## AHB-to-APB 桥简述

AHB-to-APB 桥是连接 AHB 系统总线和 APB 外设总线的桥接模块，实现协议转换和时钟域跨越。

### 桥的定位

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│  AHB     │     │ AHB-to-APB   │     │  APB     │
│  Master  │────►│    Bridge    │────►│  Slave   │
│ (CPU/DMA)│     │              │     │ (外设)   │
└──────────┘     └──────────────┘     └──────────┘
  HCLK 时钟域      协议转换             PCLK 时钟域
```

### 桥的核心功能

1. **协议转换**：AHB 流水线事务 → APB 单拍读写
2. **地址译码**：生成 APB 外设的 PSELx 信号
3. **数据缓冲**：AHB 写数据锁存 → APB 写数据输出；APB 读数据 → AHB 读数据
4. **时钟域跨越**（如 HCLK ≠ PCLK）：同步控制信号
5. **等待状态插入**：AHB 事务未完成时拉低 HREADY

### 典型 AHB-to-APB 读时序

```
AHB 侧：
HCLK:      T1        T2        T3        T4        T5
HADDR:    |<-0x00->| |  -   |  |  -   |  |  -   |  |  -   |
HTRANS:   NONSEQ    IDLE      IDLE      IDLE      IDLE
HRDATA:              |  -   |  |  -   |  |  -   |  |<-DATA|
HREADY:    1         0         0         0         1

APB 侧：
PCLK:      T1        T2        T3        T4
PADDR:    |<-0x00->| |<-0x00->| |  -   |  |  -   |
PSEL:      0         1         1         0
PENABLE:   0         0         1         0
PRDATA:                          |<-DATA->|
PREADY:                           1

时序说明：
T1: AHB 地址阶段，桥锁存地址和控制信号，HREADY=0 插入等待
T2: APB 地址阶段，PSEL=1, PENABLE=0（SETUP 状态）
T3: APB 数据阶段，PSEL=1, PENABLE=1（ACCESS 状态），PREADY=1
T4: 桥将 APB 读数据返回 AHB，HREADY=1，AHB 传输完成
```

### 桥设计要点

| 要点 | 说明 |
|------|------|
| 地址映射 | 桥内需有地址译码逻辑，将 AHB 地址空间映射到 APB 地址空间 |
| 等待周期数 | AHB-to-APB 读最少需要 2 个 APB 周期（SETUP + ACCESS），即至少 2 个 HCLK 等待 |
| 写操作 | AHB 写可以流水化，但每个 APB 写仍需 SETUP + ACCESS 两个周期 |
| 默认从设备 | 桥应包含 Default Slave，对未映射地址返回 ERROR |
| PCLK 关系 | PCLK 通常为 HCLK 的分频（如 HCLK/2 或 HCLK/4） |
| 最大外设数 | 受 PSELx 译码线数量限制，典型支持 16 个外设 |
