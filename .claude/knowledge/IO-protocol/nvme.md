# NVMe (Non-Volatile Memory Express) 协议知识

> **目标读者**：数字 IC 设计架构师
> **版本基准**：NVMe 1.4 / NVMe 2.0
> **日期**：2026-04-15

---

## 1. 协议概述

NVMe (NVM Express) 是专为基于 PCIe 的 SSD (Solid State Drive) 设计的存储协议规范。它定义了 Host 与 SSD Controller 之间的通信接口，包括寄存器映射、命令集、队列机制和数据传输方式。

### 1.1 核心定位

```
+-------------------+     +-------------------+     +-------------------+
|   Host Software   |     |   NVMe Driver     |     |   NVMe Controller |
|   (Application)   |<--->|   (Kernel Space)  |<--->|   (SSD Firmware)  |
+-------------------+     +-------------------+     +-------------------+
                               |                          |
                               |    PCIe Transport        |
                               |  (TLP / Memory R/W)      |
                               +--------------------------+
```

### 1.2 规范版本演进

| 版本 | 发布年份 | 关键新增特性 |
|------|----------|-------------|
| NVMe 1.0 | 2011 | 基础规范：Admin/I/O Queue、PRP、命令集 |
| NVMe 1.1 | 2012 | 多路径 I/O、增强电源管理 |
| NVMe 1.2 | 2014 | SGL 支持、固件更新、End-to-End Data Protection (PI) |
| NVMe 1.3 | 2017 | Directive、Endurance Group、NVMe-MI（管理接口） |
| NVMe 1.4 | 2019 | Zoned Namespace (ZNS)、持久化内存区域、I/O Determinism |
| NVMe 2.0 | 2021 | Key-Value 命令集、Namespace Types、Zone Append、NVM Sets |

### 1.3 协议栈层次

```
+-------------------------------+
|        Application            |
+-------------------------------+
|        OS / NVMe Driver       |
+-------------------------------+
|    NVMe Command Set (NVM)     |  <- 本协议定义
+-------------------------------+
|    NVMe Transport (PCIe)      |  <- PCIe TLP 封装
+-------------------------------+
|    PCIe Physical Layer        |
+-------------------------------+
```

---

## 2. NVMe vs AHCI/SATA 对比

| 特性 | NVMe | AHCI (SATA) |
|------|------|-------------|
| **传输总线** | PCIe (Gen3/Gen4/Gen5) | SATA 3.0 (6 Gbps) |
| **最大队列数** | 65,535 I/O Queues | 1 Queue |
| **队列深度** | 65,536 entries | 32 entries |
| **命令大小** | 64 Bytes (SQ Entry) | NA (基于 FIS) |
| **命令处理延迟** | ~2.8 us (典型) | ~6 us (典型) |
| **最大未完成命令** | 65535 × 65536 ≈ 4G | 32 |
| **CPU 开销** | 低（精简命令集，中断合并） | 高（FIS 封装开销大） |
| **中断** | MSI-X，可 per-queue，中断合并 | 单一中断，无合并 |
| **并行性** | 多核独立队列，无锁竞争 | 共享队列，需原子操作 |
| **协议开销** | 64B/4B per cmd/cpl | 32B+ FIS 封装 |
| **电源管理** | APST（自主电源状态切换） | DEVSLP |
| **支持的介质** | NVMe SSD / Optane | SATA HDD / SSD |

**核心差异总结**：NVMe 的队列体系（多队列、深队列、无锁竞争）是其相对于 AHCI 的根本优势，适合高 IOPS、低延迟场景。

---

## 3. NVMe 寄存器映射 (Controller Registers)

NVMe Controller 通过 PCIe BAR 空间暴露一组寄存器，Host 通过 MMIO 访问。

