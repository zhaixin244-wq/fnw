# wide_entry_wr — 宽表项写入器

> 将窄位宽数据流合并写入宽位宽表项，支持累加模式和字节使能模式，原子提交

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/wide_entry_wr.md |

## 核心特性
- 窄数据多周期合并为宽表项（如 32b × 4 拍 → 128b）
- ACCUMULATE 模式：连续拍次拼接
- BYTE_ENABLE 模式：按字节使能选择写入字节
- 支持 LSB_FIRST / MSB_FIRST 拍序
- 最后一拍原子提交，保证表项一致性

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| IN_WIDTH | 32 | - | 输入数据位宽 |
| ENTRY_WIDTH | 128 | IN_WIDTH 整数倍 | 表项位宽 |
| WR_MODE | "ACCUMULATE" | ACCUMULATE/BYTE_ENABLE | 写入模式 |
| WR_ORDER | "LSB_FIRST" | LSB_FIRST/MSB_FIRST | 拍序 |
| PIPE_EN | 0 | 0/1 | 输出流水线寄存器 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| in_data | I | IN_WIDTH | 输入窄数据 |
| in_valid | I | 1 | 输入有效 |
| in_strb | I | IN_WIDTH/8 | 字节使能 |
| in_last | I | 1 | 最后一拍标记 |
| in_ready | O | 1 | 接收就绪 |
| entry_out | O | ENTRY_WIDTH | 合并后的宽表项 |
| wr_valid | O | 1 | 表项写入完成（原子提交） |
| wr_strb | O | ENTRY_WIDTH/8 | 表项字节使能掩码 |

## 典型应用场景
- TCAM 表项写入（256b，AXI 32b 总线，8 拍）
- 路由表行填充（128b，AXI 64b 总线）
- 配置寄存器组字节写入（BYTE_ENABLE 模式）
- SRAM 行/Cache line 填充（512b，DDR 64b）

## 与其他实体的关系
- 无直接依赖，为独立数据通路模块

## 设计注意事项
- in_last 提前或延迟时报警（可选 SVA）
- 面积：ENTRY_WIDTH 个触发器 + 拼接 MUX + 控制状态机
- in_ready 由内部 1-entry 缓冲控制，防止背压丢数据

## 参考
- 原始文档：`.claude/knowledge/cbb/wide_entry_wr.md`
