# pipeline_reg — 流水线寄存器

> **用途**：多级流水线数据寄存，支持 stall 和 flush 控制
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

流水线寄存器在每一级流水线之间缓存数据，支持全局 stall（暂停）和 flush（冲刷）控制。数据仅在 `stall=0` 时向前传递，`flush=1` 时插入空泡（bubble）。

```
Stage N ──valid/data──> ┌───────────────┐ ──valid/data──> Stage N+1
                        │ pipeline_reg   │
clk ──────────────────> └───────────────┘
stall ─────────────────> (暂停时保持不变)
flush ─────────────────> (冲刷时插入空泡)
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽 |
| `HAS_VALID` | parameter | 1 | 是否包含 valid 位 |
| `FLUSH_VAL` | parameter | `{DATA_WIDTH{1'b0}}` | flush 时插入的空泡值 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `stall` | I | 1 | clk | 流水线暂停 |
| `flush` | I | 1 | clk | 流水线冲刷 |
| `data_in` | I | `DATA_WIDTH` | clk | 输入数据 |
| `valid_in` | I | 1 | clk | 输入有效（HAS_VALID=1） |
| `data_out` | O | `DATA_WIDTH` | clk | 输出数据 |
| `valid_out` | O | 1 | clk | 输出有效（HAS_VALID=1） |

---

## 时序

### 正常传递（stall=0, flush=0）

```
clk         __|‾|__|‾|__|‾|__|‾|__
data_in     ___| D1  | D2  | D3  |
valid_in    ___|‾‾‾‾‾|‾‾‾‾‾|_____
data_out    _________| D1  | D2  |  (延迟 1 cycle)
valid_out   _________|‾‾‾‾‾|‾‾‾‾‾|
```

### Stall 场景（stall=1）

```
clk         __|‾|__|‾|__|‾|__|‾|__
data_in     ___| D1  | D2  | D3  |
stall       _________|‾‾‾‾‾|_____
data_out    _________| D1  | D1  | D2  |  (stall 期间保持)
valid_out   _________|‾‾‾‾‾|‾‾‾‾‾|‾‾‾‾‾|
```

### Flush 场景（flush=1）

```
clk         __|‾|__|‾|__|‾|__|‾|__
data_in     ___| D1  | D2  | D3  |
flush       _____________|‾‾‾‾‾|___
data_out    _________| D1  | 0   | D3  |  (flush 插入空泡)
valid_out   _________|‾‾‾‾‾|_____|‾‾‾‾‾|
```

---

## 用法

### 基本流水线级

```verilog
// 一级流水线寄存器
pipeline_reg #(
    .DATA_WIDTH (32),
    .HAS_VALID  (1)
) u_pipe_stage1 (
    .clk       (clk),
    .rst_n     (rst_n),
    .stall     (pipe_stall),
    .flush     (pipe_flush),
    .data_in   (stage0_data),
    .valid_in  (stage0_valid),
    .data_out  (stage1_data),
    .valid_out (stage1_valid)
);
```

### 多级流水线串联

```verilog
// 3 级流水线
pipeline_reg #(.DATA_WIDTH(32)) u_s0 (.data_in(in_data),  .data_out(s0_data), .*);
pipeline_reg #(.DATA_WIDTH(32)) u_s1 (.data_in(s0_data),  .data_out(s1_data), .*);
pipeline_reg #(.DATA_WIDTH(32)) u_s2 (.data_in(s1_data),  .data_out(s2_data), .*);

// 全局 stall/flush 连接到所有级
assign pipe_stall = downstream_busy;
assign pipe_flush = branch_mispredict;
```

### 无 valid 模式（纯数据通路）

```verilog
// 数据始终有效，不需要 valid 位
pipeline_reg #(
    .DATA_WIDTH (64),
    .HAS_VALID  (0)
) u_data_pipe (
    .clk      (clk),
    .rst_n    (rst_n),
    .stall    (1'b0),   // 不暂停
    .flush    (1'b0),   // 不冲刷
    .data_in  (data_in),
    .data_out (data_out)
);
```

---

## 关键实现细节

- **stall 优先级高于 flush**：stall=1 时 flush 也被阻塞
- **传递条件**：`!stall` 时寄存器更新
- **flush 行为**：`flush && !stall` 时写入 FLUSH_VAL，valid 置 0
- **默认值**：data_out 复位为 0，valid_out 复位为 0
- **级联**：各级独立实例化，stall/flush 全局共享
- **面积**：每级 DATA_WIDTH + HAS_VALID 个触发器
