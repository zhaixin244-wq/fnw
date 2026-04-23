# UEC (Ultra Ethernet Consortium) 超级以太网协议知识文档

> **面向**：数字 IC 设计架构师
> **用途**：UEC NIC / 交换芯片 RTL 架构设计参考
> **版本**：v1.0
> **日期**：2026-04-15

---

## 1. 协议概述

**UEC (Ultra Ethernet Consortium)** 是由 AMD、Arista、Broadcom、Cisco、Eviden (Atos)、HPE、Intel、Meta、Microsoft、Oracle 等于 2023 年发起的联盟，目标是制定下一代高性能以太网传输协议，面向 **AI 训练/推理** 和 **HPC** 场景。

**核心定位**：

| 维度 | UEC | 传统以太网 / RoCE v2 |
|------|-----|---------------------|
| 目标负载 | AI/HPC（大模型训练、科学计算） | 通用数据中心 |
| 设计重点 | 延迟、吞吐、多路径、大规模集群 | 兼容性、通用性 |
| 传输层 | 全新 UEC Transport（L3.5/L4 增强） | UDP + IB BTH (RoCE v2) |
| 标准状态 | UEC 1.0 规范（持续演进中） | 成熟标准 |

**UEC 1.0 关键目标**：

- 端到端延迟 < 5μs（同 rack）
- 支持 100K+ GPU 规模集群
- 线速带宽利用率 > 95%
- 完全兼容以太网物理层（无需专有 fabric）

---

## 2. UEC 与传统以太网的关系

### 2.1 分层关系

UEC **不替代以太网**，而是在以太网 L1/L2 之上构建增强传输层：

```
+---------------------------+
|    Application (MPI/RDMA) |
+---------------------------+
|    UEC Transport Layer    |  ← UEC 核心创新层
+---------------------------+
|    UDP / IP (可选封装)     |
+---------------------------+
|    Ethernet L2 (MAC)      |  ← 复用标准以太网
+---------------------------+
|    Ethernet L1 (PHY)      |  ← 复用标准以太网
+---------------------------+
```

### 2.2 继承与增强

| 继承自以太网 | UEC 增强 |
|-------------|---------|
| 物理层（100G/200G/400G/800G SerDes） | 无改动，直接复用 |
| MAC 层帧格式（Ethernet II） | 无改动，EtherType 新分配 |
| L2 交换（VLAN、ECMP 基础） | 增强：多路径 Packet Spraying |
| L3 IP 路由（可选） | 增强：自定义传输头 |
| L4 UDP 封装（RoCE v2 的方式） | **替换为 UEC Transport Header** |
| ECN 拥塞标记 | 增强：快速反馈 + 自适应速率 |
| PFC 流控 | 补充：端到端 Credit-Based 流控 |

---

## 3. UEC 核心特性

### 3.1 多路径传输 (Multi-Path / Packet Spraying)

**问题**：传统 ECMP 基于 5 元组哈希，同一流的所有包走同一条路径，导致：
- 胖树链路利用率不均（哈希冲突）
- 单路径带宽瓶颈
- 故障切换慢

**UEC 方案**：Packet Spraying（数据包喷洒）
- 同一数据流的包可以分布在多条等价路径上
- 接收端处理乱序到达
- 显著提升链路利用率（从 ~60% 提升至 >90%）

**IC 设计影响**：
- 发送端：需要多路径选择逻辑（per-packet 而非 per-flow）
- 接收端：需要乱序重组缓冲（Reorder Buffer）
- 交换机：需要支持 per-packet 负载均衡

### 3.2 可靠传输层 (Reliable Transport)

**两种可靠模式**：

| 模式 | 机制 | 适用场景 | 延迟 |
|------|------|----------|------|
| **Credit-Based** | 发送前获取 credit，保证不丢包 | AI 训练（AllReduce） | 最低 |
| **ACK-Based** | 接收端 ACK 确认，丢包重传 | 通用可靠传输 | 稍高 |

