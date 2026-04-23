---
name: RTL Coding Style
description: Verilog-2005 + SV Interface RTL 编码规范。严谨、可综合、DFT 友好。
---

# RTL 编码规范

> 适用范围：所有可综合 RTL。语言：Verilog-2005 + SV Interface（仅 interface/typedef/modport）。SVA 仅 assert/assume/cover。

---

## 1. 文件组织

**文件命名**：`{module}.v`（RTL）、`{module}_intf.sv`（Interface）、`{module}_sva.sv`（SVA）、`{module}_tb.v`（TB）。一个文件一个模块，.sv 仅用于 Interface/SVA。

**文件头**：`// Module / Function / Author / Date / Revision`，五项齐全。

**内部顺序**：头注释 → include → 参数 → 端口 → 内部信号 → Interface → 组合逻辑 → 时序逻辑 → 子模块 → SVA → endmodule。

---

## 2. 命名规范

| 类型 | 风格 | 示例 |
|------|------|------|
| 模块/信号/端口 | 小写下划线 | `data_valid` |
| 参数 | 大写下划线 | `DATA_WIDTH` |
| 时钟 | `clk` 前缀 | `clk_core` |
| 复位 | `rst_xxx_n` 后缀 | `rst_core_n` |
| 使能/有效/就绪 | `_en` / `_valid` / `_ready` | `fifo_wr_en` |
| 完成/错误/中断 | `_done` / `_err` / `_irq` | `parity_err` |
| 计数器/地址/数据 | `_cnt` / `_addr` / `_data` | `beat_cnt` |
| 流水线寄存器 | `{sig}_r{n}` | `data_r1`, `valid_r2` |
| 仲裁请求/授权 | `{src}_arb_req` / `_gnt` | `ch0_arb_gnt` |
| Credit 计数 | `{res}_credit_cnt` | `ram_beat_credit_cnt` |

**命名原则**：信号名必须准确反映功能角色。`data`→`payload_data`，`cnt`→`beat_cnt`，`en`→`crc_en`。避免同模块内含义模糊的缩写。

**禁止**：单字母名（genvar 除外）、Verilog 关键字、仅大小写不同、`tmp`/`temp`/`aux`。低有效 `_n` 结尾，引用时显式：`if (!rst_n)`。

---

## 3. 模块声明与端口

```verilog
module module_name #(
    parameter  DATA_WIDTH = 32,
    localparam SEL_W      = $clog2(CH_NUM)
)(
    input  wire                  clk, rst_n,      // 时钟复位最前
    input  wire [DATA_WIDTH-1:0] src_data,         // 输入
    input  wire                  src_valid,
    output wire                  src_ready,
    output reg  [DATA_WIDTH-1:0] dst_data,         // 输出
    output reg                   dst_valid,
    input  wire                  dst_ready
);
```
参数在端口前，派生用 `localparam`。输入 `wire`，时序输出 `reg`，组合输出 `wire`。同一接口信号连续排列。

**子模块实例化必须名称关联**，禁止位置关联。正例：`.clk(clk), .rst_n(rst_n)`；反例：`u_fifo(clk, rst_n, data, ...)`。

---

## 4. 参数化设计

- 硬编码数值提取为 `parameter`/`localparam`，端口位宽用参数 `[DATA_WIDTH-1:0]`
- FIFO 深度必须 2 的幂次
- `generate` 必须有标签，循环变量用 `genvar`

```verilog
genvar i;
generate
    for (i = 0; i < CH_NUM; i = i + 1) begin : gen_ch
        assign out[i] = in[i] & en[i];   // 正例：有标签
    end
endgenerate
// 反例：begin 后无标签 → 编译错误或信号不可见
```

---

## 5. 时钟与复位

- 模块内单时钟域，CDC 放专用模块。**禁止门控时钟**，用 ICG：`CKLNQD1 u_icg (.CP(clk), .E(en), .TE(scan_en), .Q(gated_clk))`
- 统一低有效异步复位，所有寄存器明确复位值。`always @(posedge clk or negedge rst_n)`，复位分支列所有寄存器，非复位用 `*_nxt`。

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin data_r <= 0; valid_r <= 1'b0; end
    else begin data_r <= data_nxt; valid_r <= valid_nxt; end
end
// 反例：always @(posedge clk) 缺异步复位；复位时依赖默认值
```

**CDC**：单 bit 双触发器，多 bit 异步 FIFO/格雷码，同步链禁止插组合逻辑。双触发器：`sig_sync1 <= sig_src; sig_sync2 <= sig_sync1;`

---

## 6. 组合逻辑

**task/function**：禁止 `task`。`function` 仅纯组合计算，必须声明返回位宽，禁止 `#`/`$display`。

