# IP (IPv4/IPv6) 协议知识文档

> 面向数字 IC 设计架构师的参考文档
> 标准来源：RFC 791 (IPv4)、RFC 8200 (IPv6)

---

## 1. 协议概述

Internet Protocol (IP) 是网络层（Layer 3）的核心协议，提供无连接、尽力而为（best-effort）的数据报传输服务。

**核心特征**：
- **无连接**：不维护端到端会话状态，每个数据报独立路由
- **不可靠**：不保证送达、不保证顺序、不保证无重复；可靠性由上层（TCP）保障
- **分片/重组**：支持在中间节点分片，目的节点重组（IPv6 仅源端分片）
- **版本共存**：IPv4（32-bit 地址，RFC 791）和 IPv6（128-bit 地址，RFC 8200）

**在协议栈中的位置**：
```
┌──────────────────────────┐
│  Application (HTTP/FTP)  │
├──────────────────────────┤
│  Transport (TCP/UDP)     │
├──────────────────────────┤
│  Network (IP)            │  ← 本文档重点
├──────────────────────────┤
│  Data Link (Ethernet)    │
├──────────────────────────┤
│  Physical                │
└──────────────────────────┘
```

---

## 2. IPv4 报头格式

最小 20 字节，最大 60 字节（含 Options）。每行 32 bit（4 字节）。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version|  IHL  |      TOS      |         Total Length          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Identification        |Flags|    Fragment Offset      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Time to Live |    Protocol   |       Header Checksum         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Source Address                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Destination Address                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Options (if IHL > 5)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

---

## 3. IPv4 各字段详解

| 字段 | 位宽 | 说明 |
|------|------|------|
| **Version** | 4 bit | 固定为 `4'b0100` |
| **IHL** | 4 bit | Internet Header Length，报头长度（以 4 字节为单位）。最小值 5（20 字节），最大值 15（60 字节） |
| **TOS** | 8 bit | Type of Service。前 6 bit 为 DSCP（Differentiated Services Code Point，用于 QoS 优先级），后 2 bit 为 ECN（Explicit Congestion Notification） |
| **Total Length** | 16 bit | 整个 IP 包长度（报头 + 载荷），最大 65535 字节 |
| **Identification** | 16 bit | 分片标识符。同一原始包的所有分片共享相同 ID |
| **Flags** | 3 bit | Bit 0: 保留（必须为 0）；Bit 1: DF（Don't Fragment，1=禁止分片）；Bit 2: MF（More Fragments，1=后面还有分片） |
| **Fragment Offset** | 13 bit | 分片偏移（以 8 字节为单位），指示本分片在原始包中的位置 |
| **TTL** | 8 bit | Time To Live。每经过一个路由器减 1，减到 0 则丢弃并发送 ICMP Time Exceeded |
| **Protocol** | 8 bit | 上层协议号。ICMP=1、TCP=6、UDP=17 |
| **Header Checksum** | 16 bit | 仅校验报头（不含载荷）。每跳重新计算（因 TTL 递减） |
| **Source Address** | 32 bit | 源 IP 地址 |
| **Destination Address** | 32 bit | 目的 IP 地址 |
| **Options** | 可变 | 可选字段，如 Record Route、Timestamp、Source Route 等。IC 设计中通常不处理或透传 |

**TOS 字段细分**：
```
 0   1   2   3   4   5   6   7
+---+---+---+---+---+---+---+---+
|     DSCP (6 bit)      |ECN(2)|
+---+---+---+---+---+---+---+---+
```

**Protocol 常用编号**：
| 编号 | 协议 |
|------|------|
| 1 | ICMP |
| 2 | IGMP |
| 6 | TCP |
| 17 | UDP |
| 41 | IPv6 encapsulation |
| 47 | GRE |
| 50 | ESP (IPsec) |
| 51 | AH (IPsec) |
| 89 | OSPF |

---

## 4. IPv4 地址格式

**基本格式**：32 bit，点分十进制表示，如 `192.168.1.1`

**地址分类**（传统分类，已被 CIDR 取代）：

