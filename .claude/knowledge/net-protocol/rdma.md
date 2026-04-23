# RDMA / RoCE 协议知识文档

> **面向**：数字 IC 设计架构师
> **用途**：RNIC（RDMA Network Interface Card）RTL 架构设计参考
> **版本**：v1.0
> **日期**：2026-04-15

---

## 1. 协议概述

**RDMA (Remote Direct Memory Access)** 是一种允许一台计算机直接访问另一台计算机内存的网络通信技术，无需操作系统内核参与，无需 CPU 介入数据搬运。

**三大核心特性**：

| 特性 | 说明 | 硬件影响 |
|------|------|----------|
| **零拷贝 (Zero-Copy)** | 数据直接从网卡 DMA 到应用内存，不经过内核缓冲区 | RNIC 需要 Memory Translation Engine（VA→PA） |
| **内核旁路 (Kernel Bypass)** | 用户态直接提交 Work Request 到网卡，不经过系统调用 | Doorbell 机制：用户态写 PCIe MMIO 通知硬件 |
| **CPU 卸载 (CPU Offload)** | 协议处理（重传、ACK、分片）由硬件完成 | Send/Receive Engine 需完整实现传输层状态机 |

**性能优势**：相比传统 TCP/IP Socket，RDMA 延迟降低 10-100 倍（~1μs vs ~50μs），CPU 占用降低 90% 以上。

---

## 2. RDMA 三种实现对比

| 维度 | InfiniBand (IB) | RoCE v1 | RoCE v2 (rRoCE) | iWARP |
|------|-----------------|---------|-----------------|-------|
| **底层链路** | InfiniBand 专用 fabric | 以太网 L2（同子网） | 以太网 L3（跨子网） | TCP/IP |
| **传输层** | IB Transport (可靠/不可靠) | IB Transport over Eth | **IB Transport over UDP** | TCP (RFC 5045 DDP + MPA) |
| **封装** | LRH → BTH → Payload | GRH → BTH → Payload | Eth → IP → **UDP** → BTH → Payload | Eth → IP → TCP → DDP → Payload |
| **流控** | Credit-based + Link Level | PFC (逐跳) | **PFC + ECN/DCTCP** | TCP 自身流控 |
| **拥塞控制** | Credit-based (内建) | 无标准方案 | **ECN-based (类似 DCTCP)** | TCP 拥塞控制 |
| **跨子网** | 支持 (IB Router) | **不支持** (L2 only) | **支持** (IP routing) | 支持 |
| **乱序处理** | 有序 fabric，无需乱序 | 同 IB | **需处理 IP/UDP 乱序** | TCP 保序 |
| **典型部署** | HPC 集群、超算 | 数据中心（同 rack） | **云数据中心（主流）** | WAN / 遗留以太网 |
| **IC 设计关注** | 完整 IB 协议栈 | 简化版，无 UDP | **需 UDP 解析 + ECN** | TCP 状态机复杂 |

**当前主流**：RoCE v2 — 兼容以太网基础设施，支持跨子网，是数据中心 RDMA 的事实标准。

---

## 3. RDMA 核心概念

### 3.1 Queue Pair (QP)

QP 是 RDMA 通信的基本端点，每个 QP 包含：

```
+---------------------------------------------------------------+
|                        Queue Pair (QP)                        |
|                                                               |
|  +---------------------+    +----------------------+          |
|  |    Send Queue (SQ)  |    |   Receive Queue (RQ) |          |
|  |                     |    |                      |          |
|  |  WQE 0  <-- head   |    |  WQE 0  <-- head     |          |
|  |  WQE 1              |    |  WQE 1               |          |
|  |  WQE 2              |    |  WQE 2               |          |
|  |  ...                |    |  ...                  |          |
|  |  WQE N-1            |    |  WQE N-1              |          |
|  +---------------------+    +----------------------+          |
|           |                          |                        |
|           v                          v                        |
|  +---------------------------------------------+             |
|  |           Completion Queue (CQ)              |             |
|  |                                              |             |
|  |  CQE 0  (SQ completion)                      |             |
|  |  CQE 1  (RQ completion)                      |             |
|  |  CQE 2  (SQ completion)                      |             |
|  |  ...                                         |             |
|  +---------------------------------------------+             |
+---------------------------------------------------------------+
```

**关键关系**：
- 每个 QP 有 1 个 SQ 和 1 个 RQ
- SQ 和 RQ 可以共享同一个 CQ，也可以各有独立 CQ
- 一个 CQ 可以被多个 QP 共享
- QP 全局唯一编号：**QPN (QP Number)**，24-bit

### 3.2 Work Request (WR) / Work Queue Element (WQE)

WR 是用户提交的操作请求，硬件将其格式化为 WQE 放入 SQ/RQ。

**WQE 基本结构**：

