# priority_encoder

> 将独热请求编码为二进制索引，支持可配置优先级方向和锁定模式的优先编码器 CBB

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/priority_encoder.md |

## 核心特性
- 支持 LOW（编号小优先）和 HIGH（编号大优先）两种优先级方向
- 同时输出独热 grant 和二进制 index，接口完整
- 可选锁定模式：lock 时冻结 grant，release 后重新仲裁
- 可配置纯组合输出或寄存器输出
- 广泛用于仲裁器、中断控制器、MUX 选择等场景

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_REQ` | 8 | ≥2 | 请求者数量 |
| `PRIORITY` | `"LOW"` | `"LOW"` / `"HIGH"` | 优先级方向 |
| `LOCK_EN` | 0 | 0/1 | 锁定使能 |
| `GRANT_OUT` | 1 | 0/1 | 是否输出独热 grant |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `req` | I | `NUM_REQ` | 请求向量 |
| `grant` | O | `NUM_REQ` | 独热授权 |
| `index` | O | `$clog2(NUM_REQ)` | 二进制索引 |
| `valid` | O | 1 | 存在有效请求 |
| `lock` | I | 1 | 锁定当前 grant（`LOCK_EN=1` 时有效） |
| `release` | I | 1 | 释放锁定（`LOCK_EN=1` 时有效） |

## 典型应用场景
- DMA 通道仲裁：多通道竞争时选择最高优先级通道
- 带锁定的总线仲裁：突发传输期间锁定 grant 防止中途切换
- MUX 选择：`GRANT_OUT=0` 时仅用 index 驱动多路选择器

## 与其他实体的关系
- **arbiter** 内部使用 `priority_encoder` 实现固定优先级策略
- **bigrr** 是大位宽场景的替代方案，N<128 时优先用 `priority_encoder`
- 与 `findfirstone`/`findlastone` 功能类似，但额外提供 grant 独热码和锁定机制

## 设计注意事项
- LOW 优先级实现：`req & (~req + 1)` 提取最低有效位再编码
- HIGH 优先级实现：从最高位向下扫描，或翻转后复用 LOW 逻辑
- 纯组合/寄存器输出可配置，根据时序需求选择
- 面积：`log2(NUM_REQ) × NUM_REQ` 门 + 可选锁定触发器
- 锁定期间 grant 冻结，release 后立即重新仲裁

## 参考
- 原始文档：`.claude/knowledge/cbb/priority_encoder.md`