**Credit-Based Flow Control（核心）**：
- 接收端预先分配 credit（发送窗口）给发送端
- 发送端仅在有 credit 时发送
- 每发送一个包消耗 credit，收到 ACK 后释放 credit
- 避免丢包，无需重传

**IC 设计影响**：
- 需要 per-connection credit 计数器
- Credit 发放/回收的状态机
- 发送窗口管理逻辑

### 3.3 拥塞控制 (Congestion Control)

**三阶段机制**：

```
发送端                网络/交换机              接收端
  |                      |                      |
  |--- 数据包 --------->|                      |
  |                      | (ECN 标记)           |
  |                      |--- 数据包 --------->|
  |                      |                      |
  |<--- ACK + RTT反馈 --|<--- ACK ------------|
  |                      |                      |
  | (调整发送速率)        |                      |
```

| 阶段 | 机制 | 说明 |
|------|------|------|
| **检测** | ECN 标记 | 交换机队列超阈值时，标记 CE bit |
| **反馈** | RTT 测量 | 端到端精确延迟测量 |
| **响应** | 自适应速率 | 发送端根据 ECN + RTT 调整速率 |

**与 DCTCP 的区别**：
- UEC 拥塞控制更快收敛（亚 RTT 级别响应）
- 支持 per-packet 精度的速率调整
- 针对 AI 流量模式优化（burst + 同步）

### 3.4 原子操作支持 (Atomic Operations)

UEC 支持远程内存原子操作，无需目标 CPU 介入：

| 操作 | 描述 | 应用场景 |
|------|------|----------|
| Compare-and-Swap (CAS) | 比较并交换 | 锁实现、无锁数据结构 |
| Fetch-and-Add (FAA) | 原子加 | 计数器、队列尾指针 |
| Fetch-and-AND/OR | 原子位操作 | 标志位管理 |

**IC 设计影响**：
- NIC 需要 Atomic Operation Engine（AOE）
- 需要 PCIe 原子操作支持或 NIC 内部缓存一致性
- 操作的顺序性和幂等性保证

### 3.5 安全 (Security)

| 安全层 | 协议 | 说明 |
|--------|------|------|
| **L2 安全** | MACsec (IEEE 802.1AE) | 逐跳链路加密，GCM-AES-128/256 |
| **L3 安全** | IPsec (可选) | 端到端加密 |
| **UEC 内建** | 内建认证 + 加密 | 轻量级，针对 HPC 优化 |

**IC 设计影响**：
- MACsec 引擎（GCM-AES 流水线）
- Key 分发和管理（SAK 管理）
- 加密不影响线速（需硬件加速）

---

## 4. 协议栈层次

```
+==========================================+
|         Application Layer                |
|   (MPI / RDMA verbs / UCX / NCCL)        |
+==========================================+
|         UEC Transport Layer              |  ← UEC 核心
|   - Reliable delivery (Credit/ACK)      |
|   - Multi-path routing                  |
|   - Congestion control                  |
|   - Atomic operations                   |
|   - Ordering & reassembly               |
+==========================================+
|         UEC Packet Header               |  ← 自定义传输头
|   - Flow ID, Sequence Number            |
|   - Path ID, Credit info                |
|   - Opcode, Flags                       |
+==========================================+
|         UDP / IP (可选)                   |  ← L3 封装（跨子网时）
|         Ethernet EtherType              |  ← L2 封装
+==========================================+
|         Ethernet MAC (IEEE 802.3)        |  ← 复用
+==========================================+
|         Ethernet PHY (100G~800G)         |  ← 复用
+==========================================+
```

**两种封装模式**：

| 模式 | 封装结构 | 适用场景 |
|------|----------|----------|
| **L2 模式** | Eth → UEC Header → Payload | 同子网（rack 内） |
| **L3 模式** | Eth → IP → UDP → UEC Header → Payload | 跨子网（数据中心级） |

