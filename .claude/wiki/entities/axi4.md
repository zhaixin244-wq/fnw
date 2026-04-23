# AXI4

高性能片上总线协议，支持突发传输、乱序完成和多 Outstanding 事务。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 片上总线（AMBA 家族） |
| **版本** | AMBA AXI4 (ARM IHI 0022E) |
| **来源** | ARM |

## 核心特征

- **五通道分离架构**：AW/W/B/AR/R 通道独立，支持并行传输
- **突发传输**：FIXED/INCR/WRAP 三种类型，最大 256 拍
- **乱序完成**：不同 ID 事务可乱序返回，提高总线利用率
- **多 Outstanding**：多个未完成事务并行飞行，隐藏延迟
- **字节选通 WSTRB**：支持非对齐字节粒度写操作
- **原子操作**：AxLOCK 信号支持独占访问（Exclusive Access）
- **4KB 地址边界**：突发传输不可跨越 4KB 边界

## 关键信号

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| `AWID/ARID` | ID_WIDTH | M→S | 事务标识，用于乱序/排序 |
| `AWADDR/ARADDR` | ADDR_WIDTH | M→S | 起始地址 |
| `AWLEN/ARLEN` | 8 | M→S | 突发长度（实际拍数 = AWLEN+1） |
| `AWSIZE/ARSIZE` | 3 | M→S | 每拍字节数 = 2^AWSIZE |
| `AWBURST/ARBURST` | 2 | M→S | 突发类型：FIXED/INCR/WRAP |
| `WDATA` | DATA_WIDTH | M→S | 写数据（8~1024 bit） |
| `WSTRB` | DATA_WIDTH/8 | M→S | 字节选通 |
| `WLAST` | 1 | M→S | 写最后一拍标记 |
| `RDATA` | DATA_WIDTH | S→M | 读数据 |
| `RLAST` | 1 | S→M | 读最后一拍标记 |
| `BRESP/RRESP` | 2 | S→M | 响应码：OKAY/EXOKAY/SLVERR/DECERR |
| `AxVALID/AxREADY` | 1 | - | Valid/Ready 握手信号 |
| `AWCACHE/ARCACHE` | 4 | M→S | 缓存属性 |
| `AWPROT/ARPROT` | 3 | M→S | 保护属性 |
| `AWQOS/ARQOS` | 4 | M→S | QoS 服务质量标识 |

## 关键参数

| 参数 | 范围 | 说明 |
|------|------|------|
| 数据位宽 | 8~1024 bit | 2 的幂次 |
| 地址位宽 | 最高 64 bit | 通常 32 bit |
| ID 位宽 | 参数化 | 用于乱序排序 |
| 最大突发长度 | 256 拍 | AXI4 支持 1~256 |
| 响应码 | OKAY/EXOKAY/SLVERR/DECERR | 4 种 |

## 典型应用

- DDR/HBM 控制器接口
- 高性能 DMA 引擎
- SoC 片上互连（Crossbar/Mesh）
- GPU/NPU 数据通路
- PCIe/SATA 桥接

## 与其他协议的关系

- **AXI4-Lite**：AXI4 精简版，无 burst、无 ID、仅单拍 32/64 bit
- **AXI4-Stream**：AXI4 流式变体，无地址空间，单向数据流
- **AHB**：AXI4 前身/简化版，2 级流水线，最大 16 拍 burst
- **APB**：最低层级外设总线，通过 AXI-to-APB 桥连接

## 设计要点

- Valid 不能依赖 Ready（防组合环路）
- WLAST/RLAST 必须正确标记 burst 最后一拍
- 不可跨越 4KB 地址边界
- ID 信号实现乱序，需确保同 ID 保序
