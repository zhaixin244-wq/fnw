# NAT / DHCP / DNS 网络服务协议

> **面向**：数字 IC 设计架构师
> **用途**：NIC/SoC 网络加速引擎设计参考
> **日期**：2026-04-15

---

## 1. NAT (Network Address Translation)

### 1.1 协议概述

| 字段 | 内容 |
|------|------|
| **RFC** | RFC 3022（原始 RFC 1631 的修订） |
| **核心功能** | 在网络边界对 IP 地址/端口进行转换，复用有限的公网 IPv4 地址 |
| **部署位置** | 网关/路由器/NAT 设备（内网与公网之间） |
| **协议层** | 网络层（L3）+ 传输层（L4，NAPT 场景） |

NAT 通过维护地址转换表，在私有网络（RFC 1918 地址：10.0.0.0/8、172.16.0.0/12、192.168.0.0/16）与公网之间进行 IP 报文的源/目的地址改写，从而解决 IPv4 地址枯竭问题，同时提供一定程度的网络隔离。

### 1.2 NAT 类型

| 类型 | 转换方向 | 转换内容 | 典型场景 |
|------|----------|----------|----------|
| **SNAT (Source NAT)** | 内部 → 外部 | 替换源 IP（和端口） | 企业内网访问 Internet |
| **DNAT (Destination NAT)** | 外部 → 内部 | 替换目的 IP（和端口） | 公网访问内网服务器（端口映射） |
| **NAPT / PAT** | 双向 | 源 IP + 源端口复用同一公网 IP | 家庭路由器、运营商 CGNAT |
| **Static NAT** | 双向 | 内部 IP ↔ 公网 IP 1:1 固定映射 | 服务器发布 |
| **Dynamic NAT** | 内部 → 外部 | 内部 IP 动态分配公网 IP | 地址池场景 |
| **Twice NAT** | 双向 | 同时改写源和目的地址 | 地址重叠场景（两私网互通） |

### 1.3 NAPT 转换流程

```
内部主机                    NAT 设备                      公网服务器
  |                          |                              |
  |  Src=192.168.1.10:5001   |                              |
  |  Dst=8.8.8.8:80          |                              |
  |------------------------->|                              |
  |                          |  NAT 表查表：                 |
  |                          |  Key=(192.168.1.10, 5001, TCP)|
  |                          |  → 命中：取 External IP:Port  |
  |                          |  → 未命中：分配 203.0.113.1:N  |
  |                          |                              |
  |                          |  Src=203.0.113.1:61001       |
  |                          |  Dst=8.8.8.8:80              |
  |                          |----------------------------->|
  |                          |                              |
  |                          |  Src=8.8.8.8:80              |
  |                          |  Dst=203.0.113.1:61001       |
  |                          |<-----------------------------|
  |                          |                              |
  |                          |  反向查表：                    |
  |                          |  Key=(203.0.113.1, 61001, TCP)|
  |                          |  → Internal IP:Port          |
  |  Src=8.8.8.8:80          |                              |
  |  Dst=192.168.1.10:5001   |                              |
  |<-------------------------|                              |
```

### 1.4 NAT 表项格式

```
+---------------------+----------------------+----------+----------+
| Internal IP:Port    | External IP:Port     | Protocol | Timeout  |
+---------------------+----------------------+----------+----------+
| 192.168.1.10:5001   | 203.0.113.1:61001    | TCP      | 7200s   |
| 192.168.1.10:5002   | 203.0.113.1:61002    | UDP      | 300s    |
| 192.168.1.20:1234   | 203.0.113.1:62001    | TCP      | 7200s   |
| 192.168.1.30:53     | 203.0.113.2:53       | UDP      | 300s    |
+---------------------+----------------------+----------+----------+
```

**默认超时值（Linux conntrack 参考）**：

| 协议 | 超时 | 说明 |
|------|------|------|
| TCP ESTABLISHED | 7200s (2h) | 已建立连接 |
| TCP SYN_SENT | 120s | 等待握手 |
| TCP TIME_WAIT | 120s | 连接关闭等待 |
| UDP | 300s (5min) | 无状态，按最后报文 |
| ICMP | 30s | 短超时 |
| Generic | 600s (10min) | 其他协议 |

