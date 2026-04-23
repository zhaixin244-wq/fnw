# RoCE v2 (RDMA over Converged Ethernet v2) 协议知识文档

> **面向**：数字 IC 设计架构师
> **版本**：v1.0
> **日期**：2026-04-15
> **参考规范**：InfiniBand Architecture (IBA) Release 1.3, RoCE v2 Annex (Annex A17)

---

## 1. 协议概述

RoCE v2 (RDMA over Converged Ethernet v2) 是一种在标准以太网上实现 RDMA (Remote Direct Memory Access) 的传输协议。它将 InfiniBand 的传输层直接封装在 **Ethernet + IPv4/UDP** 之上，使得 RDMA 技术可以在现有的以太网基础设施上运行，无需专用的 InfiniBand 交换网络。

**核心特性**：

| 特性 | 说明 |
|------|------|
| 传输介质 | 标准以太网（10/25/40/50/100/200/400 GbE） |
| 封装层 | Ethernet / IPv4 / UDP / BTH (IB Transport) |
| UDP 目标端口 | **4791** (IANA 分配) |
| 可靠性模型 | 可靠连接 (RC)、不可靠数据报 (UC/UD) |
| 零拷贝 | 网卡直接 DMA 读写用户空间内存 |
| 内核旁路 | 数据面绕过 OS 内核，用户态直接操作 |
| CPU 卸载 | 协议处理（分片/重组/重传/拥塞）全部由 RNIC 硬件完成 |

**与 InfiniBand 的关系**：RoCE v2 直接复用 IB 传输层协议（BTH 头、OpCode、PSN、ACK/NAK），仅替换链路层和网络层（IB LRH → Ethernet/IP/UDP）。因此 RoCE v2 的 QP 模型、WQE 格式、可靠性机制与 IB 原生 RDMA 高度一致。

**典型应用场景**：AI/GPU 集群（NCCL/Gloo）、分布式存储（NVMe-oF）、高频交易、HPC。

---

## 2. 封装格式

### 2.1 完整帧封装

```
+------------------------------------------------------------------+
|                          Ethernet II Frame                        |
+--------+---------+--------+-----+--------------------------------+
| Preamble| Eth Dst | Eth Src|Ether|        IPv4 Header            |
|  7B     |  6B     |  6B   |Type | (20B, Proto=17 for UDP)       |
|         |         |       |0x0800                                |
+--------+---------+--------+-----+-----+----------+--------------+
|                                     | UDP Header (8B)            |
|                                     | SrcPort=var                |
|                                     | DstPort=4791 (RoCE v2)     |
|                                     | Length / Checksum=0        |
+-------------------------------------+-----+---------------------+
|                                           | BTH (12B)            |
|                                           | Base Transport Header |
+-------------------------------------------+-----+---------------+
|                                           | Payload               |
|                                           | (RC/UC/UD 原始数据)   |
+-------------------------------------------+-----+---------------+
|                                           | ICRC (4B)             |
|                                           | Invariant CRC         |
+-------------------------------------------+-----+---------------+
|                                    FCS (4B) Ethernet Frame Check |
+------------------------------------------------------------------+
```

### 2.2 各层详细封装

```
+------------------+------------------+------------------+
|    Ethernet      |    IPv4          |    UDP           |
+==================+==================+==================+
| Dst MAC (48b)    | Version = 4      | Src Port (16b)   |
| Src MAC (48b)    | IHL = 5 (20B)    | Dst Port = 4791  |
| EtherType=0x0800 | TOS/ECN (8b)     | Length (16b)     |
| (IPv4)           | Total Length     | Checksum = 0     |
|                  | ID / Flags / Frag|  (UDP over IPv4  |
|                  | TTL (64 推荐)    |   可选校验)      |
|                  | Protocol = 17    |                  |
|                  | (UDP)            |                  |
|                  | Hdr Checksum     |                  |
|                  | Src IP (32b)     |                  |
|                  | Dst IP (32b)     |                  |
+------------------+------------------+------------------+
|                        BTH (12B)                       |
+========================================================+
| OpCode (8b) | TVer (4b) | P_Key (16b) | FResv (4b)   |
+--------------------------------------------------------+
| Dest QPN (24b)                  | AckReq (1b) | PSN  |
|                                  | Resv (7b)  |(24b) |
+--------------------------------------------------------+
|                       Payload                          |
+--------------------------------------------------------+
|                       ICRC (4B)                        |
+--------------------------------------------------------+
|                       FCS  (4B)                        |
+========================================================+
```

### 2.3 封装开销分析

| 层次 | 字节数 | 说明 |
|------|--------|------|
| Ethernet Header | 14 | Dst + Src + EtherType |
| IPv4 Header | 20 | 无选项 |
| UDP Header | 8 | DstPort=4791 |
| BTH | 12 | IB Base Transport Header |
| ICRC | 4 | Invariant CRC |
| FCS | 4 | Ethernet CRC |
| **协议开销合计** | **62** | 无 VLAN/QinQ 标签时 |
| + VLAN Tag | 4 | 802.1Q (PFC 优先级标记) |
| + Preamble + IFG | 20 | 7B Preamble + 1B SFD + 12B IFG |
| **物理层总开销** | **86** | 含 VLAN |

**有效载荷效率**：MTU=1500 时，有效数据 = 1500 - 20(UDP) - 12(BTH) - 4(ICRC) = 1464B，效率 = 1464/(1500+14+4) = 96.3%。使用 9000B Jumbo Frame 效率可达 99.0%。

---

## 3. BTH (Base Transport Header) 详细字段定义

BTH 是 RoCE v2 的核心传输层头，共 12 字节（96 bit），直接继承自 InfiniBand。

