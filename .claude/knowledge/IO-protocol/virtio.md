# VirtIO 协议知识文档

> **适用读者**：数字 IC 设计架构师
> **参考规范**：OASIS VirtIO 1.0 (Split Virtqueue) / 1.1 (Packed Virtqueue) / 1.2 / 1.3
> **用途**：VDPA / VirtIO 硬件加速引擎架构设计参考

---

## 1. 协议概述

VirtIO 是 OASIS（Organization for the Advancement of Structured Information Standards）维护的**半虚拟化（Para-virtualization）I/O 框架**标准。其核心思想是：Guest OS 运行修改过的前端驱动（Guest Driver），通过共享内存中的环形缓冲区（Virtqueue）与 Host 上的后端实现（Host Backend）通信，避免传统设备模拟的高开销。

**关键特性**：
- **半虚拟化**：Guest 明知自己在虚拟化环境中，驱动不做硬件模拟，直接面向高效协议接口
- **标准化**：OASIS VirtIO 规范 v1.0/v1.1/v1.2/v1.3，跨 hypervisor（QEMU/KVM, Hyper-V, Firecracker 等）
- **设备类型丰富**：Net, Block, Console, SCSI, 9P, GPU, Input, vsock 等
- **高性能**：零拷贝 / 批量通知 / 中断抑制，接近物理 I/O 性能

**架构角色**：

| 角色 | 说明 |
|------|------|
| **Guest Driver** | 运行在 Guest OS 内核态，前端驱动，管理 Virtqueue、Feature 协商、收发请求 |
| **Virtqueue** | 共享内存中的数据结构（Descriptor Table + Available Ring + Used Ring），Guest/Host 通过它传递 I/O 请求 |
| **Host Backend** | 运行在 Host 上的后端实现（QEMU virtio 设备模拟、vhost 内核模块、vhost-user 用户态进程、VDPA 硬件） |
| **Physical Device** | 真实的物理 I/O 设备（NIC、NVMe 等），由 Host Backend 驱动 |

---

## 2. VirtIO 核心架构

```
+-------------------+          +-------------------+          +-------------------+
|    Guest OS       |          |   Host Software   |          | Physical Device   |
|                   |          |                   |          |                   |
| +---------------+ |          | +---------------+ |          | +---------------+ |
| | Guest Driver  | |          | | Host Backend  | |          | | NIC / NVMe /  | |
| | (前端驱动)    | |          | | (后端实现)    | |          | | Storage       | |
| +-------+-------+ |          | +-------+-------+ |          | +-------+-------+ |
|         |          |          |         |          |          |         |         |
| +-------v-------+ |          | +-------v-------+ |          |         |         |
| |  Virtqueue    | |          | |  Virtqueue    | |          |         |         |
| |  Manager      | |          | |  Worker       | |          |         |         |
| +-------+-------+ |          | +-------+-------+ |          |         |         |
|         |          |          |         |          |          |         |         |
+---------+----------+          +---------+----------+          +---------+---------+
          |                               |                               |
          |    +-----------------------+  |                               |
          +--->|   Shared Memory       |<-+                               |
               |                       |                                  |
               | +-------------------+ |                                  |
               | | Descriptor Table  | |                                  |
               | | Available Ring    | |   Notification (Kick / IRQ)      |
               | | Used Ring         | |                                  |
               | +-------------------+ |                                  |
               +-----------------------+                                  |
                    (Guest Memory)                                         |
                                                                           |
                              +--------------------------------------------+
                              |
                    +---------v---------+
                    |  DMA Engine / Bus |
                    |  (PCIe / Platform)|
                    +-------------------+

数据路径：
  Guest Driver --写 Desc+Avail--> Shared Memory --通知--> Host Backend
  Host Backend --处理 I/O--> Physical Device
  Host Backend --写 Used Ring--> Shared Memory --中断--> Guest Driver
```

**关键点**：Guest 与 Host 之间的数据交换完全通过共享内存中的 Virtqueue 完成。通知（Notification）和中断（Interrupt）仅用于事件触发，不携带数据。

---

## 3. Virtqueue 详解

### 3.1 Split Virtqueue（v1.0 推荐）

Split Virtqueue 将三个数据结构在内存中**分离存放**（Split apart），这是 v1.0 规范定义的经典实现。

#### 3.1.1 Descriptor Table（描述符表）

每个 Descriptor 16 字节，描述一个 I/O buffer：

```
Descriptor (16 bytes, little-endian):
+--------+--------+--------+--------+--------+--------+--------+--------+
| addr (64-bit, Guest Physical Address of buffer)                        |
+--------+--------+--------+--------+--------+--------+--------+--------+
| len  (32-bit, length of buffer in bytes)                               |
+--------+--------+--------+
| flags(16-bit)             | next (16-bit, chain index)                 |
+---------------------------+--------------------------------------------+

flags bit 定义：
  [0] VIRTQ_DESC_F_NEXT  : 1 = next 字段有效，形成链式描述符
  [1] VIRTQ_DESC_F_WRITE : 1 = 设备写入（device-writable），即 Host -> Guest 方向
                            0 = 设备只读（device-readable），即 Guest -> Host 方向
  [2] VIRTQ_DESC_F_INDIRECT : 1 = 此描述符指向一个间接描述符表
```

**描述符链示例**（一个 I/O 请求由多个 buffer 组成）：

```
Descriptor Table Index:
  [0] addr=A, len=12, flags=NEXT,          next=1   --> Header
  [1] addr=B, len=1514, flags=NEXT,        next=2   --> Packet Data
  [2] addr=C, len=4, flags=WRITE|NEXT,     next=3   --> Status (Host 写回)
  [3] (unused)

Guest 设置 Available Ring idx=0，指向 Descriptor Chain Head = 0
Host 完成后，写 Used Ring: id=0, len=1530
```

#### 3.1.2 Available Ring（可用环，Guest -> Host）

```
Available Ring 内存布局：
+-------------------+  <-- 基地址（由 Queue Notify / QueueReady 寄存器配置）
| flags (16-bit)    |  bit 0: VIRTQ_AVAIL_F_NO_INTERRUPT (Guest 告知 Host 不要发中断)
+-------------------+
| idx  (16-bit)     |  Guest 下一次要写入的 ring slot 位置（单调递增，wrap around）
+-------------------+
| ring[0] (16-bit)  |  描述符链头索引
| ring[1] (16-bit)  |
| ...               |
| ring[N-1]         |  N = Queue Size
+-------------------+
| used_event(16-bit)|  v1.0: 下一个 used 事件的 idx（用于中断抑制）
+-------------------+
```

Guest 的写入流程：
1. 填充 Descriptor Table（描述 I/O buffer）
2. 将描述符链头索引写入 `ring[idx % queue_size]`
3. `idx++`（memory barrier 后）
4. 写 Queue Notify 寄存器通知 Host

#### 3.1.3 Used Ring（已使用环，Host -> Guest）

