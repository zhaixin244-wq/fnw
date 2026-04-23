# async_fifo — 异步 FIFO（跨时钟域 FIFO）

> **用途**：不同时钟域之间的数据传输缓冲，解决 CDC 数据通路问题
> **可综合**：是
> **语言**：Verilog + Gray 码

---

## 模块概述

异步 FIFO 是跨时钟域（CDC）数据传输的标准方案。写侧和读侧使用不同时钟，通过 Gray 码指针 + 双触发器同步器实现安全的满/空判断，避免亚稳态传播。

```
Producer (clk_wr) ──push──> ┌──────────┐ ──pop──> Consumer (clk_rd)
                            │async_fifo│
                            │ (depth=N)│
                            └──────────┘
     Gray码 wr_ptr ──2FF sync──> rd侧判断满/空
     Gray码 rd_ptr ──2FF sync──> wr侧判断满/空
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽（bit） |
| `FIFO_DEPTH` | parameter | 16 | FIFO 深度，**必须为 2 的幂** |
| `ALMOST_FULL_THRESH` | parameter | `FIFO_DEPTH - 2` | Almost Full 阈值 |
| `ALMOST_EMPTY_THRESH` | parameter | 2 | Almost Empty 阈值 |
| `ADDR_WIDTH` | localparam | `$clog2(FIFO_DEPTH)` | 地址位宽 |
| `PTR_WIDTH` | localparam | `ADDR_WIDTH + 1` | 指针位宽（多 1 位用于满判断） |

---

## 接口

### 写侧端口（clk_wr 域）

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_wr` | I | 1 | - | 写侧时钟 |
| `rst_wr_n` | I | 1 | - | 写侧低有效异步复位 |
| `push` | I | 1 | clk_wr | 写使能 |
| `push_data` | I | `DATA_WIDTH` | clk_wr | 写入数据 |
| `full` | O | 1 | clk_wr | FIFO 满 |
| `almost_full` | O | 1 | clk_wr | Almost Full |

### 读侧端口（clk_rd 域）

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_rd` | I | 1 | - | 读侧时钟 |
| `rst_rd_n` | I | 1 | - | 读侧低有效异步复位 |
| `pop` | I | 1 | clk_rd | 读使能 |
| `pop_data` | O | `DATA_WIDTH` | clk_rd | 读出数据（寄存器输出） |
| `empty` | O | 1 | clk_rd | FIFO 空 |
| `almost_empty` | O | 1 | clk_rd | Almost Empty |

---

## 时序

### 关键时序约束

| 参数 | 说明 | 典型值 |
|------|------|--------|
| `Tco_wr` | clk_wr 到 push_data 的 clock-to-output | ≤ 1 cycle |
| `Tco_rd` | clk_rd 到 pop_data 的 clock-to-output | ≤ 1 cycle |
| `Tsync` | Gray 码指针跨域同步延迟 | 2 cycles（双触发器） |
| `Tfull` | full 信号响应延迟 | 3 cycles（wr_ptr → 同步 → 比较 → 寄存器） |
| `Tempty` | empty 信号响应延迟 | 3 cycles（rd_ptr → 同步 → 比较 → 寄存器） |

### 跨时钟域写入场景

```
clk_wr  __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
push    ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___
push_data XXX D1    D2    D3    D4    D5    XXX
full    _____________________________|‾‾‾‾‾‾‾‾‾‾
                                     ↑ 延迟 ~3 cycles 后 full 拉高
```

### 跨时钟域读出场景

```
clk_rd  __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
pop     _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
pop_data XXXXXXXXX D1    D2    D3    D4    D5
empty   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾
                                      ↑ 延迟 ~3 cycles 后 empty 拉高
```

---

## 用法

### 跨时钟域数据传输

```verilog
// 写侧（快时钟域 clk_fast）
always @(posedge clk_fast or negedge rst_fast_n) begin
    if (!rst_fast_n) begin
        async_push <= 1'b0;
    end else if (fast_data_valid && !async_full) begin
        async_push      <= 1'b1;
        async_push_data <= fast_data;
    end else begin
        async_push <= 1'b0;
    end
end

// 读侧（慢时钟域 clk_slow）
assign slow_data_valid = !async_empty;
assign slow_data       = async_pop_data;
assign async_pop       = !async_empty && slow_data_ready;
```

### 速率匹配（快写慢读）

```verilog
// 写侧：突发写入，速率 1 GHz
// 读侧：持续读出，速率 250 MHz
// FIFO 深度 ≥ 突发长度 × (clk_wr / clk_rd) + 反馈延迟裕量

// 示例：突发 64 beats，频率比 4:1
// DEPTH ≥ 64 × 1 + 4 = 68 → 取 128
```

### 与 Valid/Ready 接口对接

```verilog
// AXI-Stream 写入侧
assign axis_in_tready = !async_full;
assign async_push     = axis_in_tvalid && !async_full;
assign async_push_data = axis_in_tdata;

// AXI-Stream 读出侧
assign axis_out_tvalid = !async_empty;
assign axis_out_tdata  = async_pop_data;
assign async_pop       = axis_out_tvalid && axis_out_tready;
```

---

## 深度计算

```
异步 FIFO 深度 = 最大突发长度 + 同步延迟裕量

同步延迟裕量 = 2（Gray 码同步）+ 1（寄存器输出）= 3 cycles（按慢时钟计算）

示例：
- 突发长度 = 64 words
- clk_wr = 500 MHz, clk_rd = 125 MHz
- 慢侧同步延迟 = 3 cycles @ 125 MHz = 24 ns = 12 cycles @ 500 MHz

DEPTH = 64 + 12 = 76 → 向上取整到 2 的幂 = 128
```

---

## 关键实现细节

- **Gray 码转换**：二进制指针 → Gray 码（`bin ^ (bin >> 1)`）再跨域同步
- **同步器**：2 级触发器链（`sync[0]` → `sync[1]`）
- **满判断**：写侧用同步后的 rd_ptr Gray 码，转换回二进制比较
- **空判断**：读侧用同步后的 wr_ptr Gray 码，直接 Gray 码比较
- **复位**：写侧和读侧独立复位（`rst_wr_n` / `rst_rd_n`），复位时 Gray 码指针清零同步到对侧
- **存储介质**：双端口 RAM（写端口 clk_wr，读端口 clk_rd），或寄存器阵列（小深度）
