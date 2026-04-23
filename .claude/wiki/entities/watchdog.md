# watchdog — 看门狗定时器

> 系统健康监控，软件未及时喂狗时触发复位或中断，支持预分频和安全锁定

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/watchdog.md |

## 核心特性
- 预分频计数器 + 主计数器实现宽范围超时
- RESET/IRQ/BOTH 三种超时动作模式
- BOTH 模式先中断后复位，软件有机会在中断中喂狗
- 配置锁定机制（UNLOCK_KEY 解锁）
- 可选首次喂狗独立超时值（FIRST_TIMEOUT）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| CNT_WIDTH | 32 | - | 计数器位宽 |
| PRESCALE | 256 | - | 预分频比 |
| TIMEOUT_ACTION | "RESET" | RESET/IRQ/BOTH | 超时动作 |
| FIRST_TIMEOUT | 0 | - | 首次喂狗超时值 |
| LOCK_EN | 1 | 0/1 | 配置锁定使能 |
| UNLOCK_KEY | 32'h1ACCE551 | - | 解锁密钥 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| wdt_en | I | 1 | 看门狗使能 |
| kick | I | 1 | 喂狗脉冲 |
| timeout_val | I | CNT_WIDTH | 超时值 |
| irq_timeout_val | I | CNT_WIDTH | 中断超时值 |
| wdt_rst | O | 1 | 看门狗复位输出 |
| wdt_irq | O | 1 | 看门狗中断输出 |
| cnt_value | O | CNT_WIDTH | 当前计数值 |
| locked | O | 1 | 配置已锁定 |
| unlock | I | 1 | 写入 UNLOCK_KEY 解锁 |
| lock | I | 1 | 锁定配置 |

## 典型应用场景
- 系统看门狗（@100MHz，PRESCALE=256，超时约 256ms）
- 安全启动监控（FIRST_TIMEOUT=1）

## 与其他实体的关系
- `counter` 为通用计数器，本模块专注看门狗功能
- `intc` 可接收 wdt_irq 中断信号

## 设计注意事项
- 预分频使用系统时钟，即使软件跑飞也能检测
- 锁定后需写入 UNLOCK_KEY 才可修改配置
- 面积：CNT_WIDTH + prescale 计数器 + 状态机，约 0.5-1K GE

## 参考
- 原始文档：`.claude/knowledge/cbb/watchdog.md`