```
Used Ring 内存布局：
+-------------------+
| flags (16-bit)    |  bit 0: VIRTQ_USED_F_NO_NOTIFY (Host 告知 Guest 不要发 notify)
+-------------------+
| idx  (16-bit)     |  Host 下一次要写入的 ring slot 位置
+-------------------+
| ring[0].id  (16-bit) |  已处理的描述符链头索引
| ring[0].len (32-bit) |  设备写入的总字节数（仅 WRITE 方向有意义）
| ring[1].id  (16-bit) |
| ring[1].len (32-bit) |
| ...                  |
+-------------------+
| avail_event(16-bit)|  v1.0: 下一个 avail 事件的 idx（用于 notify 抑制）
+-------------------+
```

Host 的完成流程：
1. 处理 Available Ring 中的 descriptor chain
2. DMA 读写数据
3. 将 `{id, len}` 写入 Used Ring `ring[idx % queue_size]`
4. `idx++`（memory barrier 后）
5. 发中断通知 Guest

#### 3.1.4 Split vs Packed Virtqueue 对比

| 特性 | Split Virtqueue (v1.0) | Packed Virtqueue (v1.1) | Packed Virtqueue v2 (v1.3) |
|------|------------------------|-------------------------|---------------------------|
| **内存布局** | 3 个独立数组（Desc Table + Avail Ring + Used Ring） | 单个连续数组（Descriptor Ring） | 单个连续数组，支持动态大小变更 |
| **Descriptor 大小** | 16 bytes | 16 bytes（扩展 flags 字段） | 16 bytes（新增 event_suppression 结构） |
| **Cache 友好性** | 较差（三个结构分散在不同 cache line） | 好（单数组，顺序访问） | 好（同 v1.1，额外优化 event suppression） |
| **描述符回收** | Host 在 Used Ring 中返回，Guest 需遍历 | 内联 flags 位（Driver/Device Owns）标识所有权 | 同 v1.1 |
| **环回绕检测** | 通过 idx 回绕 | 通过 Wrap Counter 标志位（1 bit） | 同 v1.1 |
| **间接描述符** | 支持 | 支持（嵌套 Packed Ring） | 支持 |
| **通知优化** | 需单独读写 flags/event 字段 | 内联于 descriptor 中，减少 cache miss | 新增独立 event suppression 结构，更灵活 |
| **动态队列大小** | 不支持 | 不支持 | 支持（v1.3 新增） |
| **适用场景** | 兼容性好，实现简单 | 高性能场景（virtio-net 高吞吐） | 最高性能 + 灵活通知管理 |
| **规范引入** | v1.0 | v1.1（2019） | v1.3（2022） |

**Packed Virtqueue Descriptor 格式**（16 字节）：

```
+--------+--------+--------+--------+--------+--------+--------+--------+
| addr (64-bit)                                                            |
+--------+--------+--------+--------+--------+--------+--------+--------+
| len  (32-bit)                                                            |
+--------+--------+
| id   (16-bit)   |   // 内部用，用于 completed buffer 标识
+--------+--------+
| flags(16-bit)   |   // bit 0: F_NEXT, bit 1: F_WRITE, bit 2: F_INDIRECT
+-----------------+   // bit 7: AVAIL (Driver owns)  bit 15: USED (Device owns)
                       // Wrap Counter 嵌入 AVAIL/USED 位的极性中
```

Packed Ring 的所有权切换：
- Driver 写入后：置 AVAIL = Wrap Counter 极性，USED = !Wrap Counter 极性
- Device 完成后：置 USED = Wrap Counter 极性
- 当所有 descriptor 的 USED == current Wrap Counter 时，环回绕，Toggle Wrap Counter

---

## 4. VirtIO 设备类型表

| Device ID | 设备类型 | 典型用途 | 关键 Virtqueue |
|-----------|----------|----------|---------------|
| 1 | **virtio-net** | 虚拟网卡 | RX Queue, TX Queue, Control Queue |
| 2 | **virtio-blk** | 虚拟块设备 | Request Queue |
| 3 | **virtio-console** | 虚拟控制台 | Port RX/TX (per port) |
| 4 | **virtio-scsi** | 虚拟 SCSI 控制器 | Request Queue, Event Queue, Control Queue |
| 5 | **virtio-entropy** | 随机数设备 | Request Queue |
| 6 | **virtio-9p** | 9P 文件系统共享（Plan 9） | Request Queue |
| 7 | **virtio-mac80211 wlan** | 虚拟无线网卡 | TX/RX |
| 8 | **virtio-rproc-serial** | 远程处理器串口 | TX/RX |
| 9 | **virtio-caif** | CAIF 通信 | TX/RX |
| 10 | **virtio-memory-balloon** | 内存气球 | Stats Queue |
| 11 | **virtio-rpmsg** | 远程消息 | TX/RX |
| 12 | **virtio-scsi** (v2) | SCSI (更新) | 同 virtio-scsi |
| 13 | **virtio-vsock** | VM Socket 通信 | RX/TX/Event |
| 14 | **virtio-crypto** | 加密加速 | Data Queue, Control Queue |
| 15 | **virtio-sound** | 音频设备 | TX/RX/Control |
| 16 | **virtio-gpu** | GPU 设备 | Control Queue, Cursor Queue |
| 17 | **virtio-fs** | 文件系统共享（FUSE） | Request Queue |
| 18 | **virtio-input** | 输入设备（键盘/鼠标） | Event Queue |
| 19 | **virtio-pmem** | 持久化内存 | Flush Queue |
| 20 | **virtio-rpmb** | RPMB 存储 | Request Queue |
| 21 | **virtio-iommu** | IOMMU 设备 | Request Queue |
| 22 | **virtio-watchdog** | 看门狗 | Request Queue |
| 23 | **virtio-can** | CAN 总线 | TX/RX |
| 24 | **virtio-dmabuf** | DMA Buffer 共享 | Control Queue |
| 25 | **virtio-para** | 参数配置 | Request Queue |
| 26 | **virtio-async-tx** | 异步传输 | Request Queue |
| 27 | **virtio-nsm** | 安全模块 | Request Queue |
| 28 | **virtio-bridge** | 网桥设备 | TX/RX |
| 29 | **virtio-mei** | 管理引擎接口 | Request Queue |
| 30 | **virtio-csi** | CSI 摄像头 | Request Queue |
| 31 | **virtio-pmem-v2** | 持久化内存 v2 | Flush Queue |
| 32 | **virtio-ml** | 机器学习加速 | Request Queue |
| 33 | **virtio-vdpa** | VDPA 统一设备 | 由具体设备决定 |
| 34 | **virtio-audio-codec** | 音频编解码 | Request Queue |
| 35 | **virtio-ibft** | iBFT 网络引导 | Request Queue |
| 36 | **virtio-mmio-platform** | MMIO 平台设备 | Request Queue |
| 37 | **virtio-cxl-bridge** | CXL 桥接 | Request Queue |
| 38 | **virtio-hwrng** | 硬件随机数 | Request Queue |
| 39 | **virtio-mem** | 动态内存热插拔（v1.3） | Request Queue |
| 40 | **virtio-fs** (v2) | 文件系统共享增强（v1.3） | Request Queue |
| 41 | **virtio-pvclock** | 半虚拟化时钟（v1.3） | Request Queue |
| 42 | **virtio-camera** | 摄像头设备（v1.3） | Request Queue |

