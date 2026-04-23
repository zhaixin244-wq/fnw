# SR-IOV (Single Root I/O Virtualization) 协议知识文档

> **面向**：数字 IC 设计架构师
> **规范来源**：PCI-SIG PCI Express Single Root I/O Virtualization and Sharing Specification (Rev 1.1)，兼容 PCIe Gen6.3 Base Specification
> **适用场景**：PCIe Endpoint / Root Complex / Switch 设计，网卡/NVMe/GPU 等设备虚拟化；Gen6 新增 IDE 加密对 VF 隔离的增强

---

## 1. 协议概述

SR-IOV 是 PCI-SIG 定义的硬件虚拟化规范，允许一个物理 PCIe 设备（PF）在硬件层面虚拟出多个轻量级 PCIe 功能（VF），每个 VF 可以直通分配给虚拟机（VM），绕过 Hypervisor 实现近原生的 I/O 性能。

**核心价值**：
- **性能**：VF 直通，数据面不经 Hypervisor，延迟接近裸金属
- **隔离**：IOMMU 保证 VF 间地址空间隔离
- **密度**：单设备服务多个 VM，减少硬件成本

**典型应用**：10G/25G/100G 网卡、NVMe SSD、GPU、InfiniBand HCA

---

## 2. SR-IOV 核心概念

### 2.1 PF (Physical Function)

- 完整的 PCIe Function，支持所有标准 PCIe Capability
- 包含 SR-IOV Extended Capability 结构，用于管理 VF
- Host 驱动通过 PF 配置 VF 数量、使能/禁用 VF
- PF 自身可以独立承担 I/O 操作（与 VF 并存）

### 2.2 VF (Virtual Function)

- 轻量级 PCIe Function，仅包含数据移动所需的最小资源
- 从 PF 派生，共享 PF 的物理资源（如网卡的 MAC/PHY）
- 每个 VF 有独立的 BAR 空间、独立的 MSI-X 向量
- VF 不能独立存在，必须依附于 PF
- VF 具有完整的 Bus/Device/Function 编号，可被 VM 直接访问

### 2.3 VF BAR

- 每个 VF 拥有独立的 BAR，定义其 MMIO 地址空间
- VF BAR 寄存器位于 SR-IOV Capability 结构中（非标准 BAR 位置）
- 实际地址 = VF BAR 基地址 + VF Stride x VF 编号
- VF BAR 大小由 PF 配置，所有 VF 共享相同大小

### 2.4 PF/VF 关系

```
1 个 PF 可派生 N 个 VF
N 的范围：
  - TotalVFs：硬件支持的最大 VF 数（只读，硬件上限）
  - NumVFs：软件实际启用的 VF 数（可写，≤ TotalVFs）
  - VF Enable：全局使能位
```

---

## 3. SR-IOV Capability 结构

SR-IOV Capability 属于 PCIe Extended Capability，Capability ID = 0x0010。

