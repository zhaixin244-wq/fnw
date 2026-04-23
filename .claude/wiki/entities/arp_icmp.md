# ARP / ICMP / IGMP

> 网络层辅助协议族：ARP 完成地址解析，ICMP 提供差错报告与诊断，IGMP 管理组播成员。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络协议（L3 辅助协议） |
| **标准** | RFC 826 (ARP) / RFC 792 (ICMP) / RFC 3376 (IGMPv3) |
| **协议号** | ARP: L2 EtherType=0x0806; ICMP: IP Protocol=1; IGMP: IP Protocol=2 |

## 核心特性

1. **ARP (RFC 826)**：IPv4 地址→MAC 地址解析，Request 广播 + Reply 单播，ARP 表缓存 (TTL 通常 20min)
2. **ICMP (RFC 792)**：差错报告 (Destination Unreachable / Time Exceeded / Redirect) + 诊断 (Echo Request/Reply)
3. **ICMPv6 (RFC 4443)**：IPv6 必需，包含 NDP (Neighbor Discovery) / SLAAC / Path MTU Discovery
4. **IGMPv3 (RFC 3376)**：组播组成员管理，支持 Source-Specific Multicast (SSM)，查询-报告机制

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| ARP 包长 | 28 bytes (IPv4) | HTYPE(2)+PTYPE(2)+HLEN(1)+PLEN(1)+OPER(2)+SHA+SPA+THA+TPA |
| ARP 操作码 | 1=Request, 2=Reply | RARP (3/4) 已废弃 |
| ICMP 类型数 | ~40+ | Type + Code 二维分类 |
| IGMPv3 查询间隔 | 125s (默认) | Query Interval |
| 组播 MAC | 01:00:5E:xx:xx:xx | IPv4 组播映射 |

## 典型应用场景

- ARP：IPv4 网络地址解析，网关/路由器必备
- ICMP：ping/traceroute 网络诊断，Path MTU Discovery
- IGMP：组播视频流、RoCE v2 Reliable Multicast

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| Ethernet | ARP 直接封装在以太帧 (EtherType=0x0806) |
| IP | ICMP/IGMP 封装在 IP 包内 (Protocol=1/2) |
| IPv6 | ICMPv6 替代 ARP (NDP) + IGMP (MLD) |
| VLAN | ARP 广播受 VLAN 域限制 |
| RoCE v2 | IGMP 管理 RDMA 组播组 |

## RTL 设计要点

- **ARP 表硬件化**：CAM/SRAM 实现 IP→MAC 查找表，支持老化/更新/替换
- **ARP Request 生成**：硬件自动生成广播 ARP Request，超时重试
- **ICMP Echo Reply**：硬件可实现快速 ping 响应 (Type=0)，减轻 CPU 负担
- **ICMP Checksum**：16-bit one's complement，与 IP 校验和算法相同
- **IGMP Snooping**：交换机硬件解析 IGMP 报告，维护组播转发表
- **NDP (ICMPv6)**：Neighbor Solicitation/Advertisement 处理，Target MAC 更新

## 参考

- RFC 826 (ARP)
- RFC 792 (ICMP)
- RFC 4443 (ICMPv6)
- RFC 3376 (IGMPv3)
- RFC 4861 (NDP)
