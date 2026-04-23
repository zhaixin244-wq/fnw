# NAT / DHCP / DNS

> 网络基础设施辅助协议：NAT 实现地址转换，DHCP 自动分配 IP，DNS 完成域名解析。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络基础设施服务协议 |
| **标准** | RFC 3022 (NAT) / RFC 2131 (DHCPv4) / RFC 1035 (DNS) |
| **层级** | NAT: L3-L4 / DHCP: L4 (UDP) / DNS: L4 (UDP/TCP) |

## 核心特性

1. **NAT (Network Address Translation)**：私有 IP → 公有 IP 转换，SNAT/DNAT/NAPT (PAT)，连接跟踪表
2. **DHCP (Dynamic Host Configuration Protocol)**：自动分配 IP/掩码/网关/DNS，DORA 流程 (Discover→Offer→Request→ACK)
3. **DNS (Domain Name System)**：域名→IP 解析，递归/迭代查询，A/AAAA/CNAME/MX/TXT 记录
4. **硬件 NAT 加速**：连接跟踪表 CAM 查找 + 报文头改写，线速 NAT 处理
5. **DHCP Relay**：跨子网 DHCP 中继，Option 82 插入交换机端口信息

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| NAT 并发连接 | 64K-1M+ | 取决于连接跟踪表大小 |
| NAT 超时 | TCP: 2h / UDP: 300s / ICMP: 60s | 可配置 |
| DHCP 租期 | 典型 24h | 可配置 |
| DNS 端口 | 53 (UDP/TCP) | TCP 用于大响应 |
| DNS 缓存 | TTL 秒数 | 由权威服务器指定 |
| NAT 端口范围 | 1024-65535 | NAPT 映射端口 |

## 典型应用场景

- 网关/路由器 NAT 加速 (SmartNIC/DPU)
- 数据中心 ToR 交换机 DHCP Relay
- 企业网 DNS 缓存加速

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| IP | NAT 修改 IP 头 (SIP/DIP) |
| TCP/UDP | NAPT 修改 TCP/UDP 端口号 |
| DHCP | 基于 UDP (端口 67/68) |
| DNS | 基于 UDP/TCP (端口 53) |
| ICMP | NAT 需处理 ICMP Error 包内嵌 IP 头 |

## RTL 设计要点

- **连接跟踪表**：五元组 (SIP+DIP+SP+DP+Proto) → 映射条目，CAM/TCAM 查找，1 周期命中
- **报文头改写**：IP 头 checksum 重算 + TCP/UDP checksum 增量更新 (仅改写的字段)
- **NAT 表老化**：硬件定时器扫描过期条目，支持优先级替换策略
- **DHCP Snooping**：解析 DHCP 报文，建立 IP-MAC-Port 绑定表，防止欺骗
- **DNS 报文解析**：UDP DstPort=53 识别，域名压缩格式解析 (指针+标签)
- **ALG (Application Layer Gateway)**：FTP/SIP 等协议在 Payload 中嵌入 IP，需深度包检测

## 参考

- RFC 3022 (Traditional NAT)
- RFC 2131 (DHCPv4)
- RFC 1035 (DNS)
- RFC 8277 (BGP for MPLS)
