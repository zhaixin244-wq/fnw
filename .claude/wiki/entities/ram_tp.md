# ram_tp

> 真双端口 RAM，两个端口均可独立读写，灵活度最高

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/ram_tp.md |

## 核心特性
- 两个端口功能完全对称，均可独立进行读和写操作
- 支持同时钟（COMMON）和独立时钟（INDEPENDENT）两种模式
- 可配置写冲突模式：READ_FIRST / WRITE_FIRST / NO_CHANGE
- 每端口独立读使能（rd_a/rd_b），支持低功耗控制
- FPGA 推断 True Dual-Port Block RAM，ASIC 需双端口 SRAM macro

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | ≥1 | 数据位宽（bit） |
| `ADDR_WIDTH` | 8 | ≥1 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | `""` | 文件路径 | 初始化文件（空=不初始化） |
| `CLOCKING` | `"COMMON"` | COMMON/INDEPENDENT | 时钟模式 |
| `READ_LATENCY` | 1 | 0/1 | 1=寄存器输出，0=组合输出 |
| `WRITE_MODE` | `"READ_FIRST"` | READ_FIRST/WRITE_FIRST/NO_CHANGE | 写冲突模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk_a` | I | 1 | 端口 A 时钟 |
| `addr_a` | I | ADDR_WIDTH | 端口 A 地址 |
| `wdata_a` | I | DATA_WIDTH | 端口 A 写数据 |
| `we_a` | I | 1 | 端口 A 写使能 |
| `rd_a` | I | 1 | 端口 A 读使能 |
| `rdata_a` | O | DATA_WIDTH | 端口 A 读数据 |
| `clk_b` | I | 1 | 端口 B 时钟 |
| `addr_b` | I | ADDR_WIDTH | 端口 B 地址 |
| `wdata_b` | I | DATA_WIDTH | 端口 B 写数据 |
| `we_b` | I | 1 | 端口 B 写使能 |
| `rd_b` | I | 1 | 端口 B 读使能 |
| `rdata_b` | O | DATA_WIDTH | 端口 B 读数据 |

## 典型应用场景
- CPU 寄存器文件（端口 A 读写复用 rs1+wb，端口 B 读 rs2）
- 乒乓缓冲（两个 ram_tp 实例交替读写）
- 共享数据缓冲（双处理器共享存储区，INDEPENDENT 模式）

## 与其他实体的关系
- **ram_sp**：ram_tp 双端口对称，ram_sp 单端口，面积和带宽差异大
- **ram_dp**：ram_dp 端口不对称（一写一读），ram_tp 两端口均可读写，灵活度更高
- **ram_ro**：ram_tp 可通过禁用写使能模拟 ROM 功能，但 ram_ro 更精简

## 设计注意事项
- READ_FIRST（推荐）：同地址写+读时读到旧数据，最常见
- WRITE_FIRST：读到新数据，写立即生效
- NO_CHANGE：写操作期间读输出保持不变
- 双写同地址行为未定义，必须由上层仲裁避免
- CLOCKING=INDEPENDENT 时需注意跨时钟域的地址时序约束

## 参考
- 原始文档：`.claude/knowledge/cbb/ram_tp.md`
