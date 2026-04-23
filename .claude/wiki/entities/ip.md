# IP (Internet Protocol)

> 互联网网络层核心协议，负责数据包的寻址与路由转发，IPv4 和 IPv6 是当前两大版本。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络协议（L3 网络层） |
| **标准** | RFC 791 (IPv4) / RFC 8200 (IPv6) |
| **版本** | IPv4 (32-bit) / IPv6 (128-bit) |

## 核心特性

1. **IPv4 头部**：20-60B 可变长，包含 TTL、Protocol、Checksum、分片偏移
2. **IPv6 头部**：固定 40B，简化设计，扩展头链式处理，无头部校验和
3. **分片/重组**：IPv4 中间节点可分片 (DF=0)；IPv6 仅源端分片，用 Fragment Extension Header
4. **ECN (Explicit Congestion Notification)**：2-bit ECN 字段 (00=非ECN, 01/10=ECT, 11=CE)，路由器标记拥塞
5. **路由查找**：最长前缀匹配 (LPM)，IPv4 CIDR / IPv6 前缀，硬件 TCAM 或 Trie 实现

## 关键参数

| 参数 | IPv4 | IPv6 |
|------|------|------|
| 地址长度 | 32 bit | 128 bit |
| 头部长度 | 20-60 bytes | 40 bytes (固定) |
| TTL/Hop Limit | 8 bit | 8 bit |
| 协议/Next Header | 8 bit | 8 bit |
| 分片支持 | 中间节点分片 | 仅源端分片 |
| 校验和 | 有 (每跳重算) | 无 (依赖 L2/L4) |
| 最大包长 | 65535 bytes | Jumbogram (>64KB 可选) |

## 典型应用场景

- 数据中心 L3 路由 (Leaf/Spine)
- VXLAN/GENEVE 隧道外层承载
- RoCE v2 网络层封装

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| Ethernet | L2 承载，EtherType=0x0800(IPv4)/0x86DD(IPv6) |
| TCP/UDP | 上层传输层，Protocol=6(TCP)/17(UDP) |
| ARP | IPv4 地址解析（IPv6 用 NDP/ICMPv6） |
| VXLAN/GENEVE | IPv4/IPv6 作为隧道外层 |
| ECMP | 基于 IP 五元组哈希做等价多路径 |
| DiffServ | DSCP 字段在 IP 头部 |

## RTL 设计要点

- **头部解析**：IPv4 IHL 提取可选字段、IPv6 Extension Header 链式解析 (Hop-by-Hop → Routing → Fragment)
- **校验和**：IPv4 16-bit one's complement sum，硬件需逐 16-bit 累加 + 回卷折叠
- **分片处理**：Fragment Offset 13-bit × 8 字节对齐，MF 标志 + Identification 重组
- **LPM 查找**：TCAM 或 SRAM Trie (2-4 级流水线)，支持 IPv4/IPv6 双栈
- **ECN 处理**：解析 ECT/CE 标记，CE 时设置 TCP ECN Echo (ECE)
- **TTL/Hop Limit 递减**：每跳 -1，到 0 时丢弃 + ICMP 超时

## 参考

- RFC 791 (IPv4)
- RFC 8200 (IPv6)
- RFC 3168 (ECN)
- RFC 2474 (DiffServ)
