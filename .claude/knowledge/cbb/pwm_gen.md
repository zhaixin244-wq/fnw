# pwm_gen — PWM 信号发生器

> **用途**：可配置占空比和频率的脉冲宽度调制信号发生器
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

PWM（Pulse Width Modulation）发生器产生可配置频率和占空比的方波信号。通过计数器与比较阈值实现，占空比 = 比较值 / 周期值。用于电机控制、LED 亮度调节、DAC 数模转换、电源管理调压等场景。

```
clk ──> ┌──────────┐
cfg ──> │ pwm_gen  │ ──pwm_out──> PWM 信号
en  ──> └──────────┘
           ↑ 周期 = PERIOD, 占空比 = DUTY / PERIOD
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `CNT_WIDTH` | parameter | 16 | 计数器位宽 |
| `CHANNELS` | parameter | 1 | PWM 通道数 |
| `PERIOD_MODE` | parameter | `"DYNAMIC"` | 周期模式：`"FIXED"` = 参数固定，`"DYNAMIC"` = 运行时配置 |
| `ALIGNMENT` | parameter | `"LEFT"` | 对齐方式：`"LEFT"` = 左对齐，`"CENTER"` = 中心对齐 |
| `CNT_MAX` | parameter | `(1<<CNT_WIDTH)-1` | 最大计数值（FIXED 模式） |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `en` | I | 1 | clk | 模块使能 |
| `period` | I | `CNT_WIDTH` | clk | PWM 周期值（DYNAMIC 模式） |
| `duty` | I | `CHANNELS × CNT_WIDTH` | clk | 各通道占空比值 |
| `pwm_out` | O | `CHANNELS` | clk | PWM 输出信号 |
| `pwm_irq` | O | `CHANNELS` | clk | 周期结束中断（可选） |

---

## 时序

### 左对齐（PERIOD=10, DUTY=3）

```
clk      __|‾|__|‾|__|‾|__|__|__|__|__|__|__|__|__|__|__|__|__|__|__|
cnt      ___| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | 1 | 2 | 3 |
pwm_out  ___|‾‾‾‾‾‾‾‾‾‾‾‾‾|_______________|‾‾‾‾‾‾‾‾‾‾‾‾‾|___________
                  ↑ duty=3, 占空比 30%                   ↑ 新周期
```

### 中心对齐（PERIOD=10, DUTY=3）

```
clk      __|‾|__|‾|__|__|__|__|__|__|__|__|__|__|__|__|__|__|__|
cnt_up   ___| 0 | 1 | 2 | 3 | 4 | 5 | 4 | 3 | 2 | 1 | 0 | 1 |
cnt_dn   ___| 5 | 4 | 3 | 2 | 1 | 0 | 1 | 2 | 3 | 4 | 5 | 4 |
pwm_out  _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___________|‾‾‾‾‾‾‾‾‾
                    ↑ 中心对齐，对称波形
```

### 多通道（4 通道，不同占空比）

```
clk      __|‾|__|‾|__|__|__|__|__|__|__|__|
pwm[0]   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (duty=100%)
pwm[1]   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___________  (duty=50%)
pwm[2]   ___|‾‾‾‾‾‾‾‾‾‾|_______________  (duty=33%)
pwm[3]   ___|‾‾‾‾‾|____________________  (duty=16%)
```

---

## 用法

### LED 亮度控制

```verilog
// 8 通道 LED，每通道独立亮度控制
pwm_gen #(
    .CNT_WIDTH   (8),
    .CHANNELS    (8),
    .PERIOD_MODE ("FIXED"),
    .CNT_MAX     (255),
    .ALIGNMENT   ("LEFT")
) u_led_pwm (
    .clk      (clk),
    .rst_n    (rst_n),
    .en       (led_enable),
    .duty     ({led7_bright, led6_bright, led5_bright, led4_bright,
                led3_bright, led2_bright, led1_bright, led0_bright}),
    .pwm_out  (led_pwm_out),
    .pwm_irq  ()
);
```

### 电机 PWM（中心对齐）

```verilog
// 3 相电机控制，中心对齐减少谐波
pwm_gen #(
    .CNT_WIDTH   (12),
    .CHANNELS    (3),
    .PERIOD_MODE ("DYNAMIC"),
    .ALIGNMENT   ("CENTER")
) u_motor_pwm (
    .clk      (clk),
    .rst_n    (rst_n),
    .en       (motor_en),
    .period   (pwm_period),          // 可调频率
    .duty     ({phase_c, phase_b, phase_a}),
    .pwm_out  ({motor_c, motor_b, motor_a}),
    .pwm_irq  (pwm_cycle_irq)
);
```

### DAC 输出

```verilog
// 高频 PWM 用于 DAC，后接 RC 滤波器
pwm_gen #(
    .CNT_WIDTH   (10),
    .CHANNELS    (1),
    .PERIOD_MODE ("FIXED"),
    .CNT_MAX     (1023),
    .ALIGNMENT   ("LEFT")
) u_dac_pwm (
    .clk      (clk_100m),
    .rst_n    (rst_n),
    .en       (1'b1),
    .duty     (dac_value),           // 10-bit DAC 值
    .pwm_out  (dac_pwm_pin),
    .pwm_irq  ()
);
// 占空比 = dac_value / 1024, 滤波后得到模拟电压
```

---

## 关键实现细节

- **左对齐**：计数器 0 → PERIOD 递增，`pwm_out = (cnt < duty)`
- **中心对齐**：计数器 0 → PERIOD 递增再递减（三角波），`pwm_out = (cnt_up < duty) || (cnt_down < duty)`
- **多通道**：每个通道独立比较器，共享一个计数器
- **周期更新**：DYNAMIC 模式下，period 更新在当前周期结束后生效
- **duty 约束**：duty 应 ≤ period，否则输出恒高
- **pwm_irq**：每周期结束时产生单周期中断
- **en=0**：pwm_out 输出恒低，计数器暂停
- **复位**：计数器清零，pwm_out 输出低
- **面积**：CHANNELS × CNT_WIDTH 个比较器 + 1 个计数器