```
+---------------------------------------------------------------+
| SR-IOV Capability Structure (Extended Capability)             |
+----------------+----------------+-----------------------------+
| Offset  Field  | Size (bytes)   | Description                 |
+----------------+----------------+-----------------------------+
| 0x00  Cap Header| 4             | Ext Cap ID = 0x0010         |
|                |                | Cap Version = 0x01          |
|                |                | Next Cap Offset             |
+----------------+----------------+-----------------------------+
| 0x04  TotalVFs | 2             | 硬件支持的最大 VF 数         |
+----------------+----------------+-----------------------------+
| 0x06  Function | 2             | VF Migration 拥有者         |
|        Dep Link|                | (Function Dependency Link)  |
+----------------+----------------+-----------------------------+
| 0x08  First VF | 2             | 第一个 VF 相对 PF 的路由     |
|        Offset  |                | 偏移（RID 偏移）            |
+----------------+----------------+-----------------------------+
| 0x0A  VF Stride| 2             | 相邻 VF 的路由间隔           |
+----------------+----------------+-----------------------------+
| 0x0C  VF Enable| 2             | VF Enable 位图              |
+----------------+----------------+-----------------------------+
| 0x0E  VF Status| 2             | VF Status（保留/状态）       |
+----------------+----------------+-----------------------------+
| 0x10  VF BAR0  | 4             | VF BAR0 基地址和大小控制     |
+----------------+----------------+-----------------------------+
| 0x14  VF BAR1  | 4             | VF BAR1（如需 64-bit BAR）  |
+----------------+----------------+-----------------------------+
| 0x18  VF BAR2  | 4             | VF BAR2                     |
+----------------+----------------+-----------------------------+
| 0x1C  VF BAR3  | 4             | VF BAR3（可选）             |
+----------------+----------------+-----------------------------+
| 0x20  VF BAR4  | 4             | VF BAR4（可选）             |
+----------------+----------------+-----------------------------+
| 0x24  VF BAR5  | 4             | VF BAR5（可选）             |
+----------------+----------------+-----------------------------+
| 0x28  VF Migr  | 4             | VF Migration State Array    |
|        State   |                | (初始化能力/状态)           |
+----------------+----------------+-----------------------------+
| 0x2C  VF Device| 2             | VF 的 Device ID             |
|        ID      |                |                             |
+----------------+----------------+-----------------------------+
| 0x2E  Supported| 4             | VF 支持的页面大小位图        |
|        Page Sz |                |                             |
+----------------+----------------+-----------------------------+
| 0x32  System   | 4             | 系统页面大小（对 DMA 映射）  |
|        Page Sz |                |                             |
+----------------+----------------+-----------------------------+
```

**关键字段说明**：

| 字段 | RTL 设计要点 |
|------|-------------|
| `TotalVFs` | 硬件常量，决定最大 VF 寄存器组数 |
| `NumVFs` | 软件编程值，决定实际启用的 VF 数，触发资源分配 |
| `VF Enable` | 置位后 VF 出现在 PCIe 总线上，需先配置 BAR |
| `First VF Offset` | VF0 相对 PF 的 RID 偏移，典型值 1 |
| `VF Stride` | VF 间 RID 间隔，典型值 1 |
| `VF BARs` | 定义每个 VF 的 MMIO 空间大小，所有 VF 共用同一大小 |
| `Supported Page Sizes` | IOMMU 相关，位图表示支持的页面大小 |
| `System Page Size` | 软件选择的系统页面大小，影响 DMA 映射粒度 |

---

## 4. 地址翻译三件套：IOMMU / ATS / PRI

```
  VM 应用层    │  Guest IOVA
              ▼
  Guest 驱动  │  DMA Request (IOVA)
              ▼
  ┌───────────────────────────┐
  │     IOMMU (DMA Remapping) │  ← IOVA → PA 翻译 + 权限检查
  │     Intel VT-d / AMD-Vi   │
  └─────────┬─────────────────┘
            │ PA (Physical Address)
            ▼
  ┌───────────────────────────┐
  │     ATS (Device-side TLB) │  ← 设备缓存翻译结果，减少 IOMMU 查表
  │     PCIe ATS Capability   │
  └─────────┬─────────────────┘
            │ Cached PA
            ▼
  ┌───────────────────────────┐
  │     PRI (Page Request)    │  ← 按需分页：设备请求未映射的页
  │     PCIe PRI Capability   │
  └───────────────────────────┘
```

### 4.1 IOMMU (DMA Remapping)

- **功能**：IOVA (I/O Virtual Address) 到 PA (Physical Address) 的翻译
- **每个 VF 独立的地址空间**：IOMMU 用 RID (Requester ID) 区分不同 VF 的翻译表
- **隔离保证**：VM A 的 VF 只能访问 VM A 的物理内存
- **规格**：Intel VT-d (Virtualization Technology for Directed I/O)、AMD-Vi (I/O Virtualization)
- **RTL 要点**：设备发出的 DMA TLP 中携带 VF 的 BDF，IOMMU 用 BDF 索引翻译表

### 4.2 ATS (Address Translation Service)

- **功能**：设备本地缓存 IOMMU 翻译结果（Device-side TLB），减少每次 DMA 都查 IOMMU 的开销
- **工作流程**：
  1. 设备发送 ATS Translation Request 给 Root Complex
  2. IOMMU 翻译后返回 ATS Completion（带 PA + 权限）
  3. 设备缓存到本地 TLB
  4. 后续 DMA 直接用缓存的 PA
