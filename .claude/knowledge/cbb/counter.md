# counter — 计数器

> **用途**：通用可配置计数器，支持使能、加载、上下计数、自动重载
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

通用计数器模块支持多种计数模式：自由计数、上限自动重载、上下计数（三角波）、外部加载等。广泛用于帧计数、波特率生成、超时检测、突发传输计数等场景。

```
clk ──> ┌──────────┐ ──cnt──> 计数值
en  ──> │ counter  │ ──tc──>  终点标志（Terminal Count）
load──> └──────────┘ ──zero──> 零标志
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `CNT_WIDTH` | parameter | 8 | 计数器位宽 |
| `CNT_MAX` | parameter | `(1<<CNT_WIDTH)-1` | 计数上限 |
| `CNT_MIN` | parameter | 0 | 计数下限 |
| `CNT_MODE` | parameter | `"FREE"` | 模式：`"FREE"` / `"MODULO"` / `"UPDOWN"` |
| `LOAD_EN` | parameter | 1 | 外部加载使能 |
| `TC_AT_MAX` | parameter | 1 | tc 信号产生位置：1=到达 MAX 时，0=到达 0 时 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `en` | I | 1 | clk | 计数使能 |
| `load` | I | 1 | clk | 加载使能 |
| `load_val` | I | `CNT_WIDTH` | clk | 加载值 |
| `clr` | I | 1 | clk | 同步清零 |
| `cnt` | O | `CNT_WIDTH` | clk | 当前计数值 |
| `tc` | O | 1 | clk | 终点标志（Terminal Count） |
| `zero` | O | 1 | clk | 零标志 |

---

## 时序

### FREE 模式（自由计数）

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
en        ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
cnt       ___| 0 | 1 | 2 | 3 | 4 | 5 | 6 |
tc        _____________________________|‾‾‾  (达到 MAX)
```

### MODULO 模式（模 N 计数）

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
en        ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
cnt       ___| 0 | 1 | 2 | 3 | 0 | 1 | 2 |  (MAX=3, 自动回 0)
tc        _____________|‾|___________|‾|
```

### UPDOWN 模式（上下计数）

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
en        ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
up_down   ___|‾‾‾‾‾‾‾‾‾‾‾‾|_______________
cnt       ___| 0 | 1 | 2 | 3 | 2 | 1 | 0 |  (上计数到 MAX，下计数到 0)
tc        _____________|‾|_____|‾|_________  (到达上下限时)
```

### 加载与清零

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__
en        ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
load      _________|‾|_______________
load_val  _________|10|______________
cnt       ___| 0 | 1 |10 | 11| 12|__
clr       _______________|‾|_________
cnt       ___________________| 0 | 1 |
```

---

## 用法

### 波特率生成

```verilog
// 115200 baud @ 50MHz: 计数值 = 50M/(16*115200) - 1 = 26
counter #(
    .CNT_WIDTH (8),
    .CNT_MODE  ("MODULO"),
    .CNT_MAX   (26)
) u_baud_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (1'b1),
    .tc    (baud_tick),
    .cnt   ()
);
```

### 突发传输计数

```verilog
// AXI 突发传输 beat 计数
counter #(
    .CNT_WIDTH (8),
    .CNT_MODE  ("MODULO"),
    .CNT_MAX   (burst_len - 1),
    .LOAD_EN   (1)
) u_beat_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .en       (axi_valid && axi_ready),
    .load     (burst_start),
    .load_val (8'd0),
    .tc       (burst_last_beat),
    .cnt      (beat_count)
);
```

### 超时检测

```verilog
// 超时计数器，达到上限拉高超时标志
counter #(
    .CNT_WIDTH (16),
    .CNT_MODE  ("FREE"),
    .CNT_MAX   (16'hFFFF),
    .TC_AT_MAX (1)
) u_timeout_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (waiting),
    .clr   (response_received),
    .tc    (timeout_flag),
    .cnt   (timeout_count)
);
```

---

## 关键实现细节

- **FREE**：`cnt <= cnt + 1`，到 MAX 后停在 MAX
- **MODULO**：`cnt <= (cnt >= CNT_MAX) ? CNT_MIN : cnt + 1`，自动回绕
- **UPDOWN**：内部 `direction` 寄存器，到 MAX 翻转为下，到 MIN 翻转为上
- **tc**：到达计数终点时拉高 1 周期（`en && cnt == CNT_MAX` 或 `en && cnt == CNT_MIN`）
- **zero**：`cnt == 0` 时持续拉高
- **优先级**：`clr` > `load` > `en`
- **复位**：计数器复位为 CNT_MIN
