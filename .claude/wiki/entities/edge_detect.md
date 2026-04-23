# edge_detect — 边沿检测器

> 检测信号的上升沿、下降沿或双边沿，产生单周期脉冲

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/edge_detect.md |

## 核心特性
- 支持 RISING/FALLING/BOTH 三种检测类型
- 多 bit 独立检测，输出位宽与输入一致
- 脉冲宽度恒定 1 周期
- 复位后第一个上升沿不会丢失

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| WIDTH | 1 | - | 检测信号位宽 |
| EDGE_TYPE | "RISING" | RISING/FALLING/BOTH | 检测类型 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| signal_in | I | WIDTH | 待检测信号（必须是寄存器输出） |
| rise_pulse | O | WIDTH | 上升沿脉冲 |
| fall_pulse | O | WIDTH | 下降沿脉冲 |
| any_pulse | O | WIDTH | 双边沿脉冲 |

## 典型应用场景
- 中断信号上升沿检测
- I2C SCL 边沿检测
- 多 bit 状态信号变化检测

## 与其他实体的关系
- `pulse_extend` 常配合使用，将边沿脉冲展宽
- `intc` 中 EDGE 模式内部使用边沿检测逻辑

## 设计注意事项
- signal_in 必须是寄存器输出，否则可能产生毛刺脉冲
- rise = signal_in & ~signal_d1，fall = ~signal_in & signal_d1，any = signal_in ^ signal_d1

## 参考
- 原始文档：`.claude/knowledge/cbb/edge_detect.md`
