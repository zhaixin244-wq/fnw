# NVMe over Fabrics (NVMe-oF) 协议知识文档

> **适用对象**：数字 IC 设计架构师
> **目标**：为 NVMe-oF Host/Target 硬件加速器（SmartNIC / DPU）设计提供协议参考
> **规范基础**：NVM Express over Fabrics Specification, Revision 1.1 (2023)

---

## 1. 协议概述

NVMe over Fabrics (NVMe-oF) 将 NVMe 命令集从本地 PCIe 总线扩展到 Fabric 网络传输层，允许 Host 通过以太网、InfiniBand 或 Fibre Channel 远程访问 NVMe SSD，实现存储与计算分离。

**核心设计目标**：
- 保留 NVMe 的低延迟、高并行队列模型
- 支持多种 Fabric 传输（RDMA / TCP / FC）
- 支持多 Host 共享命名空间（Namespace）
- 与本地 NVMe 共享上层命令语义（Admin / I/O 命令集）

**规范族**：
- **NVMe Base Spec**：定义命令集、队列模型、寄存器接口（本地 PCIe）
- **NVMe over Fabrics Spec**：定义 Fabric 传输映射、Capsule 格式、Discovery 机制
- **NVMe over RDMA / TCP / FC**：各传输层的具体绑定规范

---

## 2. NVMe vs NVMe-oF 架构对比

### 本地 NVMe（NVMe over PCIe）

```
+-----------------------------------------------------------+
|                         Host                              |
|  +-------------+    +----------+                          |
|  | Application |--> | NVMe     |                          |
|  | (SPDK/内核) |    | Driver   |                          |
|  +-------------+    +----+-----+                          |
|                          | PCIe MMIO / Doorbell           |
|                    +-----v------+                          |
|                    | NVMe Ctrl  |   +------------------+  |
|                    | (本地芯片) |<->| NVMe SSD (NAND)  |  |
|                    +------------+   +------------------+  |
+-----------------------------------------------------------+
```

**特点**：
- Host 通过 PCIe BAR 空间直接访问 NVMe Controller 寄存器
- SQ/CQ 队列位于 Host 内存，Controller 通过 DMA 读取
- 延迟：~10 us（典型值）
- 距离限制：板级 / 系统级

### NVMe over Fabrics

```
+---------------------------+        +---------------------------+
|          Host             |        |         Target            |
|  +-------------+          |        |                          |
|  | Application |          |        |   +------------------+  |
|  | (SPDK/内核) |          |        |   | NVMe-oF          |  |
|  +------+------+          |        |   | Controller       |  |
|         |                 |        |   | (Fabric + NVMe)  |  |
|  +------v-------+        |        |   +--------+---------+  |
|  | NVMe-oF      |        |        |            |            |
|  | Host Driver  |        |        |   +--------v---------+  |
|  +------+-------+        |        |   | Backend Storage   |  |
|         | Fabric API     |        |   | (NVMe SSD / HDD)  |  |
|  +------v-------+        |        |   +-------------------+  |
|  | Transport    |        |        |                          |
|  | (RDMA/TCP/FC)|        |        |                          |
|  +------+-------+        |        |                          |
|         |                |        |                          |
+---------|----------------+        +---------------------------+
          |                              ^
          +------- Fabric Network -------+
                  (Ethernet / IB / FC)
```

**关键差异对比表**：

| 维度 | 本地 NVMe (PCIe) | NVMe-oF |
|------|-------------------|---------|
| 传输介质 | PCIe Gen4/5 | Ethernet / IB / FC |
| 延迟 | ~10 us | ~15 us (RDMA) / ~30 us (TCP) |
| 队列位置 | Host 物理内存（Controller DMA 读取） | Host 内存 + Fabric 传输（Capsule 封装） |
| 寄存器访问 | PCIe BAR MMIO | 无 MMIO，通过 Capsule 交互 |
| 连接方式 | PCIe 枚举 / AER | Fabric 连接建立（Connect 命令） |
| 发现机制 | PCIe 枚举 | Discovery Service |
| 距离 | 板级 | 数据中心级（km 级） |
| 共享 NS | 不支持 | 支持多 Host 共享 |

---

