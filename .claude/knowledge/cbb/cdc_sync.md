# cdc_sync — 跨时钟域同步器

> **用途**：将信号从一个时钟域安全地传递到另一个时钟域
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

CDC（Clock Domain Crossing）同步器解决异步信号在不同时钟域之间传递时的亚稳态问题。提供三种同步方案：

| 方案 | 适用场景 | 延迟 |
|------|----------|------|
| **双触发器同步（2-FF Sync）** | 单 bit 控制信号 | 2 cycles |
| **脉冲同步（Pulse Sync）** | 单周期脉冲信号 | 3 cycles |
| **握手同步（Handshake Sync）** | 多 bit 数据通路 | 可变（≥3 cycles） |

```
src_clk 域 ──信号──> ┌──────────┐ ──同步后信号──> dst_clk 域
                     │ cdc_sync │
                     └──────────┘
```

---

## 子模块 A：双触发器同步器（sync_2ff）

### 参数

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `WIDTH` | 1 | 同步信号位宽（通常为 1） |
| `STAGES` | 2 | 同步器级数（2 或 3，推荐 2） |

### 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_dst` | I | 1 | - | 目标时钟域 |
| `rst_dst_n` | I | 1 | - | 目标域异步复位 |
| `data_src` | I | `WIDTH` | src_clk | 源域信号（**必须是寄存器输出**） |
| `data_dst` | O | `WIDTH` | clk_dst | 同步后的信号 |

### 时序

```
src_clk   __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
data_src  _______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
dst_clk   ___|‾|___|‾|___|‾|___|‾|___|‾|___
sync[0]   _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
sync[1]   _______________________|‾‾‾‾‾‾‾‾‾
data_dst  _______________________|‾‾‾‾‾‾‾‾‾
          ↑ src 信号变化 → 2 cycles 后 dst 域稳定
```

- **延迟**：2 个 dst_clk 周期
- **要求**：`data_src` 必须是 src_clk 域的寄存器输出（不能是组合逻辑）

### 用法

```verilog
// 单 bit 控制信号跨域
sync_2ff #(.WIDTH(1)) u_sync_en (
    .clk_dst    (clk_slow),
    .rst_dst_n  (rst_slow_n),
    .data_src   (fast_en_reg),    // 必须是寄存器输出
    .data_dst   (slow_en_synced)
);
```

---

## 子模块 B：脉冲同步器（sync_pulse）

### 参数

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `STAGES` | 2 | 同步器级数 |

### 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_src` | I | 1 | - | 源时钟域 |
| `rst_src_n` | I | 1 | - | 源域异步复位 |
| `clk_dst` | I | 1 | - | 目标时钟域 |
| `rst_dst_n` | I | 1 | - | 目标域异步复位 |
| `pulse_src` | I | 1 | clk_src | 源域单周期脉冲 |
| `pulse_dst` | O | 1 | clk_dst | 目标域单周期脉冲 |

### 时序

```
clk_src    __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
pulse_src  _____|‾|_________________________________  (单周期)
toggle_src _______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (翻转后保持)
clk_dst    ___|‾|___|‾|___|‾|___|‾|___|‾|___|‾|___
toggle_dst _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (2FF 同步)
pulse_dst  _________________________|‾|____________  (边沿检测)
```

- **原理**：src 脉冲 → toggle 翻转 → 2FF 同步 toggle → dst 边沿检测 → dst 脉冲
- **延迟**：3 个 dst_clk 周期
- **限制**：两个脉冲间隔必须 ≥ 3 个 dst_clk 周期，否则丢失

### 用法

```verilog
// 中断脉冲从快时钟域到慢时钟域
sync_pulse u_sync_irq (
    .clk_src    (clk_fast),
    .rst_src_n  (rst_fast_n),
    .clk_dst    (clk_slow),
    .rst_dst_n  (rst_slow_n),
    .pulse_src  (fast_irq_pulse),
    .pulse_dst  (slow_irq_pulse)
);
```

---

## 子模块 C：握手同步器（sync_handshake）

### 参数

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `DATA_WIDTH` | 32 | 数据位宽 |
| `STAGES` | 2 | 同步器级数 |

### 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_src` | I | 1 | - | 源时钟域 |
| `rst_src_n` | I | 1 | - | 源域异步复位 |
| `clk_dst` | I | 1 | - | 目标时钟域 |
| `rst_dst_n` | I | 1 | - | 目标域异步复位 |
| `data_src` | I | `DATA_WIDTH` | clk_src | 源数据 |
| `valid_src` | I | 1 | clk_src | 数据有效 |
| `ready_src` | O | 1 | clk_src | 握手完成 |
| `data_dst` | O | `DATA_WIDTH` | clk_dst | 目标数据 |
| `valid_dst` | O | 1 | clk_dst | 数据有效 |
| `ready_dst` | I | 1 | clk_dst | 目标就绪 |

### 时序

```
clk_src    __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
valid_src  _______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_________
data_src   _______| D1 (保持稳定)            |_________
ready_src  _____________________________|‾|___________
                                        ↑ 握手完成
clk_dst    ___|‾|___|‾|___|‾|___|‾|___|‾|___|‾|___
valid_dst  _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
data_dst   _________________| D1                  ‾‾
ready_dst  _________________________|‾‾‾‾‾‾‾‾‾‾‾‾‾
```

- **原理**：valid_src → toggle 同步 → valid_dst；ready_dst → toggle 同步 → ready_src
- **延迟**：可变，取决于两个时钟域的频率关系，最少 4 个慢时钟周期
- **吞吐**：较低（每次传输都需要完整握手往返）

### 用法

```verilog
// 多 bit 配置寄存器从配置域传递到工作域
sync_handshake #(.DATA_WIDTH(32)) u_sync_cfg (
    .clk_src    (clk_cfg),
    .rst_src_n  (rst_cfg_n),
    .clk_dst    (clk_core),
    .rst_dst_n  (rst_core_n),
    .data_src   (cfg_reg),
    .valid_src  (cfg_update),
    .ready_src  (cfg_done),
    .data_dst   (core_cfg),
    .valid_dst  (core_cfg_valid),
    .ready_dst  (core_cfg_ready)
);
```

---

## 方案选择指南

| 场景 | 推荐方案 | 理由 |
|------|----------|------|
| 单 bit 电平信号（enable/config） | 双触发器 | 最简单，延迟最低 |
| 单 bit 脉冲（中断/start） | 脉冲同步 | 保证脉冲不丢失 |
| 多 bit 数据（配置/状态） | 握手同步 | 安全传递多位数据 |
| 多 bit 高吞吐数据 | **异步 FIFO** | 见 `async_fifo`，吞吐最高 |
