# uart_reg_mod 微架构规格书

> 基于 `uart_FS_v1.0.md` §5.1 编写。APB 从接口模块，负责地址解码和寄存器读写。编码规范遵循 `rules/coding-style.md`。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块/子模块** | `uart` / `uart_reg_mod` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-MA-uart_reg_mod-v1.0` |
| **对应 FS** | `uart_FS_v1.0.md` §5.1 |
| **作者/日期/审核** | `AI Agent` / `2026-04-27` / `{reviewer}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本 |

---

## 3. 子模块概述

### 3.1 功能定位

`uart_reg_mod` 是 APB 从接口模块，负责地址解码和寄存器读写。将 APB 总线事务转换为内部寄存器访问信号，支持 16550 兼容的寄存器布局。本模块仅包含配置寄存器读写逻辑，不承载任何功能逻辑。

**从 FS 继承的需求**：

| 需求 ID | 需求描述 | FS 章节 |
|---------|----------|---------|
| REQ-009 | APB 从接口 32 位 | FS §5.1, §6.2 |
| REQ-004 | 可编程波特率（DLL/DLH） | FS §7.2 |

### 3.2 与上级/兄弟模块的关系

| 邻接模块 | 接口方向 | 接口名称 | 说明 |
|----------|----------|----------|------|
| APB Master | 输入 | APB 总线信号 | APB3 从接口 |
| uart_baud_gen | 输出 | `baud_div_int`, `baud_div_frac`, `oversample_sel` | 波特率配置 |
| uart_tx | 输出 | `data_bits`, `stop_bits`, `parity_en`, `parity_even` | 帧格式配置 |
| uart_rx | 输出 | `data_bits`, `stop_bits`, `parity_en`, `parity_even` | 帧格式配置 |
| uart_ctrl | 输出 | `ier`, `mcr_loop`, `mcr_afe`, `fcr_*` | 控制配置 |
| uart_fifo(TX) | 输出 | `tx_fifo_rst` | TX FIFO 复位 |
| uart_fifo(RX) | 输出 | `rx_fifo_rst` | RX FIFO 复位 |
| 各功能模块 | 输入 | `reg_rd_data` | 读数据返回 |

