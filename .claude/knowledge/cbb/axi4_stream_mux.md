# axi4_stream_mux — AXI4-Stream 多路复用器

> **用途**：多路 AXI4-Stream 输入通过仲裁共享单一输出通道
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

AXI4-Stream 多路复用器将多个 AXI4-Stream 从接口（Slave）的输出汇聚到一个主接口（Master），通过仲裁策略（固定优先级或轮询）在多个输入流之间选择。选中通道的 tvalid/tdata/tlast 等信号直通到输出，未选中通道的 tready 反压为低。

```
M0 (AXIS Slave) ──┐
M1 (AXIS Slave) ──┤──> ┌─────────────────┐ ──> S (AXIS Master)
M2 (AXIS Slave) ──┤    │ axi4_stream_mux  │
M3 (AXIS Slave) ──┘    └─────────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_PORTS` | parameter | 4 | 输入端口数量 |
| `DATA_WIDTH` | parameter | 32 | 数据位宽（bit） |
| `USER_WIDTH` | parameter | 0 | 用户自定义信号位宽 |
| `DEST_WIDTH` | parameter | 0 | 目标标识位宽 |
| `KEEP_EN` | parameter | 1 | tkeep 使能 |
| `LAST_EN` | parameter | 1 | tlast 使能 |
| `ARB_TYPE` | parameter | `"RR"` | 仲裁策略：`"FP"` = 固定优先级，`"RR"` = 轮询 |
| `PIPE_STAGE` | parameter | 0 | 输出流水线级数（0=直通，1=插入一级寄存器） |

---

## 接口

### 输入端口（NUM_PORTS 个 AXI4-Stream Slave）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `s_tvalid` | I | `NUM_PORTS` | 各端口 valid |
| `s_tready` | O | `NUM_PORTS` | 各端口 ready |
| `s_tdata` | I | `NUM_PORTS × DATA_WIDTH` | 各端口数据 |
| `s_tkeep` | I | `NUM_PORTS × DATA_WIDTH/8` | 各端口字节有效（KEEP_EN） |
| `s_tlast` | I | `NUM_PORTS` | 各端口帧结束（LAST_EN） |
| `s_tuser` | I | `NUM_PORTS × USER_WIDTH` | 各端口用户信号 |
| `s_tdest` | I | `NUM_PORTS × DEST_WIDTH` | 各端口目标标识 |

### 输出端口（1 个 AXI4-Stream Master）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `m_tvalid` | O | 1 | 输出 valid |
| `m_tready` | I | 1 | 下游 ready |
| `m_tdata` | O | `DATA_WIDTH` | 输出数据 |
| `m_tkeep` | O | `DATA_WIDTH/8` | 输出字节有效 |
| `m_tlast` | O | 1 | 输出帧结束 |
| `m_tuser` | O | `USER_WIDTH` | 输出用户信号 |
| `m_tdest` | O | `DEST_WIDTH` | 输出目标标识 |

### 公共端口

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `grant_idx` | O | `$clog2(NUM_PORTS)` | 当前被选中端口索引（调试用） |

---

## 时序

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
s_tvalid    ___|3'b101___|3'b111___|3'b010___
s_tready    ___|3'b001___|3'b010___|3'b010___
              ↑ 选中 M0   ↑ 选中 M1   ↑ 选中 M1
m_tvalid    ___|‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾‾
m_tdata     ___|M0的数据  |M1的数据  |M1的数据
m_tready    ___|‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾‾|‾‾‾‾‾‾‾‾‾
grant_idx   ___|  0      |  1      |  1      |
```

- 仲裁在每个传输完成后重新进行（tvalid & tready 握手完成）
- tlast 信号表示帧结束，帧传输过程中不会切换端口
- 选中端口的 tready 与下游 m_tready 直通，未选中端口 tready=0

---

## 用法

### 4 路 DMA 汇聚

```verilog
axi4_stream_mux #(
    .NUM_PORTS  (4),
    .DATA_WIDTH (64),
    .ARB_TYPE   ("RR"),
    .LAST_EN    (1),
    .PIPE_STAGE (1)
) u_axis_mux (
    .clk   (clk),
    .rst_n (rst_n),
    // 输入
    .s_tvalid ({dma3_tvalid, dma2_tvalid, dma1_tvalid, dma0_tvalid}),
    .s_tready ({dma3_tready, dma2_tready, dma1_tready, dma0_tready}),
    .s_tdata  ({dma3_tdata, dma2_tdata, dma1_tdata, dma0_tdata}),
    .s_tlast  ({dma3_tlast, dma2_tlast, dma1_tlast, dma0_tlast}),
    // 输出
    .m_tvalid (mux_tvalid),
    .m_tready (mux_tready),
    .m_tdata  (mux_tdata),
    .m_tlast  (mux_tlast),
    .grant_idx()
);
```

### 带 DEST 的路由复用

```verilog
axi4_stream_mux #(
    .NUM_PORTS  (2),
    .DATA_WIDTH (32),
    .DEST_WIDTH (4),
    .ARB_TYPE   ("FP")          // 固定优先级：M0 > M1
) u_route_mux (
    .clk   (clk),
    .rst_n (rst_n),
    .s_tvalid ({m1_tvalid, m0_tvalid}),
    .s_tready ({m1_tready, m0_tready}),
    .s_tdata  ({m1_tdata, m0_tdata}),
    .s_tdest  ({m1_tdest, m0_tdest}),
    .m_tvalid (out_tvalid),
    .m_tready (out_tready),
    .m_tdata  (out_tdata),
    .m_tdest  (out_tdest)
);
```

---

## 关键实现细节

- **仲裁核心**：内部实例化 `arbiter` 模块，grant 输出控制 MUX 选择
- **帧锁定**：LAST_EN=1 时，帧传输过程中（tlast=0）锁定仲裁，保证帧完整性
- **tready 反压**：只有被选中端口的 tready 连接到下游 m_tready，其余为 0
- **PIPE_STAGE=1**：输出插入一级流水线寄存器，改善时序，但增加 1 cycle 延迟
- **信号拼接**：输入信号以 `{M3, M2, M1, M0}` 顺序拼接，高位为高编号端口
- **面积**：仲裁逻辑 + MUX + 可选流水线寄存器
