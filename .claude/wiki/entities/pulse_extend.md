# pulse_extend — 脉冲展宽器

> 将短脉冲展宽为指定周期数的长脉冲，支持 ONESHOT 和 RETRIGGER 两种模式

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/pulse_extend.md |

## 核心特性
- 递减计数器实现，cnt > 0 时 pulse_out = 1
- ONESHOT 模式：触发后忽略新脉冲，计数到 0 才响应
- RETRIGGER 模式：计数期间收到新脉冲重新加载
- 支持多 bit 独立计数
- busy 指示展宽状态

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| WIDTH | 1 | - | 脉冲信号位宽 |
| CYCLES | 4 | ≥ 1 | 展宽周期数 |
| MODE | "RETRIGGER" | ONESHOT/RETRIGGER | 触发模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| pulse_in | I | WIDTH | 输入脉冲 |
| pulse_out | O | WIDTH | 展宽后脉冲 |
| busy | O | 1 | 正在展宽中 |

## 典型应用场景
- LED 闪烁控制（CYCLES=1M，@100MHz ≈ 10ms）
- 中断信号展宽（CYCLES=8，确保目标时钟域能采到）
- 可重触发看门狗脉冲（RETRIGGER 模式）

## 与其他实体的关系
- `edge_detect` 常配合使用，边沿检测后展宽脉冲
- `watchdog` 内部可用 RETRIGGER 模式实现喂狗超时

## 设计注意事项
- CYCLES=1 时脉冲宽度不变，仅 1 周期
- 复位计数器为 0，输出为低
- 多 bit 模式每位独立计数互不影响

## 参考
- 原始文档：`.claude/knowledge/cbb/pulse_extend.md`
