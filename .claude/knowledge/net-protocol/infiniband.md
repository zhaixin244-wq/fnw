# InfiniBand 协议知识文档

> **面向**：数字 IC 设计架构师
> **用途**：HCA (Host Channel Adapter)、IB 交换芯片等设计参考
> **日期**：2026-04-15

---

## 1. 协议概述

InfiniBand（IB）是由 **InfiniBand Trade Association (IBTA)** 制定的高性能互联标准，面向数据中心和 HPC 场景。

**核心特征**：

- **RDMA 原生**：零拷贝、内核旁路（Kernel Bypass）的数据传输
- **低延迟**：IB 端口到端口延迟 < 100ns（交换机跳数），HCA 到 HCA 延迟 < 1us（单节点）
- **高带宽**：单端口最高 400Gbps（XDR 4x）
- **无损网络**：Credit-Based 流控，链路级重传，零丢包
- **高可靠**：传输层硬件重传（RC 服务类型），端到端 ACK
- **CPU 卸载**：所有协议处理在 HCA 硬件完成，CPU 不参与数据搬运

**应用场景**：

- HPC 集群互联（TOP500 超算中占比 > 70%）
- AI/ML 训练集群（GPU 间高速互联）
- 分布式存储后端网络
- 高频交易（超低延迟需求）

---

## 2. InfiniBand 架构

### 2.1 子网拓扑

InfiniBand 网络由一个或多个 **子网（Subnet）** 组成，子网间通过 **路由器（Router）** 互联。

```
                        +-------------------+
                        |   Subnet Manager   |
                        |       (SM)         |
                        +--------+----------+
                                 | (管理通路)
                                 v
+----------+    1x/4x/12x   +--------+    1x/4x/12x   +----------+
|  HCA     +--------------->+ Switch +<--------------+  HCA     |
| (Node A) |                |        |                | (Node B) |
+----------+                +---+----+                +----------+
                                | (级联)
                                v
+----------+    1x/4x/12x   +--------+    1x/4x/12x   +----------+
|  HCA     +--------------->+ Switch +<--------------+  HCA     |
| (Node C) |                |        |                | (Node D) |
+----------+                +---+----+                +----------+
                                |
                                v
                           +----------+
                           |  Router  +------->  其他子网
                           +----------+
```

**架构要素**：

| 组件 | 说明 |
|------|------|
| **HCA** (Host Channel Adapter) | 端节点适配器，连接主机 PCIe 总线，实现 QP、RDMA 操作 |
| **Switch** | 子网内数据交换，基于 LID 路由，线速转发 |
| **Router** | 子网间路由，基于 GID 路由，跨子网寻址 |
| **SM** (Subnet Manager) | 子网管理器，发现拓扑、分配 LID、配置路由表、管理 QoS |
| **Subnet** | 由 SM 管理的单个广播域，内部用 LID 寻址 |

### 2.2 端口与链路

- 每个物理端口支持 **1x / 4x / 12x** 通道（lane）配置
- 每个 lane 独立串行收发，带宽随 lane 数线性叠加
- 链路支持信号均衡和 FEC（前向纠错，HDR 及以上强制）

---

## 3. 协议栈层次

```
+==========================================+
|         Upper Layer Protocols            |
|  (SDP / SRP / iSER / IPoIB / DAPL / MPI) |
+==========================================+
|         Transport Layer                  |
|  Queue Pair (QP) / RC / UC / UD / RD / XRC |
|  BTH / DETH / Atomic / RDMA Op           |
+==========================================+
|         Network Layer                    |
|  GRH (Global Route Header) / GID / LID   |
+==========================================+
|         Link Layer                       |
|  LRH (Local Route Header) / VL / Credit  |
|  Link-Level Retry / VL Arbitration       |
+==========================================+
|         Physical Layer                   |
|  SerDes / 64b/66b Encoding / FEC         |
|  SDR → DDR → QDR → FDR → EDR → HDR → NDR → XDR |
+==========================================+
```

