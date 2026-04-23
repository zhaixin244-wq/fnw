# VirtIO

> 虚拟化 I/O 半虚拟化标准协议，定义 Guest 与 Hypervisor 之间的高效数据传输接口 (virtqueue)。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 虚拟化 IO 协议 |
| **标准** | OASIS VirtIO Specification v1.0-1.2 |
| **传输层** | MMIO / PCI / Channel I/O (s390) |

## 核心特性

1. **Virtqueue**：Host-Guest 数据传输核心结构，由 Descriptor Table + Available Ring + Used Ring 组成
2. **Split Virtqueue**：经典模式，Descriptor Table / Available / Used 三个独立区域
3. **Packed Virtqueue**：高密度模式，Descriptor + Flags 合并为单环，减少内存访问次数
4. **Feature Negotiation**：Host 和 Guest 通过 Feature Bits 协商功能 (VIRTIO_NET_F_CSUM / MRG_RXBUF 等)
5. **VDPA (vDPA)**：VirtIO 数据面硬件加速，virtio 接口 + SR-IOV 硬件后端

## 关键参数

| 参数 | Split | Packed |
|------|-------|--------|
| Descriptor | 16 bytes (addr+len+flags+next) | 16 bytes (addr+len+id+flags) |
| Ring 结构 | 3 个独立区域 | 1 个合并环 |
| 内存访问 | 3 次/描述符 | 1 次/描述符 |
| 间接描述 | 支持 (指向子表) | 支持 |
| 事件索引 | 可选 | 内置 |
| 最大队列深度 | 32768 | 32768 |

## 典型应用场景

- KVM/QEMU 虚拟化 IO (virtio-net / virtio-blk / virtio-scsi)
- VDPA 硬件加速虚拟交换
- Firecracker / Cloud Hypervisor 轻量虚拟化
- Kata Containers 安全容器

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| SR-IOV | VDPA = VirtIO 数据面 + SR-IOV 硬件后端 |
| PCIe | VirtIO over PCI 使用 PCIe BAR 传输 |
| Ethernet | virtio-net 虚拟网卡 |
| NVMe | virtio-blk 虚拟块设备 |

## RTL 设计要点

- **Descriptor 解析**：16B Descriptor → addr(GPA) + len + flags(VNEXT/VRING/INDIRECT/WRITE)
- **Available Ring 读取**：Guest 更新 idx → Host 读取 ring[idx mod size] → 获取 Descriptor Chain Head
- **Used Ring 写入**：Host 写入 ring[idx] = (id, len) → 更新 idx → 通知 Guest (中断/MMIO)
- **Packed Ring**：Descriptor Flags 内含 Used/Available 标志，单环读写，wrap counter 区分满/空
- **Feature Bits**：32-bit Feature 协商寄存器，Guest/Host 各自支持的 Feature 取交集
- **VDPA 硬件后端**：VF 的 virtqueue 直接映射到硬件 DMA 引擎，绕过 QEMU

## 参考

- OASIS VirtIO v1.2 Specification
- OASIS vDPA Specification
- Linux virtio-spec Documentation
