# PCIe 接口协议

> **用途**：高速串行点对点互联总线
> **规范版本**：PCI Express Base Specification r6.3 (PCIe 6.0/6.1/6.2/6.3)
> **典型应用**：NVMe SSD、GPU 互联、网卡、FPGA 加速卡、SoC 互联

---

## 1. 协议概述

PCIe（PCI Express）是一种高速串行点对点互联协议，取代传统并行 PCI/PCI-X 总线。

**核心特征**：

| 特征 | 说明 |
|------|------|
| 拓扑结构 | 点对点（Point-to-Point），非共享总线 |
| 信号方式 | 串行差分对（LVDS），每通道 1 对 TX + 1 对 RX |
| 协议分层 | 三层架构：事务层 / 数据链路层 / 物理层 |
| 数据模型 | 基于包（Packet-based），非共享总线仲裁 |
| 寻址方式 | Memory Mapped I/O（MMIO），48-bit 地址空间 |
| 流控机制 | Credit-based Flow Control（基于信用的流控） |
| 可靠性 | 链路级 CRC + 重传（ACK/NAK）；Gen6 新增 FLIT 级 FEC |
| 拓扑 | Root Complex → Switch → Endpoint 的层级树状结构 |
| 新特性 (Gen6) | PAM4 信令、1b/1b FLIT 模式、IDE 加密、Lane Margining |

---

## 2. 分层架构

```
┌─────────────────────────────────────────────────┐
│                  Transaction Layer               │
│  ┌───────────────────────────────────────────┐   │
│  │  TLP 生成/解析    地址路由    ID 路由      │   │
│  │  流控 Credit 检查  排序规则   电源管理请求  │   │
│  └───────────────────────────────────────────┘   │
├─────────────────────────────────────────────────┤
│                  Data Link Layer                 │
│  ┌───────────────────────────────────────────┐   │
│  │  DLLP 生成/解析   LCRC 生成/校验          │   │
│  │  ACK/NAK 重传机制  流控更新   链路状态维护 │   │
│  └───────────────────────────────────────────┘   │
├─────────────────────────────────────────────────┤
│                   Physical Layer                 │
│  ┌───────────────────────────────────────────┐   │
│  │  8b/10b / 128b/130b / 1b/1b FLIT 编码      │   │
│  │  SerDes TX/RX     LTSSM 链路训练           │   │
│  │  时钟恢复         均衡(EQ)  弹性缓冲       │   │
│  └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
        ║ TX±/RX± 差分对 ║
        ╚═══════════════╝
```

**数据流方向**：

| 层 | 发送方向 | 接收方向 |
|----|----------|----------|
| 事务层 | 产生 TLP（请求/完成包） | 解析 TLP，提取路由信息 |
| 数据链路层 | 添加 LCRC，管理重传缓冲 | 校验 LCRC，发送 ACK/NAK DLLP |
| 物理层 | 并串转换、编码、差分驱动 | 接收均衡、时钟恢复、串并转换、解码 |

---

## 3. 各层功能详解

### 3.1 事务层（Transaction Layer）

事务层是 PCIe 的最上层，负责 TLP（Transaction Layer Packet）的生成、解析和路由。

**核心功能**：

| 功能 | 说明 |
|------|------|
| TLP 生成/解析 | 构建 TLP Header + Payload，解析接收的 TLP；Gen6 FLIT 模式下 TLP 封装在 FLIT 内 |
| 路由 | Memory/IO：基于地址路由；Config/Completion：基于 ID（BDF）路由 |
| 流控检查 | 发送前检查 Credit 余额，Credit 不足则阻塞；Gen6 FLIT 模式使用基于 FLIT 的 Credit |
| 排序规则 | ID-based ordering，支持 Relaxed Ordering（RO） |
| 电源管理 | PM_PME、PME_Turn_Off 等电源管理 TLP |
| 中断 | MSI/MSI-X 消息型中断 |
| IDE (Gen6) | Integrity & Data Encryption，可选的 TLP 加密与完整性保护（AES-GCM） |

**TLP 类型分类**：

| TLP 类型 | 缩写 | 路由方式 | 说明 |
|----------|------|----------|------|
| Memory Read Request | MRd | 地址路由 | 读请求，触发 Completion 返回 |
| Memory Write Request | MWr | 地址路由 | 写请求，Posted，无需完成包 |
| IO Read Request | IORd | 地址路由 | IO 读（Legacy，Gen3+ 已弃用） |
| IO Write Request | IOWr | 地址路由 | IO 写（Legacy，Gen3+ 已弃用） |
| Config Read Type 0/1 | CfgRd0/1 | ID 路由 | 配置空间读，枚举设备用 |
| Config Write Type 0/1 | CfgWr0/1 | ID 路由 | 配置空间写 |
| Completion | Cpl | ID 路由 | 完成包（无数据） |
| Completion with Data | CplD | ID 路由 | 完成包（带数据，MRd 的响应） |
| Message | Msg | 地址/ID/隐式 | 电源管理、中断、错误报告等 |
| IDE TLP (Gen6) | IDE | 地址路由 | 加密 TLP，经 IDE 加密引擎处理后传输 |

**Posted vs Non-Posted**：

| 类型 | 特征 | 典型 TLP |
|------|------|----------|
| Posted | 发出后无需 Completion 响应，吞吐高 | MWr, Msg |
| Non-Posted | 必须等待 Completion 返回，延迟敏感 | MRd, CfgRd/Wr, IORd/Wr |

### 3.2 数据链路层（Data Link Layer）

数据链路层提供可靠的包传输，介于事务层与物理层之间。

**核心功能**：

