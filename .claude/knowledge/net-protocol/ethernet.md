# 以太网 L2 (Ethernet Layer 2) 协议知识文档

> **目标读者**：数字 IC 设计架构师（MAC 设计、交换芯片方向）
> **版本**：v1.0
> **日期**：2026-04-15

---

## 1. 协议概述

### 1.1 IEEE 802.3 标准

以太网由 Xerox PARC 于 1973 年发明，后经 Digital、Intel、Xerox（DIX）联合标准化为 Ethernet II，IEEE 在此基础上制定 IEEE 802.3 标准族。两者在帧格式上有细微差异（详见第 2 节）。

IEEE 802.3 标准覆盖物理层（PHY）和数据链路层的 MAC 子层，定义了信号编码、帧格式、介质访问控制方式等核心规范。

### 1.2 共享介质 vs 交换介质

| 特性 | 共享介质（Shared） | 交换介质（Switched） |
|------|-------------------|---------------------|
| 拓扑 | 总线型 / 集线器（Hub） | 星型 / 交换机（Switch） |
| 冲突域 | 所有端口在同一冲突域 | 每端口独立冲突域 |
| 带宽 | 所有站点共享 | 每端口独享带宽 |
| 典型设备 | 10BASE-2/5, Hub | Layer 2 Switch |
| CSMA/CD | 必需 | 全双工模式下不需要 |

### 1.3 CSMA/CD（半双工）vs 全双工

**CSMA/CD（Carrier Sense Multiple Access with Collision Detect）**：

- 半双工模式下使用，站点发送前先监听（Carrier Sense），若检测到冲突则发送 Jam Signal，执行退避算法后重传
- 现代交换网络已基本淘汰半双工，但 MAC 设计仍需兼容

**全双工**：

- 点对点链路，发送和接收同时进行，无冲突检测
- 现代以太网的主流工作模式
- 需要流量控制（Pause 帧）替代冲突检测的流控作用

---

## 2. 以太网帧格式

### 2.1 Ethernet II (DIX) 帧

```
+----------+----------+--------+------------------+-----+
|    DA    |    SA    |  Type  |     Payload      | FCS |
|  6 bytes |  6 bytes | 2 bytes| 46~1500 bytes    |4bytes|
+----------+----------+--------+------------------+-----+
           |<-------- Minimum 64 bytes (excl. preamble) -------->|
```

| 字段 | 说明 |
|------|------|
| **DA (Destination Address)** | 目的 MAC 地址，6 字节 |
| **SA (Source Address)** | 源 MAC 地址，6 字节 |
| **Type** | 上层协议类型，值 >= 1536 (0x0600)。常见值：0x0800=IPv4, 0x0806=ARP, 0x86DD=IPv6, 0x8100=802.1Q VLAN |
| **Payload** | 数据载荷，46~1500 字节。不足 46 字节需填充（Padding）至最小帧长 64 字节（不含 Preamble） |
| **FCS (Frame Check Sequence)** | CRC-32 校验，4 字节 |

**前导码（Preamble）与 SFD**：7 字节 0x55 + 1 字节 0xD5，用于接收端时钟同步，不计入帧长。

### 2.2 IEEE 802.3 帧

```
+----------+----------+--------+-----------+------------------+-----+
|    DA    |    SA    | Length | LLC/SNAP  |     Payload      | FCS |
|  6 bytes |  6 bytes | 2 bytes| 3~8 bytes | 46~1500 bytes    |4bytes|
+----------+----------+--------+-----------+------------------+-----+
```

| 字段 | 说明 |
|------|------|
| **Length** | 值 <= 1500 (0x05DC)，表示 Payload + LLC/SNAP 的总长度 |
| **LLC (Logical Link Control)** | 3 字节 DSAP + SSAP + Control |
| **SNAP (Sub-Network Access Protocol)** | 5 字节 OUI (3) + Type (2)，用于承载 EtherType |

**区分方法**：Length/Type 字段值 <= 1500 为 802.3 帧，>= 1536 为 Ethernet II 帧。

### 2.3 VLAN 标签

#### 802.1Q（单层 VLAN）

在 DA+SA 之后插入 4 字节 VLAN Tag：

