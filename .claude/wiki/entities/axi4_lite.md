# AXI4-Lite

AXI4 精简版，用于寄存器访问等低带宽场景。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 片上总线（AMBA 家族） |
| **版本** | AMBA AXI4-Lite (ARM IHI 0022E §B2) |
| **来源** | ARM |

## 核心特征

- **无突发传输**：仅单拍（single-beat），每次传输 1 个 beat
- **无 ID 信号**：所有事务按发出顺序完成（严格保序）
- **固定数据宽度**：仅 32-bit 或 64-bit
- **5 通道架构**：保留 AW/W/B/AR/R 通道，简化信号集
- **面积小**：实现面积远小于 AXI4 Full（约 5k gates）
- **低延迟**：典型 3~5 cycles

## 关键信号

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| `ACLK` | 1 | I | 全局时钟 |
| `ARESETn` | 1 | I | 低有效异步复位 |
| `AWADDR/ARADDR` | ADDR_WIDTH | M→S | 读写地址（通常 32 bit） |
| `AWPROT/ARPROT` | 3 | M→S | 保护属性：Privileged/Secure/Data-Instruction |
| `WDATA` | 32/64 | M→S | 写数据 |
| `WSTRB` | 4/8 | M→S | 字节选通 |
| `RDATA` | 32/64 | S→M | 读数据 |
| `BRESP/RRESP` | 2 | S→M | 响应码：OKAY/SLVERR/DECERR |
| `AxVALID/AxREADY` | 1 | - | Valid/Ready 握手 |

## 关键参数

| 参数 | 范围 | 说明 |
|------|------|------|
| 数据位宽 | 32 / 64 bit | 固定 |
| 地址位宽 | 通常 32 bit | 字节对齐 |
| 保护属性 | 3 bit | [2]=Priv/User, [1]=Sec/NonSec, [0]=Data/Instr |
| 面积 | ~5 kGates | 典型实现 |

## 典型应用

- CSR 寄存器访问
- 外设配置接口
- 中断控制器
- 低速外设（UART/SPI/I2C 配置）

## 与其他协议的关系

- **AXI4 Full**：AXI4-Lite 的完整版，支持 burst/ID/OoO
- **APB**：类似的寄存器访问场景，APB 更简单（3 状态 FSM）
- **AHB-Lite**：AHB 简化版，支持 burst，复杂度介于 AXI4 和 APB 之间

## 设计要点

- 严格保序（无 ID，FIFO 顺序完成）
- Valid 不能依赖 Ready（同 AXI4 规则）
- WSTRB 全 0 写入行为取决于从设备实现
- 适合与 AXI4 Full 互连（桥接逻辑简单）
