# bigrr

> 大位宽位图轮询仲裁器 CBB，使用 RAM 存储 bitmap 优化面积和时序，支持 64-4096 请求者

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/bigrr.md |

## 核心特性
- 将 bitmap 存储在 Block RAM 中，解决大位宽（N≥128）轮询仲裁的面积和时序问题
- 两阶段搜索策略：段级 OR 归约 + 段内 findfirstone，关键路径拆分
- 支持单周期（PIPE_STAGE=1）和两级流水线（PIPE_STAGE=2）两种模式
- NUM_REQ 必须为 2 的幂，支持 64-4096 请求者
- 通过 set_idle 接口显式管理 bitmap 状态

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_REQ` | 1024 | 64-4096，2的幂 | 请求者数量 |
| `DATA_WIDTH` | 32 | 固定 | RAM 数据位宽（每字 32 bit） |
| `PIPE_STAGE` | 2 | 1/2 | 流水线级数 |
| `RESET_VAL` | `"ALL_IDLE"` | `"ALL_IDLE"` / `"FILE"` | 复位值 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `req` | I | `NUM_REQ` | 请求向量 |
| `grant` | O | `NUM_REQ` | 独热授权 |
| `grant_idx` | O | `$clog2(NUM_REQ)` | 授权索引 |
| `grant_valid` | O | 1 | 授权有效 |
| `set_idle` | I | 1 | 请求完成后标记空闲 |
| `set_idle_idx` | I | `$clog2(NUM_REQ)` | 标记空闲的索引 |

## 典型应用场景
- 千端口仲裁器：1024 端口交换芯片输出仲裁
- 大规模中断仲裁：512 路中断源轮询处理
- 网络交换芯片：256 端口入口/出口调度

## 与其他实体的关系
- 是 **priority_encoder** 和 **arbiter** 在大位宽场景（N≥128）的替代方案
- N<128 时用寄存器 `priority_encoder` 即可，无需 BIGRR
- 不涉及带宽分配（与 wrr/dwrr/robin_bucket 不同），仅做公平轮询

## 设计注意事项
- 两阶段搜索：段级搜索 `log2(NUM_SEGMENTS)` 级逻辑，位级搜索 5 级逻辑
- 有效请求 = `req & ~bitmap`（请求中但尚未被服务的）
- grant 后 bitmap 对应位置 1，set_idle 时清零
- RAM 读写冲突：搜索读和 bitmap 更新写需仲裁或双端口 RAM
- PIPE_STAGE=2 时仲裁延迟 2 cycle，PIPE_STAGE=1 时延迟 1 cycle
- 面积：`NUM_REQ/8` 字节 RAM + 2 个 findfirstone + 控制逻辑

## 参考
- 原始文档：`.claude/knowledge/cbb/bigrr.md`