```
+==========================================================+
|               NVMe Controller Register Map               |
|              (Mapped to PCIe BAR0 / BAR1)                |
+==========================================================+

Offset    Name                    Size   Access
------    ----                    ----   ------
0x0000    CAP (Capabilities)      8B     RO
           +--------------------------------------------------+
           | MPSMAX | MPSMIN | RSVD | MQES                   |
           | [55:52]| [51:48]|47:36 | [35:16]                |
           +--------------------------------------------------+
           |  CSS   | AMS    | RSVD | TO     | DSTRD|RSVD |1:0|
           | [15:12]| [11:08]|      | [07:00]|               | |
           +--------------------------------------------------+

0x0008    VS (Version)            4B     RO
           +--------------------------------------------------+
           | TER   | MNR   | MJR                              |
           |[31:24]|[23:16]| [15:00]                          |
           +--------------------------------------------------+

0x000C    INTMS (Interrupt Mask Set)      4B     RW1S
0x0010    INTMC (Interrupt Mask Clear)    4B     RW1C

0x0014    CC (Controller Configuration)   4B     RW
           +--------------------------------------------------+
           | EN  | RSVD  | CSS  | MPS  | AMS  |RSVD|IOCQES|IOSQES|
           | [00]| [03:01]|[07:04]|[10:07]|[12:11]|    |19:16|23:20|
           +--------------------------------------------------+

0x001C    Reserved                4B

0x0020    CSTS (Controller Status)        4B     RO
           +--------------------------------------------------+
           | RDY | CFS | PP  | RSVD                            |
           | [00]| [01]| [02]| [31:03]                         |
           +--------------------------------------------------+

0x0024    NSSR (NVM Subsystem Reset)      4B     RW

0x0028    AQA (Admin Queue Attributes)    4B     RW
           +--------------------------------------------------+
           | ACQS (CQ Depth)     | ASQS (SQ Depth)             |
           | [27:16]             | [11:00]                     |
           +--------------------------------------------------+

0x0030    ASQ (Admin SQ Base Address)     8B     RW (64B-aligned)
0x0038    ACQ (Admin CQ Base Address)     8B     RW (64B-aligned)

0x0040+   CMBLOC (Controller Memory Buffer)  略
0x0048+   CMBSZ                             略

------    Doorbell Registers (在 0x1000 附近)                 ------
0x1000    SQ0TDBL (Admin SQ Tail Doorbell)  4B    RW
0x1004    CQ0HDBL (Admin CQ Head Doorbell)  4B    RW
0x1008    SQ1TDBL (I/O SQ1 Tail Doorbell)   4B    RW
0x100C    CQ1HDBL (I/O CQ1 Head Doorbell)   4B    RW
          ...     (每 Queue pair 占 2×(2^DSTRD) Bytes)

+==========================================================+

DSTRD (Doorbell Stride) in CAP[31:16] bits [19:16]:
  实际 Stride = 2^DSTRD bytes，典型 DSTRD=0 → 每个 Doorbell 4 bytes。

Doorbell 寄存器起始地址 = CAP.DSTRD 决定偏移量。
SQ 和 CQ 的 Doorbell 交替排列：
  SQ0TDBL @ (2 * QueueID * (4 << DSTRD)) + base
  CQ0HDBL @ (2 * QueueID * (4 << DSTRD)) + 4 + base
```

---

## 4. 关键寄存器详解

### 4.1 CAP (Capabilities) — 偏移 0x0000，64-bit

| 位域 | 名称 | 描述 |
|------|------|------|
| [15:00] | TO (Timeout) | 超时值，单位 500ms。0 = 无超时限制 |
| [19:16] | DSTRD | Doorbell Stride = 2^DSTRD × 4 bytes |
| [23:20] | RSVD | 保留 |
| [27:24] | CSS (Command Sets Supported) | bit0=1 支持 NVM 命令集 |
| [31:28] | MPSMIN | 最小内存页大小 = 2^(12+MPSMIN) |
| [35:32] | MPSMAX | 最大内存页大小 = 2^(12+MPSMAX) |
| [51:36] | MQES | Maximum Queue Entries Supported = MQES+1 |
| [55:52] | CQES | CQ Entry Size 支持（NVMe 2.0+） |
| [59:56] | SQES | SQ Entry Size 支持（NVMe 2.0+） |
| [63:60] | RSVD | 保留 |

**典型值**：
- MQES = 0xFFFF → 最大 65536 entries
- MPSMIN = 0 → 最小页 4KB
- MPSMAX = 0 → 最大页 4KB（常见）

### 4.2 CC (Controller Configuration) — 偏移 0x0014，32-bit

| 位域 | 名称 | 描述 |
|------|------|------|
| [00] | EN (Enable) | 1 = 使能 Controller |
| [03:01] | RSVD | 保留 |
| [07:04] | CSS (Command Set Selected) | 0x6=NVM Command Set |
| [10:07] | MPS (Memory Page Size) | 页大小 = 2^(12+MPS) |
| [12:11] | AMS (Arbitration Mechanism) | 00=Round Robin, 01=WRR |
| [15:13] | RSVD | 保留 |
| [19:16] | IOCQES (I/O CQ Entry Size) | 2^IOCQES DW (典型 4→64B) |
| [23:20] | IOSQES (I/O SQ Entry Size) | 2^IOSQES DW (典型 6→256B) |
| [31:24] | RSVD | 保留 |

### 4.3 CSTS (Controller Status) — 偏移 0x0020，32-bit

| 位域 | 名称 | 描述 |
|------|------|------|
| [00] | RDY (Ready) | 1 = Controller 已就绪 |
| [01] | CFS (Controller Fatal Status) | 1 = 致命错误 |
| [02] | PP (Processing Paused) | 1 = 处理暂停（NVMe 1.4+） |
| [03] | SHST (Shutdown Status) | 00=正常, 01=进行中, 10=完成 |
| [04] | NSSRO (NVM Subsystem Reset Occurred) | 1 = 发生子系统复位 |
| [31:05] | RSVD | 保留 |

### 4.4 Controller 初始化流程