| 功能 | 说明 |
|------|------|
| LCRC | 对 TLP 添加 32-bit Link CRC，接收端校验 |
| Sequence Number | 每个 TLP 附加 12-bit 序列号，用于排序和重传 |
| ACK/NAK | 接收端通过 DLLP 反馈 ACK（成功）或 NAK（校验失败） |
| 重传机制 | NAK 触发发送端从重传缓冲区重发 TLP |
| 流控更新 | 通过 InitFC/UpdateFC DLLP 传递 Credit 信息 |
| 链路状态 | 监控链路存活，超时触发重训练 |

**DLLP 类型**：

| DLLP 类型 | 说明 |
|-----------|------|
| Ack | 确认 TLP 正确接收，释放重传缓冲 |
| Nak | TLP 校验失败或序列号错误，触发重传 |
| InitFC1 / InitFC2 | 流控初始化阶段 1/2 的 Credit 广播 |
| UpdateFC | 流控 Credit 更新（释放已消费的 Credit） |
| PM_Enter_L1/L2/L3 | 电源管理状态切换请求 |
| PM_Active_State_Request | 请求进入低功耗状态 |
| Vendor Specific | 厂商自定义 DLLP |

**DLLP 格式（8 字节）**：

```
┌──────────┬──────────┬──────────┬──────────┐
│  Type    │  Data    │ Reserved │  CRC-16  │
│ [15:8]   │ [7:2]    │ [1:0]    │ [15:0]   │
└──────────┴──────────┴──────────┴──────────┘
  1 byte      1 byte     1 byte    2 bytes
```

**重传机制流程**：

```
发送端                          接收端
  │                               │
  ├── TLP(seq=N) ──────────────→ │
  │                               ├── 检查 LCRC → OK
  │  ←───────────────────── Ack(N)│
  ├── 释放重传缓冲 seq=N         │
  │                               │
  ├── TLP(seq=N+1) ────────────→ │
  │                               ├── 检查 LCRC → FAIL
  │  ←─────────────────── Nak(N+1)│
  ├── 重传缓冲区 seq=N+1 重发    │
  ├── TLP(seq=N+1) ────────────→ │
  │                               ├── 检查 LCRC → OK
  │  ←───────────────────── Ack(N+1)
```

### 3.3 物理层（Physical Layer）

物理层处理电气信号的发送、接收和链路初始化。

**核心功能**：

| 功能 | 说明 |
|------|------|
| 编码/解码 | Gen1/2：8b/10b（20% 开销）；Gen3/4/5：128b/130b（1.56%）；Gen6：1b/1b FLIT（极低开销）+ 可选 128b/130b |
| SerDes | 串行器/解串器，每通道独立 TX/RX；Gen6 使用 PAM4（4 电平脉冲幅度调制）信令 |
| LTSSM | Link Training and Status State Machine，链路初始化状态机 |
| 时钟恢复 | CDR（Clock Data Recovery），从数据流中提取时钟 |
| 均衡 | TX/RX 均衡（Equalization），补偿通道损耗 |
| 弹性缓冲 | 弹性缓冲器（Elastic Buffer）吸收 ppm 级时钟偏差 |
| Ordered Sets | TS1/TS2、SKIP、FTS、EIOS 等特殊有序集 |
| FEC (Gen6) | FLIT 模式下前向纠错（Forward Error Correction），纠正物理层错误 |
| Lane Margining (Gen6) | 接收端测试能力，评估链路质量裕量 |

**编码方式对比**：

| Gen | 编码 | 信令 | 数据速率 | 有效带宽效率 | 说明 |
|-----|------|------|----------|-------------|------|
| Gen1 | 8b/10b | NRZ | 2.5 GT/s | 80% | 每 8 bit 数据编码为 10 bit |
| Gen2 | 8b/10b | NRZ | 5.0 GT/s | 80% | 同 Gen1，速率翻倍 |
| Gen3 | 128b/130b | NRZ | 8.0 GT/s | 98.46% | 128 bit 数据 + 2 bit header |
| Gen4 | 128b/130b | NRZ | 16.0 GT/s | 98.46% | 同 Gen3，速率翻倍 |
| Gen5 | 128b/130b | NRZ | 32.0 GT/s | 98.46% | 同 Gen3，速率再翻倍 |
| Gen6 | 1b/1b FLIT | PAM4 | 64.0 GT/s | ~95%+ (FLIT 模式) | PAM4 信令，固定 256B FLIT，含 FEC；也可选 128b/130b |

> **Gen6 PAM4 信令**：PAM4（4-Level Pulse Amplitude Modulation）在每个符号周期传输 2 bit（4 个电压电平），相比 NRZ（2 电平）在相同符号速率下带宽翻倍。64 GT/s PAM4 的符号速率为 32 GBaud（与 Gen5 NRZ 32 GT/s 的符号速率相同），但每符号传输 2 bit。

> **Gen6 1b/1b FLIT 模式**：FLIT（Flow Control Unit）是固定 256 字节的传输单元，包含数据和 FEC 校验位。FLIT 模式取消了传统 TLP 的 Start/End 帧标记，改为 FLIT 内直接封装 TLP，显著降低协议开销并提升错误纠正能力。FLIT 模式是 Gen6 的默认和推荐编码模式。

**物理层有序集**：

| 有序集 | 说明 |
|--------|------|
| TS1/TS2 | Training Sequence，链路训练协商速率/宽度/Lane 反转等 |
| SKIP | 周期性插入，弹性缓冲器对齐用（Gen1/2 每 1180 symbol 一次） |
| FTS | Fast Training Sequence，L0s 退出时快速恢复链路 |
| EIOS | Electrical Idle Ordered Set，进入 Electrical Idle 状态 |
| SDP | Start of Data Packet，数据包起始标记 |

---

## 4. TLP 包格式

### 4.1 通用 TLP 结构

