# ram_dp

> 双端口同步读写存储器，支持两个独立端口同时读写操作

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/ram_dp.md |

## 核心特性
- 两个完全独立的读写端口（Port A / Port B），可同周期并行操作
- 支持同时钟（COMMON）和独立时钟（INDEPENDENT）两种模式
- 同步写（posedge clk），寄存器输出读（延迟 1 周期）
- 双写同地址行为未定义，需上层仲裁避免
- FPGA 推断 True Dual-Port Block RAM，ASIC 需双端口 SRAM macro

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | ≥1 | 数据位宽（bit） |
| `ADDR_WIDTH` | 8 | ≥1 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | `""` | 文件路径 | 初始化文件（空=不初始化） |
| `CLOCKING` | `"COMMON"` | COMMON/INDEPENDENT | 时钟模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk_a` | I | 1 | 端口 A 时钟 |
| `addr_a` | I | ADDR_WIDTH | 端口 A 地址 |
| `wdata_a` | I | DATA_WIDTH | 端口 A 写数据 |
| `we_a` | I | 1 | 端口 A 写使能 |
| `rdata_a` | O | DATA_WIDTH | 端口 A 读数据 |
| `clk_b` | I | 1 | 端口 B 时钟 |
| `addr_b` | I | ADDR_WIDTH | 端口 B 地址 |
| `wdata_b` | I | DATA_WIDTH | 端口 B 写数据 |
| `we_b` | I | 1 | 端口 B 写使能 |
| `rdata_b` | O | DATA_WIDTH | 端口 B 读数据 |

## 典型应用场景
- 异步 FIFO 存储介质（CLOCKING=INDEPENDENT，写端口+读端口）
- CPU 寄存器文件（一写一读，或两个实例实现 2 读 1 写）
- 双访问缓冲区（生产者写 + 消费者读）

## 与其他实体的关系
- **ram_sp**：ram_dp 双端口带宽翻倍，面积端口电路翻倍
- **ram_tp**：ram_dp 端口功能不对称（一写一读），ram_tp 两端口均可读写
- **async_fifo**：async_fifo 内部使用 ram_dp（INDEPENDENT 模式）作为存储介质

## 设计注意事项
- 双写同地址行为未定义，综合工具通常实现为 write-first 或 read-first
- CLOCKING=INDEPENDENT 时地址变化需满足 SRAM 时序要求
- 一端写一端读同地址时，读端看到旧数据
- 面积与单端口 RAM 相同（存储），但端口电路面积翻倍

## 参考
- 原始文档：`.claude/knowledge/cbb/ram_dp.md`
