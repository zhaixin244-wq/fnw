# USB 接口协议

> **用途**：通用串行总线，主从架构高速外设接口
> **规范版本**：USB 2.0 (2000) / USB 3.0 (2008) / USB 3.1 (2013) / USB 3.2 (2017) / USB4 (2019)
> **典型应用**：存储设备、HID、摄像头、音频、Type-C 生态

---

## 1. 协议概述

USB（Universal Serial Bus）是一种主从架构的串行总线协议，采用差分信号传输，支持即插即用和热插拔。

**核心特征**：

| 特性 | 说明 |
|------|------|
| 拓扑 | 主从架构（Host - Hub - Device），星形/树形拓扑 |
| 信号 | 差分信号对（D+/D- 用于 USB 2.0，超速通道用于 3.x） |
| 时钟 | 接收端从数据流中恢复时钟（自同步编码：NRZI+位填充 / 8b10b / 128b132b） |
| 枚举 | Host 通过设备枚举发现和配置 Device |
| 供电 | VBUS 提供 5V 供电（USB 2.0 标准 500mA，BC 1.2 扩展至 2A+） |
| 热插拔 | 支持动态插入/移除检测 |

### 速率演进

| 版本 | 代号 | 信号速率 | 编码 | 理论带宽 | 引入年份 |
|------|------|----------|------|----------|----------|
| USB 1.0 | LS (Low Speed) | 1.5 Mbps | NRZI + 位填充 | ~1.5 Mbps | 1996 |
| USB 1.1 | FS (Full Speed) | 12 Mbps | NRZI + 位填充 | ~12 Mbps | 1998 |
| USB 2.0 | HS (High Speed) | 480 Mbps | NRZI + 位填充 | ~480 Mbps | 2000 |
| USB 3.0 | SS (SuperSpeed) | 5 Gbps | 8b/10b | ~500 MB/s | 2008 |
| USB 3.1 | SS+ (SuperSpeed+) | 10 Gbps | 8b/10b | ~1.21 GB/s | 2013 |
| USB 3.2 | SS+ 2x2 | 20 Gbps | 8b/10b | ~2.42 GB/s | 2017 |
| USB4 | Gen 3x2 | 40 Gbps | 128b/132b | ~4.8 GB/s | 2019 |

---

## 2. USB 速率对比表

| 速率等级 | 信令速率 | 差分信号电压 | 总线编码 | 最大电缆长度 | 全双工 |
|----------|----------|-------------|----------|-------------|--------|
| LS | 1.5 Mbps | 3.3V (D+/D-) | NRZI + 位填充 | 3m | 否 |
| FS | 12 Mbps | 3.3V (D+/D-) | NRZI + 位填充 | 5m | 否 |
| HS | 480 Mbps | 400mV (D+/D-) | NRZI + 位填充 | 5m | 否 |
| SS | 5 Gbps | 100mV 差分 | 8b/10b | 3m | 是 |
| SS+ | 10 Gbps | 100mV 差分 | 8b/10b | 1m（被动） | 是 |
| SS+ 2x2 | 20 Gbps | 100mV 差分 | 8b/10b | 1m（被动） | 是 |
| USB4 | 20/40 Gbps | 100mV 差分 | 128b/132b | 0.8m（被动） | 是 |

**关键差异**：USB 2.0（LS/FS/HS）为半双工共享差分对，USB 3.x+ 为全双工独立 TX/RX 通道。

---

## 3. 信号定义

### 3.1 USB 2.0 信号（4 线制）

| 信号名 | 功能 | 说明 |
|--------|------|------|
| `VBUS` | 电源 | +5V 供电（Host → Device），检测设备连接 |
| `D+` | 数据正 | 差分信号正端，兼用连接检测（FS/HS） |
| `D-` | 数据负 | 差分信号负端，兼用连接检测（LS） |
| `GND` | 地 | 信号地和电源地 |

**连接检测机制**：
- Device 端 D+ 或 D- 上拉 1.5kΩ 电阻到 3.3V
- FS Device：D+ 上拉 → Host 检测 D+ 变高 → 识别为 FS 设备
- LS Device：D- 上拉 → Host 检测 D- 变高 → 识别为 LS 设备
- HS Device：初始 FS 上拉 → 通过 Chirp 握手协商切换到 HS

### 3.2 USB 3.x 信号（9 线制，含兼容 USB 2.0）