| 层次 | 功能 | 关键头部 |
|------|------|----------|
| **Physical** | 电信号编码、SerDes、FEC | - |
| **Link** | 包交换、VL 路由、信用流控、链路重传 | LRH |
| **Network** | 子网内/子网间寻址与路由 | GRH（跨子网时） |
| **Transport** | QP 管理、RDMA 操作、可靠传输 | BTH, DETH |
| **Upper** | 应用协议封装 | - |

---

## 4. 速率演进

| 代次 | 名称 | 单 lane 速率 | 编码 | 4x 带宽 | 年份 |
|------|------|-------------|------|---------|------|
| Gen 1 | SDR | 2.5 Gbps | 8b/10b | 8 Gbps | 2001 |
| Gen 2 | DDR | 5.0 Gbps | 8b/10b | 16 Gbps | 2004 |
| Gen 3 | QDR | 10.0 Gbps | 8b/10b | 32 Gbps | 2007 |
| Gen 4 | FDR | 14.0625 Gbps | 64b/66b | 54.5 Gbps | 2011 |
| Gen 5 | EDR | 25.78125 Gbps | 64b/66b | 100 Gbps | 2014 |
| Gen 6 | HDR | 53.125 Gbps | 64b/66b + RS-FEC | 200 Gbps | 2018 |
| Gen 7 | NDR | 106.25 Gbps | PAM4 + RS-FEC | 400 Gbps | 2022 |
| Gen 8 | XDR | 200+ Gbps | PAM4 + RS-FEC | 800 Gbps | 2024+ |

**IC 设计关键**：
- FDR 及以上采用 64b/66b 编码（替代 8b/10b），编码效率从 80% 提升至 ~97%
- HDR 及以上强制 RS-FEC（Reed-Solomon Forward Error Correction）
- NDR 及以上采用 PAM4 调制，需要更复杂的 ADC/DSP 模块

---

## 5. 链路层 (Link Layer)

### 5.1 包格式 — Local Route Header (LRH)

IB 链路层包由 LRH 开头，标识链路级路由和 VL 信息。

```
+-------+-------+-------+-------+-------+-------+-------+-------+
|  VL   |  LNH  |  SL   |  Rsv  |    DLID (16-bit)              |
| (3:0) | (1:0) | (3:0) |       |                               |
+-------+-------+-------+-------+-------+-------+-------+-------+
|    SLID (16-bit)              |   Length (11:0) / Pkey (15:12) |
|                               |   [DLID bits 15:12]            |
+-------+-------+-------+-------+-------+-------+-------+-------+

LRH 字段定义：
  VL   [3:0]   — Virtual Lane 编号 (0~15)
  LNH  [1:0]   — Next Header 指示：
                   00 = 无（仅 LRH）
                   01 = RAW (Raw Header)
                   10 = BTH (Base Transport Header)
                   11 = GRH + BTH (Global Route + Transport)
  SL   [3:0]   — Service Level (QoS 优先级)
  DLID [15:0]  — Destination LID
  SLID [15:0]  — Source LID
  Length [11:0] — 包总长度（4-byte words）
```

### 5.2 虚拟通道 (Virtual Lane)

| VL | 用途 | 说明 |
|----|------|------|
| VL0 ~ VL14 | 数据通道 | 用户数据和操作，数量由 SM 配置 |
| VL15 | 管理通道 | 管理报文（MAD/SM 通信）独占 |

- 每个 VL 有独立的 **VL Arbitration**（加权轮询仲裁）
- VL15 不参与数据仲裁，优先级最高
- 实际支持的 VL 数量由端口能力决定（最少 1 个 VL0）

**IC 设计要点**：
- VL 缓冲区需独立实现，每 VL 对应一个 FIFO
- VL Arbitration 实现加权轮询（Weighted Round Robin）
- VL15 作为管理通道需有独立的优先级仲裁路径

### 5.3 信用流控 (Credit-Based Flow Control)

```
 发送端                                    接收端
+--------+     数据包(VL0)              +--------+
|        | -------------------------->  |        |
| TX VL0 |     CreditGrant(VL0)        | RX VL0 |
|        | <--------------------------  |        |
|        |                              |        |
|        |     数据包(VL1)              |        |
| TX VL1 | -------------------------->  | RX VL1 |
|        |     CreditGrant(VL1)        |        |
+--------+                              +--------+
```

