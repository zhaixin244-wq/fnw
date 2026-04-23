# PCIe 事务层 (TLP) 深度协议知识

> **定位说明**：本文档聚焦 PCIe Transaction Layer (TLP) 包格式、事务规则和 IP 设计要点。与 `bus-protocol/pcie.md`（PCIe 概述、拓扑、链路训练）互为补充，后者关注链路层和物理层，本文档深入事务层细节。**已更新至 Gen6.3（含 FLIT 模式、10-bit Tag、IDE、Completion Coalescing）。**

---

## 1. TLP 包类型分类

### 1.1 总览

| 类别 | TLP 类型 | 缩写 | Posted? | 方向 | 用途 |
|------|----------|------|---------|------|------|
| Memory Read | Memory Read Request | MRd | Non-Posted | Requester → Completer | 读取内存/MMIO |
| Memory Write | Memory Write Request | MWr | Posted | Requester → Completer | 写入内存/MMIO |
| IO Read | IO Read Request | IORd | Non-Posted | Requester → Completer | IO 空间读 |
| IO Write | IO Write Request | IOWr | Non-Posted | Requester → Completer | IO 空间写 |
| Config Read (Type 0) | Configuration Read Type 0 | CfgRd0 | Non-Posted | Bus → Endpoint | 配置空间读 (直连设备) |
| Config Write (Type 0) | Configuration Write Type 0 | CfgWr0 | Non-Posted | Bus → Endpoint | 配置空间写 (直连设备) |
| Config Read (Type 1) | Configuration Read Type 1 | CfgRd1 | Non-Posted | Bus → Bridge | 配置空间读 (跨桥) |
| Config Write (Type 1) | Configuration Write Type 1 | CfgWr1 | Non-Posted | Bus → Bridge | 配置空间写 (跨桥) |
| Completion | Completion without Data | Cpl | - | Completer → Requester | 无数据完成 |
| Completion with Data | Completion with Data | CplD | - | Completer → Requester | 带数据完成 |
| Completion Locked | Completion Locked | CplLk | - | Completer → Requester | 锁定事务完成 |
| Message | Message without Data | Msg | Posted | 端到端/广播 | 中断/电源管理/错误 |
| Message with Data | Message with Data | MsgD | Posted | 端到端/广播 | 带数据的消息 |

### 1.2 Posted vs Non-Posted 概要

- **Posted**：发送方无需等待 Completion 即可继续发送下一个 TLP。MWr、Msg/MsgD 属于 Posted。
- **Non-Posted**：发送方必须等待对应的 Completion（Cpl/CplD）才能完成事务。MRd、CfgRd/Wr、IORd/IOWr 属于 Non-Posted。

---

## 2. TLP Header 完整格式

### 2.1 通用 Header 结构（DW 0）

```
DW 0 (32 bit):
+--------+--------+--------+--------+--------+--------+--------+--------+
| Fmt    | Type   | R  |TC  | Attr | TH | TD | EP | AT   | Length        |
| [31:29]|[28:24] |[23:21]|[20:18]|[17:16]|[15]|[14]|[13]|[12:11]| [9:0]       |
+--------+--------+--------+--------+--------+--------+--------+--------+
  3 bit    5 bit   3 bit   3 bit   2 bit   1b   1b   1b   2 bit   10 bit

> **Gen6 FLIT 模式 Header 变化**：FLIT 模式下 TLP Header 格式基本兼容，但 TLP 不再携带独立的 LCRC 和 Sequence Number（由 FLIT 层统一处理）。此外，Gen6 扩展了 Tag 字段和 Length 字段以支持更大范围。
```

- **Fmt[2:0]**：TLP 格式。b000=3DW 无数据, b001=4DW 无数据, b010=3DW 有数据, b011=4DW 有数据
- **Type[4:0]**：TLP 类型（与 Fmt 联合编码，见第 4 节）
- **R**：保留位
- **TC[2:0]**：Traffic Class (0-7)
- **Attr[2:0]**：属性位。Attr[1]=Relaxed Ordering, Attr[0]=No Snoop
- **TH**：TLP Processing Hints (Gen3+)
- **TD**：TLP Digest 存在标志（1=尾部有 ECRC 4 字节）
- **EP**：Poisoned（1=数据含错误，转发但不使用）
- **AT[1:0]**：Address Translation（00=未翻译, 01=翻译后, 10/11=保留）
- **Length[9:0]**：有效载荷长度，以 DW 为单位。00_0000_0000=1024 DW

### 2.2 3DW Header（32-bit Address）

适用于 32-bit 地址空间的 Memory/IO 请求。

```
DW 0: Fmt + Type + TC + Attr + TH + TD + EP + AT + Length
DW 1: Requester ID [15:0] + Tag [7:0]
DW 2: Last DW BE [3:0] + First DW BE [3:0] + Address [31:2]
       [31:28]         [27:24]          [23:0]
```

详细位域：