**Gen1~5（非 FLIT 模式）**：
```
┌──────────┬──────────┬──────────┬──────────────────┐
│  Header  │   Data   │   ECRC   │                  │
│ 12/16 B  │  0-N B   │  0/4 B   │                  │
└──────────┴──────────┴──────────┴──────────────────┘
```

**Gen6 FLIT 模式**：
```
┌───────────────────────────────────────────────────┐
│                  FLIT (256 Bytes)                  │
│  ┌──────────┬──────────┬──────────┬─────────────┐ │
│  │  Header  │   Data   │   ECRC   │    FEC      │ │
│  │ 12/16 B  │  0-N B   │  0/4 B   │  (纠错码)   │ │
│  └──────────┴──────────┴──────────┴─────────────┘ │
└───────────────────────────────────────────────────┘
```

| 字段 | 大小 | 说明 |
|------|------|------|
| Header | 3 或 4 DW（12 或 16 字节） | 路由信息、TLP 类型、长度等 |
| Data Payload | 0 ~ 4096 字节（Max Payload Size） | 写数据或完成包返回的读数据 |
| ECRC | 0 或 4 字节 | End-to-End CRC，可选 |
| FEC (Gen6 FLIT) | 可变 | 前向纠错码，纠正物理层 bit 错误 |

> **FLIT 模式关键变化**：TLP 不再有独立的 LCRC 和 Sequence Number（这些由 FLIT 层处理），TLP 之间不再有 STP/SDP 帧标记，多个 TLP 可以紧密排列在同一 FLIT 内，极大提高带宽利用率。

### 4.2 TLP Header 格式（3DW / 4DW）

#### 4DW Header（64-bit 地址）

```
DW0:
┌──────┬──────┬──────┬───────────┬──────┬──────┬──────────┐
│ Fmt  │ Type │  TC  │   Attr    │  TH  │  TD  │  EP  AT  │
│[31:29│[28:24│[23:21│  [20:18]  │[17]  │[16]  │[15][14:12│
├──────┴──────┴──────┴───────────┴──────┴──────┼──┬───────┤
│              Length [9:0]                     │R │Length │
│              [9:0]                           │  │[11:10]│
└──────────────────────────────────────────────┴──┴───────┘

DW1:
┌──────────────────────────────────────────────────────┐
│              Requester ID  [31:16]                    │
│         Bus [15:8]  Device [15:11]  Function [10:8]   │
├──────────────────────┬───────────────────────────────┤
│     Tag [9:0]        │    Last DW BE / First DW BE   │
│  (Gen6: 10-bit Tag)  │         [7:4]  /  [3:0]       │
└──────────────────────┴───────────────────────────────┘

DW2:
┌──────────────────────────────────────────────────────┐
│              Address [63:32]                          │
└──────────────────────────────────────────────────────┘

DW3:
┌──────────────────────────────────────────────────────┐
│              Address [31:2]  │ Rsvd │                 │
└──────────────────────────────────────────────────────┘
```

#### 3DW Header（32-bit 地址）

```
DW0:  同 4DW 格式
DW1:  同 4DW 格式（Requester ID + Tag + BE）
DW2:  Address [31:2] + Rsvd
```

> **Gen6 Tag 扩展**：Gen6 将 Tag 从 8-bit 扩展到 10-bit，最大 Outstanding 请求从 256 增加到 1024。DW1 中 Tag[9:8] 占用原保留位。对于 Gen1~5 兼容模式，Tag[9:8] 为 0。

### 4.3 Header 关键字段说明

| 字段 | 位宽 | 说明 |
|------|------|------|
| Fmt[2:0] | 3 bit | TLP 格式：000=3DW no data, 001=4DW no data, 010=3DW w/ data, 011=4DW w/ data, 100=TLP Prefix |
| Type[4:0] | 5 bit | TLP 类型（与 Fmt 配合决定具体事务） |
| TC[2:0] | 3 bit | Traffic Class（0~7），决定 VC 映射和优先级 |
| Attr[2:0] | 3 bit | Attr[2]=ID-Based Ordering, Attr[1]=Relaxed Ordering, Attr[0]=No Snoop |
| TH | 1 bit | TLP Processing Hints（Gen3+） |
| TD | 1 bit | TLP Digest（ECRC 存在标记） |
| EP | 1 bit | Poisoned（数据已损坏标记） |
| AT[1:0] | 2 bit | Address Translation（PASID 相关） |
| Length[9:0] | 10 bit | 数据长度，单位 DW（0 = 1024 DW） |
| Requester ID | 16 bit | BDF：Bus[7:0] + Device[4:0] + Function[2:0] |
| Tag[7:0] | 8 bit (Gen2~5) / 10 bit (Gen6) | 请求标签，用于匹配 Completion（Gen2: 8 bit, Gen6: 10 bit, 最大 1024 outstanding） |
| First DW BE[3:0] | 4 bit | 第一个 DW 的字节使能（支持不对齐访问） |
| Last DW BE[3:0] | 4 bit | 最后一个 DW 的字节使能 |
| Address | 32/64 bit | 目标地址（DW aligned，低 2 bit 固定为 0） |

**Fmt + Type 编码表**：

| Fmt | Type | TLP 类型 | 说明 |
|-----|------|----------|------|
| 000 | 00000 | MRd (3DW) | 32-bit 地址 Memory Read |
| 001 | 00000 | MRd (4DW) | 64-bit 地址 Memory Read |
| 010 | 00000 | MWr (3DW) | 32-bit 地址 Memory Write |
| 011 | 00000 | MWr (4DW) | 64-bit 地址 Memory Write |
| 000 | 00010 | IORd | IO Read |
| 010 | 00010 | IOWr | IO Write |
| 000 | 00100 | CfgRd0 | Config Read Type 0 |
| 010 | 00100 | CfgWr0 | Config Write Type 0 |
| 000 | 00101 | CfgRd1 | Config Read Type 1 |
| 010 | 00101 | CfgWr1 | Config Write Type 1 |
| 000 | 01010 | Cpl | Completion（无数据） |
| 010 | 01010 | CplD | Completion（带数据） |
| 001 | 10rrr | Msg | Message（无数据，路由见 rrr） |
| 011 | 10rrr | MsgD | Message（带数据） |

