# mux_onehot — 独热码多路选择器

> 使用独热选择信号从多个数据输入中选择一个输出，单级 AND-OR 逻辑

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/mux_onehot.md |

## 核心特性
- 独热选择避免二进制到独热码的译码延迟
- 单级 AND-OR 门，比二进制选择器（解码+多级 MUX）快
- 可选输出寄存器（PIPE_EN）
- 无有效选择时输出 DEFAULT_VAL
- sel_valid 指示选择有效

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| NUM_PORTS | 4 | - | 输入端口数 |
| DATA_WIDTH | 32 | - | 数据位宽 |
| PIPE_EN | 0 | 0/1 | 输出寄存器使能 |
| DEFAULT_VAL | 0 | - | 无有效选择时默认值 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| data_in | I | NUM_PORTS × DATA_WIDTH | 数据输入（拼接） |
| sel | I | NUM_PORTS | 独热选择信号 |
| data_out | O | DATA_WIDTH | 被选数据输出 |
| sel_valid | O | 1 | 选择有效 |

## 典型应用场景
- 仲裁器结果直连 MUX（grant 独热信号）
- 流水线级间数据选择
- 带默认值的多路选择器

## 与其他实体的关系
- 常与仲裁器配合使用，仲裁器输出独热 grant 直接驱动 sel
- `valid_ready_delay` 为协议延迟，本模块为数据选择

## 设计注意事项
- sel 必须保证至多 1 bit 有效（独热约束）
- data_in 按 `{data_N-1, ..., data_1, data_0}` 顺序拼接
- 面积：NUM_PORTS × DATA_WIDTH 个 AND 门 + DATA_WIDTH 个 OR 树

## 参考
- 原始文档：`.claude/knowledge/cbb/mux_onehot.md`