**机制**：
- 每个 VL 独立维护 **credit 计数器**
- 发送前检查 credit > 0，每发一个 buffer 减 1
- 接收端释放 buffer 后发送 **CreditGrant**，发送端加回 credit
- **不丢包**：credit 耗尽则停止发送，不会溢出

**IC 设计要点**：
- 每 VL 需要一对 credit 计数器（发送端跟踪计数 + 接收端缓冲管理）
- CreditGrant 通过特殊的流控包（FLIT）传递，不占用数据带宽
- 链路初始化时通过 **Credit Setup (CS)** 包交换初始 credit 值
- 典型实现：每 VL 接收缓冲 64~256 entries，credit 计数器宽度 8~10 bit

### 5.4 链路级重传 (Link-Level Retry)

```
 发送端                              掿收端
  PKT SN=0  ---------------------->  收到 SN=0, 校验OK → ACK
  PKT SN=1  ---------------------->  收到 SN=1, 校验OK → ACK
  PKT SN=2  -------X (丢失)         (未收到)
  PKT SN=3  ---------------------->  收到 SN=3, SN!=2 → NAK
  <--------------------- NAK(RNR=2)
  重传 SN=2  ---------------------->  收到 SN=2, 校验OK → ACK
  重传 SN=3  ---------------------->  收到 SN=3, 校验OK → ACK
```

**机制**：
- 每个包携带 **PSN (Packet Sequence Number)**，7-bit（SDR/QDR）或 24-bit（FDR 及以上）
- 接收端检查 PSN 连续性，正确则回 **ACK**，错误则回 **NAK**（携带期望 PSN）
- 发送端维护重传窗口（Retransmit Window），保存已发送但未 ACK 的包
- 支持 **RNR-NAK**（Receiver Not Ready）：接收端暂时无法接收

**IC 设计要点**：
- 重传窗口缓冲区：典型深度 32~64 个包
- PSN 比较逻辑：需处理 PSN 环回（0xFFFFFF → 0x000000）
- 重传定时器：Timeout 值由 SM 配置，典型 10us~1s
- ACK/NAK 包的处理优先级高于数据包

---

## 6. 网络层 (Network Layer)

### 6.1 Global Route Header (GRH)

跨子网时在 LRH 和 BTH 之间插入 GRH，使用 IPv6 格式的 GID 寻址。

```
+-------+-------+-------+-------+-------+-------+-------+-------+
|  IPver|  TClass  |   Flow Label (20-bit)             |  Next  |
|  =6   | (7:0)   |                                   | Header |
+-------+-------+-------+-------+-------+-------+-------+-------+
| Hop Limit |   SGID (128-bit, Source GID)                     |
| (7:0)     |                                                   |
+-----------+                                                   |
|            ...                                                |
+-------+-------+-------+-------+-------+-------+-------+-------+
|            DGID (128-bit, Destination GID)                    |
|                                                               |
+-------+-------+-------+-------+-------+-------+-------+-------+
```

- GID：128-bit，格式与 IPv6 地址兼容
- SGID/DGID：源/目的全局标识符
- Hop Limit：跳数限制，每经过一个 router 减 1

### 6.2 Local ID (LID)

- **16-bit** 子网内唯一标识
- SM 负责分配，范围 0x0001 ~ 0xBFFF（单播），0xC000 ~ 0xFFFF（组播）
- 子网内基于 LID 路由（交换机查表转发）

### 6.3 路由机制

| 场景 | 路由方式 | 查找依据 |
|------|---------|---------|
| 子网内 | **LID 路由** | 交换机 FDB（Forwarding DataBase）以 DLID 为索引 |
| 子网间 | **GID 路由** | 路由器以 DGID 为索引，通过 GRH 转发 |

- 交换机只看 LRH 中的 DLID，不解析上层
- 路由器解析 GRH 中的 DGID，查找下一跳

