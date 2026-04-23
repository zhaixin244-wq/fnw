# ARP / ICMP / IGMP 协议知识文档

> **面向读者**：数字 IC 设计架构师
> **用途**：NIC（网卡）/ 交换芯片 / 路由器芯片设计参考
> **语言**：中文为主，技术术语保留英文

---

## 1. ARP (Address Resolution Protocol)

### 1.1 协议概述

ARP 定义于 **RFC 826**，用于将 **IPv4 地址**解析为 **MAC 地址**（48-bit）。在以太网中，数据帧的转发依据是 MAC 地址而非 IP 地址，因此发送方必须先获取目标 IP 对应的 MAC 地址才能封装以太网帧。

- **协议号**：EtherType = `0x0806`
- **工作层次**：介于 Layer 2（Data Link）和 Layer 3（Network）之间
- **适用范围**：仅 IPv4；IPv6 使用 NDP（Neighbor Discovery Protocol）替代
- **报文封装**：ARP 报文直接封装在以太网帧的 payload 中，不经过 IP 层

### 1.2 ARP 报文格式

ARP 报文长度可变（取决于硬件地址和协议地址长度），以太网 + IPv4 场景下固定 **28 字节**。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Hardware Type         |         Protocol Type         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Hw Size       | Proto Size    |           Opcode              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Sender MAC (bytes 0-3)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Sender MAC (bytes 4-5)        |   Sender IP (0-1)     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Sender IP (bytes 2-3)       |   Target MAC (0-1)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Target MAC (bytes 2-5)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       Target IP                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 值（以太网 + IPv4） | 说明 |
|------|------|---------------------|------|
| Hardware Type (HTYPE) | 16 bit | `0x0001` (Ethernet) | 硬件地址类型 |
| Protocol Type (PTYPE) | 16 bit | `0x0800` (IPv4) | 协议地址类型 |
| Hardware Size (HLEN) | 8 bit | `6` | 硬件地址长度（MAC = 6 bytes） |
| Protocol Size (PLEN) | 8 bit | `4` | 协议地址长度（IPv4 = 4 bytes） |
| Opcode | 16 bit | 见下表 | 操作码 |
| Sender MAC | 48 bit | 发送方 MAC | |
| Sender IP | 32 bit | 发送方 IP | |
| Target MAC | 48 bit | 目标 MAC | 请求时填全 0 |
| Target IP | 32 bit | 目标 IP | |

**Opcode 定义**：

| Opcode | 含义 | 说明 |
|--------|------|------|
| 1 | ARP Request | 广播请求："谁拥有 Target IP？请告诉我" |
| 2 | ARP Reply | 单播应答："Target IP 是我的，我的 MAC 是 XXX" |
| 3 | RARP Request | 反向 ARP 请求（已废弃） |
| 4 | RARP Reply | 反向 ARP 应答（已废弃） |

### 1.3 ARP 请求 / 响应流程

典型场景：主机 A（192.168.1.10）要向主机 B（192.168.1.20）发送数据，但不知道 B 的 MAC 地址。

```
  Host A (192.168.1.10)              Network (Broadcast)           Host B (192.168.1.20)
       |                                    |                             |
       |  1. ARP Request (Broadcast)        |                             |
       |  Src MAC: AA:AA:AA:AA:AA:AA        |                             |
       |  Src IP:  192.168.1.10             |                             |
       |  Dst MAC: FF:FF:FF:FF:FF:FF        |                             |
       |  Dst IP:  192.168.1.20             |                             |
       |----------------------------------->|---------------------------->|  (广播到达所有主机)
       |                                    |                             |
       |                                    |  2. Host B 检查 Target IP   |
       |                                    |     匹配自身 IP，发送 Reply  |
       |                                    |                             |
       |  3. ARP Reply (Unicast)            |                             |
       |  Src MAC: BB:BB:BB:BB:BB:BB        |                             |
       |  Src IP:  192.168.1.20             |                             |
       |  Dst MAC: AA:AA:AA:AA:AA:AA        |                             |
       |  Dst IP:  192.168.1.10             |                             |
       |<-----------------------------------|-----------------------------|
       |                                    |                             |
       |  4. Host A 更新 ARP 缓存表         |                             |
       |     192.168.1.20 → BB:BB:BB:BB:BB:BB                            |
       |                                    |                             |
       |  5. 正常数据通信（使用已知 MAC）    |                             |
       |===================================>|=============================>|
```