```
Host                                   Controller
  |                                       |
  |--- 1. Read CAP, VS (了解能力) -------->|
  |<--------------------------------------|
  |                                       |
  |--- 2. CC.EN = 0 (禁止 Controller) ---->|
  |--- 3. 等待 CSTS.RDY = 0 ------------->|
  |                                       |
  |--- 4. 配置 AQA (Queue 大小) ---------->|
  |--- 5. 写 ASQ (Admin SQ 基地址) ------->|
  |--- 6. 写 ACQ (Admin CQ 基地址) ------->|
  |--- 7. 配置 CC (CSS/MPS/AMS/IOSQES/IOCQES) ->|
  |--- 8. CC.EN = 1 (使能 Controller) ---->|
  |--- 9. 等待 CSTS.RDY = 1 ------------->|
  |                                       |
  |--- 10. 发送 Admin 命令 (Identify...) ->|
  |<-- 11. 收到 CQ Completion ------------|
  |                                       |
  |--- 12. Create I/O CQ / SQ ----------->|
  |--- 13. I/O 就绪                       |
```

---

## 5. 队列体系

### 5.1 队列架构总览

```
+------------------------------------------------------+
|                    Host (CPU Cores)                   |
|                                                      |
|  Core 0          Core 1          Core N              |
|  +-------+       +-------+       +-------+           |
|  | I/O SQ|       | I/O SQ|       | I/O SQ|           |
|  | I/O CQ|       | I/O CQ|       | I/O CQ|           |
|  +---|---+       +---|---+       +---|---+           |
|      |               |               |               |
|  +---|---+       +---|---+       +---|---+           |
|  |Admin  |       |       |       |       |           |
|  |SQ |CQ |       |       |       |       |           |
|  +---|---+       +---|---+       +---|---+           |
|      |               |               |               |
+======|===============|===============|===============+
       |               |               |
+======|===============|===============|==================+
| NVMe Controller (SSD)                                   |
|                                                         |
|  +----------------+  +----------------+                 |
|  |  Admin Queue   |  |  I/O Queues    |                 |
|  |  Processing    |  |  Processing    |                 |
|  +----------------+  +----------------+                 |
|  |  SQ Fetch DMA  |  |  SQ Fetch DMA  |                 |
|  |  Cmd Decode    |  |  Cmd Decode    |                 |
|  |  Data Xfer     |  |  Data Xfer     |                 |
|  |  CQ Write      |  |  CQ Write      |                 |
|  +----------------+  +----------------+                 |
|                                                         |
|  +------------------------------------------+          |
|  |          Flash Translation Layer          |          |
|  +------------------------------------------+          |
|  |          NAND Flash Controller           |          |
|  +------------------------------------------+          |
+---------------------------------------------------------+
```

### 5.2 Admin Queue

| 项目 | 值 |
|------|-----|
| 数量 | 固定 1 SQ + 1 CQ |
| 用途 | 管理命令（非数据 I/O） |
| 由谁创建 | Host 在 CC.EN=1 之前配置（AQA/ASQ/ACQ 寄存器） |
| Doorbell | SQ0TDBL / CQ0HDBL |

**Admin 命令类别**：
- Identify Controller / Namespace
- Create / Delete I/O SQ / CQ
- Set Features / Get Features
- Get Log Page
- Firmware Image Download / Activate
- Abort
- Asynchronous Event Request

### 5.3 I/O Queue

| 项目 | 值 |
|------|-----|
| 最大数量 | 65535 SQ + 65535 CQ |
| 由谁创建 | 通过 Admin 命令（Create I/O CQ / Create I/O SQ）创建 |
| 队列关联 | 每个 SQ 关联到一个 CQ（SQ.CQID 指定） |
| 多对一 | 多个 SQ 可以关联同一个 CQ |
| 典型配置 | 每 CPU 核心 1 SQ + 1 CQ |

### 5.4 SQ/CQ 数据结构

#### Submission Queue Entry (SQ Entry) — 16~64 DW (64~256 Bytes)

```
DW  |  Byte 0  |  Byte 1  |  Byte 2  |  Byte 3
----+-----------+----------+----------+----------
00  |  CDW0 (Opcode | FUSE | PSDT | CID)
01  |  NSID (Namespace Identifier)
02  |  Reserved
03  |  Reserved
04  |  MPTR (Metadata Pointer) [31:0]
05  |  MPTR (Metadata Pointer) [63:32]
06  |  PRP1 / SGL1 Addr [31:0]     (Data Pointer)
07  |  PRP1 / SGL1 Addr [63:32]    (Data Pointer)
08  |  PRP2 / SGL2 Addr [31:0]     (or PRP List)
09  |  PRP2 / SGL2 Addr [63:32]
10  |  CDW10 (Command Specific DW10)
11  |  CDW11 (Command Specific DW11)
12  |  CDW12 (Command Specific DW12)
13  |  CDW13 (Command Specific DW13)
14  |  CDW14 (Command Specific DW14)
15  |  CDW15 (Command Specific DW15)
```

**CDW0 位域**：
```
 31     16 15   14  13:12  11:10    08:07   06:00
+---------+------+-------+---------+-------+--------+
|   CID   | FUSE | PSDT  |  RSVD   |  SGL  |Opcode  |
|         |      |       |         |SubType|        |
+---------+------+-------+---------+-------+--------+
```