```
+---------------------------------------------------------------+
|                        WQE (64 bytes typical)                 |
+----------------+----------------------------------------------+
|  Control       |  Opcode, Flags, WQE size, next WQE pointer   |
+----------------+----------------------------------------------+
|  Scatter/Gather|  Local addr, LKey, length (for RECV/READ)    |
|  List (SGL)    |  Local addr, LKey, length (up to 16 entries) |
+----------------+----------------------------------------------+
|  Remote Addr   |  Remote VA, RKey, length (for WRITE/READ)    |
+----------------+----------------------------------------------+
|  UD Header     |  QPN, GRH (for UD operations only)          |
+----------------+----------------------------------------------+
|  Immediate     |  32-bit immediate data (optional)            |
+----------------+----------------------------------------------+
```

### 3.3 Completion Queue Entry (CQE)

CQE 是操作完成的通知，由硬件写入 CQ。

```
+---------------------------------------------------------------+
|                        CQE (16/32/64 bytes)                   |
+----------------+----------------------------------------------+
|  Opcode        |  SEND / RECV / WRITE / READ / error type     |
+----------------+----------------------------------------------+
|  WQE Index     |  指向已完成的 WQE（SQ 或 RQ 中的位置）       |
+----------------+----------------------------------------------+
|  Status        |  成功 / 错误码                               |
+----------------+----------------------------------------------+
|  QP Number     |  源 QPN                                      |
+----------------+----------------------------------------------+
|  Byte Count    |  实际传输字节数                               |
+----------------+----------------------------------------------+
|  Imm. Data     |  32-bit immediate data (if present)          |
+----------------+----------------------------------------------+
|  Flags         |  Solicited, Error, Owner bit                 |
+----------------+----------------------------------------------+
```

**Owner bit**：硬件写 CQE 时置 1，软件消费后清 0 — 硬件通过此位判断 CQ 槽位是否可用。

### 3.4 Memory Region (MR) / Memory Window (MW)

RDMA 操作直接访问远端内存，必须预先注册：

| 概念 | 说明 |
|------|------|
| **Memory Region (MR)** | 应用向 RNIC 注册一段物理连续内存，获得 **LKey (Local Key)** 和 **RKey (Remote Key)** |
| **LKey** | 本地访问凭证，本地 SGL 中引用 |
| **RKey** | 远程访问凭证，远端 WRITE/READ 操作中携带 |
| **Memory Window (MW)** | MR 的子集视图，可动态绑定/解绑，提供更细粒度的权限控制 |
| **权限控制** | Remote Read / Remote Write / Local Write / Atomic |

**IC 设计意义**：RNIC 需要 **Memory Translation / TLB** 硬件，将 WQE 中的虚拟地址（VA）翻译为物理地址（PA），同时验证 Key 的合法性。

### 3.5 Protection Domain (PD)

PD 是访问控制的逻辑容器：

- 所有 QP 和 MR 必须绑定到同一个 PD
- 同一 PD 内的 QP 可以访问该 PD 内的所有 MR
- 不同 PD 之间完全隔离
- 用途：多租户隔离、安全域划分

### 3.6 服务类型

| 服务类型 | 全称 | 可靠性 | 连接模式 | 典型用途 |
|----------|------|--------|----------|----------|
| **RC** | Reliable Connection | 可靠（ACK + 重传） | 连接（1对1） | 大数据传输、存储 |
| **UC** | Unreliable Connection | 不可靠（无重传） | 连接（1对1） | 视频流、实时数据 |
| **UD** | Unreliable Datagram | 不可靠 | 数据包（1对多） | 控制消息、多播 |

**关键差异**：
- RC：支持所有操作（SEND/RECV/WRITE/READ/Atomic），有 PSN 序列号和重传
- UC：支持 SEND/RECV/WRITE（无 READ/Atomic），无重传
- UD：仅支持 SEND/RECV，必须携带 GRH（Global Route Header），消息大小受限于 MTU

---

## 4. RDMA 操作类型

### 4.1 操作分类

| 类别 | 操作 | 发起端 WQE | 响应端 WQE | 说明 |
|------|------|-----------|-----------|------|
| **双边操作** | SEND | SQ: Send WQE | RQ: Recv WQE | 双方都需提交 WQE |
| **双边操作** | RECV | - | RQ: Recv WQE | 被动接收 |
| **单边操作** | WRITE | SQ: Write WQE | **不需要** | 直接写远端内存 |
| **单边操作** | READ | SQ: Read WQE | **不需要** | 直接读远端内存 |
| **单边操作** | Atomic FAA | SQ: Atomic WQE | **不需要** | Fetch-and-Add |
| **单边操作** | Atomic CAS | SQ: Atomic WQE | **不需要** | Compare-and-Swap |

### 4.2 SEND/RECV（双边操作）

**WQE 格式**：