> 完整列表参见 OASIS VirtIO 规范 Appendix: Device Types。

---

## 5. 设备初始化流程

### 5.1 状态机

```
                    +------------------+
                    |                  |
                    v                  |
              +-----------+            |
              |  RESET    |<-----------+------+
              +-----+-----+                  |
                    |                        |
          (设备发现) |                        |
                    v                        |
              +-----------+                  |
              |  ACK_DEV   | Device 向 Guest 确认存在
              +-----+-----+                  |
                    |                        |
                    v                        |
              +-----------+                  |
              |  ACK_DRV   | Guest 确认有匹配驱动
              +-----+-----+                  |
                    |                        |
                    v                        |
              +-----------+                  |
              | ACK_FEAT   | Feature 协商完成
              +-----+-----+                  |
                    |                        |
                    v                        |
              +-----------+                  |
              |  DRIVER_OK | 驱动就绪，可收发数据
              +-----+-----+                  |
                    |                        |
                    v                        |
              +-----------+                  |
              |  RUNNING   | 正常运行 <--------+
              +-----+-----+                  |
                    |                        |
            (致命错误)  |                    |
                    v                        |
              +-----------+                  |
              |  FAILED    |----------------+
              +-----------+
```

### 5.2 设备状态寄存器（Device Status）

写入顺序必须严格：

| 步骤 | Status Bit | 值 | 操作者 | 说明 |
|------|------------|-----|--------|------|
| 1 | `ACKNOWLEDGE` | 0x01 | Guest | Guest 已发现设备 |
| 2 | `DRIVER` | 0x02 | Guest | Guest 已加载驱动 |
| 3 | `DRIVER_OK` | 0x04 | Guest | 驱动就绪 |
| 4 | `FEATURES_OK` | 0x08 | Guest | Feature 协商成功 |
| 5 | `DEVICE_NEEDS_RESET` | 0x40 | Device | 设备需要复位（致命错误） |
| 6 | `FAILED` | 0x80 | Guest | 初始化失败 |

**完整初始化序列**：

```
1. Guest: status = 0 (RESET)
2. Guest: status |= ACKNOWLEDGE (0x01)
3. Guest: 读取 device_features (32/64-bit)
4. Guest: 写入 driver_features 选择支持的 feature
5. Guest: status |= DRIVER (0x02)
6. Guest: status |= FEATURES_OK (0x08)
7. Guest: 检查 status 是否包含 FEATURES_OK
         若不含 -> 协商失败, status |= FAILED
8. Guest: 配置 Virtqueue（Queue Size, Queue Address, Queue Ready）
9. Guest: status |= DRIVER_OK (0x04)
10. Device: 正常运行，处理 Virtqueue 请求
```

---

## 6. Feature Negotiation

Feature Negotiation 是 VirtIO 的核心扩展机制。每个设备定义一组 Feature Bits（64-bit 位图），通过读写配置寄存器完成位级协商。

### 6.1 协商流程

```
Device Feature Bits (设备支持的特性)
  |-- Device Feature Bits Select 0: [31:0]
  |-- Device Feature Bits Select 1: [63:32]

Driver Feature Bits (Guest 选择启用的特性)
  |-- Driver Feature Bits Select 0: [31:0]
  |-- Driver Feature Bits Select 1: [63:32]

协商规则：
  1. Guest 读取 Device Feature Bits
  2. Guest 与自身能力取 AND：driver_features &= device_features
  3. Guest 写入 Driver Feature Bits
  4. 若 Device 不接受 -> 置 DEVICE_NEEDS_RESET
  5. 最终双方启用的 feature = 交集
```

### 6.2 通用 Feature Bits（所有设备共享）

| Bit | 名称 | 说明 |
|-----|------|------|
| 0 | `VIRTIO_F_NOTIFY_ON_EMPTY` | 队列空时也通知 |
| 1 | `VIRTIO_F_ANY_LAYOUT` | 任意布局，不要求固定结构 |
| 16 | `VIRTIO_F_INDIRECT_DESC` | 支持间接描述符 |
| 17 | `VIRTIO_F_EVENT_IDX` | 支持中断/通知抑制（Used/Avail Event Index） |
| 28 | `VIRTIO_F_VERSION_1` | 遵循 v1.0 规范（现代设备必设） |
| 29 | `VIRTIO_F_ACCESS_PLATFORM` | 平台 DMA 重映射（IOMMU） |
| 32 | `VIRTIO_F_RING_PACKED` | 支持 Packed Virtqueue（v1.1） |
| 33 | `VIRTIO_F_IN_ORDER` | 设备按顺序处理描述符 |
| 34 | `VIRTIO_F_ORDER_PLATFORM` | 平台内存排序保证 |
| 35 | `VIRTIO_F_SR_IOV` | 支持 SR-IOV 虚拟功能 |
| 36 | `VIRTIO_F_NOTIFICATION_DATA` | 通知携带数据（Queue Notify 包含 desc index） |
| 37 | `VIRTIO_F_NOTIF_CONFIG_DATA` | 通知携带配置数据（v1.3） |
| 38 | `VIRTIO_F_RING_RESET` | 支持 Virtqueue 重置而不重置整个设备（v1.3） |
| 39 | `VIRTIO_F_ADMIN_VQ` | 支持 Admin Virtqueue（v1.3），用于设备管理操作 |
| 40 | `VIRTIO_F_PREFERRED_ENDIAN` | 支持首选字节序（v1.3，用于大端 Guest） |

---

## 7. VirtIO-net 设备详解

### 7.1 配置空间

VirtIO-net 配置空间通过 PCI BAR 或 MMIO 映射：

```
偏移   | 字段                  | 大小   | 说明
-------+-----------------------+--------+----------------------------------
0x00   | mac[6]                | 6 byte | MAC 地址（只读或可配）
0x06   | status                | 2 byte | 链路状态（VIRTIO_NET_S_*）
0x08   | max_virtqueue_pairs   | 2 byte | 最大 Virtqueue 对数（v1.1+）
0x0A   | mtu                   | 2 byte | MTU（VIRTIO_NET_F_MTU）
0x0C   | speed                 | 4 byte | 链路速率（VIRTIO_NET_F_SPEED_DUPLEX）
0x10   | duplex                | 1 byte | 全/半双工
```

**status 字段位定义**：

| Bit | 名称 | 说明 |
|-----|------|------|
| 0 | `VIRTIO_NET_S_LINK_UP` | 链路已建立 |
| 1 | `VIRTIO_NET_S_ANNOUNCE` | 链路状态变更公告 |

### 7.2 Virtqueue 布局

| Queue Index | 名称 | 方向 | 用途 |
|-------------|------|------|------|
| 0 | RX Queue 0 | Host -> Guest | 接收数据包 |
| 1 | TX Queue 0 | Guest -> Host | 发送数据包 |
| 2 | RX Queue 1 | Host -> Guest | 多队列接收（需 VIRTIO_NET_F_MQ） |
| 3 | TX Queue 1 | Guest -> Host | 多队列发送 |
| ... | ... | ... | ... |
| 2N | Control Queue | 双向 | 设备控制命令（需 VIRTIO_NET_F_CTRL_VQ） |