```
DW 1 (32 bit):
+--------------------+------------------+
| Requester ID       | Tag              |
| [31:16]            | [15:8]           |
+--------------------+------------------+
  Bus[15:8] Dev[7:3] Func[2:0]   8 bit

DW 2 (32 bit):
+----------+----------+---------------------------+
| Last DW  | First DW | Address [31:2]            |
| BE[3:0]  | BE[3:0]  | [23:0]                    |
| [31:28]  | [27:24]  | [23:0]                    |
+----------+----------+---------------------------+
```

- **Requester ID[15:0]**：Bus Number [15:8] + Device Number [7:3] + Function Number [2:0]
- **Tag[7:0]**：事务标签，用于匹配 Request 和 Completion。最大 outstanding 数 = 256（Gen2~5）或 32（Gen1）；**Gen6 扩展到 10-bit Tag（最大 1024 outstanding）**
- **First DW BE[3:0]**：第一个 DW 的字节使能，bit[3] 对应 byte[3] (MSB)
- **Last DW BE[3:0]**：最后一个 DW 的字节使能
- **Address[31:2]**：30-bit 地址（DW 对齐），实际地址 = {Address, 2'b00}

### 2.3 4DW Header（64-bit Address）

适用于 64-bit 地址空间的 Memory 请求。

```
DW 0: Fmt + Type + TC + Attr + TH + TD + EP + AT + Length
DW 1: Requester ID [15:0] + Tag [7:0]
DW 2: Last DW BE [3:0] + First DW BE [3:0] + Address [63:32]
       [31:28]         [27:24]          [23:0]
DW 3: Address [31:2]  + Reserved [1:0]
       [31:2]          [1:0]
```

- **DW 2 的 Address[63:32]**：高 32 位地址
- **DW 3 的 Address[31:2]**：低 30 位地址（DW 对齐）
- 注意：4DW Header 中地址位域分布在 DW2 和 DW3 中，与 3DW 的 DW2 不同

### 2.4 Completion Header（3DW）

```
DW 0: Fmt + Type + R + TC + Attr + TH + TD + EP + AT + Length
DW 1: Completer ID [15:0] + Status [2:0] + BCM + Byte Count [11:0]
       [31:16]              [15:13]      [12]  [11:0]
DW 2: Requester ID [15:0] + Tag [7:0] + R + Lower Address [6:0]
       [31:16]              [15:8]      [7]  [6:0]
```

- **Completer ID[15:0]**：完成者的 Bus/Dev/Func
- **Status[2:0]**：完成状态（见 6.1 节）
- **BCM**：Byte Count Modified（仅 Legacy，PCIe 中保留为 0）
- **Byte Count[11:0]**：剩余未完成字节数
- **Lower Address[6:0]**：CplD 中第一个有效字节的低 7 位地址

---

## 3. TLP Header 各字段详解

### 3.1 Traffic Class (TC)

| TC 值 | 优先级 | 典型用途 |
|--------|--------|----------|
| TC0 | 最低（默认） | 普通数据传输 |
| TC1-TC6 | 中等 | 高优先级数据 |
| TC7 | 最高 | 等时（isochronous）流量 |

多个 TC 可映射到同一个 Virtual Channel (VC)，通过 VC Arbitration 决定转发优先级。

### 3.2 Attribute 位

| 位 | 名称 | 含义 |
|----|------|------|
| Attr[2] | ID-Based Ordering (IDO) | Gen2+，用于跨 RC 的排序 |
| Attr[1] | Relaxed Ordering (RO) | 1=允许越过同 TC 的 Posted/Non-Posted，放宽排序约束 |
| Attr[0] | No Snoop (NS) | 1=暗示接收端无需维护缓存一致性 |

### 3.3 Length 字段编码

| Length[9:0] | 实际 DW 数 |
|-------------|-----------|
| 10'b0000000000 | 1024 DW (4096 B) |
| 10'b0000000001 | 1 DW (4 B) |
| 10'b0000000010 | 2 DW (8 B) |
| ... | ... |
| 10'b1111111111 | 1023 DW (4092 B) |

最大 TLP Payload 由 Max_Payload_Size（MPS）控制：128B / 256B / 512B / 1024B / 2048B / 4096B。

---

## 4. Fmt + Type 编码完整表

| Fmt[2:0] | Type[4:0] | TLP 类型 | 数据? | 说明 |
|----------|-----------|----------|-------|------|
| 000 | 0_0000 | MRd (3DW) | No | Memory Read, 32-bit addr |
| 001 | 0_0000 | MRd (4DW) | No | Memory Read, 64-bit addr |
| 000 | 0_0001 | MRdLk (3DW) | No | Locked Memory Read, 32-bit addr |
| 001 | 0_0001 | MRdLk (4DW) | No | Locked Memory Read, 64-bit addr |
| 010 | 0_0000 | MWr (3DW) | Yes | Memory Write, 32-bit addr |
| 011 | 0_0000 | MWr (4DW) | Yes | Memory Write, 64-bit addr |
| 000 | 0_0010 | IORd | No | IO Read |
| 010 | 0_0010 | IOWr | Yes | IO Write |
| 000 | 0_0100 | CfgRd0 | No | Config Read Type 0 |
| 010 | 0_0100 | CfgWr0 | Yes | Config Write Type 0 |
| 000 | 0_0101 | CfgRd1 | No | Config Read Type 1 |
| 010 | 0_0101 | CfgWr1 | Yes | Config Write Type 1 |
| 000 | 1_0100 | Cpl | No | Completion without Data |
| 010 | 1_0100 | CplD | Yes | Completion with Data |
| 000 | 1_0101 | CplLk | No | Locked Completion |
| 010 | 1_0101 | CplDLk | Yes | Locked Completion with Data |
| 001 | 1_0000 | Msg | No | Message without Data |
| 011 | 1_0000 | MsgD | Yes | Message with Data |
| 000 | 0_1110 | FetchAdd (3DW) | Yes | Fetch and Add (AtomicOp) |
| 001 | 0_1110 | FetchAdd (4DW) | Yes | Fetch and Add (AtomicOp) |
| 000 | 0_1111 | Swap (3DW) | Yes | Unconditional Swap (AtomicOp) |
| 001 | 0_1111 | Swap (4DW) | Yes | Unconditional Swap (AtomicOp) |
| 000 | 0_1100 | CAS (3DW) | Yes | Compare and Swap (AtomicOp) |
| 001 | 0_1100 | CAS (4DW) | Yes | Compare and Swap (AtomicOp) |
| 其他 | - | - | - | 保留 |

**关键规则**：
- Fmt[2] = 0 → 3DW Header；Fmt[2] = 1 → 4DW Header
- Fmt[1] = 0 → 无数据载荷；Fmt[1] = 1 → 有数据载荷
- Fmt[0] 用于区分 3DW/4DW 的最后一位（实际由 Fmt[2] 主导）
- Type[4] = 1 表示 Completion 或 Message 类型

---

## 5. Byte Enable 规则

### 5.1 First DW BE 与 Last DW BE

Byte Enable 用于指定 TLP 数据载荷中哪些字节是有效的。

```
First DW BE [3:0]:
  bit[3] → byte 3 (MSB of DW)
  bit[2] → byte 2
  bit[1] → byte 1
  bit[0] → byte 0 (LSB of DW)

Last DW BE [3:0]:
  bit[3] → byte 3 (MSB of last DW)
  bit[2] → byte 2
  bit[1] → byte 1
  bit[0] → byte 0 (LSB of last DW)
```

### 5.2 规则

- **单 DW 请求**（Length=1）：仅 First DW BE 有效，Last DW BE 忽略（建议设为 0000）
- **多 DW 请求**（Length>1）：First DW BE 对应第一个 DW，Last DW BE 对应最后一个 DW
- **禁止全零**：First DW BE 不能为 4'b0000（至少一个字节有效）
- **地址与 BE 关系**：Address 的低 2 位决定第一个 DW 中有效字节的起始位置

### 5.3 有效字节计算示例

| Address[1:0] | First DW BE | 有效字节 | 说明 |
|-------------|-------------|----------|------|
| 2'b00 | 4'b1111 | byte 0-3 | DW 对齐，全字节 |
| 2'b00 | 4'b0001 | byte 0 | 仅 byte 0 |
| 2'b00 | 4'b1100 | byte 2-3 | 高 2 字节 |
| 2'b01 | 4'b1110 | byte 1-3 | 偏移 1 |
| 2'b10 | 4'b1100 | byte 2-3 | 偏移 2 |
| 2'b11 | 4'b1000 | byte 3 | 偏移 3 |

**注意**：Address[1:0] 必须与 First DW BE 一致，不一致视为协议违规。

### 5.4 多 DW 有效字节计算

对于 4 DW 请求，First DW BE = 0111，Last DW BE = 1100：

```
DW 0: [xxx_] → byte 0,1,2 有效 (First DW BE=0111)
DW 1: [xxxx] → 全部有效
DW 2: [xxxx] → 全部有效
DW 3: [__xx] → byte 2,3 有效 (Last DW BE=1100)
```

---

## 6. Completion 包详解

### 6.1 Completion Status 编码

| Status[2:0] | 缩写 | 名称 | 含义 |
|-------------|------|------|------|
| 000 | SC | Successful Completion | 正常完成 |
| 001 | UR | Unsupported Request | 请求不被支持（地址/类型无效） |
| 010 | CRS | Configuration Request Retry | 配置请求重试（设备未就绪） |
| 100 | CA | Completer Abort | 完成者内部错误中止 |
| 其他 | - | - | 保留 |

### 6.2 Byte Count

- 表示原始请求中**剩余**有效字节数（不是本次 Completion 返回的字节数）
- 对于 MWr 的 Completion（Cpl，无数据），Byte Count = 0
- 对于 MRd 的 Completion（CplD），Byte Count 反映拆分后剩余未完成字节数

### 6.3 Lower Address

- 仅对 CplD 有意义
- 表示 CplD 数据载荷中第一个有效字节在原始请求地址范围内的低 7 位地址
- 配合 Byte Enable 确定接收端应将数据写入的精确位置

### 6.4 拆分 Completion

当 Completer 无法一次返回全部数据时（如 Max_Read_Request_Size 限制），将大读请求拆分为多个 CplD：

```
MRd Request: Address=0x1000, Length=512 DW (2048 B), Tag=5

CplD #1: Tag=5, Byte Count=2048, Lower Addr=0x00, Length=128 DW
  → 返回 [0x1000..0x11FF] 的数据

CplD #2: Tag=5, Byte Count=1536, Lower Addr=0x00, Length=128 DW
  → 返回 [0x1200..0x13FF] 的数据

CplD #3: Tag=5, Byte Count=1024, Lower Addr=0x00, Length=128 DW
  → 返回 [0x1400..0x15FF] 的数据

CplD #4: Tag=5, Byte Count=512,  Lower Addr=0x00, Length=128 DW
  → 返回 [0x1600..0x17FF] 的数据
```

**拆分规则**：
- 每个 CplD 的 Length 不能超过 Completer 的 Max_Payload_Size
- Byte Count 必须递减，最后一个 CplD 的 Byte Count = 实际返回的字节数
- Requester 通过 Byte Count 判断是否已收到全部 Completion
- Completion 可以乱序到达（除非使用 ID Ordering）

---

## 7. Posted vs Non-Posted 事务

### 7.1 事务分类

| 类型 | 事务 | 需要 Completion? | 排序约束 |
|------|------|-----------------|----------|
| **Posted** | MWr | 否 | 同 TC 内保序 |
| **Posted** | Msg / MsgD | 否 | 同 TC 内保序 |
| **Non-Posted** | MRd | 是 (CplD) | 同 TC 内保序 |
| **Non-Posted** | MRdLk | 是 (CplDLk) | 严格保序 |
| **Non-Posted** | IORd / IOWr | 是 (Cpl / CplD) | 严格保序 |
| **Non-Posted** | CfgRd / CfgWr | 是 (Cpl / CplD) | 严格保序 |

### 7.2 排序规则（PCIe Ordering Matrix）

PCIe 定义了严格的事务排序规则，防止死锁并保证数据一致性。

**Posted vs Posted (同 TC)**：

| 后面的 →<br>前面的 ↓ | MWr | Msg |
|----------------------|-----|-----|
| MWr | 强保序（除非 RO） | 强保序 |
| Msg | 强保序 | 强保序 |

**Posted vs Non-Posted**：

| 后面的 →<br>前面的 ↓ | MRd | Cpl |
|----------------------|-----|-----|
| MWr | **不能越过** (防死锁) | 强保序 |
| Msg | 可越过 | 可越过 |

**Non-Posted vs Non-Posted**：

| 后面的 →<br>前面的 ↓ | MRd | Cpl |
|----------------------|-----|-----|
| MRd | 强保序（除非 RO） | 强保序 |

**关键排序约束**：
- MWr **不能越过**同 Requester 的 MRd（防止读到旧数据）
- MRd **不能越过**同 Requester 的 MRd（保证读序）
- Cpl **不能越过**前面的 Cpl（保证完成序）
- RO (Relaxed Ordering) 属性可以放宽上述约束

### 7.3 死锁预防

- Posted 事务不能被 Non-Posted 事务阻塞（Posted 拥有更高转发优先级）
- Completion 必须能穿过 Posted 事务（否则发送 MRd 后阻塞所有后续 Posted）
- 保证 Credit 机制下 Posted 和 Non-Posted 独立分配 Credit

---

## 8. Flow Control（Data Link 层 Credit 机制）

### 8.1 六种 Credit 类型

PCIe 流控在 Data Link Layer 实现，基于 Credit 机制。每个 VC 独立管理 Credit。

| Credit 类型 | 缩写 | 管理对象 | Header 还是 Data |
|-------------|------|----------|-----------------|
| Posted Header | PH | Posted TLP 的 Header | Header (1 Credit = 1 个 TLP Header) |
| Posted Data | PD | Posted TLP 的 Data Payload | Data (1 Credit = 1 DW = 4 字节) |
| Non-Posted Header | NPH | Non-Posted TLP 的 Header | Header |
| Non-Posted Data | NPD | Non-Posted TLP 的 Data Payload | Data |
| Completion Header | CPLH | Completion TLP 的 Header | Header |
| Completion Data | CPLD | Completion TLP 的 Data Payload | Data |

### 8.2 Credit 初始化流程

```
InitFC1 阶段：
  1. 下游端口发送 InitFC1 DLLP（PH/PD/NPH/NPD/CPLH/CPLD 六种）
  2. 上游端口收到后回复对应的 InitFC1
  3. 双方交换初始 Credit 值

InitFC2 阶段：
  1. 下游端口发送 InitFC2 DLLP（确认 Credit 分配）
  2. 上游端口回复对应的 InitFC2
  3. 初始化完成，链路进入 L0 状态

关键规则：
  - Credit 初始化前，端口不能发送任何 TLP
  - Credit 值为 0 时（无限 Credit），对应类型的 TLP 不受 Credit 限制
  - Credit 初始化完成后，链路才能进入正常工作状态
```

### 8.3 Credit 消耗与补充

```
发送端：
  发送 TLP → 检查 Credit 余额
    - Credit 充足 → 消耗对应 Credit，发送 TLP
    - Credit 不足 → TLP 停流，等待 Credit 补充

接收端：
  收到 TLP → 处理（接收 Buffer 消耗）
    - Buffer 释放 → 发送 UpdateFC DLLP 补充 Credit

Credit 消耗计算：
  PH: 每个 Posted TLP 消耗 1 PH Credit
  PD: 消耗量 = TLP Length（DW 单位）
  NPH: 每个 Non-Posted TLP 消耗 1 NPH Credit
  NPD: 消耗量 = TLP Length（DW 单位，如 IOWr）
  CPLH: 每个 Completion TLP 消耗 1 CPLH Credit
  CPLD: 消耗量 = TLP Length（DW 单位）
```

### 8.4 Credit 分配策略

| 策略 | 说明 |
|------|------|
| 无限 Credit | Credit 值设为 0（InitFC1 中发送 0），表示该类不受限 |
| 固定 Credit | InitFC1 中发送固定值，接收端 Buffer 大小决定上限 |
| 低水线阈值 | 信用低于阈值时发送 UpdateFC 预警 |

**设计要点**：
- Credit Buffer 深度 = Max_Payload_Size + 流控延迟 Buffer
- Posted 和 Non-Posted Credit 独立管理，防止 Posted 耗尽阻塞 Completion
- Credit 溢出（发送超过实际分配）是严重协议错误

---

## 9. MSI/MSI-X 中断机制

### 9.1 MSI（Message Signaled Interrupt）

MSI 使用 Memory Write TLP 向特定地址写入中断向量号。

```
MWr TLP:
  Address = MSI Message Address（从 MSI Capability 寄存器读取）
  Data    = MSI Message Data（包含 Vector ID）

MSI Capability 寄存器（配置空间）：
  - Message Address: 32-bit，中断目标地址（通常是 RC 的中断控制器地址）
  - Message Data: 16-bit，低 N 位为中断向量号
  - Multiple Message Enable: 支持 1/2/4/8/16/32 个向量
```

**MSI 限制**：
- 最多 32 个中断向量（Multiple Message Capable 编码限制）
- 向量号必须连续分配
- 无 per-vector 独立地址/数据配置

### 9.2 MSI-X（Table-based Interrupt）

MSI-X 使用独立的 Table 存储每个中断向量的 Address/Data。

```
MSI-X Table Entry (每个 16 字节)：
+-------------------+------------------+
| Msg Address (低32) | Msg Data (32 bit)|
+-------------------+------------------+
| Msg Address (高32) | Vector Control   |
+-------------------+------------------+

Vector Control: bit[0]=Mask，1=屏蔽该向量

MSI-X 特性：
  - 最多 2048 个中断向量
  - 每个向量独立的 Address 和 Data
  - 支持 per-vector 独立 Mask
  - Table 存放在 Memory 空间（BAR）或 SR-IOV VF 的专用 BAR
  - PBA (Pending Bit Array) 记录待处理中断
```

### 9.3 中断聚合

多个 MSI-X 向量可配置为相同的 Message Address，实现中断聚合：

```
Vector 0: Address=0xFEE0_0000, Data=0x0020 → 同一 CPU 核
Vector 1: Address=0xFEE0_0000, Data=0x0021 → 同一 CPU 核
Vector 2: Address=0xFEE0_0000, Data=0x0022 → 同一 CPU 核
Vector 3: Address=0xFEE0_1000, Data=0x0030 → 不同 CPU 核
```

- 同一 Address 的多个向量 → 同一 CPU 核处理，软件通过 Data 区分
- 不同 Address → 路由到不同 CPU 核（中断亲和性）

### 9.4 设计要点

| 要点 | 说明 |
|------|------|
| MSI-X Table 存储 | 通常放在 BAR 空间，支持 BAR 地址过滤 |
| Mask/Unmask | 写 Vector Control[0]=1 屏蔽，=0 取消屏蔽 |
| PBA 管理 | 硬件置位 PBA，软件清零（读 PBA 后写 0） |
| 中断发送 | 产生 MWr TLP，Tag/Requester ID 设为本设备 |
| 性能 | MSI-X 优于 MSI：per-vector mask、更多向量、无需轮询 |

---

## 10. 错误处理

### 10.1 错误分类

| 类别 | 错误类型 | 严重性 | 处理 |
|------|----------|--------|------|
| **Correctable Error** | Receiver Error、Bad TLP、Bad DLLP、Replay Timer、Replay Rollover、Advisory Non-Fatal | Low | 计数 + AER 报告 |
| **Uncorrectable Error (Non-Fatal)** | Data Link Protocol Error、Surprise Down、Poisoned TLP、FC Protocol Error、Completion Timeout、ACS Violation、Malformed TLP | Medium | AER 报告，不导致链路复位 |
| **Uncorrectable Error (Fatal)** | Uncorrectable Internal Error、Undefined | High | AER 报告，可能导致链路复位 |

### 10.2 错误报告机制

```
错误检测 → 错误源记录（Error Status 寄存器）
  → Correctable Error:
     - ECRC Check Failed / Receiver Error 等
     - 上报 Root Port（ERR_COR Message）
  → Uncorrectable Non-Fatal:
     - Malformed TLP / Completion Timeout 等
     - 上报 Root Port（ERR_NONFATAL Message）
  → Uncorrectable Fatal:
     - 严重错误，链路可能不可用
     - 上报 Root Port（ERR_FATAL Message）
```

### 10.3 AER（Advanced Error Reporting）

AER 是 PCIe Capability 扩展，提供详细的错误状态和掩码寄存器：

```
AER Capability 寄存器组：
  +00: Uncorrectable Error Status    → 各类不可纠正错误的状态位
  +04: Uncorrectable Error Mask      → 屏蔽各错误位
  +08: Uncorrectable Error Severity  → 定义各错误为 Fatal/Non-Fatal
  +0C: Correctable Error Status      → 各类可纠正错误的状态位
  +10: Correctable Error Mask        → 屏蔽各可纠正错误位
  +14: Capabilities & Control        → ECRC 使能/检查使能
  +18: Header Log                    → 记录出错 TLP 的 Header（4 DW）
  +28: Root Error Command            → Root Port 中断使能
  +2C: Root Error Status             → Root 端错误汇总
  +34: Error Source Identification   → 标识错误来源
```

### 10.4 ECRC（End-to-End CRC）

- ECRC 附加在 TLP 尾部（TD=1 时，TLP Digest = 4 字节 ECRC）
- 覆盖 TLP Header + Data Payload
- 端到端保护，中间 Switch 不修改 ECRC
- 发送端生成 ECRC，接收端校验

### 10.5 Poisoned TLP（EP=1）

- EP (Error Poisoned) 位为 1 表示 TLP 数据含有错误
- 接收端收到 Poisoned TLP 后：
  - 不能使用数据
  - 可以转发（EP 标记在 TLP 中传播）
  - 记录 Poisoned TLP Received 错误
  - 对于 MRd 的 Poisoned CplD，Requester 记录 Completion Timeout 相关错误

---

## 11. Gen6 TLP 特性变化

### 11.1 FLIT 模式下的 TLP 封装

Gen6 的 1b/1b FLIT 模式从根本上改变了 TLP 的封装方式：

```
传统模式 (Gen1~5)：
  ┌──────┬──────────┬────────┬──────────┬──────┐
  │ STP  │ TLP Hdr  │  Data  │   ECRC   │ LCRC │  ← 每个 TLP 独立封装
  │ 4B   │ 12/16B   │ 0~4KB  │  0/4B    │ 4B   │
  └──────┴──────────┴────────┴──────────┴──────┘

FLIT 模式 (Gen6)：
  ┌───────────────────────────────────────────────┐
  │                  FLIT (256B)                   │
  │  ┌─────┬────────┬────────┬─────┬────────┬────┐│
  │  │Hdr  │TLP #1  │TLP #2  │ ... │TLP #N  │FEC ││
  │  │1B   │变长    │变长    │     │变长    │    ││
  │  └─────┴────────┴────────┴─────┴────────┴────┘│
  └───────────────────────────────────────────────┘
  多个 TLP 紧密排列在同一 FLIT 内，无帧间隙
```

**设计影响**：
- 不再需要每 TLP 独立的 LCRC 生成/校验模块
- FLIT 边界对齐逻辑取代 TLP 帧检测逻辑
- 多 TLP 封装需要 TLP 拆分/重组逻辑
- FLIT 内 padding 管理（不足 256B 时填充）

### 11.2 10-bit Tag 管理

| 项目 | Gen2~5 (8-bit) | Gen6 (10-bit) |
|------|----------------|---------------|
| Tag 范围 | 0~255 | 0~1023 |
| Outstanding 最大数 | 256 | 1024 |
| Tag 存储 | 256-bit 位图 | 1024-bit 位图 |
| Completion 匹配 | 8-bit 比较 | 10-bit 比较 |
| 向后兼容 | - | 与 Gen5 设备互连时仅用 8-bit Tag |

**RTL 设计要点**：
```verilog
// Gen6 Tag 分配器
// 1024-bit 位图，占用 128 字节寄存器或 SRAM
reg [1023:0] tag_bitmap;
wire [9:0]   next_free_tag;

// 使用优先编码器或前导零检测找空闲 Tag
findfirstone #(.WIDTH(1024)) u_tag_finder (
    .in         (~tag_bitmap),
    .first_one  (next_free_tag),
    .valid      (has_free_tag)
);
```

### 11.3 IDE 加密 TLP

Gen6 引入的 IDE (Integrity & Data Encryption) 对 TLP 设计的影响：

```
IDE TLP 流程：
  TLP 生成 → IDE 加密引擎 (AES-GCM-256) → 加密 TLP → 发送
  接收 → IDE 解密引擎 → 明文 TLP → 正常处理

IDE TLP 结构：
  ┌──────────┬─────────────┬──────────────┐
  │ IDE Hdr  │ Encrypted   │ IDE MAC      │
  │ (前缀)   │ TLP Payload │ (完整性校验)  │
  └──────────┴─────────────┴──────────────┘
```

**RTL 设计要点**：
- IDE 加密引擎位于事务层与数据链路层之间
- 需要 AES-GCM-256 硬件加速器（可通过 CBB 实现）
- 密钥管理通过 DOE (Data Object Exchange) Capability
- 可按地址范围/TC 选择性加密（IDE Selective）

### 11.4 Completion Coalescing

Gen6 允许将多个 Completion 合并：

```
传统模式 (Gen5)：
  CplD #1: Tag=5,  Length=1 DW, Byte Count=4
  CplD #2: Tag=6,  Length=1 DW, Byte Count=4
  CplD #3: Tag=7,  Length=1 DW, Byte Count=4
  → 3 个独立 TLP，3 个 Header 开销

FLIT 模式 (Gen6)：
  合并 CplD: Tag=Coal, Length=3 DW, 含 3 个原始完成的合并数据
  → 1 个 TLP，1 个 Header 开销
```

**适用场景**：NVMe 队列大量小读完成（4B/8B CplD）。

---

## 12. 设计注意事项

### 12.1 TLP 解析器设计

| 要点 | 说明 |
|------|------|
| Header 解析 | 先解析 DW0 确定 Fmt/Type → 决定 Header 长度（3DW/4DW）→ 逐字段提取 |
| 地址路由 | 根据 Requester ID (Bus/Dev/Func) 或 Address 进行路由 |
| Byte Enable 处理 | 根据 First/Last DW BE 和 Address[1:0] 裁剪有效字节 |
| ECRC 校验 | TD=1 时提取尾部 4 字节进行 CRC 校验 |
| Length 计算 | Length=0 表示 1024 DW，需要特殊处理 |

**建议流水线**：
```
Stage 0: Header DW0 解析 (Fmt/Type/Length)
Stage 1: Header DW1-DW3 收齐 + 完整解析
Stage 2: 地址路由 / ID 匹配 + 转发决策
Stage 3: 数据载荷处理（如有）
```

### 12.2 Routing 策略

| TLP 类型 | Routing 方式 | 路由依据 |
|----------|-------------|----------|
| MWr/MRd (Memory) | Address Routing | TLP 地址匹配 BAR 空间 |
| IORd/IOWr | Address Routing | IO 地址匹配 BAR |
| CfgRd0/CfgWr0 | ID Routing | Bus/Dev/Func ID 匹配 |
| CfgRd1/CfgWr1 | ID Routing | Bus/Dev/Func ID 匹配，转发到下游桥 |
| Cpl/CplD | ID Routing | Requester ID 匹配 |
| Msg/MsgD | ID Routing / Implicit | 路由到 Root Port 或广播 |
| Vendor Defined | 地址或 ID | 取决于实现 |

### 12.3 Completion Timeout 机制

```
设计要求：
  - 每个 Non-Posted 请求发出后启动 Completion Timeout Timer
  - 默认超时值：根据 PCIe 规范推荐值（通常 50us - 50ms，可配置）
  - 超时处理：
    1. 记录 Completion Timeout 状态
    2. 释放对应的 Tag
    3. 上报 Uncorrectable Error（Non-Fatal）
    4. 可选：触发 FLR（Function Level Reset）

实现建议：
  - Timer 基于 Tag 编号，每个 outstanding 请求独立超时
  - Timer 位宽 = $clog2(max_timeout_cycles)
  - 支持软件配置超时值（通过 Vendor Specific 寄存器）
```

### 12.4 Credit 管理模块

```
设计要点：
  - 六种 Credit 独立计数器（PH/PD/NPH/NPD/CPLH/CPLD）
  - 发送前检查：required_credit <= available_credit
  - Credit 消耗：原子操作（检查 + 扣减同时完成）
  - Credit 补充：收到 UpdateFC DLLP 后更新计数器
  - Credit 耗尽：对应类型 TLP 停流，其他类型不受影响
  - 支持无限 Credit 模式（Credit=0 时跳过检查）

面积估算：
  - 6 个 Credit 计数器 × 每个 12-15 bit = ~90 bit 寄存器
  - 比较逻辑 + 流控信号产生 = ~200 gates
  - 极小面积开销
```

### 12.5 MSI-X Table 设计

```
MSI-X Table (在 BAR 空间中)：
  - 表大小 = NUM_VECTORS × 16 字节
  - 支持最多 2048 个向量 = 32KB Table
  - 对每个 Entry 的读写需要 BAR 地址解码

读写逻辑：
  - 写入 Table Entry → 更新对应的 Address/Data/Vector Control
  - 写入 Vector Control[0]=1 → Mask 该向量
  - 中断触发 → 读取 Table Entry → 发送 MWr TLP
  - Mask=1 时中断挂起（PBA 置位），Mask 解除后补发

PBA (Pending Bit Array)：
  - 每个向量 1 bit，表示中断是否 pending
  - 硬件写 1，软件读取后写 0 清除
  - 大小 = ceil(NUM_VECTORS / 8) 字节
```

### 12.6 与用户逻辑的 TLP 接口

典型 PCIe IP 到用户逻辑的接口信号：

```
// TX (用户逻辑 → PCIe IP): TLP 发送
input  wire        s_axis_tx_tready,
output wire        s_axis_tx_tvalid,
output wire [N:0]  s_axis_tx_tdata,    // TLP 数据 (通常 64/128/256 bit)
output wire [M:0]  s_axis_tx_tkeep,    // 字节有效
output wire        s_axis_tx_tlast,    // TLP 结束标记
output wire        s_axis_tx_tuser,    // TLP 类型/属性等

// RX (PCIe IP → 用户逻辑): TLP 接收
output wire        m_axis_rx_tvalid,
input  wire        m_axis_rx_tready,
output wire [N:0]  m_axis_rx_tdata,
output wire [M:0]  m_axis_rx_tkeep,
output wire        m_axis_rx_tlast,
output wire        m_axis_rx_tuser,    // 含 Header 解析信息
```

**接口设计要点**：
- 数据位宽通常 64/128/256 bit，匹配链路宽度
- Header 和 Data 在同一 burst 中传输
- 用户逻辑需要自己解析 Header（部分 IP 提供解析后的信号）
- TX 侧需要处理 Backpressure（tready 拉低表示 IP buffer 满）

### 12.7 DMA 引擎设计

```
DMA 引擎核心组件：
  1. Descriptor Queue (环形缓冲/FIFO)
     - 每个 Descriptor 包含：源地址、目标地址、长度、控制位
     - 软件写入，硬件消费
  2. Read Engine (H2C: Host to Card)
     - 发送 MRd TLP 读取 Host 内存
     - 收到 CplD 后写入本地 Buffer/存储
  3. Write Engine (C2H: Card to Host)
     - 从本地 Buffer 读取数据
     - 组装 MWr TLP 写入 Host 内存
  4. Completion 管理
     - 跟踪 outstanding MRd 的 Completion
     - 超时检测和错误恢复
  5. Interrupt 逻辑
     - DMA 完成后触发 MSI/MSI-X 中断

关键设计参数：
  - Max Outstanding Read: 同时未完成的 MRd 数量 (受 Tag 数量和 Credit 限制)
  - Max Read Request Size: 单次 MRd 最大长度 (128B-4096B)
  - Max Payload Size: 单次 MWr 最大长度 (128B-4096B)
  - Buffer 深度: 排队 TLP 数据的缓冲大小
  - Address Alignment: 通常要求 128B 或 4KB 对齐以优化性能
```

### 12.8 性能优化要点

| 优化手段 | 说明 | 效果 |
|----------|------|------|
| 增大 Max_Payload_Size | 将 MPS 设为 256B/512B+ | 减少 Header 开销 |
| 增大 Max_Read_Request_Size | 支持大 MRd | 减少请求数 |
| 增大 Outstanding Read | 多 Tag 并行发 MRd（Gen6 支持 1024 Tag） | 提升读带宽 |
| Address 对齐 | 128B/4KB 对齐 | 避免拆分开销 |
| Interrupt Coalescing | 多个完成聚合成一个中断 | 减少中断开销 |
| MSI-X per-vector | 每个完成队列独立向量 | 提升中断处理并行度 |
| RO (Relaxed Ordering) | 允许事务越过 | 提升吞吐 |
| FLIT 模式 (Gen6) | 启用 1b/1b FLIT | 减少帧开销，提升带宽利用率 |
| Completion Coalescing (Gen6) | 合并多个小 Completion | 减少 Completion Header 开销 |
| 10-bit Tag (Gen6) | 扩展 Outstanding 到 1024 | 提升高延迟链路的吞吐 |

---

## 附录：缩略语

| 缩写 | 全称 |
|------|------|
| AER | Advanced Error Reporting |
| AT | Address Translation |
| BAR | Base Address Register |
| BCM | Byte Count Modified |
| CA | Completer Abort |
| CAS | Compare and Swap |
| Cpl | Completion |
| CplD | Completion with Data |
| CRS | Configuration Request Retry |
| DLLP | Data Link Layer Packet |
| ECRC | End-to-End CRC |
| EP | Error Poisoned |
| FLR | Function Level Reset |
| Fmt | Format |
| IDO | ID-based Ordering |
| MWr | Memory Write |
| MRd | Memory Read |
| MSI | Message Signaled Interrupt |
| MSI-X | Message Signaled Interrupt Extended |
| MPS | Max Payload Size |
| NPD | Non-Posted Data |
| NPH | Non-Posted Header |
| PBA | Pending Bit Array |
| PD | Posted Data |
| PH | Posted Header |
| RC | Root Complex |
| RO | Relaxed Ordering |
| SC | Successful Completion |
| TC | Traffic Class |
| TLP | Transaction Layer Packet |
| UR | Unsupported Request |
| VC | Virtual Channel |
