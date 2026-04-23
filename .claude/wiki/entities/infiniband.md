# InfiniBand

> 高性能计算互联架构，原生支持 RDMA、信用流控和链路级重传，是 RDMA 技术的原始定义协议。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 高性能互联协议（L1-L4 全栈） |
| **标准** | IBTA InfiniBand Architecture Specification |
| **速率** | SDR(2.5G) / DDR(5G) / QDR(10G) / FDR(14.0625G) / EDR(25.78125G) / HDR(50G) / NDR(100G) / XDR(200G) |

## 核心特性

1. **LRH (Local Route Header)**：DLID(16b) + SLID(16b) + VL(4b) + LVer(4b) + SL(4b) + Length(11b)
2. **信用流控 (Credit-based Flow Control)**：基于 Buffer Credit 的链路级流控，发送端有 Credit 才发包
3. **链路级重传 (Link-Level Retry)**：接收端检测错误包，发送端重传，16-bit PSN 管理
4. **虚拟通道 (VL)**：最多 16 个 Virtual Lane，支持 QoS 隔离和多优先级
5. **传输层服务**：RC/UC/UD/RD 四种，BTH 头部定义 QPN + PSN + OpCode

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| SLID/DLID | 16 bit | LID 寻址，子网内唯一 |
| VL | 4 bit (0-15) | Virtual Lane，VL15 为管理通道 |
| PSN | 24 bit | 包序列号 |
| Credit | per VL | 每 VL 独立信用计数 |
| MTU | 256/512/1024/2048/4096 | Payload 最大长度 |
| 包长 | 最大 4096+Header | LRH + BTH + Payload + ICRC |
| LID 类型 | Unicast(0-0x7FFF) / Multicast(0xC000-0xFFFF) | |

## 典型应用场景

- HPC 超算互连 (MPI over IB)
- AI/ML 集群 (NCCL over IB)
- 高性能存储 (Lustre, GPFS over IB)
- 数据中心互联 (IB Switch + HCA)

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| RDMA | IB 是 RDMA 原生传输 |
| RoCE v2 | RDMA 从 IB 移植到 Ethernet |
| UEC | 下一代 IB 兼容协议 |
| NVMe-oF | NVMe/RDMA over IB |
| PFC | IB 用 Credit Flow Control 替代 PFC |

## RTL 设计要点 (HCA 架构)

- **Credit 流控**：每 VL 独立 Credit 计数器，Credit 归零立即停止发送，收到 Credit Update 重载
- **链路级重传**：发送端保存已发包窗口 (16-entry Replay Buffer)，PSN 16-bit，接收端 NAK 触发重传
- **VL 调度**：16 VL 加权轮询调度，VL15 管理通道独立高优先级
- **LRH 解析**：提取 DLID/SLID/VL/Length/SL，路由到目标端口或 QP
- **ICRC 计算**：32-bit CRC 覆盖 BTH→Payload，与 RoCE v2 ICRC 算法一致
- **子网管理**：SMA (Subnet Management Agent) 响应 SM 查询，维护 LID/GID/PKey 表

## 参考

- IBTA InfiniBand Architecture Specification Vol.1 (Physical & Link)
- IBTA InfiniBand Architecture Specification Vol.2 (Transport)
- OPA (Omni-Path) Specification