#### Completion Queue Entry (CQ Entry) — 4 DW (16 Bytes)

```
DW  |  Byte 0  |  Byte 1  |  Byte 2  |  Byte 3
----+-----------+----------+----------+----------
00  |  DW0 (Command Specific, 如 LSP)
01  |  DW1 (SQ Head Pointer [31:16] | SQ ID [15:00])
02  |  DW2 (Status: P | SF [14:00] | CID [31:16])
03  |  DW3 (Phase Tag 保留)
```

**CQ Status Field (DW2)**：
```
 31:17  16      15:01    00
+------+----+----------+---+
| CID  | P  | Status   |   |
|      |Tag |Field(SF) |   |
+------+----+----------+---+

P (Phase Tag)：每轮 CQ 轮转取反，Host 用于判断 entry 是否为新完成。
Status Field：包含 DNR (Do Not Retry) | M (More) | CRD | SCT (Status Code Type) | SC (Status Code)
```

### 5.5 Doorbell 机制

```
+------+     SQ Doorbell (Tail)      +------------------+
| Host | ---------------------------> | NVMe Controller  |
|      |   写 SQnTDBL = new_tail      |                  |
|      |                              | Controller 读取  |
|      |     CQ Doorbell (Head)       | SQ Tail 与 Head  |
|      | ---------------------------> | 之间的新 entry   |
|      |   写 CqnHDBL = new_head      |                  |
+------+                              +------------------+

流程：
1. Host 写入 SQ Entry
2. Host 更新 SQ Tail 指针
3. Host 写 SQ Doorbell 寄存器（MMIO 写 SQnTDBL = 新 Tail 值）
4. Controller 检测到 Doorbell 变化，从 Host 内存 DMA SQ Entry
5. Controller 执行命令，写入 CQ Entry 到 Host 内存
6. Controller 发送中断（或 Host 轮询 CQ Phase Tag）
7. Host 处理 CQ Entry，更新 CQ Head
8. Host 写 CQ Doorbell 寄存器（MMIO 写 CqnHDBL = 新 Head 值）
```

**Doorbell 写操作是 PCIe Posted Write，Host 不等待 ACK。**

### 5.6 中断合并 (Interrupt Coalescing)

```
CQ Completion 1 ─┐
CQ Completion 2 ──┼──> 合并定时器 ──> 单个 MSI-X 中断
CQ Completion 3 ──┘

寄存器：Set Features - Interrupt Coalescing
  - Aggregation Time (us): 合并时间窗口
  - Aggregation Threshold (entries): 合并条目数
  - 两者取先到者触发中断
```

| 参数 | 描述 |
|------|------|
| 合并时间 | 设定时间窗口，窗口内完成的命令合并为一次中断 |
| 合并阈值 | 窗口内完成条目数达到阈值时触发中断 |
| 中断向量 | 每个 CQ 可绑定独立 MSI-X 向量 |
| 轮询模式 | 可配置为纯轮询（禁用中断），延迟更低 |

---

## 6. 命令集

### 6.1 Admin 命令 (Opcode 0x00-0xFF)

| Opcode | 命令名称 | 描述 |
|--------|----------|------|
| 0x00 | Delete I/O SQ | 删除 I/O Submission Queue |
| 0x01 | Create I/O SQ | 创建 I/O Submission Queue |
| 0x02 | Get Log Page | 获取日志页（SMART、错误、固件等） |
| 0x04 | Delete I/O CQ | 删除 I/O Completion Queue |
| 0x05 | Create I/O CQ | 创建 I/O Completion Queue |
| 0x06 | Identify | Identify Controller / Namespace |
| 0x08 | Abort | 中止指定命令 |
| 0x09 | Set Features | 设置特性（电源管理、中断合并等） |
| 0x0A | Get Features | 获取特性 |
| 0x0C | Asynchronous Event Request | 异步事件请求 |
| 0x0D | Firmware Activate | 激活固件 |
| 0x10 | Firmware Image Download | 下载固件镜像 |
| 0x11 | Device Self-test | 设备自检 |
| 0x18 | Namespace Management | 创建/删除 Namespace |
| 0x19 | Namespace Attachment | 关联/解除 Namespace 到 Controller |
| 0x1C | Keep Alive | 保活（NVMe-oF 使用） |
| 0x1D | Directive Send | 指令发送（NVMe 1.3+） |
| 0x1E | Directive Receive | 指令接收（NVMe 1.3+） |

### 6.2 NVM 命令 (I/O 命令集)

| Opcode | 命令名称 | 描述 |
|--------|----------|------|
| 0x00 | Flush | 将 volatile write cache 刷到 NVM |
| 0x01 | Write | 写入 LBA 数据 |
| 0x02 | Read | 读取 LBA 数据 |
| 0x04 | Write Uncorrectable | 标记 LBA 为不可纠正 |
| 0x05 | Compare | 比较 LBA 数据与传输数据 |
| 0x06 | Write Zeroes | 写入全 0（zero-fill） |
| 0x08 | Dataset Management | TRIM / Deallocate / 其他 |
| 0x09 | Reservation Register | 注册持久化保留 |
| 0x0A | Reservation Report | 报告持久化保留 |
| 0x0D | Reservation Acquire | 获取持久化保留 |
| 0x0E | Reservation Release | 释放持久化保留 |
| 0x0F | Verify | 校验 LBA 数据（NVMe 2.0+） |