## 3. 传输层选项

### 3.1 NVMe over RDMA (NVMe/RDMA)

- **规范**：NVM Express over Fabrics over RDMA (NVMfRDMA)
- **传输**：RDMA (Remote Direct Memory Access)，零拷贝、内核旁路
- **实现**：RoCE v2（RDMA over Converged Ethernet, 要求无损或 PFC）或 InfiniBand
- **端口**：RoCE v2 使用 UDP 端口 4791；IB 使用 RC (Reliable Connection) QP
- **队列映射**：每个 NVMe-oF SQ/CQ 对应一个 RC Queue Pair (QP)
- **数据传输**：通过 RDMA READ/WRITE 操作直接在 Host 内存与 Target 间传输数据
- **SGL**：Data 段通过 SGL (Scatter-Gather List) 描述，RDMA 直接访问

### 3.2 NVMe over TCP (NVMe/TCP)

- **规范**：NVM Express over Fabrics over TCP (NVMfTCP)
- **传输**：标准 TCP/IP，无需特殊网络硬件
- **端口**：TCP 端口 4420（IANA 注册）
- **队列映射**：一个 TCP 连接承载多个 NVMe-oF I/O Queue
- **数据传输**：通过 PDU (Protocol Data Unit) 封装，支持 Data Digest (CRC32c) 校验
- **PDU 类型**：CapsuleReq / CapsuleRsp / H2CData / C2HData / TermReq
- **优势**：无需网卡硬件支持 RDMA，部署最简单

### 3.3 NVMe over FC (NVMe/FC)

- **规范**：NVM Express over Fibre Channel (NVMfFC)
- **传输**：Fibre Channel（SAN 存储网络）
- **映射**：复用 FC-NVMe FC-4 类型（Type 28），利用 FC-LS-3 Link Service
- **命名**：使用 FC 64-bit 标识（Port WWN / Node WWN）
- **特点**：利用 FC Fabric 的 Name Server、Zone 等已有设施
- **适用**：已有 FC SAN 基础设施的数据中心

### 3.4 三种传输层对比

| 维度 | NVMe/RDMA (RoCE v2) | NVMe/TCP | NVMe/FC |
|------|----------------------|----------|---------|
| **端到端延迟** | ~15 us | ~30 us | ~20 us |
| **CPU 开销** | 极低（零拷贝、内核旁路） | 中等（需要 TCP 协议栈） | 低（HBA 卸载） |
| **带宽** | 线速（100/200/400GbE） | 受 TCP 栈限制 | 线速（32/64/128G FC） |
| **网卡要求** | RDMA 网卡（RoCE v2） | 普通以太网网卡 | FC HBA |
| **交换机要求** | 支持 PFC/ECN（无损网络） | 普通以太网交换机 | FC 交换机 |
| **部署复杂度** | 高（无损网络配置） | 低（即插即用） | 中（需要 FC Fabric） |
| **成本** | 高（RDMA 网卡 + 无损交换机） | 低（现有以太网） | 高（FC HBA + 交换机） |
| **适用场景** | 超低延迟、高性能 | 通用部署、成本敏感 | 已有 FC SAN |
| **IC 设计角度** | RDMA QP 管理、SGL 解析 | TCP 连接管理、PDU 解析 | FC HBA 集成（复杂度高） |

---

## 4. NVMe-oF 协议栈

```
+---------------------------+
| Application (SPDK/内核)   |  用户态或内核态 NVMe-oF 驱动
+---------------------------+
| NVMe-oF Layer             |  Capsule 构造/解析、队列管理、
|                           |  Discovery、连接管理
+---------------------------+
| Transport Layer           |  RDMA / TCP / FC
| (RDMA / TCP / FC)         |  数据封装与传输
+---------------------------+
| Network Layer             |  Ethernet (UDP/TCP) / IB / FC
+---------------------------+
| Physical Layer            |  100/200/400GbE / IB / FC
+---------------------------+
```

**各层职责**：
- **Application**：产生 NVMe Admin/I/O 命令（读/写/flush 等）
- **NVMe-oF Layer**：将 NVMe 命令封装为 Capsule，管理 Fabric 连接、队列
- **Transport Layer**：将 Capsule 映射到具体传输协议的 PDU/Message，处理数据传输
- **Network Layer**：标准网络协议栈（TCP/IP 或 RDMA verbs 或 FC-2/3）

