# ECMP / LAG

> 等价多路径 (ECMP) 和链路聚合 (LAG) 技术，通过哈希分流实现负载均衡和链路冗余。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络负载均衡技术 |
| **标准** | RFC 2991/2992 (ECMP) / IEEE 802.1AX (LAG/LACP) |
| **层级** | ECMP: L3 路由层 / LAG: L2 链路层 |

## 核心特性

1. **ECMP**：多条等价路由路径，基于五元组 (SIP+DIP+SP+DP+Proto) 哈希选路，逐包/逐流分流
2. **LAG (Link Aggregation)**：多条物理链路捆绑为一条逻辑链路，LACP (802.3ad) 动态协商
3. **哈希算法**：CRC-32 / XOR / Toeplitz (RSS 专用)，硬件查找表配置对称/非对称模式
4. **一致性哈希 (Consistent Hashing)**：链路增减时最小化流量迁移，Resilient ECMP / WCMP
5. **自适应 ECMP**：基于实时链路利用率动态调整权重 (DLB, Dynamic Load Balancing)

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| ECMP 路径数 | 最大 256+ | 受 FIB 表深度限制 |
| LAG 成员数 | 8 (典型) / 16+ | IEEE 802.1AX |
| 哈希输入 | 5 元组 / 3 元组 / 2 元组 | 可配置 |
| 哈希输出 | log2(N) bit | 选择 N 条路径之一 |
| LACP 超时 | Short(1s) / Long(30s) | Actor/Partner 协商 |
| Resilient Hash | N×M 映射表 | N 入口 × M 出口 |

## 典型应用场景

- 数据中心 Leaf/Spine ECMP 路由
- 服务器双网卡 Bonding (LACP)
- 交换机堆叠链路聚合
- AI 集群多路径负载均衡

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| IP | ECMP 基于 IP 头部哈希 |
| Ethernet | LAG 基于以太链路聚合 |
| VLAN/QoS | 哈希可包含 VLAN 信息 |
| VXLAN | 外层 IP 五元组 ECMP |
| RoCE v2 | UDP 五元组哈希 ECMP |
| UEC | 依赖 ECMP 做多路径喷洒 |

## RTL 设计要点

- **哈希引擎**：CRC-32 / Toeplitz 可配置，输入字段掩码可配 (SIP/DIP/SP/DP/Proto)
- **对称哈希**：SIP↔DIP 互换后哈希值相同，保证往返路径一致 (用于 RoCE v2 ACK)
- **路径选择**：哈希输出 mod N 选路径，Resilient Hash 用映射表替代 mod
- **LACP 帧处理**：解析/生成 LACPDU (Slow Protocol, EtherType=0x8809)
- **链路状态监控**：成员链路 Down 时重映射哈希，1:N 冗余切换
- **DLB 自适应**：监控各出口队列深度/利用率，动态调整哈希权重

## 参考

- RFC 2991 (Multipath Issues in Unicast and Multicast Next-Hop Selection)
- IEEE 802.1AX (Link Aggregation / LACP)
- RFC 7938 (Use of ECMP in Data Centers)