### 1.5 ALG (Application Level Gateway)

某些应用层协议在 payload 中嵌入 IP 地址/端口信息，NAT 无法通过简单的 L3/L4 头部改写完成转换，需要 ALG 深度解析并改写 payload。

| 协议 | 问题 | ALG 处理 |
|------|------|----------|
| **FTP** | PORT/EPRT 命令携带 IP:Port | 改写命令中的地址，创建额外的 NAT 表项 |
| **SIP** | SDP body 中携带媒体地址 | 改写 SDP 中的 c= 行和 m= 行端口 |
| **H.323** | 动态端口分配 | ALG 跟踪 H.225/H.245 协商 |
| **DNS** | 响应含公网 IP（不适用 NAT 后场景） | 通常不做特殊处理 |
| **TFTP** | 基于 UDP，动态端口 | 跟踪 TFTP 请求建立关联连接 |
| **IPsec** | ESP 无端口号 | 需要 NAT-T (RFC 3947/3948) 封装 |

### 1.6 NAT 穿越技术

| 技术 | 原理 | 适用场景 |
|------|------|----------|
| **STUN** (RFC 5389) | 客户端向公网 STUN Server 发送请求，获取自身在 NAT 上的映射地址和 NAT 类型 | P2P 通信建立（如 WebRTC） |
| **TURN** (RFC 5766) | 当 P2P 直连失败时，通过 TURN Server 中继所有数据 | 对称型 NAT 穿越失败时的备选 |
| **ICE** (RFC 8445) | 综合使用 STUN + TURN，收集所有可用的 candidate 地址对，选择最优路径 | VoIP / WebRTC |

NAT 类型与穿越能力对照：

| NAT 类型 | STUN 可穿越 | 说明 |
|----------|-------------|------|
| Full Cone | 是 | 最宽松，任何外部主机可主动发送 |
| Restricted Cone | 是 | 仅曾被发送过的外部 IP 可回包 |
| Port Restricted Cone | 是 | 仅曾被发送过的外部 IP:Port 可回包 |
| Symmetric | 否（需 TURN） | 每个外部目标分配不同映射端口 |

### 1.7 设计注意事项（IC 设计视角）

| 设计项 | 说明 |
|--------|------|
| **NAT 表存储** | Hash 表（O(1) 查找）+ 链式冲突解决；或使用 CAM/TCAM 实现确定性查找延迟。大规模场景（CGNAT，百万表项）需外部 DDR/HBM 缓存 |
| **表项老化** | 硬件定时器扫描，支持可配置超时。TCP 连接跟踪需解析 TCP 状态机（SYN/FIN/RST），FIN/RST 后缩短超时 |
| **端口分配算法** | 预分配块（块大小 64/256）减少冲突；随机起始偏移避免端口扫描；保留系统端口（< 1024） |
| **校验和更新** | NAT 改写 IP/Port 后需重算 IP Header Checksum 和 TCP/UDP Checksum（TCP/UDP 校验和包含伪头部），硬件实现流水化加法器 |
| **与防火墙集成** | NAT 表通常与 Stateful Firewall 的连接跟踪表合一，避免双重查找。ACL 规则在 NAT 转换前/后分别匹配（取决于策略方向） |
| **硬件加速** | 五元组 Hash → 查表 → Header 改写 → 校验和增量更新，可实现单周期查表 + 1-2 周期改写的流水线 |
| **IPv6 过渡** | NAT64（RFC 6146）/ DS-Lite / MAP-E 等方案需在 NAT 引擎中支持 IPv6 头部处理 |
| **分片报文** | 分片报文（非首片）不含端口号，需缓存首片信息或使用 IP ID + 协议作为临时 Key |

---

## 2. DHCP (Dynamic Host Configuration Protocol)

### 2.1 协议概述

| 字段 | 内容 |
|------|------|
| **RFC** | RFC 2131 (DHCPv4)、RFC 8415 (DHCPv6) |
| **核心功能** | 动态分配 IP 地址、子网掩码、网关、DNS 等网络参数 |
| **传输层** | UDP（Server: 67，Client: 68）/ DHCPv6（Server: 547，Client: 546） |
| **前身** | BOOTP (RFC 951) |

