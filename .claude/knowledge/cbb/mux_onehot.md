# mux_onehot — 独热码多路选择器

> **用途**：使用独热选择信号从多个数据输入中选择一个输出
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

独热码多路选择器使用独热码（One-Hot）选择信号代替二进制编码选择，避免了二进制到独热码的译码延迟。在高速数据通路中，独热选择可减少 MUX 逻辑级数。常用于仲裁结果直连 MUX、流水线数据选择等场景。

```
data_0 ──┐
data_1 ──┤──> ┌─────────────┐ ──data_out──> 被选数据
data_2 ──┤    │ mux_onehot   │
data_3 ──┘    └─────────────┘
sel[3:0]──>    ↑ sel[2]=1 → 输出 data_2
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_PORTS` | parameter | 4 | 输入端口数 |
| `DATA_WIDTH` | parameter | 32 | 数据位宽 |
| `PIPE_EN` | parameter | 0 | 输出寄存器使能 |
| `DEFAULT_VAL` | parameter | `0` | 无有效选择时的默认输出值 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `data_in` | I | `NUM_PORTS × DATA_WIDTH` | clk | 数据输入（拼接） |
| `sel` | I | `NUM_PORTS` | clk | 独热选择信号 |
| `data_out` | O | `DATA_WIDTH` | clk | 被选数据输出 |
| `sel_valid` | O | 1 | clk | 选择有效（sel 不全 0） |

> **注意**：sel 必须保证至多 1 bit 有效（独热约束），否则输出不确定。

---

## 时序

```
clk       __|‾|__|‾|__|‾|__|‾|__
data_in   ___|D0|D1|D2|D3__________
sel       ___|0001|0010|0100|1000___
data_out  _______|D0___|D1___|D2___  (组合逻辑或寄存器输出)
sel_valid _______|‾‾‾‾‾|‾‾‾‾‾|‾‾‾‾‾|
```

---

## 用法

### 仲裁器结果直连 MUX

```verilog
// 仲裁器输出独热 grant，直接连接 MUX 选择
mux_onehot #(
    .NUM_PORTS (4),
    .DATA_WIDTH(64)
) u_arb_mux (
    .clk      (clk),
    .rst_n    (rst_n),
    .data_in  ({dma3_data, dma2_data, dma1_data, dma0_data}),
    .sel      (grant),             // 独热 grant 信号
    .data_out (selected_data),
    .sel_valid(grant_valid)
);

// 相比 bin2onehot + case MUX，省去编码+解码两级逻辑
```

### 流水线级间选择

```verilog
mux_onehot #(
    .NUM_PORTS (3),
    .DATA_WIDTH(128),
    .PIPE_EN   (1)                 // 输出寄存一拍
) u_pipe_mux (
    .clk      (clk),
    .rst_n    (rst_n),
    .data_in  ({stage2_data, stage1_data, stage0_data}),
    .sel      (pipe_valid),
    .data_out (mux_out),
    .sel_valid()
);
```

### 带默认值的选择器

```verilog
mux_onehot #(
    .NUM_PORTS   (8),
    .DATA_WIDTH  (32),
    .DEFAULT_VAL (32'hDEADBEEF)    // 无选择时输出默认值
) u_default_mux (
    .clk      (clk),
    .rst_n    (rst_n),
    .data_in  ({d7, d6, d5, d4, d3, d2, d1, d0}),
    .sel      (port_sel),
    .data_out (mux_data),
    .sel_valid(sel_valid)
);
```

---

## 关键实现细节

- **核心逻辑**：`data_out = (sel[0] & data_0) | (sel[1] & data_1) | ...`
- **单级逻辑**：独热选择只需一级 AND-OR 门，比二进制选择器（需要解码+多级 MUX）快
- **拼接输入**：data_in 按 `{data_N-1, ..., data_1, data_0}` 顺序拼接
- **PIPE_EN=1**：输出加一级寄存器，改善时序
- **面积**：NUM_PORTS × DATA_WIDTH 个 AND 门 + DATA_WIDTH 个 OR 树
- **独热约束**：sel 必须保证最多 1 bit 有效，可用 SVA 检测
- **综合优化**：综合工具通常将 AND-OR 推断为 MUX primitives