### 3.1 字段布局

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|    OpCode     |TVer |F|Partition Key (P_Key)       |Reserved |
|    (8b)       |(4b) |R|(16b)                        |  (4b)   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Destination QP Number (Dest QPN)            |A|Rsvd |
|          (24b)                                       |K|(7b)  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Packet Sequence Number (PSN)               |
|                    (24b)                                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.2 字段定义

| 字段 | 位宽 | 位置 [bit] | 说明 |
|------|------|-----------|------|
| **OpCode** | 8 | [31:24] | 操作码，标识包类型和在消息中的位置（详见 §4） |
| **TVer** | 4 | [23:20] | Transport Header Version，RoCE v2 固定为 `0x0` |
| **F** | 1 | [19] | First Packet 标记，指示是否为新消息的第一包 |
| **P_Key** | 16 | [18:3] | Partition Key，用于逻辑分区隔离，值 `0xFFFF` 为默认全通 |
| **Reserved** | 4 | [2:0] + [下一字节高 1 位] | 保留，填 0 |
| **Dest QPN** | 24 | [31:8] (第 2 个 32-bit word) | 目标 Queue Pair Number，标识远端 QP |
| **AckReq** | 1 | [7] (第 2 个 word) | Acknowledge Request，置 1 时接收端必须回复 ACK |
| **Reserved** | 7 | [6:0] | 保留，填 0 |
| **PSN** | 24 | [31:8] (第 3 个 32-bit word) | Packet Sequence Number，24-bit 序列号，循环使用 |

### 3.3 关键字段说明

**OpCode**：标识当前包的操作类型（SEND/WRITE/READ/ACK/NAK）和在多包消息中的位置（FIRST/MIDDLE/LAST/ONLY）。详见 §4 编码表。

**P_Key (Partition Key)**：
- `0xFFFF`：Default partition，允许与任意 QP 通信
- 其他值：逻辑分区，QP 间 P_Key 高 15 bit 必须匹配
- 用于多租户隔离或安全分区

**Dest QPN**：
- 24-bit QP 编号，与源 QPN 共同标识一条 RDMA 连接
- QP0/QP1 为特殊管理 QP（RoCE v2 中通常不用）
- 可用 QPN 范围：1 ~ 0xFFFFFE（约 1600 万）

**PSN (Packet Sequence Number)**：
- 24-bit 序列号（0 ~ 0xFFFFFF），发送端为每个包递增
- 用于接收端检测丢包、乱序、重复
- PSN 比较使用模 2^24 运算，支持序列号回绕

**AckReq**：
- 发送端在最后一个包或周期性地置 1，强制接收端回复 ACK
- 用于确认传输进度和触发重传

---

## 4. OpCode 编码表

### 4.1 完整 OpCode 编码

| OpCode [7:0] | 十六进制 | 类型 | 位置 | 操作 | 说明 |
|:-------------|:--------|:-----|:-----|:-----|:-----|
| `0000_0000` | `0x00` | SEND | First | SEND_FIRST | 多包 SEND 的首包 |
| `0000_0001` | `0x01` | SEND | Middle | SEND_MIDDLE | 多包 SEND 的中间包 |
| `0000_0010` | `0x02` | SEND | Last | SEND_LAST | 多包 SEND 的末包 |
| `0000_0011` | `0x03` | SEND | Only | SEND_ONLY | 单包 SEND |
| `0000_0100` | `0x04` | SEND | Last (Imm) | SEND_LAST_WITH_IMMEDIATE | 末包携带立即数 |
| `0000_0101` | `0x05` | SEND | Only (Imm) | SEND_ONLY_WITH_IMMEDIATE | 单包携带立即数 |
| `0000_1000` | `0x08` | RDMA WRITE | First | RDMA_WRITE_FIRST | 多包 WRITE 的首包 |
| `0000_1001` | `0x09` | RDMA WRITE | Middle | RDMA_WRITE_MIDDLE | 多包 WRITE 的中间包 |
| `0000_1010` | `0x0A` | RDMA WRITE | Last | RDMA_WRITE_LAST | 多包 WRITE 的末包 |
| `0000_1011` | `0x0B` | RDMA WRITE | Only | RDMA_WRITE_ONLY | 单包 WRITE |
| `0000_1100` | `0x0C` | RDMA WRITE | Last (Imm) | RDMA_WRITE_LAST_WITH_IMMEDIATE | 末包携带立即数 |
| `0000_1101` | `0x0D` | RDMA WRITE | Only (Imm) | RDMA_WRITE_ONLY_WITH_IMMEDIATE | 单包携带立即数 |
| `0001_0000` | `0x10` | RDMA READ REQ | Only | RDMA_READ_REQUEST | READ 请求（单包） |
| `0001_0001` | `0x11` | RDMA READ RESP | First | RDMA_READ_RESPONSE_FIRST | READ 响应首包 |
| `0001_0010` | `0x12` | RDMA READ RESP | Middle | RDMA_READ_RESPONSE_MIDDLE | READ 响应中间包 |
| `0001_0011` | `0x13` | RDMA READ RESP | Last | RDMA_READ_RESPONSE_LAST | READ 响应末包 |
| `0001_0100` | `0x14` | RDMA READ RESP | Only | RDMA_READ_RESPONSE_ONLY | READ 响应单包 |
| `0001_0101` | `0x15` | ACK | Only | ACK | 确认包 |
| `0001_0110` | `0x16` | NAK | Only | NAK | 否定确认包（通用） |
| `0010_0000` | `0x20` | CNP | Only | CNP | 拥塞通知包 (Congestion Notification Packet) |

**注**：OpCode 编码规则为 `{操作类型[3:0], 位置[3:0]}`。位置字段：First=0x0, Middle=0x1, Last=0x2, Only=0x3, Last+Imm=0x4, Only+Imm=0x5。

### 4.2 NAK 子类型

NAK 通过 BTH 之后的附加字节或 Transport Header 扩展携带子错误码：