```
+----------+----------+------------------+--------+------------------+-----+
|    DA    |    SA    |    VLAN Tag      |  Type  |     Payload      | FCS |
|  6 bytes |  6 bytes |    4 bytes        | 2 bytes| 46~1500 bytes    |4bytes|
+----------+----------+------------------+--------+------------------+-----+
                          |
                     +---------+------+----------+
                     |  TPID   | TCI  |          |
                     | 2 bytes | 2 bytes|         |
                     +---------+------+----------+
                          |        |
                     0x8100   +----+-----+--------+
                              | PCP | DEI |  VID   |
                              | 3b  | 1b  | 12 bits|
                              +-----+-----+--------+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| **TPID** | 16 bits | Tag Protocol Identifier，值 0x8100，取代原 Type 位置 |
| **PCP** | 3 bits | Priority Code Point (0~7)，用于 QoS 优先级 |
| **DEI** | 1 bit | Drop Eligible Indicator，可丢弃标记 |
| **VID** | 12 bits | VLAN ID (0~4095)，0 和 4095 保留 |

#### 802.1ad（QinQ，双层 VLAN）

在 802.1Q 外层再加一层 VLAN Tag：

```
+----+----+----------+----------+-----+
| DA | SA | Outer Tag| Inner Tag|Type | Payload | FCS |
+----+----+----------+----------+-----+---------+-----+
         | TPID     | TPID     |
         | 0x88A8   | 0x8100   |
```

- 外层 TPID = 0x88A8（运营商 VLAN）
- 内层 TPID = 0x8100（客户 VLAN）
- 带 VLAN Tag 的最小帧长为 68 字节

---

## 3. MAC 地址格式

### 3.1 48-bit MAC 地址结构

```
+---+---+---+---+---+---+---+---+---+---+---+---+...+---+---+---+---+---+---+
| b7| b6| b5| b4| b3| b2| b1| b0| b7| b6|...| b0|...| b7| b6|...| b1| b0|
+---+---+---+---+---+---+---+---+---+---+---+---+...+---+---+---+---+---+---+
 |           |                     |                             |
