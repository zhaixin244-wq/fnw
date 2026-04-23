# ram_ro

> 预初始化只读存储器（ROM），用于查找表、微码、系数表

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/ram_ro.md |

## 核心特性
- 仅支持读操作，无写端口，存储内容由 INIT_FILE 在仿真/综合时加载
- 支持寄存器输出（READ_LATENCY=1）和组合输出（READ_LATENCY=0）两种模式
- ROM_STYLE 可选 AUTO/BLOCK/DISTRIBUTED，控制综合推断方式
- 无 INIT_FILE 时内容全 0（综合工具默认行为）
- 面积略小于同容量 RAM（无写电路）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | ≥1 | 数据位宽（bit） |
| `ADDR_WIDTH` | 8 | ≥1 | 地址位宽，深度 = 2^ADDR_WIDTH |
| `INIT_FILE` | `""` | 文件路径 | 初始化文件（HEX 格式） |
| `READ_LATENCY` | 1 | 0/1 | 1=寄存器输出，0=组合输出 |
| `ROM_STYLE` | `"AUTO"` | AUTO/BLOCK/DISTRIBUTED | 综合风格 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `en` | I | 1 | 读使能（低功耗控制） |
| `addr` | I | ADDR_WIDTH | 读地址 |
| `rdata` | O | DATA_WIDTH | 读数据 |

## 典型应用场景
- 三角函数/对数系数查找表（小容量用 DISTRIBUTED）
- 微控制器指令 ROM（大容量用 BLOCK）
- 中断向量表（组合输出 READ_LATENCY=0 快速跳转）

## 与其他实体的关系
- **ram_sp**：ram_sp 设 we=0 可当 ROM 用，但 ram_ro 无写逻辑更精简，语义更清晰
- **ram_tp / ram_dp**：ROM 场景无需双端口，ram_ro 是最简选择

## 设计注意事项
- READ_LATENCY=0 时 addr→rdata 为纯组合路径，大深度 ROM 可能成关键路径
- FPGA 小容量（≤64×32）建议 DISTRIBUTED 省 BRAM 资源
- ASIC 编译为 ROM macro，面积 = 2^ADDR_WIDTH × DATA_WIDTH
- 初始化文件格式为 HEX，每行一个数据，地址递增

## 参考
- 原始文档：`.claude/knowledge/cbb/ram_ro.md`
