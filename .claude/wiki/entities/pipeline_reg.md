# pipeline_reg — 流水线寄存器

> 多级流水线数据寄存，支持 stall（暂停）和 flush（冲刷）控制

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/pipeline_reg.md |

## 核心特性
- !stall 时寄存器更新，flush 时插入空泡（bubble）
- stall 优先级高于 flush
- 可选 valid 位（HAS_VALID）
- 可配置 flush 时的空泡值（FLUSH_VAL）
- 各级独立实例化，stall/flush 全局共享

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DATA_WIDTH | 32 | - | 数据位宽 |
| HAS_VALID | 1 | 0/1 | 是否包含 valid 位 |
| FLUSH_VAL | 0 | - | flush 时插入的空泡值 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| stall | I | 1 | 流水线暂停 |
| flush | I | 1 | 流水线冲刷 |
| data_in | I | DATA_WIDTH | 输入数据 |
| valid_in | I | 1 | 输入有效 |
| data_out | O | DATA_WIDTH | 输出数据 |
| valid_out | O | 1 | 输出有效 |

## 典型应用场景
- 多级流水线数据通路（3 级串联）
- 纯数据通路（HAS_VALID=0）
- 分支预测失败后的流水线冲刷

## 与其他实体的关系
- `valid_ready_delay` 为 Valid/Ready 协议延迟，本模块为流水线级间寄存
- 与 `counter` 配合实现流水线计数

## 设计注意事项
- flush && !stall 时写入 FLUSH_VAL，valid 置 0
- 面积：每级 DATA_WIDTH + HAS_VALID 个触发器
- 复位：data_out 和 valid_out 均复位为 0

## 参考
- 原始文档：`.claude/knowledge/cbb/pipeline_reg.md`