**IC 设计要点**：
- 交换机 FDB 典型深度 4K~64K entries（LID 16-bit，但实际不全分配）
- 路由表查找可以用 TCAM 或哈希表实现
- 组播路由需要支持组播树复制（port mask）

---

## 7. 传输层 (Transport Layer)

### 7.1 Queue Pair (QP)

QP 是 IB 传输层的核心抽象，由 **Send Queue (SQ)** 和 **Receive Queue (RQ)** 组成。

```
用户态应用                内核态                 HCA 硬件
+-----------+          +--------+            +----------+
| Work      |          | QP     |            | QP State |
| Request   +--------->| Context|----------->| Machine  |
| (WR/WQE)  |          |        |            |          |
+-----------+          +--------+            +-----+----+
     |                                              |
     v                                              v
  +------+   Doorbell  +------+    DMA   +------+  +------+
  |  SQ  | ----------> | Door | -------> | TX   |  | RX   |
  +------+             | bell |          | Pipe |  | Pipe |
  +------+   CQE       +------+          +------+  +------+
  |  RQ  | <----------                          |
  +------+   Completion                        v
                                       网络侧 (IB Port)
```

**QP 服务类型**：

| 服务类型 | 全称 | 可靠性 | 连接方式 | 典型用途 |
|----------|------|--------|---------|---------|
| **RC** | Reliable Connection | 可靠 | 连接 | RDMA Read/Write，可靠数据传输 |
| **UC** | Unreliable Connection | 不可靠 | 连接 | 流媒体、组播优化 |
| **UD** | Unreliable Datagram | 不可靠 | 无连接 | 管理报文、MPI 短消息 |
| **RD** | Reliable Datagram | 可靠 | 无连接（多连接复用） | 管理（较少使用） |
| **XRC** | eXtended RC | 可靠 | 连接（共享 RQ） | 大规模集群优化 QP 数量 |

### 7.2 传输包格式 — Base Transport Header (BTH)

```
+-------+-------+-------+-------+-------+-------+-------+-------+
|OpCode | Solic.| Mig   |  PKey              |  TVer  | F  | L |
| (7:0) | ited  | req   |  (15:0)            | (3:0)  | ECN| N |
+-------+-------+-------+-------+-------+-------+-------+-------+
|              PSN (Packet Sequence Number, 24-bit)              |
|                                                               |
+-------+-------+-------+-------+-------+-------+-------+-------+
```

**OpCode 关键编码**：

| OpCode | 含义 | 说明 |
|--------|------|------|
| 0x00 | SEND_First | SEND 操作首包 |
| 0x01 | SEND_Middle | SEND 操作中间包 |
| 0x02 | SEND_Last | SEND 操作末包 |
| 0x04 | RDMA_Write_First | RDMA WRITE 首包（含 immediate） |
| 0x06 | RDMA_Write_Last | RDMA WRITE 末包 |
| 0x08 | RDMA_Read_Request | RDMA READ 请求 |
| 0x10 | RDMA_Read_Response_First | RDMA READ 响应首包 |
| 0x11 | RDMA_Read_Response_Last | RDMA READ 响应末包 |
| 0x80 | ACK | 确认 |
| 0x81 | NAK | 否定确认（含原因码） |

### 7.3 RDMA 操作类型

```
+----------+   SEND(WQE)    +----------+
| 主机 A   | -------------> | 主机 B   |
| (Init)   |                | (Target) |
|          |   WRITE(WQE)   |          |
|          | -------------> |          |
|          |                |          |
|          |   READ(WQE)    |          |
|          | -------------> |          |
|          | <------------- |          |
|          |                |          |
|          |  Atomic(F&A)   |          |
|          | -------------> |          |
|          | <------------- |          |
+----------+                +----------+
```

| 操作 | 方向 | 可靠性要求 | 说明 |
|------|------|-----------|------|
| **SEND** | Init→Target | RC/UC/UD | 将数据发送到远端 RQ 的 WR 指定缓冲区 |
| **WRITE** | Init→Target | RC/UC | 将数据直接写入远端内存地址（无需远端参与） |
| **READ** | Target→Init | RC | 从远端内存读取数据到本地（需远端密钥授权） |
| **Atomic** | 双向 | RC | 原子操作：Fetch&Add / Compare&Swap |