DHCP 基于 Client/Server 模型，客户端在启动时向 DHCP Server 请求网络配置参数，Server 从地址池中分配 IP 地址并指定租约时长。

### 2.2 DHCP 报文格式 (DHCPv4)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     OP (1)    |   HTYPE (1)   |    HLEN (1)   |    HOPS (1)   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         XID (4)                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          SECS (2)             |          FLAGS (2)            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        CIADDR (4)                             |
+                      (Client IP, 已有地址时填写)               +
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        YIADDR (4)                             |
+                    (Your IP, Server 分配给 Client)             +
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        SIADDR (4)                             |
+                   (Server IP, 下一阶段 Server)                 +
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        GIADDR (4)                             |
+                  (Gateway IP, Relay Agent 填写)                +
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        CHADDR (16)                            |
+                  (Client Hardware Address, MAC)               +
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        SNAME (64)                             |
+                   (Server Host Name)                          +
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        FILE (128)                             |
+                   (Boot File Name)                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        OPTIONS (variable)                     |
+                   (Magic Cookie + Options)                    +
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

**关键字段**：

| 字段 | 长度 | 说明 |
|------|------|------|
| OP | 1B | 1=BOOTREQUEST, 2=BOOTREPLY |
| HTYPE | 1B | 硬件类型：1=Ethernet |
| HLEN | 1B | 硬件地址长度：6（MAC 地址） |
| HOPS | 1B | Relay Agent 跳数，Client 置 0 |
| XID | 4B | 事务 ID，Client 随机生成，用于匹配请求/响应 |
| SECS | 2B | Client 启动后经过的秒数 |
| FLAGS | 2B | 最高位：Broadcast 标志 |
| CIADDR | 4B | Client IP 地址（已有时填写，否则 0） |
| YIADDR | 4B | Server 分配给 Client 的 IP |
| SIADDR | 4B | 下一阶段 Server 地址（如 TFTP Server） |
| GIADDR | 4B | Relay Agent 地址（跨子网时使用） |
| CHADDR | 16B | Client 硬件地址（MAC 填前 6 字节） |
| OPTIONS | 变长 | DHCP Option（Option 53=Message Type 为关键） |

### 2.3 DHCP 四步流程

```
Client                         Server (Broadcast)
  |                                |
  |-------- DHCPDISCOVER -------->|  (Client 广播，寻找 Server)
  |  Src: 0.0.0.0:68              |  CIADDR=0, XID=random
  |  Dst: 255.255.255.255:67      |
  |                                |
  |<-------- DHCPOFFER -----------|  (Server 提供可用 IP)
  |  Src: Server_IP:67            |  YADDR=offer_ip
  |  Dst: 255.255.255.255:68      |  Option 53=02
  |                                |
  |-------- DHCPREQUEST --------->|  (Client 选择并请求该 IP)
  |  Src: 0.0.0.0:68              |  Requested IP in Option 50
  |  Dst: 255.255.255.255:67      |  Option 53=03
  |                                |
  |<--------- DHCPACK ------------|  (Server 确认分配)
  |  Src: Server_IP:67            |  YADDR=assigned_ip
  |  Dst: 255.255.255.255:68      |  Option 53=05, Option 51=lease_time
  |                                |
  |       Client 使用分配的 IP     |
```

**其他报文类型**：

| 类型 | Option 53 值 | 方向 | 说明 |
|------|-------------|------|------|
| DHCPDISCOVER | 1 | Client → Server | 广播发现 |
| DHCPOFFER | 2 | Server → Client | 提供 IP |
| DHCPREQUEST | 3 | Client → Server | 请求 IP |
| DHCPDECLINE | 4 | Client → Server | IP 冲突，拒绝 |
| DHCPACK | 5 | Server → Client | 确认 |
| DHCPNAK | 6 | Server → Client | 拒绝 |
| DHCPRELEASE | 7 | Client → Server | 释放 IP |
| DHCPINFORM | 8 | Client → Server | 已有 IP，仅请求其他配置 |

### 2.4 DHCP 租约管理

