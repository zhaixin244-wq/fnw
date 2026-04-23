---
name: RTL Coding Style
description: Verilog + SystemVerilog Interface RTL 编码规范。严谨、易读、可综合。仅允许 Verilog 语法 + SV Interface，SVA 仅用于断言。
---

# RTL 编码规范

> **适用范围**：所有 RTL 实现代码（可综合部分）
> **语言约束**：Verilog-2005 + SystemVerilog Interface（仅 interface/typedef/modport）
> **SVA 约束**：仅 `assert property` / `assume property` / `cover property`，不使用 SV OOP 特性
> **目标**：代码严谨、易读、可综合、DFT 友好

---

## 1. 文件组织

### 文件命名
```
{module_name}.v           — 主模块 RTL
{module_name}_pkg.vh      — 公共参数、宏定义（如需共享）
{module_name}_intf.sv     — SystemVerilog Interface 定义（仅 .sv）
{module_name}_sva.sv      — SVA 断言绑定模块（仅 .sv）
{module_name}_tb.v        — 仿真 testbench
```
- 一个文件只放一个模块（interface 和 sva 除外）
- Interface/SVA 用 `.sv`，其余 RTL 用 `.v`

### 文件头注释
```verilog
// ============================================================================
// Module   : {module_name}
// Function : {一句话功能描述}
// Author   : {name}
// Date     : YYYY-MM-DD
// Revision : v1.0
// ============================================================================
```

### 文件内部顺序
```
文件头注释 → timescale(仅tb) → include → module声明 → 参数 → 端口 → 内部信号
→ Interface实例化 → 组合逻辑 → 时序逻辑 → 子模块实例化 → SVA → endmodule
```

---

## 2. 命名规范

### 通用规则
| 类型 | 风格 | 示例 |
|------|------|------|
| 模块名/信号名/端口名 | 小写 + 下划线 | `axi_master_arbiter`, `data_valid` |
| 参数名 | 大写 + 下划线 | `DATA_WIDTH`, `FIFO_DEPTH` |
| 时钟 | `clk` 前缀 | `clk`, `clk_core` |
| 复位 | `rst_n` 后缀 | `rst_n`, `rst_core_n` |
| 使能 | `_en` 后缀 | `fifo_wr_en` |
| 有效/就绪 | `_valid` / `_ready` 后缀 | `data_valid`, `pkt_ready` |
| 完成/错误/中断 | `_done` / `_err` / `_irq` 后缀 | `calc_done`, `parity_err` |
| 计数器/地址/数据 | `_cnt` / `_addr` / `_data` 后缀 | `beat_cnt`, `mem_addr` |

### 禁止
- 禁止单字母信号名（`generate` 循环变量 `i/j/k` 除外）
- 禁止 Verilog 关键字作信号名
- 禁止同模块内信号名仅大小写不同
- 禁止 `tmp`/`temp`/`aux` 等无意义命名
- 低有效信号必须以 `_n` 结尾，引用时显式标注极性：`if (!rst_n)`

---

## 3. 模块声明与端口

- 参数在端口之前，派生参数用 `localparam`
- 端口声明包含方向和类型，按功能分组
- 时钟复位端口始终放在最前面
- 输入始终为 `wire`，时序输出用 `reg`，组合输出用 `wire`

---

## 4. 参数化设计

- 所有硬编码数值必须提取为 `parameter` 或 `localparam`
- 端口位宽必须使用参数：`[DATA_WIDTH-1:0]` 而非 `[31:0]`
- FIFO 深度、流水线级数、通道数等必须参数化
- `generate` 块必须有标签，循环变量用 `genvar`

---

## 5. 时钟与复位

### 时钟
- 模块内只允许一个时钟域（CDC 跨域逻辑放在专用 CDC 模块）
- **禁止门控时钟**，使用标准 ICG cell：`CKLNQD1 u_icg (.CP(clk), .E(en), .TE(scan_en), .Q(gated_clk))`

### 复位
- 统一使用**低有效异步复位**，多时钟域使用异步复位同步释放
- 所有寄存器必须有明确复位值，禁止依赖默认值
- 复位释放顺序：先释放下游，再释放上游

### 时序逻辑
- 仅使用 `always @(posedge clk or negedge rst_n)` 块
- 复位分支列出所有寄存器复位值，非复位分支使用 `*_nxt` 驱动
- 一个 `always` 块只驱动一组相关寄存器

---

## 6. 组合逻辑

- `always @(*)` 块内**所有输出信号必须赋默认值**（避免 latch）
- `case` 必须有 `default` 分支
- 组合逻辑块中禁止使用 `<=`，简单组合逻辑优先使用 `assign`
- **不写 else = latch**，所有 `if` 必须补全分支

---

## 7. 状态机