---

## 5. Capsule 格式

### 5.1 Command Capsule (Host -> Target)

NVMe-oF 使用 **Capsule** 取代本地 NVMe 的 Doorbell + DMA 机制。每个 Capsule 是一个在 Fabric 上传输的消息。

```
Command Capsule 结构：
+-----------------------------------------------+
|  NVMe-oF Capsule Header (24 bytes)            |
|  - PDU Type, Flags, Data Offset, Data Length  |
+-----------------------------------------------+
|  SQE (NVMe Submission Queue Entry, 64 bytes)  |
|  - CDW0-CDW15，与本地 NVMe SQE 格式兼容       |
+-----------------------------------------------+
|  SGL Descriptors (可变长度)                    |
|  - 描述数据缓冲区地址/长度                     |
|  - 支持 SGL Data Block, SGL Segment,          |
|    SGL Last Segment, Keyed SGL 等             |
+-----------------------------------------------+
```

**Capsule Header 字段**：

| 字段 | 位宽 | 说明 |
|------|------|------|
| PDU Type | 8 | 01h = CapsuleReq |
| Flags | 8 | 传输层特定标志 |
| H2CData Offset | 16 | 到 H2C Data PDU 的偏移（相对 PDU 头） |
| Capsule Command Data Length | 32 | Capsule 中数据部分长度（SGL 部分） |
| SQE Header (CDW0-CDW1) | 64 | NVMe 命令头（Opcode, Fused, PSDT, CID, NSID） |

### 5.2 Response Capsule (Target -> Host)

```
Response Capsule 结构：
+-----------------------------------------------+
|  NVMe-oF Capsule Header (24 bytes)            |
|  - PDU Type = 02h (CapsuleRsp)               |
+-----------------------------------------------+
|  CQE (NVMe Completion Queue Entry, 16 bytes)  |
|  - SQHD, SQID, CID, Status (SC, SCT, etc.)   |
+-----------------------------------------------+
```

### 5.3 SGL (Scatter-Gather List) 在 NVMe-oF 中的用法

| SGL 类型 | Subtype | 说明 |
|----------|---------|------|
| SGL Data Block | 0x00 | 单段数据描述（地址+长度） |
| SGL Bit Bucket | 0x01 | 用于接收方向（Target 写）的占位符 |
| SGL Segment | 0x02 | 指向下一个 SGL 段 |
| SGL Last Segment | 0x03 | 最后一个 SGL 段 |
| Keyed SGL Data Block | 0x04 | 带 Memory Handle 的 SGL（用于 RDMA） |

**RDMA 特定**：SGL 中的 Address 字段在 RDMA 传输中被 RDMA READ/WRITE 的 raddr 替代，NVMe-oF 层需要将 SGL 转换为 RDMA 内存区域 (MR) 操作。

**TCP 特定**：数据通过 H2CData / C2HData PDU 传输，SGL 描述数据的 Host 缓冲区布局。

---

## 6. 连接模型

### 6.1 Host-Controller 连接建立

本地 NVMe 通过 PCIe 枚举发现 Controller；NVMe-oF 通过 **Fabric Connect** 命令建立逻辑连接。

```
Host                                          Target (NVMe-oF Ctrl)
  |                                                |
  |--- Connect Command (Admin SQE) --------------->|
  |    (Host NQN, Controller ID,                   |
  |     Queue Size, SQ/CQ 物理地址)                |
  |                                                |
  |<-- Connect Response (CQE) ---------------------|
  |    (Status, Controller ID, CRTO, CAP)          |
  |                                                |
  |    连接建立完成，可发送 I/O 命令                |
```

**Connect 命令关键参数**：
- **Host NQN**：Host 的唯一标识（NVM Qualified Name，类似 iSCSI IQN）
- **Controller ID**：Target 分配的控制器标识
- **SQ Size / CQ Size**：队列深度
- **Queue 物理地址**：在 RDMA 传输中为 QP 信息；在 TCP 传输中通过 CID 标识

