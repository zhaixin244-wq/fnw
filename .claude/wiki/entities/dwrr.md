# dwrr

> 基于信用值（Credit）的加权轮询调度器 CBB，支持变长包的精确字节级带宽比例分配

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/dwrr.md |

## 核心特性
- 引入信用额度（Quantum/Deficit Counter）机制，按字节而非按包计数
- 解决标准 WRR 在变长包场景下的不公平问题
- 支持 BYTE（按字节）和 BEAT（按传输拍数）两种计量模式
- 支持 STATIC 和 DYNAMIC 两种量子配置模式
- 长期带宽比例 = quantum 比例，即使包长差异大也保证公平

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_QUEUES` | 4 | ≥2 | 队列数量 |
| `QUANTUM_WIDTH` | 16 | ≥1 | 量子位宽（字节），最大量子 = 2^16-1 |
| `CREDIT_WIDTH` | 17 | QUANTUM_WIDTH+1 | 信用计数器位宽（需容纳负值） |
| `QUANTUM_MODE` | `"STATIC"` | `"STATIC"` / `"DYNAMIC"` | 量子模式 |
| `PKT_MODE` | `"BYTE"` | `"BYTE"` / `"BEAT"` | 计量模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `queue_req` | I | `NUM_QUEUES` | 队列非空指示 |
| `queue_len` | I | `NUM_QUEUES × 16` | 各队列头部包长度（字节） |
| `grant` | O | `NUM_QUEUES` | 调度授权（独热码） |
| `grant_idx` | O | `$clog2(NUM_QUEUES)` | 被调度队列索引 |
| `grant_valid` | O | 1 | 调度有效 |
| `tx_bytes` | I | 16 | 本次实际传输字节数 |
| `tx_done` | I | 1 | 传输完成脉冲 |
| `quantum` | I | `NUM_QUEUES × QUANTUM_WIDTH` | 各队列量子值（DYNAMIC 模式） |

## 典型应用场景
- 网络交换芯片出口调度：多优先级队列精确字节级带宽分配
- 变长突发 DMA 调度：大包场景下保证小队列不被饿死
- 多通道带宽隔离：按 quantum 比例分配总线带宽

## 与其他实体的关系
- 是 **wrr** 的字节级精确版本，解决变长包不公平问题
- 相比 **robin_bucket** 实现更复杂但带宽控制更精确
- credit 机制与 CBB 流控中 credit counter 设计思路一致

## 设计注意事项
- 信用计数器为有符号数（CREDIT_WIDTH 位），每轮初 +quantum，传输时 -tx_bytes
- credit < 0 时停止调度该队列，等待下轮恢复
- 一轮结束条件：所有队列 credit < 0 或无请求时重新加量子
- 跨包处理：一个量子不足以传完大包时，credit 累积到下一轮
- 面积：`NUM_QUEUES × CREDIT_WIDTH` 触发器 + 比较器 + 轮询逻辑
- queue_len 用于预判是否足够额度，非必须但可优化调度决策

## 参考
- 原始文档：`.claude/knowledge/cbb/dwrr.md`