---

## 5. 完成包（Completion）

完成包是 Non-Posted 事务的响应。

### 5.1 Completion Header 格式（3DW）

```
DW0:
┌──────┬──────┬──────┬───────────┬──┬──┬──┬──┬─────────┐
│ Fmt  │ Type │  TC  │   Attr    │TH│TD│EP│AT│ Length  │
│[31:29│[28:24│[23:21│  [20:18]  │  │  │  │  │ [9:0]   │
└──────┴──────┴──────┴───────────┴──┴──┴──┴──┴─────────┘

DW1:
┌──────────────────────────────────────────────────────┐
│              Completer ID  [31:16]                    │
│         Bus [15:8]  Device [15:11]  Function [10:8]   │
├──────┬───────────────────────────────────────────────┤
│ BCM  │              Byte Count [11:0]                 │
│ [12] │                                               │
├──────┴───────────────────────────────────────────────┤
│       Requester ID [31:16]  │    Tag [7:0]           │
└─────────────────────────────┴───────────────────────┘

DW2:
┌──────┬──────────────┬────────────────────────────────┐
│ Rsvd │ Lower Addr   │      Status [15:13]            │
│[31:16│   [6:0]      │     Byte Count MSB [12]       │
└──────┴──────────────┴────────────────────────────────┘
```

### 5.2 Completion 关键字段

| 字段 | 说明 |
|------|------|
| Completer ID | 响应者的 BDF |
| Requester ID | 原始请求者的 BDF |
| Tag | 匹配原始请求的 Tag |
| Status[2:0] | 完成状态：SC=成功, UR=不支持请求, CRS=配置重试, CA=不支持完成 |
| BCM (Byte Count Modified) | Byte Count 是否被修改（Stale Read 相关） |
| Byte Count[11:0] | 剩余待传输字节数（用于多 Completion 场景） |
| Lower Address[6:0] | 第一个有效数据字节的地址偏移 |

### 5.3 多 Completion 场景

一个 MRd 请求可能被拆分为多个 CplD 返回：

```
MRd(4KB) → CplD#1(1KB) → CplD#1KB → CplD#1KB → CplD#1KB

每包 Byte Count 递减：
  CplD#1: Byte Count = 4096 - 0    = 4096 (首包)
  CplD#2: Byte Count = 4096 - 1024 = 3072
  CplD#3: Byte Count = 4096 - 2048 = 2048
  CplD#4: Byte Count = 4096 - 3072 = 1024 (末包)
```

---

## 6. 流控机制（Credit-based Flow Control）

PCIe 使用基于信用的流控，发送端在发送 TLP 前必须确认接收端有足够 Buffer 空间。

### 6.1 六种 Credit 类型

每个 VC（Virtual Channel）有 6 种独立的 Credit：

| Credit 类型 | 缩写 | 管理对象 | 单位 | 说明 |
|-------------|------|----------|------|------|
| Posted Header | PH | Posted TLP 的 Header | 1 Credit/1 Header | MWr、Msg 等的 Header 空间 |
| Posted Data | PD | Posted TLP 的 Data | 1 Credit/16 Bytes | MWr、MsgD 等的 Payload 空间 |
| Non-Posted Header | NPH | Non-Posted TLP 的 Header | 1 Credit/1 Header | MRd、CfgRd/Wr 等的 Header 空间 |
| Non-Posted Data | NPD | Non-Posted TLP 的 Data | 1 Credit/16 Bytes | IOWr 等的 Payload 空间 |
| Completion Header | CPLH | Completion 的 Header | 1 Credit/1 Header | Cpl、CplD 的 Header 空间 |
| Completion Data | CPLD | Completion 的 Data | 1 Credit/16 Bytes | CplD 的 Payload 空间 |

### 6.2 流控协议流程

```
初始化阶段：
  1. 复位后双方进入 FC_INIT1 状态
  2. 交换 InitFC1 DLLP（广播初始 Credit 值）
  3. 双方收到 InitFC1 后进入 FC_INIT2
  4. 交换 InitFC2 DLLP（确认 Credit 值）
  5. 双方收到 InitFC2 后流控初始化完成，进入正常运行

正常运行阶段：
  1. 发送端每发一个 TLP，扣除对应 Credit
  2. 接收端消费 TLP 后，通过 UpdateFC DLLP 回补 Credit
  3. Credit 归零 → 发送端阻塞该类 TLP
```

### 6.3 Credit 计算示例

```
假设接收端 Buffer 配置：
  PH Buffer = 32 Headers   → 32 Credits
  PD Buffer = 2048 Bytes   → 128 Credits (2048/16)

发送端发送 MWr(Header=12B, Data=64B)：
  PH Credit -= 1   (32 → 31)
  PD Credit -= 4   (128 → 124,  64B/16 = 4)

接收端处理完毕后发送 UpdateFC：
  PH Credit += 1   (31 → 32)
  PD Credit += 4   (124 → 128)
```

**Credit 饱和处理**：

| 场景 | 处理方式 |
|------|----------|
| Credit 为 0 | 阻塞对应类型 TLP，其他类型可继续发送 |
| Credit Update DLLP 丢失 | 由 DLLP 的 LCRC 保护，错误则重传 |
| 初始化 Credit = Infinite | 允许，表示接收端 Buffer 不会满（如 Completion Buffer） |

---

## 7. 虚拟通道（Virtual Channel）

虚拟通道提供多优先级服务质量（QoS），允许不同流量类别独立排队和调度。

### 7.1 VC 架构

