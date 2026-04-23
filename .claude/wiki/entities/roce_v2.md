# RoCE v2 (RDMA over Converged Ethernet v2)

> 基于 Ethernet + UDP/IP 承载的 RDMA 协议，是数据中心 RDMA 的主流部署方案。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | RDMA 传输协议（L2+L3+L4） |
| **标准** | IBTA RoCE v2 / InfiniBand Spec Vol.1 Appendix A |
| **封装** | Ethernet + IP + UDP(DstPort 4791) + BTH + Payload |

## 核心特性

1. **BTH (Base Transport Header)**：OpCode(8b) + Solicited(1b) + MigReq(1b) + PadCount(2b) + TransportVer(4b) + PartitionKey(16b) + DstQPN(24b) + AckReq(1b) + PSN(24b)
2. **OpCode 体系**：SEND/RDMA_WRITE/RDMA_READ_REQ/ACK/ATOMIC/CMP_SWAP 等，RC/UC/UD 三种服务
3. **ICRC (Invariant CRC)**：32-bit CRC 覆盖 BTH+Payload，保证端到端数据完整性 (非 L2 FCS 范围)
4. **DCQCN 拥塞控制**：基于 ECN 的端到端拥塞控制，CNP (Congestion Notification Packet) 反馈
5. **可靠传输 (RC)**：PSN (Packet Sequence Number) 24-bit，超时重传 + Go-Back-N

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| UDP DstPort | 4791 | RoCE v2 标准端口 |
| BTH 长度 | 12 bytes | 基础传输头 |
| PSN | 24 bit | 包序列号 |
| ICRC | 32 bit | Invariant CRC (覆盖 BTH+Payload) |
| MTU | 1024 / 2048 / 4096 bytes | IB MTU，以太 MTU 需更大 |
| DCQCN α | 0-1 (定点) | 拥塞程度因子 |

## 典型应用场景

- 数据中心无损 RDMA 网络 (PFC + ECN + DCQCN)
- AI/ML 集群 (NCCL over RoCE v2)
- NVMe/RDMA 存储网络
- 分布式数据库 (GPUDirect RDMA)

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| RDMA | RoCE v2 是 RDMA 的 Ethernet 传输 |
| UDP | 封装在 UDP 内 (DstPort 4791) |
| IP/ECN | 依赖 IP ECN 字段做拥塞标记 |
| PFC | RoCE v2 无损传输依赖 PFC |
| VLAN/QoS | CoS 优先级保证 RDMA 流量 QoS |
| InfiniBand | BTH 头部格式继承自 IB |

## RTL 设计要点

- **BTH 解析**：从 UDP 载荷提取 OpCode / DstQPN / PSN / PadCount，路由到 QP 上下文
- **ICRC 引擎**：32-bit CRC (CRC-32C 或 IB 定义多项式)，覆盖 BTH + Payload + GRH(可选)
- **PSN 检查**：RC 模式下比较期望 PSN 与接收 PSN，乱序/丢失触发 NAK + 重传
- **DCQCN 响应**：解析 IP ECN=CE → 生成 CNP 包 → 发送回源端
- **CNP 包生成**：UDP SrcPort=4791, DstPort=4791, BTH OpCode=CNP, 无 Payload
- **多队列 RSS**：Toeplitz 哈希 (SIP+DIP+UDP SP+DP) 分流到多 RNIC 处理队列

## 参考

- IBTA InfiniBand Architecture Spec Vol.1 Appendix A (RoCE v2)
- RFC 3168 (ECN)
- DCQCN (SIGCOMM 2015)
- IBTA RoCE v2 Specification