| NAK Code | 含义 | 说明 |
|----------|------|------|
| `0x00` | PSN Sequence Error | PSN 不连续，丢包 |
| `0x01` | Invalid Request | 请求类型非法 |
| `0x02` | Remote Access Error | 远端访问权限错误 |
| `0x03` | Remote Operational Error | 远端操作错误 |
| `0x04` | Invalid RD Request | RD 请求无效 |

---

## 5. ICRC (Invariant CRC) 计算

### 5.1 计算目的

ICRC (Invariant CRC-32) 保护 RDMA 传输过程中**不变字段**的完整性。与以太网 FCS 不同，ICRC 覆盖的字段在经过中间交换机时不会被修改（TTL、checksum 等 IP 头字段会变化，不参与 ICRC 计算）。

### 5.2 计算范围

ICRC 覆盖从 UDP 头之后到 Payload 结束的所有字节，以及 IPv4/UDP 头中的不变字段。

```
ICRC 计算范围：
+---------------------------+
| UDP Header (8B)           |  ← 仅 Port 字段参与，Checksum 字段设为 0
+---------------------------+
| BTH (12B)                 |  ← 全部字段
+---------------------------+
| Payload                   |  ← 全部数据
+---------------------------+
| Pad (如有, 填充到 4B 对齐) |
+---------------------------+
```

IPv4 头中的不变字段也参与 ICRC：
- Version, IHL, Total Length, Identification, Flags, Fragment Offset
- Source IP, Destination IP
- **不包含**：TTL, Header Checksum（这些会被交换机修改）

### 5.3 计算方法

- 多项式：`0x1EDC6F41`（与 iSCSI CRC 相同，反转的 CRC-32C）
- 初始值：`0xFFFFFFFF`
- 最终异或值：`0xFFFFFFFF`
- 反射输入/输出：是

**硬件实现要点**：
- CRC-32C 可用流水线实现，每个时钟处理 1/2/4 字节
- 支持增量计算（streaming CRC），无需缓存整帧
- 查表法：256 项 × 32-bit = 1KB ROM

---

## 6. 可靠连接 (RC) 传输流程

### 6.1 QP 状态机

```
                 Modify QP            Modify QP
    +--------+  (INIT)   +-------+  (RTR)    +-------+
    | RESET  | --------> | INIT  | --------> |  RTR  |
    +--------+           +-------+           +-------+
                              |                   |
                         Modify QP           Modify QP
                         (error)             (RTS)
                              |                   |
                              v                   v
                          +-------+          +-------+
                          | ERR   | <------- |  RTS  |
                          +-------+   error  +-------+
                                           |
                                      send drain
                                           |
                                           v
                                      +-------+
                                      |  SQD  |
                                      +-------+
                                           |
                                      flush done
                                           |
                                           v
                                      +-------+
                                      |  SQE  |
                                      +-------+
                                           |
                                      Modify QP
                                      (back to RTS)
```

| 状态 | 含义 | 允许操作 |
|------|------|----------|
| **RESET** | QP 初始状态 | 可修改 QP 属性 |
| **INIT** | 已配置 P_Key、QPN | 可修改 QP 属性，不可收发 |
| **RTR** (Ready To Receive) | 准备接收 | 可接收 SEND/READ RESP，不可发送 |
| **RTS** (Ready To Send) | 可发送可接收 | 完全正常工作状态 |
| **SQD** (Send Queue Drain) | 发送队列排空 | 停止新请求，等待在途包完成 |
| **SQE** (Send Queue Error) | 发送错误 | 部分恢复状态 |
| **ERR** | 错误状态 | 需软件介入恢复 |

### 6.2 SEND/RECV 事务

发送端通过 SQ 的 WQE 发送数据，接收端通过 RQ 的 WQE 接收数据。

```
  Host A (Sender)                           Host B (Receiver)
  =================                         ==================
       |                                         |
       |  --- SEND_FIRST (PSN=100) ----------->  |
       |  [BTH: Op=0x00, PSN=100, DstQPN=Y]     |  收到，写入 RQ WQE buffer
       |                                         |
       |  --- SEND_MIDDLE (PSN=101) ---------->  |
       |  [BTH: Op=0x01, PSN=101]                |  继续写入 buffer
       |                                         |
       |  --- SEND_LAST (PSN=102, AckReq=1) ->  |
       |  [BTH: Op=0x02, PSN=102, AckReq=1]      |  消息完整，生成 CQE
       |                                         |
       |  <--- ACK (MSN=XXX) -----------------  |
       |  [BTH: Op=0x15, PSN=103]                |  确认 PSN 100-102
       |                                         |
       |  生成 CQE (Send Complete)               |
       |                                         |
```

**SEND with Immediate**：末包携带 32-bit 立即数（`SEND_LAST_WITH_IMMEDIATE`），接收端将立即数写入 CQE 通知上层。

### 6.3 RDMA WRITE 事务

发起端直接将数据写入远端内存，远端不需要预先发布 RQ WQE（零接收端参与）。

```
  Host A (Writer)                           Host B (Target)
  =================                         ==================
       |                                         |
       |  WQE: WRITE raddr=RMT_ADDR, len=4096    |
       |                                         |
       |  --- WRITE_FIRST (PSN=200) ---------->  |
       |  [BTH: Op=0x08, PSN=200, DstQPN=Y]      |
       |  [RETH: RmtAddr=0x..., RmtKey=0x...,    |
       |         DMA Length=4096]                 |
       |  [Payload: 1st fragment]                |  DMA write to RMT_ADDR
       |                                         |
       |  --- WRITE_MIDDLE (PSN=201) ---------->  |
       |  [BTH: Op=0x09, PSN=201]                |  DMA write (cont.)
       |                                         |
       |  --- WRITE_LAST (PSN=202, AckReq=1) ->  |
       |  [BTH: Op=0x0A, PSN=202]                |  DMA write (final)
       |                                         |
       |  <--- ACK (PSN=203) ------------------  |
       |                                         |  生成 CQE (可选)
       |  生成 CQE (Write Complete)              |
       |                                         |
```