**关键特征**：
- ARP Request 使用 **广播**（Dst MAC = `FF:FF:FF:FF:FF:FF`）
- ARP Reply 使用 **单播**（直接回复给请求方）
- 交换机对广播帧进行 **泛洪**（Flooding），所有端口都会收到
- 非目标主机收到 ARP Request 后检查 Target IP，不匹配则丢弃

### 1.4 ARP 缓存

每台主机维护一张 **ARP 缓存表**（ARP Cache / ARP Table），缓存 IP→MAC 映射，避免每次通信都发送 ARP 请求。

| 条目 | 说明 |
|------|------|
| IP Address | 目标 IPv4 地址 |
| MAC Address | 对应的 MAC 地址 |
| Interface | 网络接口 |
| Age / TTL | 剩余生存时间 |
| State | dynamic / static / incomplete / reachable |

**老化机制**：
- 动态条目有 **TTL**（Time To Live），典型超时值：
  - Linux 默认：`60s`（可通过 `/proc/sys/net/ipv4/neigh/<dev>/gc_stale_time` 调整）
  - Cisco IOS 默认：**4 小时**（14400s）
  - Windows 默认：**15 ~ 45 秒**（RFC 建议不超过 20 分钟）
- 超时后条目被删除，下次通信需重新 ARP
- 完成条目（complete）超时前如果无流量，转为 stale 状态
- **ARP 请求失败**时创建 incomplete 条目，重试若干次后删除

### 1.5 Gratuitous ARP（免费 ARP）

Gratuitous ARP 是一种特殊的 ARP 报文，**Target IP 填写自身 IP**，分为 Gratuitous Request 和 Gratuitous Reply。

```
Gratuitous ARP Request:
  Sender MAC: AA:AA:AA:AA:AA:AA
  Sender IP:  192.168.1.10
  Target MAC: 00:00:00:00:00:00  (或 FF:FF:FF:FF:FF:FF)
  Target IP:  192.168.1.10       (自身 IP)
```

**用途**：

| 用途 | 说明 |
|------|------|
| IP 冲突检测 | 主机获取 IP 后主动发送 GARP，若收到回复则说明 IP 冲突 |
| 更新邻居缓存 | 主机 MAC 变化或 IP 切换（如 VRRP/HSRP 切换）时，通知其他主机更新 ARP 表 |
| VLAN 场景 | 部分交换机用 GARP 触发 MAC 地址表刷新 |

### 1.6 代理 ARP（Proxy ARP）

当路由器/网关代替其他主机响应 ARP 请求时，称为 Proxy ARP。

```
  Host A (192.168.1.10)             Router (Proxy)           Host B (192.168.2.20)
       |                                |                          |
       | ARP Request:                   |                          |
       | "谁是 192.168.2.20?"           |                          |
       |------------------------------->|                          |
       |                                |                          |
       | ARP Reply:                     |  (代替 Host B 回复)      |
       | "192.168.2.20 的 MAC 是        |                          |
       |  路由器接口 MAC: RR:RR:RR:..." |                          |
       |<-------------------------------|                          |
       |                                |                          |
       | 数据发给路由器 MAC             |                          |
       |------------------------------->|---------> Host B         |
```

**典型场景**：
- 子网间通信：主机配置了错误的子网掩码时，路由器通过 Proxy ARP 代理转发
- 移动 IP：代理节点代替移动主机响应 ARP
- 部分 L3 交换机的 ARP 代理功能

### 1.7 设计注意事项（IC 设计视角）