```
时间轴（假设租约 = 86400s = 24h）：

  |------ T1 ------|-------- T2 --------|------ 到期 ------|
  0               50%                  87.5%              100%
  |                |                     |                  |
  分配成功      单播续租            广播续租           租约失效
  (REQUEST)     (REQUEST to         (DISCOVER          (必须重新
                 original Server)    broadcast)          DISCOVER)
```

| 参数 | 时间点 | 行为 |
|------|--------|------|
| **T1 (Renewal Timer)** | 50% 租约时长 | Client 向原 Server **单播** DHCPREQUEST 续租 |
| **T2 (Rebinding Timer)** | 87.5% 租约时长 | T1 续租失败，Client **广播** DHCPDISCOVER 请求任意 Server 续租 |
| **Lease Expiry** | 100% 租约时长 | 租约到期，Client 必须停止使用该 IP，重新走 DISCOVER 流程 |

### 2.5 DHCP Relay

当 DHCP Server 与 Client 不在同一子网时，需要 Relay Agent 转发 DHCP 报文。

```
Client              Relay Agent (Router)           DHCP Server
  |                         |                            |
  |-- DHCPDISCOVER (bcast)->|                            |
  |                         |--- DHCPDISCOVER (unicast)->|
  |                         |  GIADDR=Relay_IP           |
  |                         |  (改写目的为 Server_IP)      |
  |                         |                            |
  |                         |<-- DHCPOFFER (unicast) ----|
  |<-- DHCPOFFER (bcast) ---|                            |
  |                         |                            |
  |-- DHCPREQUEST (bcast) ->|                            |
  |                         |--- DHCPREQUEST (unicast) ->|
  |                         |                            |
  |                         |<-- DHCPACK (unicast) ------|
  |<-- DHCPACK (bcast) -----|                            |
```

**Relay Agent 核心行为**：
- 收到 Client 广播 DHCP 报文后，填入自身 IP 到 GIADDR，单播转发给配置的 DHCP Server
- Server 根据 GIADDR 判断 Client 所在子网，从对应地址池分配 IP
- Relay Agent 转发 Server 回复给 Client

### 2.6 DHCPv6

DHCPv6（RFC 8415）用于 IPv6 网络的地址分配和配置。与 DHCPv4 的主要差异：

| 对比项 | DHCPv4 | DHCPv6 |
|--------|--------|--------|
| 报文格式 | BOOTP 扩展 | 全新格式（Type-Length-Value） |
| 传输端口 | UDP 67/68 | UDP 547/546 |
| 客户端 ID | MAC (CHADDR) | DUID (DHCP Unique Identifier) |
| 前缀分配 | 不支持 | 支持 IA_PD (Prefix Delegation) |
| 地址自动配置 | 仅 DHCP | DHCPv6 + SLAAC（NDP） |

**DHCPv6 四步流程（SARR）**：

```
Client                          Server
  |                                |
  |-------- SOLICIT ------------->|  (多播 ff02::1:2, 寻找 Server)
  |                                |
  |<------- ADVERTISE ------------|  (Server 回复可用配置)
  |                                |
  |-------- REQUEST ------------->|  (Client 选择 Server)
  |                                |
  |<-------- REPLY ---------------|  (Server 分配地址/前缀)
```

### 2.7 设计注意事项（IC 设计视角）

| 设计项 | 说明 |
|--------|------|
| **SoC/DMA 中的 DHCP Client** | 网卡固件在初始化时实现 DHCP 客户端状态机。SoC 启动流程：ROM → Bootloader → 网络初始化 → DHCP 获取地址 → 载入镜像（PXE/iSCSI 场景）。硬件只需实现 UDP 收发，DHCP 状态机可由固件完成 |
| **报文校验和** | DHCP over UDP，需计算 UDP 校验和（包含伪头部）。硬件 TX 路径支持 Checksum Offload（TCP/UDP 校验和硬件计算）可减轻 CPU 负担 |
| **DHCP Snooping (交换芯片)** | 交换芯片在硬件中实现 DHCP Snooping：信任端口（连接 DHCP Server）vs 非信任端口（连接 Client）。非信任端口只允许 DHCP DISCOVER/REQUEST/DECLINE/RELEASE 通过，阻断伪造的 OFFER/ACK。构建绑定表（MAC ↔ IP ↔ Port ↔ VLAN）用于 ARP Inspection 和 IP Source Guard |
| **Relay Agent 硬件加速** | 在路由器 NPU 中，Relay Agent 功能可硬件实现：捕获广播 DHCP 报文 → 修改 GIADDR → 查路由表确定 Server 地址 → 单播转发。时延要求低，但吞吐要求高（大量 Client 并发获取地址） |
| **Option 解析** | DHCP Options 采用 TLV 格式（Tag-Length-Value），硬件需实现流式解析器支持嵌套和可变长 Option |
| **地址池管理** | Server 端需管理大地址池（Hash 或 Bitmap），硬件加速可用于高并发场景（数据中心 DHCP） |