| 类别 | 首位 | 地址范围 | 默认掩码 | 用途 |
|------|------|----------|----------|------|
| A | 0 | 1.0.0.0 - 126.255.255.255 | /8 | 大型网络 |
| B | 10 | 128.0.0.0 - 191.255.255.255 | /16 | 中型网络 |
| C | 110 | 192.0.0.0 - 223.255.255.255 | /24 | 小型网络 |
| D | 1110 | 224.0.0.0 - 239.255.255.255 | - | 组播 |
| E | 1111 | 240.0.0.0 - 255.255.255.255 | - | 保留 |

**私有地址范围**（RFC 1918）：
- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`

**CIDR 表示法**：`地址/前缀长度`，如 `192.168.1.0/24`
- 子网掩码由连续的 1 组成，如 `/24` = `255.255.255.0`
- 网络地址 = IP & 子网掩码
- 广播地址 = 网络地址 | (~子网掩码)
- 可用主机数 = 2^(32 - 前缀长度) - 2

---

## 5. IPv4 分片与重组

**分片条件**：IP 包大小 > 出接口 MTU（通常 Ethernet MTU = 1500 字节）

**分片机制**：
1. 发送方设置 **Identification**（同一原始包的所有分片相同）
2. 每个分片设置 **Fragment Offset**（以 8 字节为单位）
3. 除最后一个分片外，设置 **MF (More Fragments) = 1**
4. 每个分片的 **Total Length** 包含该分片自身的长度
5. 分片偏移必须 8 字节对齐（除最后一个分片外）

**示例**：4000 字节数据 + 20 字节报头 = 4020 字节，MTU = 1500

| 分片 | Total Length | MF | Fragment Offset | 数据范围 |
|------|-------------|-----|-----------------|----------|
| 1 | 1500 | 1 | 0 | 0 - 1479 |
| 2 | 1500 | 1 | 185 (=1480/8) | 1480 - 2959 |
| 3 | 1060 | 0 | 370 (=2960/8) | 2960 - 4019 |

**DF 与路径 MTU 发现**：
- 发送方设置 DF = 1，若路由器需要分片则丢弃并返回 ICMP "Fragmentation Needed"
- 发送方据此降低 MTU，直至路径通畅

**IC 设计要点**：
- 分片逻辑需要缓存原始包 + 重新计算每片的 Total Length / Offset / Checksum
- 重组逻辑需要按 Identification 聚合、按 Offset 排序、拼装后上交
- 重组超时：RFC 791 建议至少 15 秒，实际芯片中用计数器实现

---

## 6. IPv6 报头格式

固定 40 字节，比 IPv4 更规整，便于硬件解析。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version| Traffic Class |           Flow Label                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Payload Length        |  Next Header  |   Hop Limit   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
+                                                               +
|                                                               |
+                         Source Address (128 bit)              +
|                                                               |
+                                                               +
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
+                                                               +
|                                                               |
+                      Destination Address (128 bit)            +
|                                                               |
+                                                               +
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| **Version** | 4 bit | 固定为 `4'b0110` |
| **Traffic Class** | 8 bit | 类似 IPv4 TOS，前 6 bit DSCP + 后 2 bit ECN |
| **Flow Label** | 20 bit | 标识同一数据流，路由器可据此做相同路径转发（per-flow QoS） |
| **Payload Length** | 16 bit | 扩展头 + 上层载荷的总长度（不含基本报头 40 字节） |
| **Next Header** | 8 bit | 指示下一个头类型：扩展头编号或上层协议号（如 TCP=6、UDP=17） |
| **Hop Limit** | 8 bit | 等同 IPv4 TTL，每跳减 1 |
| **Source Address** | 128 bit | 源 IPv6 地址 |
| **Destination Address** | 128 bit | 目的 IPv6 地址 |

**IC 设计要点**：
- 40 字节固定长度 = 正好 10 个 32-bit word，硬件解析简单
- 无需校验和计算（IPv6 去掉了 Header Checksum，依赖上层和链路层校验）
- Next Header 链式解析是 IPv6 硬件设计的核心挑战

---

## 7. IPv6 扩展头链

IPv6 通过 **Next Header** 字段链式串联扩展头，取代 IPv4 的 Options。

**扩展头类型与编号**：

