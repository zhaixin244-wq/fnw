# crossbar — 交叉开关

> **用途**：多主多从非阻塞互连，多个主设备可同时访问不同从设备
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

交叉开关（Crossbar）实现 N×M 的全连接互连矩阵，允许多个主设备（Master）同时访问不同的从设备（Slave），只要目标从设备不冲突。相比共享总线（同一时刻只有一对主从通信），交叉开关可并行传输，显著提升总带宽。适用于多核访存、NoC 路由节点、DMA 多端口汇聚等场景。

```
M0 ──┐         ┌── S0
M1 ──┼──> ┌──┐ ──┼── S1
M2 ──┤    │XBAR│ ──┤
M3 ──┘    └──┘ ──┘── S2

M0→S0, M1→S2, M2→S1 可同时工作（3路并行）
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_MASTER` | parameter | 4 | 主设备数量 |
| `NUM_SLAVE` | parameter | 4 | 从设备数量 |
| `DATA_WIDTH` | parameter | 32 | 数据位宽 |
| `ADDR_WIDTH` | parameter | 32 | 地址位宽 |
| `ARB_TYPE` | parameter | `"RR"` | 从设备侧仲裁策略：`"FP"` / `"RR"` |
| `LOCK_EN` | parameter | 1 | 事务级锁定使能 |
| `DECODE_MODE` | parameter | `"RANGE"` | 地址解码模式：`"RANGE"` = 地址范围，`"FIXED"` = 固定映射表 |

---

## 接口

### Master 侧（NUM_MASTER 组）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `m_req` | I | `NUM_MASTER` | 主设备请求 |
| `m_addr` | I | `NUM_MASTER × ADDR_WIDTH` | 主设备地址 |
| `m_wdata` | I | `NUM_MASTER × DATA_WIDTH` | 主设备写数据 |
| `m_we` | I | `NUM_MASTER` | 主设备写使能 |
| `m_rdata` | O | `NUM_MASTER × DATA_WIDTH` | 主设备读数据 |
| `m_grant` | O | `NUM_MASTER` | 主设备授权 |
| `m_ready` | O | `NUM_MASTER` | 主设备就绪 |

### Slave 侧（NUM_SLAVE 组）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `s_req` | O | `NUM_SLAVE` | 从设备请求 |
| `s_addr` | O | `NUM_SLAVE × ADDR_WIDTH` | 从设备地址 |
| `s_wdata` | O | `NUM_SLAVE × DATA_WIDTH` | 从设备写数据 |
| `s_we` | O | `NUM_SLAVE` | 从设备写使能 |
| `s_rdata` | I | `NUM_SLAVE × DATA_WIDTH` | 从设备读数据 |
| `s_ready` | I | `NUM_SLAVE` | 从设备就绪 |

### 公共端口

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |

---

## 时序

### 非阻塞并行访问

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__
m_req       ___|4'b1111_______________|
              ↑ M0→S0, M1→S2, M2→S1, M3→S3（全部命中不同从设备）
m_grant     ___|4'b1111_______________|  (全部授予)
s_req[S0]   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
s_req[S1]   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
s_req[S2]   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
s_req[S3]   ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_
```

### 从设备冲突仲裁

```
clk         __|‾|__|‾|__|‾|__|‾|__
m_req       ___|4'b0101___________|  (M0→S1, M2→S1，冲突!)
m_grant     ___|4'b0100___________|  (M2 胜出，M0 被仲裁)
m_ready[M0] _________________|‾‾‾|_  (M0 等待)
m_ready[M2] ___|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|_  (M2 立即传输)
```

---

## 用法

### 4×4 存储交叉开关

```verilog
crossbar #(
    .NUM_MASTER  (4),
    .NUM_SLAVE   (4),
    .DATA_WIDTH  (64),
    .ADDR_WIDTH  (32),
    .ARB_TYPE    ("RR"),
    .DECODE_MODE ("RANGE")
) u_mem_xbar (
    .clk       (clk),
    .rst_n     (rst_n),
    // Master 侧
    .m_req     ({cpu3_req, cpu2_req, cpu1_req, cpu0_req}),
    .m_addr    ({cpu3_addr, cpu2_addr, cpu1_addr, cpu0_addr}),
    .m_wdata   ({cpu3_wdata, cpu2_wdata, cpu1_wdata, cpu0_wdata}),
    .m_we      ({cpu3_we, cpu2_we, cpu1_we, cpu0_we}),
    .m_rdata   ({cpu3_rdata, cpu2_rdata, cpu1_rdata, cpu0_rdata}),
    .m_grant   ({cpu3_grant, cpu2_grant, cpu1_grant, cpu0_grant}),
    .m_ready   ({cpu3_ready, cpu2_ready, cpu1_ready, cpu0_ready}),
    // Slave 侧
    .s_req     ({mem3_req, mem2_req, mem1_req, mem0_req}),
    .s_addr    ({mem3_addr, mem2_addr, mem1_addr, mem0_addr}),
    .s_wdata   ({mem3_wdata, mem2_wdata, mem1_wdata, mem0_wdata}),
    .s_we      ({mem3_we, mem2_we, mem1_we, mem0_we}),
    .s_rdata   ({mem3_rdata, mem2_rdata, mem1_rdata, mem0_rdata}),
    .s_ready   ({mem3_ready, mem2_ready, mem1_ready, mem0_ready})
);
```

### 2×3 非对称交叉开关

```verilog
// 2 个 Master 访问 3 个 Slave（SRAM, ROM, 外设）
crossbar #(
    .NUM_MASTER  (2),
    .NUM_SLAVE   (3),
    .DATA_WIDTH  (32),
    .ADDR_WIDTH  (16),
    .ARB_TYPE    ("FP")           // 固定优先级：M0 > M1
) u_asym_xbar (
    .clk       (clk),
    .rst_n     (rst_n),
    .m_req     ({dma_req, cpu_req}),
    .m_addr    ({dma_addr, cpu_addr}),
    .m_wdata   ({dma_wdata, cpu_wdata}),
    .m_we      ({dma_we, cpu_we}),
    .m_rdata   ({dma_rdata, cpu_rdata}),
    .m_grant   ({dma_grant, cpu_grant}),
    .m_ready   ({dma_ready, cpu_ready}),
    .s_req     ({peri_req, rom_req, sram_req}),
    .s_addr    ({peri_addr, rom_addr, sram_addr}),
    .s_wdata   ({peri_wdata, rom_wdata, sram_wdata}),
    .s_we      ({peri_we, rom_we, sram_we}),
    .s_rdata   ({peri_rdata, rom_rdata, sram_rdata}),
    .s_ready   ({peri_ready, rom_ready, sram_ready})
);
```

---

## 关键实现细节

- **地址解码**：每个 Master 的地址经过解码确定目标 Slave
- **从设备侧仲裁**：多个 Master 访问同一 Slave 时，由 Slave 侧仲裁器决定胜者
- **非阻塞**：不同 Master 访问不同 Slave 时完全并行，无任何等待
- **带宽**：最大并行度 = min(NUM_MASTER, NUM_SLAVE)，峰值带宽 = 单端口 × 并行度
- **面积**：NUM_MASTER × NUM_SLAVE 组 MUX + NUM_SLAVE 个仲裁器
- **数据通路**：Master → 地址解码 → MUX 选择 → Slave，Slave → 数据 MUX → Master
- **锁支持**：LOCK_EN=1 时，事务锁定直到传输完成
- **面积代价**：交叉开关面积随端口数平方增长，4×4 以下合理，8×8 以上考虑 NoC 方案