```
=== Send WQE ===
+-----+-----+-----+-----+-----------+-----------+
| Op  |Flag | SGL | ImD | SGL[0]    | SGL[n]    |
+-----+-----+-----+-----+-----------+-----------+
|SEND | inv |addr0|imm | {lkey,len} | {lkey,len}|
|     |     |     |    | (本地数据) | (本地数据) |
+-----+-----+-----+-----+-----------+-----------+

=== Recv WQE ===
+-----+-----+-----+-----------+-----------+
| Op  |Flag | SGL | SGL[0]    | SGL[n]    |
+-----+-----+-----+-----------+-----------+
|RECV | -   |addr0| {lkey,len}| {lkey,len}|
|     |     |     | (接收缓冲) | (接收缓冲) |
+-----+-----+-----+-----------+-----------+
```

**CQE 格式**：

```
=== Send CQE ===
+--------+-------+--------+-----+-------+
|Opcode  |WQE Idx|Status  | QPN |ByteCnt|
+--------+-------+--------+-----+-------+
|SEND    |  i    | success|src  |  len  |
+--------+-------+--------+-----+-------+

=== Recv CQE ===
+--------+-------+--------+-----+-------+--------+
|Opcode  |WQE Idx|Status  | QPN |ByteCnt|Imm Data|
+--------+-------+--------+-----+-------+--------+
|RECV    |  j    | success|peer |  len  |  val   |
+--------+-------+--------+-----+-------+--------+
```

### 4.3 WRITE（单边操作：远程写）

```
=== Write WQE ===
+-----+-----+-----+-----+-----------+----------------+----------------+
| Op  |Flag | SGL | ImD | SGL[0]    | Remote Addr    | RKey           |
+-----+-----+-----+-----+-----------+----------------+----------------+
|WRITE| inv |addr0|imm | {lkey,len} | remote_va=0x...| remote_rkey=.. |
|     |     |     |    | (源数据)  | (远端目标地址)  | (远端访问密钥) |
+-----+-----+-----+-----+-----------+----------------+----------------+
```

- 远端不需要提交任何 WQE
- 硬件将本地数据直接 DMA 写入远端内存
- 可携带 32-bit Immediate Data（接收端产生 CQE 通知）

### 4.4 READ（单边操作：远程读）

```
=== Read WQE ===
+-----+-----+-----+-----------+----------------+----------------+
| Op  |Flag | SGL | SGL[0]    | Remote Addr    | RKey           |
+-----+-----+-----+-----------+----------------+----------------+
|READ | -   |addr0| {lkey,len}| remote_va=0x...| remote_rkey=.. |
|     |     |     | (本地目标)| (远端源地址)    | (远端访问密钥) |
+-----+-----+-----+-----------+----------------+----------------+
```

- 远端硬件响应 READ 请求，返回数据
- 发起端收到数据后产生 CQE

### 4.5 Atomic 操作

| 操作 | 语义 | WQE 额外字段 |
|------|------|-------------|
| **Fetch-and-Add (FAA)** | `old_val = *remote_addr; *remote_addr += add_val` | Add Value (64-bit) |
| **Compare-and-Swap (CAS)** | `if (*remote_addr == compare) then *remote_addr = swap` | Compare Value, Swap Value (各 64-bit) |

- Atomic 操作的远端地址必须 8-byte 对齐
- 操作粒度：64-bit
- 返回值：操作前的旧值

---

## 5. RoCE v2 协议栈

```
+---------------------------------------------------------------+
|                    RoCE v2 Packet Structure                   |
+---------------------------------------------------------------+

+--------+--------+--------+--------+---------+-------+--------+
|  Eth   |  IPv4  |  UDP   |  BTH   | Payload |  ICRC |  FCS   |
| Header | Header | Header |        | (raw)   |       |        |
+--------+--------+--------+--------+---------+-------+--------+
  14B      20B      8B      12B      0~4096B   4B     4B

=== Eth Header (14B) ===
+----------+----------+-------+
| Dst MAC  | Src MAC  |EtherTy|
| 6B       | 6B       | 2B    |
+----------+----------+-------+
                             0x0800 = IPv4

=== IPv4 Header (20B) ===
+----+----+----+-----+----+----+-------+-------+-------+-------+
|Ver |ToS |Len | ID  |Flg |TTL |Proto  |Src IP |Dst IP |Opt   |
| 4b | 8b |16b | 16b |16b | 8b | 8b    | 32b   | 32b   | var  |
+----+----+----+-----+----+----+-------+-------+-------+-------+
                      ECN  UDP=17
                     bits
                DSCP/ECN field:
                [7:2] = DSCP (0x00 or 0x2A for RoCE)
                [1:0] = ECN  (00=NotECT, 01=ECT1, 10=ECT2, 11=CE)

=== UDP Header (8B) ===
+--------+--------+--------+--------+
|Src Port|Dst Port| Length |Checksum|
| 16b    | 16b    |  16b   |  16b   |
+--------+--------+--------+--------+
            4791 = RoCE v2 well-known port

=== BTH (12B) — Base Transport Header ===
+------+-------+-----+----+------+------+----+----+----+
|OpCode|F(m1)  |PSN  | QP#(dst) |Resv|Pad  |Ver |Resv|P_Key|
| 8b   | 1b    | 24b |   24b    | 4b | 2b  | 2b | 2b | 16b |
+------+-------+-----+----------+----+-----+----+----+-----+
  F = Solicited Event (SE)
  m1 = M bit (migration, RC only)

=== ICRC (4B) — Invariant CRC ===
  CRC-32 over invariant fields (excluding variant IP/UDP fields)
```

