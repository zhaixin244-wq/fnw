# axi4_stream_mux

> AXI4-Stream 多路复用器，多路输入流通过仲裁共享单一输出通道

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/axi4_stream_mux.md |

## 核心特性
- 多路 AXI4-Stream 输入汇聚到单一输出，支持 FP（固定优先级）和 RR（轮询）仲裁
- 帧锁定：LAST_EN=1 时帧传输过程中不切换端口，保证帧完整性
- 选中端口 tready 直通下游，未选中端口 tready=0 反压
- 可选输出流水线（PIPE_STAGE=1），改善时序增加 1 cycle 延迟
- 支持 tkeep、tlast、tuser、tdest 可选信号

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `NUM_PORTS` | 4 | ≥1 | 输入端口数量 |
| `DATA_WIDTH` | 32 | ≥8 | 数据位宽 |
| `USER_WIDTH` | 0 | ≥0 | 用户自定义信号位宽 |
| `DEST_WIDTH` | 0 | ≥0 | 目标标识位宽 |
| `KEEP_EN` | 1 | 0/1 | tkeep 使能 |
| `LAST_EN` | 1 | 0/1 | tlast 使能 |
| `ARB_TYPE` | "RR" | FP/RR | 仲裁策略 |
| `PIPE_STAGE` | 0 | 0/1 | 输出流水线级数 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `s_tvalid` | I | NUM_PORTS | 各端口 valid |
| `s_tready` | O | NUM_PORTS | 各端口 ready |
| `s_tdata` | I | NUM_PORTS×DATA_WIDTH | 各端口数据 |
| `s_tlast` | I | NUM_PORTS | 各端口帧结束 |
| `m_tvalid` | O | 1 | 输出 valid |
| `m_tready` | I | 1 | 下游 ready |
| `m_tdata` | O | DATA_WIDTH | 输出数据 |
| `m_tlast` | O | 1 | 输出帧结束 |
| `grant_idx` | O | $clog2(NUM_PORTS) | 当前选中端口索引 |

## 典型应用场景
- 多路 DMA 汇聚：4 路 DMA 输出合并为单一数据流
- 带 DEST 的路由复用：多输入流按目标标识复用输出通道

## 与其他实体的关系
- 常与 shaper 组合，各输入流整形后复用输出
- 内部实例化 arbiter 模块完成仲裁

## 设计注意事项
- 输入信号按 `{M(N-1), ..., M1, M0}` 顺序拼接，高位为高编号端口
- 帧传输期间（tlast=0）锁定仲裁，避免帧内切换导致数据错乱
- 面积：仲裁逻辑 + MUX + 可选流水线寄存器

## 参考
- 原始文档：`.claude/knowledge/cbb/axi4_stream_mux.md`
