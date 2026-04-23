# watchdog — 看门狗定时器

> **用途**：系统健康监控，软件未及时"喂狗"时触发复位或中断
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

看门狗定时器（Watchdog Timer）用于监控系统运行状态。软件需要在定时器超时前"喂狗"（写入特定值清除计数器），否则看门狗触发复位或中断信号。支持预分频、可配置超时窗口、第一次喂狗超时、安全锁定等机制。用于 SoC 看门狗复位、安全启动监控、系统自恢复等场景。

```
软件 ──kick──> ┌──────────┐ ──wdt_rst──> 系统复位
              │ watchdog  │ ──wdt_irq──> 中断
clk ────────> └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `CNT_WIDTH` | parameter | 32 | 计数器位宽 |
| `PRESCALE` | parameter | 256 | 预分频比（WDT 时钟 = clk / PRESCALE） |
| `TIMEOUT_ACTION` | parameter | `"RESET"` | 超时动作：`"RESET"` = 复位，`"IRQ"` = 中断，`"BOTH"` = 先中断后复位 |
| `FIRST_TIMEOUT` | parameter | 0 | 首次喂狗超时值（0=与普通超时相同） |
| `LOCK_EN` | parameter | 1 | 配置锁定使能 |
| `UNLOCK_KEY` | parameter | `32'h1ACCE551` | 解锁密钥 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `wdt_en` | I | 1 | clk | 看门狗使能 |
| `kick` | I | 1 | clk | 喂狗脉冲（单周期） |
| `timeout_val` | I | `CNT_WIDTH` | clk | 超时值 |
| `irq_timeout_val` | I | `CNT_WIDTH` | clk | 中断超时值（BOTH 模式，先中断后复位的间隔） |
| `wdt_rst` | O | 1 | clk | 看门狗复位输出 |
| `wdt_irq` | O | 1 | clk | 看门狗中断输出 |
| `cnt_value` | O | `CNT_WIDTH` | clk | 当前计数值（调试用） |
| `locked` | O | 1 | clk | 配置已锁定 |
| `unlock` | I | 1 | clk | 写入 UNLOCK_KEY 解锁 |
| `lock` | I | 1 | clk | 锁定配置 |

---

## 时序

### 正常喂狗

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
wdt_en      ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
kick        _________|‾|_______________|‾|_________
cnt_value   ___| 0→1→2→...→N-1| 0→1→2→...→M-1| 0  (喂狗后清零)
wdt_rst     _______________________________________
wdt_irq     _______________________________________
```

### 超时复位（RESET 模式）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
wdt_en      ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
kick        ___________________________________
cnt_value   ___| 0 | 1 | 2 |...| MAX | MAX+1|
wdt_rst     _____________________________|‾‾‾|_  (计数到 timeout_val)
              ↑ 超时触发复位
```

### 先中断后复位（BOTH 模式）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
kick        _________________________________________
cnt_value   ___| 0→1→2→...→TIMEOUT |...→TIMEOUT+IRQ_TMO|
wdt_irq     _____________________________|‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (先中断)
wdt_rst     _____________________________________________|‾‾‾|_  (后复位)
              ↑ 第一次超时→中断  ↑ 软件有机会在中断中喂狗
```

---

## 用法

### 系统看门狗

```verilog
watchdog #(
    .CNT_WIDTH      (32),
    .PRESCALE       (256),          // @100MHz → WDT 时钟 = 390kHz
    .TIMEOUT_ACTION ("BOTH"),
    .LOCK_EN        (1),
    .UNLOCK_KEY     (32'h1ACCE551)
) u_sys_wdt (
    .clk              (clk),
    .rst_n            (rst_n),
    .wdt_en           (1'b1),
    .kick             (sw_kick),
    .timeout_val      (32'd100000),  // ~256ms @390kHz
    .irq_timeout_val  (32'd10000),   // 中断后 ~25ms 复位
    .wdt_rst          (wdt_reset),
    .wdt_irq          (wdt_irq),
    .cnt_value        (wdt_cnt),
    .locked           (wdt_locked),
    .unlock           (wdt_unlock),
    .lock             (wdt_lock)
);

// 全局复位：看门狗复位 OR 外部复位
assign sys_rst_n = rst_n & ~wdt_reset;
```

### 安全启动监控

```verilog
// 第一次喂狗有独立超时值，监控启动过程
watchdog #(
    .CNT_WIDTH      (24),
    .PRESCALE       (1),
    .TIMEOUT_ACTION ("RESET"),
    .FIRST_TIMEOUT  (1)             // 首次超时独立配置
) u_boot_wdt (
    .clk              (clk),
    .rst_n            (rst_n),
    .wdt_en           (boot_wdt_en),
    .kick             (boot_done_kick),
    .timeout_val      (24'hFFFFFF),
    .irq_timeout_val  (24'd0),
    .wdt_rst          (boot_timeout_rst),
    .wdt_irq          (),
    .cnt_value        (),
    .locked           (),
    .unlock           (1'b0),
    .lock             (1'b0)
);
```

---

## 关键实现细节

- **预分频计数器**：`prescale_cnt` 计满 PRESCALE-1 后主计数器 +1
- **喂狗**：kick 脉冲将主计数器清零
- **超时检测**：`cnt_value >= timeout_val` 时触发动作
- **BOTH 模式**：先拉高 wdt_irq，中断后计数 irq_timeout_val，仍未喂狗则拉高 wdt_rst
- **锁定机制**：配置寄存器写入后 lock 位锁死，需写入 UNLOCK_KEY 才可修改
- **wdt_rst**：单周期脉冲或电平（可配置），连接系统复位逻辑
- **时钟域安全**：预分频使用系统时钟，即使软件跑飞也能检测
- **面积**：CNT_WIDTH + prescale 计数器 + 状态机，约 0.5-1K GE