**各层功能**：

| 层 | 功能 | IC 设计关注 |
|----|------|------------|
| Ethernet | L2 帧传输 | MAC 接口（XGMAC/CGMAC） |
| IPv4 | L3 路由 + ECN 标记 | IP 头解析/生成，ECN bits 检测 |
| UDP | L4 封装/解封装 | 端口 4791，UDP checksum（可选） |
| BTH | RDMA 传输层 | **核心**：OpCode/PSN/QPN 解析，重传状态机 |
| ICRC | 数据完整性校验 | CRC-32 计算（需覆盖不变字段） |

---

## 6. BTH (Base Transport Header) 格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     OpCode    |F|S|M| PadCnt|   TVer  | P_Key                 |
|     (8 bits)  |E|R| |(2 bits)|(2 bits)|   (16 bits)           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Reserved               |         Dest QPN              |
|        (8 bits)               |         (24 bits)             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|A| PktSeqNum (PSN)                                            |
|K|(24 bits)                                                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

字段说明：

OpCode (8 bits):
  0x00 = SEND First          0x01 = SEND Middle
  0x02 = SEND Last           0x03 = SEND Last with Immediate
  0x04 = SEND Only           0x05 = SEND Only with Immediate
  0x06 = RDMA Write First    0x07 = RDMA Write Middle
  0x08 = RDMA Write Last     0x09 = RDMA Write Last with Imm
  0x0A = RDMA Write Only     0x0B = RDMA Write Only with Imm
  0x0C = RDMA Read Request   0x0D = RDMA Read Response First
  0x0E = RDMA Read Response Mid  0x0F = RDMA Read Response Last
  0x10 = RDMA Read Response Only  0x11 = RDMA ACK
  0x12 = Atomic ACK          0x13 = Compare-Swap Req
  0x14 = Fetch-Add Req       0x15 = SEND Last Invalidate
  0x16 = SEND Only Invalidate

SE (Solicited Event, 1 bit):
  1 = 请求接收端产生 CQE 时设置 Solicited Event 标志

M (Migration, 1 bit):
  1 = 支持 CM (Communication Manager) 迁移

PadCnt (2 bits):
  填充字节数（0-3），使数据负载 4-byte 对齐

TVer (2 bits):
  Transport Header Version = 0x0

P_Key (16 bits):
  Partition Key — 用于分区隔离

Dest QPN (24 bits):
  目的 QP Number

AckReq (1 bit, bit 31 of word 3):
  1 = 请求接收端发送 ACK

PSN (24 bits):
  Packet Sequence Number — 用于可靠传输的序列号和重传
```

---

## 7. 可靠连接 (RC) 传输流程

### 7.1 QP 状态机（连接建立）

```
+-------+  Create QP  +-------+  Modify QP  +-------+  Modify QP  +-------+
| RESET | ----------> | INIT  | ----------> |  RTR  | ----------> |  RTS  |
+-------+             +-------+             +-------+             +-------+
    |                    |                    |                      |
    | 初始化QP           | 设置P_Key          | 设置远端QPN          | 设置SQ PSN
    | 分配资源           | 设置端口           | 设置初始PSN          | 开始发送
    |                    | 设置访问权限       | 设置MTU              |
    |                    |                    |                      |
    v                    v                    v                      v
