# spi_master

> SPI 主设备控制器，支持 4 种 SPI 模式、可配置数据宽度和多片选

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/spi_master.md |

## 核心特性
- 支持 4 种 SPI 模式（CPOL/CPHA 组合），兼容所有标准 SPI 从设备
- 可配置数据宽度 4-32 bit，支持 MSB/LSB 优先
- 可配置时钟分频，SCLK = clk / CLK_DIV
- 支持多片选（NUM_CS 参数），单模块挂接多个 SPI 从设备
- 全双工通信，同时发送和接收

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DATA_WIDTH | 8 | 4-32 | 数据位宽 |
| CLK_DIV | 4 | ≥2 | 时钟分频比 |
| CPOL | 0 | 0/1 | 时钟极性 |
| CPHA | 0 | 0/1 | 时钟相位 |
| CS_DELAY | 1 | ≥0 | 片选建立/保持延迟 |
| LSB_FIRST | 0 | 0/1 | 位序选择 |
| NUM_CS | 1 | ≥1 | 片选数量 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| tx_data | I | DATA_WIDTH | 发送数据 |
| rx_data | O | DATA_WIDTH | 接收数据 |
| start | I | 1 | 启动传输脉冲 |
| done | O | 1 | 传输完成脉冲 |
| busy | O | 1 | 传输中标志 |
| cs_sel | I | $clog2(NUM_CS) | 片选选择 |
| spi_sclk | O | 1 | SPI 时钟输出 |
| spi_mosi | O | 1 | 主出从入 |
| spi_miso | I | 1 | 主入从出 |
| spi_cs_n | O | NUM_CS | 低有效片选 |

## 典型应用场景
- SPI Flash 读写（CLK_DIV=2, Mode 0）
- SPI DAC/ADC 数据采集（多片选）
- 传感器数据读取

## 与其他实体的关系
- 与 `i2c_master` 同属串行总线主控 CBB，SPI 速率更高但仅支持点对点
- 多设备场景通过 NUM_CS 参数扩展，无需外部译码逻辑

## 设计注意事项
- CS 管理：start 前 CS_DELAY 周期拉低 CS_N，done 后 CS_DELAY 周期拉高
- 状态机：IDLE → CS_SETUP → SHIFT → CS_HOLD → DONE → IDLE
- 面积约 1-2K GE（2 × DATA_WIDTH 移位寄存器 + 计数器 + FSM）

## 参考
- 原始文档：`.claude/knowledge/cbb/spi_master.md`