- `always @(*)` 所有输出**先赋默认值**（防 latch）
- `case` 必须 `default`，`if` 必须补全 `else`
- 组合逻辑只用 `=`，禁止 `<=`

```verilog
always @(*) begin
    out = 0; valid = 1'b0;          // 默认值
    case (state)
        S_IDLE: if (start) begin out = din; valid = 1'b1; end
        default: ;                   // case default
    endcase
end
// 反例：if (en) out = din; → en=0 时 latch
```

**Latch 检查**：always @(*) 开头赋默认值、if 补 else、case 有 default、三目运算覆盖全分支、generate if 补 else。

---

## 7. 状态机

- `localparam` 定义状态，禁止 `define`。≤16 状态独热码，>16 二进制编码。命名 `state_cur`/`state_nxt`，两段式（时序存状态 + 组合算次态）。必须从非法状态回到 IDLE。

```verilog
localparam [3:0] S_IDLE=4'b0001, S_WORK=4'b0010;  // 独热码
always @(posedge clk or negedge rst_n)              // 段1
    if (!rst_n) state_cur <= S_IDLE;
    else state_cur <= state_nxt;
always @(*) begin                                    // 段2
    state_nxt = S_IDLE;
    case (state_cur)
        S_IDLE: if (start) state_nxt = S_WORK;
        S_WORK: state_nxt = done ? S_IDLE : S_WORK;
        default: state_nxt = S_IDLE;                 // 非法回收
    endcase
end
```

---

## 8. 握手协议

- `valid` 不依赖 `ready`（防组合环路），拉高后保持稳定直到握手
- `ready` 优先仅依赖下游（`ready = !full`），需要反压时才组合依赖 valid
- 握手：`valid & ready` 同高一拍完成

```verilog
always @(posedge clk or negedge rst_n)              // 发送端
    if (!rst_n) src_valid_r <= 1'b0;
    else if (src_valid_r && src_ready) src_valid_r <= next_valid;  // 握手后更新
    else if (!src_valid_r) src_valid_r <= next_valid;
assign dst_ready = !fifo_full;                       // 接收端
```

---

## 9. FIFO 设计

- 指针多 1 位。满：`wr_ptr[MSB]!=rd_ptr[MSB] && wr_ptr[LSB:0]==rd_ptr[LSB:0]`。空：`wr_ptr==rd_ptr`
- 深度 = `B_max + D_fb × (R_prod/R_cons)`，含 50% 裕量，向上取 2 的幂
- 快产慢消深度由突发量+速率差决定；慢产快消仅由突发量决定

---

## 10. SystemVerilog Interface

- 仅信号分组，**不含逻辑**（无 always/assign）。必须定义 `master`/`slave` modport。后缀 `.sv`。

---

## 11. SVA 断言

- 独立 `.sv` 文件，`bind` 绑定 RTL，` `ifdef ASSERT_ON` ` 内
- 命名：`assert_`/`assume_`/`cover_`，property `p_`，sequence `s_`

```systemverilog
`ifdef ASSERT_ON
property p_valid_stable; @(posedge clk) disable iff (!rst_n) (valid&&!ready)|=>valid; endproperty
assert_valid_stable: assert property (p_valid_stable);
property p_data_stable; @(posedge clk) disable iff (!rst_n) (valid&&!ready)|=>$stable(data); endproperty
assert_data_stable: assert property (p_data_stable);
property p_reset_idle; @(posedge clk) !rst_n|->(state_cur==S_IDLE); endproperty
assert_reset_idle: assert property (p_reset_idle);
`endif
```

---

## 12. 代码风格

- 缩进 4 空格（禁 Tab），`begin` 同行末尾，`end` 对齐
- 时序 `<=`，组合 `=`，同一块禁混用。`assign` 用 `=`
- 常量显式位宽（`8'd1` 而非 `1`），不同位宽赋值显式截位/扩展
- `case` 必须 `default`，禁 `casex/casez`
- `generate` 必须有标签
- 注释覆盖率 >30%（`//`/`/* */` 计入，编译指令不计），禁止注水注释（如重复端口名），只注释关键信息（设计意图、约束条件、协议例外）。架构追溯 `// Ref: Arch-Sec-X.Y`，CBB 引用 `// CBB Ref: {doc}`

### always 块组织

- 单个 always 块控制在 **100 行以内**，逻辑量较大时可放宽至 **200 行**，超过则拆分
- 单个 always 块生成信号数 **< 5 个**
- 语义相近的信号放同一 always（如 `data_r` 和 `valid_r`），不相近的拆分（如 `data_r` 和 `err_cnt` 分块）
- 总线信号按功能域分段赋值，而非一次性拼接：`{out_hdr, out_data, out_tail} = ...` → 分域段独立赋值