| 主题 | 说明 |
|------|------|
| **ARP 表存储** | NIC/交换芯片需维护硬件 ARP 表（CAM/TCAM），典型容量 256 ~ 16K 条目。查找基于目标 IP 的精确匹配，适合用 Hash + CAM 实现 |
| **ARP 表老化** | 硬件定时器实现条目老化。IC 设计中需权衡定时器精度与面积：每条目独立定时器 vs 全局扫描定时器 |
| **ARP 代理** | L3 交换芯片需实现 ARP 代理逻辑：收到 ARP Request 时查路由表，若目标 IP 可达则用自身 MAC 回复 |
| **ARP 欺骗防护** | 硬件可实现：IP-MAC 绑定表（静态配置）、动态学习时检查 Sender IP 是否与已知条目冲突、异常 ARP 速率检测与限流 |
| **ARP 报文过滤** | 交换芯片需对 ARP 报文进行基本合法性检查：Opcode 只允许 1/2、HTYPE=Ethernet、PTYPE=IPv4 |
| **硬件加速** | 高速 NIC 可将 ARP 响应处理卸载到硬件（Offload），减少 CPU 中断。关键：ARP 表更新需与软件保持一致性 |
| **组播关联** | ARP Request 广播占用带宽，大规模网络中可结合 IGMP Snooping 限制广播域（但 ARP 本身非组播协议） |

---

## 2. ICMP (Internet Control Message Protocol)

### 2.1 协议概述

ICMP 定义于 **RFC 792**，是 IPv4 网络层的控制与诊断消息协议。ICMP 不用于数据传输，而是用于传递 **网络控制信息**（如目的不可达、超时、重定向等）。

- **协议号**：IP Protocol Number = `1`
- **工作层次**：网络层（Layer 3），封装在 IP 报文的 payload 中
- **特点**：ICMP 自身无端口号（Port），不基于 TCP/UDP
- **注意**：ICMP 报文本身也可被 ICMP 响应（如 ICMP 超时消息），但某些类型（如 Destination Unreachable）不会再触发 ICMP

### 2.2 ICMP 报文格式

ICMP 报文由 **8 字节头部** + **可变长度数据** 组成。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     Type      |     Code      |          Checksum             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Rest of Header (4 bytes)                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Data (variable)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| Type | 8 bit | 消息类型 |
| Code | 8 bit | 消息子类型（同一 Type 下的细分） |
| Checksum | 16 bit | ICMP 报文校验和（覆盖整个 ICMP 报文） |
| Rest of Header | 32 bit | 含义取决于 Type/Code（如 Echo 类含 Identifier + Sequence Number） |
| Data | 变长 | 通常包含触发 ICMP 的原始 IP 报文的前 28 字节（IP 头 20 + TCP/UDP 头 8） |

### 2.3 常用消息类型

| Type | Code | 名称 | 方向 | 说明 |
|------|------|------|------|------|
| 0 | 0 | **Echo Reply** | 响应 → | Ping 应答 |
| 3 | 0-15 | **Destination Unreachable** | 路由器 → | 目的不可达，Code 细分原因 |
| 5 | 0-3 | **Redirect** | 路由器 → | 重定向到更优网关 |
| 8 | 0 | **Echo Request** | 请求 → | Ping 请求 |
| 11 | 0-1 | **Time Exceeded** | 路由器 → | TTL 超时（Code 0=TTL 超时, 1=分片重组超时） |
| 12 | 0-2 | **Parameter Problem** | 路由器 → | IP 头部参数错误 |

**Destination Unreachable (Type 3) 细分**：

| Code | 含义 |
|------|------|
| 0 | Network Unreachable（网络不可达） |
| 1 | Host Unreachable（主机不可达） |
| 2 | Protocol Unreachable（协议不可达） |
| 3 | Port Unreachable（端口不可达） |
| 4 | Fragmentation Needed and DF Set（需要分片但设置了 DF） |
| 5 | Source Route Failed（源路由失败） |
| 6 | Destination Network Unknown |
| 7 | Destination Host Unknown |
| 13 | Communication Administratively Prohibited（管理禁止） |

