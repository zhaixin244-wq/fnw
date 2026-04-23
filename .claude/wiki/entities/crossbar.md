# crossbar

> N×M 非阻塞交叉开关，多主多从全连接互连矩阵

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/crossbar.md |

## 核心特性
- N×M 全连接互连，多主设备可同时访问不同从设备
- 从设备侧仲裁支持固定优先级（FP）和轮询（RR）
- 非阻塞并行传输，不同主从对完全并行
- 支持事务级锁定（LOCK_EN），保证原子操作
- 地址解码支持 RANGE 和 FIXED 两种模式

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_MASTER` | 4 | ≥1 | 主设备数量 |
| `NUM_SLAVE` | 4 | ≥1 | 从设备数量 |
| `DATA_WIDTH` | 32 | ≥8 | 数据位宽 |
| `ADDR_WIDTH` | 32 | ≥8 | 地址位宽 |
| `ARB_TYPE` | "RR" | FP/RR | 从设备侧仲裁策略 |
| `LOCK_EN` | 1 | 0/1 | 事务级锁定使能 |
| `DECODE_MODE` | "RANGE" | RANGE/FIXED | 地址解码模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `m_req` | I | NUM_MASTER | 主设备请求 |
| `m_addr` | I | NUM_MASTER×ADDR_WIDTH | 主设备地址 |
| `m_wdata` | I | NUM_MASTER×DATA_WIDTH | 主设备写数据 |
| `m_rdata` | O | NUM_MASTER×DATA_WIDTH | 主设备读数据 |
| `m_grant` | O | NUM_MASTER | 主设备授权 |
| `m_ready` | O | NUM_MASTER | 主设备就绪 |
| `s_req` | O | NUM_SLAVE | 从设备请求 |
| `s_rdata` | I | NUM_SLAVE×DATA_WIDTH | 从设备读数据 |
| `s_ready` | I | NUM_SLAVE | 从设备就绪 |

## 典型应用场景
- 多核访存：多个 CPU 核心并行访问 SRAM/DDR
- DMA 多端口汇聚：多个 DMA 通道同时传输
- NoC 路由节点：片上网络交换节点

## 与其他实体的关系
- 通常与 address_decoder 配合完成地址到从设备的映射
- 4×4 以下合理，8×8 以上建议考虑 NoC 方案

## 设计注意事项
- 面积随端口数平方增长：NUM_MASTER × NUM_SLAVE 组 MUX + NUM_SLAVE 个仲裁器
- 最大并行度 = min(NUM_MASTER, NUM_SLAVE)
- 同一从设备多主竞争时由从设备侧仲裁器决定胜者
- LOCK_EN=1 时事务锁定直到传输完成，注意死锁风险

## 参考
- 原始文档：`.claude/knowledge/cbb/crossbar.md`