**RETH (Remote Entry Transport Header)**：WRITE/FIRST 包在 BTH 之后携带 RETH（16 字节），包含远端地址 (Remote Address)、远端内存 Key (R_Key) 和 DMA 长度。

### 6.4 RDMA READ 事务

发起端请求远端数据，分为 READ_REQUEST（拉取请求）和 READ_RESPONSE（数据返回）两个方向。

```
  Host A (Requester)                        Host B (Responder)
  =================                         ==================
       |                                         |
       |  WQE: READ lcl=LCL_ADDR, rmt=RMT_ADDR   |
       |                                         |
       |  --- READ_REQUEST (PSN=300) ---------->  |
       |  [BTH: Op=0x10, PSN=300, DstQPN=Y]      |
       |  [RETH: RmtAddr=0x..., RmtKey=0x...,    |
       |         DMA Length=4096,                 |
       |         LclAddr=0x..., LclKey=0x...]    |
       |                                         |  读取本地内存
       |                                         |
       |  <--- READ_RESPONSE_FIRST (PSN=100) --- |
       |  [BTH: Op=0x11, PSN=100]                |  DMA write to LCL_ADDR
       |                                         |
       |  <--- READ_RESPONSE_MIDDLE (PSN=101) -- |
       |                                         |
       |  <--- READ_RESPONSE_LAST (PSN=102) ---- |
       |  [BTH: Op=0x13, PSN=102]                |
       |                                         |
       |  --- ACK (PSN=301) ------------------>  |
       |  确认 READ_REQUEST 已处理               |
       |                                         |
       |  生成 CQE (Read Complete)               |
       |                                         |
```

**关键**：READ 是双向事务。Requester 发 READ_REQUEST（包含目标地址和期望长度），Responder 发送 READ_RESPONSE 回数据。两端各自维护 PSN。

### 6.5 丢包恢复（Go-Back-N + NAK）

RoCE v2 使用 **Go-Back-N** 选择重传机制，基于 PSN 序列号实现。

#### 6.5.1 丢包检测

| 触发条件 | 检测方 | 响应 |
|----------|--------|------|
| 收到乱序 PSN | 接收端 | 发送 NAK(PSN Sequence Error)，携带期望的下一个 PSN |
| 超时未收到 ACK | 发送端 | 超时重传（从 ACK 确认的 PSN 开始重发） |
| 收到重复 PSN | 接收端 | 丢弃重复包，重新发送 ACK |

#### 6.5.2 重传流程

```
  Sender                                    Receiver
  ======                                    ========
       |                                         |
       |  --- SEND (PSN=100) ----------------->  |  正常接收
       |  <--- ACK (next=101) ----------------  |
       |                                         |
       |  --- SEND (PSN=101) ---- X  丢包!      |
       |                                         |
       |  --- SEND (PSN=102) ----------------->  |  PSN 101 缺失
       |  <--- NAK (expected=101) -------------  |  NAK: 期望 PSN 101
       |                                         |
       |  --- SEND (PSN=101) [重传] -----------> |  Go-Back-N: 从 101 重发
       |  --- SEND (PSN=102) [重发] -----------> |
       |  <--- ACK (next=103) ----------------  |
       |                                         |
```

#### 6.5.3 超时机制

- **RNR NAK** (Receiver Not Ready)：接收端 RQ 无可用 WQE 时发送，包含重试定时器（1~65536 ms）
- **发送端超时重传**：ACK 未在 timeout 内到达时，重传未确认的包
- **重试次数上限**：通常 7 次（`retry_cnt`），超过则 QP 进入 ERR 状态
- **RNR 重试次数上限**：通常 7 次（`rnr_retry`）

---

## 7. 拥塞控制

### 7.1 PFC (Priority Flow Control)

PFC (IEEE 802.1Qbb) 是链路层流控机制，为 RoCE v2 提供无损网络基础。

#### 7.1.1 工作原理

```
  +--------+    Ethernet    +--------+
  | RNIC A | ==============> | Switch |
  +--------+                +--------+
       |                          |
       |  PFC XOFF (pri=N)       |
       | <=======================|  反压：该优先级队列拥塞
       |                          |
       |  (停止发送 pri=N 流量)    |
       |                          |
       |  PFC XON (pri=N)        |
       | <=======================|  释放：队列清空
       |                          |
       |  (恢复发送 pri=N 流量)    |
```

#### 7.1.2 PFC 与 RoCE v2 的关系

| 项目 | 说明 |
|------|------|
| 优先级映射 | RoCE v2 流量标记在 VLAN PCP 字段中（通常 PCP=5 或 6） |
| PFC 对象 | 以 802.1p 优先级为粒度（共 8 个优先级），每个优先级独立反压 |
| 无损保证 | PFC 反压发送端停止发送，避免丢包（RoCE v2 依赖无损网络） |
| 帧格式 | PFC Pause 帧携带 8 个 priority 的 on/off 向量和 quanta |

#### 7.1.3 PFC 风暴问题

PFC 反压具有传播性：下游 switch 反压 → switch 反压上游 → 上游 RNIC 停止。若多流汇聚导致队列拥塞，PFC 风暴可能导致大面积流量停滞。

**缓解方案**：ECN + DCQCN（主动拥塞控制），减少对 PFC 的依赖。

### 7.2 ECN + CNP 拥塞通知

#### 7.2.1 ECN 标记

ECN (Explicit Congestion Notification, RFC 3168) 利用 IPv4 头中的 ECN 位（TOS 字段 bit[1:0]）。