### 6.3 命令格式详解

以 **Read 命令 (Opcode=0x02)** 为例：

```
DW00: 0x0000_0002   (Opcode=0x02, CID=0x0000, 其他=0)
DW01: NSID          (Namespace ID)
DW02: 0x0000_0000
DW03: 0x0000_0000
DW04: MPTR_LO       (Metadata Pointer, 如不使用则 0)
DW05: MPTR_HI
DW06: PRP1_LO       (Data Buffer 物理地址低 32bit)
DW07: PRP1_HI
DW08: PRP2_LO       (或 PRP List 指针)
DW09: PRP2_HI
DW10: SLBA[31:0]    (起始 LBA 低 32bit)
DW11: SLBA[63:32]   (起始 LBA 高 32bit)
DW12: NLB[15:0]     (Number of Logical Blocks - 1)
      LR  [16]      (Limited Retry)
      FUA [17]      (Force Unit Access)
      PRINFO[20:17] (Protection Info)
      DTYPE[24:23]  (Directive Type)
DW13: DSPEC[31:16]  (Directive Specific)
      DSM[07:00]    (Dataset Management)
DW14: EILBRT[31:00] (Expected Initial LB Reference Tag)
DW15: ELBAT[15:00]  (Expected LB Application Tag)
      ELBATM[31:16] (Expected LB Application Tag Mask)
```

以 **Write 命令 (Opcode=0x01)** 为例：格式与 Read 相同，区别在于 DW12/DW13 的写特有位。

---

## 7. 数据传输：PRP vs SGL

### 7.1 PRP (Physical Region Page)

```
+-----------+      +-----------+      +-----------+
| SQ Entry  |      | PRP List  |      | Data      |
|           |      | (in Mem)  |      | Buffers   |
| PRP1: ----+----->| PRP[0]    |----->| Buffer 1  |
| PRP2: ----+----->| PRP[1]    |----->| Buffer 2  |
|           |      | PRP[2]    |----->| Buffer 3  |
|           |      | ...       |      | ...       |
|           |      | PRP[n]    |----->| Buffer n  |
+-----------+      +-----------+      +-----------+
```

- PRP1 / PRP2 直接嵌入 SQ Entry (DW6-DW9)
- PRP1：第一个页地址
- PRP2：若数据跨 2 页以内，PRP2 放第二个页地址；若超过 2 页，PRP2 指向 PRP List（一个页中放多个 PRP entry）
- 每个 PRP entry = 8 字节，一页（4KB）可放 512 个 PRP entry
- PRP Entry 格式：页地址 + 页内偏移（低 12 位 = 页内偏移，必须是数据长度的整数倍）

### 7.2 SGL (Scatter Gather List)

```
+-----------+      +-----------+      +-----------+
| SQ Entry  |      | SGL       |      | Data      |
|           |      | Segments  |      | Buffers   |
| SGL1: ----+----->| SGL Desc 0|----->| Buffer 0  |
| (SGL Addr |      |  Addr/Len |      |           |
|  在 DW6-9)|      | SGL Desc 1|----->| Buffer 1  |
|           |      |  Addr/Len |      |           |
|           |      | SGL Desc n|----->| Buffer n  |
+-----------+      +-----------+      +-----------+
```

**SGL Descriptor 格式 (16 bytes)**：
```
Byte 0-7:  SGL Segment Address (64-bit 物理地址)
Byte 8-11: Length (32-bit)
Byte 12:   SGL Identifier
Byte 13:   RSVD
Byte 14-15: RSVD
```

**SGL 段类型 (Descriptor Type in byte 12, bits [3:0])**：
| 值 | 类型 | 描述 |
|----|------|------|
| 0x0 | Data Block | 数据块地址和长度 |
| 0x1 | Bit Bucket | 丢弃数据（Write Zeroes 等） |
| 0x2 | Segment | 指向下一个 SGL Segment |
| 0x3 | Last Segment | 最后一个 SGL Segment |
| 0xF | Transport Data | NVMe-oF 使用 |

### 7.3 PRP vs SGL 选择

| 特性 | PRP | SGL |
|------|-----|-----|
| 复杂度 | 简单（页对齐地址链） | 灵活（任意地址/长度） |
| 连续性要求 | 必须页对齐 | 无对齐要求 |
| 元数据支持 | 原生支持 | 需额外描述 |
| 典型使用 | 本地 NVMe SSD | NVMe-oF、复杂存储 |
| 控制器实现 | 更简单 | 需要更多硬件资源 |

---

## 8. 多核优化