### 7.4 可靠连接 RC 流程

```
 发送端 (Init)                              接收端 (Target)

 WQE 入 SQ                                  WR 入 RQ
   |                                          |
   v                                          v
 SEND_First (PSN=100)  ──────────────────>  收到 PSN=100, 放入 RQ
 SEND_Middle (PSN=101) ──────────────────>  收到 PSN=101, 拼接
 SEND_Last  (PSN=102)  ──────────────────>  收到 PSN=102, 完整包
                                           → 生成 CQE
   <─────────────────────────────── ACK (MSN=102)
   → SQ 完成，生成 CQE
```

- **PSN**：24-bit 包序号，每包递增，保证顺序
- **ACK**：接收端确认收到的最后一个 PSN
- **重传**：发送端超时未收到 ACK 或收到 NAK，从指定 PSN 重传
- **MSN**：Message Sequence Number，用于跟踪完整消息的完成

---

## 8. 子网管理 (Subnet Management)

### 8.1 Subnet Manager (SM)

SM 是 InfiniBand 子网的集中管理实体，通常运行在主节点（Master SM）或交换机内。

**SM 职责**：

| 功能 | 说明 |
|------|------|
| 拓扑发现 | 通过 SubnAdmGet/Set 查询所有节点和端口 |
| LID 分配 | 为每个端口分配唯一 LID |
| 路由计算 | 计算最优路由表（LFT: Linear Forwarding Table）并下发 |
| QoS 配置 | 配置 SL→VL 映射、VL Arbitration |
| 链路配置 | 配置速率、宽度、Credit、重传参数 |
| 错误处理 | 监控链路错误计数器，触发故障恢复 |

### 8.2 管理数据报 (MAD)

MAD（Management Datagram）是 IB 管理报文的封装格式，通过 UD QP 传输（PKey=0xFFFF, QKey=0x80010000）。

**MAD 类别**：

| 类别 | 类名 | 功能 |
|------|------|------|
| Subnet Administration | SubnAdm | 拓扑发现、属性查询/设置 |
| Performance Management | PerfMgt | 端口性能计数器读取 |
| Baseboard Management | BM | 板级管理（电源、温度） |
| SNMP Tunneling | SNMP | SNMP 代理封装 |
| Vendor-Specific | VS | 厂商自定义扩展 |

```
MAD 包结构：
+-----------+-----------+-----------+-----------+
| LRH       | GRH       | BTH       | DETH      |
| (Link)    | (Global)  | (Transport)|(Datagram) |
+-----------+-----------+-----------+-----------+
| MAD Header (64 bytes)                         |
|  - BaseVersion / Class / Method / Status      |
|  - TID (Transaction ID)                       |
|  - AttributeID / AttributeModifier            |
+-----------+-----------+-----------+-----------+
| MAD Data (256 bytes)                          |
+-----------+-----------+-----------+-----------+
```

---

## 9. RDMA 在 InfiniBand 上的承载

### 9.1 RDMA 与 InfiniBand 的关系

- InfiniBand 是 RDMA 的**原生载体**，RDMA 操作（SEND/WRITE/READ/Atomic）直接在 IB 传输层定义
- QP、WQE、CQE 等核心概念均为 IB 传输层的一部分
- IB 硬件（HCA）原生实现完整 RDMA 协议栈

### 9.2 与 RoCE v2 的实现差异