```
IPv4 Header TOS/ECN 字段:
  +-----+-----+-----+-----+-----+-----+-----+-----+
  |  DSCP (6b)              | ECN (2b)             |
  +-----+-----+-----+-----+-----+-----+-----+-----+
                                       [1:0]
  ECN 编码:
    00 = Not ECN-Capable (Non-ECT)
    01 = ECN-Capable Transport 0 (ECT(0))
    10 = ECN-Capable Transport 1 (ECT(1))
    11 = Congestion Experienced (CE)  ← 交换机拥塞时标记
```

**流程**：
1. 发送端标记 IPv4 ECN = ECT(0) 或 ECT(1)
2. 交换机队列超过阈值时，将 ECN 改写为 CE (Congestion Experienced)
3. 接收端检测到 CE 标记后，生成 CNP 回传发送端

#### 7.2.2 CNP (Congestion Notification Packet)

CNP 是接收端发回的特殊 RoCE v2 包，通知发送端降速。

```
CNP 包结构：
+------------------+
| Ethernet Header  |
+------------------+
| IPv4 Header      |  ECN = 00 (Non-ECT)
+------------------+
| UDP Header       |  DstPort = 4791
+------------------+
| BTH              |  OpCode = 0x20 (CNP)
|  OpCode = 0x20   |  Dest QPN = 发送端 QPN
|  Dest QPN = src  |
+------------------+
| CNP Header       |  含 QP 号、流标识
+------------------+
| ICRC             |
+------------------+
| FCS              |
+------------------+
```

CNP 特点：
- 单包，无需 ACK
- 携带 QP 标识（发送端 QPN），发送端据此降速
- 最小帧长（约 64~74 字节），不增加网络负担

### 7.3 DCQCN 拥塞控制算法

DCQCN (Data Center Quantized Congestion Notification) 是 RoCE v2 最常用的端到端拥塞控制算法，结合 ECN 标记和速率调整。

#### 7.3.1 三角色模型

```
  +-----------+       ECN=CE         +-----------+      CNP       +-----------+
  |  Sender   | ------------------> |  Switch   | ------------> | Receiver  |
  | (Rate     |    (队列拥塞,        |           |  (CNP 回传)   | (检测CE,  |
  |  Adjust)  |     标记 CE)        | (队列监控) |               |  发CNP)   |
  +-----------+                    +-----------+               +-----------+
       |                                                                  |
       |  收到 CNP 后:                                                     |
       |  1. 降低发送速率 (RP: Rate Probing)                               |
       |  2. 逐步恢复速率 (AI: Additive Increase)                          |
       |                                                                  |
```

#### 7.3.2 速率调整状态机

```
  +--------+  CNP 收到   +----------+  超时(α恢复)
  |  STAGE | ----------> |  FASTER  | ----------> STAGE (速率+AI)
  |  0     |  (速率×(1-α))|          |
  +--------+             +----------+
       ^                      |
       |                      | 超时
       |                      v
       |                 +----------+
       +---------------- |  FASTER  |  持续加速
                         |  (AI)    |  速率 += AI
                         +----------+
```

**关键参数**：

| 参数 | 典型值 | 说明 |
|------|--------|------|
| α (降速因子) | 0.5 | 收到 CNP 后速率乘 (1-α) |
| α 恢复时间 | 50-100 us | α 逐渐衰减到 0 |
| G (目标速率) | 按线速计算 | 长期目标速率 |
| AI (加性增) | G/Δt_per_increase | 每周期增加的速率 |
| 高速阈值 (HAI) | 接近线速 | 接近上限时用更大的 AI 步长 |
| Timer 刷新周期 | ~55 us | DCQCN 状态更新周期 |

#### 7.3.3 DCQCN 效果

- 快速降速：收到 CNP 后立即降速，避免拥塞加剧
- 渐进恢复：通过 AI 逐步恢复速率，避免再次拥塞
- 公平收敛：多流竞争时，各流速率收敛到公平共享

---

## 8. 与 InfiniBand 原生 RDMA 的对比

| 对比维度 | InfiniBand (IB) 原生 | RoCE v2 |
|----------|---------------------|---------|
| **链路层** | IB Link Layer (专用) | 标准 Ethernet |
| **网络层** | 无（IB LRH 直接寻址） | IPv4 (可扩展 IPv6) |
| **传输层** | IB Transport (BTH) | 相同 (BTH) |
| **寻址方式** | LID (16-bit Local ID) + GID | IP 地址 + UDP 端口 |
| **路由方式** | IB 子网路由 + 自适应路由 | IP 路由 + ECMP |
| **交换机** | IB 交换机（专用设备） | 标准以太网交换机 |
| **流控** | IB Credit-based + VL Arbitration | PFC (802.1Qbb) + ECN/DCQCN |
| **无损保证** | 链路层 Credit 流控原生无损 | PFC 提供无损保证 |
| **拥塞控制** | FECN/BECN 机制 | ECN + CNP + DCQCN |
| **MTU** | 256/512/1024/2048/4096 | 受以太网 MTU 限制（1500 或 9000 Jumbo） |
| **分片/重组** | 链路层自动分片 | RNIC 硬件分片（受 MTU 限制） |
| **管理接口** | SM (Subnet Manager) 集中管理 | 无集中管理（IP 网络） |
| **QP 模型** | 完全相同 | 完全相同 |
| **WQE/CQE 格式** | 完全相同 | 完全相同 |
| **可靠性** | RC/UC/UD | RC/UC/UD（相同） |
| **交换机成本** | 高（专用设备） | 低（通用以太网交换机） |
| **部署难度** | 需要专用 IB 网络 | 复用现有以太网基础设施 |
| **带宽演进** | NDR 400Gb/s | 400/800GbE |
| **典型延迟** | ~0.5-1 us (同子网) | ~1-3 us (同机架) |

