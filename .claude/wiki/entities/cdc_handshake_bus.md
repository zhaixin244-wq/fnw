# cdc_handshake_bus

> 多 bit CDC 握手总线，基于请求-应答协议安全传递跨时钟域数据

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/cdc_handshake_bus.md |

## 核心特性
- 多 bit 数据跨时钟域安全传输，基于 toggle + 2FF 同步
- 比异步 FIFO 节省面积（无存储阵列），适合低频场景
- 支持 src/dst 双向背压，数据不丢失
- 可配置同步器级数（2 或 3 级）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DATA_WIDTH | 32 | ≥1 | 数据位宽 |
| SYNC_STAGES | 2 | 2-3 | 同步器级数 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk_src / clk_dst | I | 1 | 源/目标时钟域 |
| rst_src_n / rst_dst_n | I | 1 | 源/目标域异步复位 |
| data_src | I | DATA_WIDTH | 源数据 |
| valid_src | I | 1 | 数据有效（请求） |
| ready_src | O | 1 | 传输完成（应答） |
| data_dst | O | DATA_WIDTH | 目标数据 |
| valid_dst | O | 1 | 数据有效 |
| ready_dst | I | 1 | 目标就绪 |

## 典型应用场景
- 配置参数从配置域传递到工作域（每秒几十到几千次）
- CPU 域下发命令到 DMA 域
- 工作域上报状态到监控域

## 与其他实体的关系
- 是 `cdc_sync` 中 sync_handshake 的独立封装，接口更清晰
- 与 `cdc_pulse_stretch` 互补：前者传多 bit 数据，后者传单 bit 脉冲
- 高频数据流应使用异步 FIFO 而非本模块

## 设计注意事项
- 最低延迟约 5 个慢时钟周期（2 req 同步 + 1 锁存 + 2 ack 同步）
- data_src 必须在 valid_src=1 期间保持不变
- valid_src 依赖 ready_src 时须注意组合环路风险
- 适用低频配置传递，不适合高频数据流
- 面积：DATA_WIDTH 触发器 + 4 同步触发器 + 边沿检测逻辑

## 参考
- 原始文档：`.claude/knowledge/cbb/cdc_handshake_bus.md`
