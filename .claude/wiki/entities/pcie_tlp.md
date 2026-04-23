# PCIe TLP (Transaction Layer Packet)

> PCIe 事务层数据包协议，定义设备间通信的请求/完成格式，是 PCIe 总线的核心数据交换机制。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | IO 总线协议（PCIe 事务层） |
| **标准** | PCI Express Base Specification (Gen1-6) |
| **版本** | Gen1(2.5GT/s) → Gen2(5G) → Gen3(8G) → Gen4(16G) → Gen5(32G) → Gen6(64G, PAM4/FLIT) |

## 核心特性

1. **TLP 类型**：Memory Read/Write (MRd/MWr) / IO Read/Write / Completion (CplD) / Config / Message / AtomicOp
2. **Posted vs Non-Posted**：MWr/Message 为 Posted (不需 Completion)；MRd/IO/Cfg 为 Non-Posted (需 CplD 返回)
3. **Flow Control Credits**：Header (PH/PH) + Data (PD/NPD) + Completion (CH/CD) 六种信用类型
4. **MSI-X 中断**：Memory Write 格式的中断消息，支持最多 2048 向量/Function，地址+数据模式
5. **Gen6 FLIT**：固定 256B FLIT (Flow Control Unit)，替代可变长 TLP，内置 CRC + FEC

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| TLP 头部长度 | 3/4 DW (12/16 bytes) | 3DW: 32-bit 地址; 4DW: 64-bit 地址 |
| 最大载荷 (MPS) | 128/256/512/1024/2048/4096 bytes | 典型 256B 或 512B |
| Max Read Request | 128B - 4096B | Gen5+ 支持 4096B |
| Completion Timeout | 50μs - 50ms | 可配置，超时重试 |
| FC Credit 单位 | Header: 1 credit = 1 DW / Data: 1 credit = 4 DW | |
| MSI-X 向量 | 最大 2048 | Per Function |
| Gen6 FLIT | 256 bytes | 236B Payload + 6B CRC + 8B FEC + 6B Header |

## 典型应用场景

- PCIe Endpoint 设备 (NVMe SSD / GPU / NIC)
- PCIe Root Complex (CPU 内集成)
- PCIe Switch 互联
- CXL (Compute Express Link) 互联

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| NVMe | NVMe SQ/CQ 通过 PCIe BAR MMIO + DMA 访问 |
| SR-IOV | VF 的 TLP 携带 VF BDF，IOMMU 按 BDF 翻译 |
| CXL | 基于 PCIe 物理层，TLP 扩展 (CXL.cache/mem) |
| ATS | TLP 扩展用于地址翻译请求/完成 |

## RTL 设计要点

- **TLP 解析**：提取 Fmt(2b)+Type(5b) 区分 MRd/MWr/CplD，DW0 字段解析
- **Flow Control**：6 种 FC Credit 独立计数 (PH/PD/NPH/NPD/CH/CD)，初始化后每 TLP 消耗
- **Completion 超时**：Non-Posted 请求发送后启动定时器，超时触发 Completion Timeout Status
- **MSI-X 发送**：构建 Memory Write TLP，地址=MSI-X Table Address，数据=MSI-X Table Data
- **Gen6 FLIT 模式**：256B 固定帧长，CRC-6 + FEC(Reed-Solomon)，支持 2-cycle 纠错
- **10-bit Tag (Gen5+)**：支持 1024 outstanding 请求，Tag 管理需 per-VF 分配

## 参考

- PCI Express Base Specification Rev 6.0
- PCI-SIG SR-IOV Specification Rev 1.1
- CXL Specification Rev 3.0