---

## 13. 常用模块设计规范

### 存储器

| 场景 | 方式 |
|------|------|
| 深度 ≤ 8 | 寄存器阵列 |
| 深度 > 8 | SRAM（1R1W/2P），阈值以工艺库最小深度为准 |
| 同地址同周期写 | 写优先于读，bypass 回读 |
| 只读常量表 | `case` 推断 ROM |

SRAM：禁止行为级描述替代 macro，写使能同步，读延迟标注，地址参数化。

### 仲裁器
策略明确（Fixed/RR/WRR），RR 指针在包/事务边界更新，优先级参数化，无请求时不选中。

### Credit 流控
命名 `{res}_beat_credit_cnt`/`{res}_byte_credit_cnt`，归零立即反压禁止超发，回收时机注释，位宽 `$clog2(MAX)+1`，初始值 APB 配置。

### 流水线 stall/flush
每级必须有 valid，stall 阻塞上游所有级（禁跳级），flush 高于 stall 清除所有级，flush 触发源注释，包边界（`last`/`eop`）可识别。

### SRAM 写冲突仲裁
同地址同周期写：W2 优先，W1 被反压时其上游 ready 拉低。`assign wr1_ready = ~wr2_en | (wr2_addr != wr1_addr);`

### 多通道隔离
通道编号 `ch_id` 位宽 `$clog2(CH_NUM)`，共享资源 RR 仲裁，通道间无耦合，每通道独立状态。

### 链表管理
空闲链表 head/tail 分离，指针 `$clog2(DEPTH)` 位，next 写入时同步更新。

---

## 14. DFT 友好性

- 寄存器可入扫描链，禁止异步置位，禁止门控时钟（用 ICG），无组合反馈环/非有意 latch/未连接端口，ICG 有 scan_en 端口

---

## 15. 可综合性检查清单

> **完整检查清单（IC-01~39 + IM-01~08）统一维护在 `.claude/shared/quality-checklist-impl.md`。**
> 本节仅提供本文件旧编号到 IC 编号的映射，以及 Latch 专项和 lint 工具指引。

Review 头部：`模块 / 文件 / Review 人 / 日期 / Lint 工具+结果`

### 编号映射（本文件 # → quality-checklist-impl.md IC 编号）

| 旧 # | IC 编号 | 旧 # | IC 编号 | 旧 # | IC 编号 | 旧 # | IC 编号 |
|------|---------|------|---------|------|---------|------|---------|
| 1 | IC-01 | 10 | IC-10 | 19 | IC-19 | 28 | IC-23 |
| 2 | IC-02 | 11 | IC-11 | 20 | IC-35 | 29 | IC-24 |
| 3 | IC-03 | 12 | IC-12 | 21 | IC-20 | 30 | IC-25 |
| 4 | IC-04 | 13 | IC-13 | 22 | IC-21 | 31 | IC-26 |
| 5 | IC-05 | 14 | IC-14 | 23 | IC-30 | 32 | IC-27 |
| 6 | IC-06 | 15 | IC-15 | 24 | IC-31 | 33 | IC-36 |
| 7 | IC-07 | 16 | IC-16 | 25 | IC-32 | 34 | IC-37 |
| 8 | IC-08 | 17 | IC-17 | 26 | IC-33 | 35 | IC-38 |
| 9 | IC-09 | 18 | IC-18 | 27 | IC-34 | 36 | IC-39 |

### Latch 专项
always @(*) 输出默认值、if 补 else、case 有 default、局部变量全路径赋值。

### lint 工具
Verilator `--lint-only -Wall`（免费）、SpyGlass / AscentLint（商业）。建议纳入 CI。

---

## 16. 反合理化清单

| 借口 | 回应 |
|------|------|
| "信号名不重要" | 信号名是接口契约 |
| "默认值设 0 就行" | 必须符合协议规范 |
| "复位异步无所谓" | 影响 CDC、DFT、面积 |
| "先写 RTL 再补断言" | 断言是可执行文档 |
| "FIFO 深度随便选" | 深度 = 流控模型计算结果 |
| "用 casex 省事" | casex 有 x 传播风险 |
| "if-else 不用写 else" | 不写 else = latch |
| "interface 里加个 always" | Interface 不含逻辑 |
| "跨域打一拍就行" | 单 bit 双触发器，多 bit 异步FIFO |
| "门控时钟省面积" | 标准 ICG 等效且 DFT 友好 |
| "一个 always 写完省事" | >200行或≥5信号不可读不可维护 |
| "总线直接拼接就行" | 分域段赋值可定位每域错误 |
| "注释越多越好" | 注水注释遮蔽关键信息 |
| "信号名随便取" | 命名模糊导致集成时误连信号 |
