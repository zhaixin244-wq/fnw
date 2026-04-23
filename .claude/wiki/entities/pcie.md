# PCIe

高速串行点对点互联总线，取代传统并行 PCI/PCI-X。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 高速串行互联 |
| **版本** | PCIe Base Spec r6.3 (Gen1~Gen6) |
| **来源** | PCI-SIG |

## 核心特征

- **3 层架构**：事务层 / 数据链路层 / 物理层
- **点对点**：非共享总线，每通道 1 对 TX + 1 对 RX 差分
- **Credit 流控**：6 种 Credit 类型，基于信用的流控
- **可靠性**：链路级 CRC + ACK/NAK 重传
- **TLP/DLLP 包**：基于包的数据模型
- **Gen6 新特性**：PAM4 信令、FLIT 模式、IDE 加密

## 关键信号/概念

| 概念 | 说明 |
|------|------|
| `TX+/TX-` | 发送差分对 |
| `RX+/RX-` | 接收差分对 |
| `LTSSM` | 链路训练状态机 |
| `TLP` | 事务层包（Memory/IO/Config/Completion/Message） |
| `DLLP` | 数据链路层包（ACK/NAK/FC Update） |
| `BDF` | Bus/Device/Function 设备标识 |
| `MSI/MSI-X` | 消息信号中断 |

## 关键参数

| 参数 | Gen1 | Gen2 | Gen3 | Gen4 | Gen5 | Gen6 |
|------|------|------|------|------|------|------|
| 速率(GT/s) | 2.5 | 5 | 8 | 16 | 32 | 64 |
| 编码 | 8b/10b | 8b/10b | 128b/130b | 128b/130b | 128b/130b | 1b/1b FLIT |
| 信令 | NRZ | NRZ | NRZ | NRZ | NRZ | PAM4 |
| 最大 Lane | x32 | x32 | x32 | x32 | x32 | x32 |

## 典型应用

- NVMe SSD
- GPU 互联
- 网卡 / FPGA 加速卡
- SoC 内部互联

## 与其他协议的关系

- **AXI4**：PCIe RC/EP 内部通常使用 AXI4 互连
- **USB**：USB 主机控制器通过 PCIe 连接 CPU
- PCIe 是外部高速互联的主流方案

## 设计要点

- Credit 流控：发送前检查 Credit 余额，不足则阻塞
- Posted vs Non-Posted：MWr 为 Posted 无需完成包，MRd 为 Non-Posted 需 CplD
- 4KB 地址边界规则
- LTSSM 状态机管理链路训练/电源管理
- Gen6 PAM4 信令需 FEC 纠错
