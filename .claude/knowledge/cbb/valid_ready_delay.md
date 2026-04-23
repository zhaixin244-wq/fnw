# valid_ready_delay — Valid/Ready 延迟模块

> **用途**：在 Valid/Ready 握手路径中插入可配置延迟，用于时序调整或协议转换
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

Valid/Ready 延迟模块在 Valid/Ready 握手信号路径中插入 N 级寄存器，实现可配置的传输延迟。数据跟随 valid 同步延迟，ready 反压路径可选是否延迟。用于时序对齐、协议转换、仿真测试等场景。

```
上游(Master) ──valid/data──> ┌──────────────────┐ ──valid/data──> 下游(Slave)
                             │ valid_ready_delay  │
                             │ (delay = N cycles) │
上游(Master) <──ready─────── └──────────────────┘ <──ready────── 下游(Slave)
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽 |
| `VALID_DELAY` | parameter | 1 | valid/data 延迟级数 |
| `READY_DELAY` | parameter | 0 | ready 反压延迟级数（0=不延迟） |
| `FULL_HANDSHAKE` | parameter | 1 | 完整握手模式：1=valid 和 ready 都就绪才传递 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `s_valid` | I | 1 | clk | 上游 valid |
| `s_ready` | O | 1 | clk | 上游 ready（反压） |
| `s_data` | I | `DATA_WIDTH` | clk | 上游数据 |
| `m_valid` | O | 1 | clk | 下游 valid |
| `m_ready` | I | 1 | clk | 下游 ready（反压） |
| `m_data` | O | `DATA_WIDTH` | clk | 下游数据 |

---

## 时序

### VALID_DELAY=1, READY_DELAY=0

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__
s_valid   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
s_data    ___| D1  | D2  | D3  | D4  |
s_ready   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (ready 不延迟，直通)
m_valid   _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (valid 延迟 1 cycle)
m_data    _________| D1  | D2  | D3  |   (数据延迟 1 cycle)
m_ready   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
```

### VALID_DELAY=2, READY_DELAY=1

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
s_valid   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
s_data    ___| D1  | D2  | D3  | D4  | D5  |
s_ready   _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (ready 延迟 1 cycle)
m_valid   _____________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (valid 延迟 2 cycles)
m_data    _____________| D1  | D2  | D3  |   (数据延迟 2 cycles)
m_ready   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (下游 ready 直通)
```

---

## 用法

### 时序对齐

```verilog
// 在数据通路中插入 2 周期延迟，与控制信号对齐
valid_ready_delay #(
    .DATA_WIDTH   (64),
    .VALID_DELAY  (2),
    .READY_DELAY  (0)
) u_timing_align (
    .clk      (clk),
    .rst_n    (rst_n),
    .s_valid  (data_valid),
    .s_ready  (data_ready),
    .s_data   (data_in),
    .m_valid  (data_valid_d2),
    .m_ready  (data_ready_d2),
    .m_data   (data_out_d2)
);
```

### 仿真延迟注入

```verilog
// 仿真中模拟长路径延迟
valid_ready_delay #(
    .DATA_WIDTH   (32),
    .VALID_DELAY  (5),
    .READY_DELAY  (3)
) u_sim_delay (
    .clk      (clk),
    .rst_n    (rst_n),
    .s_valid  (src_valid),
    .s_ready  (src_ready),
    .s_data   (src_data),
    .m_valid  (dst_valid),
    .m_ready  (dst_ready),
    .m_data   (dst_data)
);
```

### 背压路径延迟

```verilog
// 模拟反压路径较长的场景
valid_ready_delay #(
    .DATA_WIDTH   (128),
    .VALID_DELAY  (1),
    .READY_DELAY  (2)      // 反压信号延迟 2 cycle
) u_backpressure_delay (
    .clk      (clk),
    .rst_n    (rst_n),
    .s_valid  (in_valid),
    .s_ready  (in_ready),
    .s_data   (in_data),
    .m_valid  (out_valid),
    .m_ready  (out_ready),
    .m_data   (out_data)
);
```

---

## 关键实现细节

- **VALID 延迟**：valid 和 data 通过 N 级触发器链同步延迟
- **READY 延迟**：ready 信号可选通过 M 级触发器链反向延迟
- **FULL_HANDSHAKE=1**：内部 FIFO 缓冲 valid 和 data，ready 反压正确传递
- **FULL_HANDSHAKE=0**：简单寄存器链，valid 保持期间 ready 反压可能丢数据
- **复位**：所有寄存器复位为 0
- **面积**：VALID_DELAY × (1 + DATA_WIDTH) 触发器 + READY_DELAY × 1 触发器
- **注意**：VALID_DELAY 过大时需要内部缓冲防止 valid 保持期间数据被覆盖