| 信号名 | 功能 | 说明 |
|--------|------|------|
| `VBUS` | 电源 | +5V 供电 |
| `D+` / `D-` | USB 2.0 兼容 | 向下兼容 USB 2.0 设备 |
| `SSTX+` / `SSTX-` | SuperSpeed 发送 | Host→Device 差分发送对 |
| `SSRX+` / `SSRX-` | SuperSpeed 接收 | Device→Host 差分接收对 |
| `GND_DRAIN` | 信号地 | 信号回流地 |

**关键变化**：USB 3.x 新增独立的 TX/RX 差分对，实现全双工。USB 2.0 的 D+/D- 线保留用于向后兼容。

### 3.3 USB 2.0 线状态定义

| 线状态 | D+ | D- | 含义 |
|--------|----|----|------|
| SE0 | 低 | 低 | 单端 0：复位/包结束/断开 |
| SE1 | 低 | 高 | 单端 1：非法状态 |
| J | 高 | 低 | 空闲态（FS）/ 驱动态 |
| K | 低 | 高 | 与 J 互补（FS） |
| IDLE | - | - | FS：J 状态；LS：K 状态 |

---

## 4. 拓扑结构

USB 采用树形拓扑，Host 为根节点，通过 Hub 级联扩展。

```
                    +-----------+
                    |   Host    |
                    | (Root Hub)|
                    +-----+-----+
                          |
              +-----------+-----------+
              |                       |
         +----+----+            +----+----+
         |  Hub 1  |            |  Hub 2  |
         +----+----+            +----+----+
              |                      |    |
         +----+----+          +-----+ +-----+
         |  Hub 1.1 |         |     | |     |
         +----+----+        Dev1  Dev2 Dev3
              |
         +---------+
         | Dev1.1  |
         +---------+
```

**拓扑规则**：
- 最多 7 层级联（Root Hub + 5 级 Hub + 1 级 Device = 127 个设备地址）
- Hub 负责上行/下行信号中继、连接检测、端口电源管理
- Host 轮询调度所有事务，Device 不能主动发起通信（除 Remote Wakeup）
- USB 3.x 超速路径和 USB 2.0 路径独立，Hub 内部实际为两个独立子系统

---

## 5. 数据包格式（USB 2.0）

USB 2.0 定义四类包（Packet），均以 SYNC 字段开始，以 EOP（End of Packet）结束。

### 5.1 包类型

| 包类型 | PID 范围 | 组成 | 说明 |
|--------|----------|------|------|
| Token | 0x01~0x0F | PID + ADDR/ENDP + CRC5 | 事务发起方（Host）发送，指定目标设备和端点 |
| Data | 0x03~0x0F | PID + Data (0~1024B) + CRC16 | 携带实际数据负载 |
| Handshake | 0x02~0x0E | PID only | ACK/NAK/STALL/ERR 确认 |
| Special | 特殊 | PID + ... | PRE（低速前导）、SOF（帧起始）、Split 等 |

### 5.2 PID 编码

PID（Packet Identifier）为 4 位编码，取反后重复，共 8 位。

| PID[3:0] | PID 值 | 含义 | 类型 |
|----------|--------|------|------|
| 0001 | 0xE1 | OUT | Token |
| 1001 | 0x69 | IN | Token |
| 0101 | 0xA5 | SOF | Special |
| 1101 | 0x25 | SETUP | Token |
| 0011 | 0xC3 | DATA0 | Data |
| 1011 | 0x4B | DATA1 | Data |
| 0111 | 0x87 | DATA2 (HS) | Data |
| 1111 | 0x0F | MDATA (HS) | Data |
| 0010 | 0xD2 | ACK | Handshake |
| 1010 | 0x5A | NAK | Handshake |
| 0110 | 0x96 | STALL | Handshake |
| 1110 | 0x1E | NYET (HS) | Handshake |
| 1100 | 0x3C | PRE | Special |
| 1000 | 0x7F | ERR (Split) | Handshake |

### 5.3 包结构

```
Token 包:
+--------+------+------------+-------+-----+
|  SYNC  | PID  | ADDR (7b)  |ENDP(4b)|CRC5 |  EOP
+--------+------+------------+-------+-----+

Data 包:
+--------+------+------------------+-------+-----+
|  SYNC  | PID  | DATA (0~1024 B)  | CRC16 |  EOP
+--------+------+------------------+-------+-----+

Handshake 包:
+--------+------+-----+
|  SYNC  | PID  | EOP |
+--------+------+-----+
```

