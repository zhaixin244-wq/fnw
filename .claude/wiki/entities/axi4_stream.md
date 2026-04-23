# AXI4-Stream

高速流式数据传输接口，无地址空间概念。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 流式总线（AMBA 家族） |
| **版本** | AMBA AXI4-Stream (ARM IHI 0051A) |
| **来源** | ARM |

## 核心特征

- **无地址空间**：数据从 Master 流向 Slave，无地址译码
- **单向数据流**：仅一个方向，无读/写分离
- **Valid/Ready 握手**：标准流控协议，支持背压
- **包边界标记**：TLAST 标识传输包的最后一个 beat
- **多路复用与路由**：TID/TDEST 提供流标识和目的路由
- **字节分类**：TSTRB/TKEEP 区分 Data/Position/Null 字节

## 关键信号

| 信号 | 位宽 | 必需 | 说明 |
|------|------|------|------|
| `TVALID` | 1 | 是 | 数据有效 |
| `TREADY` | 1 | 是 | 从端就绪 |
| `TDATA` | TDATA_WIDTH | 是 | 数据载荷（字节整数倍） |
| `TLAST` | 1 | 可选 | 包/帧最后 beat 标记 |
| `TSTRB` | TDATA_WIDTH/8 | 可选 | 字节有效指示（区分 Position byte） |
| `TKEEP` | TDATA_WIDTH/8 | 可选 | 字节保留指示（Data/Null） |
| `TID` | TID_WIDTH | 可选 | 流标识（Stream ID） |
| `TDEST` | TDEST_WIDTH | 可选 | 路由信息（Destination） |
| `TUSER` | TUSER_WIDTH | 可选 | 用户自定义 sideband |

## 关键参数

| 参数 | 范围 | 说明 |
|------|------|------|
| TDATA 位宽 | 8/16/32/64/128/256+ | 字节整数倍 |
| TID 位宽 | 参数化 | 通常 1~8 bit |
| TDEST 位宽 | 参数化 | 通常 1~8 bit |
| TUSER 位宽 | 参数化 | 自定义 sideband |

## 典型应用

- 视频流传输（ISP → Display）
- DMA 数据搬运
- DSP 处理链路
- 包处理流水线
- FPGA 内部数据流互连

## 与其他协议的关系

- **AXI4 Full**：AXI4-Stream 无地址、单向、无 burst 限制
- **AXI4-Lite**：AXI4-Lite 有地址空间，用于寄存器访问
- 常与 AXI4 DMA 配合：DMA 用 AXI4 读写内存，用 Stream 传输数据

## 设计要点

- TVALID 不能依赖 TREADY（防组合环路）
- TLAST 必须在包最后一拍正确断言
- TSTRB=0 且 TKEEP=1 为保留状态，不应出现
- TDATA 位宽必须为字节整数倍