+-------+  Error    +-------+  Close     +-------+  Close      +-------+
| ERROR | <-------- | CLOSE | <--------- | CLOSE | <----------- | CLOSE |
+-------+           +-------+            +-------+             +-------+
```

**状态转移详细说明**：

| 转移 | 前置条件 | 关键操作 |
|------|----------|----------|
| RESET → INIT | QP 已创建 | 设置 P_Key, Port, 访问权限 |
| INIT → RTR | INIT 完成 | 设置 remote QPN, 初始 PSN, MTU, RNR timeout |
| RTR → RTS | 远端 QP 也已到 RTR | 设置 SQ PSN, retry count, timeout |
| * → ERROR | 任意错误 | 清理资源，通知上层 |
| * → CLOSE | 关闭 QP | 释放所有资源 |

### 7.2 SEND/RECV 事务流程

```
+------------------+                                    +------------------+
|     发起端       |                                    |     响应端       |
| (Local RNIC)     |                                    | (Remote RNIC)    |
+------------------+                                    +------------------+
        |                                                        |
        | 1. 用户提交 Send WQE to SQ                             |
        | 2. 用户提交 Recv WQE to RQ  <---- 必须先准备好 Recv WQE
        |                                                        |
        | 3. RNIC 取 Send WQE，组装 packet                        |
        | 4. SEND pkt (OpCode=0x04, PSN=N) ---------------------->| 5. 解析 BTH
        |    BTH: Op=SEND_ONLY, QPN=dst, PSN=N                   | 6. 匹配 QP
        |    Payload: 本地 SGL 指向的数据                          | 7. 查找 RQ WQE
        |                                                        | 8. DMA 数据到 Recv WQE 的 SGL
        |                                                        | 9. 产生 Recv CQE
        |                                                        |
        |<-------------------------- SEND_ACK (OpCode=0x11) -----| 10. 发送 ACK
        |    BTH: Op=ACK, PSN=N, A=1                              |
        | 11. 接收 ACK                                             |
        | 12. 产生 Send CQE                                        |
        |                                                        |
        v                                                        v

=== 时序要求 ===
- Recv WQE 必须在 Send WQE 到达之前就绪（否则 RNR NAK）
- ACK 延迟：typical 1-2 round trips
- PSN 连续递增，接收端检查 PSN 顺序
```

### 7.3 WRITE 事务流程（单边操作）

```
+------------------+                                    +------------------+
|     发起端       |                                    |     响应端       |
+------------------+                                    +------------------+
        |                                                        |
        | 1. 用户提交 Write WQE to SQ                            |
        |    指定: 本地SGL, remote VA, remote RKey, length        |
        |                                                        |
        | 2. RNIC 组装 WRITE packet                               |
        | 3. WRITE pkt (OpCode=0x0A, PSN=N) -------------------->| 4. 解析 BTH + AETH
        |    BTH: Op=WRITE_ONLY, QPN=dst                         | 5. 提取 RKey + Remote VA
        |    RETH: Remote VA, RKey, DMA length                   | 6. Memory Translation: VA→PA
        |    Payload: 本地数据                                    | 7. DMA 写入远端内存
        |                                                        | 8. 发送 ACK
        |<-------------------------- WRITE_ACK (OpCode=0x11) ---| 
        | 9. 产生 Write CQE                                       |
        |                                                        |
        v                                                        v

=== 关键点 ===
- 远端无需提交任何 WQE（单边操作）
- 远端 RNIC 硬件自动完成 DMA 写 + ACK
- 支持 Immediate Data：写完后产生 Recv CQE 通知远端应用
```

### 7.4 READ 事务流程（单边操作）

```
+------------------+                                    +------------------+
|     发起端       |                                    |     响应端       |
+------------------+                                    +------------------+
        |                                                        |
        | 1. 用户提交 Read WQE to SQ                             |
        |    指定: 本地SGL(目标), remote VA, RKey, length         |
        |                                                        |
        | 2. 发送 READ REQUEST                                    |
        | 3. READ_REQ (OpCode=0x0C, PSN=N) -------------------->| 4. 解析 RETH
        |    RETH: Remote VA, RKey, DMA length                   | 5. Memory Translation: VA→PA
        |                                                        | 6. DMA 读取远端内存
        |                                                        | 7. 拆分为多个响应包
        |                                                        |
        |<-- READ_RESP_FIRST (OpCode=0x0D, PSN=M) --------------| 8. 发送数据
        |<-- READ_RESP_MIDDLE (OpCode=0x0E, PSN=M+1) -----------| 
        |    ...                                                  |
        |<-- READ_RESP_LAST (OpCode=0x0F, PSN=M+K) -------------| 
        |                                                        |
        | 9. DMA 到本地 SGL                                       |
        | 10. 产生 Read CQE                                       |
        |                                                        |
        v                                                        v

=== 关键点 ===
- READ 是请求-响应模式，需要多次往返
- 响应端被动处理，无需预提交 WQE
- 数据量大时需拆分为多个 READ_RESP 包
- READ 请求的 PSN 和响应的 PSN 独立计数
```

### 7.5 丢包重传

**PSN (Packet Sequence Number) 机制**：

- 发送端每发一个包，PSN 递增
- 接收端按 PSN 顺序接收
- 发送端收到 ACK 确认已接收的 PSN
- 超时未收到 ACK → 重传

**重传策略**：

```
+---------------------------------------------------------------+
|                    Retransmit State Machine                    |
+---------------------------------------------------------------+

发送端维护:
  - send_psn: 下一个发送包的 PSN
  - ack_psn: 最近收到的 ACK 中确认的 PSN
  - retry_cnt: 当前重试次数
  - retry_max: 最大重试次数 (QP 参数)