| 对比项 | InfiniBand | RoCE v2 |
|--------|-----------|---------|
| **物理层** | IB 专用 SerDes（SDR~XDR） | Ethernet PHY（25G/50G/100G/200G） |
| **链路层** | IB Link Layer（LRH/VL/Credit） | Ethernet（无信用流控，依赖 PFC/ECN） |
| **网络层** | IB 网络层（LID/GRH） | IPv4/UDP 封装 |
| **传输层** | IB Transport（BTH 原生） | BTH 封装在 UDP payload 中 |
| **流控** | Credit-Based（逐跳、无损） | PFC（Priority-based）或 ECN（端到端） |
| **重传** | 链路级重传（逐跳）+ 端到端重传 | 仅端到端重传（RC 重传） |
| **管理** | SM + MAD（原生） | 子网管理依赖外部（如 OpenSM） |
| **QoS** | SL→VL 映射 + VL Arbitration | DSCP/802.1p + PFC 队列 |
| **延迟** | 更低（无以太网封装开销） | 略高（UDP 封装 ~30ns 额外延迟） |
| **成本** | IB 交换/HCA 专用硬件 | 复用以太网交换生态 |

**包封装差异示意**：

```
InfiniBand 包：
[LRH (8B)] [GRH (40B)] [BTH (12B)] [Payload] [ICRC (4B)]

RoCE v2 包：
[Ethernet (14B)] [IP (20B)] [UDP (8B)] [BTH (12B)] [Payload] [ICRC (4B)]
```

---

## 10. 与以太网/UEC 的关系和演进

### 10.1 InfiniBand vs 以太网

| 维度 | InfiniBand | Ethernet |
|------|-----------|----------|
| 哲学 | 无损、确定性、硬件卸载 | 尽力传输、软件协议栈 |
| RDMA | 原生支持 | 需 RoCE v2 或 iWARP |
| 流控 | Credit-Based（无丢包） | PFC/ECN（可丢包） |
| 生态 | 较小（专用厂商） | 极大（全球标准） |
| 扩展性 | 子网内 48K LID 限制 | 无此限制（IP 寻址） |
| 趋势 | AI/HPC 仍为主力 | 以太网追赶（UEC） |

### 10.2 UEC (Ultra Ethernet Consortium)

UEC 是 2023 年成立的联盟，目标是以以太网为基础构建类似 IB 的高性能互联：

- 引入 **多路径乱序传输**（IB RC 是单路径有序）
- 定义新的可靠传输协议（替代传统 TCP/RoCE v2 的部分限制）
- 目标延迟和带宽与 IB HDR/NDR 对标
- 目前仍在规范制定阶段，尚未大规模部署

### 10.3 演进方向

```
        InfiniBand 路线
              |
    SDR → DDR → QDR → FDR → EDR → HDR → NDR → XDR
                                          |
                                    AI/HPC 主流
                                          |
      ┌───────────────────────────────────┘
      |
      v
  RoCE v2 (兼容 IB RDMA，跑在以太网上)
      |
      v
  UEC (下一代以太网高性能互联)
      |
      v
  以太网全面替代？（待观察）
```

**架构师观点**：
- 短期（2024-2028）：IB 在 AI 集群中仍是性能标杆
- 中期（2028-2032）：UEC 以太网方案成熟后可能逐步侵蚀 IB 市场
- 长期：取决于成本、生态和性能差距

---

## 11. HCA 硬件设计要点

### 11.1 总体架构

```
+========================== PCIe Root Complex ==========================+
|                                                                       |
|  +----------+     +------------+     +------------+     +----------+ |
|  | PCIe     |     | Doorbell   |     | WQE/CQE    |     | Memory   | |
|  | Endpoint +---->| Manager    +---->| Engine     +---->| Trans-   | |
|  |          |     |            |     | (SQ/RQ)    |     | lation   | |
|  +-----+----+     +------------+     +------+-----+     +-----+----+ |
|        |                                    |                 |       |
|        |      +------------+                 |                 |       |
|        +----->| QP Context +-----------------+                 |       |
|              | Manager      |                                   |       |
|              +------+-------+                                   |       |
|                     |                                           |       |
|              +------v-------+     +------------+     +---------v----+ |
|              | TX Pipeline  +---->| IB Link    +---->| RX Pipeline  | |
|              | (SQ->Packet) |     | Layer      |     | (Packet->RQ) | |
|              +--------------+     +------+-----+     +--------------+ |
|                                         |                             |
|                                    IB Physical Port(s)                |
+========================================+==============================+
```