### 7.3 包格式

Guest 与 Host 之间的每个网络包以 `virtio_net_hdr` 头部开头：

```
virtio_net_hdr (12 bytes, v1.0; 20 bytes 含 hash 字段):
+--------+
| flags  |  1 byte
+--------+
| gso_type | 1 byte
+--------+
| hdr_len  | 2 bytes  -- v1.0 固定 12
+--------+
| gso_size  | 2 bytes -- 最大分段大小
+--------+
| csum_start | 2 bytes -- 校验起始偏移
+--------+
| csum_offset | 2 bytes -- 校验写入偏移
+--------+
| num_buffers | 2 bytes -- VIRTIO_NET_F_MRG_RXBUF: 合并的 buffer 数
+--------+
```

**flags 字段**：

| Bit | 名称 | 说明 |
|-----|------|------|
| 0 | `VIRTIO_NET_HDR_F_NEEDS_CSUM` | Guest 请求 Host 计算校验和 |
| 1 | `VIRTIO_NET_HDR_F_DATA_VALID` | Host 已验证校验和 |
| 2 | `VIRTIO_NET_HDR_F_RSC_INFO` | RSC（接收端合并）信息有效 |

**gso_type 字段**：

| 值 | 名称 | 说明 |
|----|------|------|
| 0  | `VIRTIO_NET_HDR_GSO_NONE` | 无 GSO |
| 1  | `VIRTIO_NET_HDR_GSO_TCPV4` | TCPv4 分段 |
| 2  | `VIRTIO_NET_HDR_GSO_UDP` | UDP 分段 |
| 3  | `VIRTIO_NET_HDR_GSO_TCPV6` | TCPv6 分段 |
| 4  | `VIRTIO_NET_HDR_GSO_ECN` | ECN 标记（与其他值 OR 使用） |

### 7.4 VIRTIO_NET_F_* 特性列表

| Feature Bit | 名称 | 说明 |
|-------------|------|------|
| 0 | `VIRTIO_NET_F_CSUM` | Host 可计算校验和 |
| 1 | `VIRTIO_NET_F_GUEST_CSUM` | Guest 可计算校验和 |
| 2 | `VIRTIO_NET_F_CTRL_GUEST_OFFLOADS` | 控制 Guest offload |
| 3 | `VIRTIO_NET_F_MTU` | 配置空间含 MTU 字段 |
| 5 | `VIRTIO_NET_F_MAC` | 配置空间含 MAC 地址 |
| 7 | `VIRTIO_NET_F_GUEST_TSO4` | Guest 支持 TSO IPv4 |
| 8 | `VIRTIO_NET_F_GUEST_TSO6` | Guest 支持 TSO IPv6 |
| 9 | `VIRTIO_NET_F_GUEST_ECN` | Guest 支持 ECN TSO |
| 10 | `VIRTIO_NET_F_GUEST_UFO` | Guest 支持 UFO |
| 11 | `VIRTIO_NET_F_HOST_TSO4` | Host 支持 TSO IPv4 |
| 12 | `VIRTIO_NET_F_HOST_TSO6` | Host 支持 TSO IPv6 |
| 13 | `VIRTIO_NET_F_HOST_ECN` | Host 支持 ECN TSO |
| 14 | `VIRTIO_NET_F_HOST_UFO` | Host 支持 UFO |
| 15 | `VIRTIO_NET_F_MRG_RXBUF` | Host 合并多个 RX buffer |
| 16 | `VIRTIO_NET_F_STATUS` | 配置空间含 status 字段 |
| 17 | `VIRTIO_NET_F_CTRL_VQ` | 支持 Control Virtqueue |
| 18 | `VIRTIO_NET_F_CTRL_RX` | Control VQ 可过滤 RX |
| 19 | `VIRTIO_NET_F_CTRL_VLAN` | Control VQ 可管理 VLAN |
| 20 | `VIRTIO_NET_F_GUEST_ANNOUNCE` | Guest 可公告链路状态变化 |
| 21 | `VIRTIO_NET_F_MQ` | 支持多 Virtqueue 对 |
| 22 | `VIRTIO_NET_F_CTRL_MAC_ADDR` | Control VQ 可更改 MAC |
| 28 | `VIRTIO_NET_F_RSC_EXT` | RSC 扩展 |
| 36 | `VIRTIO_NET_F_HASH_REPORT` | 支持 hash 报告 |
| 56 | `VIRTIO_NET_F_VQ_NOTF_COAL` | VQ 通知合并 |
| 57 | `VIRTIO_NET_F_NOTF_COAL` | 通知合并 |
| 58 | `VIRTIO_NET_F_GUEST_USO4` | Guest USO IPv4 |
| 59 | `VIRTIO_NET_F_GUEST_USO6` | Guest USO IPv6 |
| 60 | `VIRTIO_NET_F_HOST_USO` | Host USO |
| 61 | `VIRTIO_NET_F_HASH_TUNNEL` | 隧道 hash |
| 62 | `VIRTIO_NET_F_VQ_PRE_FILL` | VQ 预填充 |

---

## 8. VirtIO-blk 设备详解

### 8.1 配置空间

```
偏移   | 字段           | 大小   | 说明
-------+----------------+--------+----------------------------------
0x00   | capacity       | 8 byte | 容量（512-byte 扇区数）
0x08   | size_max       | 4 byte | 最大请求大小
0x0C   | seg_max        | 4 byte | 最大 scatter-gather 段数
0x10   | geometry       | ...    | 磁盘几何参数（cylinders/heads/sectors）
0x18   | blk_size       | 4 byte | 块大小（默认 512）
0x1C   | topology       | ...    | 物理块对齐信息
0x28   | writeback      | 1 byte | 写回策略
0x29   | unused0        | 3 byte | 保留
0x2C   | max_discard_sectors | 4 byte | 最大 discard 扇区数
0x30   | max_discard_seg    | 4 byte | 最大 discard 段数
0x34   | discard_sector_alignment | 4 byte | discard 对齐
0x38   | max_write_zeroes_sectors | 4 byte | 最大 write zeroes 扇区数
0x3C   | max_write_zeroes_seg | 4 byte | 最大 write zeroes 段数
0x40   | write_zeros_may_unmap | 1 byte | write zeroes 可释放映射
```

### 8.2 请求格式

每个 blk 请求由 3 个 buffer 组成的 descriptor chain 描述：

```
Descriptor 0: Header (16 bytes, device-readable)
+--------+--------+
| type   (32-bit) |  请求类型
+--------+--------+
| reserved(32-bit)|
+--------+--------+
| sector (64-bit) |  起始扇区号
+--------+--------+

Descriptor 1: Data (N bytes, direction depends on type)
  device-readable for WRITE/WRITE_ZEROES
  device-writable for READ

Descriptor 2: Status (1 byte, device-writable)
+--------+
| status |  0=OK, 1=ERROR, 2=UNSUPPORTED
+--------+
```