I/G U/L      |<------ OUI (24 bits) ----->|<------ NIC (24 bits) -------->|
```

| 位 | 名称 | 说明 |
|----|------|------|
| Bit 0 (Byte 0, LSB) | **I/G** | Individual/Group：0=单播，1=组播 |
| Bit 1 (Byte 0) | **U/L** | Universal/Local：0=全局唯一（OUI 分配），1=本地管理 |

### 3.2 地址类型

| 类型 | 格式 | 说明 |
|------|------|------|
| **单播 (Unicast)** | I/G=0 | 发往单一目标站点 |
| **组播 (Multicast)** | I/G=1，非全 1 | 发往一组站点 |
| **广播 (Broadcast)** | FF:FF:FF:FF:FF:FF | 发往所有站点 |
| **OUI** | 前 3 字节 | IEEE 分配给厂商的唯一标识 |

---

## 4. 速率演进表

| 速率 | IEEE 标准 | 常见名称 | 编码 | 对 PHY 接口 | 最大距离（铜缆） | 帧时间 (@min) |
|------|-----------|---------|------|------------|-----------------|--------------|
| 10 Mbps | 802.3i | 10BASE-T | Manchester | MII | 100m (Cat3) | 51.2 us |
| 100 Mbps | 802.3u | 100BASE-TX | 4B5B + MLT-3 | MII / RMII | 100m (Cat5) | 5.12 us |
| 1 Gbps | 802.3ab | 1000BASE-T | 4D-PAM5 | GMII / RGMII / SGMII | 100m (Cat5e) | 512 ns |
| 2.5 Gbps | 802.3bz | 2.5GBASE-T | DSQ128 | 2.5GMII / USXGMII | 100m (Cat5e) | 204.8 ns |
| 5 Gbps | 802.3bz | 5GBASE-T | DSQ128 | 5GMII / USXGMII | 100m (Cat6) | 102.4 ns |
| 10 Gbps | 802.3ae | 10GBASE-SR/LR | 64B66B | XGMII / XAUI | 300m (OM3 MMF) / 10km (SMF) | 51.2 ns |
| 25 Gbps | 802.3by | 25GBASE-SR/CR | 64B66B | 25GMII | 100m (OM4 MMF) | 20.48 ns |
| 40 Gbps | 802.3ba | 40GBASE-SR4 | 64B66B (4x10G) | XLGMII / XLAUI (4-lane) | 150m (OM4 MMF) | 12.8 ns |
| 50 Gbps | 802.3cd | 50GBASE-SR/CR | PAM4 | 50GMII / LAUI-2 | 100m (OM4 MMF) | 10.24 ns |
| 100 Gbps | 802.3ba | 100GBASE-SR10/SR4 | 64B66B (4x25G/10x10G) | CGMII / CAUI-4 (4-lane) / CAUI-10 | 150m (OM4 MMF) / 10km (SMF) | 5.12 ns |
| 200 Gbps | 802.3bs | 200GBASE-SR4/FR4 | PAM4 (4x50G) | CAUI-8 (8-lane) | 100m (OM4 MMF) | 2.56 ns |
| 400 Gbps | 802.3bs | 400GBASE-SR16/FR8 | PAM4 (8x50G / 16x25G) | CAUI-16 / C2M (8-lane) | 100m (OM4 MMF) / 2km (SMF) | 1.28 ns |
| 800 Gbps | 802.3df | 800GBASE-SR8/DR8 | PAM4 (8x100G) | C2M (8-lane x100G) | 100m (OM4 MMF) / 500m (SMF) | 0.64 ns |

> 帧时间 = 最小帧长(64B x 8 = 512 bits) / 速率

---

## 5. 物理层（PHY）接口

### 5.1 MII 系列（≤ 1G）

| 接口 | 速率 | 数据位宽 | 时钟频率 | 信号数 | 说明 |
|------|------|---------|---------|--------|------|
| **MII** | 10/100 Mbps | 4-bit TX + 4-bit RX | 25 MHz (100M) / 2.5 MHz (10M) | 18 | 标准并行接口 |
| **RMII** | 10/100 Mbps | 2-bit | 50 MHz (REF_CLK) | 9 | 减少引脚 |
| **GMII** | 1 Gbps | 8-bit TX + 8-bit RX | 125 MHz | 24 | 千兆并行接口 |
| **RGMII** | 1 Gbps | 4-bit DDR | 125 MHz (DDR) | 14 | 减半引脚的 GMII |
| **SGMII** | 10/100/1000 Mbps | SerDes 1-lane | 625/62.5/6.25 MHz (serial) | 4 (差分) | 串行 GMII，支持自协商 |
| **QSGMII** | 4x1 Gbps | SerDes 1-lane | 5 GHz (serial) | 4 (差分) | 4 端口复用单 lane |

### 5.2 XGMII 系列（10G）

| 接口 | 速率 | 数据位宽 | 时钟频率 | 说明 |
|------|------|---------|---------|------|
| **XGMII** | 10 Gbps | 32-bit DDR + 4-bit C/M | 156.25 MHz (DDR) | 标准并行，74 pin |
| **XAUI** | 10 Gbps | 4 SerDes lanes | 3.125 GHz/lane | 串行替代 XGMII，16 pin |
| **RXAUI** | 10 Gbps | 2 SerDes lanes | 6.25 GHz/lane | 减半 XAUI |

### 5.3 高速串行接口（≥ 25G）

| 接口 | 速率 | Lanes | 每 Lane 速率 | 说明 |
|------|------|-------|-------------|------|
| **25GMII** | 25 Gbps | 1 | 25.78125 Gbps | 25G 内部接口 |
| **XLAUI** | 40 Gbps | 4 | 10.3125 Gbps | 40G 芯片间接口 |
| **CAUI-4** | 100 Gbps | 4 | 25.78125 Gbps | 100G 芯片间接口 |
| **CAUI-8** | 200 Gbps | 8 | 26.5625 Gbps (PAM4) | 200G 芯片间接口 |
| **CAUI-16** | 400 Gbps | 16 | 26.5625 Gbps (PAM4) | 400G 芯片间接口 |
| **C2M** | 800 Gbps | 8 | 106.25 Gbps (PAM4) | 800G 芯片到模块接口 |

> SerDes 速率说明：64B66B 编码引入 ~3% 开销，故串行速率略高于名义速率。PAM4 编码下符号速率 = 比特速率 / 2。

---

## 6. 帧间间隔（IFG / IPG）

| 参数 | 值 | 说明 |
|------|----|------|
| **IFG (Inter-Frame Gap)** | 96-bit time | 帧间最小空闲时间（无论速率） |
| **IPG (Inter-Packet Gap)** | 12 bytes | 等价于 IFG（按字节计） |

**各速率下 IFG 时间**：

| 速率 | IFG (96 bit-time) |
|------|--------------------|
| 10 Mbps | 9.6 us |
| 100 Mbps | 960 ns |
| 1 Gbps | 96 ns |
| 10 Gbps | 9.6 ns |
| 100 Gbps | 960 ps |
| 400 Gbps | 240 ps |

> MAC TX 设计必须在帧之间插入至少 96-bit time 的 IFG，这是标准强制要求。

---

## 7. FCS（CRC-32 校验）

### 7.1 CRC-32 多项式

**IEEE 802.3 标准多项式**：

```
G(x) = x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10
     + x^8  + x^7  + x^5  + x^4  + x^2  + x^1  + x^0