---

## 5. UEC 传输层包格式

### 5.1 L2 模式包格式

```
+----------+----------+--------+------------------+-----------------+-----+
|    DA    |    SA    |EtherType=  |  UEC Transport  |    Payload     | FCS |
|  6 bytes |  6 bytes | 0xUEC      |     Header      |                | 4 B |
+----------+----------+--------+------------------+-----------------+-----+
```

### 5.2 L3 (UDP) 模式包格式

```
+------+-----+-----+------+----------------+------------------+-----+
| DA/SA| VLAN|Ether|  IP  |      UDP       | UEC Trans Header | FCS |
| 12 B |opt. |type |Header|   8 bytes      |    (variable)    | 4 B |
+------+-----+-----+------+----------------+------------------+-----+
                      |<-- 可选跨子网封装 -->|<--- UEC 核心 --->|
```

### 5.3 UEC Transport Header 详细格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|    Opcode     |     Flags     |         Flow ID (16-bit)      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      Sequence Number (32-bit)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|    Path ID    |   Credit Cnt  |       Reserved        | C | A |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      Payload Length (16-bit)   |   Checksum    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Opcode (8-bit):
  0x00 = DATA          - 普通数据包
  0x01 = ACK           - 确认包
  0x02 = NAK           - 否定确认（丢包指示）
  0x03 = CREDIT_GRANT  - Credit 发放
  0x04 = CREDIT_RETURN - Credit 回收
  0x10 = ATOMIC_CAS    - 原子 Compare-and-Swap
  0x11 = ATOMIC_FAA    - 原子 Fetch-and-Add
  0x20 = RNR_NAK       - Receiver-Not-Ready NAK
  0xFE = CONTROL       - 控制/管理包
  0xFF = ERROR         - 错误包

Flags (8-bit):
  bit 0: FIRST_PKT    - 事务首包
  bit 1: LAST_PKT     - 事务末包
  bit 2: ECN_MARKED   - ECN 标记
  bit 3: SECURITY_EN  - 安全使能
  bit 4: ATOMIC_REQ   - 原子操作请求
  bit 5: MULTI_DEST   - 多播/组播
  bit 6: RETRANSMIT   - 重传包
  bit 7: RESERVED

C (2-bit): Credit 管理标志
  00 = 无 credit 信息
  01 = 携带 credit grant
  10 = 携带 credit return
  11 = reserved

A (1-bit): ACK 请求标志
```

---

## 6. 多路径机制 (Packet Spraying)

### 6.1 原理

```
                  +-- Path 0 (Hash=0x00) --+
                  |                        |
Sender ---------> +-- Path 1 (Hash=0x01) --+ ---------> Receiver
  (Tx)            |                        |             (Rx)
                  +-- Path 2 (Hash=0x02) --+
                  |                        |
                  +-- Path 3 (Hash=0x03) --+

包 0: Seq=0, Path=0 ───── Path 0 ─────> 到达，Seq=0
包 1: Seq=1, Path=2 ───── Path 2 ─────> 到达，Seq=1（乱序）
包 2: Seq=2, Path=1 ───── Path 1 ─────> 到达，Seq=2
包 3: Seq=3, Path=3 ───── Path 3 ─────> 到达，Seq=3
包 4: Seq=4, Path=0 ───── Path 0 ─────> 到达，Seq=4