### 11.2 QP 状态机

QP 每个实例维护独立状态：

```
          RESET ──────────> INIT
            |                 |
            |                 v
            |              RTR (Ready To Receive)
            |                 |
            |                 v
            |              RTS (Ready To Send)
            |                 |
            |                 v
            |              SQERR (Send Queue Error)
            |                 |
            |                 v
            v              ERROR
          (关闭)

RESET:  QP 未初始化，无 WQE 处理
INIT:   QP 已配置参数（PKey, QKey, LID），可接收包但不可发送
RTR:    路由信息完整，可接收和响应
RTS:    可以发送和接收
SQERR:  发送出错，RQ 继续工作
ERROR:  严重错误，QP 停止工作
```

**IC 设计要点**：
- 每个 QP 状态寄存器需独立维护
- 状态转换必须有硬件仲裁，防止软件和硬件同时修改
- 状态转换需要原子操作保证一致性

### 11.3 WQE/CQE 处理

**WQE (Work Queue Entry)** 格式：

| 字段 | 大小 | 说明 |
|------|------|------|
| Opcode | 4-bit | SEND/WRITE/READ/Atomic/Bind |
| Send Flags | 8-bit | Signaled, Solicited, Inline, Fence |
| LKey / RKey | 32-bit | 本地/远端内存密钥 |
| Local Address | 64-bit | 本地 DMA 缓冲区地址 |
| Length | 32-bit | 数据长度 |
| Remote Address | 64-bit | RDMA 操作的远端地址（RC） |
| Remote Key | 32-bit | 远端内存访问密钥（RC） |

**处理流程**：
1. 主机写入 SQ Ring Buffer，触发 Doorbell 写入
2. HCA 读取 Doorbell，通过 DMA 读取 WQE
3. 解析 WQE，生成 BTH 包头，通过 DMA 读取数据
4. 发送包，等待 ACK
5. 收到 ACK 后，生成 CQE 写入 CQ Ring Buffer
6. 通过 MSI-X 中断通知主机

**IC 设计要点**：
- Doorbell 处理需要低延迟（写 PCIe BAR → 内部 FIFO）
- WQE DMA 读取需要高效的 Scatter-Gather DMA 引擎
- CQE 写入需要保证顺序性（Completion Ordering）
- 支持 Inline Data（小包数据内嵌 WQE，减少 DMA 访问）

### 11.4 Memory Translation

HCA 需要将虚拟地址（VA）翻译为物理地址（PA），支持 IOMMU 隔离：

```
WQE 中的 VA ──> IOMMU / ATS ──> PA ──> PCIe DMA

翻译缓存（Translation Cache）：
+----------+--------+--------+----------+
| VA Tag   | LKey   | PA     | 权限位   |
+----------+--------+--------+----------+
| ...      | ...    | ...    | ...      |
+----------+--------+--------+----------+
```

**IC 设计要点**：
- Translation Cache（MR Cache）：典型 4K~64K entries，需要支持并发查询
- 支持 ATS (Address Translation Service) 协议，利用 PCIe IOMMU
- 支持 Huge Page 映射（减少 TLB miss）
- 内存保护：LKey/RKey 校验、地址范围检查

### 11.5 Credit 管理

```
每 VL 发送端：
+-----------+     +-----------+
| Credit    |     | 发送 FIFO |
| Counter   |<--->| (Buffer)  |
| (per VL)  |     |           |
+-----------+     +-----------+
      ^
      | CreditGrant 包
      |
  接收端释放 Buffer

每 VL 接收端：
+-----------+     +-----------+
| Buffer    |     | Free List |
| Pool      |<--->| Manager   |
| (per VL)  |     |           |
+-----------+     +-----------+
      ^
      | 从 Buffer Pool 分配
      |
  收到数据包
```

**关键参数**：
- 初始 Credit：由 SM 通过 CS 包配置
- Buffer 深度：每 VL 典型 64~256 entries
- Credit Grant 频率：达到阈值时批量发放（减少开销）

### 11.6 链路级重传实现

