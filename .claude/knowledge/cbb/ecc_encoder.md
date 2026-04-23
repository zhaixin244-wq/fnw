# ecc_encoder — ECC 编码器

> **用途**：对数据生成 SECDED（单纠错双检错）ECC 校验位
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

ECC 编码器实现海明码（Hamming Code）扩展的 SECDED（Single Error Correction, Double Error Detection）编码。输入 N 位数据，输出 N+K+1 位（K 为校验位数，+1 为总奇偶校验位）。用于 SRAM/DRAM 数据保护，防止存储器 SEU（单粒子翻转）导致的数据错误。

```
data_in[N-1:0] ──> ┌──────────────┐ ──> data_with_ecc[N+K:0]
                   │ ecc_encoder  │
                   └──────────────┘
        数据 → 海明编码 → 数据 + 校验位 + 总奇偶
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽 |
| `ECC_WIDTH` | localparam | 根据 DATA_WIDTH 自动计算 | ECC 校验位位宽 |
| `TOTAL_WIDTH` | localparam | `DATA_WIDTH + ECC_WIDTH + 1` | 总输出位宽（含总奇偶位） |

---

## 常用数据宽度对应 ECC 位宽

| 数据位宽 | ECC 位宽 | 总位宽 | 说明 |
|----------|----------|--------|------|
| 8 | 5 | 14 | 4 校验 + 1 总奇偶 |
| 16 | 6 | 23 | 5 校验 + 1 总奇偶 |
| 32 | 7 | 40 | 6 校验 + 1 总奇偶 |
| 64 | 8 | 73 | 7 校验 + 1 总奇偶 |
| 128 | 9 | 138 | 8 校验 + 1 总奇偶 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `data_in` | I | `DATA_WIDTH` | - | 输入数据 |
| `ecc_out` | O | `ECC_WIDTH` | - | ECC 校验位输出 |
| `parity_out` | O | 1 | - | 总奇偶校验位 |
| `data_with_ecc` | O | `TOTAL_WIDTH` | - | 数据+ECC 完整输出 |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

---

## 海明码编码原理

### 校验位位置

海明码中校验位占据 2^n 位置（1, 2, 4, 8, 16...），数据位填充其余位置。

```
位置: 1  2  3  4  5  6  7  8  9  10 11 ...
类型: P1 P2 D1 P4 D2 D3 D4 P8 D5 D6  D7 ...
```

### 校验位计算

- P1 = D1 ⊕ D2 ⊕ D4 ⊕ D5 ⊕ D7 ...（奇数位置数据位）
- P2 = D1 ⊕ D3 ⊕ D4 ⊕ D6 ⊕ D7 ...（校验位 2 覆盖的位置）
- P4 = D2 ⊕ D3 ⊕ D4 ⊕ ...
- 总奇偶 = D1 ⊕ D2 ⊕ ... ⊕ P1 ⊕ P2 ⊕ ...

### SECDED 能力

| 错误类型 | 检错 | 纠错 |
|----------|------|------|
| 无错 | 检测到 | - |
| 1-bit 错误 | 检测到 | **纠正** |
| 2-bit 错误 | 检测到 | 不可纠正 |
| 3-bit 错误 | 可能漏检 | 不可纠正 |

---

## 用法

### SRAM 写入时编码

```verilog
ecc_encoder #(
    .DATA_WIDTH (32)
) u_ecc_enc (
    .data_in        (wr_data),
    .ecc_out        (wr_ecc),
    .parity_out     (wr_parity),
    .data_with_ecc  (wr_data_with_ecc)
);

// 写入 SRAM：数据+ECC 一起存储
sram_write_data = {wr_parity, wr_ecc, wr_data};  // 40-bit 总线
```

### AXI 总线 ECC 保护

```verilog
ecc_encoder #(
    .DATA_WIDTH (64)
) u_wdata_ecc (
    .data_in        (m_axi_wdata),
    .ecc_out        (wdata_ecc),
    .parity_out     (wdata_parity),
    .data_with_ecc  ()
);

// ECC 位写入 ECC SRAM 或通过 sideband 传递
assign ecc_ram_wdata = {wdata_parity, wdata_ecc};
```

### 配置寄存器 ECC 保护

```verilog
ecc_encoder #(
    .DATA_WIDTH (16)
) u_cfg_ecc (
    .data_in        (cfg_reg),
    .ecc_out        (cfg_ecc),
    .parity_out     (cfg_parity),
    .data_with_ecc  (cfg_with_ecc)
);

// 定期校验配置寄存器完整性
assign cfg_integrity_ok = (recompute_ecc == cfg_ecc);
```

---

## 关键实现细节

- **编码算法**：每个校验位 P[i] 是其覆盖的所有数据位的异或
- **总奇偶位**：所有数据位和校验位的异或，用于区分 1-bit 和 2-bit 错误
- **纯组合逻辑**：无时钟延迟，输入到输出仅门延迟
- **编码延迟**：ECC_WIDTH 级 XOR 门（每个校验位需要多个 XOR 级联）
- **面积**：ECC_WIDTH × ~DATA_WIDTH/2 个 XOR 门
- **与 ecc_decoder 配对**：编码器生成校验位 → 存储 → 读出后解码器检测/纠错
- **数据位宽映射**：不同 DATA_WIDTH 的校验位计算公式不同，综合工具自动推断
- **面积开销**：32-bit 数据需 7 位 ECC = 22% 面积开销换取 SECDED 保护