**位填充规则**：NRZI 编码后，连续 6 个 1 必须插入 1 个 0，接收端自动去除。

---

## 6. 传输类型

| 传输类型 | 端点方向 | 最大包长（HS） | 用途 | 特性 |
|----------|----------|---------------|------|------|
| Control | IN/OUT | 64 B | 设备配置、命令 | 必须有，双向，保证传输（重试） |
| Bulk | IN 或 OUT | 512 B | 大数据存储 | 无带宽保证，尽力传输，重试保证 |
| Interrupt | IN 或 OUT | 1024 B | 周期性查询，低延迟 | 有最小轮询间隔，保证延迟上界 |
| Isochronous | IN 或 OUT | 1024 B | 音视频实时流 | 有带宽保证，无重试（无 ACK），允许丢包 |

**调度优先级**：Host 总是优先调度 Isochronous 和 Interrupt，剩余带宽分配给 Bulk 和 Control。

**事务对比**：

| 特性 | Control | Bulk | Interrupt | Isochronous |
|------|---------|------|-----------|-------------|
| 数据完整性 | 保证 | 保证 | 保证 | 不保证 |
| 带宽保证 | 无 | 无 | 有（最小间隔） | 有（预留带宽） |
| 拥塞处理 | NAK 重试 | NAK 重试 | NAK 重试 | 无 NAK，跳过 |
| 数据切换 | DATA0/DATA1 | DATA0/DATA1 | DATA0/DATA1 | 仅 DATA0 |
| 典型应用 | 枚举 | U盘传输 | 鼠标键盘 | 音频/摄像头 |

---

## 7. 事务流程

### 7.1 IN 事务（Device → Host）

```
Host                                      Device
  |                                         |
  |---- [IN Token] ------------------------>|  Phase 1: Token（Host 发出）
  |                                         |
  |<--- [DATA0/DATA1 payload] -------------|  Phase 2: Data（Device 回复数据）
  |                                         |
  |---- [ACK] ---------------------------->|  Phase 3: Handshake（Host 确认）
  |                                         |
```

- Device 无数据可发：回复 NAK → Host 重试
- Device 端点 STALL：回复 STALL → Host 停止该端点调度

### 7.2 OUT 事务（Host → Device）

```
Host                                      Device
  |                                         |
  |---- [OUT Token] ---------------------->|  Phase 1: Token
  |                                         |
  |---- [DATA0/DATA1 payload] ------------>|  Phase 2: Data
  |                                         |
  |<--- [ACK] ----------------------------|  Phase 3: Handshake（Device 确认）
  |                                         |
```

- Device 缓冲区满：回复 NAK → Host 重试
- HS Bulk 传输：Device 可回复 NYET（not yet）→ PING 机制探测就绪

### 7.3 SETUP 事务（Control 传输专用）

```
Host                                      Device
  |                                         |
  |---- [SETUP Token] -------------------->|  Stage 1: Setup
  |---- [DATA0: 8B Setup Packet] --------->|  （bmRequestType + bRequest + wValue + wIndex + wLength）
  |<--- [ACK] ----------------------------|
  |                                         |
  |---- [IN/OUT Token] ------------------->|  Stage 2: Data（可选，方向由 bmRequestType 决定）
  |---- [DATA0/DATA1 ...] ---------------->|  （N 个数据包）
  |<--- [ACK] ----------------------------|
  |                                         |
  |---- [IN/OUT (反向)] ------------------>|  Stage 3: Status（确认阶段）
  |<--- [DATA0 (ZLP)] --------------------|  （零长度包表示成功）
  |---- [ACK] ----------------------------|
```

### 7.4 HS Bulk 传输 PING 事务

```
Host                                      Device
  |                                         |
  |---- [PING Token] --------------------->|  探测端点是否就绪
  |<--- [NAK] ----------------------------|  未就绪
  |                                         |
  |---- [PING Token] --------------------->|  再次探测
  |<--- [ACK] ----------------------------|  就绪
  |                                         |
  |---- [OUT Token] ---------------------->|  开始数据传输
  |---- [DATA ...] ----------------------->|
```

---

## 8. 端点（Endpoint）

端点是 Device 内部的数据缓冲区，每个端点有唯一编号（0~15），对应一个传输方向。

### 8.1 端点类型

