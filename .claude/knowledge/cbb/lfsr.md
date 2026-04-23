# lfsr — 线性反馈移位寄存器

> **用途**：伪随机数生成、CRC 计算、测试向量生成、扰码/解扰
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

线性反馈移位寄存器（LFSR）通过移位和异或反馈产生伪随机序列。支持 Galois（并行）和 Fibonacci（串行）两种结构，可配置多项式（反馈点）。用于 BIST 内建自测试的伪随机向量生成、通信扰码/解扰、白噪声模拟、PRBS 测试码型生成等场景。

```
clk ──> ┌──────────┐ ──lfsr_out──> LFSR 值 / 伪随机输出
en  ──> │  lfsr    │ ──lfsr_bit──> 串行输出（Fibonacci）
load──> └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `LFSR_WIDTH` | parameter | 16 | LFSR 位宽 |
| `POLY` | parameter | `16'hB400` | 多项式（反馈配置，bit 位置表示异或反馈点） |
| `INIT` | parameter | `16'hACE1` | 初始种子（非零） |
| `LFSR_TYPE` | parameter | `"GALOIS"` | 结构：`"GALOIS"` = 并行，`"FIBONACCI"` = 串行 |
| `OUT_WIDTH` | parameter | `LFSR_WIDTH` | 输出位宽（可截取 LFSR 部分位输出） |

---

## 常用 LFSR 多项式

| 位宽 | 多项式 | PRBS 标准 | 最大周期 |
|------|--------|----------|---------|
| 8 | `8'hB8` | PRBS-8 | 255 |
| 16 | `16'hB400` | PRBS-16 | 65535 |
| 31 | `31'h48000000` | PRBS-31 | 2^31-1 |
| 32 | `32'hD0000001` | PRBS-32 | 2^32-1 |
| 7 | `7'h60` | PRBS-7 (PCIe/USB) | 127 |
| 15 | `15'h6000` | PRBS-15 | 32767 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `en` | I | 1 | clk | 移位使能 |
| `load` | I | 1 | clk | 加载种子 |
| `seed` | I | `LFSR_WIDTH` | clk | 种子值 |
| `lfsr_out` | O | `OUT_WIDTH` | clk | LFSR 输出值 |
| `lfsr_bit` | O | 1 | clk | 串行输出（Fibonacci 结构） |
| `equal_seed` | O | 1 | clk | 当前值等于种子（周期检测） |

---

## 时序

### Galois 结构（并行 LFSR）

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
en        ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
lfsr_out  ___|S0  |V1  |V2  |V3  |V4  |V5  |  (伪随机序列)
equal_seed_____|‾|___________________________  (周期末回到种子)
              ↑ 加载种子
```

### Fibonacci 结构（串行输出）

```
clk       __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
en        ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
lfsr_bit  ___|b0 |b1 |b2 |b3 |b4 |b5 |b6 |  (串行伪随机比特)
lfsr_out  ___|S0  |S1  |S2  |S3  |S4  |S5  |  (移位寄存器值)
```

---

## 用法

### BIST 伪随机测试向量

```verilog
lfsr #(
    .LFSR_WIDTH (32),
    .POLY       (32'hD0000001),
    .INIT       (32'h12345678),
    .LFSR_TYPE  ("GALOIS")
) u_bist_lfsr (
    .clk       (clk),
    .rst_n     (rst_n),
    .en        (bist_running),
    .load      (bist_start),
    .seed      (32'h12345678),
    .lfsr_out  (bist_pattern),
    .lfsr_bit  (),
    .equal_seed(bist_cycle_done)
);

// 伪随机数据输入被测模块
assign dut_test_data = bist_pattern[DATA_WIDTH-1:0];
```

### PRBS-7 测试码型（PCIe/SerDes）

```verilog
lfsr #(
    .LFSR_WIDTH (7),
    .POLY       (7'h60),
    .INIT       (7'h7F),
    .LFSR_TYPE  ("FIBONACCI"),
    .OUT_WIDTH  (1)
) u_prbs7 (
    .clk       (clk),
    .rst_n     (rst_n),
    .en        (1'b1),
    .load      (1'b0),
    .seed      (7'h7F),
    .lfsr_out  (),
    .lfsr_bit  (prbs7_bit),       // 串行 PRBS 输出
    .equal_seed()
);

// PRBS 发送端
assign tx_data = prbs7_bit;
```

### 通信扰码器

```verilog
lfsr #(
    .LFSR_WIDTH (16),
    .POLY       (16'hB400),
    .INIT       (16'hFFFF),
    .LFSR_TYPE  ("GALOIS")
) u_scrambler (
    .clk       (clk),
    .rst_n     (rst_n),
    .en        (data_valid),
    .load      (frame_start),
    .seed      (16'hFFFF),
    .lfsr_out  (scramble_bits),
    .lfsr_bit  (),
    .equal_seed()
);

// 扰码：数据 XOR LFSR
assign scrambled_data = tx_data ^ scramble_bits[DATA_WIDTH-1:0];
```

---

## 关键实现细节

- **Galois（并行）**：每个 bit 可以异或反馈，单周期完成移位+反馈，速度快
- **Fibonacci（串行）**：只在 LSB 引入反馈，逐 bit 移位，适合串行输出
- **最大周期**：选择正确的多项式，LFSR 周期 = 2^LFSR_WIDTH - 1（全 0 排除）
- **POLY 格式**：bit 位置表示异或反馈点，如 16'hB400 = bit[15,13,12,10]
- **种子不能为全 0**：全 0 状态会永远锁死
- **equal_seed**：检测周期结束，`lfsr_out == seed` 时拉高
- **扰码/解扰**：同构 LFSR 接收端再次 XOR 即可还原
- **面积**：LFSR_WIDTH 个触发器 + XOR 门（数量 = POLY 中 1 的个数）
