# ram_sp

> 单端口同步读写存储器，用于 FIFO 存储阵列、缓冲区、查找表

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/ram_sp.md |

## 核心特性
- 单一地址端口，每周期仅支持读或写，不能同时进行
- 同步写（posedge clk），寄存器输出读（延迟 1 周期）
- 读写同地址时写优先（new data），读出为旧数据
- 支持 HEX 文件初始化（`$readmemh`）
- FPGA 自动推断 Block RAM，ASIC 映射 SRAM compiler

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | ≥1 | 数据位宽（bit） |
| `ADDR_WIDTH` | 8 | ≥1 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | `""` | 文件路径 | 初始化文件（空=不初始化） |
| `READ_LATENCY` | 1 | 0/1 | 1=寄存器输出，0=组合输出 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `addr` | I | ADDR_WIDTH | 读写地址 |
| `wdata` | I | DATA_WIDTH | 写数据 |
| `we` | I | 1 | 写使能 |
| `rdata` | O | DATA_WIDTH | 读数据 |

## 典型应用场景
- FIFO 存储阵列（配合 sync_fifo 使用）
- 通用缓冲区（只读或读写模式）
- 查找表（LUT）/ ROM（we=0 只读模式）

## 与其他实体的关系
- **ram_dp / ram_tp**：单端口 vs 双端口/真双端口，ram_sp 面积最小但带宽最低
- **ram_ro**：ram_sp 设 we=0 即可当 ROM 使用，但 ram_ro 无写逻辑更精简
- **sync_fifo**：sync_fifo 内部使用 ram_sp 作为存储介质

## 设计注意事项
- 每周期只能读或写，不能同时，需外部仲裁读写时序
- 读写同地址时读到旧数据，需注意流水线数据一致性
- READ_LATENCY=0 时 addr→rdata 为纯组合路径，大深度可能成关键路径
- 面积 = 2^ADDR_WIDTH × DATA_WIDTH bit

## 参考
- 原始文档：`.claude/knowledge/cbb/ram_sp.md`