超时事件:
  if (timeout && send_psn > ack_psn + 1) {
      if (retry_cnt < retry_max) {
          retry_cnt++;
          resend from (ack_psn + 1);    // Go-Back-N: 重发所有未确认包
      } else {
          transition to QP ERROR;        // 超过最大重试次数
      }
  }

NAK 处理:
  接收端可返回:
  - PSN NAK: 期望的下一个 PSN，告知发送端从哪里重传
  - RNR NAK (Receiver Not Ready): 接收端无 Recv WQE，带超时参数
```

**Go-Back-N vs Selective ACK**：

| 策略 | 说明 | 硬件复杂度 |
|------|------|-----------|
| **Go-Back-N** | 重发所有从 ack_psn+1 开始的包 | 低（标准 IB 默认） |
| **Selective ACK (SACK)** | 只重发丢失的特定包 | 高（需记录每包状态） |

IB 标准使用 Go-Back-N。SACK 作为可选扩展。

---

## 8. 拥塞控制（RoCE v2: ECN-based）

RoCE v2 使用 **ECN (Explicit Congestion Notification)** 实现端到端拥塞控制，机制类似 DCTCP。

```
                      拥塞发生
                         |
  +----------+     +-----+------+     +----------+     +----------+
  | 发送端   | --> | 网络交换机 | --> | 接收端   | --> | 发送端   |
  |          |     | (Congested)|     |          |     |          |
  | 发送数据 |     | 设置 CE bit|     | 检测 CE  |     | 降低速率 |
  | ECT=1    |     | in IP ToS  |     | 在 ACK   |     | 恢复探测 |
  +----------+     +------------+     | 携带 CNP |     +----------+
                                       +----------+

ECN 状态转移:

  发送端:                  交换机:                 接收端:
  ECT(1) ---- pkt ---->  队列深度 > 阈值?
  (ECN Capable)          |                    |
                         | Y: 设置 CE bit     |
                         | ---- pkt+CE ---->  | 检测到 CE:
                         |                    | 发送 CNP
                         |                    | (Congestion
                         | <---- CNP ---------|  Notification
                         |                    |  Packet)
  收到 CNP:              |                    |
  降低 cwnd              |                    |
  (典型: 减半)           |                    |
```

**CNP (Congestion Notification Packet)**：
- 一种特殊的 RoCE v2 包，BTH 中 OpCode = 0x81
- 携带拥塞点的 QPN
- 发送端收到 CNP 后降低发送速率

**IC 设计意义**：
- 发送端需要速率控制状态机（类似 TCP cwnd/ssthresh）
- 需要 ECN bits 检测逻辑（IP header ToS[1:0]）
- CNP 发送/接收处理

---

## 9. PFC (Priority Flow Control)

PFC 是 RoCE 无损网络的基础，基于 IEEE 802.1Qbb。

```
+---------------------------------------------------------------+
|              PFC: Per-Priority Pause Mechanism                |
+---------------------------------------------------------------+

  +-------+    PAUSE     +--------+    PAUSE     +-------+
  | 发送端 | <-- frame -- | 交换机 | <-- frame -- | 接收端 |
  | RNIC  |              |        |              | RNIC  |
  +-------+              +--------+              +-------+

PFC Pause 帧格式 (Ethernet Type = 0x8808):

  +----------+---------+---------------------------+
  | Dst MAC  | Src MAC | EtherType | Pause Params |
  | 01:80:C2 | *       | 0x8808    |              |
  | :00:01:xx|         |           |              |
  +----------+---------+-----------+--------------+
                                  |
                                  v
                         +------------------+
                         | Class Enable Vec |  (2 bytes)
                         | bit[N]=1 表示    |
                         | 优先级 N 需要暂停 |
                         +------------------+
                         | Pause Duration   |  (8 × 2 bytes)
                         | per class (quanta)|
                         +------------------+

  典型配置:
  - Priority 0: 普通 TCP 流量 (不使用 PFC)
  - Priority 3: RoCE 流量 (使用 PFC) — 无损
  - Priority 6: CNP 流量 (高优先级)

PFC 反压流程:

  1. 接收端缓冲区使用量 > XOFF 阈值:
     发送 PFC Pause 帧 (priority=3, quanta=N)

  2. 上游交换机/网卡收到 Pause:
     停止发送 priority=3 的帧
     持续 quanta × 512 bit-time

  3. 缓冲区释放后, 发送 XON (quanta=0):
     恢复发送

  注意: PFC 逐跳生效 (hop-by-hop), 不端到端