```
CPU Core 0                  CPU Core 1
+-----------+              +-----------+
| App 0     |              | App 1     |
+-----+-----+              +-----+-----+
      |                          |
+-----+-----+              +-----+-----+
| I/O SQ 0  |              | I/O SQ 1  |
| I/O CQ 0  |              | I/O CQ 1  |
+-----+-----+              +-----+-----+
      |                          |
      |     MSI-X Vec 0          |     MSI-X Vec 1
      +-----------+  +-----------+
                  |  |
             +----+--+----+
             |  PCIe Bus  |
             +----+--+----+
                  |  |
             +----+--+----+
             | NVMe Ctrl  |
             +------------+

要点：
1. 每个 CPU 核心独立 SQ/CQ 对，无需锁竞争
2. 中断或轮询均可，按需选择
3. 中断合并减少中断开销
4. SQ Entry 直接提交到 Controller（Doorbell 写）
5. 多个 SQ 可共享一个 CQ（合并中断）
```

**多核性能对比**：

| 方案 | 队列数 | 并行性 | 锁开销 |
|------|--------|--------|--------|
| AHCI | 1 | 低 | 高（需自旋锁） |
| NVMe (1 Queue) | 1 | 低 | 高 |
| NVMe (N Queue) | N | 高 | 无（天然隔离） |

---

## 9. Namespace (命名空间)

### 9.1 基本概念

Namespace 是 NVM 存储的逻辑分区，类似磁盘分区。每个 Namespace 有独立的：
- NSID (Namespace ID)
- LBA 格式（大小、元数据长度）
- 容量和特性

```
+-------------------+     +-------------------+
|   Controller 0    |     |   Controller 1    |
+-------------------+     +-------------------+
| NS 1 (100GB)      |     | NS 1 (100GB)      |
| NS 2 (200GB)      |     | NS 3 (300GB)      |
| NS 3 (300GB)      |     |                   |
+-------------------+     +-------------------+
  NS 2 可被两个 Controller 共享（如使用 ANA）
```

### 9.2 LBA 格式

| 字段 | 说明 |
|------|------|
| LBA Size | 512B / 4KB（常见） |
| Metadata Size | 0 / 8 / 16 / 32 / 64 / 128 bytes |
| PI (Protection Info) | 端到端保护信息，0/8/16 bytes |
| Relative Performance | 最佳/更好/良好/降级 |

### 9.3 Namespace 管理

- Identify Namespace：获取 LBA 格式、容量、特性
- Namespace Management (Admin)：创建/删除 Namespace
- Namespace Attachment (Admin)：关联/解除 Controller
- Active Namespace List / ID List：枚举 Namespace

---

## 10. NVMe 特性

### 10.1 多路径 I/O & ANA (Asymmetric Namespace Access)

- 一个 Namespace 可被多个 Controller 访问
- ANA 状态：Optimized (最优路径)、Non-Optimized (非最优)、Inaccessible、Persistent Loss
- Host 驱动根据 ANA 状态选择路径

### 10.2 Zoned Namespace (ZNS) — NVMe 1.4+

```
+------------------------------------------+
|             Zoned Namespace              |
+-----+-----+-----+-----+-----+-----+----+
|Zone |Zone |Zone |Zone |Zone |Zone |    |
|  0  |  1  |  2  |  3  |  4  |  5  |... |
+-----+-----+-----+-----+-----+-----+----+
  ^写入方向→（顺序写入，随机读取）

Zone 命令集：
  - Zone Management Send (Zone Append, Close, Finish, Reset, Open)
  - Zone Management Report (列举 Zone 状态)
```

- Zone 状态：Empty → Open → Closed → Full → Offline
- 消除 FTL 写放大，延长 SSD 寿命
- 适用于数据库日志、视频存储等顺序写场景

### 10.3 持久化内存区域 (Persistent Memory Region)

- Controller 可暴露一块 NVM 作为持久化内存窗口
- Host 通过 PCIe 直接读写（非 DMA），类似 DAX
- 适用：PMEM 替代方案

### 10.4 Key-Value 命令集 (NVMe 2.0+)

| 命令 | Opcode | 描述 |
|------|--------|------|
| KV Write | 0x01 | 写入 Key-Value 对 |
| KV Read | 0x02 | 读取 Key-Value 对 |
| KV Delete | 0x10 | 删除 Key-Value 对 |
| KV Exist | 0x14 | 查询 Key 是否存在 |

### 10.5 End-to-End 数据保护 (PI / DIF)

```
+--------+---------+--------+
|  LBA   |  Data   |  PI    |   <- 传输时附加保护信息
+--------+---------+--------+
| 512/4K |  N bytes|8/16 B  |

PI (Protection Information) 内容：
  - Guard Tag: CRC-16 校验（覆盖整个 LBA 数据）
  - Application Tag: 应用自定义标签
  - Reference Tag: LBA 地址的 CRC 或线性递增

PI Type：
  Type 1: Guard + App Tag + Ref Tag (用于固定映射)
  Type 2: Guard + App Tag + Ref Tag (用于日志映射)
  Type 3: Guard + App Tag (无 Ref Tag)
```

---

## 11. NVMe-oF 简述

NVMe-oF (NVMe over Fabrics) 将 NVMe 命令扩展到网络传输层，使远程 NVMe 存储对 Host 而言如同本地 NVMe 设备。