| 端点号 | 方向 | 类型 | 说明 |
|--------|------|------|------|
| EP0 | IN/OUT | Control | 默认控制端点，枚举和命令使用，必须存在 |
| EP1~EP15 | IN 或 OUT | Bulk / Interrupt / Isochronous | 可选，由设备描述符声明 |

**关键规则**：
- EP0 始终为 Control 类型，双向共享同一个端点号
- 其他端点每个方向独立编号（如 EP1 IN 和 EP1 OUT 是两个端点）
- 端点属性在 Endpoint Descriptor 中声明

### 8.2 数据切换（Data Toggle）

USB 使用 DATA0/DATA1 交替机制保证数据顺序和完整性：

```
Host 发送 DATA0 → Device ACK → toggle 翻转
Host 发送 DATA1 → Device ACK → toggle 翻转
...
```

- Host 和 Device 各自维护独立的 toggle 状态
- 收到 CRC 错误的包：不翻转 toggle，对方重发
- SETUP 事务始终使用 DATA0，完成后 Host 和 Device toggle 均复位为 DATA1

### 8.3 双缓冲（Double Buffering）

- 适用于 Bulk 和 Isochronous 端点
- Device 内部维护两个缓冲区：一个供 USB SIE 读写，一个供应用/固件处理
- 减少总线空闲等待，提高吞吐
- SIE 设计中需支持 buffer 切换的 ping-pong 机制

---

## 9. 描述符体系

描述符是 Device 向 Host 报告自身能力和配置的数据结构，层次化组织。

### 9.1 描述符层级

```
Device Descriptor (每设备 1 个)
  |
  +-- Configuration Descriptor 1 (至少 1 个)
  |     |
  |     +-- Interface Descriptor 0 (至少 1 个)
  |     |     |
  |     |     +-- Endpoint Descriptor EP1 IN
  |     |     +-- Endpoint Descriptor EP2 OUT
  |     |
  |     +-- Interface Descriptor 1
  |           |
  |           +-- Endpoint Descriptor EP3 IN
  |
  +-- Configuration Descriptor 2 (可选)
  |
  +-- String Descriptor 0, 1, 2, ... (可选，存储厂商/产品/序列号字符串)
```

### 9.2 主要描述符

| 描述符类型 | bDescriptorType | 长度 | 关键字段 | 说明 |
|------------|-----------------|------|----------|------|
| Device | 0x01 | 18 B | bcdUSB, idVendor, idProduct, bNumConfigurations | 设备基本信息 |
| Configuration | 0x02 | 9+N B | wTotalLength, bNumInterfaces, bmAttributes, bMaxPower | 一个配置的完整信息含子描述符 |
| Interface | 0x04 | 9 B | bInterfaceNumber, bInterfaceClass, bNumEndpoints | 接口功能分组 |
| Endpoint | 0x07 | 7 B | bEndpointAddress, bmAttributes, wMaxPacketSize, bInterval | 端点传输参数 |
| String | 0x03 | 变长 | UNICODE 字符串 | 可选，人可读标识 |
| HID Report | 0x22 | 变长 | 报告格式 | HID 类专用 |

### 9.3 标准请求（Control Transfer on EP0）

| bRequest | 值 | 方向 | 功能 |
|----------|----|------|------|
| GET_DESCRIPTOR | 0x06 | Device→Host | 读取描述符 |
| SET_ADDRESS | 0x05 | Host→Device | 分配设备地址 |
| SET_CONFIGURATION | 0x09 | Host→Device | 激活配置 |
| GET_STATUS | 0x00 | Device→Host | 获取状态 |
| CLEAR_FEATURE | 0x01 | Host→Device | 清除特性 |
| SET_FEATURE | 0x03 | Host→Device | 设置特性 |
| GET_INTERFACE | 0x0A | Device→Host | 获取当前 Alternate Setting |
| SET_INTERFACE | 0x0B | Host→Device | 切换 Alternate Setting |

---

## 10. 枚举过程

Host 通过枚举过程发现 Device 并分配地址和配置。

### 10.1 枚举步骤

