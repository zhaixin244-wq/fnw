# TileLink

RISC-V 生态片上互联总线协议，支持缓存一致性。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 片上总线 |
| **版本** | TileLink Spec v1.8 |
| **来源** | UC Berkeley |

## 核心特征

- **3 级兼容**：TL-UL（轻量）/ TL-UH（重量）/ TL-C（缓存一致）
- **5 通道架构**：A/B/C/D/E 通道，独立 Valid/Ready 握手
- **缓存一致性**：TL-C 支持 MESI-like 协议（None/Branch/Tip 权限）
- **消息传输**：基于消息（非地址/数据分离），每事务一条消息
- **RISC-V 标准**：Rocket Chip / BOOM / Chipyard 的标准互联方案
- **向下兼容**：TL-C master 可与 TL-UH/TL-UL slave 通信

## 关键信号

| 通道 | 方向 | TL-UL | TL-UH | TL-C | 说明 |
|------|------|-------|-------|------|------|
| A | Client→Manager | 有 | 有 | 有 | 请求通道 |
| B | Manager→Client | - | 有 | 有 | Probe/通知 |
| C | Client→Manager | - | 有 | 有 | Release/响应 |
| D | Manager→Client | 有 | 有 | 有 | 响应通道 |
| E | Client→Manager | - | - | 有 | Grant Ack |

## 关键参数

| 特性 | TL-UL | TL-UH | TL-C |
|------|-------|-------|------|
| 缓存一致性 | 无 | 无 | 完整 MESI-like |
| Burst/Block | 无 | 支持 | 支持 |
| 原子操作 | 不支持 | 支持 | 支持 |
| Hint/Intent | 不支持 | 支持 | 支持 |
| Outstanding | 支持 | 支持 | 支持 |
| 典型 Master | 简单外设 | DMA | CPU Cache |

## 典型应用

- RISC-V SoC 互联（Rocket Chip/BOOM）
- L1/L2 缓存一致性域
- DMA 控制器连接
- 外设寄存器访问（TL-UL）

## 与其他协议的关系

- **AXI4**：AXI4 无缓存一致性，TileLink TL-C 有 MESI-like
- **AMBA ACE**：ARM 一致性扩展，TileLink 是 RISC-V 生态的对应方案
- **Wishbone**：Wishbone 更简单，TileLink 功能更丰富

## 设计要点

- A 通道操作码：Get/PutFullData/PutPartialData/ArithmeticData/LogicalData/GetBlock/PutBlock
- TL-C 一致性流程：Acquire → Grant → Probe → Release
- source/sink ID 匹配：A.channel source 对应 D.channel source
- Valid/Ready 握手规则同 AXI4：Valid 不依赖 Ready
- channel 间无时序依赖，可在不同周期完成
