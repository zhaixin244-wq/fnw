# APB

低功耗外设总线，用于寄存器访问。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 片上总线（AMBA 家族） |
| **版本** | AMBA APB4 (ARM IHI 0024E) |
| **来源** | ARM |

## 核心特征

- **3 状态 FSM**：IDLE → SETUP → ACCESS，协议极简
- **无流水线**：每次事务必须完成才能发起下一次
- **无 Burst**：每次传输只访问一个地址
- **低功耗**：信号翻转少，静态功耗极低
- **APB4 扩展**：PREADY（等待扩展）、PSLVERR（错误响应）、PSTRB（字节选通）
- **面积最小**：约 500 gates，AMBA 家族中最简单

## 关键信号

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| `PCLK` | 1 | I | APB 时钟 |
| `PRESETn` | 1 | I | 低有效异步复位 |
| `PADDR` | ADDR_WIDTH | M→S | 地址总线 |
| `PSELx` | 1 | M→S | 从设备选择（每从设备独立） |
| `PENABLE` | 1 | M→S | 使能信号（ACCESS 阶段有效） |
| `PWRITE` | 1 | M→S | 写使能：1=写，0=读 |
| `PWDATA` | DATA_WIDTH | M→S | 写数据（通常 32 bit） |
| `PRDATA` | DATA_WIDTH | S→M | 读数据 |
| `PREADY` | 1 | S→M | 传输就绪（APB4 新增，可插入等待） |
| `PSLVERR` | 1 | S→M | 从设备错误响应（APB4 新增） |
| `PSTRB` | DATA_WIDTH/8 | M→S | 字节选通（APB4 新增） |

## 关键参数

| 参数 | 范围 | 说明 |
|------|------|------|
| 数据位宽 | 8/16/32 | 通常 32 bit |
| 零等待延迟 | 2 cycles | SETUP + ACCESS |
| 最大面积 | ~500 gates | 最小 AMBA 实现 |
| 事务类型 | 读/写 | 单拍，无 burst |

## 典型应用

- UART/SPI/I2C 控制器寄存器
- GPIO 配置
- Timer/Watchdog
- 中断控制器配置
- SoC 外设桥末端

## 与其他协议的关系

- **AXI/AHB**：通过 AXI/AHB-to-APB 桥连接，APB 处于最末端
- **AXI4-Lite**：类似场景，AXI4-Lite 保留 5 通道握手，APB 更简单
- APB 是 AMBA 体系中最低层级的总线

## 设计要点

- 3 状态 FSM：IDLE（PSELx=0）→ SETUP（PSELx=1,PENABLE=0）→ ACCESS（PSELx=1,PENABLE=1）
- PREADY 拉低可插入等待状态
- PSLVERR 在 ACCESS 阶段采样
- PSTRB 仅在写操作时有效
- 零 Outstanding，严格保序