### 6.2 队列创建（Fabric SQ/CQ vs 本地 SQ/CQ）

| 维度 | 本地 NVMe (PCIe) | NVMe-oF |
|------|-------------------|---------|
| SQ 物理位置 | Host 内存 | Host 内存（但 Controller 不能直接 DMA） |
| 命令投递 | Doorbell 寄存器写入 | Capsule 通过 Fabric 发送 |
| CQ 获取 | Controller DMA 写入 Host 内存 | Response Capsule 通过 Fabric 接收 |
| Doorbell | 写 PCI BAR 寄存器 | 无 Doorbell，Capsule 发送即投递 |
| 中断 | MSI-X | 传输层事件（RDMA CQE / TCP 数据到达） |

**关键差异**：本地 NVMe Controller 可以直接 DMA 访问 Host 内存的 SQ/CQ；NVMe-oF Controller 无法直接访问 Host 内存，所有命令和数据通过 Fabric Capsule 传输。

### 6.3 带内认证（DH-HMAC-CHAP）

NVMe-oF 支持 Fabric 连接建立时的带内认证，防止未授权主机连接。

- **协议**：DH-HMAC-CHAP（Diffie-Hellman + HMAC Challenge Handshake Authentication Protocol）
- **流程**：
  1. Host 发送 Connect 命令，携带认证消息（DH 公钥 + CHAP Challenge）
  2. Target 回复 Connect Response，携带认证结果（DH 公钥 + CHAP Response）
  3. 可能需要多轮交互完成密钥协商
- **密钥协商**：使用 DH（Diffie-Hellman）算法协商共享密钥
- **身份验证**：使用 HMAC-SHA256 或 HMAC-SHA512 验证 CHAP Challenge/Response
- **参数**：DH Group（RFC 7919 groups）、Hash Function（SHA-256/384/512）、HMAC Function

---

## 7. Discovery 机制

### 7.1 Discovery Service

NVMe-oF 使用集中式 **Discovery Service** 让 Host 发现可用的 NVMe-oF Subsystem。

```
Host                                          Discovery Controller
  |                                                |
  |--- 连接到 Discovery Service ------------------>|
  |    (Transport: RDMA/TCP/FC,                    |
  |     Port: 8009(RDMA)/4420(TCP))                |
  |                                                |
  |--- Get Log Page (Discovery Log Page) --------->|
  |                                                |
  |<-- Discovery Log Page (条目列表) --------------|
  |    - Subsystem NQN                             |
  |    - Transport Type + Transport Address        |
  |    - Subsystem Type (Discovery / NVMe)         |
  |    - Access Control (Asymmetric Namespace)     |
  |                                                |
  |    Host 根据 Log Page 连接到目标 Subsystem     |
```

### 7.2 Discovery Log Page

| 字段 | 说明 |
|------|------|
| Genctr | Generation Counter（Log 变化时递增） |
| Number of Records | 当前记录数 |
| Records[] | 条目数组，每条包含： |
| - Subsystem NQN | 目标 Subsystem 的 NQN |
| - Transport Type | rdma / tcp / fc |
| - Transport Address | 目标地址（IP/WWN） |
| - Transport Service ID | 端口号（4420 / 8009 / FC Port ID） |
| - Subsystem Type | Discovery / NVMe |
| - TREQ | Transport Requirements（安全、队列数等） |

### 7.3 Subsystem NQN

- **格式**：`nqn.yyyy-mm.domain:subsystem_name`（如 `nqn.2014-08.com.example:storage1`）
- **Discovery NQN**：固定为 `nqn.2014-08.org.nvmexpress.discovery`
- **用途**：作为 Subsystem 的全局唯一标识，Host 通过 NQN 匹配连接目标

### 7.4 Asymmetric Namespace Access (ANA)

- 多路径环境下，同一 Namespace 在不同 Controller 上可能有不同优先级
- ANA Log Page 报告每个 Namespace 的 ANA State（Optimized / Non-Optimized / Inaccessible / Persistent Loss）
- Host 驱动根据 ANA 状态选择最优路径

---

## 8. 命名空间共享

### 8.1 多 Host 共享同一 Namespace

