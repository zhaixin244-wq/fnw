# sync_fifo

> 同一时钟域内的同步 FIFO，用于数据缓冲与速率匹配

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/sync_fifo.md |

## 核心特性
- 同一时钟域内工作，采用环形缓冲区 + 读写指针实现
- 指针多 1 位（PTR_WIDTH = ADDR_WIDTH + 1），用于满判断
- 支持 Almost Full / Almost Empty 阈值预警
- pop_data 为寄存器输出，读使能后延迟 1 周期有效
- 深度必须为 2 的幂，存储介质可选寄存器阵列或 SRAM

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | ≥1 | 数据位宽（bit） |
| `FIFO_DEPTH` | 8 | 2^n | FIFO 深度，必须为 2 的幂 |
| `ALMOST_FULL_THRESH` | FIFO_DEPTH-2 | 1~DEPTH-1 | Almost Full 阈值 |
| `ALMOST_EMPTY_THRESH` | 2 | 1~DEPTH-1 | Almost Empty 阈值 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `push` | I | 1 | 写使能 |
| `push_data` | I | DATA_WIDTH | 写入数据 |
| `full` | O | 1 | FIFO 满 |
| `almost_full` | O | 1 | 接近满 |
| `pop` | I | 1 | 读使能 |
| `pop_data` | O | DATA_WIDTH | 读出数据（延迟 1 cycle） |
| `empty` | O | 1 | FIFO 空 |
| `almost_empty` | O | 1 | 接近空 |

## 典型应用场景
- 同时钟域内生产者-消费者速率匹配
- Valid/Ready 接口缓冲（in_ready = !full, out_valid = !empty）
- 流控背压（almost_full 控制上游暂停）

## 与其他实体的关系
- **async_fifo**：sync_fifo 用于同时钟域，async_fifo 用于跨时钟域，后者多 Gray 码同步器
- **ram_sp**：sync_fifo 内部使用 ram_sp 作为存储介质（大深度时）

## 设计注意事项
- 满时 push 被忽略，数据丢失，需外部确保 !full 时才 push
- empty 时 pop_data 无效，需外部确保 !empty 时才 pop
- 深度计算：DEPTH = 最大突发 + 反馈延迟 × (R_prod/R_cons)，含 50% 裕量，向上取 2 的幂
- full/empty 状态信号延迟 1 cycle（寄存器输出）
- 满判断：wr_ptr[MSB]!=rd_ptr[MSB] && wr_ptr[LSB:0]==rd_ptr[LSB:0]
- 空判断：wr_ptr == rd_ptr

## 参考
- 原始文档：`.claude/knowledge/cbb/sync_fifo.md`