| 项目 | 说明 |
|------|------|
| VC 数量 | VC0 ~ VC7（8 个），VC0 必须支持 |
| TC 到 VC 映射 | TC0~TC7 映射到 VC0~VC7，1:1 或多对一 |
| 默认 | TC0 → VC0（所有设备必须支持） |
| 独立 Buffer | 每个 VC 有独立的发送/接收 Buffer 和 Credit |
| 仲裁 | VC 间有严格的仲裁优先级 |

### 7.2 TC-VC 映射

```
TC0 ──→ VC0  (Best Effort，默认)
TC1 ──→ VC1  (如果使能)
TC2 ──→ VC1  (可配置映射到不同 VC)
TC3 ──→ VC2
 ...
TC7 ──→ VC7  (最高优先级)
```

### 7.3 VC 仲裁

| 仲裁层级 | 方式 | 说明 |
|----------|------|------|
| VC 间仲裁 | 严格优先级 / WRR（加权轮询） | 路由层决定哪个 VC 先发 |
| VC 内仲裁 | 基于 TC 优先级 | 同一 VC 内多个 TC 的调度 |
| 端口仲裁（Switch） | 固定 / WRR / RR | Switch 上游端口的多个输入端口仲裁 |

---

## 8. 链路宽度与速率

### 8.1 链路宽度

| 链路宽度 | Lane 数 | 说明 |
|----------|---------|------|
| x1 | 1 | 最基本配置 |
| x2 | 2 | 少见 |
| x4 | 4 | 常见于 SSD |
| x8 | 8 | 常见于网卡、加速卡 |
| x16 | 16 | 常见于 GPU |

### 8.2 各代速率与带宽

| 代次 | 编码 | 信令 | 速率 (GT/s) | 单 Lane 带宽 | x1 有效带宽 | x4 有效带宽 | x8 有效带宽 | x16 有效带宽 |
|------|------|------|------------|-------------|-----------|-----------|-----------|------------|
| Gen1 | 8b/10b | NRZ | 2.5 | 250 MB/s | 250 MB/s | 1 GB/s | 2 GB/s | 4 GB/s |
| Gen2 | 8b/10b | NRZ | 5.0 | 500 MB/s | 500 MB/s | 2 GB/s | 4 GB/s | 8 GB/s |
| Gen3 | 128b/130b | NRZ | 8.0 | 985 MB/s | 985 MB/s | 3.94 GB/s | 7.88 GB/s | 15.75 GB/s |
| Gen4 | 128b/130b | NRZ | 16.0 | 1969 MB/s | 1969 MB/s | 7.88 GB/s | 15.75 GB/s | 31.51 GB/s |
| Gen5 | 128b/130b | NRZ | 32.0 | 3938 MB/s | 3938 MB/s | 15.75 GB/s | 31.51 GB/s | 63.02 GB/s |
| Gen6 | 1b/1b FLIT | PAM4 | 64.0 | ~7500 MB/s | ~7.5 GB/s | ~30 GB/s | ~60 GB/s | ~120 GB/s |

> **注意**：以上为单向带宽，PCIe 全双工，理论双向带宽翻倍。
> **Gen6 带宽说明**：Gen6 1b/1b FLIT 模式下，64 GT/s × 1 bit/symbol ÷ 8 = 8 GB/s 理论单 Lane 带宽，扣除 FLIT 内 FEC 开销后有效带宽约 7.5 GB/s。实际可用带宽取决于 TLP 负载效率和协议开销。

### 8.3 带宽计算

```
Gen3 x4 有效带宽计算：
  速率 = 8.0 GT/s
  编码效率 = 128/130 = 98.46%
  单 Lane = 8.0 × 10^9 × (128/130) / 8 = 984.6 MB/s
  x4 总带宽 = 984.6 × 4 = 3,938 MB/s ≈ 3.94 GB/s

Gen6 x16 有效带宽计算：
  速率 = 64.0 GT/s (PAM4, 每符号 2 bit)
  符号速率 = 32 GBaud
  编码 = 1b/1b FLIT（几乎无编码开销）
  FLIT 大小 = 256 Bytes（含 FEC）
  单 Lane 理论 = 64 × 10^9 / 8 = 8,000 MB/s
  FEC 开销 ≈ 5~7% → 有效 ≈ 7,500 MB/s
  x16 总带宽 = 7,500 × 16 = 120,000 MB/s ≈ 120 GB/s
  双向带宽 = ~240 GB/s
```

---

## 9. LTSSM 状态机

LTSSM（Link Training and Status State Machine）管理 PCIe 链路的初始化、训练、功耗和错误恢复。

### 9.1 状态总览

```
                    ┌──────────┐
          ┌────────→│  Detect  │←────────────────┐
          │         └────┬─────┘                  │
          │              │ 检测到对端             │
          │              ▼                        │
          │         ┌──────────┐                  │
          │         │   Poll   │ 发送 TS1/TS2    │
          │         └────┬─────┘                  │
          │              │                        │
          │              ▼                        │
          │    ┌──────────────────┐               │
          │    │  Configuration   │ 协商速率/宽度  │
          │    └────────┬─────────┘               │
          │             │                         │
          │             ▼                         │
     ┌────┴────────────────────────────┐          │
     │              L0                  │←───┐    │
     │         (Active State)          │    │    │
     └──┬────┬────┬────┬────┬────┬─────┘    │    │
        │    │    │    │    │    │           │    │
        ▼    ▼    ▼    ▼    ▼    ▼           │    │
      L0s  L1   L2   L3  Recovery  Disable   │    │
        │    │    │    │    │       │         │    │
        │    │    │    │    │       │         │    │
        └────┴────┴────┴────┼───────┘         │    │
                            │                  │    │
                            └──────────────────┘    │
                                                     │
                              Hot Reset / Link Down ─┘
```

### 9.2 各状态说明

