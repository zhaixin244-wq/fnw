# AHB

高性能系统总线，支持突发传输和流水线操作。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 片上总线（AMBA 家族） |
| **版本** | AMBA AHB5 (ARM IHI 0033E) |
| **来源** | ARM |

## 核心特征

- **2 级流水线**：地址阶段和数据阶段重叠，提高吞吐
- **突发传输**：INCR/WRAP 突发，最大 16 拍
- **单周期总线移交**：无等待状态的主设备切换
- **非三态总线**：AHB5 去除三态驱动，DFT 友好
- **AHB-Lite 变体**：单 Master 版本，去仲裁逻辑，用于 Cortex-M

## 关键信号

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| `HCLK` | 1 | I | 总线时钟 |
| `HRESETn` | 1 | I | 低有效异步复位 |
| `HADDR` | ADDR_WIDTH | M→S | 地址总线 |
| `HTRANS` | 2 | M→S | 传输类型：IDLE/BUSY/NONSEQ/SEQ |
| `HWDATA` | DATA_WIDTH | M→S | 写数据 |
| `HRDATA` | DATA_WIDTH | S→M | 读数据 |
| `HWRITE` | 1 | M→S | 写使能 |
| `HSIZE` | 3 | M→S | 传输大小 = 2^HSIZE |
| `HBURST` | 3 | M→S | 突发类型：SINGLE/INCR/WRAP4/8/16 |
| `HREADY` | 1 | S→M | 传输完成（等待状态控制） |
| `HRESP` | 2 | S→M | 响应码（AHB5 简化为 OKAY/ERROR） |
| `HPROT` | 4 | M→S | 保护属性 |

## 关键参数

| 参数 | 范围 | 说明 |
|------|------|------|
| 数据位宽 | 8/16/32/64/128/256/512/1024 | 通常 32/64 |
| 最大突发长度 | 16 拍 | INCR/WRAP |
| 地址边界 | 1 KB | 突发不可跨越 |
| 流水线级数 | 2 | 地址+数据 |

## 典型应用

- 嵌入式处理器系统总线（Cortex-M/R）
- DMA 控制器
- SRAM/ROM 控制器
- AHB-to-APB 桥接

## 与其他协议的关系

- **AXI4**：AHB 的升级版，5 通道、支持 OoO/Outstanding
- **APB**：AHB 通过桥接器连接 APB 外设
- **AHB-Lite**：AHB 单 Master 简化版

## 设计要点

- HREADY 在数据阶段拉低插入等待状态
- HTRANS=NONSEQ/SEQ 区分突发首拍/后续拍
- 突发不可跨越 1KB 边界
- AHB5 简化 HRESP 为 1 bit（OKAY/ERROR）
