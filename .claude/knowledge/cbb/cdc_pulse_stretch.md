# cdc_pulse_stretch — CDC 脉冲展宽同步器

> **用途**：将源时钟域的窄脉冲展宽后安全传递到目标时钟域
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

CDC 脉冲展宽同步器解决跨时钟域窄脉冲同步问题。当源域脉冲宽度小于目标域时钟周期时，标准 2FF 同步器可能完全丢失脉冲。本模块先在源域展宽脉冲（至少保持到目标域可以采到），再通过 2FF 同步器传递到目标域，最后在目标域产生单周期脉冲。

```
src_clk 域                                  dst_clk 域
pulse_src ──> ┌──────────────────────┐ ──> pulse_dst
              │ cdc_pulse_stretch    │
              └──────────────────────┘
     窄脉冲 → 展宽 → 2FF同步 → 边沿检测 → 单周期脉冲
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `SYNC_STAGES` | parameter | 2 | 同步器级数 |
| `STRETCH_CYCLES` | parameter | 3 | 展宽周期数（≥ dst_clk / src_clk 比值 + 2） |
| `EDGE_TYPE` | parameter | `"RISING"` | 触发：`"RISING"` = 上升沿触发，`"LEVEL"` = 电平触发 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_src` | I | 1 | - | 源时钟域 |
| `rst_src_n` | I | 1 | - | 源域异步复位 |
| `clk_dst` | I | 1 | - | 目标时钟域 |
| `rst_dst_n` | I | 1 | - | 目标域异步复位 |
| `pulse_src` | I | 1 | clk_src | 源域脉冲输入 |
| `pulse_dst` | O | 1 | clk_dst | 目标域单周期脉冲输出 |
| `busy` | O | 1 | clk_src | 展宽/同步中（源域） |

---

## 时序

### 快域到慢域

```
clk_src     __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
pulse_src   _____|‾|_______________________________  (单周期窄脉冲)
stretch_reg _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_______________  (展宽 3 周期)
busy        _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_______________

clk_dst     ___|‾|___|‾|___|‾|___|‾|___|‾|___|‾|___
sync_dst    _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (2FF 同步)
pulse_dst   _________________________|‾|___________  (边沿检测)
```

### 慢域到快域

```
clk_src     __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
pulse_src   _____|‾|_______________________
stretch_reg _____|‾‾‾‾‾‾‾‾‾‾‾‾|____________  (展宽足够长)

clk_dst     ___|‾|___|‾|___|‾|___|‾|___|‾|___
sync_dst    _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (同步)
pulse_dst   _____________|‾|_______________  (脉冲)
```

### 连续脉冲（间隔不足）

```
clk_src     __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
pulse_src   _____|‾|___|‾|__________________  (两个脉冲太近)
busy        _____|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________
                    ↑ 第二个脉冲被忽略（busy 期间）
```

---

## 用法

### 中断信号跨域

```verilog
// 快域中断脉冲同步到慢域
cdc_pulse_stretch #(
    .SYNC_STAGES   (2),
    .STRETCH_CYCLES(4),       // src 比 dst 快 ≤ 4 倍
    .EDGE_TYPE     ("RISING")
) u_irq_sync (
    .clk_src   (clk_fast),
    .rst_src_n (rst_fast_n),
    .clk_dst   (clk_slow),
    .rst_dst_n (rst_slow_n),
    .pulse_src (fast_irq),
    .pulse_dst (slow_irq),
    .busy      (irq_sync_busy)
);
```

### 触发信号传递

```verilog
// ADC 采样触发从控制域传递到 ADC 时钟域
cdc_pulse_stretch #(
    .SYNC_STAGES   (3),       // 高可靠性
    .STRETCH_CYCLES(6),
    .EDGE_TYPE     ("RISING")
) u_adc_trig (
    .clk_src   (clk_ctrl),
    .rst_src_n (rst_ctrl_n),
    .clk_dst   (clk_adc),
    .rst_dst_n (rst_adc_n),
    .pulse_src (adc_start),
    .pulse_dst (adc_sample_trig),
    .busy      ()
);
```

### DMA 完成通知

```verilog
cdc_pulse_stretch #(
    .SYNC_STAGES   (2),
    .STRETCH_CYCLES(8),       // 安全裕量
    .EDGE_TYPE     ("LEVEL")  // 电平触发更安全
) u_dma_done (
    .clk_src   (clk_dma),
    .rst_src_n (rst_dma_n),
    .clk_dst   (clk_cpu),
    .rst_dst_n (rst_cpu_n),
    .pulse_src (dma_done),
    .pulse_dst (dma_done_irq),
    .busy      ()
);
```

---

## 关键实现细节

- **展宽**：src 域脉冲触发一个 STRETCH_CYCLES 周期的计数器，stretch_reg 在计数期间保持高
- **2FF 同步**：stretch_reg 通过双触发器同步到 dst 域
- **边沿检测**：dst 域对 sync_dst 做边沿检测产生单周期脉冲
- **busy 保护**：展宽期间忽略新的 pulse_src 输入，防止脉冲丢失
- **STRETCH_CYCLES 选择**：必须 ≥ dst 最慢周期 / src 最快周期 + 2（裕量）
- **面积**：STRETCH_CYCLES 计数器 + SYNC_STAGES 触发器 + 边沿检测，约 10-20 触发器
- **相比 sync_pulse 优势**：展宽版本对源域脉冲宽度无要求（可为任意宽度），更适合非周期触发