NVMe-oF 支持多个 Host 同时访问同一 Namespace，典型场景：分布式文件系统、数据库集群。

```
+----------+     +----------+
|  Host A  |     |  Host B  |
+----+-----+     +-----+----+
     |                 |
     v                 v
+-----------------------------------+
|   NVMe-oF Subsystem               |
|   +---------------------------+   |
|   | Namespace 1 (NSID=1)     |<--|--- 共享 NS
|   | +---------------------+  |   |
|   | | NS Descriptors      |  |   |
|   | | EUI64 / NGUID / UUID|  |   |
|   | +---------------------+  |   |
|   +---------------------------+   |
|   +---------------------------+   |
|   | Namespace 2 (NSID=2)     |   |
|   +---------------------------+   |
+-----------------------------------+
```

### 8.2 分布式锁协调

多 Host 共享 NS 需要并发访问控制机制：

| 机制 | 说明 |
|------|------|
| Compare and Write (CAW) | NVMe Compare + Write 原子操作，用于实现分布式锁 |
| Reservation（预留） | NVMe Reservation 命令，支持 Exclusive Access / Write Exclusive 等模式 |
| 分布式锁服务 | 外部协调服务（如 etcd、ZooKeeper）管理锁 |

### 8.3 Reservation Types

| Reservation 类型 | 说明 |
|-----------------|------|
| Write Exclusive | 仅持有者可写，其他 Host 可读 |
| Exclusive Access | 仅持有者可读写 |
| Write Exclusive - Registrants Only | 仅注册的 Host 可写 |
| Exclusive Access - Registrants Only | 仅注册的 Host 可读写 |

---

## 9. NVMe-oF Target

### 9.1 功能定位

NVMe-oF Target 是 Fabric 网络端的存储服务端，接收 Host 的 NVMe 命令并执行，操作后端存储。

### 9.2 典型架构（软件参考，硬件映射）

```
+-------------------------------------------------------+
|                   NVMe-oF Target                       |
|                                                       |
|  +-------------------------------------------------+  |
|  |  Fabric Interface (RDMA/TCP/FC)                 |  |
|  |  - 连接管理（Accept, Connect 处理）              |  |
|  |  - Capsule 接收/发送                             |  |
|  |  - 数据传输（RDMA READ/WRITE / TCP PDU）         |  |
|  +-------------------------------------------------+  |
|                          |                            |
|  +-------------------------------------------------+  |
|  |  NVMe 命令处理                                   |  |
|  |  - SQE 解析（Opcode, NSID, SGL）                |  |
|  |  - 命令调度（多 SQ 轮询 / 优先级仲裁）          |  |
|  |  - Admin 命令（Identify, Get/Set Features）     |  |
|  |  - I/O 命令（Read, Write, Flush, Compare）      |  |
|  +-------------------------------------------------+  |
|                          |                            |
|  +-------------------------------------------------+  |
|  |  后端存储接口                                    |  |
|  |  - NVMe PCIe (本地 SSD)                         |  |
|  |  - 本地 NVMe (同一芯片内)                       |  |
|  |  - 分布式存储                                    |  |
|  +-------------------------------------------------+  |
|                          |                            |
|  +-------------------------------------------------+  |
|  |  Subsystem / Namespace 管理                     |  |
|  |  - NSID 到后端 LBA 的映射                       |  |
|  |  - ANA 管理                                     |  |
|  |  - Reservation 管理                             |  |
|  +-------------------------------------------------+  |
+-------------------------------------------------------+
```

### 9.3 Target 状态机（简化）

```
IDLE -> CONNECT -> ACTIVE -> DISCONNECT -> IDLE
  |         |        |           |
  |         |        |           +-- 释放资源
  |         |        +-- 处理 Admin / I/O 命令
  |         +-- 验证连接参数（NQN, QP 信息等）
  +-- 监听端口，等待连接
```

---

## 10. NVMe-oF Host

### 10.1 功能定位

NVMe-oF Host 是 Fabric 网络端的存储客户端（启动器），向 Target 发送 NVMe 命令并接收响应。

### 10.2 典型架构

