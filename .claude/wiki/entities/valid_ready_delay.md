# valid_ready_delay — Valid/Ready 延迟模块

> 在 Valid/Ready 握手路径中插入可配置延迟，用于时序调整或协议转换

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/valid_ready_delay.md |

## 核心特性
- valid 和 data 通过 N 级触发器链同步延迟
- ready 反压信号可选通过 M 级触发器链反向延迟
- FULL_HANDSHAKE=1 时内部 FIFO 缓冲防止数据丢失
- 独立配置 valid 和 ready 延迟级数

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DATA_WIDTH | 32 | - | 数据位宽 |
| VALID_DELAY | 1 | - | valid/data 延迟级数 |
| READY_DELAY | 0 | - | ready 反压延迟级数 |
| FULL_HANDSHAKE | 1 | 0/1 | 完整握手模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| s_valid | I | 1 | 上游 valid |
| s_ready | O | 1 | 上游 ready |
| s_data | I | DATA_WIDTH | 上游数据 |
| m_valid | O | 1 | 下游 valid |
| m_ready | I | 1 | 下游 ready |
| m_data | O | DATA_WIDTH | 下游数据 |

## 典型应用场景
- 数据通路中插入延迟与控制信号对齐
- 仿真中模拟长路径延迟
- 背压路径延迟模拟

## 与其他实体的关系
- `pipeline_reg` 为流水线级间寄存，本模块为协议层延迟
- `mux_onehot` 为数据选择，不涉及时序调整

## 设计注意事项
- VALID_DELAY 过大时需要内部缓冲防止 valid 保持期间数据被覆盖
- FULL_HANDSHAKE=0 简单寄存器链，ready 反压可能丢数据
- 面积：VALID_DELAY × (1 + DATA_WIDTH) 触发器 + READY_DELAY × 1 触发器

## 参考
- 原始文档：`.claude/knowledge/cbb/valid_ready_delay.md`
