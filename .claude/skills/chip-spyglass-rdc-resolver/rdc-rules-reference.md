# RDC Rules Reference — SpyGlass RDC 规则映射与分析指引

> 本文件由 `chip-spyglass-rdc-resolver` 使用，将 RDC 规则映射到优先级并提供分析指引。

---

## 优先级总览

| 优先级 | 类型 | 规则示例 | 能否 Waive | 处理方式 |
|--------|------|----------|-----------|----------|
| **P0** | 异步复位释放亚稳态 | Ar_asyncreset01, Ar_resetcross01 | **禁止** | 必须修复 |
| **P1** | Reset-less path 数据损坏 | Rdc_corrupt01 | 条件 | 分析后决定 |
| **P2** | RDC on Clock Path | Rdc_clockpath01 | **禁止** | 必须修复 |
| **P3** | 复位收敛问题 | Rdc_converge01 | 条件 | 分析后决定 |
| **P4** | Power Domain RDC | Rdc_power01 | 条件 | 分析后决定 |

---

## P0: 异步复位释放亚稳态（MUST FIX, NEVER WAIVE）

### Ar_asyncreset01 — 异步复位释放未同步

**规则含义**：异步复位信号在释放时可能违反目标寄存器的恢复/移除时间，导致亚稳态。

**为什么严重**：复位释放是 RDC 最危险的时刻——复位生效是异步立即生效无问题，但复位释放如果在时钟沿附近，目标寄存器可能进入亚稳态。

**修复方案**：

```verilog
// 错误：异步复位直接连接到目标寄存器
always @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) data <= 0;
    else data <= data_in;
end

// 修复：异步复位同步释放
reg rst_sync1, rst_sync2;
always @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        rst_sync1 <= 1'b0;
        rst_sync2 <= 1'b0;
    end else begin
        rst_sync1 <= 1'b1;
        rst_sync2 <= rst_sync1;
    end
end
// 使用 rst_sync2 作为同步后的复位
```

**约束替代方案**：

```tcl
# 如果复位顺序已知，用 reset ordering 消除
set_rdc_define_assertion_sequence \
    -from_reset {rst_sw} \
    -to_reset {rst_n}
```

### Ar_resetcross01 — 跨复位域复位信号

**规则含义**：复位信号本身跨越复位域，可能导致不一致的复位行为。

**分析指引**：检查复位信号的源头和目标是否在同一复位域。如果跨域，需要同步或 ordering。

---

## P1: Reset-less Path 数据损坏（REVIEW）

### Rdc_corrupt01 — 无复位流水线级数据损坏

**规则含义**：RDC 亚稳态穿过无复位的流水线级，传播到有复位的目标寄存器，可能导致数据损坏。

**RDC 独有挑战**：不同于 CDC 的同步器即可阻断，RDC 亚稳态可穿过很长的无复位级：

```
rst_a → [FF_a] → [FF_no_reset] → [FF_no_reset] → ... → [FF_b] ← rst_b
```

**修复方案**：

```verilog
// 方案 A：在目标寄存器前添加同步触发器
reg data_sync;
always @(posedge clk or negedge rst_b_n) begin
    if (!rst_b_n) data_sync <= 1'b0;
    else data_sync <= data_from_pipeline;
end

// 方案 B：Safe-stating — 复位前门控输入
assign safe_data = rdc_gate ? 1'b0 : data_from_pipeline;
always @(posedge clk or negedge rst_b_n) begin
    if (!rst_b_n) data <= 1'b0;
    else data <= safe_data;
end
```

**约束替代方案**：

```tcl
# 使用 qualifier 声明阻断信号
rdc_qualifier -signal rdc_gate -value 1

# 跳过无复位级，聚焦端点
configure_rdc_corrupt -skip_resetless_flops true
```

**Waive 条件**：
- 无复位级实际很短（1-2 级），且目标寄存器有同步器保护
- 数据路径在功能模式下不会被复位打断

---

## P2: RDC on Clock Path（MUST FIX, NEVER WAIVE）

### Rdc_clockpath01 — 复位信号传播到时钟路径

**规则含义**：复位寄存器的输出如果连接到时钟门控单元（ICG）的使能端，复位释放时的亚稳态会导致时钟毛刺。

**为什么严重**：时钟毛刺是 chip-killing bug——可能导致整个时钟域的寄存器行为不可预测。

**修复方案**：

```verilog
// 错误：复位信号通过组合逻辑驱动 ICG
assign icg_en = func_en & ~rst_n;  // 复位信号参与组合逻辑

// 修复：复位信号不参与时钟路径组合逻辑
assign icg_en = func_en;  // 复位通过寄存器复位处理
// 或者：复位时直接门控时钟（用 MUX 而非组合逻辑）
assign gated_clk = rst_n ? clk : 1'b0;
```

**禁止 Waive 原因**：时钟毛刺影响整个时钟域，后果不可预测。

---

## P3: 复位收敛问题（REVIEW）

### Rdc_converge01 — 多复位信号收敛

**规则含义**：来自不同复位域的复位信号在组合逻辑中收敛，可能导致复位行为不一致。

**分析指引**：
1. 检查收敛的复位信号是否属于同一复位组
2. 检查复位释放顺序是否已声明

**约束替代方案**：

```tcl
# 同组复位之间的 RDC 自动安全
set_reset_groups -name grp_por -group {rst_n}
set_reset_groups -name grp_func -group {rst_sw rst_dbg}
```

**Waive 条件**：
- 复位信号已在同一组中
- 复位顺序已通过 `set_rdc_define_assertion_sequence` 声明

---

## P4: Power Domain RDC（REVIEW）

### Rdc_power01 — 功耗域相关 RDC

**规则含义**：多个功耗域各有独立复位，复位释放顺序必须与功耗域转换对齐。如果 UPF 未考虑，隐藏路径可能在硅片上表现为 RDC。

**分析指引**：
1. 检查是否读取了 UPF 文件
2. 检查隔离单元（Isolation Cell）是否阻断了 RDC 路径
3. 检查电源开关（Power Switch）是否影响复位行为

**Waive 条件**：
- UPF 中已有隔离单元阻断 RDC 路径
- 功耗域转换顺序保证复位安全

---

## 约束替代方案（优先于 Waive）

在可能的情况下，优先使用 RDC 约束解决问题，而非 waive：

| 约束类型 | 适用场景 | 示例 |
|----------|----------|------|
| `set_rdc_define_assertion_sequence` | 复位顺序已知 | `-from_reset {rst_sw} -to_reset {rst_n}` |
| `set_reset_groups` | 同组复位 | `-name grp_por -group {rst_n}` |
| `rdc_qualifier` | 有阻断信号 | `-signal rdc_gate -value 1` |
| `configure_rdc_scenario` | 场景降噪 | `-name func_mode -active_resets {rst_sw}` |
| `configure_rdc_corrupt` | 跳过无复位级 | `-skip_resetless_flops true` |

## RDC 违例处理策略总结

| 策略 | 适用场景 | 优先级 |
|------|----------|--------|
| **Reset Ordering** | 复位顺序已知 | 最高（优先使用） |
| **Reset Grouping** | 同组复位 | 高 |
| **Qualifier** | 有阻断信号 | 高 |
| **Sync Flop** | 输出级加同步器 | 中（RTL 修改） |
| **Safe Stating** | 定制安全逻辑 | 中（RTL 修改） |
| **Clock Gating** | 复位时关闭时钟 | 中（RTL 修改） |
| **Waive** | 误报/功能不可能 | 最低（最后手段） |