**Echo Request/Reply (Type 8/0) 的 Rest of Header**：

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     Type      |     Code      |          Checksum             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Identifier          |        Sequence Number        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Data (payload)                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 说明 |
|------|------|
| Identifier | 标识 Ping 会话（通常为进程 PID） |
| Sequence Number | 序列号，递增编号 |

### 2.4 Ping 流程

Ping 使用 ICMP Echo Request / Echo Reply 测试主机可达性和往返延迟。

```
  Host A (192.168.1.10)                              Host B (192.168.1.20)
       |                                                    |
       |  1. ICMP Echo Request                               |
       |  IP: Src=192.168.1.10, Dst=192.168.1.20             |
       |  ICMP: Type=8, Code=0, Seq=1                        |
       |  ID=0x1234                                          |
       |---------------------------------------------------->|
       |                                                    |
       |  2. Host B 收到后立即回复                          |
       |                                                    |
       |  3. ICMP Echo Reply                                 |
       |  IP: Src=192.168.1.20, Dst=192.168.1.10             |
       |  ICMP: Type=0, Code=0, Seq=1                        |
       |  ID=0x1234                                          |
       |<----------------------------------------------------|
       |                                                    |
       |  4. Host A 计算 RTT                                |
       |     RTT = 收到时间 - 发送时间                      |
       |                                                    |
       |  (重复以上过程 N 次，如 N=4)                       |
       |                                                    |
```

**典型输出**：

```
PING 192.168.1.20 (192.168.1.20) 56(84) bytes of data.
64 bytes from 192.168.1.20: icmp_seq=1 ttl=64 time=0.456 ms
64 bytes from 192.168.1.20: icmp_seq=2 ttl=64 time=0.389 ms
64 bytes from 192.168.1.20: icmp_seq=3 ttl=64 time=0.412 ms

--- 192.168.1.20 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2048ms
rtt min/avg/max/mdev = 0.389/0.419/0.456/0.027 ms
```

### 2.5 Traceroute 原理

Traceroute 利用 **TTL 递增** + **ICMP Time Exceeded** 响应来发现数据包经过的每一跳路由器。

```
  Host A                                                Host B (目标)
       |                                                      |
       |  Round 1: TTL=1                                       |
       |  UDP/ICMP Probe ─────────────────> R1 (第1跳路由器)   |
       |                                  R1: TTL 减到 0       |
       |                                  R1 → A: Time Exceeded|
       |<────────────── ICMP Type=11 (from R1) ────────────────|
       |  记录 R1 的 IP 和 RTT                                  |
       |                                                      |
       |  Round 2: TTL=2                                       |
       |  UDP/ICMP Probe ─────────────────> R1 ──> R2          |
       |                                  R2: TTL 减到 0       |
       |                                  R2 → A: Time Exceeded|
       |<────────────── ICMP Type=11 (from R2) ────────────────|
       |  记录 R2 的 IP 和 RTT                                  |
       |                                                      |
       |  Round 3: TTL=3                                       |
       |  ... (类似过程，直到到达目标)                          |
       |                                                      |
       |  Round N: 到达 Host B                                 |
       |  UDP: 端口不可达 (Port Unreachable, Type=3 Code=3)    |
       |<────────────── ICMP Type=3 (from Host B) ─────────────|
       |  Traceroute 结束                                      |
```

**两种实现方式**：

| 方式 | 描述 | 端口使用 |
|------|------|----------|
| UDP-based（Linux 默认） | 发送 UDP 包到高端口（33434+递增） | 目标返回 Port Unreachable |
| ICMP-based（Windows 默认） | 发送 ICMP Echo Request | 目标返回 Echo Reply |

### 2.6 ICMPv6

ICMPv6 定义于 **RFC 4443**，是 ICMP 在 IPv6 中的对应协议（IP Protocol Number = `58`），功能大幅扩展。

