# UEC (Ultra Ethernet Consortium)

> 面向 AI/HPC 的下一代以太网传输协议，基于 Ethernet + UDP 承载，引入多路径喷洒和信用流控机制。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 高性能网络传输协议 |
| **标准** | UEC 1.0 Specification |
| **传输基础** | Ethernet + IP + UDP |
| **目标场景** | AI/ML 集群互联、HPC |

## 核心特性

1. **多路径包喷洒 (Multi-Path Packet Spraying)**：同一消息的包分散到多条等价路径，提高聚合带宽
2. **Credit-based Flow Control**：接收端预分配 Credit 给发送端，Credit 耗尽时停止发送，避免 PFC 级联
3. **可靠传输**：基于消息的有序交付，乱序包在接收端重组，超时重传
4. **拥塞控制**：端到端拥塞感知，基于 RTT 和 ECN 的混合拥塞控制
5. **与 RoCE v2 兼容**：BTH 头部格式兼容，支持渐进式部署

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 承载协议 | Ethernet + UDP | UDP DstPort 待定义 |
| 多路径 | ECMP + 包喷洒 | 包级负载均衡 |
| Credit 单位 | MTU 或 Byte | 接收端预分配 |
| 可靠性 | 消息级有序 | 不同于 RC 的连接级有序 |
| 拥塞控制 | RTT + ECN 混合 | 替代纯 ECN 的 DCQCN |

## 典型应用场景

- 大规模 AI 训练集群 (万卡互联)
- HPC 超算互连
- 下一代数据中心网络

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| RoCE v2 | UEC 是 RoCE v2 的演进，兼容 BTH |
| RDMA | UEC 继承 RDMA 的 QP/MR 模型 |
| InfiniBand | UEC 从 IB 借鉴 Credit Flow Control |
| ECMP | UEC 的多路径依赖 ECMP 基础设施 |
| PFC | UEC 旨在减少对 PFC 的依赖 |

## RTL 设计要点

- **多路径路由**：包级 ECMP 哈希，需支持 Spraying (同一 QP 的包走不同路径)
- **Credit 管理**：接收端 Credit Pool → 发送端 Credit Grant → Credit Return 闭环
- **乱序重组**：接收端 Reorder Buffer (ROB)，按消息偏移重组，支持大窗口
- **RTT 测量**：硬件时间戳 (NS) 记录发送时间，ACK 返回时计算 RTT
- **拥塞控制引擎**：CWND 基于 RTT/ECN 调整，需 per-QP 状态机
- **与 RoCE v2 共存**：BTH 解析兼容，通过 OpCode/Version 区分

## 参考

- UEC 1.0 Specification
- Ultra Ethernet Consortium Technical Overview
