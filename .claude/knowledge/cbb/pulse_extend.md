# pulse_extend — 脉冲展宽器

> **用途**：将短脉冲展宽为指定周期数的长脉冲，或产生固定宽度脉冲
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

脉冲展宽器将输入的单周期或多周期脉冲展宽到指定的时钟周期数。用于慢速外设驱动、LED 闪烁控制、测试信号生成、跨时钟域前的脉冲稳定等场景。

```
pulse_in ──> ┌──────────────┐ ──pulse_out──> 展宽后脉冲
             │ pulse_extend  │
             └──────────────┘
             ←── Cycles ────>
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `WIDTH` | parameter | 1 | 脉冲信号位宽 |
| `CYCLES` | parameter | 4 | 展宽周期数（≥ 1） |
| `MODE` | parameter | `"RETRIGGER"` | 模式：`"ONESHOT"` = 单次触发，`"RETRIGGER"` = 可重触发 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `pulse_in` | I | `WIDTH` | clk | 输入脉冲 |
| `pulse_out` | O | `WIDTH` | clk | 展宽后脉冲 |
| `busy` | O | 1 | clk | 忙信号，正在展宽中 |

---

## 时序

### ONESHOT 模式

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
pulse_in    _____|‾|_______________________________
pulse_out   _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________________  (展宽 4 周期)
busy        _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________________
cnt         _____| 3 | 2 | 1 | 0 |________________
                      ↑ 忽略新脉冲（ONESHOT）
```

- 触发后计数器递减，计数期间忽略新输入脉冲

### RETRIGGER 模式

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
pulse_in    _____|‾|___________|‾|_______________
pulse_out   _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (重触发)
busy        _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
cnt         _____| 3 | 2 | 1 | 0→3| 2 | 1 | 0 |__
                      ↑ 重触发，计数器重新加载
```

- 计数期间收到新脉冲，计数器重新加载为 CYCLES

---

## 用法

### LED 闪烁控制

```verilog
// 将按键脉冲展宽到 1M 周期（@100MHz = 10ms）
pulse_extend #(
    .WIDTH  (1),
    .CYCLES (1_000_000),
    .MODE   ("ONESHOT")
) u_led_extend (
    .clk      (clk),
    .rst_n    (rst_n),
    .pulse_in (btn_pulse),
    .pulse_out(led_flash),
    .busy     (led_busy)
);
```

### 中断信号展宽

```verilog
// 将短脉冲展宽到 8 周期，确保目标时钟域能采到
pulse_extend #(
    .WIDTH  (1),
    .CYCLES (8),
    .MODE   ("ONESHOT")
) u_irq_extend (
    .clk      (clk),
    .rst_n    (rst_n),
    .pulse_in (irq_short),
    .pulse_out(irq_wide),
    .busy     ()
);
```

### 可重触发看门狗脉冲

```verilog
// 持续输入脉冲保持输出高，停止输入后输出延时关闭
pulse_extend #(
    .WIDTH  (1),
    .CYCLES (256),
    .MODE   ("RETRIGGER")
) u_wdg_extend (
    .clk      (clk),
    .rst_n    (rst_n),
    .pulse_in (kick_pulse),
    .pulse_out(wdg_output),
    .busy     (wdg_active)
);
```

---

## 关键实现细节

- **计数器**：递减计数器，`cnt > 0` 时 `pulse_out = 1`
- **ONESHOT**：`cnt == 0` 时才响应新脉冲（加载 CYCLES-1）
- **RETRIGGER**：任何时刻收到脉冲都重新加载计数器
- **复位**：计数器复位为 0，输出为低
- **CYCLES=1**：脉冲宽度不变，仅 1 周期
- **多 bit 模式**：每位独立计数，互不影响
