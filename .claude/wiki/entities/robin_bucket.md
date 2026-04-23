# robin_bucket

> 基于令牌桶 + 轮询机制的公平调度器 CBB，适合变长事务场景的差异化带宽控制

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/robin_bucket.md |

## 核心特性
- 结合轮询和令牌桶两种机制，每通道维护独立令牌桶
- 令牌不足的通道自动跳过，等待补充后继续
- 支持差异化消耗（cost 参数），不同通道每次消耗不同令牌数
- 令牌有上限（TOKEN_MAX），防止累积过多
- 实现比 dwrr 简单，适合事务计数而非字节计数场景

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_CH` | 4 | ≥2 | 通道数量 |
| `TOKEN_WIDTH` | 8 | ≥1 | 令牌计数器位宽 |
| `COST_WIDTH` | 4 | ≥1 | 单次消耗令牌数位宽 |
| `REFILL_VALUE` | 4 | ≥1 | 每轮补充令牌数 |
| `TOKEN_MAX` | 15 | ≤2^TOKEN_WIDTH-1 | 令牌桶容量上限 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `req` | I | `NUM_CH` | 通道请求 |
| `cost` | I | `NUM_CH × COST_WIDTH` | 各通道单次消耗令牌数 |
| `grant` | O | `NUM_CH` | 授权（独热码） |
| `grant_idx` | O | `$clog2(NUM_CH)` | 授权索引 |
| `grant_valid` | O | 1 | 授权有效 |
| `tx_done` | I | 1 | 传输完成（扣除令牌） |
| `refill` | I | 1 | 令牌补充脉冲 |
| `tokens` | O | `NUM_CH × TOKEN_WIDTH` | 各通道当前令牌数（调试用） |

## 典型应用场景
- DMA 突发调度：多通道按令牌配额公平调度
- NoC 路由仲裁：5 方向输入端口的轮询仲裁
- 差异化带宽控制：高 cost 通道带宽自动降低

## 与其他实体的关系
- 相比 **wrr** 实现更简单，按事务计数而非按权重
- 相比 **dwrr** 不支持字节级精确控制，但面积更小
- **bigrr** 是大位宽轮询的替代方案，不涉及带宽分配

## 设计注意事项
- 轮询指针从上一轮胜出者的下一个位置开始扫描
- 令牌扣除时机：tx_done 时 `tokens -= cost`
- 令牌补充时机：refill 脉冲时 `tokens = min(tokens + REFILL_VALUE, TOKEN_MAX)`
- 全部耗尽：所有通道 tokens < cost 时等待 refill 后重新调度
- refill 需外部定时器驱动，典型周期 256 cycles
- 面积：`NUM_CH × TOKEN_WIDTH` 触发器 + 轮询逻辑 + 比较器

## 参考
- 原始文档：`.claude/knowledge/cbb/robin_bucket.md`
