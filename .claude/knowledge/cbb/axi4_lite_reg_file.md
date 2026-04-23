# axi4_lite_reg_file — AXI4-Lite 寄存器文件

> **用途**：AXI4-Lite 从接口寄存器文件，CPU 可通过总线读写配置寄存器
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

AXI4-Lite 寄存器文件提供标准 AXI4-Lite 从接口，CPU 通过 AXI 总线对内部寄存器进行读写访问。支持软件可读写（RW）、只读（RO）、写 1 清零（W1C）等常见寄存器类型。用于 SoC 配置空间、外设控制寄存器、状态查询等场景。

```
CPU (AXI4-Lite Master) ──AXI4-Lite──> ┌──────────────────┐ ──reg_out[N:0]──> 功能逻辑
                                       │ axi4_lite_reg_file│
                                       │ (REG_COUNT × 32b) │ <──reg_in[N:0]── 状态反馈
                                       └──────────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `REG_COUNT` | parameter | 16 | 寄存器数量 |
| `ADDR_WIDTH` | parameter | 6 | 地址位宽（≥ $clog2(REG_COUNT*4)） |
| `BASE_ADDR` | parameter | 0 | 基地址（用于地址偏移计算） |
| `REG_TYPE` | parameter | `"RW"` | 每个寄存器的类型：`"RW"` / `"RO"` / `"W1C"` |

---

## 接口

### AXI4-Lite 从接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `awaddr` | I | `ADDR_WIDTH` | clk | 写地址 |
| `awvalid` | I | 1 | clk | 写地址有效 |
| `awready` | O | 1 | clk | 写地址就绪 |
| `wdata` | I | 32 | clk | 写数据 |
| `wstrb` | I | 4 | clk | 写字节使能 |
| `wvalid` | I | 1 | clk | 写数据有效 |
| `wready` | O | 1 | clk | 写数据就绪 |
| `bresp` | O | 2 | clk | 写响应 |
| `bvalid` | O | 1 | clk | 写响应有效 |
| `bready` | I | 1 | clk | 写响应就绪 |
| `araddr` | I | `ADDR_WIDTH` | clk | 读地址 |
| `arvalid` | I | 1 | clk | 读地址有效 |
| `arready` | O | 1 | clk | 读地址就绪 |
| `rdata` | O | 32 | clk | 读数据 |
| `rresp` | O | 2 | clk | 读响应 |
| `rvalid` | O | 1 | clk | 读响应有效 |
| `rready` | I | 1 | clk | 读响应就绪 |

### 寄存器接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `reg_out` | O | `REG_COUNT×32` | clk | 寄存器输出值（连接功能逻辑） |
| `reg_in` | I | `REG_COUNT×32` | clk | 寄存器输入值（RO/W1C 类型的状态反馈） |
| `reg_wr_strobe` | O | `REG_COUNT` | clk | 寄存器写入脉冲（每个寄存器一个） |

---

## 时序

### 写事务（2 周期完成）

```
clk      __|‾|__|‾|__|‾|__|‾|__|‾|__
awaddr   ___| ADDR          |________
awvalid  ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________
awready  _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
wdata    ___| DATA          |________
wstrb    ___| 4'b1111      |________
wvalid   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________
wready   _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
bresp    _____________________|OKAY|__
bvalid   _____________________|‾‾‾‾|__
bready   _________________________|‾‾‾|
```

### 读事务（2 周期完成）

```
clk      __|‾|__|‾|__|‾|__|‾|__
araddr   ___| ADDR    |________
arvalid  ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
arready  _________|‾‾‾‾‾‾‾‾‾‾‾|___
rdata    _______________| DATA  |___
rresp    _______________| OKAY  |___
rvalid   _______________|‾‾‾‾‾‾|___
rready   _________________|‾‾‾‾‾‾‾‾|
```

---

## 用法

### 基本配置寄存器

```verilog
axi4_lite_reg_file #(
    .REG_COUNT  (8),
    .ADDR_WIDTH (5)
) u_cfg_regs (
    .clk   (clk),
    .rst_n (rst_n),
    // AXI4-Lite
    .awaddr  (s_axi_awaddr[4:0]),
    .awvalid (s_axi_awvalid),
    .awready (s_axi_awready),
    .wdata   (s_axi_wdata),
    .wstrb   (s_axi_wstrb),
    .wvalid  (s_axi_wvalid),
    .wready  (s_axi_wready),
    .bresp   (s_axi_bresp),
    .bvalid  (s_axi_bvalid),
    .bready  (s_axi_bready),
    .araddr  (s_axi_araddr[4:0]),
    .arvalid (s_axi_arvalid),
    .arready (s_axi_arready),
    .rdata   (s_axi_rdata),
    .rresp   (s_axi_rresp),
    .rvalid  (s_axi_rvalid),
    .rready  (s_axi_rready),
    // 寄存器接口
    .reg_out      ({ctrl_reg3, ctrl_reg2, ctrl_reg1, ctrl_reg0}),
    .reg_in       ({status_reg3, status_reg2, status_reg1, status_reg0}),
    .reg_wr_strobe()
);
```

### 混合 RW / RO / W1C 寄存器

```verilog
// 配置：REG_TYPE[0]="RW", REG_TYPE[1]="RW", REG_TYPE[2]="RO", REG_TYPE[3]="W1C"
// REG[0]：控制寄存器（软件可写）
// REG[1]：配置寄存器（软件可写）
// REG[2]：状态寄存器（只读，硬件写入）
// REG[3]：中断状态（写 1 清零）

assign reg_in_vec[2*32+:32] = hw_status;       // RO 寄存器值由硬件提供
assign irq_clear = reg_wr_strobe[3];            // W1C 写入时产生清零脉冲
```

---

## 关键实现细节

- **写地址/数据并行**：awready 和 wready 同时拉高，简化握手逻辑
- **字节使能**：wstrb 控制每个字节的写入，支持 8/16/32 位写入
- **地址对齐**：地址按 4 字节对齐，`reg_idx = (addr - BASE_ADDR) >> 2`
- **响应码**：OKAY=2'b00，DECERR=2'b11（地址越界时返回）
- **RO 寄存器**：写操作被忽略，读操作返回 reg_in 值
- **W1C 寄存器**：写 1 对应位清零，写 0 保持不变
- **面积**：REG_COUNT × 32 个触发器 + AXI 握手逻辑