| 状态 | 进入条件 | 行为 | 退出条件 |
|------|----------|------|----------|
| **Detect** | 上电复位 / 链路断开 | 检测对端阻抗（检测是否连接） | 检测到对端 → Poll |
| **Poll** | Detect 完成 | 发送 TS1 Ordered Set，速率协商 | 收到 TS1 → Configuration |
| **Configuration** | Poll 完成 | Lane 编号分配、宽度协商、极性反转 | 协商成功 → L0；失败 → Detect |
| **L0** | Configuration 成功 | 正常数据传输状态 | 见下方转换 |
| **L0s** | Idle 时间过长 | ASPM 低功耗，单向进入 | 有数据发送 → Recovery → L0 |
| **L1** | 软件/ASPM 请求 | 比 L0s 更深的低功耗 | 唤醒请求 → Recovery → L0 |
| **L2** | PME_Turn_Off | 深度休眠，仅保留唤醒逻辑 | PME_TO_Ack → L3 或唤醒 |
| **L3** | 主电源关闭 | 完全断电 | 上电 → Detect |
| **Recovery** | L0s/L1 退出 / 速度改变 / 重训练 | 重新训练，无需回到 Detect | 成功 → L0；失败 → Disable/Detect |
| **Disabled** | 软件禁用链路 | 链路禁用，不发送 | 软件重新使能 → Detect |
| **Loopback** | 测试模式 | 回环测试 | 测试结束 → Detect |
| **Hot Reset** | 软件触发 | 发送 Hot Reset TS1 | 对端收到 → Detect |

### 9.3 速率协商

| 协商阶段 | 行为 |
|----------|------|
| Gen1 | 8b/10b，TS1/TS2 速率标识位 = 0 |
| Gen2 | 8b/10b，TS1/TS2 中设置 5.0 GT/s 位 |
| Gen3~5 | 128b/130b，需要 EQ（均衡）协商 |
| Gen6 | 1b/1b FLIT 或 128b/130b，PAM4 信令，需 EQ + FLIT 能力协商 |

> **Gen6 LTSSM 变化**：Gen6 在 Configuration 状态中增加了 FLIT 模式能力协商。双方通过 TS1/TS2 中的 FLIT Support 位协商是否启用 1b/1b FLIT 模式。若双方均支持 FLIT，则优先使用 FLIT 模式。Recovery 状态中也支持从 128b/130b 切换到 FLIT 模式。

---

## 10. 事务排序规则

PCIe 定义了严格的事务排序规则，保证正确性的同时最大化吞吐。

### 10.1 排序原则

| 规则 | 说明 |
|------|------|
| 相同 TC | 必须保持 TLP 到达顺序 |
| 不同 TC | 无需保持顺序（不同 VC 路径不同） |
| Posted vs Non-Posted | Non-Posted 不能越过同地址的先行 Posted |
| Completion | 必须返回到原始请求者，按 Tag 匹配 |
| Relaxed Ordering (RO) | 设置 RO 位的 TLP 可越过先行 TLP（不同地址时） |

### 10.2 排序矩阵（同 TC、同地址）

| 先行事务 ↓ \ 后续事务 → | Posted | Non-Posted (Rd) | Non-Posted (Wr) | Completion |
|--------------------------|--------|-----------------|-----------------|------------|
| Posted | - | No reorder (*) | No reorder (*) | - |
| Non-Posted (Rd) | - | - | - | No reorder (*) |
| Non-Posted (Wr) | - | - | - | - |
| Completion | - | - | - | - |

> `*` 表示默认禁止重排；设置 RO 位后，不同地址可重排。

### 10.3 ID-Based Ordering (IDO)

- Gen2 引入，Attr[2] 控制
- 不同 Requester ID 的 TLP 可以重排
- 适用于多 Root Port 并发访问同一 Endpoint 场景

---

## 11. MSI / MSI-X 中断

PCIe 使用消息型中断（Message Signaled Interrupt），取代传统 INTx 边带信号。

### 11.1 MSI vs MSI-X 对比

| 特性 | MSI | MSI-X |
|------|-----|-------|
| 向量数 | 1, 2, 4, 8, 16, 32 | 最多 2048 |
| 地址/数据 | 所有向量共享同一地址和数据值 | 每个向量独立地址和数据值 |
| 配置方式 | Capability 结构内 | MSI-X Table（独立 BAR 空间） |
| 灵活性 | 低 | 高（可映射到不同 CPU 核心） |

### 11.2 MSI 中断机制

```
设备产生中断：
  1. 设备向 MSI Address 寄存器写入 MSI Data 值
  2. 该写操作作为 MWr TLP 发送到 Root Complex
  3. Root Complex 解析 MWr 目标地址为中断控制器
  4. 中断控制器将中断路由到目标 CPU 核心

MSI Address: 0xFEExxxxx（xAPIC 地址范围）
MSI Data:    中断向量号（Vector）
```

### 11.3 MSI-X Table 格式

| 偏移 | 字段 | 大小 | 说明 |
|------|------|------|------|
| 0x00 | Msg Addr | 8 字节 | 中断目标地址（64-bit） |
| 0x08 | Msg Data | 4 字节 | 中断数据值 |
| 0x0C | Vector Control | 4 字节 | Bit 0 = Mask |

---

## 12. 设计注意事项

### 12.1 SerDes 接口

| 注意事项 | 说明 |
|----------|------|
| AC 耦合 | TX/RX 之间需 100nF AC 耦合电容 |
| 阻抗匹配 | 差分阻抗 85~100 ohm（典型 100 ohm） |
| 走线长度匹配 | 同一 Link 内 Lane 间 skew ≤ 5 ns（Gen3）/ 20 ns（Gen1/2） |
| 参考时钟 | 100 MHz 参考时钟，需低抖动（< 1ps rms jitter） |
| ESD 保护 | 差分线上 ESD 保护需考虑信号完整性 |

