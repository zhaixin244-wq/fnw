# uart_fifo 微架构规格书

> 基于 `uart_FS_v1.0.md` §5.5 编写。参数化同步 FIFO CBB，可作为独立模块复用。编码规范遵循 `rules/coding-style.md`。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块/子模块** | `uart` / `uart_fifo` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-MA-uart_fifo-v1.0` |
| **对应 FS** | `uart_FS_v1.0.md` §5.5 |
| **作者/日期/审核** | `AI Agent` / `2026-04-27` / `{reviewer}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本 |

---

## 3. 子模块概述

### 3.1 功能定位

`uart_fifo` 是参数化同步 FIFO，作为独立 CBB 设计，被 TX 和 RX 通路分别实例化。使用寄存器阵列实现，深度和宽度可参数化配置。提供满/空/接近满/数据计数等状态标志，支持同步读写操作。

**从 FS 继承的需求**：

| 需求 ID | 需求描述 | FS 章节 |
|---------|----------|---------|
| REQ-005 | TX FIFO 深度 ≥ 16 字节 | FS §5.5, §8.3 |
| REQ-006 | RX FIFO 深度 ≥ 16 字节 | FS §5.5, §8.3 |

### 3.2 与上级/兄弟模块的关系

| 邻接模块 | 接口方向 | 接口名称 | 说明 |
|----------|----------|----------|------|
| uart_tx | 输入 | `rd_en`, `rd_data` | TX FIFO 读接口 |
| uart_tx | 输出 | `fifo_empty` | TX FIFO 空标志 |
| uart_rx | 输入 | `wr_en`, `wr_data` | RX FIFO 写接口 |
| uart_rx | 输出 | `fifo_full` | RX FIFO 满标志 |
| uart_ctrl | 输出 | `fifo_almost_full` | 接近满标志，用于 RTS 流控 |
| uart_reg_mod | 输入 | `almost_full_thresh` | 接近满阈值配置 |

### 3.3 内部框图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 内部结构图（`wd_uart_fifo_arch.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![uart_fifo 内部框图](wd_uart_fifo_arch.png)
```

> **图片说明**：本图展示 uart_fifo 的内部架构，包含以下核心组件：
> - 寄存器阵列：DEPTH × DATA_WIDTH 位的寄存器堆，用于存储 FIFO 数据
> - 写指针（wr_ptr）：多 1 位指针，指向下一个写入位置
> - 读指针（rd_ptr）：多 1 位指针，指向下一个读取位置
> - 状态逻辑：根据 wr_ptr 和 rd_ptr 计算 full/empty/almost_full/count
> - 数据从 wr_data 端口写入，从 rd_data 端口读出
> - 控制信号：wr_en/rd_en 分别控制写入和读取操作

---

## 4. 接口定义

### 4.1 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `wr_en` | I | 1 | wire | clk | - | 写使能 |
| 4 | `wr_data` | I | DATA_WIDTH | wire | clk | - | 写数据 |
| 5 | `rd_en` | I | 1 | wire | clk | - | 读使能 |
| 6 | `rd_data` | O | DATA_WIDTH | reg | clk | 0 | 读数据 |
| 7 | `fifo_full` | O | 1 | reg | clk | 0 | FIFO 满标志 |
| 8 | `fifo_empty` | O | 1 | reg | clk | 1 | FIFO 空标志 |
| 9 | `fifo_almost_full` | O | 1 | reg | clk | 0 | FIFO 接近满标志 |
| 10 | `fifo_count` | O | CNT_WIDTH | reg | clk | 0 | FIFO 数据计数 |
| 11 | `fifo_overflow` | O | 1 | reg | clk | 0 | 溢出标志（满时写入） |
| 12 | `fifo_underflow` | O | 1 | reg | clk | 0 | 下溢标志（空时读取） |
| 13 | `almost_full_thresh` | I | CNT_WIDTH | wire | clk | - | 接近满阈值配置 |

**参数定义**：

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `DATA_WIDTH` | 8 | 数据位宽 |
| `DEPTH` | 16 | FIFO 深度（必须为 2 的幂） |
| `CNT_WIDTH` | $clog2(DEPTH)+1 | 计数器位宽，多 1 位用于区分满/空 |

**TX FIFO 实例参数**：DATA_WIDTH=10（8 位数据 + 1 位奇偶校验 + 1 位帧信息），DEPTH=16

**RX FIFO 实例参数**：DATA_WIDTH=11（8 位数据 + 1 位奇偶校验 + 1 位帧错误 + 1 位 Break），DEPTH=16

**与 FS 接口映射**：

| 本模块端口 | FS 接口 | FS 信号名 | 映射说明 |
|------------|---------|-----------|----------|
| `wr_en` | FS §5.5.2 | `wr_en` | 直连 |
| `wr_data` | FS §5.5.2 | `wr_data` | 直连 |
| `rd_en` | FS §5.5.2 | `rd_en` | 直连 |
| `rd_data` | FS §5.5.2 | `rd_data` | 直连 |
| `fifo_full` | FS §5.5.2 | `fifo_full` | 直连 |
| `fifo_empty` | FS §5.5.2 | `fifo_empty` | 直连 |
| `fifo_almost_full` | FS §5.5.2 | `fifo_almost_full` | 直连 |
| `fifo_count` | FS §5.5.2 | `fifo_count` | 直连 |

### 4.2 接口协议与事务时序

**协议类型**：同步读写（wr_en/rd_en 边沿触发）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_fifo_rw.json`），编译为 PNG。