| 编号 | 扩展头名称 | 位置 |
|------|-----------|------|
| 0 | Hop-by-Hop Options | 紧跟基本报头 |
| 43 | Routing | Hop-by-Hop 之后 |
| 44 | Fragment | Routing 之后 |
| 60 | Destination Options | Fragment 之后 |
| 6 | TCP | 上层协议（终止链） |
| 17 | UDP | 上层协议（终止链） |

**推荐处理顺序**：
```
IPv6 Basic Header (40B)
  → Next Header = 0  → Hop-by-Hop Options
    → Next Header = 43 → Routing Header
      → Next Header = 44 → Fragment Header
        → Next Header = 60 → Destination Options
          → Next Header = 6  → TCP Header
            → Payload
```

**IC 设计要点**：
- 需要逐级解析 Next Header，直到识别上层协议
- 最大扩展头链深度需设定硬件限制（典型值 4-6 级）
- Fragment 扩展头仅在源端使用，路由器不做 IPv6 分片

---

## 8. IPv6 地址格式

**128 bit**，冒号十六进制表示，8 组 4 位十六进制数。

**完整格式**：
```
2001:0db8:0000:0000:0000:0000:0000:0001
```

**零压缩**（每个地址只能用一次 `::`）：
```
2001:db8::1
```

**地址类型**：

| 类型 | 前缀 | 说明 |
|------|------|------|
| 全局单播 (GUA) | `2000::/3` | 全球可达，等同公网 IP |
| 链路本地 (LLA) | `fe80::/10` | 仅同一链路，自动生成 |
| 唯一本地 (ULA) | `fc00::/7` | 私有地址 |
| 组播 | `ff00::/8` | 一对多通信 |
| 回环 | `::1/128` | 等同 127.0.0.1 |
| 未指定 | `::/128` | 等同 0.0.0.0 |

**接口标识符**：后 64 bit 通常由 EUI-64 或 SLAAC 生成。

---

## 9. IPv4 vs IPv6 对比表

| 对比项 | IPv4 | IPv6 |
|--------|------|------|
| 地址长度 | 32 bit | 128 bit |
| 地址空间 | ~43 亿 (2^32) | ~3.4×10^38 (2^128) |
| 报头长度 | 20-60 字节（变长） | 40 字节（固定） |
| 报头校验和 | 有（每跳重算） | 无（依赖链路层/传输层） |
| 分片 | 路由器和源端均可 | 仅源端 |
| Options | 报头内 Options 字段 | 扩展头链 |
| 广播 | 支持 | 不支持（用组播替代） |
| 组播 | 可选 | 内置必选 |
| IPSec | 可选 | 内置必选 |
| QoS | TOS 字段 | Traffic Class + Flow Label |
| 自动配置 | DHCP | SLAAC / DHCPv6 |
| 邻居发现 | ARP (广播) | NDP (组播 ICMPv6) |
| 硬件解析复杂度 | 较高（变长报头+Options） | 较低（固定报头） |

---

## 10. NAT (Network Address Translation)

**目的**：在私有地址与公网地址之间转换，缓解 IPv4 地址枯竭。

**三种主要类型**：

### SNAT (Source NAT)
- 将内部源 IP 替换为公网 IP
- 出方向修改 Source Address

### DNAT (Destination NAT)
- 将外部目的 IP 替换为内部 IP
- 入方向修改 Destination Address
- 典型应用：端口映射、DMZ

### NAPT (Network Address Port Translation / PAT)
- 同时转换 IP 地址 + 端口号
- 一个公网 IP 可复用 65535 个连接
- 映射表：`(内部IP:端口) ↔ (公网IP:端口)`

**IC 设计要点**：
- NAT 表查找：5 元组（SrcIP, DstIP, SrcPort, DstPort, Protocol）匹配
- 需要重新计算 IP Header Checksum 和 TCP/UDP Checksum
- NAPT 表项数量决定 SRAM/TCAM 容量需求
- 连接跟踪（conntrack）：需要超时老化机制

---

## 11. 路由基础

### 路由表
每条路由表项包含：目的网络前缀、前缀长度、下一跳地址、出接口、度量值。