---

## 3. DNS (Domain Name System)

### 3.1 协议概述

| 字段 | 内容 |
|------|------|
| **RFC** | RFC 1035（基础）、RFC 1034（概念与设施）|
| **核心功能** | 将域名（如 www.example.com）解析为 IP 地址（A/AAAA 记录） |
| **传输层** | UDP 53（默认）/ TCP 53（大数据传输，如 Zone Transfer） |
| **协议层** | 应用层（L7） |
| **数据格式** | 二进制（非文本） |

DNS 是一个分布式、层次化的数据库系统，采用 Client/Resolver + Server 的架构。除域名→IP 解析外，还承载邮件路由（MX）、域名别名（CNAME）、反向解析（PTR）等功能。

### 3.2 DNS 报文格式

```
+---------------------+----------------------+
|       Header        |      固定 12 字节     |
+---------------------+----------------------+
|     Question        |   查询问题（变长）     |
+---------------------+----------------------+
|      Answer         |   应答记录（变长）     |
+---------------------+----------------------+
|    Authority        |   权威记录（变长）     |
+---------------------+----------------------+
|    Additional       |   附加记录（变长）     |
+---------------------+----------------------+
```

**Header 格式**：

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      ID (16 bits)                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|QR|  Opcode   |AA|TC|RD|RA| Z|AD|CD|   RCODE  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    QDCOUNT (16 bits)                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    ANCOUNT (16 bits)                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    NSCOUNT (16 bits)                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    ARCOUNT (16 bits)                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| ID | 16 | 报文标识，用于匹配请求与响应 |
| QR | 1 | 0=Query, 1=Response |
| Opcode | 4 | 0=标准查询, 1=反向查询, 2=服务器状态, 4=Notify, 5=Update |
| AA | 1 | Authoritative Answer（权威应答） |
| TC | 1 | Truncation（报文被截断，需 TCP 重传） |
| RD | 1 | Recursion Desired（请求递归解析） |
| RA | 1 | Recursion Available（Server 支持递归） |
| AD | 1 | Authenticated Data（DNSSEC 验证通过） |
| CD | 1 | Checking Disabled（禁用 DNSSEC 验证） |
| RCODE | 4 | 响应码：0=No Error, 1=Format Error, 2=Server Failure, 3=Name Error (NXDOMAIN), 5=Refused |
| QDCOUNT | 16 | Question Section 条目数 |
| ANCOUNT | 16 | Answer Section 条目数 |
| NSCOUNT | 16 | Authority Section 条目数 |
| ARCOUNT | 16 | Additional Section 条目数 |

### 3.3 DNS 查询流程

#### 递归查询

```
Client                Local DNS              Root Server    .com TLD    example.com
  |                      |                      |              |            |
  |-- www.example.com -->|                      |              |            |
  |  (递归查询)          |                      |              |            |
  |                      |-- . ? A ------------>|              |            |
  |                      |<-- .com NS ref ----- |              |            |
  |                      |                      |              |            |
  |                      |-- www.example.com -->|              |            |
  |                      |   ? A                |              |            |
  |                      |                      |              |            |
  |                      |                      |-- query ---->|            |
  |                      |                      |<-- NS ref ---|            |
  |                      |<-------------------------------------|            |
  |                      |-- www.example.com ------------------>|            |
  |                      |   ? A                               |            |
  |                      |<------------------------------------ A 93.184.216.34
  |<-- 93.184.216.34 ---|                      |              |            |
  |  (最终应答)          |                      |              |            |
```

#### 迭代查询

