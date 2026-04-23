# VXLAN / GENEVE 网络虚拟化协议

> **面向数字 IC 设计架构师的参考文档**
> 日期：2026-04-15

---

## 1. VXLAN (Virtual Extensible LAN, RFC 7348)

### 1.1 协议概述

VXLAN 是一种 **L2 over L3 隧道技术**，将以太网帧封装在 UDP/IP 报文内穿越三层网络。核心目标是解决传统 VLAN 仅 12-bit VID（4094 个网络）的限制。

- **VNI (VXLAN Network Identifier)**：24-bit，支持 **~1600 万个**虚拟二层网络
- **封装角色**：VTEP (VXLAN Tunnel Endpoint) 负责封装/解封装
- **传输基础**：外层使用标准 IP/UDP 传输，便于穿越现有三层网络
- **典型场景**：数据中心多租户隔离、跨 DC 二层延伸、VM 迁移

### 1.2 封装格式

```
+------------------------------------------------------------------+
|                        Outer Ethernet Header                      |
|  Dst MAC (6B) | Src MAC (6B) | EtherType=0x0800 (2B) | VLAN(opt) |
+------------------------------------------------------------------+
|                          Outer IPv4 Header                        |
|  Ver/IHL/TOS | Total Length | ID/Flags/Frag | TTL=255 | Proto=17 |
|  Src IP (4B) | Dst IP (4B) | Options (opt)                      |
+------------------------------------------------------------------+
|                           Outer UDP Header                        |
|  Src Port (2B) [hash] | Dst Port = 4789 (2B) | Length | Checksum |
+------------------------------------------------------------------+
|                         VXLAN Header (8B)                         |
|  Flags(8b)=0x08 | R(24b)=0 | VNI(24b) | R(8b)=0                 |
+------------------------------------------------------------------+
|                     Inner Ethernet Header                         |
|  Dst MAC (6B) | Src MAC (6B) | EtherType (2B) | VLAN (opt)      |
+------------------------------------------------------------------+
|                        Inner Payload (L2/L3/L4...)                |
|  Inner IP | Inner TCP/UDP | Application Data                     |
+------------------------------------------------------------------+
|                              FCS (4B)                            |
+------------------------------------------------------------------+
```

**封装开销**：50B（无 VLAN）或 54B（有 VLAN），Jumbo MTU 必须支持。

### 1.3 VXLAN Header 格式 (8 Bytes)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|R|R|R|R|I|R|R|R|            Reserved                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                VXLAN Network Identifier (VNI) |   Reserved    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 值 | 说明 |
|------|------|----|------|
| Flags[7:4] | 4b | `0000` | 保留，必须为 0 |
| **I (Flag)** | 1b | `1` | VXLAN 标志位，标识报文为 VXLAN 封装 |
| Flags[2:0] | 3b | `000` | 保留，必须为 0 |
| Reserved | 24b | `0x000000` | 保留字段 |
| **VNI** | 24b | `VXLAN ID` | 虚拟网络标识，0x000001 ~ 0xFFFFFF |
| Reserved | 8b | `0x00` | 保留字段 |

**IC 设计要点**：
- 8B 固定头，解码简单（仅需解析 I flag 和 24-bit VNI）
- VNI 可直接作为查表 key，位宽 24-bit，需映射到本地端口表
- Flags 字段可做硬连线校验（非 `0x08` 则报错）

### 1.4 VTEP (VXLAN Tunnel Endpoint) 功能

VTEP 是 VXLAN 网络的边缘设备，承担封装/解封装核心功能：

```
                  VTEP 功能框图

  本地网络 (L2)                    Overlay 网络 (L3)
       |                                 |
       v                                 v
  +----------+    查 VNI 表     +------------------+
  | Inner L2 |  --------->     | VXLAN 封装引擎    |
  | Frame    |                 | +Outer IP/UDP     |
  +----------+                 | +VXLAN Header     |
       ^                       | +VNI 插入         |
       |                       +------------------+
  +----------+                          |
  | 解封装后  |  <---------  VXLAN 报文 |
  | L2 Frame |    查 VNI 表              |
  +----------+
```

**VTEP 核心功能表**：