**type 字段值**：

| 值 | 名称 | 说明 |
|----|------|------|
| 0  | `VIRTIO_BLK_T_IN` | 读（Host -> Guest） |
| 1  | `VIRTIO_BLK_T_OUT` | 写（Guest -> Host） |
| 4  | `VIRTIO_BLK_T_FLUSH` | 刷写缓存 |
| 5  | `VIRTIO_BLK_T_DISCARD` | 回收空间 |
| 11 | `VIRTIO_BLK_T_WRITE_ZEROES` | 写零 |
| 13 | `VIRTIO_BLK_T_SECURE_ERASE` | 安全擦除 |

---

## 9. Vhost（后端加速）

Vhost 是将 Host Backend 的数据面处理从 QEMU 用户态解耦出来的加速框架，目标是减少 I/O 路径上的上下文切换和内存拷贝。

### 9.1 Vhost-net（内核态）

```
+-------------------+                    +-------------------+
|    Guest OS       |                    |   Host Kernel     |
|                   |                    |                   |
| +---------------+ |                    | +---------------+ |
| | virtio-net    | |                    | | vhost-net     | |  <-- 内核模块
| | Guest Driver  | |                    | | (内核态worker) | |
| +-------+-------+ |                    | +-------+-------+ |
|         |          |                    |         |         |
| +-------v-------+ |   ioctl / eventfd  | +-------v-------+ |
| |  Virtqueue    |<-+------------------->| |  Virtqueue    | |
| |  (Guest Mem)  | |   共享内存映射      | |  (Guest Mem)  | |
| +---------------+ |                    | +---------------+ |
+-------------------+                    |         |         |
                                         | +-------v-------+ |
                                         | | TAP / veth    | |
                                         | +---------------+ |
                                         +-------------------+
```

**特点**：
- QEMU 通过 `/dev/vhost-net` 与内核模块通信（ioctl）
- 数据面由内核 vhost-net 直接处理，不经 QEMU 用户态
- TX path: Guest -> vhost-net kernel -> TAP -> Host Network Stack
- RX path: Host Network Stack -> TAP -> vhost-net kernel -> Guest
- 中断通过 eventfd 注入 Guest

### 9.2 Vhost-user（用户态）

```
+-------------------+                    +-------------------+
|    Guest OS       |                    |   Host User Space |
|                   |                    |                   |
| +---------------+ |                    | +---------------+ |
| | virtio-net    | |                    | | vhost-user    | |
| | Guest Driver  | |                    | | Backend       | |  <-- DPDK/OVS-DPDK/SPDK
| +-------+-------+ |                    | +-------+-------+ |
|         |          |                    |         |         |
| +-------v-------+ |                    | +-------v-------+ |
| |  Virtqueue    |<-+-- Unix Socket --->| |  Virtqueue    | |
| |  (Guest Mem)  | |   + mmap 共享内存   | |  (Guest Mem)  | |
| +---------------+ |                    | +---------------+ |
+-------------------+                    +-------------------+
```

**特点**：
- QEMU 通过 Unix Domain Socket 与用户态后端（DPDK vhost-user library）通信
- 控制面消息：SET_MEM_TABLE, SET_VRING_ADDR, SET_VRING_KICK, SET_VRING_CALL 等
- 数据面：后端进程 mmap Guest 内存，直接读写 Virtqueue
- 无需内核参与数据路径，延迟更低
- 典型应用：OVS-DPDK, SPDK vhost-blk

**vhost-user 协议消息**：

| 消息 | 方向 | 说明 |
|------|------|------|
| `VHOST_USER_GET_FEATURES` | Backend -> QEMU | 获取后端支持的 feature |
| `VHOST_USER_SET_FEATURES` | QEMU -> Backend | 设置协商后的 feature |
| `VHOST_USER_SET_MEM_TABLE` | QEMU -> Backend | 通知 Guest 内存布局 |
| `VHOST_USER_SET_VRING_NUM` | QEMU -> Backend | 设置 VQ 队列大小 |
| `VHOST_USER_SET_VRING_ADDR` | QEMU -> Backend | 设置 VQ 各部分地址 |
| `VHOST_USER_SET_VRING_BASE` | QEMU -> Backend | 设置 VQ 当前 idx |
| `VHOST_USER_SET_VRING_KICK` | QEMU -> Backend | 设置 kick fd（Guest 通知后端） |
| `VHOST_USER_SET_VRING_CALL` | QEMU -> Backend | 设置 call fd（后端通知 Guest） |
| `VHOST_USER_SET_VRING_ENABLE` | QEMU -> Backend | 使能/禁用 VQ |
| `VHOST_USER_GET_VRING_BASE` | Backend -> QEMU | 获取 VQ 当前 idx（迁移时） |
| `VHOST_USER_SET_STATUS` | QEMU -> Backend | 设置设备状态 |

### 9.3 VDPA（Virtio Data Path Acceleration）

VDPA 是 vhost 的终极形态：**硬件直接实现 Virtqueue 协议**，同时保留 VirtIO 驱动生态。

```
+-------------------+                    +-------------------+
|    Guest OS       |                    |   Host            |
|                   |                    |                   |
| +---------------+ |                    | +---------------+ |
| | virtio-net    | |                    | | vdpa bus      | |
| | Guest Driver  | |                    | | driver        | |
| +-------+-------+ |                    | +-------+-------+ |
|         |          |                    |         |         |
| +-------v-------+ |                    | +-------v-------+ |
| |  Virtqueue    |<-+--- PCIe DMA ----->| |  Virtqueue    | |
| |  (Guest Mem)  | |                    | |  (Guest Mem)  | |
| +---------------+ |                    | +---------------+ |
+-------------------+                    +-------------------+
                                                  |
                                          +-------v-------+    +------------------+
                                          |  VDPA Device   |--->| Physical NIC     |
                                          |  (SmartNIC/    |    | (e.g. Mellanox   |
                                          |   FPGA)        |    |  ConnectX-6)     |
                                          +---------------+    +------------------+
```

**特点**：
- 硬件直接实现 Virtqueue 数据面（Descriptor 解析 + Avail/Used Ring 管理）
- Guest 装载标准 virtio-net 驱动，无需修改
- Host 通过 vdpa bus 驱动与硬件交互，配置面走 vhost-user 协议
- 支持 Live Migration：硬件状态可导出/导入
- 性能接近 SR-IOV VF，灵活性接近 VirtIO（可热迁移）

**VDPA 架构层次**：

| 层 | 说明 |
|----|------|
| **Guest Driver** | 标准 virtio-net/blk 驱动 |
| **vDPA Framework** | Linux 内核 vdpa bus，提供统一的 vhost-user 接口 |
| **vDPA Device Driver** | SmartNIC / FPGA 上的 vdpa 设备驱动（如 mlx5_vdpa） |
| **vDPA Hardware** | 硬件实现：virtqueue DMA 引擎 + 特性协商寄存器 + 中断注入 |

---

## 10. 与 SR-IOV 的对比和互补