```
Client                Local DNS              Root Server    .com TLD    example.com
  |                      |                      |              |            |
  |-- www.example.com -->|                      |              |            |
  |  (递归查询)          |                      |              |            |
  |                      |-- . ? A ------------>|              |            |
  |                      |<-- NS .com, addr ----|              |            |
  |                      |                      |              |            |
  |                      |-- www.example.com ? A ------------->|            |
  |                      |<-- NS example.com, addr ------------|            |
  |                      |                      |              |            |
  |                      |-- www.example.com ? A -------------------------->|
  |                      |<---------------------------------- A 93.184.216.34
  |<-- 93.184.216.34 ---|                      |              |            |
```

> 实际中 Local DNS Server 通常对 Client 提供递归服务，自身向上游进行迭代查询。

### 3.4 DNS 记录类型

| 类型 | 值 | 格式示例 | 说明 |
|------|----|----------|------|
| **A** | 1 | `example.com. 300 IN A 93.184.216.34` | IPv4 地址记录 |
| **AAAA** | 28 | `example.com. 300 IN AAAA 2606:2800:220:1::` | IPv6 地址记录 |
| **CNAME** | 5 | `www.example.com. 300 IN CNAME example.com.` | 域名别名 |
| **MX** | 15 | `example.com. 300 IN MX 10 mail.example.com.` | 邮件交换（含优先级） |
| **NS** | 2 | `example.com. 300 IN NS ns1.example.com.` | 域名服务器 |
| **PTR** | 12 | `34.216.184.93.in-addr.arpa. 300 IN PTR example.com.` | 反向解析 |
| **SOA** | 6 | `example.com. 300 IN SOA ns1 admin 2024010101 3600 900 ...` | 起始授权（Zone 元数据） |
| **TXT** | 16 | `example.com. 300 IN TXT "v=spf1 include:..."` | 文本记录（SPF/DKIM 等） |
| **SRV** | 33 | `_sip._tcp.example.com. 300 IN SRV 10 60 5060 sip.example.com.` | 服务定位 |
| **CAA** | 257 | `example.com. 300 IN CAA 0 issue "letsencrypt.org"` | CA 授权 |

### 3.5 DNS 缓存与 TTL

DNS 响应中每条记录都携带 TTL（Time To Live，单位：秒），缓存服务器在 TTL 到期前返回缓存结果。

```
Client 查询 → 缓存命中且 TTL>0 → 直接返回缓存
           → 缓存未命中/TTL=0  → 向上游递归查询 → 更新缓存并记录 TTL
```

**TTL 老化机制**：

| 场景 | 行为 |
|------|------|
| TTL > 0 | 返回缓存记录，TTL 每秒递减 |
| TTL = 0 | 缓存过期，下次查询触发上游查询 |
| 查询返回时 | 用新响应的 TTL 覆盖缓存计时器 |

**典型 TTL 值**：

| 场景 | TTL | 说明 |
|------|-----|------|
| 稳定服务 | 86400 (24h) | 减少查询负载 |
| 可能变更 | 300 (5min) | 便于快速切换 |
| 即将变更 | 60 (1min) | 迁移/故障切换 |
| CDN/Anycast | 30~60 | 需快速切换流量 |

### 3.6 DNSSEC

DNSSEC（DNS Security Extensions, RFC 4033-4035）通过数字签名验证 DNS 响应的真实性和完整性，防止 DNS 欺骗和缓存投毒。

**核心机制**：

| 组件 | 说明 |
|------|------|
| **RRSIG** | 资源记录的数字签名（对每条 RRSet 签名） |
| **DNSKEY** | Zone 的公钥 |
| **DS** | Delegation Signer，子 Zone 公钥的 Hash，存储在父 Zone 中 |
| **NSEC / NSEC3** | 证明确实不存在某个记录（Negative Answer Auth） |

**验证链**：

```
Root Zone (Trust Anchor)
  |
  | DS record for .com
  ↓
.com Zone
  |
  | DS record for example.com
  ↓
example.com Zone → RRSIG 签名 → 验证 DNS 响应
```

**AD 标志**：验证通过后，DNS 响应 Header 中 AD (Authenticated Data) 位置 1。

### 3.7 设计注意事项（IC 设计视角）