| 功能 | 说明 |
|------|------|
| 封装 | Inner L2 Frame + VXLAN Header + Outer UDP/IP/Ethernet |
| 解封装 | 剥离外层，恢复 Inner L2 Frame，转发到本地端口 |
| VNI 映射 | VNI ↔ 本地 VLAN / Port 映射表 |
| MAC 学习 | 源 MAC 学习（控制面或数据面） |
| ARP 代理 | 减少广播流量，VTEP 可代理 ARP 应答 |

### 1.5 VXLAN 传输流程

```
 Host A (10.1.1.1)          VTEP-1              VTEP-2          Host B (10.1.1.2)
       |                       |                    |                |
       | Inner L2 Frame        |                    |                |
       | Dst=B_MAC, Src=A_MAC  |                    |                |
       | Dst=10.1.1.2, Src=10.1.1.1                |                |
       |---------------------->|                    |                |
       |                       |                    |                |
       |                 查 VNI 表                  |                |
       |                 封装 VXLAN:                |                |
       |                 Outer: Src=VTEP1_IP        |                |
       |                 Outer: Dst=VTEP2_IP        |                |
       |                 Outer: DPort=4789          |                |
       |                 VXLAN: VNI=10000           |                |
       |                       |----UDP/IP 报文---->|                |
       |                       |                    |                |
       |                       |              解封装 VXLAN          |
       |                       |              查 VNI 表             |
       |                       |              恢复 Inner L2 Frame   |
       |                       |                    |--------------->|
       |                       |                    |  Inner L2 Frame|
       |                       |                    |<---------------|
       |<----------------------------------------- UDP/IP 报文 -----|
       | 解封装                  |                    |               |
       |<----------------------|                    |               |
  Inner L2 Reply
```

### 1.6 多播 vs 头端复制 (BUM 流量处理)

BUM = **B**roadcast + **U**nknown-unicast + **M**ulticast

| 处理方式 | 机制 | 优点 | 缺点 |
|----------|------|------|------|
| **多播复制** | VTEP 加入多播组，BUM 流量发到多播组 | 交换网络内高效复制 | 需要底层网络支持多播（IGMP/PIM） |
| **头端复制 (Head-End Replication)** | 源 VTEP 逐一单播复制到所有远端 VTEP | 无需底层多播支持 | N 个 VTEP = N 份复制，可扩展性差 |

**头端复制流程**（IC 设计重点关注）：

```
                    VTEP-1 (源)
                       |
                 BUM Frame 到达
                       |
              查 Egress VTEP 列表
                       |
            +----------+----------+
            |          |          |
          单播复制   单播复制   单播复制
            v          v          v
          VTEP-2    VTEP-3    VTEP-4
```

**IC 设计要点**：
- 头端复制需要 **复制引擎**，支持 1-to-N 帧复制
- 复制份数受 VTEP 列表大小限制，需参数化设计
- 每份复制需更新 Outer Dst IP / Src UDP Port（RSS hash）
- 多播方式需要芯片支持 IGMP snooping + PIM

### 1.7 VXLAN-GPE (Generic Protocol Extension)

VXLAN-GPE 在 VXLAN 基础上扩展，支持封装 **L3 协议**（不仅限于 L2）：

