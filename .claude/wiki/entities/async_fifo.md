# async_fifo

> 跨时钟域异步 FIFO，通过 Gray 码 + 双触发器实现安全的 CDC 数据传输

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/async_fifo.md |

## 核心特性
- 写侧和读侧使用不同时钟，解决 CDC 数据通路问题
- Gray 码指针跨域同步（bin → Gray → 2FF sync → 比较）
- 满/空信号延迟约 3 cycles（同步 2 + 比较寄存 1）
- 写侧和读侧独立复位（rst_wr_n / rst_rd_n）
- 深度必须为 2 的幂，存储介质为双端口 RAM 或寄存器阵列

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | ≥1 | 数据位宽（bit） |
| `FIFO_DEPTH` | 16 | 2^n | FIFO 深度，必须为 2 的幂 |
| `ALMOST_FULL_THRESH` | FIFO_DEPTH-2 | 1~DEPTH-1 | Almost Full 阈值 |
| `ALMOST_EMPTY_THRESH` | 2 | 1~DEPTH-1 | Almost Empty 阈值 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk_wr` | I | 1 | 写侧时钟 |
| `rst_wr_n` | I | 1 | 写侧低有效异步复位 |
| `push` | I | 1 | 写使能 |
| `push_data` | I | DATA_WIDTH | 写入数据 |
| `full` | O | 1 | FIFO 满 |
| `almost_full` | O | 1 | 接近满 |
| `clk_rd` | I | 1 | 读侧时钟 |
| `rst_rd_n` | I | 1 | 读侧低有效异步复位 |
| `pop` | I | 1 | 读使能 |
| `pop_data` | O | DATA_WIDTH | 读出数据 |
| `empty` | O | 1 | FIFO 空 |
| `almost_empty` | O | 1 | 接近空 |

## 典型应用场景
- 跨时钟域数据传输（快写慢读 / 慢写快读）
- 速率匹配（如 1GHz 写 → 250MHz 读）
- AXI-Stream 跨域桥接（tready=!full, tvalid=!empty）

## 与其他实体的关系
- **sync_fifo**：sync_fifo 用于同时钟域，async_fifo 用于跨时钟域
- **ram_dp**：async_fifo 内部使用 ram_dp（INDEPENDENT 模式）作为存储介质

## 设计注意事项
- 深度计算：DEPTH = 最大突发 + 同步延迟裕量（3 cycles 按慢时钟），向上取 2 的幂
- Gray 码转换：bin ^ (bin >> 1)，同步后直接比较判断空，转换回二进制比较判断满
- 复位时 Gray 码指针清零需同步到对侧
- full/empty 响应延迟约 3 cycles，设计流控时需考虑此延迟裕量
- 2 级触发器同步器（sync[0] → sync[1]），禁止在同步链间插入组合逻辑

## 参考
- 原始文档：`.claude/knowledge/cbb/async_fifo.md`
