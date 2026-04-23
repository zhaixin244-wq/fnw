# wide_entry_wr — 宽表项写入器

> **用途**：将窄位宽数据流合并写入宽位宽表项，支持多周期填充和原子提交
> **可综合**：是
> **语言** : Verilog

---

## 模块概述

宽表项写入器解决"窄数据写宽表"问题：输入数据位宽小于表项位宽时，需要多次写入合并为一个完整表项。支持两种模式：**累加模式**（连续拍次拼接）和**字节使能模式**（按 byte enable 选择写入字节）。写入完成后产生原子提交信号，保证表项数据一致性。用于 TCAM 表项写入、路由表更新、配置寄存器组写入、SRAM 行填充等场景。

```
窄数据 (32b) × 4拍 ──> ┌──────────────┐ ──> 宽表项 (128b)
                       │ wide_entry_wr │ ──> wr_valid（原子提交）
                       └──────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `IN_WIDTH` | parameter | 32 | 输入数据位宽 |
| `ENTRY_WIDTH` | parameter | 128 | 表项位宽（必须为 IN_WIDTH 的整数倍） |
| `NUM_BEATS` | localparam | `ENTRY_WIDTH / IN_WIDTH` | 合并拍数 |
| `WR_MODE` | parameter | `"ACCUMULATE"` | 写入模式：`"ACCUMULATE"` / `"BYTE_ENABLE"` |
| `WR_ORDER` | parameter | `"LSB_FIRST"` | 拍序：`"LSB_FIRST"` = 低字先写，`"MSB_FIRST"` = 高字先写 |
| `PIPE_EN` | parameter | 0 | 输出流水线寄存器 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `in_data` | I | `IN_WIDTH` | clk | 输入窄数据 |
| `in_valid` | I | 1 | clk | 输入有效 |
| `in_strb` | I | `IN_WIDTH/8` | clk | 字节使能（BYTE_ENABLE 模式） |
| `in_last` | I | 1 | clk | 最后一拍标记 |
| `in_ready` | O | 1 | clk | 接收就绪 |
| `entry_out` | O | `ENTRY_WIDTH` | clk | 合并后的宽表项 |
| `wr_valid` | O | 1 | clk | 表项写入完成（原子提交） |
| `wr_strb` | O | `ENTRY_WIDTH/8` | clk | 表项字节使能掩码 |
| `beat_cnt` | O | `$clog2(NUM_BEATS)` | clk | 当前拍计数（调试） |

---

## 时序

### 累加模式（IN=32, ENTRY=128, 4 拍）

```
clk         __|‾|__|‾|__|__|__|__|__|__|__|__|‾|__|‾|__|__
in_data     ___|W0___|W1___|W2___|W3___|W0___|W1___|
in_valid    ___|‾‾‾‾‾|‾‾‾‾‾|‾‾‾‾‾|‾‾‾‾‾|‾‾‾‾‾|‾‾‾‾‾|
in_last     _________________|‾‾‾‾‾|_______________|‾‾‾‾‾|
beat_cnt    _________| 0 | 1 | 2 | 3 | 0 | 1 |_______|
entry_out   _____________________________|W3|W2|W1|W0________
wr_valid    _________________________________| ‾ |___________
              ↑ 4 拍拼接完成，原子提交
```

### 字节使能模式

```
clk         __|‾|__|‾|__|__|__|__|__|‾|__|__
in_data     ___|D0______|D1______|D2______|
in_strb     ___|4'b1111_|4'b0011_|4'b1100_|
in_valid    ___|‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾|
in_last     ___________________________|‾‾‾‾|
entry_out   ___________________________|{D2_lo|D1_lo|D0}|___
wr_strb     ___________________________|16'b1111_0011_1111|__
wr_valid    _______________________________| ‾ |_____________
              ↑ 有效字节拼接，BE 控制每个字节