```
目的网络          下一跳        出接口   度量
10.0.0.0/8       192.168.1.1   eth0     10
172.16.0.0/12    192.168.1.2   eth1     20
0.0.0.0/0        192.168.1.254 eth0     100  ← 默认路由
```

### 最长前缀匹配 (LPM)
- 多条路由可能匹配同一目的地址时，选择**前缀最长**的条目
- 例：目的地址 `10.1.2.3`，匹配 `10.0.0.0/8` 和 `10.1.0.0/16`，选择 `/16`
- **核心算法**：TCAM（Ternary CAM）查表、或 Trie 树（基数树）软件查找

### 下一跳解析
1. 路由表查找得到下一跳 IP
2. ARP/NDP 查找得到下一跳 MAC
3. 修改 TTL（递减）、重算 Header Checksum
4. 重写目的 MAC，从出接口发送

---

## 12. ECN (Explicit Congestion Notification)

**位置**：IP 报头 TOS 字段的最低 2 bit（IPv4）或 Traffic Class 的最低 2 bit（IPv6）。

**编码**：

| ECN 值 | 含义 |
|--------|------|
| `00` | Not-ECT（不支持 ECN） |
| `01` | ECT(1)（支持 ECN） |
| `10` | ECT(0)（支持 ECN） |
| `11` | CE（Congestion Experienced，路由器标记拥塞） |

**工作流程**：
1. 发送方设置 ECT(0) 或 ECT(1) 标记
2. 路由器发生拥塞时，将 ECN 改写为 CE（`11`）
3. 接收方在 TCP ACK 中回传 ECE 标记
4. 发送方降低发送速率，并发送 CWR 确认

**IC 设计要点**：
- 路由器/交换机需要队列深度阈值判断，达到阈值时标记 CE
- 需要修改 IP 报头并更新 Header Checksum（IPv4）
- ECN 仅在双方都支持时才生效

---

## 13. 设计注意事项

### 13.1 报头解析

| 要点 | 说明 |
|------|------|
| 版本判断 | 首 4 bit 区分 IPv4/IPv6，分别进入不同解析流水线 |
| 报头长度 | IPv4 由 IHL 确定（20-60 字节），IPv6 固定 40 字节 + 扩展头链 |
| 提取 5 元组 | SrcIP, DstIP, SrcPort, DstPort, Protocol（从 TCP/UDP 头提取端口） |
| 流水线设计 | 报头解析应为 1-2 级流水线，避免成为关键路径 |

### 13.2 TTL 递减与校验和更新

```
// IPv4: TTL 递减 + Checksum 增量更新
// 旧 Checksum + 旧 TTL 高 8 bit 值 → TTL 减 1 后增量修正
new_checksum = old_checksum + (old_ttl << 8) - ((old_ttl - 1) << 8);
// 或简写为：new_checksum = old_checksum + 0x0100;
// 注意进位回卷
```

- IPv6 无需校验和更新（Hop Limit 递减后直接修改，无 Checksum）
- 这是 IPv6 硬件设计的优势之一

### 13.3 分片与重组

- **发送侧**：MTU 检测 → 分片引擎 → 为每个分片生成独立报头
- **接收侧**：按 (SrcIP, DstIP, Protocol, Identification) 聚合 → 按 Fragment Offset 重组 → 超时释放
- 重组缓冲区大小和超时策略是面积/性能权衡的关键

### 13.4 LPM 查找算法

| 算法 | 介质 | 优点 | 缺点 |
|------|------|------|------|
| TCAM | 专用 SRAM | 单周期查找，确定性延迟 | 面积大、功耗高 |
| 基数树 (Trie) | SRAM | 面积小、可扩展 | 多次访存、延迟不确定 |
| 哈希 + TCAM 混合 | SRAM + TCAM | 平衡面积和性能 | 设计复杂 |

### 13.5 IPv6 处理

- 无 Header Checksum → 处理延迟更低
- 扩展头链解析 → 需设计 Next Header 递归/迭代解析器
- 128-bit 地址 → LPM 表项更大，TCAM 面积更大
- Flow Label → 可用于快速流分类，避免完整 5 元组匹配

### 13.6 DSCP 优先级映射 QoS

