# NVMe-oF (NVMe over Fabrics)

> NVMe 协议在网络传输上的扩展，通过 RDMA/TCP/FC 等网络传输 NVMe 命令，实现远程存储访问。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 存储网络协议 |
| **标准** | NVM Express over Fabrics Spec 1.1 / 2.0 |
| **传输方式** | NVMe/RDMA / NVMe/TCP / NVMe/FC |

## 核心特性

1. **Capsule 格式**：SQ Capsule (Command + Inline Data) / RSP Capsule (Completion + Response Data)
2. **NVMe/RDMA**：基于 RDMA (RoCE v2/IB) 传输，低延迟 (~10μs)，需要 RNIC
3. **NVMe/TCP**：基于 TCP 传输，无需专用硬件，端口 4420，适合广域网
4. **NVMe/FC**：基于 Fibre Channel 传输，企业级存储网络
5. **Discovery 服务**：Discovery Controller 管理子系统发现，支持动态添加/删除远端 NVM 子系统

## 关键参数

| 参数 | NVMe/RDMA | NVMe/TCP | NVMe/FC |
|------|-----------|----------|---------|
| 传输层 | RDMA (RoCE v2/IB) | TCP | FC |
| 默认端口 | 4420 | 4420 | FC Well-Known |
| 延迟 | ~10-20 μs | ~50-100 μs | ~20-50 μs |
| 零拷贝 | 是 (RDMA) | 否 (需拷贝) | 是 |
| 硬件需求 | RNIC | 标准 NIC | FC HBA |
| Capsule 头 | 24 bytes (Command) | 8 bytes (PDU) | FC Header |

## 典型应用场景

- 分布式存储集群 (Ceph / VSAN)
- 远端 NVMe SSD 池化
- 数据中心存储网络
- 混合云存储

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| NVMe | NVMe-oF 是 NVMe 的网络传输扩展 |
| RDMA | NVMe/RDMA 使用 RDMA Send/RDMA Write |
| TCP | NVMe/TCP 使用 TCP 流式传输 |
| RoCE v2 | NVMe/RDMA 的以太网传输层 |
| FC | NVMe/FC 使用 Fibre Channel |

## RTL 设计要点

- **Capsule 解析**：SQ Capsule = Command(64B) + Inline Data (可选)；RSP Capsule = Completion(16B) + Response Data
- **NVMe/RDMA Send**：SQ Capsule 通过 RDMA Send 传输，Completion 通过 RDMA Send 返回
- **NVMe/TCP PDU**：8B PDU Header (PDU Type + Length) + Capsule Data，支持 PDU 级联
- **Discovery 处理**：Discovery Log Page 返回所有可达 NVM 子系统列表
- **Queue 映射**：NVMe-oF SQ/CQ 映射到网络 QP/连接，1:1 或 N:1 关系
- **Data 传输**：Read 数据通过 RDMA Write 直接写入 Host 内存 (零拷贝)

## 参考

- NVM Express over Fabrics Specification 1.1
- NVM Express over Fabrics Specification 2.0
- RFC 8026 (NVMe/TCP)