| 特性 | VirtIO (纯软件) | SR-IOV (硬件 VF) | VDPA |
|------|-----------------|-------------------|------|
| **性能** | 中等（vhost-user 后可接近线速） | 极高（硬件 VF 直通） | 极高（硬件 Virtqueue） |
| **Guest 驱动** | virtio-net（上游内核） | VF 驱动（需 vendor 驱动） | virtio-net（上游内核） |
| **Live Migration** | 天然支持 | 困难（硬件状态） | 支持（状态可导出） |
| **热迁移复杂度** | 低 | 高（需 fallback 到 virtio） | 中（硬件需支持状态冻结） |
| **硬件依赖** | 无 | 需要 SR-IOV capable NIC | 需要 VDPA capable NIC |
| **驱动生态** | 广泛（所有 virtio 驱动） | 厂商特定 | 广泛（复用 virtio 驱动） |
| **多租户隔离** | 依赖 hypervisor | 硬件级 VF 隔离 | 硬件级隔离（可配） |
| **配置灵活性** | 高（纯软件） | 低（VF 数量固定） | 高（硬件资源可配） |

**VDPA = SR-IOV 性能 + VirtIO 灵活性**

VDPA 解决的核心矛盾：
- SR-IOV VF 性能好，但 Live Migration 支持差，且需要 vendor 特定驱动
- VirtIO 灵活性好，Live Migration 天然支持，但纯软件性能受限
- VDPA：硬件实现 virtqueue 数据面（SR-IOV 级性能），Guest 用标准 virtio 驱动，支持 Live Migration

**典型部署组合**：

```
场景 1: 高性能 + 需要迁移
  -> VDPA（数据面硬件加速，控制面软件管理，迁移时冻结硬件状态）

场景 2: 高性能 + 不需要迁移（裸金属/稳态 VM）
  -> SR-IOV VF 直通

场景 3: 无特殊硬件，纯虚拟化
  -> vhost-user (OVS-DPDK / SPDK)
```

---

## 11. VirtIO 1.3 新增特性

### 11.1 Admin Virtqueue

v1.3 引入 Admin Virtqueue，用于设备管理操作，将管理面与数据面分离：

```
传统模式：
  Guest 驱动 --> 配置空间寄存器读写 --> 设备
  管理操作与数据通路共用配置空间，扩展性差

v1.3 Admin VQ 模式：
  Guest 驱动 --> Admin Virtqueue --> 设备
  管理命令通过 VQ 传递，支持异步、批量管理操作
```

**Admin VQ 特性**：
- 专用 Virtqueue（feature bit 39: `VIRTIO_F_ADMIN_VQ`）
- 管理命令以 descriptor chain 形式提交
- 支持：设备信息查询、VQ 配置管理、统计信息采集、固件更新等
- 管理命令与数据命令并行处理，不阻塞数据通路

**RTL 设计影响**：
- 需要独立的 Admin VQ 处理引擎，与数据 VQ 引擎并行
- Admin 命令解析器需支持可变长度命令格式
- Admin VQ 也需要独立的中断向量

### 11.2 Virtqueue Reset

v1.3 支持单个 Virtqueue 级别的软重置，无需重置整个设备：

```
传统模式：
  Guest 需要重置 VQ → 必须重置整个设备 → 重新初始化所有 VQ

v1.3 VQ Reset：
  Guest 写 queue_reset 寄存器 → 仅重置指定 VQ → 该 VQ 可重新配置
```

**VQ Reset 行为**：
- VQ 的 `last_avail_idx` 和 `last_used_idx` 清零
- VQ 的 Descriptor Table / Avail Ring / Used Ring 地址变为无效
- VQ 进入未就绪状态（queue_ready = 0）
- 不影响其他 VQ 和设备全局状态

**RTL 设计影响**：
- 每个 VQ 需要独立的复位控制逻辑
- VQ Reset 时需等待该 VQ 的所有 pending DMA 完成
- VQ Reset 信号需同步到 VQ 的所有子模块（Descriptor Parser, DMA Engine, Interrupt Controller）

### 11.3 Notification Data 增强

v1.3 扩展了通知机制，支持携带更多数据：

```
v1.1 VIRTIO_F_NOTIFICATION_DATA：
  Queue Notify 寄存器写入值 = {VQ Index, Buffer Index}
  → 设备知道哪个 VQ 的哪个 buffer 被提交

v1.3 VIRTIO_F_NOTIF_CONFIG_DATA：
  通知数据可包含额外配置信息
  → 设备可在通知中获取更多上下文（如批量大小、优先级）
```

### 11.4 Packed Virtqueue Event Suppression v2

v1.3 对 Packed VQ 的中断/通知抑制机制进行了重构：

```
v1.1 模式：
  Event Suppression 内联在 Descriptor Ring 的特定位置
  需要额外的内存访问读取 event 值

v1.3 v2 模式：
  独立的 Event Suppression 结构（独立内存区域）
  结构包含：
    - 下一个要处理的 idx（用于中断抑制）
    - 下一个要发送的通知 idx（用于通知抑制）
    - flags（控制抑制行为）
```

**优势**：
- Event Suppression 与 Descriptor Ring 分离，减少 cache 污染
- 支持更灵活的批量中断/通知策略
- 适用于高频 I/O 场景（NVMe、RDMA）

### 11.5 动态队列大小（Dynamic Queue Size）

v1.3 支持运行时变更 Virtqueue 大小：

```
传统模式：
  初始化时通过 queue_size 配置 VQ 大小，运行时不可变
  VQ 大小由设备能力和 Guest 选择共同决定

v1.3 动态模式：
  Guest 可在运行时通过 Admin VQ 请求变更 VQ 大小
  设备允许 → 冻结 VQ → 重新配置 → 恢复运行
```

**应用场景**：
- VM 热迁移后根据目标 Host 能力调整 VQ 大小
- 负载变化时动态调整队列深度以优化延迟/吞吐

### 11.6 大端支持（Preferred Endian）

v1.3 引入 `VIRTIO_F_PREFERRED_ENDIAN`，支持大端 Guest：

```
v1.0~1.2：
  VirtIO 规范要求 little-endian
  大端 Guest（如 PowerPC、s390）需软件做字节序转换

v1.3：
  设备可通过 feature bit 声明支持大端
  Guest 可协商首选字节序，避免软件转换开销
```

### 11.7 新增设备类型

| 设备 ID | 设备类型 | 说明 |
|---------|----------|------|
| 39 | **virtio-mem** | 动态内存热插拔，支持细粒度（如 4MB 块）的内存增减 |
| 40 | **virtio-fs v2** | 文件系统共享增强版，改进 DAX 模式和缓存一致性 |
| 41 | **virtio-pvclock** | 半虚拟化时钟设备，提供高精度时间同步 |
| 42 | **virtio-camera** | 摄像头设备，支持视频流采集 |

### 11.8 VIRTIO_NET_F_* 新增特性

| Feature Bit | 名称 | 说明 |
|-------------|------|------|
| 63 | `VIRTIO_NET_F_VIRTIO_NET_HDR_VERSION` | 支持 virtio_net_hdr 版本协商（v1.3） |
| 64 | `VIRTIO_NET_F_RSS` | 接收端扩展（RSS），支持 Toeplitz hash |
| 65 | `VIRTIO_NET_F_HASH_REPORT` | hash 报告增强（v1.3 合并到通用位） |
| 66 | `VIRTIO_NET_F_STANDBY` | 备用网卡模式（主备切换） |

