# i2c_master

> I2C 主设备控制器，支持 7/10 位寻址、标准/快速模式和时钟拉伸

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/i2c_master.md |

## 核心特性
- 支持 7 位和 10 位寻址模式
- 支持标准模式 100 kbps、快速模式 400 kbps、快速模式+ 1 Mbps
- 支持 START/STOP/RSTART 条件生成、ACK/NACK 检测
- 可选时钟拉伸（CLOCK_STRETCH 参数）
- 命令 FIFO 缓冲，支持连续事务

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| CLK_FREQ | 50_000_000 | - | 系统时钟频率 (Hz) |
| I2C_FREQ | 400_000 | 100k/400k/1M | I2C 时钟频率 (Hz) |
| ADDR_MODE | "7BIT" | "7BIT"/"10BIT" | 地址模式 |
| CLOCK_STRETCH | 1 | 0/1 | 时钟拉伸支持 |
| CMD_FIFO_DEPTH | 8 | ≥1 | 命令 FIFO 深度 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| dev_addr | I | 10 | 从设备地址 |
| wr_data | I | 8 | 写数据 |
| rd_data | O | 8 | 读数据 |
| cmd | I | 3 | 命令（0=START,1=WRITE,2=READ,3=STOP,4=RSTART） |
| cmd_valid | I | 1 | 命令有效 |
| cmd_ready | O | 1 | 命令就绪 |
| done | O | 1 | 命令完成 |
| ack | O | 1 | ACK 状态（0=ACK,1=NACK） |
| busy | O | 1 | 总线忙 |
| arbitration_lost | O | 1 | 仲裁丢失 |
| scl_oe / sda_oe | O | 1 | 开漏输出使能 |

## 典型应用场景
- I2C EEPROM 读写（7-bit 寻址）
- 温度/压力传感器读取（带时钟拉伸）
- PMIC 配置、GPIO 扩展器控制

## 与其他实体的关系
- 与 `spi_master` 同属串行总线主控 CBB，I2C 支持多主仲裁但速率较低
- 开漏输出需外部上拉电阻，与 SPI 的推挽输出不同

## 设计注意事项
- 时钟分频：`scl_div = CLK_FREQ / (4 × I2C_FREQ)`，四分频产生四相位
- 开漏输出：scl_o/sda_o 为 0 拉低，1 释放（高阻）
- 仲裁丢失：SDA 输出高但检测到低时立即释放总线
- 状态机：IDLE → START → ADDR → RW → ACK_CHECK → DATA → ACK → STOP/RSTART
- 面积约 2-4K GE

## 参考
- 原始文档：`.claude/knowledge/cbb/i2c_master.md`
