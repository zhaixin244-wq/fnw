# sync_fifo — 同步 FIFO

> **用途**：同一时钟域内的数据缓冲与速率匹配
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

同步 FIFO（First In First Out）用于同一时钟域内数据的有序缓冲，解决生产者与消费者速率不匹配问题。采用环形缓冲区 + 读写指针实现，支持 Almost Full / Almost Empty 阈值预警。

```
Producer ──push──> ┌──────────┐ ──pop──> Consumer
                   │ sync_fifo│
                   │ (depth=N)│
                   └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽（bit） |
| `FIFO_DEPTH` | parameter | 8 | FIFO 深度，**必须为 2 的幂** |
| `ALMOST_FULL_THRESH` | parameter | `FIFO_DEPTH - 2` | Almost Full 阈值（≥ 此值拉高） |
| `ALMOST_EMPTY_THRESH` | parameter | 2 | Almost Empty 阈值（≤ 此值拉高） |
| `PTR_WIDTH` | localparam | `$clog2(FIFO_DEPTH)` | 指针位宽 |
| `ADDR_WIDTH` | localparam | `PTR_WIDTH` | 地址位宽 |

---

## 接口

### Push 端口（写入侧）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `push` | I | 1 | 写使能，高有效 |
| `push_data` | I | `DATA_WIDTH` | 写入数据 |
| `full` | O | 1 | FIFO 满，此时 `push` 被忽略 |
| `almost_full` | O | 1 | FIFO 接近满（≥ 阈值） |

### Pop 端口（读出侧）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `pop` | I | 1 | 读使能，高有效 |
| `pop_data` | O | `DATA_WIDTH` | 读出数据（**寄存器输出，延迟 1 cycle**） |
| `empty` | O | 1 | FIFO 空，此时 `pop_data` 无效 |
| `almost_empty` | O | 1 | FIFO 接近空（≤ 阈值） |

### 公共端口

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |

---

## 时序

### 写入时序

```
clk     ___|‾‾‾|___|‾‾‾|___|‾‾‾|___|‾‾‾|___
push    ___|‾‾‾‾‾‾‾|___________|‾‾‾‾‾‾‾|___
push_data XXXX D1   XXXXXXXXXXXX D2      XXXX
full    _______________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                      ↑ FIFO 满，push 被忽略
```

- `push=1` 且 `full=0` 时，数据在 clk 上升沿写入
- `push=1` 且 `full=1` 时，写入被忽略，数据丢失

### 读出时序

```
clk     ___|‾‾‾|___|‾‾‾|___|‾‾‾|___|‾‾‾|___
pop     _________|‾‾‾‾‾‾‾|_______________
pop_data XXXXXXXXX  D1     D2（寄存器输出）
empty   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___________
                            ↑ pop 之后 empty 可能再拉高
```

- `pop=1` 且 `empty=0` 时，数据在下一个 clk 上升沿输出到 `pop_data`
- **注意**：`pop_data` 为寄存器输出，读使能后延迟 1 个周期才能看到数据

### 状态信号延迟

| 信号 | 相对 push/pop 的延迟 | 说明 |
|------|---------------------|------|
| `full` / `empty` | 1 cycle | 寄存器输出 |
| `almost_full` / `almost_empty` | 1 cycle | 寄存器输出 |

---

## 用法

### 基本写入/读出

```verilog
// 写入
if (!fifo_full && has_data) begin
    fifo_push      <= 1'b1;
    fifo_push_data <= data_to_write;
end else begin
    fifo_push <= 1'b0;
end

// 读出
if (!fifo_empty && consumer_ready) begin
    fifo_pop <= 1'b1;
    // pop_data 将在下一个周期有效
end else begin
    fifo_pop <= 1'b0;
end

// 使用读出数据（延迟 1 cycle）
always @(posedge clk) begin
    if (fifo_pop_d1) begin
        process_data <= fifo_pop_data;
    end
end
```

### 带 Valid/Ready 接口的 FIFO

```verilog
// 接收端（push 侧）
assign fifo_push      = in_valid && !fifo_full;
assign fifo_push_data = in_data;
assign in_ready       = !fifo_full;  // backpressure

// 发送端（pop 侧）
assign out_valid = !fifo_empty;
assign out_data  = fifo_pop_data;
wire   fifo_pop  = out_valid && out_ready;  // 握手完成才 pop
```

### Almost Full / Almost Empty 使用

```verilog
// 上游流控：FIFO 接近满时停止输入
assign upstream_pause = fifo_almost_full;

// 下游预警：FIFO 接近空时暂停消费者
assign consumer_pause = fifo_almost_empty;
```

---

## 深度计算

```
FIFO_DEPTH = 最大突发长度 + 流控反馈延迟 × (生产者速率 / 消费者速率)

示例：
- 最大突发 = 16 beats
- 反馈延迟 = 2 cycles
- 生产者速率 = 1 word/cycle
- 消费者速率 = 1 word/cycle

DEPTH = 16 + 2 × (1/1) = 18 → 向上取整到 2 的幂 = 32
含 50% 裕量：32 × 1.5 = 48 → 取 64
```

---

## 关键实现细节

- **指针位宽**：比地址位宽多 1 位（`PTR_WIDTH = ADDR_WIDTH + 1`），用于满判断
- **满判断**：`(wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0])`
- **空判断**：`wr_ptr == rd_ptr`
- **存储介质**：寄存器阵列（小深度）或 SRAM（大深度，需外部例化）
