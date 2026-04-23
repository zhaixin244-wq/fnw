# clk_div — 时钟分频器

> **用途**：将输入时钟按可配置分频比产生低频时钟输出
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

时钟分频器将高速时钟分频为低速时钟。支持整数分频、奇偶分频、占空比 50% 输出。输出时钟可直接用作功能时钟或通过标准 ICG 门控。注意：分频时钟直接输出仅用于非关键路径（如外设时钟），关键时钟应使用 PLL/MMCM 产生。

```
clk_in ──> ┌──────────┐ ──clk_out──> 分频后时钟
           │ clk_div   │ ──clk_out_en──> 使能脉冲
           └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DIV_WIDTH` | parameter | 8 | 分频比位宽 |
| `DIV_VALUE` | parameter | 2 | 固定分频比（FIXED 模式） |
| `MODE` | parameter | `"FIXED"` | 模式：`"FIXED"` = 固定分频，`"DYNAMIC"` = 动态分频 |
| `DUTY_50` | parameter | 1 | 占空比 50% 使能 |
| `PHASE` | parameter | 0 | 初始相位偏移（0-3） |
| `OUT_TYPE` | parameter | `"CLOCK"` | 输出类型：`"CLOCK"` = 时钟输出，`"ENABLE"` = 使能脉冲 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 输入时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `en` | I | 1 | clk | 分频使能 |
| `div_value` | I | `DIV_WIDTH` | clk | 动态分频比（DYNAMIC 模式） |
| `clk_out` | O | 1 | - | 分频时钟输出（CLOCK 类型） |
| `clk_out_en` | O | 1 | clk | 使能脉冲输出（ENABLE 类型） |
| `locked` | O | 1 | clk | 输出稳定标志 |

---

## 时序

### 偶数分频（DIV=4，占空比 50%）

```
clk_in   __|‾|__|‾|__|‾|__|‾|__|‾|__|__|‾|__|‾|__|‾|__|‾|
cnt      ___| 0 | 1 | 2 | 3 | 0 | 1 | 2 | 3 | 0 | 1 | 2 |
clk_out  _____|‾‾‾‾‾‾‾‾‾‾‾‾|_____________|‾‾‾‾‾‾‾‾‾‾‾‾|___
           ↑ 分频比 = 4，占空比 50%
```

### 奇数分频（DIV=3，占空比 50%）

```
clk_in   __|‾|__|‾|__|‾|__|‾|__|__|‾|__|‾|__|‾|__|__|‾|__
cnt      ___| 0 | 1 | 2 | 0 | 1 | 2 | 0 | 1 | 2 | 0 | 1 |
clk_out  _______|‾‾‾‾‾‾‾‾‾‾‾‾|_________|‾‾‾‾‾‾‾‾‾‾‾‾|___
           ↑ DIV=3 时使用上升沿+下降沿计数实现 50% 占空比
```

### 使能脉冲模式（DIV=8）

```
clk_in   __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
cnt      ___| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 0 | 1 |
clk_out_en _____________________________|‾|_______________|‾|_
             ↑ 每 DIV 个周期输出 1 个脉冲
```

### 动态分频切换

```
clk_in   __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
div_value___| 2       | 4               |
cnt      ___| 0 | 1 | 0 | 1 | 2 | 3 | 0 |  (切换后立即生效)
clk_out  _____|‾|__|‾|__|‾‾‾‾‾‾‾‾‾‾‾‾‾‾|__|
             ↑ DIV=2   ↑ DIV=4
```

---

## 用法

### 外设时钟分频

```verilog
// 100MHz → 25MHz（DIV=4）
clk_div #(
    .DIV_WIDTH (8),
    .DIV_VALUE (4),
    .MODE      ("FIXED"),
    .DUTY_50   (1),
    .OUT_TYPE  ("CLOCK")
) u_uart_clk (
    .clk       (clk_100m),
    .rst_n     (rst_n),
    .en        (uart_enable),
    .div_value (),
    .clk_out   (clk_uart),
    .clk_out_en(),
    .locked    ()
);

// 分频时钟通过 ICG 门控后使用
CKLNQD1 u_uart_icg (
    .CP  (clk_uart),
    .E   (uart_active),
    .TE  (scan_en),
    .Q   (gated_uart_clk)
);
```

### 动态分频（自适应频率）

```verilog
clk_div #(
    .DIV_WIDTH (16),
    .MODE      ("DYNAMIC"),
    .DUTY_50   (1),
    .OUT_TYPE  ("CLOCK")
) u_core_clk_div (
    .clk       (clk_pll),
    .rst_n     (rst_n),
    .en        (1'b1),
    .div_value (cfg_div_ratio),    // 寄存器配置
    .clk_out   (clk_core),
    .clk_out_en(),
    .locked    (clk_stable)
);
```

### SPI 时钟生成（使能模式）

```verilog
clk_div #(
    .DIV_WIDTH (8),
    .DIV_VALUE (16),
    .MODE      ("FIXED"),
    .DUTY_50   (0),
    .OUT_TYPE  ("ENABLE")
) u_spi_clk_div (
    .clk       (clk),
    .rst_n     (rst_n),
    .en        (spi_busy),
    .div_value (),
    .clk_out   (),
    .clk_out_en(spi_sclk_en),      // SPI 用使能脉冲驱动
    .locked    ()
);

assign spi_sclk = spi_sclk_en ? ~spi_sclk_reg : spi_sclk_reg;
```

---

## 关键实现细节

- **偶数分频**：计数到 DIV/2-1 翻转，简单实现占空比 50%
- **奇数分频**：上升沿计数器和下降沿计数器交错，OR 合成 50% 占空比
- **使能模式**：OUT_TYPE="ENABLE" 时，计数到 DIV-1 输出 1 周期脉冲
- **动态切换**：DYNAMIC 模式下 div_value 更新立即生效（计数器重新加载）
- **相位偏移**：PHASE 参数设置计数器初始值，0=无偏移
- **locked**：分频稳定后拉高（延迟 DIV 个周期）
- **注意**：CLOCK 输出类型不能直接 assign 给组合逻辑（毛刺），需通过 ICG 门控
- **面积**：DIV_WIDTH 个触发器 + 比较器，极小开销
