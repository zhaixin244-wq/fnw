# clk_gating — 集成时钟门控单元

> **用途**：标准 ICG（Integrated Clock Gating）单元包装，用于动态时钟门控省功耗
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

集成时钟门控单元（ICG）使用标准单元库中的 Latch-based clock gating cell 替代直接门控时钟（`assign gated = clk & en`），避免毛刺和 DFT 问题。内部使用低电平锁存器在时钟低电平时锁存使能信号，确保使能变化只发生在时钟低电平时，gated_clk 输出无毛刺。用于 SoC 动态功耗管理，空闲模块关闭时钟省电。

```
clk ──> ┌──────────────┐
en  ──> │  clk_gating  │ ──> gated_clk
scan_en─>│  (ICG cell)  │
         └──────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `ICG_CELL` | parameter | `"CKLNQD1"` | 标准单元库 ICG cell 名称 |
| `TECH_NODE` | parameter | `"GENERIC"` | 工艺节点：`"GENERIC"` / `"TSMC7"` / `"SAMSUNG5"` |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_in` | I | 1 | - | 输入时钟 |
| `en` | I | 1 | - | 时钟使能（高有效，门控时钟） |
| `scan_en` | I | 1 | - | DFT 扫描使能（测试模式强制开时钟） |
| `clk_out` | O | 1 | - | 门控后时钟输出 |

---

## 时序

### 正常操作

```
clk_in    __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
en        _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|
latch_en  _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|  (低电平锁存，无毛刺)
clk_out   __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|_  (en=1 时正常输出)
                              ↑ en 拉低后
clk_out   __|‾|__|‾|__|‾|_____________|_______  (gated，输出恒低)
```

### DFT 扫描模式

```
clk_in    __|‾|__|‾|__|‾|__|‾|__|‾|__
scan_en   _____________|‾‾‾‾‾‾‾‾‾‾‾‾‾
en        _____________|_____________
clk_out   __|‾|__|‾|__|‾|__|‾|__|‾|__  (scan_en 强制开时钟)
```

### 毛刺防护

```
clk_in    __|‾|__|‾|__|‾|__|‾|__
en        _____|_|‾|_|‾‾‾‾‾‾‾‾‾  (en 有毛刺)
latch_en  _________|‾‾‾‾‾‾‾‾‾‾‾  (锁存后无毛刺)
clk_out   __|‾|__|‾|__|‾|__|‾|__  (输出无毛刺)
```

---

## 用法

### 模块级时钟门控

```verilog
// UART 模块时钟门控
clk_gating #(
    .ICG_CELL("CKLNQD1")
) u_uart_cg (
    .clk_in   (clk),
    .en       (uart_active),
    .scan_en  (scan_en),
    .clk_out  (gated_uart_clk)
);

// UART 模块使用 gated_clk
always @(posedge gated_uart_clk or negedge rst_n) begin
    if (!rst_n)
        uart_reg <= 1'b0;
    else
        uart_reg <= uart_next;
end
```

### 多级时钟门控

```verilog
// 系统级 → 子系统级 → 模块级
clk_gating u_sys_cg (.clk_in(clk_pll), .en(sys_active),   .scan_en(se), .clk_out(clk_sys));
clk_gating u_sub_cg (.clk_in(clk_sys), .en(sub_active),   .scan_en(se), .clk_out(clk_sub));
clk_gating u_mod_cg (.clk_in(clk_sub), .en(mod_active),   .scan_en(se), .clk_out(clk_mod));
```

### 片选式时钟门控

```verilog
// 8 个通道，每个通道独立门控
genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin : gen_ch_cg
        clk_gating u_ch_cg (
            .clk_in   (clk),
            .en       (ch_active[i]),
            .scan_en  (scan_en),
            .clk_out  (gated_ch_clk[i])
        );
    end
endgenerate
```

### 功耗管理状态机配合

```verilog
// 低功耗状态机控制门控
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pwr_state <= PWR_ACTIVE;
    else
        pwr_state <= pwr_next;
end

assign module_clk_en = (pwr_state == PWR_ACTIVE);

clk_gating u_pwr_cg (
    .clk_in   (clk),
    .en       (module_clk_en),
    .scan_en  (scan_en),
    .clk_out  (gated_clk)
);
```

---

## 关键实现细节

- **Latch 结构**：en 信号通过低电平锁存器（DLHQN1）锁存，消除毛刺
  ```verilog
  // 内部结构（示意）
  wire en_latched;
  DLHQN1 u_latch (.D(en), .G(!clk_in), .Q(en_latched));
  assign clk_out = clk_in & (en_latched | scan_en);
  ```
- **扫描使能优先**：scan_en=1 时强制开时钟，保证 DFT 扫描链正常工作
- **门控粒度**：建议至少以模块级为单位门控，过细粒度增加时钟树复杂度
- **综合约束**：`set_clock_gating_style` 告诉综合工具自动插入 ICG
- **面积**：1 个 ICG cell ≈ 6-8 GE（含锁存器+AND门+OR门）
- **功耗节省**：门控后该时钟树上的所有寄存器动态功耗降为 0
- **注意**：门控时钟不能直接 assign，必须通过标准 ICG cell，否则有毛刺风险