接收端 Reorder Buffer 按 Seq 重排序后递交上层
```

### 6.2 路径选择策略

| 策略 | 描述 | 负载均衡效果 | 复杂度 |
|------|------|-------------|--------|
| **轮询 (Round-Robin)** | 依次分配到各路径 | 均匀 | 低 |
| **哈希 (Hash-based)** | 基于 FlowID + Seq 哈希 | 较均匀 | 中 |
| **权重 (Weighted)** | 根据路径拥塞程度分配权重 | 自适应 | 高 |
| **ECMP + Spraying** | ECMP 分流组内再 spray | 最佳 | 高 |

**UEC 推荐**：Hash-based per-packet spraying，配合拥塞反馈动态调整路径权重。

### 6.3 乱序处理

**接收端 Reorder Buffer（ROB）**：

```
收到 Seq=0 → 递交 Seq=0（连续）
收到 Seq=2 → 存入 ROB[2]，等待 Seq=1
收到 Seq=1 → 存入 ROB[1]，发现 0,1,2 连续 → 递交 Seq=0,1,2
收到 Seq=3 → 递交 Seq=3（连续）
```

**IC 设计影响**：

| 设计要点 | 说明 |
|----------|------|
| ROB 深度 | 取决于最大乱序程度（路径数 × 延迟差） |
| ROB 结构 | CAM + Data Buffer 或 Ring Buffer + Bitmap |
| 递交逻辑 | 连续检测 + 批量递交 |
| 内存带宽 | ROB 需双端口（写入 + 递交读出） |

---

## 7. 可靠传输 (Credit-Based Flow Control)

### 7.1 工作流程

```
Sender                                    Receiver
  |                                         |
  |  1. 连接建立时，Receiver 发放 Credit     |
  |<------- CREDIT_GRANT (credits=16) ------|
  |                                         |
  |  2. Sender 在 Credit 范围内发送          |
  |-------- DATA (Seq=0, Credit Cnt=15) -->|
  |-------- DATA (Seq=1, Credit Cnt=14) -->|
  |-------- DATA (Seq=2, Credit Cnt=13) -->|
  |                                         |
  |  3. Receiver 处理完毕，回 ACK + 释放     |
  |<------- ACK (Seq=0, Credit+=1) ---------|
  |                                         |
  |  4. Sender 收到 ACK，Credit 恢复         |
  |-------- DATA (Seq=3, Credit Cnt=14) -->|
  |                                         |
  |  5. Credit 为 0 时，Sender 停止发送      |
  |    等待 Receiver 释放 Credit             |
```

### 7.2 Credit 管理状态机

```
+---------+  grant   +----------+  发送成功  +----------+
|  CLOSED | -------> |  OPEN    | --------> |  OPEN    |
|         |          | credit=N |  credit-- | credit=N-1|
+---------+          +----------+           +----------+
     ^                    |                      |
     |                    | ACK 到达             | ACK 到达
     |                    | credit++             | credit++
     |                    v                      v
     |              +----------+           +----------+
     +-------------|  OPEN    |           |  OPEN    |
     (credit=0,    |credit=N+1|           |credit=N  |
      发送停止)     +----------+           +----------+
```

### 7.3 丢包恢复

| 场景 | 检测方式 | 恢复机制 |
|------|----------|----------|
| 数据包丢失 | Seq gap（接收端） | NAK → 发送端重传 |
| ACK 丢失 | 超时（发送端） | 超时重传 |
| Credit 包丢失 | 超时 | 重发 Credit 请求 |

**超时计算**：基于 RTT 测量，`Timeout = RTT × 2 + margin`

---

## 8. 拥塞控制

### 8.1 ECN + RTT 反馈机制

```
+-----------+      +-----------+      +-----------+
|  Sender   | ---> |  Switch   | ---> | Receiver  |
|           |      | (队列深度 |      |           |
| 发送速率  |      |  超阈值)  |      |           |
| Rate=N    |      | ECN 标记  |      | 回传 ACK  |
+-----------+      +-----------+      +-----------+
      ^                                    |
      |         ACK 携带 ECN 反馈           |
      +------------------------------------+
      |
      | 根据 ECN 比例调整速率：
      |   ECN_ratio > 0.1 → 降速 10%
      |   ECN_ratio < 0.01 → 升速 5%
      |   其他 → 保持
      v
  调整后 Rate = N'（自适应）