```
DSCP (6 bit) → 内部优先级队列索引
典型映射（8 级队列）：
  DSCP 0-7   → Queue 0 (Best Effort)
  DSCP 8-15  → Queue 1
  DSCP 16-23 → Queue 2
  ...
  DSCP 46    → Queue 7 (EF - Expedited Forwarding)
  DSCP 48    → Queue 7 (CS6 - 网络控制)
```

### 13.7 与 MAC/传输层接口

```
MAC → IP 层接口：
  - 输入：帧头已剥离，payload 从 IP 报头开始
  - 输出：IP 包准备好后交 MAC 添加帧头

IP → Transport 层接口：
  - 输入：IP 报头已解析，5 元组 + payload 传递给上层
  - 输出：上层数据 + 5 元组，IP 层封装报头
```

---

## 14. 封装格式

完整的 Ethernet II / IP / TCP/UDP 封装结构：

```
┌─────────────────────────────────────────────────────────────┐
│ Ethernet II Frame (以太网帧)                                │
│ ┌──────────┬──────────┬────────┬─────────────────┬───────┐ │
│ │ Dst MAC  │ Src MAC  │EtherType│                 │  FCS  │ │
│ │  6 byte  │  6 byte  │ 2 byte │                 │ 4 byte│ │
│ │          │          │ 0x0800 │                 │       │ │
│ └──────────┴──────────┴───┬────┘                 └───────┘ │
│                           │                                 │
│                    ┌──────▼──────────────────────────────┐  │
│                    │ IP Header (20-60 byte)              │  │
│                    │ ┌──────────────────────────────────┐│  │
│                    │ │ Version/IHL/TOS/Total Length     ││  │
│                    │ │ ID/Flags/Frag Offset             ││  │
│                    │ │ TTL/Protocol/Header Checksum     ││  │
│                    │ │ Source IP / Destination IP       ││  │
│                    │ └──────────────────┬───────────────┘│  │
│                    └────────────────────┬────────────────┘  │
│                                         │                   │
│                    ┌────────────────────▼────────────────┐  │
│                    │ TCP Header (20-60 byte)             │  │
│                    │ 或 UDP Header (8 byte)              │  │
│                    │ ┌──────────────────────────────────┐│  │
│                    │ │ Src Port / Dst Port              ││  │
│                    │ │ Seq Number / Ack Number (TCP)    ││  │
│                    │ │ Flags (TCP)                      ││  │
│                    │ │ Window / Checksum / Urgent       ││  │
│                    │ └──────────────────┬───────────────┘│  │
│                    └────────────────────┬────────────────┘  │
│                                         │                   │
│                    ┌────────────────────▼────────────────┐  │
│                    │ Payload (应用数据)                   │  │
│                    │ 46 - 1500 byte (MTU 限制)           │  │
│                    └─────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

EtherType 常用值：
  0x0800 = IPv4
  0x0806 = ARP
  0x86DD = IPv6
  0x8100 = VLAN (IEEE 802.1Q)
```

**最大/最小帧长**：
- 最小以太网帧：64 字节（含 14 字节帧头 + 4 字节 FCS，payload 最小 46 字节，不足需填充）
- 最大以太网帧：1518 字节（标准 MTU 1500 + 14 帧头 + 4 FCS）
- Jumbo Frame：9000 字节（非标准，需端到端协商）

---

## 参考标准

| RFC | 标题 | 说明 |
|-----|------|------|
| RFC 791 | Internet Protocol (IPv4) | IPv4 核心规范 |
| RFC 8200 | Internet Protocol Version 6 (IPv6) | IPv6 核心规范 |
| RFC 793 | Transmission Control Protocol (TCP) | TCP 协议规范 |
| RFC 768 | User Datagram Protocol (UDP) | UDP 协议规范 |
| RFC 2474 | Definition of the DS Field (DSCP) | DSCP 编码定义 |
| RFC 3168 | ECN for IP | ECN 规范 |
| RFC 1918 | Address Allocation for Private Internets | 私有地址定义 |
| RFC 4291 | IPv6 Addressing Architecture | IPv6 地址架构 |
| RFC 4443 | ICMPv6 | IPv6 控制消息 |