| 设计项 | 说明 |
|--------|------|
| **NIC 中的 DNS Offload** | SmartNIC 可实现 DNS 解析加速：硬件解析 DNS 报文 → 查询本地缓存 → 命中直接返回，未命中转发给 Host CPU。适合 CDN/Gateway 场景的高 QPS 域名解析 |
| **DNS 缓存硬件** | 片上 SRAM 存储热点域名缓存（Hash 索引 + TTL 管理），外部 DDR 存储全量缓存。硬件定时器扫描过期条目 |
| **报文解析流水线** | DNS 报文为二进制 TLV 格式，适合硬件流式解析：Header（固定 12B）→ Question Section → Answer/Authority/Additional Section（每条记录含 Name + Type + Class + TTL + RDLength + RData） |
| **域名编码** | DNS 使用 Label 编码（长度前缀 + 标签，如 `\3www\7example\3com\0`），支持指针压缩（Label 长度最高 2 位为 11 时为压缩指针）。硬件解析器需支持指针回溯 |
| **DNSSEC 验证加速** | RSA/ECDSA 签名验证计算量大，可集成硬件加密加速器（如 EIP-130）加速 RRSIG 校验 |
| **DoH/DoT 支持** | DNS over HTTPS (RFC 8484) / DNS over TLS (RFC 7858) 需要 TLS 握手，SmartNIC 可集成 TLS 卸载引擎 |
| **与 TCP/UDP 引擎集成** | DNS 默认 UDP 53，大响应时 TC 标志置 1 需切换 TCP 重传。硬件需支持 UDP/TCP 双模收发 |

---

## 4. 三协议关联设计总结

| 协议 | 在 NIC/SoC 中的角色 | 关键硬件需求 |
|------|---------------------|-------------|
| **NAT** | 数据面加速：五元组查表 + 报文改写 | Hash/CAM 查表、校验和增量更新、TCP 状态跟踪、定时器老化 |
| **DHCP** | 控制面：初始化地址获取 | UDP 收发、状态机（固件实现）、DHCP Snooping（交换芯片硬件） |
| **DNS** | 控制面 / 数据面加速：域名解析 | 报文解析流水线、缓存管理、可选加密加速（DNSSEC/DoT） |

**典型集成架构**：

```
                    +-------------------+
                    |    Host CPU       |
                    |  (DHCP Client,    |
                    |   DNS Resolver,   |
                    |   NAT 管理面)      |
                    +--------+----------+
                             | PCIe / AXI
                    +--------+----------+
                    |    NIC / SoC       |
                    |  +--------------+  |
                    |  | NAT Engine   |  |  ← 数据面硬件加速
                    |  | (Hash+CAM)   |  |
                    |  +--------------+  |
                    |  +--------------+  |
                    |  | DNS Cache    |  |  ← 可选硬件缓存
                    |  | + Parser     |  |
                    |  +--------------+  |
                    |  +--------------+  |
                    |  | DHCP Snooping|  |  ← 交换芯片功能
                    |  | + Bind Table |  |
                    |  +--------------+  |
                    +--------+----------+
                             |
                        Network Port
```

---

## 参考文献

| 编号 | 文档 | 说明 |
|------|------|------|
| RFC 1034 | Domain Names - Concepts and Facilities | DNS 基础概念 |
| RFC 1035 | Domain Names - Implementation and Specification | DNS 实现规范 |
| RFC 2131 | Dynamic Host Configuration Protocol | DHCPv4 |
| RFC 3022 | Traditional IP Network Address Translator (Traditional NAT) | NAT 规范 |
| RFC 3947/3948 | NAT-Traversal for IPsec | IPsec 穿越 NAT |
| RFC 4033/4034/4035 | DNS Security Extensions | DNSSEC |
| RFC 5389 | Session Traversal Utilities for NAT (STUN) | STUN |
| RFC 5766 | Traversal Using Relays around NAT (TURN) | TURN |
| RFC 6146 | Stateful NAT64 | NAT64 |
| RFC 8415 | Dynamic Host Configuration Protocol for IPv6 (DHCPv6) | DHCPv6 |
| RFC 8445 | Interactive Connectivity Establishment (ICE) | ICE |
| RFC 8484 | DNS Queries over HTTPS (DoH) | DoH |
