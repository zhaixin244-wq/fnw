# intc — 中断控制器

> 多源中断的汇聚、优先级仲裁、屏蔽与状态管理，支持电平/边沿触发

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/intc.md |

## 核心特性
- 支持 LEVEL（电平触发）和 EDGE（边沿触发）两种模式
- 可编程优先级仲裁（HAS_PRIORITY=1）或固定编号仲裁
- W1C 清除机制，pending <= pending & ~clear
- irq_raw（屏蔽前）和 irq_pending（屏蔽后）状态输出
- irq_id 输出最高优先级中断号

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| NUM_IRQ | 16 | - | 中断源数量 |
| PRIO_WIDTH | 4 | - | 优先级位宽 |
| LEVEL | "LEVEL" | LEVEL/EDGE | 中断触发方式 |
| HAS_PENDING | 1 | 0/1 | Pending 寄存器 |
| HAS_PRIORITY | 1 | 0/1 | 可编程优先级 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| irq_in | I | NUM_IRQ | 中断输入 |
| irq_out | O | 1 | 汇总中断输出（CPU） |
| irq_id | O | clog2(NUM_IRQ) | 最高优先级中断号 |
| irq_valid | O | 1 | 存在有效中断 |
| reg_irq_raw | O | NUM_IRQ | 原始中断状态 |
| reg_irq_pending | O | NUM_IRQ | 挂起中断状态 |
| reg_irq_enable | I | NUM_IRQ | 中断使能 |
| reg_irq_clear | I | NUM_IRQ | 中断清除（W1C） |
| reg_irq_priority | I | NUM_IRQ × PRIO_WIDTH | 优先级配置 |

## 典型应用场景
- SoC 外设中断集中管理（UART/SPI/I2C/Timer/GPIO/DMA）
- GPIO 按键边沿触发中断

## 与其他实体的关系
- `watchdog` 的 wdt_irq 可接入本模块
- `edge_detect` 的检测逻辑与 EDGE 模式内部实现类似

## 设计注意事项
- 边沿触发：pending = (pending | irq_edge) & ~clear，锁存直到软件清除
- 优先级仲裁：比较所有 pending 的优先级值，选择最高
- 面积：NUM_IRQ × (PRIO_WIDTH + 2) 触发器 + 优先级编码器，约 0.5-2K GE

## 参考
- 原始文档：`.claude/knowledge/cbb/intc.md`