### 3.3 内部框图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 内部结构图（`wd_uart_reg_mod_arch.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![uart_reg_mod 内部框图](wd_uart_reg_mod_arch.png)
```

> **图片说明**：本图展示 uart_reg_mod 的内部架构，包含以下核心组件：
> - APB 从接口：处理 PSEL/PENABLE/PREADY 握手时序
> - 地址解码器：将 PADDR 映射到具体寄存器偏移
> - 寄存器阵列：IER、LCR、MCR、SCR、DLL、DLH、FCR_EXT 等配置寄存器
> - DLAB 控制：根据 LCR.DLAB 位选择访问 RBR/THR 或 DLL/DLH
> - 寄存器读写接口：reg_wr_en/reg_rd_en/reg_addr/reg_wr_data 输出到各功能模块
> - 读数据 mux：从各功能模块返回的 reg_rd_data 多路选择

---

## 4. 接口定义

### 4.1 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟（50 MHz） |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `paddr` | I | ADDR_WIDTH | wire | clk | - | APB 地址总线 |
| 4 | `psel` | I | 1 | wire | clk | - | APB 选择信号 |
| 5 | `penable` | I | 1 | wire | clk | - | APB 使能信号 |
| 6 | `pwrite` | I | 1 | wire | clk | - | APB 写使能 |
| 7 | `pwdata` | I | DATA_WIDTH | wire | clk | - | APB 写数据 |
| 8 | `prdata` | O | DATA_WIDTH | reg | clk | 0 | APB 读数据 |
| 9 | `pready` | O | 1 | reg | clk | 1 | APB 就绪信号 |
| 10 | `pslverr` | O | 1 | reg | clk | 0 | APB 错误信号 |
| 11 | `reg_wr_en` | O | 1 | reg | clk | 0 | 寄存器写使能 |
| 12 | `reg_rd_en` | O | 1 | reg | clk | 0 | 寄存器读使能 |
| 13 | `reg_addr` | O | ADDR_WIDTH | reg | clk | 0 | 寄存器地址 |
| 14 | `reg_wr_data` | O | DATA_WIDTH | reg | clk | 0 | 写数据 |
| 15 | `reg_rd_data` | I | DATA_WIDTH | wire | clk | - | 读数据（各功能模块返回） |
| 16 | `dlab` | O | 1 | reg | clk | 0 | DLAB 位，控制 DLL/DLH 访问 |
| 17 | `ier` | O | 4 | reg | clk | 0 | 中断使能寄存器 |
| 18 | `lcr` | O | 8 | reg | clk | 0 | 线路控制寄存器 |
| 19 | `mcr` | O | 6 | reg | clk | 0 | 调制解调器控制寄存器 |
| 20 | `fcr` | O | 8 | reg | clk | 0 | FIFO 控制寄存器（写入后清零） |
| 21 | `dll` | O | 8 | reg | clk | 0 | 波特率分频低字节 |
| 22 | `dlh` | O | 8 | reg | clk | 0 | 波特率分频高字节 |
| 23 | `fcr_ext` | O | 8 | reg | clk | 0 | 扩展 FIFO 控制 |
| 24 | `scr` | O | 8 | reg | clk | 0 | 暂存寄存器 |

**参数定义**：

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `ADDR_WIDTH` | 5 | APB 地址宽度 |
| `DATA_WIDTH` | 32 | APB 数据宽度 |

**与 FS 接口映射**：

| 本模块端口 | FS 接口 | FS 信号名 | 映射说明 |
|------------|---------|-----------|----------|
| `paddr` | FS §6.2 | `paddr` | 直连 |
| `psel` | FS §6.2 | `psel` | 直连 |
| `penable` | FS §6.2 | `penable` | 直连 |
| `pwrite` | FS §6.2 | `pwrite` | 直连 |
| `pwdata` | FS §6.2 | `pwdata` | 直连 |
| `prdata` | FS §6.2 | `prdata` | 直连 |
| `pready` | FS §6.2 | `pready` | 直连 |
| `pslverr` | FS §6.2 | `pslverr` | 直连 |

### 4.2 接口协议与时序

**协议类型**：APB3（PSEL → PENABLE → PREADY 握手）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_apb_write.json`），编译为 PNG。

```markdown
![APB 写事务时序](wd_apb_write.png)
```