- **Invalidate 机制**：IOMMU 发送 ATS Invalidate Request，设备清除缓存
- **RTL 要点**：需实现 ATC (Address Translation Cache) 模块，处理 Translation Request/Completion/Invalidate

### 4.3 PRI (Page Request Interface)

- **功能**：按需分页（Demand Paging），当设备访问未映射的页面时，向 IOMMU 请求映射
- **工作流程**：
  1. 设备 DMA 命中未映射页 → 发送 Page Request
  2. IOMMU/Hypervisor 处理：分配物理页、建立映射
  3. IOMMU 返回 Page Response（成功/失败）
  4. 设备重试 DMA
- **适用场景**：GPU 大地址空间、设备虚拟内存
- **RTL 要点**：需实现 PRI Requester 状态机，处理 Page Request/Response/PRG Response Passthrough

---

## 5. 中断虚拟化

### 5.1 MSI/MSI-X 分配

| 特性 | PF | VF |
|------|----|----|
| MSI | 支持 | 支持 |
| MSI-X | 支持 | 支持（每 VF 独立 MSI-X 表） |
| 中断向量数 | PF 配置 | PF 配置每个 VF 的向量数上限 |

- 每个 VF 拥有独立的 MSI-X Table 和 PBA (Pending Bit Array)
- MSI-X Table 基地址由 VF 的 BAR 映射
- 中断消息地址/数据写入 PCIe Memory Write TLP

### 5.2 Interrupt Remapping

- **IOMMU 功能**：拦截设备发出的 MSI/MSI-X，根据 RID 查中断重映射表
- **作用**：
  - 防止 VF 伪造中断目标地址（安全隔离）
  - 支持中断迁移（VM 迁移时重映射中断目标 CPU）
  - 中断聚合与负载均衡
- **RTL 要点**：MSI/MSI-X Write TLP 中携带 VF 的 BDF，IOMMU 用 BDF + vector 索引重映射表

---

## 6. DMA 隔离

```
+-------------------+-------------------+                    +-------------+
|      VF 0         |      VF 1         |      ...           |    PF       |
|  DMA Engine 0     |  DMA Engine 1     |                    | DMA Engine  |
|  BDF: 01:00.0     |  BDF: 01:00.1     |                    | BDF: 01:00.7|
+--------+----------+--------+----------+                    +------+------+
         |                   |                                       |
         +-------+-----------+-----------+---------------------------+
                 |                       |
                 ▼                       ▼
         +--------------------------------------+
         |          IOMMU (VT-d / AMD-Vi)       |
         |  RID-based Translation Table         |
         |  VF0 → Page Table A (VM A 物理内存)  |
         |  VF1 → Page Table B (VM B 物理内存)  |
         +--------------------------------------+
```

- **核心机制**：每个 VF 有独立的 Requester ID (BDF)，IOMMU 按 BDF 选择翻译表
- **硬件保证**：VF 的 DMA Engine 物理上只能使用自己的 BDF 发请求
- **RTL 要点**：每个 VF 的 DMA 控制器在 TLP Header 中固定插入 VF 的 BDF，不允许伪造

---

## 7. VF 典型使用流程

```
步骤 1: Host 发现 PF
  └─ PCIe 枚举 → PF 出现 → 读取 SR-IOV Capability

步骤 2: Host 配置 VF
  └─ 写 NumVFs = N → 配置 VF BAR（大小、地址）→ 写 VF Enable

步骤 3: VF 出现在总线上
  └─ 硬件为 VF0..VF(N-1) 分配 BDF
  └─ Host 为每个 VF 分配 IOMMU 翻译表

步骤 4: VF 直通给 VM
  └─ Hypervisor 将 VF 的 BDF 加入 VM 的设备列表
  └─ VM PCIe 枚举发现 VF → 加载 VF 驱动

步骤 5: VM 驱动直接操作 VF
  └─ MMIO 读写 VF BAR 空间（不经 Hypervisor）
  └─ 配置 DMA 描述符，IOMMU 自动翻译

步骤 6: DMA 通过 IOMMU 翻译
  └─ VF DMA → IOVA → IOMMU 查表 → PA → 访问 VM 内存

步骤 7: 中断送达 VM
  └─ VF MSI-X → IOMMU Interrupt Remap → 送达 VM vCPU
```

