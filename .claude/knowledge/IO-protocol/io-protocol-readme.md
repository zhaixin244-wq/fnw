# I/O 协议知识库总览

> **用途**：芯片设计常用 I/O 与存储协议参考文档，供 chip-arch agent 在 DPU/SmartNIC/存储控制器/SoC 架构设计时快速检索
> **总计**：7 个协议文档（不含 mips-io），覆盖 4 大类别

---

## 协议分类索引

### 1. PCIe 与虚拟化（2 个）

| 协议 | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| PCIe TLP 深度 | [pcie_tlp.md](pcie_tlp.md) | PCIe 事务层 TLP 包格式、Credit、排序、MSI-X、错误处理 | PCIe IP 设计、DMA 引擎 |
| SR-IOV | [sr_iov.md](sr_iov.md) | PCIe I/O 虚拟化，PF/VF 直通 | SmartNIC/DPU 虚拟化 |

> **与 bus-protocol/pcie.md 的关系**：`bus-protocol/pcie.md` 是 PCIe 协议概览，`IO-protocol/pcie_tlp.md` 聚焦 TLP 事务层深度设计，两者互为补充。

### 2. 虚拟化 I/O 框架（1 个）

| 协议 | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| VirtIO | [virtio.md](virtio.md) | 半虚拟化 I/O，Virtqueue/Vhost/VDPA (v1.3) | DPU 数据面加速 |

### 3. 存储协议（2 个）

| 协议 | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| NVMe | [nvme.md](nvme.md) | PCIe SSD 控制器接口，队列体系 | NVMe SSD 控制器、DPU 存储卸载 |
| NVMe-oF | [nvme_of.md](nvme_of.md) | NVMe over Fabrics，远程存储访问 | NVMe-oF Target/Host、DPU |

### 4. 缓存一致性互联（1 个）

| 协议 | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| AMBA CHI | [chi.md](chi.md) | 多核一致性互联，替代 ACE | 多核 SoC、GPU、一致性互联 |

### 5. SoC 片外接口（1 个）

| 协议 | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| MIPS-IO | [mips-io.md](mips-io.md) | I2C/SPI/GPIO 片外配置接口 | SoC 管理接口 |

---

## 协议栈全景图

### DPU / SmartNIC 典型协议栈

```
┌─────────────────────────────────────────────────────────────────┐
│                        应用层                                    │
│            NVMe-oF Target / RDMA App / VirtIO Backend           │
├─────────────────────────────────────────────────────────────────┤
│                     协议处理层                                    │
│  NVMe │ VirtIO (Virtqueue) │ RDMA (RoCE v2) │ TCP/UDP Offload  │
├─────────────────────────────────────────────────────────────────┤
│                    I/O 虚拟化层                                   │
│  SR-IOV (PF/VF) │ IOMMU (DMA Remap) │ ATS │ VF Migration      │
├─────────────────────────────────────────────────────────────────┤
│                     PCIe 事务层                                  │
│  TLP 处理 │ DMA 引擎 │ MSI-X │ Flow Control Credit             │
├─────────────────────────────────────────────────────────────────┤
│                    PCIe 数据链路层 + 物理层                        │
│  Gen3/Gen4/Gen5 — LTSSM / 128b130b / Link Training              │
│  Gen6 — PAM4 / 1b/1b FLIT / IDE / Lane Margining               │
└─────────────────────────────────────────────────────────────────┘
```

### 多核 SoC 缓存一致性架构

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ CPU Cl0  │  │ CPU Cl1  │  │   GPU    │
│  (RN-F)  │  │  (RN-F)  │  │  (RN-F)  │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
     └──────┬──────┴──────┬──────┘
            │             │
     ┌──────▼──────┐ ┌────▼─────┐
     │   HN-F      │ │  HN-I    │
     │(一致性目录)  │ │(IO一致性)│
     └──────┬──────┘ └────┬─────┘
            │             │
     ┌──────▼─────────────▼──────┐
     │         SN-F              │
     │     (DDR Controller)      │
     └───────────────────────────┘
              AMBA CHI
```

---

## 协议关系对照

| 场景 | 推荐协议 | 关联协议 |
|------|----------|----------|
| PCIe 设备直连 | PCIe TLP + SR-IOV | MSI-X, IOMMU |
| SSD 控制器 | NVMe | PCIe TLP, DMA |
| 远程存储 | NVMe-oF | NVMe + RDMA/TCP |
| VM I/O 直通 | SR-IOV | PCIe, IOMMU, ATS |
| VM I/O 通用 | VirtIO | Vhost, VDPA |
| DPU 数据面 | SR-IOV + VirtIO + NVMe | PCIe TLP, RDMA |
| 多核一致性 | CHI | ACE (旧系统) |
| SoC 管理接口 | I2C/SPI/GPIO | JTAG (调试) |

---

## 典型芯片产品与 I/O 协议需求

| 芯片产品 | I/O 协议需求 |
|----------|-------------|
| **NVMe SSD 控制器** | NVMe + PCIe TLP + DMA + Flash Translation Layer |
| **SmartNIC / DPU** | SR-IOV + VirtIO-VDPA + NVMe-oF + PCIe TLP + RDMA |
| **GPU** | CHI (一致性) + PCIe TLP + NVLink (专有) |
| **多核 SoC** | CHI (一致性) + PCIe TLP + SR-IOV + NVMe |
| **存储加速卡** | NVMe + NVMe-oF + RDMA + PCIe TLP |
| **网卡 (NIC)** | SR-IOV + PCIe TLP + RDMA + TCP Offload |

---

## 选型速查

### I/O 虚拟化方案选型

| 特性 | SR-IOV | VirtIO | VDPA |
|------|--------|--------|------|
| 性能 | 最高（硬件直通） | 中等（软件模拟） | 高（硬件 Virtqueue） |
| 驱动 | 特定硬件驱动 | 通用驱动 | 通用驱动 |
| 灵活性 | 低（固定 VF） | 高（纯软件） | 高（硬件+通用驱动） |
| Live Migration | 困难 | 容易 | 容易 |
| 硬件复杂度 | 中 | 低（软件实现） | 高 |
| 隔离性 | 强（IOMMU） | 中（软件隔离） | 强（IOMMU） |
| 推荐 | 延迟敏感场景 | 通用虚拟化 | 性能+灵活性兼顾 |

### NVMe vs NVMe-oF

| 特性 | 本地 NVMe | NVMe-oF (RDMA) | NVMe-oF (TCP) |
|------|----------|---------------|---------------|
| 延迟 | ~10μs | ~17μs | ~30μs |
| 距离 | 机箱内 | 数据中心内 | 广域网 |
| 部署 | 简单 | 需 RoCE 网络 | 通用 TCP 网络 |
| 共享 | 不支持 | 支持 | 支持 |
| 典型应用 | 本地 SSD | 分布式存储 | 混合云存储 |

---

## 文档格式说明

每个协议文档包含以下标准章节：

| 章节 | 内容 |
|------|------|
| 协议概述 | 特性、定位、规范版本、典型应用 |
| 核心概念 | 数据结构、状态机、控制流 |
| 包/帧格式 | Header ASCII 框图，逐字段位宽说明 |
| 时序/流程 | ASCII 波形或事务流程图 |
| 对比表 | 与同类协议的特性对比 |
| 设计注意事项 | RTL 设计要点、硬件加速方案、常见陷阱 |

**配合 chip-arch agent 使用**：在生成 FS/微架构文档时，agent 会检索本目录下的协议文档作为接口设计参考。
