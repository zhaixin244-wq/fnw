# CDC Rules Reference — SpyGlass CDC 规则映射与分析指引

> 本文件由 `chip-spyglass-cdc-resolver` 使用，将 CDC 规则映射到优先级并提供分析指引。

---

## 优先级总览

| 优先级 | 规则 | 类型 | 能否 Waive | 处理方式 |
|--------|------|------|-----------|----------|
| **P0** | Ac_unsync01, Ac_unsync02 | 未同步跨域 | **禁止** | 必须修复 |
| **P1** | Ac_conv01~05 | 信号收敛 | 条件 | 分析后决定 |
| **P2** | Ac_glitch01/02/03, Clock_glitch* | 毛刺 | 条件 | 分析后决定 |
| **P3** | Ac_cdc01 | 信号宽度 | 条件 | 分析后决定 |
| **P4** | Ac_datahold01a | 数据保持 | 条件 | 分析后决定 |
| **P5** | Ac_cdc08 | 数据相关性 | 条件 | 分析后决定 |
| **P6** | Ar_unsync01, Ar_sync01, Ar_asyncdeassert01, Ar_syncdeassert01 | 复位同步 | 条件 | 分析后决定 |
| **P7** | Ac_fifo01 | FIFO 识别 | 条件 | 分析后决定 |

---

## P0: 未同步跨域（MUST FIX, NEVER WAIVE）

### Ac_unsync01 — 信号跨时钟域无同步器

**规则含义**：信号从一个时钟域的寄存器出发，到达另一个时钟域的寄存器，路径上没有任何同步器（multi-flop synchronizer）。

**为什么严重**：直接导致亚稳态，功能失败概率极高。

**典型根因**：
- 设计者忘记添加同步器
- 同步器被综合工具优化掉
- 时钟域定义不完整（SGDC 缺少时钟定义）

**修复方案**：

```verilog
// 错误：信号直接跨域
always @(posedge clk_fast) begin
    data_fast <= data_in;
end
always @(posedge clk_slow) begin
    data_slow <= data_fast;  // 跨域无同步！
end

// 修复：添加双触发器同步器
reg data_sync1, data_sync2;
always @(posedge clk_slow or negedge rst_n) begin
    if (!rst_n) begin
        data_sync1 <= 1'b0;
        data_sync2 <= 1'b0;
    end else begin
        data_sync1 <= data_fast;   // 第一级
        data_sync2 <= data_sync1;  // 第二级（同步后输出）
    end
end
assign data_slow = data_sync2;
```

**分析指引**：
1. 确认源和目标时钟域确实是异步时钟
2. 检查 SGDC 时钟定义是否完整
3. 如果信号实际为准静态（quasi_static），应修改 SGDC 而非 waive
4. 如果路径是 false path（如 DFT 信号），用 `cdc_false_path` 约束

**禁止 Waive 原因**：亚稳态是物理现象，无法通过功能验证保证安全。必须在设计层面添加同步器。

### Ac_unsync02 — 多 bit 信号跨时钟域无同步器

**规则含义**：多 bit 信号（总线）跨时钟域，未使用异步 FIFO 或格雷码等机制。

**为什么严重**：各 bit 到达时间不同，导致数据不一致（skew 问题）。

**修复方案**：
- **方案 A**：异步 FIFO（推荐，适用于连续数据流）
- **方案 B**：格雷码编码（适用于地址/指针）
- **方案 C**：握手同步（req-ack，适用于低频控制信号）

```verilog
// 方案 A：异步 FIFO
async_fifo #(.DATA_WIDTH(8), .DEPTH(16)) u_async_fifo (
    .wr_clk(clk_fast),
    .wr_rst_n(rst_n),
    .wr_en(wr_en),
    .wr_data(data_in),
    .rd_clk(clk_slow),
    .rd_rst_n(rst_n),
    .rd_en(rd_en),
    .rd_data(data_out)
);

// 方案 B：格雷码（适用于指针/地址）
reg [3:0] bin_ptr, gray_ptr;
assign gray_ptr = bin_ptr ^ (bin_ptr >> 1);  // 二进制转格雷码
// 跨域同步格雷码指针
```

---

## P1: 信号收敛（REVIEW）

### Ac_conv01~05 — 多个 CDC 信号收敛到同一逻辑

**规则含义**：来自同一源域的多个 CDC 信号在目标域组合逻辑中收敛，各信号的同步延迟不同，可能导致毛刺或错误值。

**分析指引**：
1. 检查收敛信号是否来自同一源域
2. 检查是否使用了相同的同步器结构
3. 如果是相关信号（如状态向量），应使用 gray_signals 约束或异步 FIFO

**修复方案**：
- **方案 A**：`gray_signals` 约束（适用于格雷码编码的信号组）
- **方案 B**：异步 FIFO（适用于数据总线）
- **方案 C**：合并为单一信号后同步

**Waive 条件**：
- 信号实际不相关（独立功能位）
- 收敛逻辑是寄存器输出（已同步的信号再组合）

---

## P2: 毛刺传播（REVIEW）

### Ac_glitch01/02/03 — CDC 路径上的毛刺

**规则含义**：同步器的输入来自组合逻辑而非寄存器，组合逻辑的毛刺可能被同步到目标域。

**分析指引**：
1. 检查同步器第一级的输入是否来自寄存器
2. 如果输入是组合逻辑，检查组合逻辑的输入是否稳定

**修复方案**：

