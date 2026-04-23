# VXLAN / GENEVE

> L2-over-L3 网络虚拟化隧道协议，将二层以太帧封装在 UDP/IP 包内，实现跨三层网络的大二层扩展。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络虚拟化隧道协议 |
| **标准** | RFC 7348 (VXLAN) / RFC 8926 (GENEVE) |
| **封装** | Outer Ethernet + Outer IP + Outer UDP + VXLAN/GENEVE Header + Inner Ethernet |

## 核心特性

1. **VXLAN (RFC 7348)**：8 字节头部，24-bit VNI (VXLAN Network Identifier)，支持 ~16M 虚拟网络，UDP DstPort=4789
2. **GENEVE (RFC 8926)**：可变长头部 (8B+TLV Options)，支持任意元数据扩展，更灵活但解析复杂
3. **VTEP (VXLAN Tunnel Endpoint)**：隧道端点，负责封装/解封装，可以是软件 (OVS) 或硬件 (交换机 ASIC)
4. **BUM 处理**：Broadcast/Unknown unicast/Multicast 流量通过组播或头端复制 (Ingress Replication) 转发

## 关键参数

| 参数 | VXLAN | GENEVE |
|------|-------|--------|
| 头部长度 | 8 bytes (固定) | 8+ bytes (可变，TLV) |
| 网络标识 | 24-bit VNI | 24-bit VNI |
| UDP 端口 | 4789 | 6081 |
| 选项扩展 | 无 | TLV (Type-Length-Value) |
| 版本 | 4 bit (固定 0) | 2 bit |
| OAM 标志 | 1 bit (I flag) | 1 bit (O flag) |

## 典型应用场景

- 云数据中心多租户网络隔离
- 跨数据中心大二层扩展
- Kubernetes Pod 网络 (CNI 插件)
- 硬件 VTEP 交换机加速

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| Ethernet | 内层/外层以太帧 |
| UDP | 外层传输层 (VXLAN:4789 / GENEVE:6081) |
| IP | 外层网络层承载 |
| VLAN | 内层 VLAN 信息保留在封装内 |
| ECMP | 外层 IP 五元组哈希做 ECMP |
| RDMA | RoCE v2 与 VXLAN 可叠加 (但复杂) |

## RTL 设计要点

- **封装引擎**：插入 Outer ETH/IP/UDP/VXLAN Header，Outer MAC/IP 可配置
- **解封装引擎**：匹配 UDP DstPort=4789 → 剥离外层头 → 输出内层帧
- **VNI 查找**：VNI→Segment/Bridge 查找表 (CAM)，决定内层帧转发
- **GENEVE TLV 解析**：可变长 TLV 链式解析，每 TLV 4B 对齐，需递归深度限制
- **Inner 头解析**：解封装后需重新解析内层 Ethernet/IP/TCP 头，用于 ACL/QoS
- **ICRC 跨隧道**：RoCE v2 over VXLAN 时 ICRC 计算需覆盖内层 BTH+Payload

## 参考

- RFC 7348 (VXLAN)
- RFC 8926 (GENEVE)
- RFC 7348 Section 6 (VTEP Architecture)