---

## 8. SR-IOV vs VirtIO 对比

| 维度 | SR-IOV | VirtIO |
|------|--------|--------|
| **本质** | 硬件虚拟化（硬件直通） | 半虚拟化（软件协议） |
| **性能** | 接近裸金属，延迟 < 1us | 有 Hypervisor 开销，延迟 ~10us |
| **驱动** | 需要特定硬件驱动（e.g., ixgbevf） | 通用 virtio 驱动，OS 内置 |
| **Live Migration** | 困难，需设备状态保存/恢复或 fallback | 容易，队列状态在内存中 |
| **硬件依赖** | 需要支持 SR-IOV 的设备 + IOMMU | 纯软件，任何硬件均可 |
| **灵活性** | 固定 VF 数量，扩展受限 | Virtio 设备动态创建/销毁 |
| **隔离** | IOMMU 硬件隔离，安全性高 | Hypervisor 软件隔离 |
| **典型场景** | 高性能网络、存储、GPU | 云环境通用 I/O |
| **RTL 复杂度** | 高（VF 寄存器组、IOMMU、ATS、MSI-X per VF） | 低（MMIO 寄存器 + 队列接口） |
| **SR-IOV + VirtIO** | 可结合：VF 直通给 QEMU，QEMU 内用 VirtIO 呈现给嵌套 VM | — |

---

## 9. 网卡 SR-IOV 架构

```
                    PCIe Bus
                       │
              ┌────────┴────────┐
              │   PF Manager    │
              │  (配置/管理)     │
              │  - VF 创建/使能  │
              │  - QoS 配置     │
              │  - 统计/中断     │
              └──┬───┬───┬──┬──┘
                 │   │   │  │
         ┌───────┘   │   │  └───────┐
         ▼           ▼   ▼          ▼
    +---------+ +---------+  +---------+   +---------+
    | VF 0    | | VF 1    |  | VF 2    |...| VF N    |
    | Queues: | | Queues: |  | Queues: |   | Queues: |
    | RxQ 0   | | RxQ 1   |  | RxQ 2   |   | RxQ N   |
    | TxQ 0   | | TxQ 1   |  | TxQ 2   |   | TxQ N   |
    | MSI-X   | | MSI-X   |  | MSI-X   |   | MSI-X   |
    | BAR     | | BAR     |  | BAR     |   | BAR     |
    +----+----+ +----+----+  +----+----+   +----+----+
         │           │            │               │
         └─────┬─────┴────┬──────┘               │
               │           │                     │
        +──────┴───────────┴─────────────────────┘
        │
  +─────┴──────────────────────────────┐
  │         共享物理资源                │
  │  ┌──────────┐  ┌──────────┐        │
  │  │ MAC/PHY  │  │ Switch/  │        │
  │  │ 10G/25G  │  │ Filter   │        │
  │  └──────────┘  └──────────┘        │
  │  ┌──────────┐  ┌──────────┐        │
  │  │ DMA      │  │ QoS      │        │
  │  │ Engines  │  │ Shaping  │        │
  │  └──────────┘  └──────────┘        │
  └────────────────────────────────────┘
               │
          Physical Port
```

**要点**：
- 每个 VF 拥有独立的收发队列和 MSI-X 中断
- MAC/PHY 等物理层资源由所有 VF 共享
- 内部 Switch 负责 VF 间转发和外部端口过滤
- QoS 模块实现每个 VF 的带宽限速和优先级调度

---

## 10. 设计注意事项

### 10.1 VF 数量限制

- 典型范围：64 ~ 256 个 VF / PF
- 受限因素：BAR 地址空间大小、寄存器资源、队列数量、中断向量数
- 设计建议：VF BAR 空间总大小 = NumVFs x PerVF_BAR_Size，需在 64-bit 地址空间内分配

### 10.2 QoS per VF

- 每个 VF 的带宽限制（Rate Limiting）和速率整形（Traffic Shaping）
- 通常由 PF 的 QoS 寄存器配置，硬件 Token Bucket 实现
- VF 间加权轮询（WRR）或严格优先级调度