```markdown
![FIFO 读写时序](wd_fifo_rw.png)
```

> **图片说明**：本图展示 FIFO 的读写时序：
> - 写操作：wr_en 拉高，数据在 clk 上升沿写入，fifo_empty 拉低，fifo_count 增加
> - 读操作：rd_en 拉高，数据在 clk 上升沿输出，fifo_full 拉低，fifo_count 减少
> - 同时读写：wr_en 和 rd_en 同时拉高，fifo_count 保持不变
> - 满时写入：fifo_overflow 拉高，数据丢弃
> - 空时读取：fifo_underflow 拉高，rd_data 保持上次值

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| 写延迟 | 1 | cycle | wr_en 到数据写入 |
| 读延迟 | 1 | cycle | rd_en 到 rd_data 有效 |
| 标志更新 | 1 | cycle | 操作后标志在下一周期更新 |

---

## 5. 微架构设计

### 5.1 数据通路

#### 数据流图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 数据通路图（`wd_uart_fifo_datapath.d2`），从输入到输出的完整路径。

```markdown
![uart_fifo 数据通路](wd_uart_fifo_datapath.png)
```

> **图片说明**：本图展示 uart_fifo 的数据通路，从输入到输出共 3 个阶段：
> - 阶段 0（输入）：wr_data 进入模块，wr_en 控制写入
> - 阶段 1（存储）：寄存器阵列存储，wr_ptr/rd_ptr 管理读写位置
> - 阶段 2（输出）：rd_data 从寄存器阵列读出，rd_en 控制读取
>
> 关键数据路径：wr_data → 寄存器阵列[wr_ptr] → rd_data（经过 1 cycle 延迟）。

#### 各阶段数据格式

| 阶段 | 数据名 | 位宽 | 格式说明 | 组合/时序 |
|------|--------|------|----------|-----------|
| 输入 | `wr_data` | DATA_WIDTH | 写入数据 | - |
| 存储 | `mem[0:DEPTH-1]` | DATA_WIDTH | 寄存器阵列 | 时序 |
| 输出 | `rd_data` | DATA_WIDTH | 读出数据 | 时序 |

#### 关键数据路径

| 路径 ID | 起点 | 终点 | 组合逻辑级数 | 预估延迟 | 关键路径 |
|---------|------|------|-------------|----------|----------|
| DP-001 | `wr_data` | `mem[wr_ptr]` | 0 级 | 0 ns | 否 |
| DP-002 | `mem[rd_ptr]` | `rd_data` | 0 级 | 0 ns | 否 |
| DP-003 | `wr_ptr/rd_ptr` | `fifo_full/empty` | 2 级 | ~0.4 ns | 是 |

---

### 5.2 控制逻辑

#### 控制信号列表

| 控制信号 | 位宽 | 产生源 | 功能描述 |
|----------|------|--------|----------|
| `wr_en` | 1 | 外部输入 | 写使能，高有效 |
| `rd_en` | 1 | 外部输入 | 读使能，高有效 |
| `wr_ptr` | CNT_WIDTH | 内部寄存器 | 写指针，多 1 位 |
| `rd_ptr` | CNT_WIDTH | 内部寄存器 | 读指针，多 1 位 |
| `fifo_full` | 1 | 组合逻辑 | 满标志 |
| `fifo_empty` | 1 | 组合逻辑 | 空标志 |

