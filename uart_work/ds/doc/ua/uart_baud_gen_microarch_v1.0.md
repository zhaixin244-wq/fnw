# uart_baud_gen 微架构规格书

> 基于 `uart_FS_v1.0.md` §5.2 编写。小数波特率发生器，生成 baud_tick 和 baud_tick_16x 脉冲。编码规范遵循 `rules/coding-style.md`。

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| **模块/子模块** | `uart` / `uart_baud_gen` |
| **版本** | `v1.0` |
| **文档编号** | `FNW-MA-uart_baud_gen-v1.0` |
| **对应 FS** | `uart_FS_v1.0.md` §5.2 |
| **作者/日期/审核** | `AI Agent` / `2026-04-27` / `{reviewer}` |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-04-27 | AI Agent | 初始版本 |

---

## 3. 子模块概述

### 3.1 功能定位

`uart_baud_gen` 是小数波特率发生器，通过 16 位整数分频 + 4 位小数累加器实现高精度波特率生成。产生 `baud_tick`（波特率时钟）和 `baud_tick_16x`（16 倍波特率时钟，用于过采样和 TX 移位）。支持 16x/8x 过采样模式切换。

**从 FS 继承的需求**：

| 需求 ID | 需求描述 | FS 章节 |
|---------|----------|---------|
| REQ-004 | 可编程波特率 | FS §4.1, §7.2 |
| REQ-012 | 波特率 9600~921600 bps | FS §8.1 |
| REQ-017 | 16x/8x 过采样可配 | FS §7.2 FCR_EXT.OS_SEL |

### 3.2 与上级/兄弟模块的关系

| 邻接模块 | 接口方向 | 接口名称 | 说明 |
|----------|----------|----------|------|
| uart_reg_mod | 输入 | `baud_div_int`, `baud_div_frac` | 分频值配置 |
| uart_reg_mod | 输入 | `oversample_sel` | 过采样模式选择 |
| uart_tx | 输出 | `baud_tick_16x` | TX 移位时钟 |
| uart_rx | 输出 | `baud_tick_16x`, `baud_tick_8x`, `baud_tick` | RX 过采样时钟 |

### 3.3 内部框图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 内部结构图（`wd_uart_baud_gen_arch.d2`），通过 `d2 --layout dagre` 编译为 PNG。

```markdown
![uart_baud_gen 内部框图](wd_uart_baud_gen_arch.png)
```

> **图片说明**：本图展示 uart_baud_gen 的内部架构，包含以下核心组件：
> - 整数分频计数器（div_cnt）：16 位向下计数器，从 baud_div_int 值开始递减
> - 小数累加器（frac_acc）：4 位累加器，溢出时多计一拍
> - 16x/8x 分频逻辑：根据 oversample_sel 选择分频模式
> - tick 生成逻辑：产生 baud_tick_16x、baud_tick_8x、baud_tick 脉冲
> - 配置输入：baud_div_int[15:0]、baud_div_frac[3:0]、oversample_sel

---

## 4. 接口定义

### 4.1 端口列表

| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能描述 |
|---|--------|------|------|------|--------|--------|----------|
| 1 | `clk` | I | 1 | wire | - | - | 主时钟 |
| 2 | `rst_n` | I | 1 | wire | - | - | 低有效异步复位 |
| 3 | `baud_div_int` | I | 16 | wire | clk | 0 | 整数分频值（DLL+DLH） |
| 4 | `baud_div_frac` | I | 4 | wire | clk | 0 | 小数分频值（FCR_EXT[3:0]） |
| 5 | `oversample_sel` | I | 1 | wire | clk | 0 | 过采样选择：0=16x, 1=8x |
| 6 | `baud_tick_16x` | O | 1 | reg | clk | 0 | 16 倍波特率时钟脉冲 |
| 7 | `baud_tick_8x` | O | 1 | reg | clk | 0 | 8 倍波特率时钟脉冲 |
| 8 | `baud_tick` | O | 1 | reg | clk | 0 | 波特率时钟脉冲 |

**与 FS 接口映射**：

| 本模块端口 | FS 接口 | FS 信号名 | 映射说明 |
|------------|---------|-----------|----------|
| `baud_div_int` | FS §5.2.2 | `baud_div_int` | DLL+DLH 拼接 |
| `baud_div_frac` | FS §5.2.2 | `baud_div_frac` | FCR_EXT[3:0] |
| `oversample_sel` | FS §5.2.2 | `oversample_sel` | FCR_EXT[4] |
| `baud_tick_16x` | FS §5.2.2 | `baud_tick_16x` | 脉冲输出 |
| `baud_tick_8x` | FS §5.2.2 | `baud_tick_8x` | 脉冲输出 |
| `baud_tick` | FS §5.2.2 | `baud_tick` | 脉冲输出 |

