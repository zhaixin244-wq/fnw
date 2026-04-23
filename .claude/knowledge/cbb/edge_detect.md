# edge_detect — 边沿检测器

> **用途**：检测信号的上升沿、下降沿或双边沿，产生单周期脉冲
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

边沿检测器通过比较信号当前值与上一周期值，检测信号跳变并产生单周期脉冲。常用于中断检测、握手协议起始判断、状态切换触发等场景。

```
signal ──> ┌─────────────┐ ──rise_pulse──> 上升沿脉冲
           │ edge_detect  │ ──fall_pulse──> 下降沿脉冲
           └─────────────┘ ──any_pulse ──> 双边沿脉冲
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `WIDTH` | parameter | 1 | 检测信号位宽 |
| `EDGE_TYPE` | parameter | `"RISING"` | 检测类型：`"RISING"` / `"FALLING"` / `"BOTH"` |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `signal_in` | I | `WIDTH` | clk | 待检测信号（**必须是寄存器输出**） |
| `rise_pulse` | O | `WIDTH` | clk | 上升沿脉冲（EDGE_TYPE=RISING/BOTH） |
| `fall_pulse` | O | `WIDTH` | clk | 下降沿脉冲（EDGE_TYPE=FALLING/BOTH） |
| `any_pulse` | O | `WIDTH` | clk | 双边沿脉冲（EDGE_TYPE=BOTH） |

---

## 时序

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
signal_in   _______|‾‾‾‾‾‾‾‾‾‾‾‾|___________
signal_d1   ___________|‾‾‾‾‾‾‾‾‾‾‾‾|________  (延迟1周期)
rise_pulse  ___________|‾|____________________  (signal_in && !signal_d1)
fall_pulse  _______________________|‾|________  (!signal_in && signal_d1)
any_pulse   ___________|‾|_________|‾|________  (signal_in ^ signal_d1)
```

- **延迟**：1 个时钟周期（寄存器采样）
- **脉冲宽度**：恒定 1 周期
- **要求**：`signal_in` 必须是寄存器输出，否则可能产生毛刺脉冲

---

## 用法

### 上升沿检测

```verilog
// 检测中断信号上升沿
edge_detect #(
    .WIDTH    (1),
    .EDGE_TYPE("RISING")
) u_irq_edge (
    .clk        (clk),
    .rst_n      (rst_n),
    .signal_in  (irq_reg),
    .rise_pulse (irq_pulse)
);
```

### 双边沿检测

```verilog
// 检测 I2C SCL 边沿
edge_detect #(
    .WIDTH    (1),
    .EDGE_TYPE("BOTH")
) u_scl_edge (
    .clk        (clk),
    .rst_n      (rst_n),
    .signal_in  (scl_synced),
    .rise_pulse (scl_rise),
    .fall_pulse (scl_fall),
    .any_pulse  (scl_edge)
);
```

### 多 bit 边沿检测

```verilog
// 检测 4 位状态信号变化
edge_detect #(
    .WIDTH    (4),
    .EDGE_TYPE("BOTH")
) u_status_edge (
    .clk        (clk),
    .rst_n      (rst_n),
    .signal_in  (status_reg),
    .rise_pulse (status_rise),
    .fall_pulse (status_fall),
    .any_pulse  (status_changed)
);
```

---

## 关键实现细节

- **核心逻辑**：`signal_d1` 寄存器保存上一周期值，组合逻辑比较产生脉冲
- **rise_pulse** = `signal_in & ~signal_d1`
- **fall_pulse** = `~signal_in & signal_d1`
- **any_pulse** = `signal_in ^ signal_d1`
- **复位**：`signal_d1` 复位为 0，复位释放后的第一个上升沿不会丢失
- **多 bit 模式**：每位独立检测，输出位宽与输入一致