```

**十六进制表示**：`0x04C11DB7`

**反转多项式（Reflected）**：`0xEDB88320`（按位反转后的多项式，硬件实现常用）

### 7.2 CRC 计算方法

**初始化值**：`0xFFFFFFFF`

**计算范围**：DA + SA + Length/Type + Payload（不含 Preamble、SFD 和 FCS）

**最终操作**：`FCS = ~CRC_result`（按位取反）

**逐字节处理**（MSB-first，即反射模式）：

```verilog
// 单 bit CRC-32 更新（硬件实现常用反射多项式）
function [31:0] crc32_next;
    input [31:0] crc_in;
    input        data_bit;
    reg   [31:0] crc_tmp;
begin
    crc_tmp = crc_in ^ {31'b0, data_bit};
    if (crc_tmp[0])
        crc32_next = {1'b0, crc_tmp[31:1]} ^ 32'hEDB88320;
    else
        crc32_next = {1'b0, crc_tmp[31:1]};
end
endfunction
```

### 7.3 并行 CRC-32 优化

逐 bit 实现吞吐太低，实际 MAC 设计通常采用 **8-bit（1 byte/cycle）** 或 **32-bit（4 bytes/cycle）** 并行 CRC：

```
并行 CRC 推导方法：
1. 写出单 bit 递推关系：CRC[n+1] = f(CRC[n], data[n])
2. 将 N 个单 bit 操作展开为矩阵运算
3. 预计算 N-bit 的 CRC 更新矩阵
4. 硬件实现为 N-bit 输入的组合逻辑

8-bit 并行 CRC：每时钟周期处理 1 字节，适用于 GMII (125 MHz x 8-bit)
32-bit 并行 CRC：每时钟周期处理 4 字节，适用于 XGMII (156.25 MHz x 32-bit DDR)
64-bit 并行 CRC：适用于 100G+ 接口（CGMII 64-bit @ ~390 MHz）
```

### 7.4 CRC 校验接收端

接收端对整个帧（含 FCS 字段）计算 CRC，结果应为 `0xC704DD7B`（残余值）。若不为 0 则判为 CRC 错误，丢弃该帧。

---

## 8. 自动协商（Auto-Negotiation）

### 8.1 概述

自动协商用于物理层双方交换能力信息，协商最优的速率和双工模式。主要应用于 100BASE-TX 和 1000BASE-T。

### 8.2 1000BASE-T 自动协商

使用 **FLP (Fast Link Pulse)** 交换 Base Page 和 Next Pages：

```
Base Page (16 bits):
+--------+--------+-----+-----+------+--------+----------+--------+
| Selector| Echoed |Ack  | NP  | RF   |  Pause| Adv.     | Half   |
| Field   | Nonce  |     |     |      | (802.3x)| Duplex | Duplex |
| [4:0]   | [4:0]  | [1] | [1] | [1]  | [1]   | Speed    |        |
+---------+--------+-----+-----+------+-------+----------+--------+
```

| 字段 | 说明 |
|------|------|
| Selector Field | 协议选择器（IEEE 802.3 = 00001） |
| Adv. Speed | 支持的速率能力位 |
| Half/Full Duplex | 双工模式能力位 |
| Pause (802.3x) | 是否支持 Pause 帧 |
| ACK | 确认收到对方页 |
| NP | 是否有后续 Next Page |
| RF | Remote Fault |

### 8.3 SGMII 自动协商

SGMII 通过 **自动协商序列**（在 idle 码组中携带）实现速率协商，不需要额外的协商引脚：
- PHY 发送包含速率信息的 idle 符号
- MAC 侧据此调整内部时钟分频

---

## 9. 流量控制

### 9.1 半双工：CSMA/CD

**二进制指数退避算法**：

```
冲突第 k 次重传（k <= 10）：
    r = random(0, 2^k - 1)    // k = min(冲突次数, 10)
    延迟 = r × Slot Time

Slot Time = 512 bit-time (以太网)
最大重试次数 = 16，超过则丢弃并报错
```

| 冲突次数 | 退避范围 (r) | 最大延迟 |
|---------|-------------|---------|
| 1 | 0~1 slot | 51.2 us (10M) |
| 2 | 0~3 slots | 153.6 us |
| 3 | 0~7 slots | 358.4 us |
| 10 | 0~1023 slots | 52.4 ms |
| >= 16 | 放弃传输 | - |

### 9.2 全双工：IEEE 802.3x Pause 帧

**Pause 帧格式**（MAC Control Frame）：

```
+----------+----------+--------+--------+----------+----------+-----+
|    DA    |    SA    |  Type  | Opcode | Parameter| Reserved | FCS |
| 01-80-C2 |  Src MAC | 0x8808 |0x0001  |  2 bytes | 42 bytes |4bytes|
| -00-01   |          |        |        |(pause_time)|  (0)   |     |
+----------+----------+--------+--------+----------+----------+-----+
```

| 字段 | 值 | 说明 |
|------|----|------|
| DA | `01:80:C2:00:00:01` | 目的组播地址（保留的 MAC Control 地址） |
| Type | `0x8808` | MAC Control EtherType |
| Opcode | `0x0001` | Pause 操作码 |
| Pause Time | 0~65535 | 暂停发送的时间（以 512 bit-time 为单位）= quanta |
| Pause Time = 0 | - | 取消 Pause（Resume） |

**处理流程**：

1. 接收端检测到 Pause 帧（Opcode=0x0001）
2. 读取 Pause Time 参数
3. MAC TX 暂停发送数据帧（Pause Time × 512 bit-time）
4. Pause Time 到期后恢复发送
5. 收到 Pause Time=0 的帧可提前恢复

### 9.3 PFC (IEEE 802.1Qbb)：逐优先级 Pause

**增强型 Pause 帧**：

```
+----------+--------+--------+----------+----------+-----+
|    DA    |  Type  | Opcode | Class-En | Time[0]~ | FCS |
| 01-80-C2 | 0x8808 | 0x0101 | Vector   | Time[7]  |     |
| -00-01   |        |        | (2 bytes)|(16 bytes)|     |
+----------+--------+--------+----------+----------+-----+
```

| 字段 | 说明 |
|------|------|
| Opcode | `0x0101`（PFC 专用操作码） |
| Class Enable Vector | 16-bit，Bit[7:0] 指示 8 个 CoS 哪些启用 PFC |
| Time[0]~Time[7] | 每个 CoS 的暂停时间（quanta），0 表示不暂停 |

**与 802.3x Pause 的关键区别**：

| 特性 | 802.3x Pause | 802.1Qbb PFC |
|------|-------------|-------------|
| 粒度 | 全端口暂停 | 按 CoS (0~7) 逐优先级暂停 |
| Opcode | 0x0001 | 0x0101 |
| Pause Time | 1 个参数 | 8 个独立参数 |
| 应用场景 | 简单流控 | 无损以太网（RoCE/数据中心） |

---

## 10. Jumbo Frame

### 10.1 概述

标准以太网最大帧长（MTU）为 1500 字节，Jumbo Frame 将 MTU 扩展到更大值。

| 参数 | 标准帧 | Jumbo Frame |
|------|--------|-------------|
| MTU (Payload) | 1500 bytes | 典型 9000 bytes，部分厂商支持 9216 bytes |
| 最大帧长（含头+FCS） | 1518 bytes | 典型 9018 bytes |
| IEEE 标准 | 802.3 定义 | **非 IEEE 标准**，厂商私有扩展 |

### 10.2 MAC 设计影响

| 设计项 | 影响 |
|--------|------|
| FCS 计算 | CRC-32 对长帧计算延迟增大，需流水线化 |
| 缓冲区 | TX/RX FIFO 深度需增大以容纳完整 Jumbo 帧 |
| 帧超时 | 需增加帧超时保护（防止异常长帧导致死锁） |
| 统计计数器 | MIB 需增加 Jumbo Frame 计数器 |
| 以太网类型/长度 | Type/Length 字段解析逻辑不变，但需支持更长的帧计数 |

---

## 11. 以太网交换基础

### 11.1 MAC 地址学习

**学习过程**：

1. 交换机维护 **MAC 地址表（FDB, Forwarding Database）**
2. 收到帧时，提取 SA 记录到 FDB：`<MAC Address, Port, VLAN ID, Age Timer>`
3. 转发帧时，查 FDB 中 DA 对应的 Port，单播转发
4. DA 未查到时 **洪泛（Flooding）** 到 VLAN 内所有端口
5. 老化定时器到期（典型 300s）清除表项

### 11.2 VLAN 转发

| 操作 | 说明 |
|------|------|
| **Access Port** | 收帧打上 PVID Tag，发帧剥掉 Tag |
| **Trunk Port** | 收帧保留 Tag（允许的 VLAN），发帧保留 Tag |
| **Hybrid Port** | 可灵活配置哪些 VLAN 带 Tag 发出 |
| 转发规则 | 帧仅在相同 VLAN 内转发，VLAN 隔离广播域 |

### 11.3 STP/RSTP

**STP (IEEE 802.1D)**：
- 选举 Root Bridge（最小 Bridge ID = Priority + MAC）
- 计算到 Root Bridge 的最短路径，阻塞冗余端口
- 收敛时间 30~50 秒

**RSTP (IEEE 802.1w)**：
- 快速收敛（< 1 秒），引入 Proposal/Agreement 机制
- 端口角色：Root Port, Designated Port, Alternate Port, Backup Port
- 端口状态：Discarding, Learning, Forwarding

---

## 12. MAC 子层设计框图

### 12.1 MAC TX 通路

```
+------------------+     +------------------+     +----------+     +----------+
|   Upper Layer    |     |     MAC TX       |     |          |     |          |
|   (Host/MAC IP)  |---->|                  |---->| PHY IF   |---->|   PHY    |
|                  |     | +--------------+ |     | (GMII/   |     |          |
|  TX Descriptor   |     | | Frame Assemble| |     | RGMII/   |     +----------+
|  / TX FIFO       |     | | DA+SA+Type   | |     | SGMII)   |
|                  |     | | + Payload    | |     |          |
+------------------+     | | + Pad (if any)| |     +----------+
                         | | + FCS Gen    | |
                         | +--------------+ |
                         | | IFG Insert    | |
                         | +--------------+ |
                         | | Pause Handler | |
                         | +--------------+ |
                         | | Stat Counter  | |
                         | +--------------+ |
                         +------------------+
```

### 12.2 MAC RX 通路

```
+----------+     +------------------+     +------------------+
|          |     |     MAC RX       |     |   Upper Layer    |
|   PHY    |---->|                  |---->|   (Host/MAC IP)  |
|          |     | +--------------+ |     |                  |
+----------+     | | Preamble/SFD | |     |  RX Descriptor   |
                 | | Strip        | |     |  / RX FIFO       |
     PHY IF ---->| +--------------+ |     |                  |
  (GMII/RGMII/  | | DA Filtering | |     +------------------+
   SGMII)       | +--------------+ |
                 | | Frame Parse  | |
                 | | SA/DA/Type   | |
                 | +--------------+ |
                 | | VLAN Handle  | |
                 | +--------------+ |
                 | | Length Check  | |
                 | +--------------+ |
                 | | FCS Check    | |
                 | | (CRC-32)     | |
                 | +--------------+ |
                 | | Pause Detect | |
                 | +--------------+ |
                 | | Stat Counter | |
                 | | / MIB Update | |
                 | +--------------+ |
                 +------------------+
```

---

## 13. MAC RTL 设计注意事项

### 13.1 帧解析与封装

| 设计要点 | 说明 |
|----------|------|
| Preamble/SFD 检测 | RX 侧需检测 7 字节 0x55 + 1 字节 0xD5，丢弃 Preamble |
| 帧边界检测 | 通过 SFD 定位帧起始，通过 Length 或帧间 IFG 定位帧结束 |
| VLAN Tag 识别 | TPID=0x8100 为 802.1Q，TPID=0x88A8 为 802.1ad QinQ |
| Type/Length 区分 | 值 <= 1500 为 802.3 Length，>= 1536 为 EtherType |
| Padding 补齐 | TX 侧帧长 < 64 字节（不含 Preamble/SFD）时自动补零 |
| 最小帧长检查 | RX 侧可选检查帧长是否 >= 64 字节，不足可判为 runt frame |

### 13.2 CRC-32 生成与校验

| 设计要点 | 说明 |
|----------|------|
| TX CRC 生成 | 从 DA 开始到 Payload 末尾计算 CRC，结果追加在帧尾 |
| RX CRC 校验 | 对整个帧（含 FCS 字段）计算 CRC，结果应为 0xC704DD7B |
| 并行计算 | 1G 用 8-bit 并行 CRC，10G 用 32-bit 或 64-bit 并行 CRC |
| CRC 错误处理 | 校验失败的帧丢弃，更新 CRC Error 计数器（MIB） |
| Store-and-Forward vs Cut-Through | Cut-Through 模式下 CRC 校验需在转发后进行，可能转发错误帧 |

### 13.3 字节对齐

| 场景 | 对齐要求 |
|------|---------|
| GMII | 8-bit 数据总线，每时钟 1 字节，自然对齐 |
| RGMII | 4-bit DDR，上升沿/下降沿各 4 bit，需 DDR 接收逻辑 |
| XGMII | 32-bit 数据 + 4-bit 控制（C/M），每时钟 4 字节 |
| CGMII (100G) | 64-bit 数据 + 8-bit 控制，每时钟 8 字节 |

### 13.4 速率适配

| 场景 | 解决方案 |
|------|---------|
| MAC 时钟 vs PHY 时钟 | FIFO 缓冲 + 异步时钟域转换 |
| 不同端口速率汇聚 | 内部总线带宽需 >= 所有端口之和 |
| 速率降档 | MAC 需支持动态速率切换（如 100M 降级到 10M） |
| 变长帧处理 | Cut-Through 模式需处理帧长度不确定的情况 |

### 13.5 Pause 帧处理

| 设计要点 | 说明 |
|----------|------|
| TX Pause 接收 | 检测 Pause 帧（DA=01:80:C2:00:00:01, Type=0x8808, Opcode=0x0001） |
| Pause 定时器 | Pause Time × 512 bit-time 计时，到期恢复发送 |
| Pause 帧发送 | 下游拥塞时主动发送 Pause 帧 |
| PFC 支持 | 如需无损网络，实现 8 级 CoS 独立 Pause |
| Pause 帧不转发 | Pause 帧为本地流控，不应被交换机转发 |

### 13.6 统计计数器（MIB）

**必须实现的 MIB 计数器**（RFC 2863 / IEEE 802.3 Clause 30）：

| 计数器 | 类型 | 说明 |
|--------|------|------|
| `ifInOctets` | RX | 接收字节总数 |
| `ifInUcastPkts` | RX | 接收单播帧数 |
| `ifInMulticastPkts` | RX | 接收组播帧数 |
| `ifInBroadcastPkts` | RX | 接收广播帧数 |
| `ifInErrors` | RX | 接收错误帧总数 |
| `ifInCrcErrors` | RX | CRC 校验错误帧数 |
| `ifInFrameTooLong` | RX | 超长帧数 |
| `ifInUndersizePkts` | RX | 过短帧数（<64B） |
| `ifInPauseFrames` | RX | 接收 Pause 帧数 |
| `ifOutOctets` | TX | 发送字节总数 |
| `ifOutUcastPkts` | TX | 发送单播帧数 |
| `ifOutMulticastPkts` | TX | 发送组播帧数 |
| `ifOutBroadcastPkts` | TX | 发送广播帧数 |
| `ifOutErrors` | TX | 发送错误帧数 |
| `ifOutPauseFrames` | TX | 发送 Pause 帧数 |

> 计数器位宽建议 64-bit（RFC 2863 要求 64-bit 累计值），需支持原子读取或快照机制。

### 13.7 与 PHY 接口时序

| 接口 | 关键时序参数 | 设计建议 |
|------|-------------|---------|
| **GMII** | TX_CLK 125 MHz，setup/hold ~1.5 ns | 数据在 TX_CLK 上升沿后输出 |
| **RGMII** | DDR 125 MHz，t_setup = 0.9 ns, t_hold = 0.9 ns | 需要内部 DLL/PLL 调节 TX 时钟偏移 |
| **SGMII** | SerDes CDR 恢复时钟 | 需要 SerDes/PCS 层，内部实现或外挂 IP |
| **XGMII** | DDR 156.25 MHz，源同步 | 建议使用 XAUI/SerDes 替代 |

### 13.8 与上层协议栈接口

| 接口类型 | 典型场景 | 信号 |
|----------|---------|------|
| **AXI4-Stream** | SoC 内部 MAC IP 连接 | TDATA, TVALID, TREADY, TLAST, TKEEP |
| **Wishbone** | 低成本嵌入式 | DAT, ADR, WE, STB, ACK |
| **Custom Bus** | 专用交换芯片 | 自定义 valid/ready + 数据 |

---

## 14. MII / RGMII / SGMII 接口时序

### 14.1 MII 时序

```
TX 方向（MAC → PHY）：

        ___     ___     ___     ___     ___
TX_CLK _|   |___|   |___|   |___|   |___|   |___
              |       |       |       |
TXD[3:0]  ----< D0  >-< D1  >-< D2  >-< D3  >----
TX_EN   ----<----------------- 1 ---------------->-
TX_ER   ----< valid frame >---< 0 >--------------

RX 方向（PHY → MAC）：

        ___     ___     ___     ___     ___
RX_CLK _|   |___|   |___|   |___|   |___|   |___
              |       |       |       |
RXD[3:0]  ----< D0  >-< D1  >-< D2  >-< D3  >----
RX_DV   ----<----------------- 1 ---------------->-
RX_ER   ----< valid frame >---< 0 >--------------

时钟频率：25 MHz (100M), 2.5 MHz (10M)
数据位宽：4-bit，每时钟 1 个 nibble
```

### 14.2 RGMII 时序

```
TX 方向（MAC → PHY），DDR 模式：

           _       _       _       _
TX_CLK   _| |_____| |_____| |_____| |_____
           |  |    |  |    |  |    |  |
TXD[3:0] --D0-+--D1-+--D2-+--D3-+--D4--   (DDR：上升沿和下降沿各传 4 bit)
TX_CTL  ----TX_EN--------0----------------

           _______________
           |  setup  |hold|
           | >=0.9ns |>=0.9ns |

RX 方向类似，PHY 在 RX_CLK 的上升沿和下降沿各输出 4-bit 数据。

时钟频率：125 MHz (DDR)，等效数据速率 1 Gbps
数据位宽：4-bit DDR（每时钟周期传输 2 个 nibble = 1 字节）
关键约束：TX_CLK 内部延迟约 1.5~2.0 ns（通常由 PHY 侧添加）
```

### 14.3 SGMII 时序

```
TX 方向（MAC → PHY / SerDes）：

+----------+     +--------+     +-----------+
| MAC TX   |---->| PCS    |---->| SerDes TX |
| (GMII)   |     |(8B10B  |     | (串行化)  |
| 8-bit    |     |编码)   |     | 1.25 Gbps |
+----------+     +--------+     +-----------+

串行数据流：
    __  __  __  __  __  __  __  __  __  __
   |  ||  ||  ||  ||  ||  ||  ||  ||  ||  |
___|  ||  ||  ||  ||  ||  ||  ||  ||  ||  |___

每个 bit 周期 = 0.8 ns (1.25 GHz serial clock)
10-bit 编码符号速率 = 125 M symbols/s (含 8B/10B 开销)
等效数据速率 = 1000 Mbps (8/10 编码效率)

RX 方向：
- PHY SerDes RX 通过 CDR（Clock Data Recovery）恢复时钟
- PCS 层执行 10B→8B 解码
- 输出 GMII 格式数据给 MAC

关键设计点：
- SGMII 自协商通过 idle 码组（/I1/, /I2/）携带速率信息
- 不需要独立的自协商引脚
- 支持 10/100/1000 Mbps 速率（通过符号重复/丢弃实现降速）
```

---

## 参考文献

| 编号 | 文档 |
|------|------|
| 1 | IEEE 802.3-2022, IEEE Standard for Ethernet |
| 2 | IEEE 802.1Q-2022, Bridges and Bridged Networks |
| 3 | IEEE 802.1Qbb, Priority-based Flow Control |
| 4 | IEEE 802.1ad, Provider Bridges (QinQ) |
| 5 | IEEE 802.3x, Full Duplex and Flow Control |
| 6 | IEEE 802.3by, 25 Gb/s Ethernet |
| 7 | IEEE 802.3bs, 200G/400G Ethernet |
| 8 | RFC 2863, The Interfaces Group MIB |
| 9 | CRC-32 Polynomial Analysis, Koopman, P. (1999) |