### 11.1 传输类型

| 传输层 | 描述 | 特点 |
|--------|------|------|
| RDMA | NVMe/RoCE, NVMe/iWARP | 低延迟、零拷贝 |
| TCP | NVMe/TCP | 通用性好、无特殊网卡需求 |
| Fibre Channel | NVMe/FC | 企业存储传统网络 |
| InfiniBand | NVMe/IB | HPC 领域 |

### 11.2 与本地 NVMe 的差异

| 特性 | 本地 NVMe | NVMe-oF |
|------|-----------|---------|
| 队列 | Doorbell MMIO | Fabric 特定传输 |
| 数据传输 | PRP / SGL (PCIe DMA) | SGL (Fabric RDMA) |
| 命令集 | NVM Command Set | NVM Command Set (相同) |
| Keep Alive | 可选 | 必须支持 |
| Controller | 物理 PCIe | Fabric Controller |

> **详细 NVMe-oF 规范参考**：`nvme_of.md`

---

## 12. NVMe Controller RTL 设计注意事项

### 12.1 顶层架构

```
+----------------------------------------------------------+
|                   NVMe Controller (RTL)                   |
|                                                          |
|  +----------------------------------------------------+  |
|  |                PCIe BAR 译码模块                     |  |
|  |  (寄存器地址解码、Doorbell 识别、属性检查)          |  |
|  +------------------------+---------------------------+  |
|                           |                              |
|  +------------------------+---------------------------+  |
|  |                寄存器文件 (CSR)                      |  |
|  |  CAP / VS / CC / CSTS / AQA / ASQ / ACQ            |  |
|  |  Doorbell 寄存器组                                  |  |
|  +------------------------+---------------------------+  |
|                           |                              |
|  +---------+   +---------+----------+   +---------+     |
|  | Admin   |   | I/O Queue         |   | Interrupt|     |
|  | Queue   |   | Manager           |   | Generator|     |
|  | Process |   | (SQ/CQ DMA 引擎) |   | (MSI-X)  |     |
|  +---------+   +---------+----------+   +---------+     |
|            |              |                       |      |
|  +---------+--------------+-----------------------+      |
|  |           命令调度器 / 路由器                        |  |
|  +---------+--------------+-----------------------+      |
|            |              |                              |
|  +---------+     +--------+--------+                    |
|  | Data    |     | SGL/PRP 解析器  |                    |
|  | DMA     |     | (地址翻译)      |                    |
|  +---------+     +-----------------+                    |
|            |              |                              |
|  +---------+--------------+                              |
|  |       NAND Flash Controller 接口                      |
|  +------------------------------------------------------+
```

### 12.2 关键 RTL 设计点

#### 12.2.1 PCIe BAR 寄存器译码

| 注意事项 | 说明 |
|----------|------|
| BAR 空间映射 | BAR0 映射 NVMe 寄存器（0x0000-0x0FFF）+ Doorbell（0x1000+） |
| 64-bit 寄存器 | CAP (8B)、ASQ/ACQ (8B) 需处理 32-bit PCIe 事务的拆分 |
| Doorbell 译码 | 根据 CAP.DSTRD 计算每个 Doorbell 的偏移地址 |
| 写操作类型 | 寄存器写需要同步更新内部状态（如 CC.EN 变化触发初始化/去初始化） |
| 错误处理 | 对保留地址的写入应静默丢弃，读取返回 0 |

#### 12.2.2 SQ/CQ DMA 引擎

| 子模块 | 功能 |
|--------|------|
| SQ Fetch DMA | Doorbell 触发后，DMA 读取 SQ Entry 从 Host 内存到 Controller |
| CQ Write DMA | 命令完成后，DMA 写入 CQ Entry 到 Host 内存，触发中断 |
| SQ Head 跟踪 | 维护 SQ Head 指针（Controller 读取位置），写入 CQ 的 SQ Head Pointer |
| CQ Tail 跟踪 | 维护 CQ Tail 指针（Controller 写入位置） |
| 地址计算 | SQ Base + SQ Head × Entry Size = 当前读取地址 |

#### 12.2.3 Doorbell 处理

| 设计要点 | 说明 |
|----------|------|
| Doorbell 写检测 | PCIe TLP 写入 Doorbell 区域时触发 |
| Tail 值获取 | 从 TLP payload 提取新的 Tail 值 |
| 命令数计算 | New Entries = (Tail - Head) mod Queue Size |
| 批量处理 | 可一次处理多个新 Entry（DMA burst） |
| 优先级 | Admin Queue Doorbell 优先级高于 I/O Queue |

#### 12.2.4 PRP/SGL 解析

| 设计要点 | 说明 |
|----------|------|
| PRP 解析 | 从 SQ Entry DW6-9 提取 PRP1/PRP2，必要时 DMA 读取 PRP List |
| SGL 解析 | 按 SGL Descriptor 链遍历（需支持 Segment 链接） |
| 地址对齐检查 | PRP 要求页对齐，SGL 无对齐要求 |
| 页大小 | 根据 CC.MPS 配置 |
| 跨页处理 | PRP 页内偏移 + 长度不能超过页边界 |

