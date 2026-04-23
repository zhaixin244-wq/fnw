# sr_iov

> PCI-SIG 定义的硬件虚拟化规范，允许单个 PCIe 设备虚拟出多个 VF 直通分配给 VM

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 协议 |
| 版本 | Rev 1.1 (PCI-SIG) |
| 来源 | .claude/knowledge/IO-protocol/sr_iov.md |

## 核心特性
- PF（Physical Function）派生多个 VF（Virtual Function），VF 直通 VM 绕过 Hypervisor
- IOMMU 保证 VF 间地址空间隔离，ATS/PRI 支持设备端地址翻译和按需分页
- 每个 VF 独立 BAR 空间、MSI-X 向量、收发队列
- 典型应用：10G/25G/100G 网卡、NVMe SSD、GPU、InfiniBand HCA

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| TotalVFs | 硬件定义 | 64~256 | 硬件支持的最大 VF 数 |
| NumVFs | 软件配置 | ≤TotalVFs | 实际启用的 VF 数 |
| VF Stride | 1 | ≥1 | 相邻 VF 的 RID 间隔 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| SR-IOV Capability ID | - | 16 | Ext Cap ID = 0x0010 |
| VF BAR0~BAR5 | RW | 32 | VF MMIO 地址空间控制 |
| VF Enable | RW | 1 | VF 全局使能位 |
| First VF Offset | RO | 16 | VF0 相对 PF 的 RID 偏移 |

## 典型应用场景
- 高性能网络虚拟化：VF 直通 VM，延迟接近裸金属
- NVMe 存储虚拟化：每个 VM 独立 VF 直通
- GPU 虚拟化：VF 直通 + ATS/PRI 按需分页

## 与其他实体的关系
- **PCIe**：SR-IOV 基于 PCIe Extended Capability，依赖 PCIe TLP 传输
- **VirtIO**：可结合使用，VF 直通 QEMU 后用 VirtIO 呈现给嵌套 VM
- **IOMMU**：SR-IOV 的 DMA 隔离依赖 IOMMU（VT-d/AMD-Vi）

## 设计注意事项
- VF BAR 空间总大小 = NumVFs × PerVF_BAR_Size，需在 64-bit 地址空间内分配
- 每个 VF 的 DMA TLP 必须携带正确的 BDF，不允许伪造
- VF FLR（Function Level Reset）不影响 PF 和其他 VF
- Gen6 支持 per-VF IDE 加密和 10-bit Tag 分配
- VF Migration 需支持状态冻结/导出接口

## 参考
- 原始文档：`.claude/knowledge/IO-protocol/sr_iov.md`