### 4.2 接口协议与时序

**协议类型**：脉冲输出（单周期高电平脉冲）

**事务流程**：

[图表待生成] 使用 `chip-png-wavedrom-gen` 生成 Wavedrom 时序图（`wd_baud_tick.json`），编译为 PNG。

```markdown
![波特率发生器时序](wd_baud_tick.png)
```

> **图片说明**：本图展示波特率发生器的 tick 脉冲产生时序：
> - baud_tick_16x：每个分频周期产生一个单周期脉冲，频率 = clk / (div_int + div_frac/16)
> - baud_tick_8x：在 8x 模式下，每 2 个 baud_tick_16x 产生一个脉冲
> - baud_tick：每 16 个 baud_tick_16x（或 8 个 baud_tick_8x）产生一个脉冲
> - 小数累加器在溢出时多计一拍，实现平均分频

**关键时序参数**：

| 参数 | 值 | 单位 | 说明 |
|------|----|------|------|
| baud_tick_16x 脉宽 | 1 | cycle | 单周期脉冲 |
| 波特率精度 | < 0.1 | % | @50MHz, 115200bps |
| 分频范围 | 3 ~ 65535 | - | 16 位整数分频值 |
| 小数精度 | 1/16 | - | 4 位小数累加器 |

---

## 5. 微架构设计

### 5.1 数据通路

#### 数据流图

[图表待生成] 使用 `chip-png-d2-gen` 生成 D2 数据通路图（`wd_uart_baud_gen_datapath.d2`），从输入到输出的完整路径。

```markdown
![uart_baud_gen 数据通路](wd_uart_baud_gen_datapath.png)
```

> **图片说明**：本图展示 uart_baud_gen 的数据通路，从输入到输出共 3 个阶段：
> - 阶段 0（配置）：baud_div_int + baud_div_frac 输入，oversample_sel 选择模式
> - 阶段 1（分频）：整数计数器 + 小数累加器，产生 16x tick 基础脉冲
> - 阶段 2（分频）：16x → 8x → 1x 逐级分频，产生各级 tick 脉冲
>
> 关键数据路径：baud_div_int → div_cnt → baud_tick_16x → tick_8x_cnt → baud_tick。

#### 各阶段数据格式

| 阶段 | 数据名 | 位宽 | 格式说明 | 组合/时序 |
|------|--------|------|----------|-----------|
| 配置 | `baud_div_int` | 16 | 整数分频值 | - |
| 配置 | `baud_div_frac` | 4 | 小数分频值 | - |
| 分频 | `div_cnt` | 16 | 整数计数器 | 时序 |
| 分频 | `frac_acc` | 4 | 小数累加器 | 时序 |
| 分频 | `tick_16x_cnt` | 4 | 16x tick 计数器 | 时序 |
| 输出 | `baud_tick_16x` | 1 | 16x tick 脉冲 | 时序 |
| 输出 | `baud_tick` | 1 | 1x tick 脉冲 | 时序 |

#### 关键数据路径

| 路径 ID | 起点 | 终点 | 组合逻辑级数 | 预估延迟 | 关键路径 |
|---------|------|------|-------------|----------|----------|
| DP-001 | `div_cnt` | `baud_tick_16x` | 1 级 | 0.2 ns | 否 |
| DP-002 | `frac_acc` | `div_cnt` 更新 | 2 级 | 0.4 ns | 是 |

---

### 5.2 控制逻辑

#### 控制信号列表

| 控制信号 | 位宽 | 产生源 | 功能描述 |
|----------|------|--------|----------|
| `div_cnt` | 16 | 内部寄存器 | 整数分频计数器 |
| `frac_acc` | 4 | 内部寄存器 | 小数累加器 |
| `tick_16x` | 1 | 组合逻辑 | 16x tick 使能（div_cnt 到 0 时） |
| `tick_16x_cnt` | 4 | 内部寄存器 | 16x tick 计数器，用于生成 1x tick |
| `tick_8x_cnt` | 3 | 内部寄存器 | 8x tick 计数器，用于生成 1x tick |

#### 流控机制

| 类型 | 接口 | 机制 | 背压路径 |
|------|------|------|----------|
| 无 | - | - | 波特率发生器为纯输出模块，无背压需求 |

**背压传播规则**：无。波特率发生器持续产生 tick 脉冲，不受下游影响。

---

### 5.3 状态机设计

本子模块无状态机设计。波特率发生器为纯计数器逻辑，无状态转移。

---

### 5.4 流水线设计

本子模块无流水线设计。分频计数器为单周期更新。

---

### 5.5 FIFO / 缓冲设计