```

---

## 用法

### TCAM 表项写入

```verilog
// TCAM 规则表项 256-bit，总线 32-bit，需 8 拍写入
wide_entry_wr #(
    .IN_WIDTH   (32),
    .ENTRY_WIDTH(256),
    .WR_MODE    ("ACCUMULATE"),
    .WR_ORDER   ("MSB_FIRST")
) u_tcam_wr (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_data    (axi_wdata),
    .in_valid   (axi_wvalid && !full),
    .in_strb    (4'hF),
    .in_last    (beat_last),
    .in_ready   (wr_ready),
    .entry_out  (tcam_entry),
    .wr_valid   (tcam_wr_en),
    .wr_strb    (),
    .beat_cnt   ()
);

// 写入 TCAM
always @(posedge clk) begin
    if (tcam_wr_en)
        tcam_ram[wr_addr] <= tcam_entry;
end
```

### 路由表行填充

```verilog
// 路由表行宽 128-bit，AXI 64-bit 数据总线
wide_entry_wr #(
    .IN_WIDTH   (64),
    .ENTRY_WIDTH(128),
    .WR_MODE    ("ACCUMULATE"),
    .WR_ORDER   ("LSB_FIRST")
) u_route_fill (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_data    (m_axi_rdata),
    .in_valid   (m_axi_rvalid),
    .in_strb    (8'hFF),
    .in_last    (m_axi_rlast),
    .in_ready   (fill_ready),
    .entry_out  (route_entry),
    .wr_valid   (route_wr),
    .wr_strb    (),
    .beat_cnt   ()
);
```

### 配置寄存器组字节写入

```verilog
// 128-bit 配置寄存器，支持按字节更新
wide_entry_wr #(
    .IN_WIDTH   (32),
    .ENTRY_WIDTH(128),
    .WR_MODE    ("BYTE_ENABLE"),
    .WR_ORDER   ("LSB_FIRST")
) u_cfg_wr (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_data    (cfg_wdata),
    .in_valid   (cfg_wr),
    .in_strb    (cfg_wstrb),
    .in_last    (cfg_last),
    .in_ready   (cfg_ready),
    .entry_out  (cfg_entry_new),
    .wr_valid   (cfg_update),
    .wr_strb    (cfg_byte_mask),      // 哪些字节被更新
    .beat_cnt   ()
);

// 部分更新：只修改被写的字节
assign cfg_entry_final = (cfg_entry_prev & ~cfg_byte_mask_ext)
                       | (cfg_entry_new   &  cfg_byte_mask_ext);
```

### SRAM 行缓存填充

```verilog
// Cache line 填充：DDR 64-bit → SRAM 512-bit
wide_entry_wr #(
    .IN_WIDTH   (64),
    .ENTRY_WIDTH(512),
    .WR_MODE    ("ACCUMULATE"),
    .WR_ORDER   ("LSB_FIRST")
) u_cache_fill (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_data    (ddr_rdata),
    .in_valid   (ddr_rvalid),
    .in_strb    (8'hFF),
    .in_last    (ddr_rlast),
    .in_ready   (fill_ready),
    .entry_out  (cache_line_data),
    .wr_valid   (cache_line_wr),
    .wr_strb    (),
    .beat_cnt   ()
);
```

---

## 关键实现细节

- **累加寄存器**：ENTRY_WIDTH 位移位寄存器，每拍移入 IN_WIDTH 位数据
- **LSB_FIRST**：低字先入，拼接为 `{W3, W2, W1, W0}`
- **MSB_FIRST**：高字先入，拼接为 `{W0, W1, W2, W3}`
- **原子提交**：最后一拍（in_last 或 beat_cnt==NUM_BEATS-1）时 wr_valid 拉高
- **BYTE_ENABLE 模式**：每拍按 in_strb 选择写入字节，拼接时保留旧数据
- **in_ready**：内部有 1-entry 缓冲时拉高，防止背压丢数据
- **乱序保护**：in_last 提前或延迟时报警（可选 SVA）
- **面积**：ENTRY_WIDTH 个触发器 + 拼接 MUX + 控制状态机