### 10.3 VF Migration (Live Migration)

- **难点**：设备内部状态（DMA 进行中、中断待处理、队列状态）需保存/恢复
- **方案 A**：VF Pause + Save/Restore — 暂停 VF，保存状态到内存，恢复到目标主机
- **方案 B**：PF 接管 fallback — VF 暂停期间由 PF 接管 I/O，VM 感知为短暂中断
- **方案 C**：VDPA (vDPA) — 使用 VirtIO 数据面 + SR-IOV 硬件加速，兼顾迁移和性能
- **RTL 设计**：需支持 VF 状态冻结/导出接口，VF Migration State 寄存器

### 10.4 VF-PF 通信 (Mailbox)

- VF 无法直接访问 PF 的配置空间（PCIe 规则限制）
- 通信通过共享内存 + Doorbell 中断实现：
  1. VF 写 Mailbox 消息到共享 SRAM（映射在 VF BAR 中）
  2. VF 写 Doorbell 寄存器触发 PF 中断
  3. PF 读取 Mailbox、处理、写回复、触发 VF 中断
- **RTL 要点**：Mailbox SRAM 需支持双端口访问（PF + VF），需仲裁冲突

### 10.5 PCIe ACS (Access Control Services)

- ACS 强制 PCIe Switch 内部的请求路由遵循 BDF 匹配
- 防止 VF 向不属于自己的地址域发出请求
- SR-IOV 设备通常不经过 Switch（VF 直接在 Endpoint 内），但仍需配合 Root Port 的 ACS

### 10.6 RTL 设计要点

| 设计项 | 说明 |
|--------|------|
| **VF 寄存器组复制** | 每个 VF 一组独立的数据面寄存器（Queue 状态、DMA 配置等），用 VF 编号索引。PF 寄存器和 VF 寄存器分开设计。 |
| **VF BAR 译码** | BAR 匹配逻辑需支持 VF 段：`if (addr >= VF_BAR_BASE + vf_id*stride && addr < VF_BAR_BASE + (vf_id+1)*stride)` |
| **DMA IOMMU 请求生成** | DMA Engine 输出 TLP 必须携带正确的 VF BDF（Bus/Device/Function），通过 PF 配置间接获取或硬件固定分配 |
| **MSI-X Table per-VF** | 每个 VF 独立的 MSI-X Table（64 个向量 x 16 字节 = 1KB per VF），映射在 VF BAR 中。中断发送时使用 VF 的 BDF。 |
| **VF 间资源仲裁** | 共享资源（DMA Engine、出端口队列）需 Round-Robin 或加权仲裁，保证公平性 |
| **VF 复位** | VF Function Level Reset (FLR) 不影响 PF 和其他 VF，需逐 VF 的独立复位控制 |
| **VF Enable 时序** | VF Enable 置位后，VF BAR 翻译、队列使能需按序启动；VF Disable 时需等待 DMA 完成后再释放 |
| **Gen6 IDE per-VF** | Gen6 支持按 VF 选择性启用 IDE 加密，每个 VF 可配置独立的 IDE Key。需在 VF 寄存器组中增加 IDE 配置接口 |
| **Gen6 10-bit Tag per-VF** | Gen6 支持 1024 outstanding 请求，VF 间需分配 Tag 范围（如 VF0: 0~127, VF1: 128~255 等），避免 Tag 冲突 |

---

## 附录：缩略语

| 缩写 | 全称 |
|------|------|
| ACS | Access Control Services |
| ATS | Address Translation Service |
| BDF | Bus/Device/Function |
| FLR | Function Level Reset |
| IOVA | I/O Virtual Address |
| IOMMU | I/O Memory Management Unit |
| MSI | Message Signaled Interrupts |
| MSI-X | Extended Message Signaled Interrupts |
| PA | Physical Address |
| PF | Physical Function |
| PRI | Page Request Interface |
| QoS | Quality of Service |
| RID | Requester ID |
| SR-IOV | Single Root I/O Virtualization |
| TLP | Transaction Layer Packet |
| VDPA | Virtio Data Path Acceleration |
| VF | Virtual Function |
| VT-d | Virtualization Technology for Directed I/O |