```
+-------------------------------------------------------+
|                     NVMe-oF Host                       |
|                                                       |
|  +-------------------------------------------------+  |
|  |  NVMe 命令生成                                   |  |
|  |  - 来自块设备层 / 用户态 SPDK                   |  |
|  |  - Admin 命令（Subsystem 管理）                 |  |
|  |  - I/O 命令（Read/Write 请求）                  |  |
|  +-------------------------------------------------+  |
|                          |                            |
|  +-------------------------------------------------+  |
|  |  Capsule 封装                                    |  |
|  |  - SQE 构造 + SGL 构建                          |  |
|  |  - Capsule Header 添加                          |  |
|  |  - Capsule 发送到 Fabric                        |  |
|  +-------------------------------------------------+  |
|                          |                            |
|  +-------------------------------------------------+  |
|  |  Fabric 连接管理                                 |  |
|  |  - Discovery Service 连接                       |  |
|  |  - Target 连接建立 / 断开                       |  |
|  |  - 多路径管理（ANA）                            |  |
|  +-------------------------------------------------+  |
|                          |                            |
|  +-------------------------------------------------+  |
|  |  传输层接口                                      |  |
|  |  - RDMA: QP 创建, Memory Registration           |  |
|  |  - TCP: Socket 管理, PDU 收发                   |  |
|  +-------------------------------------------------+  |
+-------------------------------------------------------+
```

---

## 11. 性能对比

### 本地 NVMe vs NVMe/RDMA vs NVMe/TCP

| 指标 | 本地 NVMe (PCIe Gen4) | NVMe/RDMA (100GbE) | NVMe/TCP (100GbE) |
|------|----------------------|--------------------|--------------------|
| **随机读延迟 (4K)** | ~10 us | ~15-20 us | ~25-35 us |
| **随机写延迟 (4K)** | ~12 us | ~18-22 us | ~30-40 us |
| **带宽 (顺序读)** | ~6.5 GB/s (x4 Gen4) | ~12 GB/s (100GbE) | ~10-11 GB/s |
| **IOPS (随机 4K 读)** | ~1M+ | ~500K-800K | ~300K-500K |
| **CPU 开销/IO** | ~0.5 us | ~1-2 us | ~3-5 us |
| **中断开销** | MSI-X (1-2 us) | RDMA CQE (0.5-1 us) | TCP 软中断 (2-4 us) |

### 延迟分解分析

```
本地 NVMe (总延迟 ~10 us):
  Software overhead:     ~1 us
  PCIe Transaction:      ~1 us
  NVMe Ctrl processing:  ~2 us
  NAND access:           ~5 us
  CQE/Done:              ~1 us

NVMe/RDMA (总延迟 ~17 us):
  Software overhead:     ~1 us
  RDMA send/RC:          ~2 us
  Network traversal:     ~1 us
  Target Capsule parse:  ~1 us
  NVMe Ctrl processing:  ~2 us
  NAND access:           ~5 us
  RDMA response:         ~2 us
  Network traversal:     ~1 us
  CQE processing:        ~1 us

NVMe/TCP (总延迟 ~30 us):
  Software overhead:     ~2 us
  TCP/IP stack:          ~4 us
  Network traversal:     ~1 us
  Target TCP/IP stack:   ~3 us
  Target Capsule parse:  ~1 us
  NVMe Ctrl processing:  ~2 us
  NAND access:           ~5 us
  TCP response:          ~4 us
  Network traversal:     ~1 us
  CQE processing:        ~2 us
  (额外: TCP 拥塞控制、拷贝开销等)
```

**结论**：NVMe/RDMA 比本地 NVMe 多 ~7 us（主要是网络往返 + Capsule 封装开销）；NVMe/TCP 比 NVMe/RDMA 再多 ~10-15 us（TCP 协议栈开销）。硬件卸载可以显著减少 Host 侧开销。

---

## 12. 设计注意事项

### 12.1 NVMe-oF Target/Host RTL 设计概要

面向 SmartNIC / DPU 的 NVMe-oF 硬件加速器，需要在 RTL 中实现以下功能模块：

#### 12.1.1 RDMA/TCP 解封装模块

