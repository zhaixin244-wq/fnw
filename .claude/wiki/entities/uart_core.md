# uart_core

> 全双工 UART 收发核心，支持可配置波特率、数据格式和 FIFO 缓冲

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/uart_core.md |

## 核心特性
- 全双工异步串行收发，支持 5-8 位数据位、1-2 位停止位
- 可配置校验：无校验、奇校验、偶校验
- 16 倍过采样接收（推荐），可配置过采样率
- TX/RX 双 FIFO 缓冲，减少 CPU 负担
- 帧错误、校验错误、溢出错误检测

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| CLK_FREQ | 50_000_000 | - | 系统时钟频率 (Hz) |
| BAUD_RATE | 115200 | - | 波特率 |
| DATA_BITS | 8 | 5-8 | 数据位数 |
| STOP_BITS | 1 | 1-2 | 停止位数 |
| PARITY | "NONE" | "NONE"/"EVEN"/"ODD" | 校验模式 |
| OVERSAMPLE | 16 | ≥8 | 过采样率 |
| TX_FIFO_DEPTH | 16 | ≥1 | 发送 FIFO 深度 |
| RX_FIFO_DEPTH | 16 | ≥1 | 接收 FIFO 深度 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| tx_data | I | DATA_BITS | 发送数据 |
| tx_valid | I | 1 | 发送有效 |
| tx_ready | O | 1 | 发送就绪（FIFO 未满） |
| rx_data | O | DATA_BITS | 接收数据 |
| rx_valid | O | 1 | 接收有效 |
| rx_ready | I | 1 | 接收就绪 |
| frame_err | O | 1 | 帧错误 |
| parity_err | O | 1 | 校验错误 |
| overrun_err | O | 1 | 溢出错误 |
| txd | O | 1 | 串行发送输出 |
| rxd | I | 1 | 串行接收输入 |

## 典型应用场景
- SoC 调试串口（115200 8N1）
- 高速通信链路（921600 带偶校验）
- 低速外设接口

## 与其他实体的关系
- 与 `spi_master`、`i2c_master` 同属串行通信 CBB，UART 最简单但仅支持点对点
- 接收过采样可参考 `cdc_sync` 的同步原理

## 设计注意事项
- 波特率生成：`baud_div = CLK_FREQ / BAUD_RATE`
- 接收采样：在每位中间（第 OVERSAMPLE/2 个采样点）采样，抗噪声
- 起始位检测：rxd 持续低电平超过半个位宽确认有效
- TX/RX 各一个同步 FIFO，深度可配置
- 面积约 2-5K GE

## 参考
- 原始文档：`.claude/knowledge/cbb/uart_core.md`