### 12.2 PLL 与时钟方案

| 组件 | 说明 |
|------|------|
| 参考时钟 | 100 MHz，来自外部晶振或 Spread Spectrum Clock |
| SerDes PLL | 倍频到线速率（如 Gen3 = 8 GHz） |
| 弹性缓冲器 | 吸收 ±300 ppm 时钟偏差 |
| Spread Spectrum | 可选 SSC（±0.5% 展频），降低 EMI |

### 12.3 链路均衡（Equalization）

| Gen | EQ 方式 | 说明 |
|-----|---------|------|
| Gen1/2 | 无（8b/10b 自适应） | CDR 足以补偿 |
| Gen3 | 发送端预设（Preset）+ 自适应均衡 | 3 阶 FIR 预加重 |
| Gen4/5 | 增强 EQ，需要更复杂的训练 | 多阶 FIR + CTLE + DFE |
| Gen6 | PAM4 增强 EQ + Lane Margining | 更高复杂度的 EQ，需支持 PAM4 的 CTLE/DFE/FFE；Lane Margining 评估接收端裕量 |

> **Gen6 Lane Margining**：接收端测试功能，通过读取 Lane Margining Status 寄存器评估每条 Lane 的电压裕量和时序裕量。用于链路质量诊断和故障排查，不影响正常数据传输。

### 12.4 BDF 路由

```
Bus Number  [7:0]  : 由 BIOS/OS 枚举时分配（256 条 Bus）
Device Num  [4:0]  : 32 个 Device / Bus
Function    [2:0]  : 8 个 Function / Device

配置路由：
  Type 0：同一 Bus 内的设备（Bus Number 匹配）
  Type 1：跨 Bus 的 Switch/桥接（Bus Number 不匹配 → 转发）

EP 中实现配置空间的注意事项：
  - 需要解析 Config TLP 的 Bus/Dev/Func
  - 需要响应 Type 0 CfgRd/CfgWr
  - BAR 寄存器配置决定 MMIO 地址映射
```

### 12.5 Endpoint 实现要点

| 设计要点 | 说明 |
|----------|------|
| 配置空间 | 256 字节（Type 0）或 4KB（Type 1），含 Vendor ID/Device ID/BAR 等 |
| BAR 配置 | 6 个 BAR（32/64-bit），软件写全 1 测试大小 |
| Tag 管理 | 最多 256 个 Outstanding 请求（Gen2~5 8-bit Tag）；Gen6 扩展到 1024（10-bit Tag） |
| Max Payload Size | 128B~4096B，通过 Device Control 寄存器协商 |
| Max Read Request Size | 128B~4096B，决定单次 MRd 最大量 |
| Completion Timeout | 默认 50us~50ms，超时触发错误报告 |

---

## 13. 与 AXI 互联的对比

| 对比维度 | PCIe | AXI4 |
|----------|------|------|
| **拓扑** | 点对点串行链路，层级树状（RC→Switch→EP） | 片上共享总线/交叉开关，Master-Slave |
| **信号方式** | 串行差分（SerDes），复用到物理链路 | 并行信号，每个通道独立信号组 |
| **协议单位** | 包（TLP），带 Header + Payload + CRC | 事务，基于通道握手（AW/W/B/AR/R） |
| **事务类型** | Posted (MWr) / Non-Posted (MRd/Cfg) | Read / Write，均需响应（B/R 通道） |
| **流控机制** | Credit-based（6 种 Credit，精细控制 Buffer） | Valid/Ready 握手（简单，但需 FIFO 缓冲） |
| **路由方式** | 地址路由 / ID 路由（BDF） | 地址解码（固定连线或地址映射表） |
| **可靠性** | 链路级 CRC + ACK/NAK 重传（硬件可靠） | 无链路级校验（依赖上层协议） |
| **乱序支持** | ID-Based Ordering + Relaxed Ordering | 支持 Out-of-Order（通过 ID），但实现依赖 IP |
| **中断** | MSI/MSI-X（消息型，走数据通路） | 边带中断信号（IRQ） |
| **配置空间** | 标准 PCIe 配置空间（256B~4KB） | 无标准配置空间，由设计者定义 |
| **数据宽度** | 串行复用（物理宽度随 Lane 数变化） | 32/64/128/256/512/1024 bit 可配 |
| **延迟** | 较高（~100ns 级，含 SerDes + 协议栈） | 较低（~1-10ns 级，片内直连） |
| **功耗模型** | ASPM (L0s/L1/L2/L3)，深度休眠 | 门控时钟，无深度休眠标准 |
| **典型用途** | 芯片间 / 板间互联（距离 ~m 级） | 芯片内部互联（距离 ~mm 级） |
| **带宽效率** | 有协议开销（Header ~12-16B + DLLP + 编码） | 协议开销小（握手本身无数据开销） |

**关键差异总结**：

| 维度 | PCIe 核心理念 | AXI4 核心理念 |
|------|-------------|-------------|
| 设计目标 | 跨芯片可靠高速串行互联 | 片内低延迟高带宽并行互联 |
| 复杂度 | 高（3 层协议栈 + SerDes + LTSSM） | 中（通道握手 + 地址解码） |
| 可靠性保障 | 硬件级（LCRC + 重传 + Credit） | 依赖设计者（需自己加 FIFO/ECC） |
| 灵活性 | 标准化强（BDF 枚举、配置空间） | 灵活（自定义信号、互联拓扑） |

**PCIe-AXI 桥接设计要点**：