| 步骤 | Host 动作 | Device 响应 | 说明 |
|------|----------|-------------|------|
| 1 | 检测 D+/D- 上拉 | - | VBUS 供电，Device 上拉电阻就位 |
| 2 | 总线复位（SE0 ≥ 2.5μs） | Device 进入默认地址 0 | 复位 Device 状态 |
| 3 | GET_DESCRIPTOR (Device, 18B) | 返回 Device Descriptor | 读取厂商 ID、产品 ID、最大包长 |
| 4 | SET_ADDRESS (addr=N) | Device 切换到地址 N | 分配唯一设备地址 |
| 5 | GET_DESCRIPTOR (Device, 18B) @ addr N | 返回完整 Device Descriptor | 用新地址重新读取 |
| 6 | GET_DESCRIPTOR (Configuration, 全部) | 返回 Configuration + Interface + Endpoint | 读取所有子描述符 |
| 7 | GET_DESCRIPTOR (String, 可选) | 返回字符串 | 厂商名、产品名等 |
| 8 | SET_CONFIGURATION (config=1) | Device 激活配置，端点就绪 | 枚举完成，设备可用 |
| 9 | 加载类驱动（Class Driver） | - | 根据 idVendor/idProduct/bInterfaceClass 匹配驱动 |

### 10.2 枚举状态机

```
Powered → Default (addr 0) → Address Assigned → Configured → Active
                 |                   |                  |
            总线复位           SET_ADDRESS        SET_CONFIGURATION
```

- Default 状态：地址为 0，仅响应 EP0
- Address 状态：已分配地址，可响应全部描述符查询
- Configured 状态：端点已激活，进入正常工作模式

---

## 11. USB 2.0 收发器（PHY）信号

### 11.1 SIE 与 PHY 接口

USB 控制器通常分为 SIE（Serial Interface Engine，协议层）和 PHY（Physical Layer，物理层）两部分。

```
 +------------------+       +------------------+
 |       SIE        |       |      PHY         |
 |                  |       |                  |
 | [UTMI/ULPI] <==== Bus ====> [Analog TX/RX]---> D+/D-
 |  数字协议逻辑     |       |  模拟收发器       |
 +------------------+       +------------------+
```

### 11.2 UTMI 接口信号

UTMI（USB 2.0 Transceiver Macrocell Interface）是 SIE 到 PHY 的标准数字接口。

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `DataOut[7:0]` | SIE→PHY | 8 | 发送数据（并行） |
| `TxValid` | SIE→PHY | 1 | 发送数据有效 |
| `TxReady` | PHY→SIE | 1 | PHY 已取走数据 |
| `DataIn[7:0]` | PHY→SIE | 8 | 接收数据（并行） |
| `RxValid` | PHY→SIE | 1 | 接收数据有效 |
| `RxActive` | PHY→SIE | 1 | 接收进行中 |
| `RxError` | PHY→SIE | 1 | 接收错误（位填充/CRC） |
| `LineState[1:0]` | PHY→SIE | 2 | 线状态：00=SE0, 01=J, 10=K, 11=SE1 |
| `XcvrSelect[1:0]` | SIE→PHY | 2 | 收发器选择（HS/FS/LS） |
| `TermSelect` | SIE→PHY | 1 | 终端选择（HS：低阻；FS：1.5k） |
| `SuspendM` | SIE→PHY | 1 | 挂起使能（低有效） |
| `OpMode[1:0]` | SIE→PHY | 2 | 操作模式（正常/Disable bit stuffing/Loopback） |

### 11.3 ULPI 接口

ULPI（UTMI+ Low Pin Interface）将 UTMI 的并行接口缩减为 12 引脚：
- `DATA[3:0]`：4-bit 双向数据总线（DDR，60MHz 时提供 480Mbps 吞吐）
- `CLK`：60MHz 时钟（HS）/ 48MHz 时钟（FS）
- `DIR`：数据方向（0=SIE→PHY, 1=PHY→SIE）
- `NXT`：下一个数据节拍
- `STP`：停止传输
- `RST`：复位

**设计选型**：UTMI 引脚多但接口简单；ULPI 引脚少但协议复杂（需命令编码）。SoC 集成 PHY 用 UTMI，外置 PHY 用 ULPI。

### 11.4 PHY 关键时序

| 参数 | 典型值 | 说明 |
|------|--------|------|
| TxReady 延迟 | 1~2 cycle | TxValid 到 TxReady 的响应 |
| RxValid 延迟 | 1 cycle | RxActive 后 RxValid 有效 |
| 线状态检测 | < 2 bit time | 接收端在 2 个位时间内锁定状态 |
| EOP 检测 | SE0 持续 ≥ 1 bit time | 包结束判断 |
| Chirp 检测 | K 脉冲 7.5 ms | HS 握手序列 |