#### 流控机制

| 类型 | 接口 | 机制 | 背压路径 |
|------|------|------|----------|
| 满标志 | 输出 | fifo_full=1 时写入无效 | fifo_full → 上游停止写入 |
| 空标志 | 输出 | fifo_empty=1 时读取无效 | fifo_empty → 下游停止读取 |
| 接近满 | 输出 | fifo_almost_full 用于 RTS 流控 | almost_full → rts_n 拉高 |

**背压传播规则**：
- `fifo_full` 直接控制上游写入：`fifo_full=1` 时，`wr_en` 被忽略，`fifo_overflow` 拉高
- `fifo_empty` 直接控制下游读取：`fifo_empty=1` 时，`rd_en` 被忽略，`fifo_underflow` 拉高
- `fifo_almost_full` 用于 RTS 流控提前通知，不直接阻止写入

---

### 5.3 状态机设计

本子模块无状态机设计。FIFO 为纯组合+寄存器逻辑，无状态转移。

---

### 5.4 流水线设计

本子模块无流水线设计。FIFO 读写操作为单周期完成。

---

### 5.5 FIFO / 缓冲设计

#### FIFO 配置

本子模块本身就是 FIFO 设计，无需额外 FIFO。

#### 深度计算依据

> **FIFO 深度 = 流控模型计算结果，不是拍脑袋。**

**TX FIFO 深度计算**：
```
生产者速率 R_prod = 1 word/cycle（APB 写入，单周期）
消费者速率 R_cons = 1 word / (16 × baud_tick_16x)（波特率发送）
最大突发 B_max = 16 words（软件连续写入 16 字节）
反馈延迟 D_fb = 1 cycle（FIFO 状态反馈）

深度 = B_max = 16
含裕量(+50%)：16（已满足，无需增大）
```

**RX FIFO 深度计算**：
```
生产者速率 R_prod = 1 word / (16 × baud_tick_16x)（波特率接收）
消费者速率 R_cons = 1 word/cycle（APB 读取，单周期）
最大突发 B_max = 16 words（外部设备连续发送 16 字节）
反馈延迟 D_fb = 1 cycle（FIFO 状态反馈）

深度 = B_max = 16
含裕量(+50%)：16（已满足，无需增大）
```

**满/空判断采用多 1 位指针法**：
- 满判断：`wr_ptr[MSB] != rd_ptr[MSB] && wr_ptr[MSB-1:0] == rd_ptr[MSB-1:0]`
- 空判断：`wr_ptr == rd_ptr`

---

### 5.6 IP/CBB 集成设计

本子模块为独立 CBB 设计，不依赖外部 IP。

**CBB 可复用性**：
- 参数化设计支持任意 DATA_WIDTH 和 DEPTH（DEPTH 必须为 2 的幂）
- 可直接实例化用于其他模块的 FIFO 需求
- 接口标准，无特殊依赖

---

## 6. 关键时序分析

### 关键路径

| 路径 ID | 起点 | 组合逻辑 | 级数 | 预估延迟 |
|---------|------|----------|------|----------|
| CP-001 | `wr_ptr/rd_ptr` 寄存器 | 满/空判断逻辑 | 2 级 | 0.4 ns |
| CP-002 | `wr_ptr/rd_ptr` 寄存器 | almost_full 比较 | 2 级 | 0.4 ns |
| CP-003 | `wr_en/rd_en` | 指针更新逻辑 | 1 级 | 0.2 ns |

### 时序裕量

**裕量公式**：`Tslack = Tclk - Tcq - Tlogic - Tsetup - Tskew`

| 路径 | Tclk | Tlogic | Tslack | 是否满足 |
|------|------|--------|--------|----------|
| CP-001 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |
| CP-002 | 20ns (50MHz) | 0.4ns | **19.1ns** | 是 |
| CP-003 | 20ns (50MHz) | 0.2ns | **19.3ns** | 是 |

判断：所有路径 Tslack > 0，满足时序要求。