| 功能 | RDMA 路径 | TCP 路径 |
|------|-----------|----------|
| 传输层解析 | RC QP 消息接收、InfiniBand/RoCE BTH 头解析 | TCP Segment 重组、TCP 头解析 |
| Capsule 提取 | 从 RDMA SEND/WRITE 消息中提取 NVMe-oF Capsule | 从 TCP PDU 中提取 CapsuleReq/CapsuleRsp |
| SGL 处理 | 将 NVMe-oF SGL 转换为 RDMA MR 操作 | 将 SGL 描述为 H2CData PDU 的数据源 |
| Digest 校验 | N/A（RDMA 自身有校验） | Data Digest (CRC32c) 校验 |

#### 12.1.2 NVMe 命令解析模块

- 解析 64 字节 SQE，提取 Opcode、NSID、LBA、Length 等字段
- 支持 Admin 命令（Identify、Get/Set Features、Create/Delete IO SQ/CQ）
- 支持 I/O 命令（Read、Write、Flush、Compare、Dataset Management）
- SGL 描述符解析（支持多种 SGL 类型）

#### 12.1.3 数据 DMA 模块

- **Host -> Target (写命令)**：从 Fabric 接收数据，DMA 写入后端存储
- **Target -> Host (读命令)**：从后端存储读取数据，通过 Fabric 发送到 Host
- 支持 Scatter-Gather DMA（多个非连续物理地址）
- 支持数据对齐处理（非 4K 对齐的读写）

#### 12.1.4 Completion 回传模块

- 构造 16 字节 CQE（SQHD、SQID、CID、Status）
- 封装为 Response Capsule，通过 Fabric 发送
- 支持中断聚合（Interrupt Coalescing）减少 Capsule 发送次数

#### 12.1.5 与本地 NVMe Controller 的共存

DPU 架构中，NVMe-oF Target 可能与本地 NVMe PCIe Controller 共存：

```
+-------------------------------------------+
|                  DPU                       |
|                                           |
|  +----------+    +----------+             |
|  | NVMe-oF  |    | 本地NVMe |             |
|  | Target   |    | Ctrl     |             |
|  | (Fabric) |    | (PCIe)   |             |
|  +----+-----+    +----+-----+             |
|       |               |                   |
|  +----v----------+  +-v---------------+   |
|  | 命令分发/仲裁  |  | PCIe EP         |   |
|  | (统一NVMe引擎)|  | (对Host可见)    |   |
|  +----+----------+  +-----------------+   |
|       |                                   |
|  +----v----------+                        |
|  | 后端存储接口   |                        |
|  | (NVMe SSD)    |                        |
|  +--------------+                         |
+-------------------------------------------+
```

**共存设计要点**：
- 命令仲裁：本地 PCIe NVMe 命令与 Fabric NVMe-oF 命令竞争后端存储带宽
- 队列管理：两套队列体系（PCIe SQ/CQ + Fabric SQ/CQ）统一调度
- 数据通路：共享后端 DMA 引擎，需要仲裁逻辑
- Namespace 映射：本地 Controller 和 NVMe-oF Target 可能共享后端 NS

#### 12.1.6 SmartNIC/DPU 中的 NVMe-oF 卸载

| 卸载层级 | 卸载内容 | 实现复杂度 | 收益 |
|----------|----------|-----------|------|
| L1: 传输层卸载 | TCP/RDMA 协议处理 | 高 | 减少 Host CPU 开销 |
| L2: Capsule 卸载 | Capsule 封装/解析 | 中 | 减少内存拷贝 |
| L3: 命令卸载 | NVMe 命令执行 | 高 | 完全旁路 Host CPU |
| L4: 数据直通 | 后端存储直连 DPU | 中 | 消除 Host 中转 |

**常见实现模式**：
- **SPDK + RDMA 网卡**：SPDK 用户态轮询 + RDMA 硬件卸载传输层
- **DPU 全卸载**：DPU 上运行完整 NVMe-oF Target，Host 零开销
- **混合模式**：DPU 处理连接管理和命令路由，数据直通后端

### 12.2 RTL 设计关键约束