```
 VXLAN-GPE Header (8B):

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|R|R|R|R|I|P|R|R|     Next Protocol     |      Reserved        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                VXLAN Network Identifier (VNI) |   Reserved    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 标志 | 说明 |
|------|------|
| I | VXLAN 标志位（同 VXLAN） |
| **P** | Next Protocol 字段有效标志 |
| Next Protocol | 8-bit，标识封装的协议类型：1=IPv4, 2=IPv6, 3=Ethernet, 4=NSH |

- GPE 头的 UDP DPort 仍是 4789（与 VXLAN 共用）
- 可以直接封装 IP 报文（跳过 Inner Ethernet），减少开销

---

## 2. GENEVE (Generic Network Virtualization Encapsulation, RFC 8926)

### 2.1 协议概述

GENEVE 是 VXLAN 的增强版，核心特性是 **可扩展 TLV (Type-Length-Value) 选项头**，允许在隧道头中携带任意元数据。

- 与 VXLAN 共享 VNI 概念（24-bit）
- 支持加密、遥测、安全策略等可扩展元数据
- 正在逐步替代 VXLAN 成为新一代隧道标准（OVS/DPDK 已支持）

### 2.2 封装格式

```
+------------------------------------------------------------------+
|                        Outer Ethernet Header                      |
+------------------------------------------------------------------+
|                          Outer IP Header (v4/v6)                  |
+------------------------------------------------------------------+
|                           Outer UDP Header                        |
|  Src Port (2B) | Dst Port = 6081 (2B) | Length | Checksum        |
+------------------------------------------------------------------+
|                      GENEVE Header (8B fixed)                     |
+------------------------------------------------------------------+
|                   GENEVE Options (0~260B, optional)               |
+------------------------------------------------------------------+
|                        Inner Payload                              |
+------------------------------------------------------------------+
```

**封装开销**：最小 50B（无选项），最大 310B（260B 选项 + 50B 固定头）

### 2.3 GENEVE Header 格式 (8 Bytes)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Ver=0 |Opt Len (6b)|O|  R (5b)|     Protocol Type (16b)       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Virtual Network Identifier (VNI) (24b)  |   Reserved   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Variable Options (0~260B)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| **Ver** | 2b | 版本号，当前 `00` |
| **Opt Len** | 6b | 选项长度，单位 = 4 字节（0 = 无选项，最大 63 = 252B，实测最大支持 64 = 256B 粒度，总选项 ≤ 260B） |
| **O** | 1b | OAM 包标识，`1` = OAM 控制帧 |
| R | 5b | 保留 |
| **Protocol Type** | 16b | 内层协议类型（同 EtherType）：`0x6558` = Ethernet, `0x0800` = IPv4, `0x86DD` = IPv6 |
| **VNI** | 24b | 虚拟网络标识 |
| Reserved | 8b | 保留 |

**IC 设计要点**：
- Opt Len 字段决定后续可变长选项的字节数：`Options Bytes = Opt Len × 4`
- Protocol Type 字段让 GENEVE 可同时封装 L2 和 L3 报文
- Header 总长 = 8 + Opt Len × 4 字节，需动态解析

### 2.4 TLV Option 格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Option Class        |C|    Type     |    R (3b) |Len|
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Variable Data...                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| **Option Class** | 16b | 选项类别（IANA 分配） |
| **C (Critical)** | 1b | 接收方不识别时：`0` = 忽略，`1` = 丢弃报文 |
| **Type** | 8b | 选项类型 |
| R | 3b | 保留 |
| **Len** | 5b | 数据长度（单位 = 4 字节，不含 TLV 头） |
| **Variable Data** | 0~124B | 选项数据 |

**已定义的 Option Class**：

| Class | 用途 |
|-------|------|
| `0x0100` | 传输优化（如 Telemetry） |
| `0x0104` | 交换机安全策略 |
| `0x0108` | 加密元数据 |

**IC 设计要点**：
- TLV 解析需要状态机逐项跳转，每项长度可变
- Critical bit 处理逻辑：不识别且 C=1 时必须丢弃
- 选项解析深度受限于 Opt Len，可设定最大支持选项数

### 2.5 VXLAN vs GENEVE 对比

| 特性 | VXLAN (RFC 7348) | GENEVE (RFC 8926) |
|------|-------------------|-------------------|
| UDP DPort | **4789** | **6081** |
| 固定头长度 | 8B | 8B |
| 可扩展选项 | 无 | TLV，最大 ~260B |
| 最大封装开销 | ~50B | ~310B |
| VNI 位宽 | 24-bit | 24-bit |
| 协议类型字段 | 无（仅 Ethernet） | 有（EtherType，支持 L2/L3） |
| OAM 支持 | 无 | O flag 标识 |
| 选项版本控制 | 无 | Ver 字段 |
| 硬件支持度 | 广泛（商用芯片均已支持） | 逐步增加（部分芯片支持） |
| 解析复杂度 | 简单（固定 8B） | 复杂（需 TLV 状态机） |
| 适用场景 | 简单 overlay | 需要元数据扩展的场景 |

---

## 3. 其他隧道协议简述

### 3.1 NVGRE (RFC 7637)

基于 **GRE 封装**的网络虚拟化方案：

```
Outer Ethernet | Outer IP | GRE Header (4B) | VSID (24b in Key) | Inner Ethernet
```

- **VSID (Virtual Subnet ID)**：24-bit，嵌入 GRE Key 字段
- **外层 IP 协议号**：47 (GRE)
- **特点**：无 UDP 端口，某些 ECMP 设备无法基于五元组做 hash
- **现状**：Microsoft Hyper-V 使用，市场份额小于 VXLAN

### 3.2 STT (Stateless Transport Tunneling)

将 L2 帧封装在 **伪 TCP** 报文中：

- 使用 TCP-like 头，可利用现有 ECMP/负载均衡设备
- 外层 DPort = 7471
- NIC 可利用 TCP Segmentation Offload (TSO) 优化性能
- **现状**：主要在 VMware NSX 中使用，已逐渐被 VXLAN 取代

### 3.3 IPSec Tunnel Mode

在 IP 层提供 **加密 + 完整性保护**：

```
Outer Ethernet | Outer IP | ESP Header | Encrypted{Inner IP | Inner Payload} | ESP Trailer | ESP Auth
```

- 与 VXLAN/GENEVE 配合使用（VXLAN over IPSec）
- 增加 ~50~70B 开销（ESP 头 + IV + Auth Tag + Padding）
- 需要 Crypto Engine，加解密延迟显著

---

## 4. 设计注意事项（交换芯片 / NIC 隧道处理）

### 4.1 封装 / 解封装引擎设计

**封装引擎流程**：

```
Inner Frame ──→ [Parse Inner L2/L3] ──→ [Lookup VNI/Egress Info]
                                            │
                                            v
                               [Build VXLAN/GENEVE Header]
                                            │
                                            v
                               [Build Outer UDP Header]
                                     (SrcPort = hash)
                                     (DstPort = 4789/6081)
                                            │
                                            v
                               [Build Outer IP Header]
                                     (SrcIP/DstIP)
                                     (Proto=17, TTL=255)
                                            │
                                            v
                               [Build Outer Ethernet Header]
                                     (SrcMAC/DstMAC/VLAN)
                                            │
                                            v
                               [UDP Checksum (optional)]
                                            │
                                            v
                                      Outer Frame ──→ 端口输出