| 功能 | ICMPv4 | ICMPv6 |
|------|--------|--------|
| 错误报告 | Type 3 (Dest Unreachable), Type 11 (Time Exceeded) | Type 1 (Dest Unreachable), Type 3 (Time Exceeded) |
| 诊断 | Type 8/0 (Echo) | Type 128/129 (Echo) |
| 地址解析 | ARP (独立协议) | NDP - Type 135/136 (Neighbor Solicitation/Advertisement) |
| 路由器发现 | DHCP | NDP - Type 133/134 (Router Solicitation/Advertisement) |
| 组播管理 | IGMP (独立协议) | MLD (MLDv2: RFC 3810) - Type 130/131/132 |
| 前缀发现 | DHCP | NDP - Type 134 (Router Advertisement 携带前缀) |
| 重复地址检测 | 手动/ARP | NDP - Type 135/136 (DAD) |

**NDP 核心消息**：

| ICMPv6 Type | 名称 | 功能 |
|-------------|------|------|
| 133 | Router Solicitation (RS) | 主机请求路由器发送 RA |
| 134 | Router Advertisement (RA) | 路由器周期性/响应式广播前缀、MTU、跳数限制等 |
| 135 | Neighbor Solicitation (NS) | 类似 ARP Request，查询 IPv6→MAC 映射 |
| 136 | Neighbor Advertisement (NA) | 类似 ARP Reply，回复 IPv6→MAC 映射 |
| 137 | Redirect Message | 路由器通知主机更优下一跳 |

### 2.7 设计注意事项（IC 设计视角）

| 主题 | 说明 |
|------|------|
| **ICMP 报文生成** | 路由芯片/防火墙在丢包时需生成 ICMP Unreachable / Time Exceeded 消息。硬件实现时需缓存触发报文的前 28 字节（IP 头 + 传输层头前 8 字节），并插入到 ICMP Data 字段 |
| **ICMP 速率限制** | ICMP 报文生成速率必须限制，防止放大攻击或拥塞。典型实现：Token Bucket 限流（如 100 packets/s），超出部分静默丢弃 |
| **ICMP 过滤策略** | 防火墙芯片需支持 ICMP 类型过滤：允许 Echo Request/Reply，拒绝 Redirect（防路由篡改），可选拒绝 Timestamp |
| **Ping Offload** | 高端 NIC 可硬件实现 Ping 应答（收到 Echo Request 立即回复 Echo Reply，不经过 CPU），需独立的 ICMP Checksum 计算单元 |
| **Traceroute 支持** | 路由芯片生成 Time Exceeded 消息时需正确设置 Code=0（TTL expired），并将触发报文前 8 字节（含 IP 头）填入 ICMP Data |
| **IPv6 NDP 处理** | 交换芯片需处理 NS/NA 消息实现 IPv6 邻居表，处理 RA 消息维护默认路由。NS 的目标地址为 Solicited-Node Multicast Address（`FF02::1:FFxx:xxxx`） |
| **ICMPv6 Checksum** | ICMPv6 使用伪头部（Pseudo Header）计算校验和，包含源/目的 IPv6 地址和 Next Header 值。IC 设计中 Checksum 计算单元需支持伪头部 |
| **MLD 处理** | 交换芯片需支持 MLD Snooping（类似 IGMP Snooping），处理 Type 130/131/132 消息维护 IPv6 组播转发表 |

---

## 3. IGMP (Internet Group Management Protocol)

### 3.1 协议概述

IGMP 定义于 **RFC 2236 (v2)** / **RFC 3376 (v3)**，用于 **IPv4 组播组**的成员管理。主机通过 IGMP 通知本地路由器自己希望加入/离开哪些组播组。

- **协议号**：IP Protocol Number = `2`
- **工作层次**：网络层（Layer 3），封装在 IP 报文中
- **目的 IP**：组播路由器地址 `224.0.0.1`（所有主机）、`224.0.0.2`（所有路由器）、`224.0.0.22`（IGMPv3）
- **TTL**：IGMP 消息 TTL=1（仅限本地链路，不跨路由器转发）
- **适用范围**：仅 IPv4；IPv6 使用 MLD（Multicast Listener Discovery）