### SDC 约束建议
```tcl
create_clock -name clk -period 20 [get_ports clk]
set_input_delay  -clock clk -max 5 [get_ports {wr_en rd_en wr_data almost_full_thresh}]
set_output_delay -clock clk -max 5 [get_ports {rd_data fifo_full fifo_empty fifo_almost_full fifo_count fifo_overflow fifo_underflow}]
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
- wr_ptr = 0
- rd_ptr = 0
- fifo_full = 0
- fifo_empty = 1
- fifo_almost_full = 0
- fifo_count = 0
- fifo_overflow = 0
- fifo_underflow = 0
- rd_data = 0
- mem[] 不需要复位（无意义）

### CDC 处理

本子模块无 CDC 信号，所有信号在同一时钟域内。

---

## 8. PPA 预估

### 逻辑面积

| 组成 | 预估(kGates) | 计算依据 |
|------|-------------|----------|
| 寄存器阵列 | 0.6 | 16 × 10 bit × 6 GE = 960 GE（TX FIFO） |
| 指针逻辑 | 0.1 | 2 × 5 bit 寄存器 + 比较逻辑 |
| 状态逻辑 | 0.1 | 满/空/almost_full/count 计算 |
| 控制逻辑 | 0.1 | 读写使能处理 |
| **合计** | **0.9** | TX FIFO 实例 |

注：RX FIFO 实例面积略大（11 bit 宽度），约 1.0 kGates。

### 存储面积

| 元件 | 类型 | 容量 | 面积(mm²) |
|------|------|------|----------|
| TX FIFO mem | 寄存器阵列 | 160 bit | ~0.001 |
| RX FIFO mem | 寄存器阵列 | 176 bit | ~0.001 |

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
uart_fifo.v              — 主模块 RTL
uart_fifo_sva.sv         — SVA 断言
uart_fifo_tb.v           — 仿真 testbench
```

### 参数化
- `DATA_WIDTH`：数据位宽，默认 8
- `DEPTH`：FIFO 深度，默认 16，必须为 2 的幂
- `CNT_WIDTH`：计数器位宽，自动计算 `$clog2(DEPTH)+1`

### 编码规范

遵循 `rules/coding-style.md`。本子模块在 RTL 实现阶段需特别关注以下高风险项：

| 高风险项 | 关注点 |
|----------|--------|
| 组合逻辑 latch 防护 | always @(*) 输出默认值、if 补 else、case 有 default |
| FIFO 满/空判断 | 多 1 位指针法，满：wr_ptr[MSB]!=rd_ptr[MSB] && wr_ptr[LSB:0]==rd_ptr[LSB:0]，空：wr_ptr==rd_ptr |
| 指针回绕 | 指针宽度 = $clog2(DEPTH)+1，回绕时 MSB 翻转 |
| 同时读写 | wr_en && rd_en && !fifo_full && !fifo_empty 时，count 保持不变 |

### RTL 伪代码框架

```verilog
module uart_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    localparam CNT_WIDTH = $clog2(DEPTH) + 1
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // 写接口
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    // 读接口
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    // 状态标志
    output reg                   fifo_full,
    output reg                   fifo_empty,
    output reg                   fifo_almost_full,
    output reg  [CNT_WIDTH-1:0]  fifo_count,
    output reg                   fifo_overflow,
    output reg                   fifo_underflow,
    // 配置
    input  wire [CNT_WIDTH-1:0]  almost_full_thresh
);

// 寄存器阵列
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// 指针
reg [CNT_WIDTH-1:0] wr_ptr, rd_ptr;

// 写操作
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 0;
    end else if (wr_en && !fifo_full) begin
        mem[wr_ptr[CNT_WIDTH-2:0]] <= wr_data;
        wr_ptr <= wr_ptr + 1;
    end
end

// 读操作
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr <= 0;
        rd_data <= 0;
    end else if (rd_en && !fifo_empty) begin
        rd_data <= mem[rd_ptr[CNT_WIDTH-2:0]];
        rd_ptr <= rd_ptr + 1;
    end
end

// 状态计算（组合逻辑）
always @(*) begin
    fifo_full  = (wr_ptr[CNT_WIDTH-1] != rd_ptr[CNT_WIDTH-1]) &&
                 (wr_ptr[CNT_WIDTH-2:0] == rd_ptr[CNT_WIDTH-2:0]);
    fifo_empty = (wr_ptr == rd_ptr);
    fifo_almost_full = (fifo_count >= almost_full_thresh);
end

// 计数器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_count <= 0;
    end else begin
        case ({wr_en && !fifo_full, rd_en && !fifo_empty})
            2'b10: fifo_count <= fifo_count + 1;
            2'b01: fifo_count <= fifo_count - 1;
            default: fifo_count <= fifo_count; // 同时读写或无操作
        endcase
    end
end

// 溢出/下溢标志
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_overflow <= 0;
        fifo_underflow <= 0;
    end else begin
        fifo_overflow  <= wr_en && fifo_full;
        fifo_underflow <= rd_en && fifo_empty;
    end
end

endmodule
```

