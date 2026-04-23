# spi_i2c_uart_ip

> 低速外设 IP 选型参考，SPI/I2C/UART 三种常用接口

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/spi_i2c_uart_ip.md |

## 核心特性
- SPI：同步全双工，4 线（SCLK/MOSI/MISO/CS），1-100+ MHz
- I2C：同步半双工，2 线（SCL/SDA），100k-3.4 MHz
- UART：异步全双工，2 线（TX/RX），9600-3M bps

## 关键参数

| 接口 | 速率 | 线数 | 通信方式 | 典型应用 |
|------|------|------|----------|----------|
| SPI | 1-100+ MHz | 4 | 同步全双工 | Flash、传感器 |
| I2C | 100k-3.4 MHz | 2 | 同步半双工 | EEPROM、传感器 |
| UART | 9600-3M bps | 2 | 异步全双工 | 调试串口 |

## 典型应用场景
- 嵌入式传感器接口（I2C）
- Flash 存储接口（SPI）
- 调试串口（UART）

## 与其他实体的关系
- **spi_master**：SPI 主机 CBB
- **i2c_master**：I2C 主机 CBB
- **uart_core**：UART 核心 CBB

## 设计注意事项
- SPI 支持 4 种模式（CPOL/CPHA 组合）
- I2C 需要开漏输出和上拉电阻
- UART 波特率需要时钟分频器

## 参考
- 原始文档：`.claude/knowledge/IP/spi_i2c_uart_ip.md`