### 3.2 IGMP 消息格式

#### IGMPv2 消息格式（8 字节，最常用）

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     Type      | Max Resp Time |          Checksum             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Group Address                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| Type | 8 bit | 消息类型 |
| Max Resp Time | 8 bit | 最大响应时间（1/10 秒），仅在 Membership Query 中有意义 |
| Checksum | 16 bit | IGMP 校验和（包含伪头部） |
| Group Address | 32 bit | 组播组地址（224.0.0.0 ~ 239.255.255.255） |

**IGMPv2 消息类型**：

| Type 值 | 名称 | 发送者 | Group Address |
|---------|------|--------|---------------|
| `0x11` | Membership Query | 路由器 | 0.0.0.0（通用查询）或特定组地址（特定组查询） |
| `0x12` | IGMPv1 Membership Report | 主机 | 加入的组播地址 |
| `0x16` | IGMPv2 Membership Report | 主机 | 加入的组播地址 |
| `0x17` | Leave Group | 主机 | 离开的组播地址 |
| `0x22` | IGMPv3 Membership Report | 主机 | 包含多个组记录 |

#### IGMPv3 Membership Report 格式（可变长度）

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Type=0x22    |    Reserved   |          Checksum             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      Reserved         |  Number of Group Records (M)         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                    Group Record 1 (variable)                  |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                              ...                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                    Group Record M (variable)                  |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

**Group Record 格式**（每个组记录可变长度）：

| 字段 | 位宽 | 说明 |
|------|------|------|
| Record Type | 8 bit | MODE_IS_INCLUDE(1) / MODE_IS_EXCLUDE(2) / CHANGE_TO_INCLUDE(3) / CHANGE_TO_EXCLUDE(4) / ALLOW_NEW_SOURCES(5) / BLOCK_OLD_SOURCES(6) |
| Aux Data Len | 8 bit | 辅助数据长度（通常为 0） |
| Number of Sources (N) | 16 bit | 源地址数量 |
| Multicast Address | 32 bit | 组播组地址 |
| Source Address[N] | 32×N bit | 源地址列表（用于 SSM：Source-Specific Multicast） |

### 3.3 IGMP v1 / v2 / v3 演进对比

| 特性 | IGMPv1 (RFC 1112) | IGMPv2 (RFC 2236) | IGMPv3 (RFC 3376) |
|------|--------------------|--------------------|---------------------|
| 发布年份 | 1989 | 1997 | 2002 |
| 消息类型 | Query + Report | Query + Report + **Leave** | Query + Report（多记录） |
| 离开组播组 | 超时（无显式 Leave） | **显式 Leave 消息** | 显式 Leave（通过 Report） |
| 组查询 | 仅通用查询 | 通用查询 + **特定组查询** | 通用查询 + 特定组查询 + **特定源组查询** |
| 查询器选举 | 依赖组播路由协议 | **自身查询器选举机制** | 自身查询器选举机制 |
| 源过滤（SSM） | 不支持 | 不支持 | **支持**（指定源地址列表） |
| 最大响应时间 | 固定 10s | **可变**（Max Resp Time 字段） | **可变**（扩展精度） |
| 兼容性 | - | 向下兼容 v1 | 向下兼容 v2 |

**SSM (Source-Specific Multicast)**：IGMPv3 的关键特性，允许主机指定只接收来自特定源的组播流，地址范围 `232.0.0.0/8`。

### 3.4 组播加入 / 离开流程

#### IGMPv2 组播加入流程