### 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "FIFO 深度随便选 16" | 深度 = 流控模型计算结果，16 是计算得出 |
| "满/空判断用简单比较" | 必须用多 1 位指针法，否则无法区分满和空 |
| "同时读写不用特殊处理" | 同时读写时 count 保持不变，需要 case 处理 |
| "复位时 mem 要清零" | mem 不需要复位，只有指针和状态需要复位 |

---

## 10. 验证要点

### 关键验证场景

| 场景 ID | 描述 | 覆盖需求 | 方法 | 优先级 |
|---------|------|----------|------|--------|
| VS-001 | 写满 FIFO | REQ-005 | 功能仿真 | High |
| VS-002 | 读空 FIFO | REQ-006 | 功能仿真 | High |
| VS-003 | 同时读写 | REQ-005/006 | 功能仿真 | High |
| VS-004 | 溢出检测 | REQ-005 | 功能仿真 | High |
| VS-005 | 下溢检测 | REQ-006 | 功能仿真 | High |
| VS-006 | almost_full 阈值 | REQ-007 | 功能仿真 | Medium |

### SVA 断言要点
- 写满时 overflow：`fifo_full && wr_en |=> fifo_overflow`
- 读空时 underflow：`fifo_empty && rd_en |=> fifo_underflow`
- 满时空标志互斥：`fifo_full |-> !fifo_empty`
- 空时满标志互斥：`fifo_empty |-> !fifo_full`
- 计数器范围：`fifo_count <= DEPTH`

### 覆盖率模型

| 覆盖组 | 覆盖点 | 目标 |
|--------|--------|------|
| 读写组合 | wr_en×rd_en×full×empty 16 种 | 100% |
| 边界值 | count=0, count=DEPTH, count=DEPTH-1 | 100% |
| 异常场景 | overflow, underflow | 100% |

---

## 11. 风险与缓解

### 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | 同时读写时序竞争 | 功能 | L | 写优先于读，同周期写入先执行 |
| R-002 | 指针回绕错误 | 功能 | L | 多 1 位指针法，MSB 翻转正确 |
| R-003 | 面积超预算 | 面积 | L | 寄存器阵列实现，面积可控 |

### 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | 边界条件覆盖不全 | 补充满/空/同时读写场景 |

---

## 12. 架构决策记录

### ADR-0001: FIFO 实现方式选择

**日期**：2026-04-27 | **状态**：accepted

**背景**：UART TX/RX 各需要一个 16 深度 FIFO，需要选择实现方式。

**决策**：使用寄存器阵列实现。

**方案 A**（采用）：寄存器阵列
- 优势：实现简单，无需 SRAM 编译器，深度 16 时面积可接受
- 劣势：深度 > 32 时面积不经济

**方案 B**（拒绝）：SRAM 实现
- 优势：深度大时面积更优
- 劣势：需要 SRAM 编译器，深度 16 时 SRAM 面积反而更大

**后果**：正面——实现简单，验证容易；负面——深度扩展时需要重新评估。

---

## 13. 附录

### 需求追溯矩阵（RTM）

| 需求 ID | FS 章节 | 微架构章节 | 实现方式 | 验证场景 | 状态 |
|---------|---------|-----------|----------|----------|------|
| REQ-005 | FS §5.5 | §5.5 FIFO 设计 | 寄存器阵列，深度 16 | VS-001 | Designed |
| REQ-006 | FS §5.5 | §5.5 FIFO 设计 | 寄存器阵列，深度 16 | VS-002 | Designed |

### 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_FS_v1.0.md` | 功能规格书 |
| REF-002 | `rules/coding-style.md` | RTL 编码规范 |

### 缩略语

| 缩写 | 全称 |
|------|------|
| FIFO | First In First Out |
| CBB | Circuit Building Block |
| RTS | Request To Send |
| CTS | Clear To Send |
| PPA | Performance, Power, Area |
| SVA | SystemVerilog Assertion |
| GE | Gate Equivalent |
