# intc — 中断控制器

> **用途**：多源中断的汇聚、优先级仲裁、屏蔽与状态管理
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

中断控制器（Interrupt Controller）汇聚多个中断源，经过使能屏蔽、优先级仲裁后输出最高优先级中断到 CPU。支持中断状态寄存器（Pending）、使能寄存器（Enable）、优先级配置、中断清除（ACK/W1C）。用于 SoC 中多个外设中断的集中管理。

```
IRQ[0]  ──┐
IRQ[1]  ──┤──> ┌──────────┐ ──irq_out──> CPU 中断输入
  ...   ──┤    │   intc   │ ──irq_id──>  最高中断号
IRQ[N-1]─┘    └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_IRQ` | parameter | 16 | 中断源数量 |
| `PRIO_WIDTH` | parameter | 4 | 优先级位宽（最大优先级 = 2^PRIO_WIDTH-1） |
| `LEVEL` | parameter | `"LEVEL"` | 中断触发方式：`"LEVEL"` = 电平触发，`"EDGE"` = 边沿触发 |
| `HAS_PENDING` | parameter | 1 | 是否支持 Pending 寄存器 |
| `HAS_PRIORITY` | parameter | 1 | 是否支持可编程优先级 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `irq_in` | I | `NUM_IRQ` | clk | 中断输入（来自外设） |
| `irq_out` | O | 1 | clk | 汇总中断输出（连接 CPU） |
| `irq_id` | O | `$clog2(NUM_IRQ)` | clk | 最高优先级中断号 |
| `irq_valid` | O | 1 | clk | 存在有效中断 |

### 寄存器接口（软件访问）

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `reg_irq_raw` | O | `NUM_IRQ` | clk | 原始中断状态（屏蔽前） |
| `reg_irq_pending` | O | `NUM_IRQ` | clk | 挂起中断状态（屏蔽后） |
| `reg_irq_enable` | I | `NUM_IRQ` | clk | 中断使能寄存器 |
| `reg_irq_clear` | I | `NUM_IRQ` | clk | 中断清除（W1C） |
| `reg_irq_priority` | I | `NUM_IRQ × PRIO_WIDTH` | clk | 各中断优先级配置 |

---

## 时序

### 电平触发中断

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
irq_in      ___|4'b0010____________________|
irq_enable  ___|4'b1111____________________|
irq_pending _________|4'b0010_______________|
irq_out     _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
irq_id      _________|  1                 |
irq_clear   _________________|4'b0010______|
irq_pending _______________________|4'b0000|
irq_out     _______________________|______|
```

### 边沿触发中断

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
irq_in      _____|‾|___________|‾|_________
irq_pending _______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (锁存直到清除)
irq_out     _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
irq_clear   _________________|1|______________
irq_pending _______________________|________|_  (清除)
```

### 优先级仲裁

```
clk         __|‾|__|‾|__|‾|__|‾|__
irq_in      ___|4'b1111___________|  (4 个中断同时触发)
irq_pri[0]  ___| 4 (最高)__________|
irq_pri[1]  ___| 2 _______________|
irq_pri[2]  ___| 1 _______________|
irq_pri[3]  ___| 3 _______________|
irq_id      _________|  0        |  (优先级最高的 IRQ0 胜出)
irq_out     _________|‾‾‾‾‾‾‾‾‾‾|_
```

---

## 用法

### 基本中断控制器

```verilog
intc #(
    .NUM_IRQ      (16),
    .PRIO_WIDTH   (4),
    .LEVEL        ("LEVEL"),
    .HAS_PENDING  (1),
    .HAS_PRIORITY (1)
) u_intc (
    .clk              (clk),
    .rst_n            (rst_n),
    // 中断源输入
    .irq_in           ({uart_irq, spi_irq, i2c_irq, timer_irq,
                        gpio_irq, dma_irq, 10'd0}),
    // CPU 输出
    .irq_out          (cpu_irq),
    .irq_id           (cpu_irq_id),
    .irq_valid        (cpu_irq_valid),
    // 寄存器接口
    .reg_irq_raw      (irq_raw_status),
    .reg_irq_pending  (irq_pending_status),
    .reg_irq_enable   (irq_enable_reg),
    .reg_irq_clear    (irq_clear_reg),
    .reg_irq_priority (irq_priority_reg)
);
```

### 边沿触发中断（GPIO 按键）

```verilog
intc #(
    .NUM_IRQ      (8),
    .PRIO_WIDTH   (3),
    .LEVEL        ("EDGE"),
    .HAS_PENDING  (1),
    .HAS_PRIORITY (0)              // 固定优先级（编号越小越高）
) u_gpio_intc (
    .clk              (clk),
    .rst_n            (rst_n),
    .irq_in           (gpio_edge_in),
    .irq_out          (gpio_irq),
    .irq_id           (gpio_irq_id),
    .irq_valid        (gpio_irq_valid),
    .reg_irq_raw      (),
    .reg_irq_pending  (gpio_pending),
    .reg_irq_enable   (gpio_enable),
    .reg_irq_clear    (gpio_clear),
    .reg_irq_priority ()
);
```

---

## 关键实现细节

- **电平触发**：`pending = irq_in & enable`，中断源持续有效
- **边沿触发**：`pending = (pending | irq_edge) & ~clear`，锁存直到软件清除
- **优先级仲裁**：比较所有 pending 的优先级值，选择最高优先级输出
- **W1C 清除**：`pending <= pending & ~clear`，写 1 清零对应位
- **irq_valid**：`|pending` — 任一中断挂起即拉高
- **irq_id**：从所有 pending 中找出最高优先级的索引
- **无优先级模式**：HAS_PRIORITY=0 时按编号仲裁（编号小优先级高）
- **面积**：NUM_IRQ × (PRIO_WIDTH + 2) 触发器 + 优先级编码器，约 0.5-2K GE