**架构师结论**：RoCE v2 在传输层与 IB 原生 RDMA 高度一致（相同的 BTH/OpCode/PSN/QP 模型），主要差异在链路层和网络层。设计 RNIC 时，传输引擎可复用 IB 逻辑，仅需替换链路层为 Ethernet MAC + IP/UDP 封装/解封装。

---

## 9. 与 RoCE v1 的区别

| 对比维度 | RoCE v1 | RoCE v2 |
|----------|---------|---------|
| **封装层** | IB BTH 直接封装在 Ethernet | Ethernet / IPv4 / UDP / BTH |
| **EtherType** | `0x8915` (RoCE) | `0x0800` (IPv4) |
| **传输方式** | 纯以太网二层帧 | 三层 IP + 四层 UDP |
| **路由能力** | 仅 VLAN 二层域 | IP 路由，支持跨子网 |
| **ECMP 支持** | 不支持（二层无等价多路径） | 支持（IP 五元组 hash） |
| **UDP 端口** | 无 | DstPort = 4791 |
| **ICRC 保护** | 部分保护 | 完整保护（含 IP/UDP 不变字段） |
| **PFC 依赖** | 强依赖（二层无损） | 仍需但配合 ECN 降依赖 |
| **网络规模** | 受限于 VLAN 二层域 | 可扩展到大规模 IP 网络 |
| **部署复杂度** | 需要专用 VLAN + PFC | 可用标准 IP 网络（仍需 PFC/ECN） |
| **标准化** | InfiniBand Trade Association | InfiniBand Trade Association |
| **当前状态** | 已过时 | **主流部署方案** |

**关键区别总结**：RoCE v1 是二层协议，无法路由，不支持 ECMP，不适合大规模部署。RoCE v2 增加了 IP/UDP 封装，具备路由能力和 ECMP 多路径，是当前 AI 集群和数据中心的主流选择。

---

## 10. RNIC (RDMA NIC) 硬件架构

### 10.1 整体框图

```
+================================================================================+
|                           RNIC (RDMA NIC) 芯片                                |
+================================================================================+
|                                                                                |
|  +------------------+     +------------------+     +------------------+        |
|  |   PCIe Endpoint  |     |   DMA Engine     |     |   Doorbell       |        |
|  |   (Gen4/5 x16)   |     |   (H2C / C2H)    |     |   Processing     |        |
|  |                  |<--->|                  |<--->|                  |        |
|  |  BAR Space       |     |  Scatter-Gather  |     |  Ring Poll       |        |
|  |  MSI-X           |     |  64B Addr        |     |  WQE Fetch       |        |
|  +--------+---------+     +--------+---------+     +--------+---------+        |
|           |                        |                        |                  |
|           +------------------------+------------------------+                  |
|                                    |                                           |
|                          +---------v----------+                                |
|                          |   QP Manager        |                                |
|                          |   (QP Context RAM)  |                                |
|                          |   - SQ/RQ State     |                                |
|                          |   - PSN, Retry Cnt  |                                |
|                          |   - QP Number Table  |                                |
|                          +---------+----------+                                |
|                                    |                                           |
|                     +--------------+--------------+                            |
|                     |                             |                            |
|            +--------v----------+      +-----------v--------+                   |
|            |   Send Engine      |      |   Receive Engine   |                   |
|            |                    |      |                    |                   |
|            |  +-------------+  |      |  +-------------+  |                   |
|            |  | WQE Decode  |  |      |  | BTH Decode  |  |                   |
|            |  +------+------+  |      |  +------+------+  |                   |
|            |         |         |      |         |         |                   |
|            |  +------v------+  |      |  +------v------+  |                   |
|            |  | BTH Build   |  |      |  | RQ Match    |  |                   |
|            |  | (OpCode/PSN)|  |      |  | (QPN/PSN)   |  |                   |
|            |  +------+------+  |      |  +------+------+  |                   |
|            |         |         |      |         |         |                   |
|            |  +------v------+  |      |  +------v------+  |                   |
|            |  | Data Buffer |  |      |  | Data Buffer |  |                   |
|            |  | (TX FIFO)   |  |      |  | (RX FIFO)   |  |                   |
|            |  +------+------+  |      |  +------+------+  |                   |
|            +--------|---------+      +--------|---------+                   |
|                     |                          |                               |
|            +--------v----------+      +--------v----------+                   |
|            |   Retransmit      |      |   ACK/NAK Gen     |                   |
|            |   Buffer          |      |   & PSN Check     |                   |
|            |   (Go-Back-N)     |      |   ICRC Verify     |                   |
|            +--------+----------+      +--------+----------+                   |
|                     |                          |                               |
|                     +-----------+--------------+                               |
|                                 |                                              |
|                      +----------v-----------+                                  |
|                      |   UDP/IP Encap/Decap |                                  |
|                      |   - IPv4 Header Gen  |                                  |
|                      |   - UDP Port 4791    |                                  |
|                      |   - ECN Marking      |                                  |
|                      |   - ICRC Calc/Check  |                                  |
|                      +----------+-----------+                                  |
|                                 |                                              |
|                      +----------v-----------+                                  |
|                      |   Ethernet MAC/PCS   |                                  |
|                      |   (25/100/200/400G)  |                                  |
|                      |   - PFC (802.1Qbb)   |                                  |
|                      |   - VLAN Insert/Strip|                                  |
|                      |   - FCS Gen/Check    |                                  |
|                      +----------+-----------+                                  |
|                                 |                                              |
+=================================|==============================================+
                                  |
                          SerDes / SFP+/QSFP
```

### 10.2 子模块功能