```

### 8.2 拥塞控制参数

| 参数 | 典型值 | 说明 |
|------|--------|------|
| ECN 阈值 | 队列深度 > 50% 容量 | 交换机标记 CE bit |
| 目标延迟 | ≤ RTT_base × 1.2 | 可接受的延迟增长 |
| 降速因子 | ×0.9 | 收到 ECN 后降速比例 |
| 升速因子 | ×1.05 | 无 ECN 时升速比例 |
| 最小速率 | Line Rate × 0.1 | 最低发送速率保底 |
| 反馈周期 | 1~4 RTT | 速率调整决策周期 |

### 8.3 与传统方案对比

| 特性 | DCTCP (RoCE v2) | UEC Congestion Control |
|------|-----------------|----------------------|
| 标记方式 | ECN (IP header) | ECN + 内建反馈 |
| 反应速度 | ~1 RTT | 亚 RTT |
| 收敛时间 | 较慢 | 快速（针对 burst 流量优化） |
| 多路径感知 | 无 | 有（路径级拥塞信息） |
| AI 流量优化 | 无 | 针对 AllReduce burst 模式 |

---

## 9. 与 RoCE v2 的对比

| 维度 | RoCE v2 | UEC 1.0 |
|------|---------|---------|
| **底层** | Ethernet + UDP + IB BTH | Ethernet + UEC Transport Header |
| **传输层** | IB Transport（UDP 封装） | 全新 UEC Transport |
| **多路径** | ECMP（per-flow 哈希，同流同路径） | Packet Spraying（per-packet，多路径） |
| **乱序处理** | 不支持（有序 fabric 假设） | 原生支持（Reorder Buffer） |
| **可靠传输** | RC/UC 模式（基于 ACK/重传） | Credit-Based + ACK（双模式） |
| **拥塞控制** | ECN + DCTCP（单阶段） | ECN + RTT + 自适应（多阶段） |
| **延迟** | ~1-2μs（同 rack） | <1μs（目标，同 rack） |
| **原子操作** | IB 原子操作（FAA/CAS） | 内建原子操作 |
| **安全** | 无内建（依赖 MACsec 可选） | 内建 MACsec/IPsec |
| **规模化** | 数千节点（ECMP 哈希冲突） | 100K+ 节点（多路径优化） |
| **兼容性** | 复用 UDP 端口 4791 | 新 EtherType / UDP 端口 |
| **生态** | 成熟（Mellanox/NVIDIA） | 新兴（联盟标准化中） |
| **交换机要求** | 标准 ECMP | 需支持 per-packet spray |
| **NIC 复杂度** | 中等 | 较高（乱序重组 + credit） |

---

## 10. 与 InfiniBand 的对比

| 维度 | InfiniBand (IB) | UEC 1.0 |
|------|-----------------|---------|
| **底层** | 专用 IB fabric（非以太网） | 标准以太网 PHY + MAC |
| **交换** | IB 交换机（专用） | 以太网交换机（通用） |
| **传输层** | IB Transport（内置可靠/不可靠） | UEC Transport |
| **流控** | Credit-based（链路级） | Credit-based（端到端）+ PFC（可选） |
| **拥塞控制** | 内建 credit（不拥塞） | ECN + RTT 自适应 |
| **多路径** | 有限（LID 路由） | Packet Spraying（原生） |
| **跨子网** | IB Router | 标准 IP 路由 |
| **部署成本** | 高（专用设备） | 低（复用以太网基础设施） |
| **带宽** | HDR (200G) / NDR (400G) | 100G ~ 800G（以太网速率） |
| **延迟** | ~0.5μs（IB Switch） | <1μs（目标） |
| **生态** | NVIDIA (Mellanox) 独占 | 多厂商开放联盟 |
| **RDMA 支持** | 原生 | 通过 UEC Transport 承载 RDMA |
| **线缆/连接器** | 专用 IB 线缆 | 标准以太网线缆（DAC/AOC/光模块） |
| **故障域** | IB fabric 独立故障域 | 与以太网共享故障域 |

---

## 11. RDMA over UEC

### 11.1 承载方式

UEC Transport 层原生支持 RDMA 操作语义，通过 UEC Transport Header 的 Opcode 字段指示操作类型：

| RDMA 操作 | UEC Opcode | 说明 |
|-----------|-----------|------|
| SEND | DATA (Flags: FIRST/LAST) | 发送数据到远端 Receive Queue |
| WRITE | DATA (Flags: FIRST/LAST) | 直接写入远端内存 |
| READ | DATA + Response | 远端数据拉取 |
| ATOMIC_CAS | ATOMIC_CAS | 原子比较并交换 |
| ATOMIC_FAA | ATOMIC_FAA | 原子加 |

### 11.2 与传统 RDMA over RoCE v2 的区别

```
传统 RDMA over RoCE v2:
  Application (MPI/Verbs)
       ↓
  RDMA Transport (RC/UC/UD)
       ↓
  IB BTH Header (嵌入 UDP payload)
       ↓
  UDP → IP → Ethernet