---

## 12. 设计注意事项（VDPA / VirtIO 硬件实现）

面向 IC 架构师，以下是设计 VDPA 硬件加速引擎或 VirtIO 协议硬件实现时的关键考量。

### 12.1 Virtqueue DMA 引擎

**核心职责**：高效访问 Guest 内存中的 Descriptor Table / Available Ring / Used Ring。

**设计要点**：

| 项目 | 说明 |
|------|------|
| DMA 通道数 | 至少 2 个独立通道：一个读 Available Ring + Descriptor，一个写 Used Ring + Data |
| 缓存策略 | Descriptor Table 和 Available Ring 适合预取缓存（prefetch），Used Ring 为 write-back |
| 地址翻译 | 支持 IOMMU / ATS（Address Translation Service），feature bit VIRTIO_F_ACCESS_PLATFORM |
| 内存屏障 | 必须实现 Load-Acquire / Store-Release 语义，保证跨核可见性（Descriptor/Avail/Used 的读写顺序） |
| Scatter-Gather | Descriptor Chain 本身就是 SG 列表，DMA 引擎需支持 chain 遍历 |
| Ring Wrap | Split VQ 用 idx 回绕检测，Packed VQ 用 Wrap Counter 标志位 |
| VQ Reset (v1.3) | 支持单 VQ 级别软重置，DMA 引擎需支持 VQ Reset 时的 pending 请求安全清理 |

### 12.2 Descriptor 解析

```
硬件处理 Descriptor Chain 流程：
1. 从 Available Ring 读取 desc_head_idx
2. 检查 flags.F_NEXT，遍历链直到 !F_NEXT
3. 对每个 descriptor：
   a. 读取 addr/len/flags
   b. 若 F_INDIRECT -> 读取间接描述符表，递归解析
   c. 根据 F_WRITE 判断数据方向（Device-readable: DMA read; Device-writable: DMA write）
4. 对于 virtio-net:
   a. 第一个 descriptor 通常是 virtio_net_hdr（12/20 bytes）
   b. 后续 descriptor 是 packet payload
   c. 最后一个 descriptor 是 Status（Device 写回）
5. 完成后，将 {id, len} 写入 Used Ring
```

**关键约束**：
- descriptor addr 必须对齐（至少 1-byte 对齐，推荐 4/8-byte 对齐以优化 DMA burst）
- 单个 descriptor 长度不能超过 2^32-1
- 链长度受 Queue Size 限制（典型 256/512/1024/32768）
- 间接描述符表最大大小由 `VIRTIO_F_INDIRECT_DESC` 规范限制

### 12.3 Available/Used Ring 更新

**Available Ring（Guest -> Device）读取**：
```
1. 读取 avail.flags -> 检查 VIRTQ_AVAIL_F_NO_INTERRUPT（可选，用于优化）
2. 读取 avail.idx -> 新的 idx 值
3. 比较本地 last_avail_idx，计算新增条目数
4. 逐条读取 avail.ring[last_avail_idx % size]
5. 更新 last_avail_idx
```

**Used Ring（Device -> Guest）写入**：
```
1. 将 {descriptor_head_id, total_bytes_written} 写入 used.ring[last_used_idx % size]
2. memory barrier (StoreRelease)
3. last_used_idx++
4. 写入 used.idx = last_used_idx
5. 若需发中断，检查 used.flags & VIRTQ_USED_F_NO_NOTIFY
6. 若需中断抑制 (VIRTIO_F_EVENT_IDX): 检查 avail_event，仅当 last_used_idx >= avail_event 时发中断
```

### 12.4 中断注入

| 方式 | 说明 | 适用 |
|------|------|------|
| **MSI-X** | PCIe MSI-X 中断，每个 VQ 独立向号 | VDPA / PCIe 设备 |
| **eventfd** | vhost-user 模式，写 eventfd 触发 QEMU/KVM 注入中断 | vhost-user |
| **中断抑制** | VIRTIO_F_EVENT_IDX: 仅当满足 event 条件时才发中断，减少中断频率 | 高性能场景 |

**中断抑制逻辑**：
```
// Used Ring 中断抑制 (Guest 控制)
if (VIRTIO_F_EVENT_IDX enabled) {
    if (last_used_idx >= avail_event) {
        inject_interrupt();
    }
} else {
    if (!(used.flags & VIRTQ_USED_F_NO_NOTIFY)) {
        inject_interrupt();
    }
}
```

### 12.5 Feature 协商寄存器

硬件需实现 Feature 协商寄存器组：

```
寄存器布局（PCI Common Config 或 MMIO）：
+---------------------------+
| device_feature (32-bit)   |  只读，Select 0 对应 bit[31:0]
+---------------------------+
| device_feature_sel (32-bit)| 只写，选择读取 device_feature 的哪 32-bit
+---------------------------+
| driver_feature (32-bit)   |  Guest 写入协商后的 feature
+---------------------------+
| driver_feature_sel (32-bit)| 选择写入 driver_feature 的哪 32-bit
+---------------------------+
| queue_select (16-bit)     |  选择当前操作的 Virtqueue 索引
+---------------------------+
| queue_size (16-bit)       |  VQ 大小（可配）
+---------------------------+
| queue_ready (16-bit)      |  VQ 就绪标志
+---------------------------+
| queue_desc (64-bit)       |  Descriptor Table GPA
+---------------------------+
| queue_driver (64-bit)     |  Available Ring GPA
+---------------------------+
| queue_device (64-bit)     |  Used Ring GPA
+---------------------------+
| queue_notify (32-bit)     |  Guest 写入通知设备（含 Queue Index 或 event data）
+---------------------------+
| queue_msix_vector (16-bit)|  MSI-X 向量号
+---------------------------+
| device_status (8-bit)     |  设备状态（见 §5 初始化流程）
+---------------------------+
| queue_reset (16-bit)      |  v1.3: VQ 软重置，写 1 触发 VQ Reset（需 VIRTIO_F_RING_RESET）
+---------------------------+
```

**硬件实现要点**：
- `queue_select` 切换时，所有 queue 相关寄存器切换上下文
- `device_status` 写入后，硬件状态机按 §5 流程迁移
- Guest 写 `queue_notify` 时触发硬件开始处理对应 VQ
- `queue_notify` 写入时若 VIRTIO_F_NOTIFICATION_DATA 使能，携带 descriptor index 信息

### 12.6 PCIe 接口

VDPA 设备通常作为 PCIe Endpoint 实现：

| 接口 | 说明 |
|------|------|
| **BAR 空间** | BAR0: MSI-X Table/PBA; BAR2: 设备配置空间（Common Config + ISR Status + Notification + Device Config） |
| **MSI-X** | 每个 VQ 一个向量，支持中断聚合 |
| **DMA** | 硬件作为 PCIe Bus Master，主动读写 Guest 内存（需 ATS/IOMMU 支持） |
| **PCIe Max Payload Size** | DMA burst 大小应匹配 MPS，最大化总线利用率 |
| **FLR** | Function Level Reset：Guest 复位设备时触发，硬件状态回 RESET |

