# CHI (AMBA Coherent Hub Interface)

> ARM AMBA 5 高性能缓存一致性互联协议，基于点对点事务化架构，支持大规模多核一致性系统。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 片上互联一致性协议 |
| **标准** | AMBA CHI Specification (Issue C/D) |
| **版本** | CHI-A(2013) → CHI-B(2016) → CHI-C(2019) → CHI-D(2021) |

## 核心特性

1. **三类节点**：RN (Request Node, 发起请求) / HN (Home Node, 归属一致性) / SN (Subordinate Node, 存储/外设)
2. **四通道架构**：REQ (请求) / RSP (响应) / SNP (Snoop) / DAT (数据)，Valid/Ready 握手
3. **五态缓存模型**：UC (Unique Clean) / UD (Unique Dirty) / SC (Shared Clean) / SD (Shared Dirty) / I (Invalid)
4. **分布式 HN**：每个 HN 管理一段地址范围的一致性，支持 Snoop Filter / Full Directory
5. **Retry 机制**：HN 资源不足时返回 RetryAck + PCrdGrant，避免阻塞

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| TxnID | 12 bit | 事务标识 |
| NodeID | 7 bit | 节点编号 (最多 128 节点) |
| Cache Line | 64 bytes | 一致性粒度 |
| 通道数 | 4 (REQ/RSP/SNP/DAT) | 独立通道 |
| Snoop Filter | 按地址记录 RN 缓存状态 | 减少无效 Snoop |
| 原子操作 | AtomicStore/Load/Swap/Compare | 原生支持 |
| Stash | StashOnceShared/Unique | 数据推送到指定 RN |

## 典型应用场景

- ARM 多核 CPU Cluster 互联 (Cortex-A/X)
- DPU/SmartNIC 内部 SoC 一致性互联
- AI 芯片多核一致性系统

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| ACE (AXI Coherency) | CHI 是 ACE 的继承者，解决扩展性瓶颈 |
| AXI4 | CHI-to-AXI Bridge 用于非一致性外设 |
| SR-IOV | PCIe EP 作为 RN-I 接入 CHI 一致性域 |
| CHI-D IDE | 数据加密，防止总线嗅探 |

## RTL 设计要点

- **HN 一致性逻辑**：Snoop Filter (SRAM) 记录地址→RN 映射，目录查找 1 周期
- **四通道流控**：独立 Credit 管理 per channel，Retry 机制避免死锁
- **Snoop 路由**：基于目录查找结果点对点发送 Snoop，非广播
- **数据转发**：支持 RN-to-RN 直接数据转发 (Request Forwarding)，减少 HN 中转
- **Ordering 逻辑**：Endpoint Order / Request Order，per-RN 请求队列串行化
- **Retry 状态机**：RN 保存事务上下文等待 PCrdGrant，HN 管理 per-channel credit 池

## 参考

- AMBA CHI Specification Issue C
- AMBA CHI Specification Issue D (IDE)
- ARM Coherent Mesh Network (CMN) TRM