```

**解封装引擎流程**：

```
Outer Frame ──→ [Parse Outer Ethernet]
                    │
                    v
               [Parse Outer IP → Proto=17?]
                    │
                    v
               [Parse Outer UDP → DPort=4789/6081?]
                    │
                    v
               [Parse VXLAN/GENEVE Header → Extract VNI]
                    │
                    v
               [VNI + Outer SrcIP → 本地映射表查表]
                    │
                    v
               [Strip Outer Headers] ──→ [Parse Inner L2/L3]
                                              │
                                              v
                                        Inner Frame ──→ 转发引擎
```

### 4.2 VTEP 表（VNI 到本地端口映射）

VTEP 表是隧道处理的核心查表结构：

| Key 字段 | 值宽 | Value 字段 | 说明 |
|----------|------|------------|------|
| Outer Src IP + VNI | 32+24 bit | Local Port / VLAN | 解封装方向：远端 VTEP + VNI → 本地出口 |
| VNI + Dst MAC | 24+48 bit | Egress VTEP IP List | 封装方向：内层目标 MAC → 远端 VTEP 列表 |
| VNI + Dst MAC | 24+48 bit | Local Port | 本地转发：内层目标 MAC → 本地端口 |

**实现方式**：

| 方案 | 容量 | 延迟 | 适用 |
|------|------|------|------|
| TCAM | 大，通配支持 | 1 cycle | 企业级交换芯片 |
| Hash Table (SRAM) | 中 | 2~4 cycle（含冲突处理） | 数据中心交换芯片 |
| LPM (Longest Prefix Match) | 大 | 多级 pipeline | 需要 IP 前缀匹配时 |

### 4.3 外层 UDP 校验和计算

VXLAN/GENEVE 的外层 UDP Checksum 有特殊处理：

- **VXLAN**：RFC 7348 规定外层 UDP Checksum **可设为 0**（表示不校验），但许多实现会计算
- **GENEVE**：RFC 8926 建议计算 UDP Checksum（尤其 IPv6 场景必选）
- **计算方式**：对 VXLAN/GENEVE 头 + Inner Payload 做 pseudo-header checksum

**IC 设计要点**：
- Checksum 计算需要遍历整个 Inner Payload，延迟较大
- 建议使用 **流式 checksum 模块**（pipeline，每 cycle 处理 16-bit）
- 或利用 NIC offload（硬件 checksum generation）

### 4.4 Inner L2/L3 解析（双层报头解析）

隧道报文需要解析 **两层报头**：

```
解析阶段：外层 Ether → 外层 IP → 外层 UDP → VXLAN/GENEVE Header
          → 内层 Ether → 内层 IP → 内层 TCP/UDP → 载荷
