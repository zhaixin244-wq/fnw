# pwm_gen

> 可配置占空比和频率的 PWM 信号发生器，支持多通道和中心对齐

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/pwm_gen.md |

## 核心特性
- 可配置周期和占空比，支持 FIXED 和 DYNAMIC 两种周期模式
- 支持左对齐和中心对齐两种 PWM 波形
- 多通道独立占空比控制，共享计数器
- 可选周期结束中断输出
- 使能关闭时输出恒低、计数器暂停

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| CNT_WIDTH | 16 | ≥8 | 计数器位宽 |
| CHANNELS | 1 | ≥1 | PWM 通道数 |
| PERIOD_MODE | "DYNAMIC" | "FIXED"/"DYNAMIC" | 周期模式 |
| ALIGNMENT | "LEFT" | "LEFT"/"CENTER" | 对齐方式 |
| CNT_MAX | (1<<CNT_WIDTH)-1 | - | 最大计数值（FIXED 模式） |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| en | I | 1 | 模块使能 |
| period | I | CNT_WIDTH | PWM 周期值（DYNAMIC 模式） |
| duty | I | CHANNELS × CNT_WIDTH | 各通道占空比值 |
| pwm_out | O | CHANNELS | PWM 输出信号 |
| pwm_irq | O | CHANNELS | 周期结束中断 |

## 典型应用场景
- LED 亮度调节（8 通道，FIXED 模式）
- 3 相电机控制（中心对齐，减少谐波）
- DAC 输出（高频 PWM + RC 滤波）

## 与其他实体的关系
- 独立功能模块，与其他 CBB 无直接依赖
- 可与 `uart_core` 配合实现软件 PWM 调制

## 设计注意事项
- 左对齐：`pwm_out = (cnt < duty)`，计数器 0→PERIOD 递增
- 中心对齐：计数器 0→PERIOD 递增再递减（三角波），`pwm_out = (cnt_up < duty) || (cnt_down < duty)`
- DYNAMIC 模式 period 更新在当前周期结束后生效
- duty 应 ≤ period，否则输出恒高
- 面积：CHANNELS × CNT_WIDTH 比较器 + 1 计数器

## 参考
- 原始文档：`.claude/knowledge/cbb/pwm_gen.md`