| 子模块 | 功能 |
|--------|------|
| **PCIe Endpoint** | 主机接口，BAR 空间映射 Doorbell/Mailbox，MSI-X 中断 |
| **DMA Engine** | H2C (Host-to-Card) / C2H (Card-to-Host) DMA，Scatter-Gather |
| **Doorbell Processing** | 轮询 Doorbell Ring，提取 WQE 指令 |
| **QP Manager** | QP Context 存储与管理（SRAM/Regfile），状态机维护 |
| **Send Engine** | WQE 解码、BTH 封装、分片、PSN 分配、重传缓冲 |
| **Receive Engine** | BTH 解析、QPN 匹配、PSN 校验、ACK/NAK 生成 |
| **Retransmit Buffer** | 已发送但未确认的包缓存，Go-Back-N 重传 |
| **UDP/IP Encap/Decap** | IPv4/UDP 头封装/解封装、ECN 标记、ICRC 计算 |
| **Ethernet MAC/PCS** | 标准以太网 MAC、PFC 处理、VLAN tag 操作、FCS |
| **Completion Queue** | CQE 生成、MSI-X 中断触发、CQ 压缩 |

---

## 11. 关键设计要点

### 11.1 WQE DMA 和 Doorbell 机制

**WQE (Work Queue Entry)** 是主机软件提交给 RNIC 的工作描述符，包含操作类型、本地/远端地址、数据长度、R_Key 等。

**Doorbell 机制**：
1. 软件在 SQ Ring 中写入 WQE
2. 软件写 Doorbell 寄存器（写 QP 号 + WQE 数量）
3. RNIC 读取 Doorbell 后，通过 DMA 从主机内存读取 WQE
4. DMA 读取完成后进入 Send Engine 处理

**设计要点**：
- Doorbell 可以聚合（batch doorbell），一次通知多个 WQE，减少 PCIe 写次数
- Doorbell 寄存器映射在 PCIe BAR 空间，单次 64-bit MMIO Write
- WQE 格式遵循 InfiniBand 规范（标准 64B 对齐，SGE 列表可变长度）

### 11.2 SQ/RQ Ring Buffer 管理

```
  主机内存中的 Ring Buffer:

  +--------+--------+--------+--------+--------+--------+
  | WQE 0  | WQE 1  | WQE 2  | WQE 3  | WQE 4  | WQE 5  | ...
  +--------+--------+--------+--------+--------+--------+
  ^               ^                                        ^
  |               |                                        |
  Producer Index  Consumer Index                           Wrap
  (软件写入)      (RNIC 消费)                              (环形)

  SQ: 软件是 Producer，RNIC 是 Consumer
  RQ: RNIC 是 Producer（收到包后写入），软件是 Consumer
```

**设计要点**：
- Ring 大小（`max_send_wr` / `max_recv_wr`）必须是 2 的幂（方便 wrap 计算）
- Producer/Consumer Index 用 32-bit（高位隐含 wrap 计数）
- RNIC 内部缓存 QP Context 中的 index 值
- 需要处理 Ring 满/空的流控：SQ 满时 WQE 等待，RQ 空时发 RNR NAK

### 11.3 CQ (Completion Queue) 通知

CQ 是操作完成的事件队列，软件通过轮询或中断方式获知完成。

**设计要点**：
- CQ 可以聚合多个 QP 的完成事件
- MSI-X 中断：每个 CQ 可配置独立中断向量
- CQ 压缩 (CQ Compression)：多个小完成合并为一个 CQE，减少中断频率
- 轮询模式 (Polling)：高性能场景软件主动 poll CQ，无需中断（AI 训练常用）
- CQ Overflow 保护：CQ 满时 QP 进入 ERR 状态

### 11.4 Memory Translation / TLB / IOMMU

RDMA 需要 RNIC 直接 DMA 访问用户空间内存，需要地址翻译。

```
  虚拟地址 (VA)  →  RNIC TLB  →  物理地址 (PA)
                      ↑
                 IOMMU / ATS (Address Translation Service)
                      ↑
                 PCIe ATS 请求
```

**设计要点**：
- **MR (Memory Region)**：用户注册的内存区域，包含 VA 范围、R_Key、L_Key
- **R_Key / L_Key**：用于远端/本地访问权限校验
- **On-Chip TLB**：缓存 VA→PA 映射，减少 IOMMU 查询延迟
- **Page Table Walker**：TLB miss 时通过 PCIe ATS 向 IOMMU 请求翻译
- **IOMMU 集成**：Intel VT-d / AMD-Vi，RNIC 作为 PCIe endpoint 参与
- **Pinned Memory**：注册 MR 时锁定物理页，避免页表变动

### 11.5 多 QP 并发管理

大规模 AI 集群中，单个 RNIC 需管理数万条 QP。

**设计要点**：
- QP Context 存储：大容量 SRAM（典型 64K~256K QP）
- QP Hash / CAM：快速根据 Dest QPN + Src IP 查找 QP Context
- 并发调度：Round-Robin 或 Weighted Fair Queueing 调度多 QP
- QP 隔离：防止一条 QP 的重传阻塞其他 QP 的正常发送
- 多核适配：支持多 CPU core 同时操作不同 QP（无锁设计）

### 11.6 PFC 优先级映射

**设计要点**：
- VLAN PCP 字段映射：通常 RoCE v2 流量使用 PCP=5 或 6
- 8 个优先级队列独立 PFC 反压
- ECN 标记：出口队列深度超过 `ecn_threshold_high` 时标记 CE
- ECN 门限配置：寄存器可配置高/低阈值（与 DCQCN 参数配合）
- PFC 帧生成/响应：MAC 层硬件自动处理

### 11.7 与 PCIe/AXI 接口

| 接口 | 方向 | 协议 | 典型位宽 | 用途 |
|------|------|------|----------|------|
| Host ↔ RNIC | 双向 | PCIe Gen4/5 x16 | 256/512-bit @ 250/500 MHz | WQE DMA, Doorbell, CQE, 数据搬运 |
| RNIC 内部 | 片内 | AXI4 / AXI4-Stream | 256/512-bit | 数据通路互联 |
| RNIC ↔ PHY | 片间 | SerDes | 56/112 Gbps/lane | 以太网物理层 |