RDMA over UEC:
  Application (MPI/Verbs / NCCL)
       ↓
  RDMA Operations (语义层)
       ↓
  UEC Transport (Credit + Multi-path + CC)
       ↓
  UEC Header (+ 可选 UDP/IP 封装)
       ↓
  Ethernet
```

**关键区别**：

| 对比点 | RDMA over RoCE v2 | RDMA over UEC |
|--------|-------------------|---------------|
| 传输可靠性 | RC (ACK+重传) / UC (不可靠) | Credit-Based（不丢包）+ ACK 备选 |
| 多路径 | 无（ECMP per-flow） | Packet Spraying |
| 拥塞控制 | DCTCP/DCQCN | UEC 多阶段自适应 |
| 乱序容忍 | 不支持（需有序递交） | 原生支持（硬件重组） |
| QP 状态 | 复杂（SQ/RQ/CQ/状态机） | 简化（credit 管理替代复杂重传） |

---

## 12. NIC 硬件设计注意事项

### 12.1 关键子模块

```
+==========================================================+
|                     UEC NIC 架构                         |
|                                                          |
|  +------------+   +------------+   +----------------+   |
|  | PCIe DMA   |   | Doorbell   |   | Queue Manager  |   |
|  | Engine     |   | Processing |   | (SQ/RQ/CQ)     |   |
|  +-----+------+   +-----+------+   +-------+--------+   |
|        |                |                  |             |
|        v                v                  v             |
|  +===================================================+  |
|  |              UEC Transport Engine                  |  |
|  |                                                    |  |
|  |  +------------------+  +------------------------+ |  |
|  |  | Multi-Path       |  | Credit Manager         | |  |
|  |  | Hash & Select    |  | (per-conn credit reg)  | |  |
|  |  +------------------+  +------------------------+ |  |
|  |                                                    |  |
|  |  +------------------+  +------------------------+ |  |
|  |  | Congestion       |  | Sequence Number        | |  |
|  |  | Control Engine   |  | Manager                | |  |
|  |  +------------------+  +------------------------+ |  |
|  |                                                    |  |
|  |  +------------------+  +------------------------+ |  |
|  |  | Reorder Buffer   |  | Atomic Operation       | |  |
|  |  | (ROB)            |  | Engine (AOE)           | |  |
|  |  +------------------+  +------------------------+ |  |
|  +===================================================+  |
|        |                                        |       |
|        v                                        v       |
|  +------------+                          +-----------+  |
|  | TX MAC     |                          | RX MAC    |  |
|  | + Encap    |                          | + Decap   |  |
|  +------------+                          +-----------+  |
|        |                                        |       |
|        v                                        v       |
|  +===================================================+  |
|  |              Ethernet MAC + PHY                    |  |
|  +===================================================+  |
+==========================================================+
```

### 12.2 各子模块设计要点

#### 12.2.1 多路径哈希引擎

| 设计要点 | 说明 |
|----------|------|
| 哈希输入 | FlowID + Sequence Number |
| 哈希输出 | Path ID (0 ~ N-1) |
| 哈希算法 | CRC32 / Toeplitz（与 ECMP 兼容） |
| 路径数量 | 参数化（2/4/8/16 路径） |
| 拥塞感知 | 根据各路径拥塞反馈调整权重（可选） |

#### 12.2.2 乱序重组缓冲 (ROB)

| 设计要点 | 说明 |
|----------|------|
| ROB 深度 | `MAX_PATHS × (MAX_DELAY_DIFF / MIN_PKT_TIME)` |
| 典型值 | 64~256 entries（视路径延迟差） |
| 数据结构 | Seq Bitmap + Data Buffer（SRAM 或寄存器堆） |
| 递交检测 | 每收到包后检查连续 seq 范围 |
| 性能关键 | 需要单周期查找到达的连续区间 |

#### 12.2.3 Credit 管理器

| 设计要点 | 说明 |
|----------|------|
| Credit 宽度 | 16-bit（最大 65535 个未完成包） |
| Per-connection | 每个连接独立 credit 计数器 |
| Credit 发放 | 接收端根据缓冲区可用空间计算 |
| Credit 更新 | ACK 包携带 credit 回收信息 |
| 下溢保护 | credit=0 时强制停止发送 |

#### 12.2.4 拥塞控制引擎

| 设计要点 | 说明 |
|----------|------|
| RTT 测量 | 硬件时间戳（ns 精度） |
| ECN 计数 | 统计窗口内 ECN 标记比例 |
| 速率计算 | 硬件乘除法（或查找表近似） |
| 更新周期 | 每 1~4 RTT 更新一次发送速率 |
| 实现方式 | 定时器中断 或 轮询寄存器 |

#### 12.2.5 安全引擎 (MACsec)

| 设计要点 | 说明 |
|----------|------|
| 加密算法 | GCM-AES-128/256 |
| 流水线 | 4~8 级流水线（满足线速） |
| Key 管理 | SAK (Secure Association Key) 轮转 |
| 旁路模式 | 非加密流量不经过 MACsec 引擎 |
| 面积预算 | ~50-100 kGates（GCM-AES 引擎） |

### 12.3 关键时序路径

| 路径 | 描述 | 优化策略 |
|------|------|----------|
| TX: WQE 解析 → Header 生成 → MAC 发送 | 发送数据通路 | 流水线分级 |
| RX: MAC 接收 → Header 解析 → ROB 写入 | 接收数据通路 | 并行解码 |
| RX: ROB 连续检测 → DMA 写入主机内存 | 递交路径 | 预计算连续窗口 |
| Credit 更新路径 | ACK → Credit 算术 → 发送使能 | 单周期完成 |
| 拥塞控制路径 | ECN 计数 → 速率计算 → 限速 | 定时更新（非关键路径） |

---

## 13. AI/HPC 场景需求分析

### 13.1 典型 AI 通信模式

#### AllReduce（梯度同步）

```
GPU 0 ──── 梯度数据 ────> ─┐
GPU 1 ──── 梯度数据 ────> ─┤──> 归约节点 ──> 广播结果 ──> 所有 GPU
GPU 2 ──── 梯度数据 ────> ─┤
GPU 3 ──── 梯度数据 ────> ─┘