```
  Host A              Router (查询器)           组播源
       |                    |                      |
       |  1. 组播应用启动   |                      |
       |                    |                      |
       |  2. Membership Report (Join)              |
       |  Dst=224.0.0.x (组播组)                   |
       |  TTL=1                                    |
       |------------------->|                      |
       |                    |                      |
       |  3. 路由器更新     |                      |
       |     组播转发表      |                      |
       |                    |                      |
       |  4. 路由器向上游   |                      |
       |     发送 PIM Join  |                      |
       |                    |------------------->  |
       |                    |  5. 组播流到达       |
       |<===================|<===================  |
       |  6. 主机接收组播数据                       |
       |                    |                      |
```

#### IGMPv2 组播离开流程

```
  Host A              Router (查询器)           组播源
       |                    |                      |
       |  1. 主机停止接收   |                      |
       |                    |                      |
       |  2. Leave Group 消息                      |
       |  Dst=224.0.0.2 (所有路由器)               |
       |  Group=组播地址                           |
       |------------------->|                      |
       |                    |                      |
       |  3. 路由器发送     |                      |
       |     特定组查询      |                      |
       |     (Group-Specific Query)                |
       |<-------------------|                      |
       |                    |                      |
       |  4. 其他主机是否   |                      |
       |     仍在监听？      |                      |
       |  (等待 Max Resp Time)                     |
       |                    |                      |
       |  5a. 无响应 → 停止转发组播流               |
       |                    |--- PIM Prune ------->|
       |                    |                      |
       |  5b. 有响应 → 继续转发                     |
       |                    |                      |
```

#### 路由器周期性查询

路由器周期性发送 **General Query**（默认间隔 **125 秒**）到 `224.0.0.1`，组内所有主机随机延迟后回复 Report（**Report Suppression**：收到同组 Report 后取消自己的回复，减少重复）。

### 3.5 IGMP Snooping（交换机组播优化）

IGMP Snooping 是交换机在 **Layer 2** 层面监听 IGMP 消息，建立 **组播转发表**（Multicast Forwarding Table），避免将组播帧泛洪到所有端口。

```
  主机 A (加入组G)      交换机 (IGMP Snooping)      路由器
  主机 B (未加入)              |                      |
  主机 C (加入组G)            |                      |
       |                      |                      |
       | IGMP Report (G)      |                      |
       |--------------------->|                      |
       |                      | IGMP Report (G)      |
       |                      |--------------------->|
       |                      |                      |
       |                      | 组播流 (G)           |
       |                      |<---------------------|
       |                      |                      |
       | 组播流 (G)           |  (仅转发给端口 A、C)  |
       |<=====================|=====================>|
       |                      |                      |
```

**无 IGMP Snooping vs 有 IGMP Snooping**：

| 场景 | 行为 | 带宽影响 |
|------|------|----------|
| 无 Snooping | 组播帧泛洪到所有端口（同广播） | 浪费端口带宽 |
| 有 Snooping | 仅转发到有组员的端口 | 仅必要端口接收 |

**Snooping 表条目**：

| 字段 | 说明 |
|------|------|
| 组播组地址 | 224.x.x.x ~ 239.x.x.x |
| 成员端口列表 | 收到 IGMP Report 的端口 |
| 路由器端口 | 收到 IGMP Query 的端口（标记为路由器端口） |
| 老化定时器 | 超时无 Report 则删除条目 |

### 3.6 MLD (Multicast Listener Discovery)

MLD 是 IGMP 在 IPv6 中的对应协议，封装在 ICMPv6 消息中（IP Protocol = 58, ICMPv6 Type 130/131/132）。

| 版本 | 对应 IGMP 版本 | RFC | 关键特性 |
|------|---------------|-----|----------|
| MLDv1 | IGMPv2 | RFC 2710 | Query + Report + Done（离开） |
| MLDv2 | IGMPv3 | RFC 3810 | 源过滤（SSM）、多组记录 |

**MLD 消息类型**：

| ICMPv6 Type | 名称 | 对应 IGMP |
|-------------|------|-----------|
| 130 | Multicast Listener Query | Membership Query |
| 131 | Multicast Listener Report v1 | Membership Report v2 |
| 132 | Multicast Listener Done | Leave Group |
| 143 | Multicast Listener Report v2 | Membership Report v3 |