#### 12.2.5 命令调度

| 策略 | 说明 |
|------|------|
| Round Robin | 简单轮询各 SQ |
| WRR (Weighted Round Robin) | 支持优先级加权 |
| Admin 优先 | Admin Queue 命令始终优先处理 |
| 并行度 | 支持多命令并行执行（依赖 NAND Flash 控制器能力） |
| 命令重排序 | 可根据 LBA 位置优化访问顺序 |

#### 12.2.6 中断生成

| 设计要点 | 说明 |
|----------|------|
| MSI-X 向量 | 每个 CQ 绑定独立向量 |
| 中断合并 | 硬件定时器 + 计数器实现 |
| 中断抑制 | Set Features - Interrupt Vector Configuration |
| Phase Tag | CQ Entry 的 Phase Tag 翻转表示新的 Completion |

#### 12.2.7 与 NAND Flash Controller 接口

| 信号/接口 | 说明 |
|-----------|------|
| 命令接口 | LBA / 长度 / 操作类型 (R/W/Erase) |
| 数据接口 | 宽度：512-bit 或 1024-bit（取决于 Flash 通道数） |
| 状态反馈 | 完成信号 + 状态码 (成功/ECC 纠错/不可纠正) |
| FTL 交互 | 逻辑地址到物理地址映射（通常由固件维护） |
| 磨损均衡 | 写入次数统计，GC 管理 |

#### 12.2.8 与 PCIe 接口

| 信号/接口 | 说明 |
|-----------|------|
| AXI-Stream (Slave) | 接收 PCIe TLP (Memory Read/Write Request) |
| AXI-Stream (Master) | 发送 PCIe TLP (Completion、DMA Read Request) |
| 地址译码 | BAR hit 检测，提取寄存器偏移 |
| 完成处理 | 对 Memory Read Request 发送 Completion with Data |
| 错误处理 | 不支持的请求类型返回 Unsupported Request (UR) |
| 带宽 | 至少 PCIe Gen3 x4 (32 Gbps)，推荐 Gen4 x4 |

### 12.3 模块划分建议

```
nvme_controller/
├── nvme_controller_top.v          # 顶层模块
├── nvme_csr.v                     # 寄存器文件 (CSR)
├── nvme_doorbell_proc.v           # Doorbell 处理
├── nvme_queue_mgr.v               # 队列管理 (SQ/CQ)
├── nvme_sq_dma.v                  # SQ Fetch DMA
├── nvme_cq_dma.v                  # CQ Write DMA
├── nvme_admin_engine.v            # Admin 命令处理引擎
├── nvme_io_engine.v               # I/O 命令处理引擎
├── nvme_prp_sgl_parser.v          # PRP/SGL 解析器
├── nvme_cmd_scheduler.v           # 命令调度器
├── nvme_irq_gen.v                 # 中断生成器 (MSI-X)
├── nvme_pcie_bridge.v             # PCIe 接口桥接
├── nvme_flash_if.v                # NAND Flash 接口
├── nvme_csr_intf.sv               # CSR Interface
├── nvme_queue_intf.sv             # Queue Interface
└── nvme_sva.sv                    # SVA 断言
```

### 12.4 关键时序约束

| 约束项 | 典型值 | 说明 |
|--------|--------|------|
| 主时钟频率 | 250 MHz (PCIe Gen3 x4) | 对应 PCIe 用户时钟 |
| Doorbell 响应 | ≤ 10 cycles | Doorbell 写入到命令开始 DMA |
| SQ Entry DMA | 取决于 PCIe 带宽 | 64B/256B burst |
| CQ Completion 延迟 | 取决于 NAND | Flash 访问延迟 + 处理开销 |
| 中断生成 | ≤ 5 cycles | CQ 写入完成到中断发出 |

### 12.5 常见设计挑战

| 挑战 | 说明 | 应对方案 |
|------|------|----------|
| Doorbell 频繁写入 | 每条命令一次 Doorbell MMIO 写 | 批量处理、硬件定时合并 |
| 大量 SQ 并行 | 65535 SQ 需要管理 | 硬件表项 + 分页管理 |
| PRP/SGL 复杂性 | 多级链、跨页 | 流水线化解析 |
| 中断开销 | 高 IOPS 时中断风暴 | 硬件中断合并 + 轮询模式 |
| PCIe 带宽竞争 | SQ DMA / CQ DMA / Data DMA 竞争 | 优先级仲裁、round-robin |
| NAND 写延迟 | 写入需等待 Flash 编译完成 | 异步执行、命令队列深度管理 |

---

## 参考资料

| 编号 | 文档 |
|------|------|
| 1 | NVM Express Base Specification, Revision 2.0 (2021) |
| 2 | NVM Express NVM Command Set Specification, Revision 1.0b (2024) |
| 3 | NVM Express over Fabrics Specification, Revision 1.1 (2023) |
| 4 | PCI Express Base Specification, Revision 5.0 |
