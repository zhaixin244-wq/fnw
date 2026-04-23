# shaper

> 基于令牌桶算法的流量整形器，用于带宽限速和流量监管

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/shaper.md |

## 核心特性
- 令牌桶算法控制数据流速率，支持多流并行整形
- SHAPER 模式（排队等待）和 POLICER 模式（丢弃/标记）双模式
- 每流独立配置 CIR（承诺信息速率）和 CBS（承诺突发大小）
- 令牌归零立即反压，CBS 限制瞬间突发量
- 速率可动态配置，支持运行时 cfg_update 更新

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_FLOWS` | 4 | ≥1 | 整形流数量 |
| `TOKEN_WIDTH` | 24 | ≥16 | 令牌计数器位宽 |
| `RATE_WIDTH` | 16 | ≥8 | 速率配置位宽 |
| `BURST_WIDTH` | 16 | ≥8 | 突发大小位宽 |
| `REFRESH_PERIOD` | 100 | ≥1 | 令牌刷新周期（时钟数） |
| `SHAPING_MODE` | "SHAPER" | SHAPER/POLICER | 整形或监管模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `data_req` | I | NUM_FLOWS | 各流传输请求 |
| `data_bytes` | I | NUM_FLOWS×16 | 各流本次传输字节数 |
| `permit` | O | NUM_FLOWS | 允许传输 |
| `blocked` | O | NUM_FLOWS | 被限速（令牌不足） |
| `cir` | I | NUM_FLOWS×RATE_WIDTH | 承诺信息速率 |
| `cbs` | I | NUM_FLOWS×BURST_WIDTH | 承诺突发大小 |
| `token_refresh` | I | 1 | 令牌刷新脉冲 |
| `cfg_update` | I | 1 | 配置更新使能 |

## 典型应用场景
- 网络出口整形（Egress Shaping），多流分别限速
- AXI 总线速率控制，防止 DDR 控制器过载
- 流量监管（Policer），对接收数据标记或丢弃

## 与其他实体的关系
- 常与 crossbar 配合，整形后接入交叉开关仲裁
- 可与 axi4_stream_mux 组合，对各输入流整形后复用输出

## 设计注意事项
- 令牌填充：`min(token_cnt + cir, cbs)`，不超过桶容量
- 速率换算：`实际速率 = cir × (clk_freq / REFRESH_PERIOD) bytes/sec`
- 面积：NUM_FLOWS × (TOKEN_WIDTH + RATE_WIDTH + BURST_WIDTH) 触发器 + 比较器/加法器
- REFRESH_PERIOD 影响速率精度，需根据时钟频率和目标速率计算

## 参考
- 原始文档：`.claude/knowledge/cbb/shaper.md`