- 使用 `localparam` 定义状态值，禁止使用 `define`
- 状态数 ≤ 16 推荐独热码（One-Hot），> 16 可用二进制编码
- 状态寄存器命名：`state_cur`（当前）/ `state_nxt`（次态）
- 采用两段式：段1时序逻辑存状态，段2组合逻辑算次态+输出
- 状态转移必须有 `default` 分支，FSM 必须可从任意非法状态回到 IDLE
- 禁止在组合逻辑 FSM 中使用 `z` 或 `x` 值

---

## 8. 握手协议（Valid/Ready）

- `valid` 不能依赖 `ready` 的组合逻辑（防止组合环路）
- `valid` 拉高后必须保持稳定，直到 `ready` 握手
- `ready` 可以依赖 `valid`
- 握手完成：`valid & ready` 同时为高（单周期）

---

## 9. FIFO 设计

- 指针多 1 位用于满判断
- 满判断：`wr_ptr[MSB] != rd_ptr[MSB] && wr_ptr[LSB:0] == rd_ptr[LSB:0]`
- 空判断：`wr_ptr == rd_ptr`
- FIFO 深度必须由流控模型计算，非拍脑袋决定

---

## 10. SystemVerilog Interface

- Interface 仅用于端口信号分组，**不含任何逻辑**
- 每个 Interface 必须定义 `master` 和 `slave` 两个 modport
- Interface 文件后缀 `.sv`，不在 Interface 中使用 `always` 或 `assign`

---

## 11. SVA 断言

- SVA 放在独立 `.sv` 文件，使用 `bind` 机制绑定到 RTL
- SVA 文件仅包含 `property`/`sequence`/`assert/assume/cover`
- 命名：`assert_{描述}` / `assume_{描述}` / `cover_{描述}`，property 用 `p_` 前缀，sequence 用 `s_` 前缀
- 必须包含的 SVA 类型：握手稳定性、复位行为、协议合规、数据完整性、FIFO 满/空、非法状态检测
- SVA 必须放在 `` `ifdef ASSERT_ON ... `endif `` 内，综合时不编译

---

## 12. 代码风格

- **缩进**：4 空格（禁止 Tab）
- **赋值规则**：时序逻辑只用 `<=`，组合逻辑只用 `=`，**同一块内绝对禁止混用**
- **位宽一致**：运算/比较/赋值的位宽必须匹配，常量显式指定位宽（`8'd1` 而非 `1`）
- **case**：必须有 `default`，优先用 `case` 而非 `casex`（x 传播风险）
- **generate**：必须有标签
- **注释规范**：
  - 注释覆盖率 ≥ 50%（非空白行计）
  - 注释类型：功能块注释（模块/功能级）、架构追溯 `// Ref: Arch-Sec-X.Y.Z`、CBB 引用 `// CBB Ref: {文档名}`、行级注释（关键逻辑）
  - 文件头注释必须完整（见 §1）
  - 状态机、FIFO、仲裁等复杂逻辑必须有块级注释说明设计意图

---

## 13. DFT 友好性

- 所有寄存器必须可接入扫描链
- 禁止异步置位寄存器
- **禁止门控时钟**，使用标准 ICG cell
- 禁止结构：门控时钟、异步置位、组合反馈环、非有意 latch、未连接端口

---

## 14. 可综合性检查清单

| 检查项 | 状态 |
|--------|------|
| 所有寄存器有明确复位值 | □ |
| 组合逻辑无 latch | □ |
| 时序逻辑只用 `<=`，组合逻辑只用 `=` | □ |
| case 有 default 分支 | □ |
| 无门控时钟 | □ |
| 无不可综合结构（initial/delay/floating） | □ |
| 位宽匹配 | □ |
| SVA 在 `ifdef ASSERT_ON` 内 | □ |
| Interface 不含逻辑 | □ |
| 参数化位宽，无硬编码 `[31:0]` | □ |
| generate 块有标签 | □ |
| 文件头注释完整 | □ |

---

## 15. 反合理化清单

| 偷懒借口 | 架构师的回应 |
|----------|------------|
| "信号名不重要" | 信号名是接口契约，乱命名导致集成灾难 |
| "默认值设 0 就行" | 必须符合协议规范（如 AXI xRESP 默认 OKAY） |
| "加个 always 就够了" | 组合 vs 时序由数据通路决定 |
| "复位异步无所谓" | 影响 CDC、DFT、面积，必须从架构层决定 |
| "先写 RTL 再补断言" | 断言是架构意图的可执行文档，不写等于没有验证 |
| "时序后面综合再看" | 关键路径分析必须在架构阶段完成 |
| "FIFO 深度随便选" | 深度 = 流控模型计算结果 |
| "用 casex 省事" | casex 有 x 传播风险 |
| "if-else 不用写 else" | 不写 else = latch |
| "位宽差不多就行" | 位宽不匹配仿真可能通过但硅片失败 |
| "interface 里加个 always" | Interface 只做信号分组，加逻辑违反可综合性 |
| "一个 always 块写所有逻辑" | 功能混杂不可读、不可维护 |