```

**PFC Head-of-Line Blocking 问题**：
- 当一个优先级被暂停时，如果物理链路共享，其他优先级也会受影响
- 解决方案：DSCP-based Buffer Partitioning, PFC Watchdog（防止 PAUSE 风暴）

---

## 10. RDMA NIC (RNIC) 硬件架构

```
+=============================================================================+
|                          RNIC (RDMA NIC) Architecture                       |
+=============================================================================+

                    +------------------+
                    |   PCIe Interface |  Gen4 x16 / Gen5 x8
                    |   (RC/EP mode)   |  ~25-32 GB/s
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
    +---------+---------+       +-----------+-----------+
    | Doorbell / BAR    |       | DMA Engine            |
    | Registers         |       | (H2C / C2H)           |
    | (用户态 MMIO)     |       | Scatter-Gather DMA    |
    +---------+---------+       +-----------+-----------+
              |                             |
              +----------+  +---------------+
                         |  |
                    +----+--+----+
                    |    QP       |
                    |  Manager    |
                    | (QP Context |
                    |  State Mgr) |
                    +----+--+----+
                         |  |
              +----------+  +----------+
              |                        |
    +---------+---------+   +----------+---------+
    |   Send Engine     |   |  Receive Engine    |
    |                   |   |                    |
    | - SQ WQE Fetch    |   | - RQ WQE Fetch     |
    | - Packet Assembly |   | - Packet Disassembly|
    | - PSN Management  |   | - PSN Check         |
    | - Retry Logic     |   | - ACK Generation    |
    | - Rate Control    |   | - SGL Scatter       |
    |   (cwnd/pacing)   |   | - BTH/RETH Parse    |
    +---------+---------+   +----------+---------+
              |                        |
              +--------+  +------------+
                       |  |
                  +----+--+----+
                  |  Memory     |
                  | Translation |
                  |  & TLB      |
                  | (VA→PA,     |
                  |  Key Check) |
                  +----+--+----+
                       |  |
              +--------+  +-----------+
              |                       |
    +---------+---------+  +----------+---------+
    | Completion Engine |  |  Packet Buffer     |
    | (CQ Write,        |  |  (Rx FIFO,         |
    |  Interrupt,       |   |   Tx FIFO,         |
    |  Arm/Ci)          |   |   Reassembly Buff) |
    +---------+---------+  +----------+---------+
              |                       |
              +--------+  +------------+
                       |  |
                  +----+--+----+
                  |  Ethernet   |
                  |  MAC        |
                  | 100G/200G/  |
                  | 400G        |
                  +----+--+----+
                       |
                  +----+----+
                  |  QSFP   |
                  |  Port   |
                  +---------+