```

**IC 设计要点**：
- 解析器需要支持 **多级 header 解析**，可复用标准报文解析引擎
- 内层解析的起始偏移量由外层头总长决定（VXLAN 固定 50B，GENEVE 可变）
- 内层 EtherType 可能为 VLAN tagged（802.1Q/802.1ad），需支持嵌套解析
- ACL / QoS 分类需基于 **内层五元组**（解封装后），而非外层

### 4.5 Jumbo MTU 处理

隧道封装增加 50~80+ 字节开销，标准 1500B MTU 无法承载：

| 场景 | Inner MTU | 封装开销 | 外层 MTU 需求 |
|------|-----------|----------|---------------|
| VXLAN, 无 VLAN | 1500B | 50B | **1550B** |
| VXLAN, 有 VLAN | 1500B | 54B | **1554B** |
| VXLAN + IPSec | 1500B | 50+60B ≈ 110B | **1610B** |
| GENEVE + Options | 1500B | 50+260B = 310B | **1810B** |
| 建议通用值 | 1500B | 最大 ~310B | **>= 2000B** |

**设计建议**：
- 底层物理端口必须支持 **Jumbo Frame**（建议 >= 9216B）
- NIC / 交换芯片的 MTU 寄存器需区分 Inner/Outer MTU
- 支持 Inner 报文的分片/重组（DF=0 时），避免因封装超长导致丢包

### 4.6 与 QoS 的配合（Outer DSCP 映射）

隧道封装后，Inner 报文的优先级信息不可见，需要显式映射：

**映射方向**：

| 方向 | 操作 | 说明 |
|------|------|------|
| 封装 (Ingress → Egress) | Inner DSCP → Outer DSCP | 从内层 IP TOS 提取 DSCP，写入外层 IP TOS |
| 封装 | Inner 802.1p → Outer DSCP | VLAN PCP 到 DSCP 的映射（需要映射表） |
| 解封装 (Ingress → Egress) | Outer DSCP → 内部队列调度 | 利用外层 DSCP 做入队优先级判断 |
| 解封装 | Outer DSCP → Inner DSCP | 恢复（可选，或保留 Inner 原值） |

**IC 设计要点**：
- DSCP 映射表需可编程（6-bit → 6-bit，64 项）
- Outer DSCP 对应的 ECN 需要与 Inner ECN 协同（RFC 6040 ECN tunneling）
- 封装后外层 IP 的 ECN 字段 = Inner ECN + Outer ECN 的逐跳行为协同

---

## 5. IC 设计架构小结

| 模块 | 核心功能 | 关键指标 |
|------|----------|----------|
| 封装引擎 | Inner + VXLAN/GENEVE Header + Outer | 线速封装，1 cycle/pkt |
| 解封装引擎 | 剥离外层，提取 VNI，解析内层 | 多级 header 解析延迟 |
| VTEP 表 | VNI+MAC → Egress VTEP / Local Port | 查表延迟 ≤ 2 cycles |
| 选项解析 (GENEVE) | TLV 状态机，Critical bit 处理 | 最大选项数可参数化 |
| Checksum 引擎 | 外层 UDP/IP 校验和计算 | 流式，pipeline 设计 |
| 复制引擎 | BUM 头端复制，1-to-N | 支持 N 个对端 VTEP |
| DSCP 映射 | Inner→Outer 优先级传递 | 64 项可编程映射表 |
| MTU 管理 | Inner/Outer MTU 检查，分片处理 | 支持 >= 9216B Jumbo |