```
+------------------+
| 重传窗口 Buffer  |  (典型 32~64 包)
+--------+---------+
         |
    +----v----+     +----------+     +----------+
    | 重传    |     | 发送     |     | ACK/NAK  |
    | 控制    |<----+ 状态机   |<----+ 处理     |
    +---------+     +----------+     +----------+
         |                               ^
         v                               |
    +---------+                    +-----+-----+
    | 重传    |                    | PSN 校验  |
    | Timer   |                    | 逻辑     |
    +---------+                    +-----------+
```

**IC 设计要点**：
- 重传 Buffer 用环形 FIFO 实现，按 PSN 索引
- 需支持 "Go-Back-N" 和 "Selective Repeat" 两种策略（FDR+ 默认 Selective Retry）
- 重传 Timer 精度要求：微秒级（典型计时器宽度 16~20 bit）
- PSN 比较需处理环回：`(psn - expected) < WINDOW_SIZE` 而非简单 `==`

### 11.7 PCIe 接口

HCA 通过 PCIe 连接主机：

| PCIe 代次 | 带宽 (x16) | IB 速率匹配 |
|-----------|-----------|-------------|
| Gen 3 | ~16 GB/s | 勉强匹配 EDR 4x |
| Gen 4 | ~32 GB/s | 匹配 HDR 4x |
| Gen 5 | ~64 GB/s | 匹配 NDR 4x |
| Gen 6 | ~128 GB/s | 充裕匹配 XDR 4x |

**IC 设计要点**：
- PCIe 需要支持 **SR-IOV**（虚拟化，多 VF 实例）
- DMA 引擎需支持 Scatter-Gather 和 Zero-Copy
- Doorbell 通过 PCIe BAR 空间映射，需低延迟处理（< 1us）
- MSI-X 中断数量：典型 64~2048 个（每个 CQ 独立中断向量）
- 支持 PCIe ATS（Address Translation Service）加速 IOMMU 翻译

---

## 12. 设计检查清单

| 检查项 | 说明 |
|--------|------|
| QP 状态机完整性 | 5 个状态 + 所有合法转移路径 |
| Credit 无死锁 | 确保 Credit Grant 优先级高于数据包 |
| 重传窗口不溢出 | 窗口大小 < 接收端 Buffer |
| PSN 环回正确 | 24-bit PSN 溢出处理 |
| VL Arbitration | 加权轮询实现，VL15 优先级最高 |
| Memory Protection | LKey/RKey 校验、地址越界检查 |
| PCIe 带宽匹配 | 确认 PCIe 代次与 IB 端口速率匹配 |
| Completion Ordering | CQE 按 SQ 顺序提交 |
| Error Recovery | QP 状态机能从 ERROR 状态恢复 |
| SM 兼容性 | 支持标准 MAD 查询/响应 |

---

## 附录：缩略语

| 缩写 | 全称 |
|------|------|
| BTH | Base Transport Header |
| CQE | Completion Queue Entry |
| DETH | Datagram Extended Transport Header |
| DLID | Destination Local Identifier |
| FEC | Forward Error Correction |
| FDB | Forwarding DataBase |
| GID | Global Identifier |
| GRH | Global Route Header |
| HCA | Host Channel Adapter |
| IB | InfiniBand |
| IBTA | InfiniBand Trade Association |
| IOMMU | Input/Output Memory Management Unit |
| LFT | Linear Forwarding Table |
| LID | Local Identifier |
| LRH | Local Route Header |
| MAD | Management Datagram |
| MR | Memory Region |
| MSN | Message Sequence Number |
| PAM4 | Pulse Amplitude Modulation 4-level |
| PFC | Priority Flow Control |
| PSN | Packet Sequence Number |
| QP | Queue Pair |
| RDMA | Remote Direct Memory Access |
| RS-FEC | Reed-Solomon Forward Error Correction |
| SL | Service Level |
| SM | Subnet Manager |
| SR-IOV | Single Root I/O Virtualization |
| UEC | Ultra Ethernet Consortium |
| VL | Virtual Lane |
| WQE | Work Queue Entry |