### 12.7 Live Migration 支持

Live Migration 要求硬件在 VM 迁移时冻结状态并允许软件导出/导入：

```
迁移流程（VDPA 视角）：
1. Pre-copy 阶段：
   - 源 Host 持续脏页追踪，VDPA 硬件需记录 DMA 写入的内存页
   - 需要硬件支持脏页 bitmap 写入（或依赖 IOMMU dirty page tracking）

2. Stop-and-copy 阶段：
   - Guest 暂停
   - VDPA 硬件冻结：停止处理新的 Available Ring 条目
   - 读取硬件状态：VQ idx 值、pending interrupt、设备配置
   - 序列化状态传给目标 Host

3. Resume 阶段：
   - 目标 Host VDPA 硬件恢复：
     a. 恢复 last_avail_idx / last_used_idx
     b. 恢复设备配置空间
     c. 恢复 VQ 基地址
   - 重新使能 VQ，恢复 Guest 运行
```

**硬件需求**：
- VQ 状态可导出：`last_avail_idx`, `last_used_idx`, `used.flags`, `device_status`
- 支持 VHOST_USER_GET_VRING_BASE 消息（读取当前 VQ idx）
- 支持 VHOST_USER_SET_VRING_BASE 消息（恢复 VQ idx）
- DMA 引擎在 freeze 期间不再发起新的 DMA 请求
- 支持脏页追踪（dirty page logging）：可选的硬件 bitmap 记录 DMA 写入地址范围

### 12.8 硬件架构总结

```
VDPA Hardware Engine 模块划分（v1.3）：

+--------------------------------------------------------------+
|                       VDPA Hardware Engine                    |
|                                                              |
|  +------------------+   +------------------------+           |
|  |  PCIe Endpoint   |   |  Feature Negotiation   |           |
|  |  (BAR/MSI-X/DMA) |   |  Registers (v1.3)     |           |
|  +--------+---------+   +------------------------+           |
|           |                                                  |
|  +--------v---------+                                        |
|  |  Config Space     |  <-- device_status, queue_*           |
|  |  Management       |      queue_reset (v1.3)              |
|  +--------+---------+                                        |
|           |                                                  |
|  +--------v---------+   +------------------------+           |
|  |  VQ Fetch Engine  |-->|  Descriptor Parser     |           |
|  |  (Avail Ring      |   |  (chain traverse,      |           |
|  |   reader)         |   |   indirect desc,       |           |
|  +--------+---------+   |   addr translation)     |           |
|           |              +------------------------+           |
|           |                                                  |
|  +--------v---------+   +------------------------+           |
|  |  Data Path        |-->|  DMA Engine            |           |
|  |  (Packet/Block    |   |  (SG read/write,       |           |
|  |   processing)     |   |   IOMMU/ATS,           |           |
|  +--------+---------+   |   barrier)              |           |
|           |              +------------------------+           |
|           |                                                  |
|  +--------v---------+   +------------------------+           |
|  |  Used Ring Writer |-->|  Interrupt Controller  |           |
|  |  (idx update,     |   |  (MSI-X, event_idx,    |           |
|  |   event_idx,      |   |   event_suppression    |           |
|  |   event_suppr v2) |   |   v2, coalescing)      |           |
|  +------------------+   +------------------------+           |
|                                                              |
|  +------------------+   +------------------------+           |
|  |  Admin VQ Engine  |   |  Migration Controller  |           |
|  |  (v1.3: 管理命令  |   |  (freeze/restore,      |           |
|  |   解析+执行)      |   |   VQ Reset 支持)       |           |
|  +------------------+   +------------------------+           |
|                                                              |
|  +------------------+   +------------------------+           |
|  |  VQ Reset Ctrl    |   |  Dirty Page Tracker    |           |
|  |  (v1.3: per-VQ    |   |  (DMA write bitmap)    |           |
|  |   独立重置)       |   +------------------------+           |
|  +------------------+                                        |
+--------------------------------------------------------------+
```

---

## 附录 A：关键术语

| 术语 | 全称 | 说明 |
|------|------|------|
| VirtIO | Virtual I/O | OASIS 半虚拟化 I/O 标准 |
| Virtqueue | Virtual Queue | Guest/Host 共享的 I/O 请求队列数据结构 |
| Descriptor | 描述符 | 描述单个 I/O buffer 的 16-byte 数据结构 |
| Available Ring | 可用环 | Guest 向 Host 提交 I/O 请求的环形缓冲区 |
| Used Ring | 已使用环 | Host 向 Guest 反馈 I/O 完成的环形缓冲区 |
| Split VQ | Split Virtqueue | v1.0 规范，三个结构分离存放 |
| Packed VQ | Packed Virtqueue | v1.1 规范，单数组，cache 友好 |
| Admin VQ | Admin Virtqueue | v1.3 新增，用于设备管理操作的专用 Virtqueue |
| VQ Reset | Virtqueue Reset | v1.3 新增，单 VQ 级别软重置 |
| Event Suppression v2 | - | v1.3 新增，Packed VQ 独立的事件抑制结构 |
| VDPA | Virtio Data Path Acceleration | 硬件实现 virtqueue 数据面的框架 |
| vhost | Virtual Host | 加速 virtio 后端的框架（内核/用户态/硬件） |
| vhost-user | Virtual Host User | 用户态 vhost，通过 Unix Socket 通信 |
| SR-IOV | Single Root I/O Virtualization | PCIe 硬件虚拟化，提供 VF 直通 |
| IOMMU | I/O Memory Management Unit | I/O 地址翻译和隔离 |
| ATS | Address Translation Service | PCIe 地址翻译服务 |
| FLR | Function Level Reset | PCIe 功能级复位 |
| GSO | Generic Segmentation Offload | 通用分段卸载 |
| TSO | TCP Segmentation Offload | TCP 分段卸载 |
| USO | UDP Segmentation Offload | UDP 分段卸载 |

## 附录 B：参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | OASIS Virtio 1.0: virtio-v1.0-cs04 | Split Virtqueue 规范 |
| REF-002 | OASIS Virtio 1.1: virtio-v1.1-cs01 | Packed Virtqueue 规范 |
| REF-003 | OASIS Virtio 1.2: virtio-v1.2-cs01 | Admin VQ、VQ Reset 等 |
| REF-009 | OASIS Virtio 1.3: virtio-v1.3-cs01 | 最新规范：Admin VQ v2、Event Suppression v2、动态队列大小 |
| REF-004 | Linux kernel: drivers/virtio/ | VirtIO 驱动实现 |
| REF-005 | Linux kernel: drivers/vhost/ | vhost 内核模块 |
| REF-006 | DPDK vhost-user library | 用户态 vhost 实现 |
| REF-007 | Linux kernel: drivers/vdpa/ | VDPA 框架 |
| REF-008 | virtio-vdpa OASIS 草案 | VDPA 设备类型规范 |