---

## 12. OTG 扩展

USB OTG（On-The-Go）允许设备在 Host 和 Device 角色间切换。

### 12.1 角色定义

| 角色 | 说明 |
|------|------|
| A-Device | 默认 Host，提供 VBUS 供电 |
| B-Device | 默认 Device，由 VBUS 供电 |
| Dual-Role Device | 支持 HNP，可动态切换 Host/Device |

### 12.2 关键协议

**SRP（Session Request Protocol）**：
- B-Device 请求 A-Device 开启 VBUS 供电会话
- B-Device 先发数据线脉冲（Data Line Pulsing），再发 VBUS 脉冲
- A-Device 检测后开启 VBUS → 新会话开始

**HNP（Host Negotiation Protocol）**：
- 已建立会话的 A/B 角色可交换 Host 身份
- B-Device 发送总线挂起 → A-Device 检测到总线释放 → B-Device 切换为 Host
- 适用于：手机当 Device 连接 PC（A-Device），手机要读 U 盘时切换为 Host

### 12.3 OTG 引脚

| 引脚 | 功能 | 说明 |
|------|------|------|
| `ID` | OTG 身份检测 | 接地 → A-Device；悬空 → B-Device |
| 其他 | 同 USB 2.0 | VBUS, D+, D-, GND |

---

## 13. 设计注意事项

### 13.1 PHY 接口设计

| 要点 | 说明 |
|------|------|
| UTMI/ULPI 选择 | SoC 内嵌 PHY 用 UTMI（位宽 8/16），外置 PHY 用 ULPI（12 引脚） |
| PHY 时钟域 | PHY 提供 60MHz（HS）/ 48MHz（FS）时钟，SIE 需同步处理 |
| 挂起功耗 | Suspend 时 PHY 进入低功耗模式，SIE 需管理时钟门控 |
| ESD 保护 | D+/D- 需片上 ESD 保护二极管 |

### 13.2 SIE 设计要点

| 模块 | 功能 | 设计关键 |
|------|------|----------|
| 协议引擎 | 包解析/生成，PID 校验 | CRC5/CRC16 校验/生成，NRZI 编解码，位填充 |
| 端点控制器 | 端点缓冲管理，双缓冲切换 | 支持 16 个端点，Ping-Pong buffer，Data Toggle 状态机 |
| 事务调度器 | Token 发送 / Data 传输 / Handshake 处理 | 状态机：Idle → Token → Data → Handshake → Idle |
| DMA 引擎 | 端点 FIFO 与系统内存之间搬数 | 支持 Scatter-Gather，burst 传输 |
| 寄存器组 | 控制/状态/中断寄存器 | APB/AHB 从接口，中断聚合 |

### 13.3 端点 FIFO 设计

| 设计参数 | 说明 |
|----------|------|
| 深度 | ≥ wMaxPacketSize × 2（双缓冲）；HS Bulk = 512 × 2 = 1024 B |
| 位宽 | 8 bit（UTMI 8-bit）或 32 bit（DMA 宽总线） |
| 满/空标志 | 支持 almost_full / almost_empty 用于 DMA 流控 |
| 方向 | IN 端点：系统→FIFO→PHY；OUT 端点：PHY→FIFO→系统 |
| 乒乓切换 | buffer 满/空后切换 active buffer，同时产生中断通知 |

### 13.4 DMA 接口

| 要点 | 说明 |
|------|------|
| 传输模式 | 逐包（Packet-by-Packet）或 Scatter-Gather（描述符链） |
| 总线宽度 | 32-bit 或 64-bit AHB/AXI |
| 突发长度 | INCR4/INCR8/INCR16，需对齐 FIFO 深度 |
| 中断 | 每包完成中断 + 传输完成中断 + 错误中断 |

### 13.5 CDC（Clock Domain Crossing）处理

USB 系统典型涉及两个时钟域：

| 时钟域 | 来源 | 频率 | 说明 |
|--------|------|------|------|
| 系统总线时钟 | SoC 主时钟 | 100~200 MHz | DMA、寄存器访问 |
| USB PHY 时钟 | PHY 输出 | 30/48/60 MHz | 协议引擎、端点 FIFO |

**CDC 关键路径**：

