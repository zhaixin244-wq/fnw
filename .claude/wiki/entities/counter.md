# counter — 计数器

> 通用可配置计数器，支持 FREE/MODULO/UPDOWN 三种模式，使能/加载/清零

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/counter.md |

## 核心特性
- FREE 模式：自由计数到 MAX 停止
- MODULO 模式：模 N 计数，自动回绕
- UPDOWN 模式：上下计数（三角波）
- tc（终点标志）和 zero（零标志）输出
- 优先级：clr > load > en

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| CNT_WIDTH | 8 | - | 计数器位宽 |
| CNT_MAX | 2^CNT_WIDTH-1 | - | 计数上限 |
| CNT_MIN | 0 | - | 计数下限 |
| CNT_MODE | "FREE" | FREE/MODULO/UPDOWN | 计数模式 |
| LOAD_EN | 1 | 0/1 | 外部加载使能 |
| TC_AT_MAX | 1 | 0/1 | tc 产生位置 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| en | I | 1 | 计数使能 |
| load | I | 1 | 加载使能 |
| load_val | I | CNT_WIDTH | 加载值 |
| clr | I | 1 | 同步清零 |
| cnt | O | CNT_WIDTH | 当前计数值 |
| tc | O | 1 | 终点标志（单周期） |
| zero | O | 1 | 零标志（持续） |

## 典型应用场景
- 波特率生成（MODULO，115200 baud @50MHz）
- AXI 突发传输 beat 计数（MODULO + LOAD）
- 超时检测（FREE，达到上限拉高标志）

## 与其他实体的关系
- `watchdog` 内部使用计数器实现超时检测
- `clk_div` 内部使用计数器实现分频
- `pipeline_reg` 可配合计数器实现流水线管理

## 设计注意事项
- 复位计数器为 CNT_MIN
- tc 在到达终点时拉高 1 周期
- MODULO 模式：cnt >= CNT_MAX 时回绕到 CNT_MIN

## 参考
- 原始文档：`.claude/knowledge/cbb/counter.md`