> **图片说明**：本图展示 APB 写事务时序，包含 Setup 和 Access 两个阶段：
> - Setup 阶段（T1）：PSEL 拉高，PADDR/PWDATA/PWRITE 有效
> - Access 阶段（T2）：PENABLE 拉高，PREADY 拉高完成写操作
> - 写操作在 PENABLE && PREADY && PWRITE 的上升沿生效

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_apb_read.json`），编译为 PNG。

```markdown
![APB 读事务时序](wd_apb_read.png)
```

> **图片说明**：本图展示 APB 读事务时序：
> - Setup 阶段（T1）：PSEL 拉高，PADDR/PWRITE 有效
> - Access 阶段（T2）：PENABLE 拉高，PREADY 拉高，PRDATA 输出有效数据
> - 读数据在 PENABLE && PREADY && !PWRITE 的上升沿采样

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| 输入 setup | ≤ 10 | ns | 相对 clk 上升沿（50 MHz 下 20 ns 周期） |
| 输出 delay | ≤ 5 | ns | clk 到 PRDATA/PREADY 有效 |
| 握手响应 | 1 | cycles | PENABLE 到 PREADY 固定 1 cycle |
| PREADY 默认值 | 1 | - | 无等待状态，单周期访问 |

---

## 5. 微架构设计

### 5.1 数据通路

#### 数据流图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 数据通路图（`wd_uart_reg_mod_datapath.d2`），从输入到输出的完整路径。

```markdown
![uart_reg_mod 数据通路](wd_uart_reg_mod_datapath.png)
```

> **图片说明**：本图展示 uart_reg_mod 的数据通路，分为写路径和读路径：
> - 写路径：APB pwdata → 地址解码 → 寄存器写入 → reg_wr_data 输出到功能模块
> - 读路径：各功能模块 reg_rd_data → 多路 mux → APB prdata 输出
> - DLAB 控制：根据 LCR.DLAB 选择访问 RBR/THR（DLAB=0）或 DLL/DLH（DLAB=1）

#### APB 写路径

| 阶段 | 数据名 | 位宽 | 格式说明 | 组合/时序 |
|------|--------|------|----------|-----------|
| 输入 | `pwdata` | 32 | APB 写数据 | - |
| 解码 | `reg_addr` | 5 | 寄存器地址 | 组合 |
| 写入 | `reg_wr_data` | 32 | 写数据 | 时序 |
| 输出 | `reg_wr_en` | 1 | 写使能 | 时序 |

#### APB 读路径

| 阶段 | 数据名 | 位宽 | 格式说明 | 组合/时序 |
|------|--------|------|----------|-----------|
| 输入 | `reg_rd_data` | 32 | 各功能模块读数据 | - |
| Mux | `prdata_mux` | 32 | 多路选择 | 组合 |
| 输出 | `prdata` | 32 | APB 读数据 | 时序 |

#### 关键数据路径

| 路径 ID | 起点 | 终点 | 组合逻辑级数 | 预估延迟 | 关键路径 |
|---------|------|------|-------------|----------|----------|
| DP-001 | `paddr` | `reg_addr` | 1 级 | 0.2 ns | 否 |
| DP-002 | `reg_rd_data` | `prdata` | 2 级 | 0.4 ns | 是 |

---

### 5.2 控制逻辑

#### 控制信号列表

| 控制信号 | 位宽 | 产生源 | 功能描述 |
|----------|------|--------|----------|
| `reg_wr_en` | 1 | APB 写逻辑 | 寄存器写使能 |
| `reg_rd_en` | 1 | APB 读逻辑 | 寄存器读使能 |
| `reg_addr` | 5 | 地址解码 | 寄存器地址 |
| `dlab` | 1 | LCR[7] | DLAB 位 |
| `pslverr` | 1 | 地址越界检测 | APB 错误信号 |

#### 寄存器读写接口定义

```verilog
// 寄存器模块 → 功能模块（单向广播）
output reg                   reg_wr_en,      // 寄存器写使能
output reg                   reg_rd_en,      // 寄存器读使能
output reg  [ADDR_WIDTH-1:0] reg_addr,       // 寄存器地址
output reg  [DATA_WIDTH-1:0] reg_wr_data,    // 写数据
input  wire [DATA_WIDTH-1:0] reg_rd_data,    // 各功能模块返回的读数据（多路 mux）
```

#### 地址解码逻辑

| PADDR[4:0] | 寄存器 | DLAB | 访问类型 | 功能模块 |
|------------|--------|------|----------|----------|
| 5'h00 | RBR/THR | 0 | RO/WO | uart_rx/uart_tx |
| 5'h04 | IER | 0 | RW | uart_ctrl |
| 5'h08 | IIR/FCR | 0 | RO/WO | uart_ctrl |
| 5'h0C | LCR | 0 | RW | uart_reg_mod |
| 5'h10 | MCR | 0 | RW | uart_reg_mod |
| 5'h14 | LSR | 0 | RO | uart_ctrl |
| 5'h18 | MSR | 0 | RO | uart_ctrl |
| 5'h1C | SCR | 0 | RW | uart_reg_mod |
| 5'h20 | DLL | 1 | RW | uart_reg_mod |
| 5'h24 | DLH | 1 | RW | uart_reg_mod |
| 5'h28 | FCR_EXT | 0 | RW | uart_reg_mod |

#### 寄存器归属判定

| 寄存器类型 | 归属 | 示例 |
|-----------|------|------|
| 纯控制/使能寄存器 | 寄存器模块 | IER、LCR、MCR、SCR、DLL、DLH、FCR_EXT |
| 中断状态（W1C） | 寄存器模块 | 无（LSR/MSR 由 uart_ctrl 产生） |
| 功能配置表项 | 功能模块 | 无 |
| 状态只读寄存器 | 寄存器模块（读接口）+ 功能模块（值产生） | LSR、MSR、IIR |
| FIFO 控制 | 寄存器模块 | FCR（写入后清零） |

---

### 5.3 状态机设计

本子模块无状态机设计。寄存器模块为纯组合+寄存器逻辑，无状态转移。

---

### 5.4 流水线设计

本子模块无流水线设计。APB 读写操作为单周期完成。

---

### 5.5 FIFO / 缓冲设计

本子模块无 FIFO 设计。

---

### 5.6 寄存器分配表

| 偏移地址 | 寄存器名 | 归属模块 | 访问类型 | 复位值 | 说明 |
|----------|----------|----------|----------|--------|------|
| 0x00 | RBR | uart_rx | RO | 0x00 | 接收缓冲（DLAB=0） |
| 0x00 | THR | uart_tx | WO | - | 发送保持（DLAB=0） |
| 0x04 | IER | uart_reg_mod | RW | 0x00 | 中断使能 |
| 0x08 | IIR | uart_ctrl | RO | 0xC1 | 中断标识 |
| 0x08 | FCR | uart_reg_mod | WO | - | FIFO 控制 |
| 0x0C | LCR | uart_reg_mod | RW | 0x00 | 线路控制 |
| 0x10 | MCR | uart_reg_mod | RW | 0x00 | 调制解调器控制 |
| 0x14 | LSR | uart_ctrl | RO | 0x60 | 线路状态 |
| 0x18 | MSR | uart_ctrl | RO | 0x00 | 调制解调器状态 |
| 0x1C | SCR | uart_reg_mod | RW | 0x00 | 暂存寄存器 |
| 0x20 | DLL | uart_reg_mod | RW | 0x00 | 波特率分频低（DLAB=1） |
| 0x24 | DLH | uart_reg_mod | RW | 0x00 | 波特率分频高（DLAB=1） |
| 0x28 | FCR_EXT | uart_reg_mod | RW | 0x00 | 扩展 FIFO 控制 |

---

## 6. 关键时序分析

### 关键路径

| 路径 ID | 起点 | 组合逻辑 | 级数 | 预估延迟 |
|---------|------|----------|------|----------|
| CP-001 | `paddr` 寄存器 | 地址解码 + DLAB 判断 | 2 级 | 0.4 ns |
| CP-002 | `reg_rd_data` | 多路 mux + prdata 输出 | 2 级 | 0.4 ns |

### 时序裕量

**裕量公式**：`Tslack = Tclk - Tcq - Tlogic - Tsetup - Tskew`

| 路径 | Tclk | Tlogic | Tslack | 是否满足 |
|------|------|--------|--------|----------|
| CP-001 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |
| CP-002 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |

判断：所有路径 Tslack > 0，满足时序要求。

### SDC 约束建议
```tcl
create_clock -name clk -period 20 [get_ports clk]
set_input_delay  -clock clk -max 5 [get_ports {paddr psel penable pwrite pwdata}]
set_output_delay -clock clk -max 5 [get_ports {prdata pready pslverr}]
set_false_path   -from [get_ports rst_n]
```

---

## 7. 时钟与复位

### 时钟域归属

| 信号 | 时钟域 | 说明 |
|------|--------|------|
| 所有信号 | clk | 主时钟域，无跨时钟域信号 |

### 复位策略

异步复位同步释放，低有效 `rst_n`，2 级同步器。

复位时：
- prdata = 0
- pready = 1
- pslverr = 0
- reg_wr_en = 0
- reg_rd_en = 0
- reg_addr = 0
- reg_wr_data = 0
- dlab = 0
- ier = 0
- lcr = 0
- mcr = 0
- fcr = 0
- dll = 0
- dlh = 0
- fcr_ext = 0
- scr = 0

### CDC 处理

本子模块无 CDC 信号，所有信号在同一时钟域内。

---

## 8. PPA 预估

### 逻辑面积

| 组成 | 预估(kGates) | 计算依据 |
|------|-------------|----------|
| APB 接口逻辑 | 0.2 | 握手 + 错误检测 |
| 地址解码 | 0.1 | 5 bit 地址比较 |
| 寄存器阵列 | 0.5 | IER(4)+LCR(8)+MCR(6)+SCR(8)+DLL(8)+DLH(8)+FCR_EXT(8) = 50 bit × 6 GE |
| 读数据 mux | 0.1 | 11 路 32 bit mux |
| 控制逻辑 | 0.1 | DLAB + 写使能 |
| **合计** | **1.0** | |

### 功耗预估（PVT：`TT` / `1.0V` / `25°C` / `50MHz`）

| 指标 | 预估 | 单位 | 依据 |
|------|------|------|------|
| 动态功耗 | 0.3 | mW | α×C×V²×f，低翻转率 |
| 静态功耗 | 0.1 | mW | 漏电×V |
| **合计** | **0.4** | **mW** | |

### 关键路径 Fmax

| 路径 | 延迟 | Fmax |
|------|------|------|
| **最差路径** | 0.4 ns | ≥ 500 MHz |

---

## 9. RTL 实现指导

### 文件结构
```
uart_reg_mod.v           — 主模块 RTL
uart_reg_mod_sva.sv      — SVA 断言
uart_reg_mod_tb.v        — 仿真 testbench
```

### 参数化
- `ADDR_WIDTH`：APB 地址宽度，默认 5
- `DATA_WIDTH`：APB 数据宽度，默认 32

### 编码规范

遵循 `rules/coding-style.md`。本子模块在 RTL 实现阶段需特别关注以下高风险项：

| 高风险项 | 关注点 |
|----------|--------|
| 组合逻辑 latch 防护 | always @(*) 输出默认值、if 补 else、case 有 default |
| DLAB 控制 | DLAB=0 时访问 RBR/THR/IER，DLAB=1 时访问 DLL/DLH |
| 地址越界 | PADDR 超出范围时 PSLVERR 拉高 |
| FCR 写入后清零 | FCR 为 WO 寄存器，写入后自动清零 |

### RTL 伪代码框架

```verilog
module uart_reg_mod #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // APB 接口
    input  wire [ADDR_WIDTH-1:0] paddr,
    input  wire                  psel,
    input  wire                  penable,
    input  wire                  pwrite,
    input  wire [DATA_WIDTH-1:0] pwdata,
    output reg  [DATA_WIDTH-1:0] prdata,
    output reg                   pready,
    output reg                   pslverr,
    // 寄存器读写接口
    output reg                   reg_wr_en,
    output reg                   reg_rd_en,
    output reg  [ADDR_WIDTH-1:0] reg_addr,
    output reg  [DATA_WIDTH-1:0] reg_wr_data,
    input  wire [DATA_WIDTH-1:0] reg_rd_data,
    // 配置输出
    output reg                   dlab,
    output reg  [3:0]            ier,
    output reg  [7:0]            lcr,
    output reg  [5:0]            mcr,
    output reg  [7:0]            fcr,
    output reg  [7:0]            dll,
    output reg  [7:0]            dlh,
    output reg  [7:0]            fcr_ext,
    output reg  [7:0]            scr
);

