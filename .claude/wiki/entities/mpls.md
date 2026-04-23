# MPLS (Multiprotocol Label Switching)

> 基于标签交换的转发技术，在 IP 头部前插入固定 4 字节标签栈，实现快速转发和流量工程。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络转发技术（L2.5） |
| **标准** | RFC 3031 (MPLS Architecture) / RFC 5960 (SR-MPLS) |
| **位置** | 介于 L2 和 L3 之间，EtherType=0x8847 (IPv4) / 0x8848 (IPv6) |

## 核心特性

1. **Shim Header**：4 字节 = Label(20b) + TC(3b, 原 EXP) + S(1b, 栈底标志) + TTL(8b)
2. **标签栈 (Label Stack)**：支持多层标签嵌套，S=1 表示栈底，用于 TE/FRR/VPN
3. **LSR/LER**：Label Switch Router (标签交换) / Label Edge Router (入/出标签操作)
4. **PHP (Penultimate Hop Popping)**：倒数第二跳弹出标签，减少 LER 处理开销
5. **SR-MPLS (Segment Routing over MPLS)**：用标签栈编码源路由路径，替代 RSVP-TE 信令

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 标签 (Label) | 20 bit (0-1048575) | 0-15 保留，0=IPv4 Explicit Null, 3=IPv6 Explicit Null |
| TC | 3 bit | 流量分类 (原 EXP 位) |
| S 位 | 1 bit | 1=栈底标签 |
| TTL | 8 bit | 与 IP TTL 语义相同 |
| 标签栈深度 | 无限制 (典型 1-10) | SR-MPLS 可能用多层栈 |
| EtherType | 0x8847/0x8848 | MPLS Unicast/Multicast |

## 典型应用场景

- 运营商核心网 (MPLS VPN, L2VPN/L3VPN)
- 流量工程 (RSVP-TE / SR-MPLS)
- 快速重路由 (FRR, 50ms 切换)
- 数据中心 SR-MPLS (替代传统 MPLS 信令)

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| Ethernet | MPLS 帧在 Ethernet Payload 内 |
| IP | MPLS 标签位于 IP 头部之前 |
| SRv6 | SR-MPLS 的 IPv6 替代方案 |
| ECMP | 基于标签栈的 ECMP 哈希 |
| BGP | BGP 标签分发 (RFC 8277) |

## RTL 设计要点

- **标签解析**：从 Ethernet Payload 提取 4B Shim Header，提取 Label/TC/S/TTL
- **标签交换**：入标签→出标签 查找表 (SRAM/TCAM)，支持 Pop/Swap/Push 操作
- **PHP 处理**：识别隐式空标签 (Label=3)，弹出标签并直接转发 IP 包
- **标签栈处理**：S=0 时继续解析下一层标签，需限制最大解析深度防止死循环
- **TC→CoS 映射**：3-bit TC 映射到队列优先级
- **TTL 处理**：每跳 TTL-1，到 0 时发送 ICMP 超时 (PHP 跳需复制 TTL 到 IP 头)
- **SR-MPLS**：标签栈即路径，入节点 Push 全栈，每跳 Pop+Swap

## 参考

- RFC 3031 (MPLS Architecture)
- RFC 3032 (MPLS Label Stack Encoding)
- RFC 8660 (SR-MPLS)
- RFC 7274 (MPLS Label Reserved Values)