特点：
- 通信量大（GB 级梯度数据）
- 同步屏障（所有 GPU 必须完成才能继续）
- 对延迟敏感（直接影响训练迭代时间）
```

**网络需求**：

| 需求 | 严重度 | UEC 如何满足 |
|------|--------|-------------|
| 高带宽 | Critical | 利用多路径聚合带宽 |
| 低尾延迟 | Critical | 拥塞控制避免队头阻塞 |
| 可靠交付 | High | Credit-Based（不丢包） |
| 大规模扩展 | High | 多路径减少 ECMP 冲突 |

#### AllGather（参数广播）

```
All-Gather: 每个 GPU 持有部分数据，最终所有 GPU 获得完整数据

GPU 0: [P0] ──> 所有 GPU 获得 [P0, P1, P2, P3]
GPU 1: [P1] ──> 同上
GPU 2: [P2] ──> 同上
GPU 3: [P3] ──> 同上

特点：
- 多对多通信
- 带宽受限（数据量随 GPU 数线性增长）
```

#### Reduce-Scatter

```
Reduce-Scatter: 归约后分散，每个 GPU 获得部分归约结果

特点：
- 通信模式为 AllReduce 的一半
- 类似 AllGather 的流量模式
```

### 13.2 GPU 集群对网络的要求

| 要求 | 描述 | UEC 机制 |
|------|------|----------|
| **线速带宽** | GPU 算力增长快于网络带宽，网络不能成为瓶颈 | 多路径聚合，接近线速 |
| **微秒级延迟** | 小消息同步（如 barrier）对延迟极敏感 | Credit 流控 + 低延迟封装 |
| **百万级 GPU** | 大模型训练需 10K~100K+ GPU | 多路径消除哈希冲突 |
| **高链路利用率** | 昂贵的网络基础设施不能闲置 | Packet Spraying >90% 利用率 |
| **快速故障恢复** | GPU/链路故障需快速重路由 | 多路径天然冗余 |
| **无损网络** | 丢包重传代价极高 | Credit-Based Flow Control |

### 13.3 UEC 对 AI 流量的优化

| 优化点 | 说明 |
|--------|------|
| **突发流量容忍** | AI 训练产生 burst 模式流量（梯度同步瞬间），UEC credit 机制预留缓冲空间 |
| **同步屏障优化** | 小消息（barrier/通知）使用高优先级路径，减少同步等待 |
| **多租户隔离** | 不同训练任务使用不同 FlowID，拥塞控制 per-flow 隔离 |
| **自适应路径** | 根据实时拥塞程度调整流量分配，而非静态 ECMP |
| **硬件归约卸载** | 部分实现支持 NIC 侧梯度归约（硬件 reduce），减少 GPU 通信量 |

---

## 附录 A. 缩略语

| 缩写 | 全称 |
|------|------|
| UEC | Ultra Ethernet Consortium |
| ECMP | Equal-Cost Multi-Path |
| ECN | Explicit Congestion Notification |
| ROB | Reorder Buffer |
| PFC | Priority-based Flow Control |
| MACsec | Media Access Control Security |
| NIC | Network Interface Card |
| QP | Queue Pair |
| SQ/RQ/CQ | Send/Receive/Completion Queue |
| WQE | Work Queue Entry |
| CQE | Completion Queue Entry |
| RDMA | Remote Direct Memory Access |
| HPC | High Performance Computing |
| AI | Artificial Intelligence |
| NCCL | NVIDIA Collective Communications Library |
| MPI | Message Passing Interface |
| DCTCP | Data Center TCP |
| DCQCN | Data Center Quantized Congestion Notification |
| AOE | Atomic Operation Engine |
| CRC | Cyclic Redundancy Check |
| GCM | Galois/Counter Mode |
| AES | Advanced Encryption Standard |
| SAK | Secure Association Key |
| CAS | Compare-and-Swap |
| FAA | Fetch-and-Add |

## 附录 B. 参考资料

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | UEC 1.0 Specification (ultraethernet.org) | UEC 官方规范 |
| REF-002 | IEEE 802.3 Ethernet Standard | 以太网基础标准 |
| REF-003 | IEEE 802.1AE MACsec | 链路层安全标准 |
| REF-004 | RFC 3168 - ECN | 显式拥塞通知 |
| REF-005 | InfiniBand Architecture Specification | IB 参考（对比） |
| REF-006 | RoCE v2 (Annex A17, IBTA) | RoCE v2 参考（对比） |
