# RDMA (Remote Direct Memory Access)

> 远程直接内存访问技术，允许网卡直接读写远端主机内存，绕过 CPU/OS 实现超低延迟数据传输。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 高性能网络传输技术 |
| **标准** | IBTA (InfiniBand Trade Association) / OPA / RoCE |
| **传输方式** | Zero-copy, Kernel bypass, Hardware offload |

## 核心特性

1. **Queue Pair (QP)**：每连接一对队列 (Send Queue + Receive Queue)，QP 编号全局唯一，传输上下文隔离
2. **WQE/CQE**：Work Queue Element 描述操作，Completion Queue Element 通知完成，Doorbell 通知硬件
3. **Memory Region (MR)**：注册的内存区域，lkey/rkey 提供 DMA 访问权限，IOMMU 保护
4. **传输服务类型**：RC (可靠连接) / UC (不可靠连接) / UD (不可靠数据报) / RD (可靠数据报)
5. **核心操作**：Send/Recv / RDMA Write / RDMA Read / Atomic (CAS / Fetch&Add)

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| QP 数量 | 最大 2^24 | QPN 24-bit |
| MR lkey/rkey | 32 bit | 本地/远端内存访问密钥 |
| 最大消息 | 2^31 bytes | 单次 RDMA 操作上限 |
| Scatter-Gather | 最大 2^16 entries | SGE 列表 |
| 传输服务 | RC/UC/UD/RD | RC 最常用 |
| 门铃 (Doorbell) | MMIO Write | 通知硬件有新 WQE |

## 典型应用场景

- AI/ML 集群集合通信 (AllReduce, AllGather)
- 分布式存储 (NVMe-oF over RDMA)
- 高频交易 (超低延迟)
- HPC MPI 通信

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| InfiniBand | RDMA 原生传输，IB 链路层 |
| RoCE v2 | RDMA over Ethernet + UDP/IP |
| UEC | 下一代 RDMA，多路径+信用流控 |
| NVMe-oF | NVMe/RDMA 使用 RDMA 传输 |
| SR-IOV | VF 直通给 VM，RDMA 硬件加速 |

## RTL 设计要点 (RNIC 架构)

- **QP 上下文存储**：SRAM/TCAM 存储 QP 状态 (QPN→QP Context)，支持数万 QP
- **WQE 解析引擎**：解析 Send/RDMA Write/RDMA Read/Atomic 操作码，生成 DMA 描述符
- **DMA 引擎**：Scatter-Gather DMA，SGL 解析，IOMMU 地址翻译 (ATS/PRI)
- **消息分段/重组**：RC 模式 MTU 分段 (4KB 典型)，接收端重组
- **Completion 生成**：CQ 写入 + MSI-X 中断，支持 Event/Polled 两种模式
- **Atomic 操作**：CAS/Fetch&Add 原子执行引擎，保证远端内存原子性

## 参考

- IBTA InfiniBand Architecture Specification Vol.1-2
- RDMA over Converged Ethernet (RoCE) Specification
- OPA (Omni-Path Architecture) Specification