| 路径 | 同步方法 | 级数 | 说明 |
|------|----------|------|------|
| 控制信号（寄存器→SIE） | 双触发器同步 | 2 级 | 使能、复位、模式切换 |
| 状态信号（SIE→寄存器） | 双触发器同步 | 2 级 | 忙标志、完成标志 |
| FIFO 写指针（跨域读） | Gray 码 + 双触发器 | 2 级 | 写侧 Gray 化后同步到读侧 |
| FIFO 读指针（跨域写） | Gray 码 + 双触发器 | 2 级 | 读侧 Gray 化后同步到写侧 |
| 数据总线 | 异步 FIFO | 2 级+ | 数据宽度 ≥ 8 bit 必须用异步 FIFO |

---

## 14. USB 3.0 特性简述

### 14.1 超速链路架构

USB 3.0 引入层次化的链路协议：

```
Protocol Layer (协议层：包级，与 USB 2.0 语义兼容)
    |
Link Layer (链路层：帧级，链路管理、流控、CRC）
    |
Physical Layer (物理层：8b/10b 编码、SerDes、均衡）
```

### 14.2 关键差异（vs USB 2.0）

| 特性 | USB 2.0 | USB 3.0 |
|------|---------|---------|
| 信号 | 半双工 D+/D- | 全双工 SSTX/SSRX 差分对 |
| 带宽 | 480 Mbps | 5 Gbps（单通道），10 Gbps（Gen2） |
| 编码 | NRZI + 位填充 | 8b/10b |
| 拓扑 | 共享总线 | 点对点（每个端口独立通道） |
| 枚举 | Hub 中继检测 | LFPS（Low Frequency Periodic Signaling） |
| 流控 | NAK/ACK | Credit-based（链路层） |
| 功耗 | Suspend/Resume | U1/U2/U3 低功耗状态 + Function Suspend |

### 14.3 LFPS（Low Frequency Periodic Signaling）

- 用于链路建立和唤醒，频率 10~50 MHz 的脉冲串
- Polling LFPS：端口检测连接的握手序列
- Warm Reset：通过 LFPS 执行链路级复位
- Ux Exit：从低功耗状态唤醒时使用

### 14.4 USB 3.0 包结构

USB 3.0 定义两种包：

**链路管理包（LMP）**：端口间控制信息交换（如流控 credit 通告、链路配置）。
- Header 为 2 DW（8 字节），无 CRC。

**事务包（TP）**：承载协议层事务。
- Header 为 2 DW + CRC，序列号 2-bit，携带路由字符串（12-bit）定位目标设备。

### 14.5 带宽管理

| 机制 | 说明 |
|------|------|
| Isochronous Timestamp | Host 广播时间戳包，同步各端点 |
| Credit-based 流控 | 链路层信用计数，避免缓冲区溢出 |
| 多流支持 | Bulk 流（Stream），单端点可并发多个传输流 |
| 功耗状态 | U0（Active）→ U1（快速）→ U2（慢速）→ U3（Suspend），带宽随状态变化 |

### 14.6 USB 3.x 速率汇总

| 版本 | Gen | 通道数 | 总速率 | 编码 | 接口引脚 |
|------|-----|--------|--------|------|----------|
| USB 3.0 | Gen1 | 1 | 5 Gbps | 8b/10b | USB-A / USB-C |
| USB 3.1 | Gen2 | 1 | 10 Gbps | 8b/10b | USB-C |
| USB 3.2 | Gen1x2 | 2 | 10 Gbps | 8b/10b | USB-C |
| USB 3.2 | Gen2x2 | 2 | 20 Gbps | 8b/10b | USB-C |
| USB4 | Gen3x2 | 2 | 20/40 Gbps | 128b/132b | USB-C |

---

## 附录 A. 缩略语

| 缩写 | 全称 |
|------|------|
| CRC | Cyclic Redundancy Check |
| EOP | End of Packet |
| FS | Full Speed |
| HNP | Host Negotiation Protocol |
| HS | High Speed |
| LFPS | Low Frequency Periodic Signaling |
| LS | Low Speed |
| NRZI | Non-Return-to-Zero Inverted |
| OTG | On-The-Go |
| PHY | Physical Layer |
| PID | Packet Identifier |
| SE0 | Single-Ended Zero |
| SIE | Serial Interface Engine |
| SRP | Session Request Protocol |
| SS | SuperSpeed |
| UTM | USB Transceiver Macrocell |
| ULPI | UTMI+ Low Pin Interface |
| ZLP | Zero Length Packet |