// APB 写操作
wire apb_wr = psel && penable && pwrite && pready;
wire apb_rd = psel && penable && !pwrite && pready;

// 地址解码
wire addr_valid = (paddr <= 5'h28);

// APB 写逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_wr_en   <= 0;
        reg_addr    <= 0;
        reg_wr_data <= 0;
        dlab        <= 0;
        ier         <= 0;
        lcr         <= 0;
        mcr         <= 0;
        fcr         <= 0;
        dll         <= 0;
        dlh         <= 0;
        fcr_ext     <= 0;
        scr         <= 0;
    end else begin
        reg_wr_en <= 0;
        fcr       <= 0; // FCR 写入后清零
        if (apb_wr && addr_valid) begin
            reg_wr_en   <= 1;
            reg_addr    <= paddr;
            reg_wr_data <= pwdata;
            case (paddr)
                5'h00: if (!dlab) ; // THR，由 uart_tx 处理
                5'h04: if (!dlab) ier <= pwdata[3:0];
                5'h08: if (!dlab) fcr <= pwdata[7:0]; // FCR WO
                5'h0C: lcr <= pwdata[7:0];
                5'h10: mcr <= pwdata[5:0];
                5'h1C: scr <= pwdata[7:0];
                5'h20: if (dlab) dll <= pwdata[7:0];
                5'h24: if (dlab) dlh <= pwdata[7:0];
                5'h28: fcr_ext <= pwdata[7:0];
                default: ;
            endcase
        end
        // DLAB 由 LCR[7] 控制
        dlab <= lcr[7];
    end
end

// APB 读逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_rd_en <= 0;
        prdata    <= 0;
        pready    <= 1;
        pslverr   <= 0;
    end else begin
        reg_rd_en <= 0;
        pslverr   <= 0;
        if (apb_rd) begin
            if (addr_valid) begin
                reg_rd_en <= 1;
                reg_addr  <= paddr;
                prdata    <= reg_rd_data; // 从功能模块返回
            end else begin
                pslverr <= 1;
                prdata  <= 0;
            end
        end
    end
end

// PREADY 固定为 1（无等待状态）
always @(*) pready = 1;

endmodule
```

### 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "DLAB 不用特殊处理" | DLAB 控制 DLL/DLH 访问，必须正确实现 |
| "地址越界不用管" | 必须产生 PSLVERR，否则 APB 总线行为未定义 |
| "FCR 不用清零" | FCR 是 WO 寄存器，写入后必须清零 |
| "读数据直接用 case" | 需要多路 mux 从各功能模块返回 |

---

## 10. 验证要点

### 关键验证场景

| 场景 ID | 描述 | 覆盖需求 | 方法 | 优先级 |
|---------|------|----------|------|--------|
| VS-001 | APB 写所有寄存器 | REQ-009 | 功能仿真 | High |
| VS-002 | APB 读所有寄存器 | REQ-009 | 功能仿真 | High |
| VS-003 | DLAB 控制 | REQ-004 | 功能仿真 | High |
| VS-004 | 地址越界 | REQ-009 | 功能仿真 | Medium |
| VS-005 | FCR 写入后清零 | REQ-009 | 功能仿真 | Medium |

### SVA 断言要点
- APB 握手：`psel && penable |=> pready`（单周期响应）
- DLAB 控制：`lcr[7] |-> dlab`
- 地址越界：`paddr > 5'h28 && apb_rd |=> pslverr`

### 覆盖率模型

| 覆盖组 | 覆盖点 | 目标 |
|--------|--------|------|
| 寄存器访问 | 所有寄存器读写 | 100% |
| DLAB 状态 | DLAB=0/1 | 100% |
| 地址范围 | 有效/越界 | 100% |

---

## 11. 风险与缓解

### 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | DLAB 控制错误 | 功能 | L | 严格按 16550 规范实现 |
| R-002 | 地址越界未处理 | 功能 | L | 产生 PSLVERR |

### 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | 寄存器读写覆盖不全 | 遍历所有寄存器 |

---

## 12. 架构决策记录

无。

---

## 13. 附录

### 需求追溯矩阵（RTM）

| 需求 ID | FS 章节 | 微架构章节 | 实现方式 | 验证场景 | 状态 |
|---------|---------|-----------|----------|----------|------|
| REQ-009 | FS §5.1 | §5.1 数据通路 | APB3 从接口 | VS-001/002/003/004 | Designed |
| REQ-004 | FS §7.2 | §5.6 寄存器分配 | DLL/DLH 寄存器 | VS-003 | Designed |

### 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_FS_v1.0.md` | 功能规格书 |
| REF-002 | `rules/coding-style.md` | RTL 编码规范 |
| REF-003 | `APB Protocol Specification` | AMBA APB 协议规范 |

### 缩略语

| 缩写 | 全称 |
|------|------|
| APB | Advanced Peripheral Bus |
| DLAB | Divisor Latch Access Bit |
| IER | Interrupt Enable Register |
| LCR | Line Control Register |
| MCR | Modem Control Register |
| FCR | FIFO Control Register |
| DLL | Divisor Latch Low |
| DLH | Divisor Latch High |
| SCR | Scratch Register |
| PPA | Performance, Power, Area |
| SVA | SystemVerilog Assertion |
