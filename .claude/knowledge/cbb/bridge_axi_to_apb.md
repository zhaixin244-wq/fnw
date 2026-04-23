# bridge_axi_to_apb — AXI-to-APB 桥接器

> **用途**：AXI4-Lite 主接口转 APB 从接口，用于低速外设配置通路
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

AXI-to-APB 桥接器将 AXI4-Lite 总线事务转换为 APB（Advanced Peripheral Bus）事务。AXI 侧支持突发传输（桥接器拆分为单次传输），APB 侧按标准 APB 时序输出。用于 SoC 中高速互联到低速外设（UART、SPI、I2C、GPIO、Timer）的接口转换。

```
CPU (AXI4-Lite Master) ──AXI4-Lite──> ┌─────────────────┐ ──APB──> UART
                                       │ bridge_axi_to_apb│ ──APB──> SPI
                                       └─────────────────┘ ──APB──> Timer
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `AXI_ADDR_WIDTH` | parameter | 32 | AXI 地址位宽 |
| `AXI_DATA_WIDTH` | parameter | 32 | AXI 数据位宽 |
| `APB_ADDR_WIDTH` | parameter | 16 | APB 地址位宽 |
| `APB_DATA_WIDTH` | parameter | 32 | APB 数据位宽 |
| `NUM_APB_SLAVES` | parameter | 4 | APB 从设备数量 |
| `PIPE_EN` | parameter | 0 | 输出流水线使能 |

---

## 接口

### AXI4-Lite Slave 侧

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `s_axi_awaddr` | I | `AXI_ADDR_WIDTH` | clk | 写地址 |
| `s_axi_awvalid` | I | 1 | clk | 写地址有效 |
| `s_axi_awready` | O | 1 | clk | 写地址就绪 |
| `s_axi_wdata` | I | `AXI_DATA_WIDTH` | clk | 写数据 |
| `s_axi_wstrb` | I | `AXI_DATA_WIDTH/8` | clk | 写字节使能 |
| `s_axi_wvalid` | I | 1 | clk | 写数据有效 |
| `s_axi_wready` | O | 1 | clk | 写数据就绪 |
| `s_axi_bresp` | O | 2 | clk | 写响应 |
| `s_axi_bvalid` | O | 1 | clk | 写响应有效 |
| `s_axi_bready` | I | 1 | clk | 写响应就绪 |
| `s_axi_araddr` | I | `AXI_ADDR_WIDTH` | clk | 读地址 |
| `s_axi_arvalid` | I | 1 | clk | 读地址有效 |
| `s_axi_arready` | O | 1 | clk | 读地址就绪 |
| `s_axi_rdata` | O | `AXI_DATA_WIDTH` | clk | 读数据 |
| `s_axi_rresp` | O | 2 | clk | 读响应 |
| `s_axi_rvalid` | O | 1 | clk | 读响应有效 |
| `s_axi_rready` | I | 1 | clk | 读响应就绪 |

### APB Master 侧

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `apb_paddr` | O | `APB_ADDR_WIDTH` | clk | APB 地址 |
| `apb_pwrite` | O | 1 | clk | APB 写使能 |
| `apb_psel` | O | `NUM_APB_SLAVES` | clk | APB 从设备选择 |
| `apb_penable` | O | 1 | clk | APB 使能 |
| `apb_pwdata` | O | `APB_DATA_WIDTH` | clk | APB 写数据 |
| `apb_pstrb` | O | `APB_DATA_WIDTH/8` | clk | APB 字节使能 |
| `apb_prdata` | I | `NUM_APB_SLAVES × APB_DATA_WIDTH` | clk | APB 读数据 |
| `apb_pready` | I | `NUM_APB_SLAVES` | clk | APB 就绪 |
| `apb_pslverr` | I | `NUM_APB_SLAVES` | clk | APB 从设备错误 |

---

## 时序

### 写事务（AXI → APB，3 周期 APB）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
AXI aw/v    ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___________
AXI w/v     ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___________
AXI aw/r    _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
APB PSEL    _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (SETUP)
APB PENABLE _______________________|‾‾‾‾‾‾‾‾|_  (ACCESS)
APB PADDR   _________________|ADDR__________|_
APB PWDATA  _________________|DATA__________|_
APB PREADY  _________________________|‾‾‾‾‾‾|_
AXI b/v     _______________________________|‾|_
              ↑ AXI 握手 → APB SETUP → APB ACCESS → 完成
```

### 读事务（AXI → APB）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
AXI ar/v    ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___________
AXI ar/r    _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
APB PSEL    _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾|_
APB PENABLE _______________________|‾‾‾‾‾‾‾‾|_
APB PRDATA  _______________________|RDATA____|
APB PREADY  _____________________________|‾‾‾|
AXI r/v     _________________________________|‾
AXI RDATA   _________________________________|D|
```

---

## 用法

### 外设配置总线

```verilog
bridge_axi_to_apb #(
    .AXI_ADDR_WIDTH  (32),
    .AXI_DATA_WIDTH  (32),
    .APB_ADDR_WIDTH  (16),
    .APB_DATA_WIDTH  (32),
    .NUM_APB_SLAVES  (4)
) u_apb_bridge (
    .clk   (clk),
    .rst_n (rst_n),
    // AXI4-Lite Slave
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),
    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),
    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),
    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready),
    // APB Master
    .apb_paddr   (paddr),
    .apb_pwrite  (pwrite),
    .apb_psel    (psel),
    .apb_penable (penable),
    .apb_pwdata  (pwdata),
    .apb_pstrb   (pstrb),
    .apb_prdata  ({timer_rdata, i2c_rdata, spi_rdata, uart_rdata}),
    .apb_pready  ({timer_pready, i2c_pready, spi_pready, uart_pready}),
    .apb_pslverr ({timer_err, i2c_err, spi_err, uart_err})
);
```

---

## 关键实现细节

- **地址解码**：AXI 地址高位选择 APB 从设备，低位映射为 APB 地址
- **APB 状态机**：IDLE → SETUP（PSEL=1, PENABLE=0）→ ACCESS（PSEL=1, PENABLE=1）→ 完成
- **写事务**：AXI AW/W 并行握手 → 进入 APB 写 → APB PREADY → 返回 AXI B
- **读事务**：AXI AR 握手 → 进入 APB 读 → APB PRDATA/PREADY → 返回 AXI R
- **响应码映射**：APB PSLVERR → AXI DECERR (2'b11)，否则 OKAY (2'b00)
- **无缓冲**：每次只能处理一个 AXI 事务（AW 或 AR），不支持 outstanding
- **wstrb 映射**：AXI wstrb 直接映射为 APB PSTRB
- **延迟**：写 3 cycle，读 3 cycle（不含 AXI 握手等待）
- **面积**：状态机 + 地址解码 + 数据 MUX，约 1-2K GE