```

**各子模块功能**：

| 模块 | 功能 | 关键设计点 |
|------|------|-----------|
| **PCIe Interface** | 与 Host CPU 通信 | DMA、MSI-X 中断、BAR 空间映射 |
| **Doorbell / BAR** | 用户态通知硬件 | 64B Doorbell Write，SQ/CQ/Event 钟 |
| **DMA Engine** | Host ↔ NIC 数据搬运 | SG-DMA（Scatter-Gather），支持多不连续物理页 |
| **QP Manager** | QP 上下文管理 | QP Context 缓存（SRAM/TCAM），状态机 |
| **Send Engine** | 发送通路 | WQE 解析、包组装、PSN 管理、重传定时器 |
| **Receive Engine** | 接收通路 | 包解析、PSN 校验、ACK/NAK 生成、数据 Scatter |
| **Memory Translation** | VA → PA 地址翻译 | IOTLB (Translation Lookaside Buffer)，Page Table Walk |
| **Completion Engine** | 完成通知 | CQE 写入、MSI-X 中断触发、CQ Arm 机制 |
| **Packet Buffer** | 包缓冲 | Tx/Rx FIFO，包重组缓冲（multi-packet WRITE/READ） |
| **Ethernet MAC** | 物理层/链路层 | 100G/200G/400G MAC，PFC 处理 |

---

## 11. 设计注意事项（RNIC RTL 设计要点）

### 11.1 WQE DMA

| 设计要点 | 说明 |
|----------|------|
| WQE 格式解析 | WQE 从 Host 内存 DMA 到 NIC，格式由驱动定义（vendor-specific），需严格解析 |
| WQE 大小 | 对齐到 64B (cache line)，最小 64B，最大可达 512B（带 extended SGL） |
| SGL 解析 | Scatter-Gather List 可能跨多个页，需要多次 DMA 请求 |
| 顺序保证 | SQ 中的 WQE 必须按顺序处理，RQ 中 WQE 可以 out-of-order 匹配（UD） |

### 11.2 Doorbell

| 设计要点 | 说明 |
|----------|------|
| Doorbell Write | 用户态通过 PCIe BAR 写入 Doorbell 寄存器，通知硬件有新 WQE |
| Doorbell 格式 | 通常 64-bit：`{QPN[24], WQE_count[16], type[8], ...}` |
| 频率 | 每个 WQE 一次（轻量）或 batch 多个 WQE 后一次（coalescing） |
| 性能关键 | Doorbell → 硬件响应延迟直接影响尾延迟（p99 latency） |

### 11.3 Completion

| 设计要点 | 说明 |
|----------|------|
| CQ Ring Buffer | CQ 是 Host 内存中的环形缓冲，硬件写 CQE，软件 poll 或 interrupt 读取 |
| CQ Arm/Ci | 软件 Arm CQ 后，硬件写入 CQE 触发 MSI-X 中断；软件消费后写 CQ Doorbell 通知硬件 |
| CQ Overflow | CQ 满时硬件不能覆盖未消费的 CQE → QP 进入 ERROR 状态 |
| Polling vs Interrupt | 低延迟场景用 polling（软件不断读 CQ），高吞吐场景用 interrupt |

### 11.4 Memory Translation / TLB

| 设计要点 | 说明 |
|----------|------|
| IOTLB | 缓存 VA→PA 映射，减少 page table walk 延迟 |
| Page Size | 支持 4KB / 2MB / 1GB huge page，大页减少 TLB miss |
| TLB Miss | TLB miss 触发 page table walk（DMA 读 Host 页表），延迟 ~100-200 cycles |
| Key 验证 | 每次 DMA 需验证 LKey/RKey 合法性和访问权限 |
| 缓存一致性 | TLB invalidation（MR dereg 时）需要硬件同步机制 |

### 11.5 SQ/RQ Ring Buffer

| 设计要点 | 说明 |
|----------|------|
| 环形缓冲管理 | Head pointer（硬件消费）和 Tail pointer（软件生产）|
| 满/空判断 | 保留一个槽位区分满/空，或使用额外 bit |
| 预取 | 硬件可预取下一个 WQE 减少延迟 |
| 乒乓缓冲 | WQE DMA 和处理流水化，提高吞吐 |

### 11.6 与 PCIe / AXI 接口

| 设计要点 | 说明 |
|----------|------|
| PCIe EP 模式 | RNIC 作为 PCIe Endpoint，Host 通过 BAR 访问 Doorbell/寄存器 |
| DMA 通道 | 至少需要 2 个独立 DMA 通道：H2C (Host to Card) 和 C2H (Card to Host) |
| MSI-X | 最多支持 2048 个 MSI-X vectors，每个 CQ/Event 可独立中断 |
| AXI 内部总线 | NIC 内部互联建议使用 AXI4，数据通路 AXI4-Stream |
| DMA 对齐 | PCIe DMA 地址和长度需 4B/64B 对齐，跨页需拆分 |
| 引脚约束 | PCIe 参考时钟、复位时序、LTSSM 状态 |

---

## 12. 与 TCP/IP Offload 的对比

| 维度 | RDMA (RNIC) | TCP/IP Offload (TOE/SmartNIC) |
|------|-------------|-------------------------------|
| **目标** | 零延迟、零 CPU 开销 | 减轻 CPU 协议处理负担 |
| **CPU 开销** | ~1-2% (Doorbell + Poll) | ~10-20% (仍有 Socket 层) |
| **延迟** | ~1 μs (p50) | ~10-30 μs (p50) |
| **内存拷贝** | 0 次（零拷贝） | 1-2 次（仍需内核缓冲区） |
| **编程模型** | Verbs API (libibverbs) | 标准 Socket API |
| **连接状态** | 硬件维护 QP 状态 | 硬件维护 TCP 状态（TCB） |
| **重传** | 硬件 PSN + Go-Back-N | 硬件 TCP 重传（更复杂） |
| **拥塞控制** | ECN/CNP (简化) | TCP Cubic/BBR (复杂) |
| **流控** | PFC + Credit | TCP 滑动窗口 |
| **硬件复杂度** | 高（专用数据通路） | 非常高（完整 TCP 栈） |
| **典型用途** | HPC, AI/ML 训练, 存储 | Web 服务器, 通用网络 |
| **生态** | 需应用适配 Verbs API | 透明兼容 Socket 应用 |

**架构师总结**：
- RDMA 硬件设计的核心挑战在于 **低延迟**（每 10ns 都重要）、**Memory Translation**（IOTLB 命中率）、**可靠传输**（PSN/重传状态机）
- TCP Offload 的核心挑战在于 **连接状态管理**（百万级 TCP 连接）、**TCP 状态机复杂度**（拥塞控制、乱序重组）
- 现代 DPU/SmartNIC 趋势：同时支持 RDMA 和 TCP Offload，共享 DMA 和 PCIe 通路

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | InfiniBand Architecture Specification Vol. 1 (IBA 1.4) | IB 协议规范 |
| REF-002 | InfiniBand Architecture Specification Vol. 2 (IBA 1.4) | IB 传输层规范 |
| REF-003 | RoCEv2 Specification (Annex A17, IBTA) | RoCE v2 封装规范 |
| REF-004 | IEEE 802.1Qbb — Priority Flow Control | PFC 规范 |
| REF-005 | RFC 3168 — ECN for IP | ECN 规范 |
| REF-006 | RFC 5045 — iWARP | iWARP 协议栈 |
| REF-007 | DCTCP (SIGCOMM 2010) | ECN 拥塞控制算法 |