| 约束项 | 说明 |
|--------|------|
| 队列深度 | 典型值 1024-65536，需参数化 |
| 最大 Capsule 大小 | 受 Fabric MTU 限制（RDMA ~4KB 片段，TCP ~64KB 段） |
| 并发连接数 | 取决于 QP/Socket 资源，典型 256-4096 |
| SGL 处理深度 | 支持嵌套 SGL，最大级数需限制（典型 3-4 级） |
| CRC32c 硬件计算 | TCP 路径必须支持 Data Digest |
| 内存带宽 | 后端 DMA 引擎带宽需满足线速要求 |
| 命令延迟预算 | 从 Capsule 接收到后端命令发出 ≤ 目标延迟 |

### 12.3 RTL 模块划分建议

```
nvme_of_top.v              — 顶层模块
├── nvme_of_conn_mgr.v     — 连接管理（Fabric Connect 处理）
├── nvme_of_capsule_rx.v   — Capsule 接收与解析
├── nvme_of_capsule_tx.v   — Capsule 构造与发送
├── nvme_of_cmd_engine.v   — NVMe 命令执行引擎
├── nvme_of_sgl_parser.v   — SGL 描述符解析器
├── nvme_of_data_dma.v     — 数据 DMA 引擎
├── nvme_of_disc_client.v  — Discovery Service 客户端
├── nvme_of_auth.v         — DH-HMAC-CHAP 认证模块
├── nvme_of_reserv.v       — Reservation 管理
├── nvme_of_roce_intf.v    — RoCE v2 传输接口（如支持 RDMA）
├── nvme_of_tcp_intf.v     — TCP 传输接口（如支持 TCP）
│   ├── nvme_of_tcp_rx.v   — TCP 接收 + PDU 解析
│   ├── nvme_of_tcp_tx.v   — TCP 发送 + PDU 封装
│   └── nvme_of_crc32c.v   — CRC32c 硬件计算
├── nvme_of_local_arb.v    — 本地 NVMe 与 NVMe-oF 仲裁
└── nvme_of_sva.sv         — SVA 断言绑定模块
```

---

## 附录 A：NVMe-oF 命令 Opcode 参考

| Opcode | 命令 | 类型 | 说明 |
|--------|------|------|------|
| 0x01 | Connect | Admin | 建立 Fabric 连接 |
| 0x02 | Disconnect | Admin | 断开 Fabric 连接 |
| 0x06 | Property Set | Admin | 设置 Controller 属性（仅 Discovery） |
| 0x07 | Property Get | Admin | 获取 Controller 属性（仅 Discovery） |
| 0x18-0x1F | (保留给 NVMe-oF 扩展) | Admin | |
| 其他 | 与本地 NVMe Admin/I/O 命令兼容 | Admin/IO | Identify, Get/Set Features, Read, Write, Flush 等 |

## 附录 B：缩略语

| 缩写 | 全称 |
|------|------|
| ANA | Asymmetric Namespace Access |
| CAW | Compare and Write |
| CHAP | Challenge Handshake Authentication Protocol |
| CQE | Completion Queue Entry |
| DH | Diffie-Hellman |
| DPU | Data Processing Unit |
| FC | Fibre Channel |
| HMAC | Hash-based Message Authentication Code |
| IB | InfiniBand |
| MR | Memory Region (RDMA) |
| NQN | NVM Qualified Name |
| NSID | Namespace Identifier |
| NVMe | Non-Volatile Memory Express |
| NVMe-oF | NVMe over Fabrics |
| PDU | Protocol Data Unit |
| QP | Queue Pair (RDMA) |
| RDMA | Remote Direct Memory Access |
| RoCE | RDMA over Converged Ethernet |
| SGL | Scatter-Gather List |
| SmartNIC | Smart Network Interface Card |
| SQE | Submission Queue Entry |
| TCP | Transmission Control Protocol |

## 附录 C：参考规范

| 文档 | 版本 |
|------|------|
| NVM Express Base Specification | Revision 2.0+ |
| NVM Express over Fabrics Specification | Revision 1.1 |
| NVM Express over Fabrics over RDMA | Revision 1.1 |
| NVM Express over Fabrics over TCP | Revision 1.1 |
| NVM Express over Fibre Channel | Revision 1.1 |
| InfiniBand Architecture Specification | Release 1.4 |
| RoCE v2 Specification | IBTA |
| RFC 7919 (DH Groups) | IETF |
