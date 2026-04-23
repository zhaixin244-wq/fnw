# Ethernet

> IEEE 802.3 有线局域网二层协议，定义帧格式、MAC 控制与物理层接口，是所有有线网络的基础承载协议。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络协议（L2 数据链路层） |
| **标准** | IEEE 802.3 |
| **速率** | 10M / 100M / 1G / 10G / 25G / 40G / 50G / 100G / 200G / 400G / 800G |

## 核心特性

1. **帧格式**：DST MAC(6B) + SRC MAC(6B) + EtherType(2B) + Payload(46-1500B) + FCS(4B)，最小 64B / 最大 1518B（不含 VLAN Tag）
2. **MAC 控制**：PAUSE 帧（802.3x）全双工流控，PFC（802.1Qbb）按优先级类暂停
3. **自协商**：速率/双工/流控自动协商（1000BASE-T 以上仅全双工）
4. **物理层接口**：MII / GMII / XGMII / XLGMI / CAUI / USXGMII，SerDes 串行化
5. **MACsec (802.1AE)**：逐跳加密与完整性保护，SecTAG + ICV

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| MAC 地址 | 48 bit | 全球唯一，前 24bit OUI |
| 最小帧长 | 64 bytes | 含 FCS，保证冲突检测 |
| 最大帧长 | 1518 / 2000 / 9000 bytes | 标准 / Baby Jumbo / Jumbo |
| FCS | CRC-32 (IEEE 802.3) | 覆盖 Header + Payload |
| IFG | 12 bytes | 帧间隔 (Inter-Frame Gap) |
| Preamble | 8 bytes | 55 55 55 55 55 55 55 D5 |

## 典型应用场景

- 数据中心服务器网卡 (NIC) / SmartNIC / DPU
- ToR / Leaf / Spine 交换机
- 芯片间 SerDes 高速互连

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| VLAN (802.1Q) | 在 EtherType 后插入 4B Tag，扩展为 VLAN 帧 |
| IP | 上层协议，EtherType=0x0800(IPv4)/0x86DD(IPv6) |
| ARP | EtherType=0x0806 |
| PFC (802.1Qbb) | 基于 MAC Control 帧的逐优先级流控 |
| RoCE v2 | 基于 Ethernet + UDP/IP 承载 RDMA |

## RTL 设计要点

- **CRC-32 计算**：并行 CRC 引擎，32-bit 宽，1 周期生成 FCS，需处理残余字节
- **MAC Tx/Rx FIFO**：Tx 侧包缓冲 + 速率适配；Rx 侧帧重组 + 丢弃短帧/长帧/CRC 错误帧
- **帧间隙定时**：IFG = 12 bytes 严格遵守，Tx 状态机 IDLE → PREAMBLE → DATA → IFG → IDLE
- **SerDes 接口**：64b/66b 编码 (10G+)，Gearbox 速率适配，Lane 对齐 (Block Lock)
- **MACsec offload**：SecTAG 插入/剥离、AES-GCM 加解密引擎、SCI/SSCI 管理
- **CRC 反转**：Ethernet CRC 输入输出均反转 (reflected)，初始值 0xFFFFFFFF

## 参考

- IEEE 802.3-2022
- IEEE 802.1Qbb (PFC)
- IEEE 802.1AE (MACsec)