```
PCIe Endpoint IP                    AXI Interconnect
┌──────────────┐                   ┌──────────────┐
│ PCIe TLP     │                   │ AXI Master   │
│ 收发引擎     │ ←── 协议转换 ──→  │ 接口         │
│              │                   │              │
│ TLP→AXI AW/W │   地址映射        │ AW/W/B/AR/R  │
│ AXI R→CplD   │   Tag→ID 映射     │ 通道         │
│ Credit 管理  │   大小端转换      │              │
└──────────────┘                   └──────────────┘
```

| 桥接难点 | 说明 |
|----------|------|
| 地址映射 | PCIe BAR 空间到 AXI 地址空间的映射 |
| Tag 管理 | PCIe 256 Tag vs AXI Transaction ID 的对应 |
| 大小端 | PCIe Little-Endian vs AXI 可能的字节序差异 |
| Payload 拆分 | PCIe Max Payload Size vs AXI 突发长度限制 |
| Completion 超时 | PCIe 有超时机制，需映射到 AXI 错误响应 |
| 流控桥接 | PCIe Credit vs AXI Valid/Ready 的速率匹配 |

---

## 13. Gen6 新增特性详解

### 13.1 PAM4 信令

| 项目 | NRZ (Gen1~5) | PAM4 (Gen6) |
|------|-------------|-------------|
| 电平数 | 2（0/1） | 4（00/01/10/11） |
| 每符号 bit 数 | 1 | 2 |
| 符号速率 | = 数据速率 | = 数据速率 / 2 |
| SNR 要求 | 低 | 高（电平间距缩小） |
| 均衡复杂度 | 中 | 高（需更强大的 CTLE/DFE/FFE） |
| 应用 | Gen1~5 | Gen6 |

> **设计影响**：PAM4 需要更精密的 SerDes 设计，对 PCB 走线质量、连接器和封装的要求更高。Gen6 的 SerDes IP 功耗和面积比 Gen5 增加约 20~30%。

### 13.2 1b/1b FLIT 模式

**FLIT 结构（256 字节）**：

```
Byte 0        Byte 1~N       Byte N+1~M      最后若干 Byte
┌──────────┬──────────────┬──────────────┬────────────────┐
│ FLIT Hdr │  TLP Payload │  Padding     │   FEC (纠错码)  │
│ (1 byte) │  (变长)      │  (对齐填充)   │   (CRC/RS)     │
└──────────┴──────────────┴──────────────┴────────────────┘
```

**FLIT 模式 vs 128b/130b 模式对比**：

| 特性 | 128b/130b (Gen3~5) | 1b/1b FLIT (Gen6) |
|------|-------------------|-------------------|
| 编码开销 | 1.56% (2/130) | ~0%（无编码开销） |
| 传输单元 | 变长 TLP | 固定 256B FLIT |
| 帧标记 | STP/SDP | FLIT Header 内指示 |
| CRC | LCRC (32-bit per TLP) | FLIT 级 FEC |
| 错误处理 | 重传（ACK/NAK） | FEC 纠错 + 选择性重传 |
| 流控粒度 | Per-TLP Credit | Per-FLIT Credit |
| 多 TLP 封装 | 不支持 | 单 FLIT 内可封装多个 TLP |
| 带宽效率 | 高 | 更高（无帧间隙开销） |

### 13.3 IDE（Integrity & Data Encryption）

| 项目 | 说明 |
|------|------|
| 加密算法 | AES-GCM-256（可选 AES-GCM-128/256） |
| 保护范围 | TLP Header + Payload |
| 密钥交换 | 通过 DOE (Data Object Exchange) Capability |
| 选择性加密 | 可按 TC/VC 或地址范围选择性加密 |
| 典型场景 | 云安全、机密计算、跨主机 PCIe 互联 |
| 性能影响 | 加密/解密增加 ~1-2 cycle 延迟 |

> **IDE 应用场景**：主要用于需要端到端数据保护的场景，如 CXL（Compute Express Link）互联、云环境中多租户隔离、芯片间安全互联等。

### 13.4 Completion Coalescing（Gen6）

- Gen6 允许将多个小 Completion 合并为一个大的 CplD
- 减少 Completion Header 开销，提高带宽效率
- 适用于大量小读请求的场景（如 NVMe 队列）

### 13.5 Gen6 向后兼容

| 模式 | 说明 |
|------|------|
| FLIT 模式 | Gen6 两端均支持时启用 |
| 128b/130b 模式 | Gen6 设备与 Gen5 设备互连时回退到 128b/130b |
| 速率降级 | Gen6 → Gen5 → Gen4 → Gen3 → Gen2 → Gen1，按需降级 |

---

## 附录

### A. 常用缩略语

| 缩写 | 全称 |
|------|------|
| TLP | Transaction Layer Packet |
| DLLP | Data Link Layer Packet |
| LCRC | Link CRC |
| ECRC | End-to-End CRC |
| LTSSM | Link Training and Status State Machine |
| ASPM | Active State Power Management |
| BDF | Bus/Device/Function |
| BAR | Base Address Register |
| TC | Traffic Class |
| VC | Virtual Channel |
| CDR | Clock Data Recovery |
| EQ | Equalization |
| SerDes | Serializer/Deserializer |
| MSS | Max Payload Size |
| MRRS | Max Read Request Size |
| PME | Power Management Event |
| MSI | Message Signaled Interrupt |
| RO | Relaxed Ordering |
| IDO | ID-Based Ordering |
| IDE | Integrity & Data Encryption |
| FLIT | Flow Control Unit |
| PAM4 | 4-Level Pulse Amplitude Modulation |
| FEC | Forward Error Correction |

### B. 参考文档

| 编号 | 文档 | 版本 |
|------|------|------|
| REF-001 | PCI Express Base Specification | r6.3 |
| REF-002 | PCI Express Card Electromechanical Specification | r5.0 |
| REF-003 | PCI Express PHY Interface (PIPE) Specification | v6.0 |
| REF-004 | AMBA AXI and ACE Protocol Specification | ARM IHI 0022 |