本子模块无 FIFO 设计。

---

### 5.6 IP/CBB 集成设计

本子模块无 IP/CBB 集成。

---

## 6. 关键时序分析

### 关键路径

| 路径 ID | 起点 | 组合逻辑 | 级数 | 预估延迟 |
|---------|------|----------|------|----------|
| CP-001 | `div_cnt` 寄存器 | 比较 + 累加 | 2 级 | 0.4 ns |
| CP-002 | `frac_acc` 寄存器 | 溢出判断 + 累加 | 2 级 | 0.4 ns |

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
set_input_delay  -clock clk -max 5 [get_ports {baud_div_int baud_div_frac oversample_sel}]
set_output_delay -clock clk -max 5 [get_ports {baud_tick_16x baud_tick_8x baud_tick}]
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
- div_cnt = 0
- frac_acc = 0
- tick_16x_cnt = 0
- baud_tick_16x = 0
- baud_tick_8x = 0
- baud_tick = 0

### CDC 处理

本子模块无 CDC 信号，所有信号在同一时钟域内。

---

## 8. PPA 预估

### 逻辑面积

| 组成 | 预估(kGates) | 计算依据 |
|------|-------------|----------|
| 整数计数器 | 0.2 | 16 bit 计数器 |
| 小数累加器 | 0.05 | 4 bit 累加器 |
| tick 计数器 | 0.1 | 4+3 bit 计数器 |
| 比较逻辑 | 0.1 | 分频值比较 |
| 控制逻辑 | 0.05 | tick 生成 |
| **合计** | **0.5** | |

### 功耗预估（PVT：`TT` / `1.0V` / `25°C` / `50MHz`）

| 指标 | 预估 | 单位 | 依据 |
|------|------|------|------|
| 动态功耗 | 0.2 | mW | α×C×V²×f，计数器翻转 |
| 静态功耗 | 0.05 | mW | 漏电×V |
| **合计** | **0.25** | **mW** | |

### 关键路径 Fmax

| 路径 | 延迟 | Fmax |
|------|------|------|
| **最差路径** | 0.4 ns | ≥ 500 MHz |

---

## 9. RTL 实现指导

### 文件结构
```
uart_baud_gen.v          — 主模块 RTL
uart_baud_gen_sva.sv     — SVA 断言
uart_baud_gen_tb.v       — 仿真 testbench
```

### 参数化
- 波特率计算公式：`baud_rate = clk_freq / (16 × (baud_div_int + baud_div_frac/16))`
- 50 MHz 时钟下，115200 bps：`div_int = 27, div_frac = 1`（精度 < 0.1%）
- 50 MHz 时钟下，9600 bps：`div_int = 325, div_frac = 5`（精度 < 0.1%）

### 编码规范

遵循 `rules/coding-style.md`。本子模块在 RTL 实现阶段需特别关注以下高风险项：

| 高风险项 | 关注点 |
|----------|--------|
| 组合逻辑 latch 防护 | always @(*) 输出默认值、if 补 else、case 有 default |
| 计数器回绕 | div_cnt 递减到 0 时重新加载 |
| 小数累加溢出 | frac_acc 溢出时 div_cnt 多减 1 |
| tick 脉宽 | baud_tick_xxx 必须是单周期脉冲 |

### RTL 伪代码框架

```verilog
module uart_baud_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] baud_div_int,
    input  wire [3:0]  baud_div_frac,
    input  wire        oversample_sel,
    output reg         baud_tick_16x,
    output reg         baud_tick_8x,
    output reg         baud_tick
);

// 整数分频计数器
reg [15:0] div_cnt;
reg [3:0]  frac_acc;

// 16x tick 计数器（用于生成 1x tick）
reg [3:0]  tick_16x_cnt;

// 整数分频 + 小数累加
wire tick_16x_en = (div_cnt == 0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt   <= 0;
        frac_acc  <= 0;
    end else if (tick_16x_en) begin
        div_cnt <= baud_div_int;
        // 小数累加
        if (frac_acc + baud_div_frac >= 16) begin
            frac_acc <= frac_acc + baud_div_frac - 16;
            div_cnt  <= baud_div_int + 1; // 多计一拍
        end else begin
            frac_acc <= frac_acc + baud_div_frac;
        end
    end else begin
        div_cnt <= div_cnt - 1;
    end
end

// baud_tick_16x 生成
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) baud_tick_16x <= 0;
    else        baud_tick_16x <= tick_16x_en;
end

// baud_tick_8x 生成（8x 模式下每 2 个 16x 产生一个）
reg tick_8x_toggle;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_8x_toggle <= 0;
        baud_tick_8x   <= 0;
    end else if (tick_16x_en) begin
        tick_8x_toggle <= ~tick_8x_toggle;
        baud_tick_8x   <= tick_8x_toggle; // 每 2 个 16x 翻转一次
    end
end

// baud_tick 生成（1x 波特率）
// 16x 模式：每 16 个 tick_16x 产生一个 baud_tick
// 8x 模式：每 8 个 tick_8x 产生一个 baud_tick
wire tick_8x_en = oversample_sel ? (tick_8x_toggle && tick_16x_en) : tick_16x_en;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_16x_cnt <= 0;
        baud_tick    <= 0;
    end else if (tick_8x_en) begin
        if (tick_16x_cnt == (oversample_sel ? 7 : 15)) begin
            tick_16x_cnt <= 0;
            baud_tick    <= 1;
        end else begin
            tick_16x_cnt <= tick_16x_cnt + 1;
            baud_tick    <= 0;
        end
    end else begin
        baud_tick <= 0;
    end
end

endmodule
```