**IPv6 组播地址范围**：

| 范围 | 说明 |
|------|------|
| `FF02::1` | 所有节点（类似 224.0.0.1） |
| `FF02::2` | 所有路由器（类似 224.0.0.2） |
| `FF02::16` | 所有 MLDv2 路由器 |
| `FF02::1:FFxx:xxxx` | Solicited-Node Multicast（NDP 使用） |
| `FF0x::/8` | 全局组播地址（x = scope） |

**Snooping 对应**：IPv6 使用 **MLD Snooping**，功能与 IGMP Snooping 对等，但需解析 ICMPv6 消息而非 IGMP 消息。

### 3.7 设计注意事项（IC 设计视角）

| 主题 | 说明 |
|------|------|
| **组播转发表（MFT）** | 交换芯片核心组件。典型实现：Hash 表（组播 IP → 端口位图），容量 256 ~ 4K 条目。条目包含：组播组地址、端口位图（bitmap）、老化定时器、路由器端口标记 |
| **IGMP 报文解析** | 交换芯片需在 L2 转发路径中识别 IGMP 报文（IP Proto=2, Dst=224.0.0.x, TTL=1），解析 Membership Report / Leave 消息，更新组播转发表 |
| **Report 抑制处理** | Snooping 交换机可选择性地过滤重复 Report（同一组的多个 Report 只转发第一个给路由器），减少上行带宽 |
| **Leave 延迟处理** | 收到 Leave 后交换机应等待 Last Member Query Interval（默认 1s）再删除端口，避免误删仍有组员的端口 |
| **路由器端口发现** | 交换机通过监听 IGMP Query（来自路由器）自动学习路由器端口。也可静态配置 |
| **组播 MAC 映射** | IPv4 组播 IP 到以太网 MAC 的映射：`01:00:5E:0x:xx:xx`（低 23 bit 映射 IP 的低 23 bit）。注意映射不唯一（32 bit IP → 23 bit MAC），多个组播组可能映射到同一 MAC |
| **IPv6 组播 MAC 映射** | 以太网 MAC：`33:33:xx:xx:xx:xx`（低 32 bit 取 IPv6 组播地址的低 32 bit） |
| **组播风暴防护** | 硬件需限制组播帧的转发速率，防止组播风暴。可使用 Per-Port 或 Per-Group 的速率限制 |
| **MLD Snooping** | IPv6 交换芯片需支持 MLD Snooping，解析 ICMPv6 Type 130/131/132 消息。ICMPv6 校验和计算需包含伪头部（源/目的 IPv6 地址） |
| **硬件加速** | 组播转发查找可与单播共用 TCAM/Hash 表。组播转发表条目更新由 IGMP/MLD 报文驱动，更新操作需原子化（避免查找-更新竞争） |
| **Snooping 旁路** | 控制平面报文（IGMP/MLD）在交换芯片中应走独立路径（CPU 送 or 硬件转发），不应被普通数据通路过滤 |

---

## 附录：协议速查表

| 协议 | RFC | EtherType / IP Proto | 工作层次 | IPv4/IPv6 | 关键功能 |
|------|-----|---------------------|----------|-----------|----------|
| ARP | RFC 826 | EtherType 0x0806 | L2/L3 | IPv4 only | IP→MAC 地址解析 |
| ICMP | RFC 792 | IP Proto 1 | L3 | IPv4 | 网络诊断与错误报告 |
| ICMPv6 | RFC 4443 | IP Proto 58 | L3 | IPv6 only | ICMPv6 + NDP + MLD |
| IGMP | RFC 2236/3376 | IP Proto 2 | L3 | IPv4 only | IPv4 组播组管理 |
| MLD | RFC 2710/3810 | ICMPv6 130-132 | L3 | IPv6 only | IPv6 组播组管理 |
| NDP | RFC 4861 | ICMPv6 133-137 | L3 | IPv6 only | 邻居发现（替代 ARP） |