**PCIe 接口设计**：
- BAR0：Doorbell 空间（MMIO，单次 8B 写）
- BAR2：控制寄存器（QP 配置、中断配置）
- DMA：Scatter-Gather 支持，64-bit 地址
- MSI-X：每个 CQ/CQ 一个中断向量

**AXI 内部互联**：
- AXI4-Stream 用于数据通路（Send/Receive Engine ↔ MAC）
- AXI4-Lite 用于寄存器配置
- AXI4 用于内部 SRAM 访问（QP Context, Retransmit Buffer）

---

## 12. 典型 AI 集群网络拓扑

### 12.1 胖树 (Fat-Tree) / 叶脊 (Leaf-Spine) 拓扑

```
                      +-------+    +-------+    +-------+
                      | Spine |    | Spine |    | Spine |
                      | Sw 1  |    | Sw 2  |    | Sw 3  |
                      +---+---+    +---+---+    +---+---+
                     / |   | \      / |   | \      / |   | \
                    /  |   |  \    /  |   |  \    /  |   |  \
                   /   |   |   \  /   |   |   \  /   |   |   \
              +---+----+---+----++----+---+----++----+---+----+---+
              | Leaf  | Leaf | Leaf | Leaf | Leaf | Leaf |       |
              | Sw 1  | Sw 2 | Sw 3 | Sw 4 | Sw 5 | Sw 6 |       |
              +--+----+--+---+--+---+--+---+--+---+--+---+       |
                /|\      /|\     /|\    /|\     /|\    /|\        |
               / | \    / | \   / | \  / | \   / | \  / | \       |
              R  R  R  R  R  R  R  R  R  R  R  R  R  R  R  R     |
              N  N  N  N  N  N  N  N  N  N  N  N  N  N  N  N     |
              I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I     |
              C  C  C  C  C  C  C  C  C  C  C  C  C  C  C  C     |
```

**典型配置**：
- **2 层胖树**：每台 Leaf 连接 48 台 GPU 服务器，6 台 Spine 提供上行带宽
- **超分比 (Oversubscription)**：Leaf→Spine 上行带宽 = 下行带宽时为 1:1 无阻塞
- **收敛比**：AI 训练通常要求 1:1 无阻塞；推理可接受 3:1 或 5:1

### 12.2 ECMP (Equal-Cost Multi-Path)

ECMP 利用 IP 五元组 hash 实现多路径负载均衡。

```
  +----------+                                    +----------+
  | Server A |                                    | Server B |
  | RNIC     |                                    | RNIC     |
  +----+-----+                                    +-----+----+
       |                                                |
       |   +--------+     Path 1     +--------+        |
       +-->| Leaf 1 | ============> | Spine 1| =======+
           +--------+     Path 2     +--------+
                          ============> | Spine 2| =======+
                          Path 3     +--------+
                          ============> | Spine 3|
                                        +--------+
```

**ECMP 设计要点**：
- Hash 输入：SrcIP + DstIP + SrcPort + DstPort + Protocol
- Hash 算法：CRC32 / Toeplitz / CRC32c
- 静态 ECMP：固定 hash，简单但可能出现 hash 极化
- 动态 ECMP / Adaptive Routing：根据链路负载动态选择路径
- 同一 QP 的包必须走同一条路径（保证顺序），或由 RNIC 负责重排序

### 12.3 AI 集群规模参考

| 规模 | GPU 数量 | Spine 数量 | Leaf 数量 | 单 Spine 上行带宽 | 网络总带宽 |
|------|----------|-----------|-----------|-------------------|-----------|
| 小型 | 64~128 | 4 | 4~8 | 8×400G = 3.2T | ~12.8T |
| 中型 | 256~512 | 8 | 16~32 | 16×400G = 6.4T | ~51.2T |
| 大型 | 1024~2048 | 16 | 32~64 | 32×400G = 12.8T | ~204.8T |
| 超大 | 4096~8192 | 32+ | 64~128 | 64×800G = 51.2T | ~1.6P+ |

**注**：以上为参考值，实际配置取决于 GPU 服务器密度、单卡带宽和超分比。

---

## 附录

### A. 缩略语

| 缩写 | 全称 |
|------|------|
| BTH | Base Transport Header |
| CNP | Congestion Notification Packet |
| CQ | Completion Queue |
| CQE | Completion Queue Entry |
| DCQCN | Data Center Quantized Congestion Notification |
| ECN | Explicit Congestion Notification |
| ECMP | Equal-Cost Multi-Path |
| FCS | Frame Check Sequence |
| ICRC | Invariant CRC |
| IOMMU | Input/Output Memory Management Unit |
| MR | Memory Region |
| NAK | Negative Acknowledgment |
| PFC | Priority Flow Control |
| PSN | Packet Sequence Number |
| QP | Queue Pair |
| RC | Reliable Connection |
| RDMA | Remote Direct Memory Access |
| RETH | Remote Entry Transport Header |
| RNIC | RDMA Network Interface Card |
| RNR | Receiver Not Ready |
| RQ | Receive Queue |
| RQH | Receive Queue Handle |
| SQ | Send Queue |
| UC | Unreliable Connection |
| UD | Unreliable Datagram |
| WQE | Work Queue Entry |

### B. 参考文档

| 编号 | 文档 | 版本 | 说明 |
|------|------|------|------|
| REF-001 | InfiniBand Architecture Specification | Release 1.3 | IB 传输层规范 |
| REF-002 | RoCE Annex (Annex A17) | v1.2 | RoCE v2 封装规范 |
| REF-003 | IEEE 802.1Qbb | 2011 | Priority Flow Control |
| REF-004 | RFC 3168 | 2001 | ECN for IP |
| REF-005 | RFC 768 | 1980 | UDP |
| REF-006 | DCQCN Paper (Zhu et al.) | 2015 | DCQCN 算法论文 |