```verilog
// 错误：同步器输入来自组合逻辑
assign sync_input = a & b;  // 组合逻辑可能有毛刺
always @(posedge clk_dst) begin
    sync1 <= sync_input;
    sync2 <= sync1;
end

// 修复：先寄存再同步
always @(posedge clk_src) begin
    data_reg <= a & b;  // 先寄存
end
always @(posedge clk_dst) begin
    sync1 <= data_reg;  // 寄存器输出无毛刺
    sync2 <= sync1;
end
```

**Waive 条件**：
- 组合逻辑的输入已经是寄存器输出（无毛刺来源）
- 毛刺持续时间远小于目标时钟周期（实际不会被捕获）

---

## P3: 信号宽度（REVIEW）

### Ac_cdc01 — 快时钟域到慢时钟域的信号宽度问题

**规则含义**：快时钟域产生的脉冲信号宽度可能小于慢时钟域的时钟周期，导致慢时钟域无法采样到。

**分析指引**：
1. 计算源信号脉冲宽度（以目标时钟周期为单位）
2. 如果脉冲宽度 < 1 个目标时钟周期，需要脉冲展宽

**修复方案**：

```verilog
// 脉冲展宽电路
reg pulse_extended;
reg [1:0] extend_cnt;
always @(posedge clk_fast or negedge rst_n) begin
    if (!rst_n) begin
        pulse_extended <= 1'b0;
        extend_cnt <= 0;
    end else if (pulse_in) begin
        pulse_extended <= 1'b1;
        extend_cnt <= 2'd2;  // 展宽 3 个周期
    end else if (extend_cnt > 0) begin
        extend_cnt <= extend_cnt - 1;
    end else begin
        pulse_extended <= 1'b0;
    end
end
// 然后对 pulse_extended 做同步
```

**Waive 条件**：
- 信号是电平信号而非脉冲（宽度 > 目标时钟周期）
- 已使用 req-ack 握手协议

---

## P4: 数据保持（REVIEW）

### Ac_datahold01a — qualifier 保护下数据不稳定

**规则含义**：在使用 qualifier 信号（使能信号）同步数据时，数据在 qualifier 有效期间必须保持稳定，否则目标域可能采样到不一致的数据。

**分析指引**：
1. 检查 qualifier 信号的同步延迟
2. 检查数据在 qualifier 有效期间是否变化
3. 如果数据可能变化，需要确保数据在 qualifier 同步完成前保持稳定

**修复方案**：
- 增加数据保持时间（数据在 qualifier 拉低后保持 N 个源时钟周期）
- 使用 req-ack 握手协议替代 qualifier

**Waive 条件**：
- 数据在 qualifier 有效期间确实不会变化
- qualifier 和数据来自同一寄存器时钟沿

---

## P5: 数据相关性（REVIEW）

### Ac_cdc08 — 多 bit 数据信号的相关性问题

**规则含义**：多 bit 数据信号跨时钟域时，各 bit 之间可能存在相关性（如地址总线、数据总线），如果各 bit 同步延迟不同，可能导致目标域看到不一致的数据。

**分析指引**：
1. 检查多 bit 信号是否具有相关性（如地址、数据、计数器）
2. 如果是独立功能位（如中断状态），可单独同步
3. 如果是相关数据，需要异步 FIFO

**修复方案**：
- **相关数据**：使用异步 FIFO
- **地址/指针**：使用格雷码编码
- **独立位**：可单独添加同步器

**Waive 条件**：
- 信号是独立的功能位，各 bit 无相关性
- 已使用异步 FIFO 或格雷码

---

## P6: 复位同步（REVIEW）

### Ar_unsync01 — 异步复位未同步释放

**规则含义**：异步复位信号在释放时可能违反目标寄存器的恢复/移除时间，导致部分寄存器先退出复位、部分后退出。

**修复方案**：

```verilog
// 异步复位同步释放
reg rst_sync1, rst_sync2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_sync1 <= 1'b0;
        rst_sync2 <= 1'b0;
    end else begin
        rst_sync1 <= 1'b1;
        rst_sync2 <= rst_sync1;
    end
end
assign rst_n_synced = rst_sync2;
```

### Ar_sync01 — 复位同步器结构检查

**分析指引**：检查复位同步器是否使用标准的双触发器结构。

### Ar_asyncdeassert01 — 异步复位释放时序

**分析指引**：检查复位释放是否在时钟有效沿附近。

### Ar_syncdeassert01 — 同步复位释放

**分析指引**：检查同步复位释放是否可能导致时序问题。

**Waive 条件**：
- 复位信号已在设计中正确处理（有同步释放电路）
- 复位信号是全局复位，由 SoC 级统一处理

---

## P7: FIFO 识别（REVIEW）

### Ac_fifo01 — 异步 FIFO 结构识别

**规则含义**：SpyGlass 检测到可能的异步 FIFO 结构，需要确认其正确性。

**分析指引**：
1. 确认是否是真正的异步 FIFO
2. 检查 FIFO 的满/空判断是否使用格雷码指针
3. 检查读写指针同步是否使用双触发器

**Waive 条件**：
- 确认 FIFO 结构正确
- FIFO 来自已验证的 IP 库

---

## 约束替代方案（优先于 Waive）

在可能的情况下，优先使用 SGDC 约束解决问题，而非 waive：

| 约束类型 | 适用场景 | 示例 |
|----------|----------|------|
| `quasi_static` | 配置寄存器、模式选择信号 | `quasi_static -name "cfg_*"` |
| `set_case_analysis` | MUX 选择端、测试模式 | `set_case_analysis -value 0 [get_ports test_mode]` |
| `cdc_false_path` | DFT 专用信号、非功能路径 | `cdc_false_path -from scan_in -to scan_out` |
| `gray_signals` | 格雷码编码的信号组 | `gray_signals -name "fifo_wr_ptr[*]"` |
