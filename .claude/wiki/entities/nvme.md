# NVMe (Non-Volatile Memory Express)

> 闪存/SSD 存储访问协议，基于 PCIe 传输，通过 Submission/Completion Queue + Doorbell 实现高效 IO 处理。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 存储协议（应用层） |
| **标准** | NVM Express Base Specification (1.4/2.0) |
| **传输层** | PCIe (NVMe) / RDMA/TCP/FC (NVMe-oF) |

## 核心特性

1. **队列模型**：最多 65535 个 IO SQ + 1 Admin SQ，每 SQ 对应 1 CQ，SQ 深度最大 65536 entries
2. **SQ/CQ 提交**：Host 写 SQ Doorbell (64B 条目) 通知 SSD，SSD 写 CQ 条目 + 触发 MSI-X 中断
3. **PRP/SGL**：Physical Region Page (PRP) 描述不连续物理页；Scatter-Gather List (SGL) 支持连续/分散传输
4. **命令集**：Read/Write (LBA+NLB) / Flush / Dataset Management / Compare and Write / Write Zeroes
5. **多队列并行**：每个 CPU Core 绑定独立 SQ/CQ，无锁并发，减少中断聚合

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| SQ/CQ Entry | 64B / 16B | SQ 命令 64B，CQ 完成 16B |
| 最大队列数 | 65535 IO SQ + 1 Admin | 每 SQ 独立 CQ |
| SQ 深度 | 最大 65536 | 受 Controller 内存限制 |
| PRP Entry | 8 bytes | 物理地址 (页对齐) |
| SGL 描述符 | 16 bytes | 类型+地址+长度 |
| LBA 大小 | 512B / 4096B | 可配置 |
| Doorbell 寄存器 | 4 bytes/队列 | SQ: Tail Doorbell / CQ: Head Doorbell |
| MSI-X 向量 | 最大 2048 | Per CQ 绑定 |

## 典型应用场景

- 企业级 NVMe SSD
- 数据中心存储服务器
- NVMe-oF 存储网络
- GPU Direct Storage (GDS)

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| PCIe | NVMe 传输层，BAR0 映射寄存器 |
| NVMe-oF | NVMe over Fabrics 扩展 |
| RDMA | NVMe/RDMA 使用 RDMA 传输 NVMe 命令 |
| TCP | NVMe/TCP 使用 TCP 传输 |
| SR-IOV | NVMe VF 直通给 VM |

## RTL 设计要点 (NVMe Controller)

- **SQ/CQ SRAM**：SQ 64B×Depth + CQ 16B×Depth，Host DMA 写入，Controller DMA 读取
- **Doorbell 寄存器**：MMIO 映射在 BAR0，Host 写 Tail → 通知 Controller 有新命令
- **命令解析引擎**：提取 Opcode(8b) + NSID(32b) + PRP/SGL + LBA + NLB
- **PRP 遍历**：PRP1 直接页地址，PRP2→PRP List 页→多个页地址 (不连续 DMA)
- **SGL 解析**：SGL Segment/Last 描述符递归解析，Type 区分 Data Block/Segment/Last
- **完成队列写入**：CQ Entry = SQID(16b)+SQHD(16b)+CID(16b)+Status(16b)，Phase bit 翻转

## 参考

- NVM Express Base Specification 2.0
- NVM Express NVMe Management Interface Spec
- NVM Express over Fabrics Spec 1.1