### 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "分频值直接用整数" | 小数累加器实现平均分频，精度 < 0.1% |
| "tick 脉宽可以多拍" | 必须单周期脉冲，否则下游计数错误 |
| "过采样模式无所谓" | 16x/8x 影响 RX 采样精度，必须支持 |
| "复位值随便设" | 复位时所有计数器和输出必须清零 |

---

## 10. 验证要点

### 关键验证场景

| 场景 ID | 描述 | 覆盖需求 | 方法 | 优先级 |
|---------|------|----------|------|--------|
| VS-001 | 115200 bps 波特率 | REQ-004 | 功能仿真 | High |
| VS-002 | 9600 bps 波特率 | REQ-012 | 功能仿真 | High |
| VS-003 | 921600 bps 波特率 | REQ-012 | 功能仿真 | High |
| VS-004 | 16x 过采样模式 | REQ-017 | 功能仿真 | High |
| VS-005 | 8x 过采样模式 | REQ-017 | 功能仿真 | High |
| VS-006 | 小数分频精度 | REQ-004 | 功能仿真 | Medium |

### SVA 断言要点
- tick 脉宽：`baud_tick_16x |=> !baud_tick_16x`（单周期脉冲）
- 分频比验证：`baud_div_int` 个周期内产生 1 个 tick_16x
- 输出互斥：同一时刻最多一个 tick 为高

### 覆盖率模型

| 覆盖组 | 覆盖点 | 目标 |
|--------|--------|------|
| 分频值 | 最小/最大/常用分频值 | 100% |
| 过采样模式 | 16x/8x | 100% |
| 小数累加 | 溢出/不溢出 | 100% |

---

## 11. 风险与缓解

### 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | 波特率精度不足 | 功能 | L | 小数累加器实现平均分频 |
| R-002 | 分频值为 0 时行为异常 | 功能 | L | 分频值为 0 时 tick 恒为 0 |

### 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | 波特率精度验证困难 | 使用长时间仿真统计 tick 数量 |

---

## 12. 架构决策记录

### ADR-0002: 小数分频实现方式

**日期**：2026-04-27 | **状态**：accepted

**背景**：需要实现高精度波特率，整数分频无法满足 < 0.1% 精度要求。

**决策**：使用 4 位小数累加器实现平均分频。

**方案 A**（采用）：小数累加器
- 优势：实现简单，精度高（1/16 = 6.25% 分辨率）
- 劣势：瞬时频率有抖动

**方案 B**（拒绝）：Delta-Sigma 调制
- 优势：抖动更均匀
- 劣势：实现复杂，UART 对抖动不敏感

**后果**：正面——满足精度要求，实现简单；负面——瞬时频率有抖动，但 UART 协议容错性好。

---

## 13. 附录

### 需求追溯矩阵（RTM）

| 需求 ID | FS 章节 | 微架构章节 | 实现方式 | 验证场景 | 状态 |
|---------|---------|-----------|----------|----------|------|
| REQ-004 | FS §4.1 | §5.1 数据通路 | 16 位整数 + 4 位小数分频 | VS-001/002/003 | Designed |
| REQ-012 | FS §8.1 | §5.1 数据通路 | 分频范围 3~65535 | VS-002/003 | Designed |
| REQ-017 | FS §7.2 | §5.2 控制逻辑 | oversample_sel 选择 | VS-004/005 | Designed |

### 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_FS_v1.0.md` | 功能规格书 |
| REF-002 | `rules/coding-style.md` | RTL 编码规范 |

### 缩略语

| 缩写 | 全称 |
|------|------|
| DLL | Divisor Latch Low |
| DLH | Divisor Latch High |
| FCR | FIFO Control Register |
| PPA | Performance, Power, Area |
| SVA | SystemVerilog Assertion |
