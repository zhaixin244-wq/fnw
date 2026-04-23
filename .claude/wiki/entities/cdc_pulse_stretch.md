# cdc_pulse_stretch

> CDC 脉冲展宽同步器，将窄脉冲展宽后安全传递到目标时钟域

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/cdc_pulse_stretch.md |

## 核心特性
- 源域展宽脉冲至 STRETCH_CYCLES 周期，防止快域到慢域脉冲丢失
- 通过 2FF 同步器传递到目标域，再边沿检测还原单周期脉冲
- busy 保护：展宽期间忽略新输入，防止重叠
- 支持上升沿触发和电平触发两种模式

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| SYNC_STAGES | 2 | 2-3 | 同步器级数 |
| STRETCH_CYCLES | 3 | ≥(dst慢周期/src快周期+2) | 展宽周期数 |
| EDGE_TYPE | "RISING" | "RISING"/"LEVEL" | 触发类型 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk_src / clk_dst | I | 1 | 源/目标时钟域 |
| rst_src_n / rst_dst_n | I | 1 | 源/目标域异步复位 |
| pulse_src | I | 1 | 源域脉冲输入 |
| pulse_dst | O | 1 | 目标域单周期脉冲输出 |
| busy | O | 1 | 展宽/同步中标志 |

## 典型应用场景
- 快域中断脉冲同步到慢域
- ADC 采样触发从控制域到 ADC 时钟域
- DMA 完成通知跨域传递

## 与其他实体的关系
- 是 `cdc_sync` 中 sync_pulse 的增强版，对源域脉冲宽度无要求
- 与 `cdc_handshake_bus` 互补：前者传单 bit 脉冲，后者传多 bit 数据
- 与 `gray_converter` 无直接关系，后者用于异步 FIFO 指针

## 设计注意事项
- STRETCH_CYCLES 选择：必须 ≥ dst 最慢周期 / src 最快周期 + 2（裕量）
- busy 期间新脉冲被忽略，连续脉冲场景需评估间隔
- 面积约 10-20 触发器（计数器 + 同步器 + 边沿检测）
- 相比 sync_pulse 优势：对源域脉冲宽度无要求，更适合非周期触发

## 参考
- 原始文档：`.claude/knowledge/cbb/cdc_pulse_stretch.md`
