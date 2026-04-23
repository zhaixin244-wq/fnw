# AXI4-Stream 接口协议

> **用途**：高速流式数据传输，无地址空间概念
> **规范版本**：AMBA AXI4-Stream (ARM IHI 0051A)
> **典型应用**：视频流、DMA 数据搬运、DSP 链路、包处理流水线

---

## 1. 协议概述

AXI4-Stream 是 ARM AMBA 协议族中面向**流式数据传输**的接口标准。与 AXI4/AXI4-Lite 面向地址映射的存储访问不同，AXI4-Stream 的核心特征是：

- **无地址空间**：数据从 Master 流向 Slave，不存在地址译码和存储映射
- **单向数据流**：数据从源端（Master）流向目的端（Slave），无读/写分离
- **流控基于 TREADY/TVALID**：标准 Valid/Ready 握手协议，支持背压
- **支持包/帧边界标记**：通过 TLAST 信号标识传输包的最后一个 beat
- **参数化数据宽度**：TDATA 位宽可配置（8/16/32/64/128/256/... bit）
- **支持多路复用与路由**：TID/TDEST 提供流标识和目的路由信息

### 1.1 与 AXI4/AXI4-Lite 的本质区别

| 特性 | AXI4 | AXI4-Lite | AXI4-Stream |
|------|------|-----------|-------------|
| 地址空间 | 有（4GB） | 有（4GB） | **无** |
| 数据方向 | 读写分离 | 读写分离 | **单向流** |
| 突发传输 | 支持（1-256 beat） | 不支持（1 beat） | **无限制** |
| 握手信号 | Valid/Ready | Valid/Ready | Valid/Ready |
| 字节选通 | WSTRB | WSTRB | TSTRB/TKEEP |
| 包边界标记 | 无 | 无 | **TLAST** |
| 流标识 | 无 | 无 | **TID/TDEST** |
| 典型用途 | 存储映射、外设 | 寄存器配置 | 数据流、视频、DSP |
| 通道数 | 5（AR/R/AW/W/B） | 5（同上） | **1（单向）** |

---

## 2. 信号表

| 信号 | 方向 | 宽度 | 必需 | 说明 |
|------|------|------|------|------|
| `TVALID` | Master → Slave | 1 | **必须** | 数据有效信号 |
| `TREADY` | Slave → Master | 1 | **必须** | 从端就绪信号 |
| `TDATA` | Master → Slave | TDATA_WIDTH | **必须** | 数据载荷，宽度为字节的整数倍 |
| `TSTRB` | Master → Slave | TDATA_WIDTH/8 | 可选 | 字节有效指示（Position byte / Data byte） |
| `TKEEP` | Master → Slave | TDATA_WIDTH/8 | 可选 | 字节保留指示（Data byte / Null byte） |
| `TLAST` | Master → Slave | 1 | 可选 | 包/帧最后 beat 标记 |
| `TID` | Master → Slave | TID_WIDTH | 可选 | 流标识（Stream ID），用于多路复用 |
| `TDEST` | Master → Slave | TDEST_WIDTH | 可选 | 路由信息（Destination），用于交换网络 |
| `TUSER` | Master → Slave | TUSER_WIDTH | 可选 | 用户自定义 sideband 信号 |

### 2.1 TSTRB 与 TKEEP 的区别

| 字节类型 | TSTRB[i] | TKEEP[i] | 含义 |
|----------|----------|----------|------|
| Data byte | 1 | 1 | 有效数据字节 |
| Position byte | 1 | 0 | 位置信息字节（用于数据对齐等场景） |
| Null byte | 0 | 0 | 无效/空字节，被忽略 |
| Keep byte（TKEEP 为 1 时） | - | 1 | 保留字节 |

> **注意**：TSTRB=0 且 TKEEP=1 的组合是**保留状态**（Reserved），不应出现。
> 大多数设计仅使用 TKEEP 或 TSTRB 其中之一。TSTRB 更精细（区分 Position byte），TKEEP 更简单（有效/无效）。

---

## 3. 握手规则

AXI4-Stream 使用标准的 **Valid/Ready 握手协议**，规则与 AXI4 一致：

### 3.1 握手条件

```
当且仅当 TVALID=1 且 TREADY=1 时，发生一次数据传输（Transfer）。
```

### 3.2 核心规则

| 规则编号 | 规则描述 |
|----------|----------|
| HR-01 | Master 拉高 TVALID 后，必须保持所有数据/控制信号不变，直到握手完成 |
| HR-02 | TVALID 的拉高**不能依赖于 TREADY**（防止组合环路） |
| HR-03 | TREADY 可以依赖 TVALID，也可以在 TVALID 之前拉高 |
| HR-04 | TREADY 可以在任意时刻拉低，无需等待 TVALID |
| HR-05 | 握手完成后，Master 可以在同一周期拉高新的 TVALID 并更新数据 |
| HR-06 | TREADY 默认为 0（Slave 等待 Master）或 1（Slave 始终就绪）均可 |

### 3.3 握手状态机

```
                     TVALID=1
    ┌──────────────────────────────────────┐
    │                                      │
    ▼                                      │
 IDLE ─────────► WAIT ──────► TRANSFER ───┘
  │               │              │
  │  TVALID=0     │  TVALID=1    │  TVALID=1 & TREADY=1
  │  无传输       │  等待就绪    │  传输完成
  └───────────────┘              └─────► 新数据或返回 IDLE
```

---

## 4. 流式传输时序

### 4.1 连续传输（Back-to-Back Transfer）

```
         ___     ___     ___     ___     ___     ___
CLK    _|   |___|   |___|   |___|   |___|   |___|   |___
                    _______ _______ _______ _______
TDATA  -------------X__D0__X__D1__X__D2__X__D3__X--------
                    _______ _______ _______
TVALID _____________|       |       |       |_____________
                    _______ _______
TREADY _____________|       |       |_____________
                                        _______
TLAST  __________________________________|       |________

说明：D0, D1, D2 连续传输，D3 在 TVALID & TREADY 握手的同时 TLAST=1，
      表示该包的最后一个 beat。
```

### 4.2 带背压的传输（TREADY 延迟拉高）

```
         ___     ___     ___     ___     ___     ___     ___
CLK    _|   |___|   |___|   |___|   |___|   |___|   |___|   |___
                    _______                         _______
TDATA  -------------X__D0__X-----------------------X__D1__X----
                    _______                         _______
TVALID _____________|               _______________|       |___
                                    _______
TREADY _____________________________|       |_____________

说明：TVALID 在 clk2 拉高，但 TREADY 在 clk4 才拉高，
      因此 D0 保持稳定直到 clk5 完成握手，随后 D1 紧接传输。
```

### 4.3 TREADY 先于 TVALID 就绪

```
         ___     ___     ___     ___     ___
CLK    _|   |___|   |___|   |___|   |___|   |___
            _______ _______ _______ _______
TREADY _____|       |       |       |       |___
                    _______ _______
TDATA  -------------X__D0__X__D1__X-------------
                    _______ _______
TVALID _____________|       |       |_____________

说明：Slave 先拉高 TREADY 表示可以接收，Master 随后拉高 TVALID 送出数据。
      TREADY 始终保持高电平，实现零等待传输。
```

### 4.4 带 TLAST 的帧传输（完整帧）

```
         ___     ___     ___     ___     ___     ___
CLK    _|   |___|   |___|   |___|   |___|   |___|   |___
                    _______ _______ _______ _______ _______
TDATA  -------------X_HDR__X_D0___X_D1___X_D2___X_CRC__X--
                    _______ _______ _______ _______ _______
TVALID _____________|       |       |       |       |       |___
                    _______ _______ _______ _______ _______
TREADY _____________|       |       |       |       |       |___
                                                _______
TLAST  ________________________________________|       |________

说明：帧结构为 HDR → D0 → D1 → D2 → CRC，CRC 为最后一个 beat，TLAST=1。
      TLAST 在 CRC 有效的同时拉高，标识帧边界。
```

---

## 5. 字节类型（TSTRB vs TKEEP）

### 5.1 四种字节类型

以 TDATA_WIDTH=32 为例（4 字节）：

| TSTRB[3:0] | TKEEP[3:0] | TD[31:24] | TD[23:16] | TD[15:8] | TD[7:0] | 说明 |
|------------|------------|-----------|-----------|----------|---------|------|
| 4'b1111 | 4'b1111 | Data | Data | Data | Data | 完整 4 字节有效数据 |
| 4'b0110 | 4'b0110 | Null | Data | Data | Null | 仅中间 2 字节有效 |
| 4'b0011 | 4'b0011 | Null | Null | Data | Data | 低 2 字节有效 |
| 4'b1100 | 4'b1100 | Data | Data | Null | Null | 高 2 字节有效 |
| 4'b1010 | 4'b1000 | Position | Data | Position | Null | Position byte 场景 |
| 4'b0101 | 4'b0001 | Null | Data | Null | Data | 交替有效 |

### 5.2 典型使用场景

| 场景 | 使用方式 | 说明 |
|------|----------|------|
| 整字节传输 | TSTRB=全 1 / TKEEP=全 1 | 所有字节有效，最常见 |
| 部分字节（窄传输） | TSTRB / TKEEP 部分为 1 | 最后一个 beat 数据不满 |
| 数据压缩标识 | TKEEP=部分为 1 | 表示哪些字节被压缩保留 |
| 分包对齐 | TSTRB=部分为 1 | 表示填充字节位置 |

---

## 6. 帧与包概念

### 6.1 帧/包层次

```
┌─────────────────────────────────────────────────────┐
│                      帧（Frame）                      │
│  ┌──────────┬──────────┬──────────┬───────────────┐  │
│  │ 包 0     │ 包 1     │ 包 2     │ 包 N          │  │
│  │ (TLAST=0)│ (TLAST=0)│ (TLAST=0)│ (TLAST=1)     │  │
│  └──────────┴──────────┴──────────┴───────────────┘  │
└─────────────────────────────────────────────────────┘
```

- **Beat**：一次握手传输，TLAST=0
- **Packet / 包**：一组连续的 beat，最后一个 beat TLAST=1
- **Frame / 帧**：包含一个或多个包的完整数据单元（TLAST 标记包边界）

### 6.2 TLAST 的作用

| 作用 | 说明 |
|------|------|
| 包边界标记 | TLAST=1 标识当前 beat 为包的最后一个 beat |
| 帧结束检测 | 收端通过 TLAST 判断何时组装完一个包 |
| 缓冲区释放 | 下游收到 TLAST 后可释放缓冲区用于下一包 |
| CRC/校验 | TLAST beat 通常携带校验信息 |
| 背压同步 | TLAST 可用于标记传输序列的结束点，用于仲裁切换 |

### 6.3 TID 与 TDEST

| 信号 | 用途 | 典型宽度 |
|------|------|----------|
| `TID` | 流标识：区分来自不同源的数据流 | 1-8 bit |
| `TDEST` | 路由/目的信息：交换网络中决定数据转发方向 | 1-8 bit |

**TID 使用示例**：
```
TID=0: 视频流 A
TID=1: 视频流 B
TID=2: 音频流
TID=3: 控制流
```

**TDEST 使用示例**（交换网络）：
```
TDEST=0: 转发到输出端口 0
TDEST=1: 转发到输出端口 1
TDEST=2: 转发到 DMA 引擎
TDEST=3: 转发到错误处理模块
```

---

## 7. 用户定义信号（TUSER）

TUSER 是 Sideband 信号，用于传递与数据流相关的自定义信息。

### 7.1 典型用途

| 用途 | TUSER 编码说明 |
|------|----------------|
| 错误标记 | TUSER[0]=1 表示当前 beat 数据有错 |
| 优先级 | TUSER[1:0] 表示数据包优先级（00=低, 11=高） |
| 奇偶校验 | TUSER 携带 TDATA 的奇偶校验位 |
| 帧号 | TUSER 携带帧序号，用于乱序检测 |
| SOT/EOT 标记 | TUSER 标记 Start/End of Transfer |
| 数据类型 | TUSER 标记当前 beat 数据类型（头/体/尾） |

### 7.2 使用约束

- TUSER 在 TVALID=1 期间必须保持稳定（同 TDATA）
- TUSER 在帧内可以变化（每 beat 不同）
- TUSER 宽度应满足最小必要原则，避免浪费布线资源

---

## 8. 典型互联拓扑

### 8.1 基本互联单元

```
    M0 ──┐
         ├──► Arbiter ──► S0
    M1 ──┘

    M0 ──► Decoder ──┬──► S0
                     ├──► S1
                     └──► S2

    M0 ──┐
         ├──► MUX ──► S0（带仲裁的 MUX）
    M1 ──┘

    M0 ──► DEMUX ──┬──► S0
                   ├──► S1
                   └──► S2
```

### 8.2 互联拓扑类型

| 拓扑 | 说明 | 典型场景 |
|------|------|----------|
| **Point-to-Point** | 1 Master → 1 Slave | 最简单的直连 |
| **M:N MUX/Arbiter** | N Master → M Slave，基于 TDEST/TID 仲裁 | 多源汇聚 |
| **1:N DEMUX** | 1 Master → N Slave，基于 TDEST 路由 | 广播/路由 |
| **N:M Crossbar** | N Master → M Slave，全交叉 | 交换网络 |
| **Packer/Unpacker** | 数据宽度转换 | 不同位宽互联 |

### 8.3 仲裁策略

| 策略 | 说明 |
|------|------|
| Round-Robin | 公平轮询，防止饥饿 |
| Fixed Priority | 固定优先级，简单但可能饥饿 |
| TID-based | 按流标识仲裁，支持帧锁定 |
| 帧锁定仲裁 | 同一帧内的 beat 必须连续传输，TLAST 时释放仲裁 |

---

## 9. 吞吐计算

### 9.1 基本公式

```
吞吐量 = TDATA_WIDTH (bit) × 频率 (Hz) / 8 (bytes)

示例：
  TDATA_WIDTH = 128 bit, 频率 = 250 MHz
  吞吐量 = 128 × 250 × 10^6 / 8 = 4 GB/s
```

### 9.2 常见配置与吞吐

| TDATA_WIDTH | 频率 | 吞吐量 | 备注 |
|-------------|------|--------|------|
| 8 bit | 100 MHz | 100 MB/s | 低速控制流 |
| 32 bit | 200 MHz | 800 MB/s | 中速数据流 |
| 64 bit | 250 MHz | 2 GB/s | 高速数据流 |
| 128 bit | 250 MHz | 4 GB/s | 视频 4K |
| 256 bit | 250 MHz | 8 GB/s | 超高速 |
| 512 bit | 200 MHz | 12.8 GB/s | 高带宽 DMA |

### 9.3 考虑 TSTRB/TKEEP 的有效吞吐

```
有效吞吐 = 吞吐量 × (有效字节数 / 总字节数)

示例：
  TDATA_WIDTH = 128 bit（16 字节），TKEEP=16'h0FFF（12 字节有效）
  有效吞吐 = 4 GB/s × (12 / 16) = 3 GB/s
```

### 9.4 考虑 TREADY 背压的实际吞吐

```
实际吞吐 = 峰值吞吐 × (TREADY=1 的周期数 / 总周期数)

如果 Slave 每 N 周期接受 1 beat：
  实际吞吐 = 峰值吞吐 / N
```

---

## 10. 设计注意事项

### 10.1 背压处理

| 场景 | 处理方式 |
|------|----------|
| Slave 处理慢 | TREADY 拉低 → Master 暂停发送 |
| 上游缓冲满 | 反压上游 TREADY → 级联背压 |
| 需要丢弃数据 | Slave 拉高 TREADY 但忽略数据（需配合 TLAST） |
| 超时保护 | 背压超时后需报错/中断（TUSER 或 sideband） |

**背压传播要点**：
- TREADY 必须能从 Slave **穿透到** Master（或缓冲 FIFO）
- 中间互联节点（MUX/DEMUX）必须正确传递背压
- FIFO 深度 = 最大突发长度 + 流控延迟

### 10.2 帧锁定仲裁

在多 Master 互联场景下，必须使用**帧锁定仲裁**：

- 仲裁器选择一个 Master 后，在其 TLAST 之前**不得切换**
- TLAST 是仲裁释放的唯一合法时机
- 违反此规则会导致帧被打断，接收端无法正确组装

```
正确：M0: [D0 D1 D2 TLAST] → 切换 → M1: [D0 D1 TLAST]
错误：M0: [D0 D1] → 切换 → M1: [D0] → M0: [D2 TLAST]（帧被打断）
```

### 10.3 CDC（跨时钟域）方案

| 方案 | 适用场景 | 说明 |
|------|----------|------|
| **异步 FIFO** | 不同频率时钟域 | 最通用，支持 full handshake |
| **Gray 码同步** | 频率比例为整数倍 | 控制信号用 Gray 码编码 |
| **两级触发器同步** | 慢域到快域、低速信号 | 简单但有概率亚稳态 |
| **握手同步器** | 要求严格无丢失 | 四相握手，延迟较高 |

> **推荐**：AXI4-Stream 跨时钟域优先使用**异步 FIFO**，可同时处理数据和流控信号。

### 10.4 数据宽度转换

| 转换类型 | 模块名称 | 关键点 |
|----------|----------|--------|
| 宽→窄（Downsizer） | Data Width Converter | 拆分 beat，TKEEP 随之调整 |
| 窄→宽（Upsizer） | Data Width Converter | 合并多个 beat，缓冲后输出 |
| 非整数比 | 需要两级转换 | 先适配到公倍数宽度 |

### 10.5 常见错误

| 错误 | 后果 | 正确做法 |
|------|------|----------|
| 忽略 TREADY 背压 | 数据丢失 | 必须等待 TREADY 拉高 |
| TLAST 在非最后一个 beat 拉高 | 包边界错误 | TLAST 仅在包最后 beat 为 1 |
| 帧锁定期间仲裁切换 | 帧被打断 | 等到 TLAST 才释放仲裁 |
| TSTRB/TKEEP 与 TDATA 不匹配 | 解析错误 | 每个 beat 正确标注有效字节 |
| 跨时钟域不使用同步器 | 亚稳态、数据错误 | 使用异步 FIFO 或同步器 |

---

## 11. 典型实例化

### 11.1 Master 端（发送端）

```verilog
module axis_master #(
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter DEST_WIDTH = 4,
    parameter USER_WIDTH = 4
)(
    input  wire                      clk,
    input  wire                      rst_n,
    // AXI4-Stream Master 接口
    output wire [DATA_WIDTH-1:0]     m_axis_tdata,
    output wire [DATA_WIDTH/8-1:0]   m_axis_tstrb,
    output wire [DATA_WIDTH/8-1:0]   m_axis_tkeep,
    output wire                      m_axis_tlast,
    output wire [ID_WIDTH-1:0]       m_axis_tid,
    output wire [DEST_WIDTH-1:0]     m_axis_tdest,
    output wire [USER_WIDTH-1:0]     m_axis_tuser,
    output wire                      m_axis_tvalid,
    input  wire                      m_axis_tready
);

    // --- 内部信号 ---
    reg [DATA_WIDTH-1:0]     tdata_reg;
    reg [DATA_WIDTH/8-1:0]   tstrb_reg;
    reg [DATA_WIDTH/8-1:0]   tkeep_reg;
    reg                      tlast_reg;
    reg [ID_WIDTH-1:0]       tid_reg;
    reg [DEST_WIDTH-1:0]     tdest_reg;
    reg [USER_WIDTH-1:0]     tuser_reg;
    reg                      tvalid_reg;

    wire handshake_done = m_axis_tvalid & m_axis_tready;

    // --- 输出赋值 ---
    assign m_axis_tdata  = tdata_reg;
    assign m_axis_tstrb  = tstrb_reg;
    assign m_axis_tkeep  = tkeep_reg;
    assign m_axis_tlast  = tlast_reg;
    assign m_axis_tid    = tid_reg;
    assign m_axis_tdest  = tdest_reg;
    assign m_axis_tuser  = tuser_reg;
    assign m_axis_tvalid = tvalid_reg;

    // --- 状态定义 ---
    localparam [1:0] S_IDLE = 2'd0,
                     S_SEND = 2'd1,
                     S_LAST = 2'd2;

    reg [1:0] state_cur, state_nxt;
    reg [7:0] beat_cnt, beat_cnt_nxt;

    // --- 时序逻辑 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_cur  <= S_IDLE;
            beat_cnt   <= 8'd0;
            tvalid_reg <= 1'b0;
            tdata_reg  <= {DATA_WIDTH{1'b0}};
            tstrb_reg  <= {(DATA_WIDTH/8){1'b0}};
            tkeep_reg  <= {(DATA_WIDTH/8){1'b0}};
            tlast_reg  <= 1'b0;
            tid_reg    <= {ID_WIDTH{1'b0}};
            tdest_reg  <= {DEST_WIDTH{1'b0}};
            tuser_reg  <= {USER_WIDTH{1'b0}};
        end else begin
            state_cur  <= state_nxt;
            beat_cnt   <= beat_cnt_nxt;
            tvalid_reg <= tvalid_nxt;
            tdata_reg  <= tdata_nxt;
            tstrb_reg  <= tstrb_nxt;
            tkeep_reg  <= tkeep_nxt;
            tlast_reg  <= tlast_nxt;
            tid_reg    <= tid_nxt;
            tdest_reg  <= tdest_nxt;
            tuser_reg  <= tuser_nxt;
        end
    end

    // --- 组合逻辑：次态与输出 ---
    // （示意，实际根据数据源替换）
    reg [DATA_WIDTH-1:0]     tdata_nxt;
    reg [DATA_WIDTH/8-1:0]   tstrb_nxt;
    reg [DATA_WIDTH/8-1:0]   tkeep_nxt;
    reg                      tlast_nxt;
    reg [ID_WIDTH-1:0]       tid_nxt;
    reg [DEST_WIDTH-1:0]     tdest_nxt;
    reg [USER_WIDTH-1:0]     tuser_nxt;
    reg                      tvalid_nxt;
    reg [7:0]                beat_cnt_nxt;

    always @(*) begin
        state_nxt    = state_cur;
        beat_cnt_nxt = beat_cnt;
        tvalid_nxt   = tvalid_reg;
        tdata_nxt    = tdata_reg;
        tstrb_nxt    = tstrb_reg;
        tkeep_nxt    = tkeep_reg;
        tlast_nxt    = tlast_reg;
        tid_nxt      = tid_reg;
        tdest_nxt    = tdest_reg;
        tuser_nxt    = tuser_reg;

        case (state_cur)
            S_IDLE: begin
                if (start_i) begin
                    state_nxt    = S_SEND;
                    beat_cnt_nxt = 8'd0;
                    tvalid_nxt   = 1'b1;
                    tdata_nxt    = data_i;
                    tstrb_nxt    = {(DATA_WIDTH/8){1'b1}};
                    tkeep_nxt    = {(DATA_WIDTH/8){1'b1}};
                    tlast_nxt    = 1'b0;
                    tid_nxt      = tid_i;
                    tdest_nxt    = tdest_i;
                    tuser_nxt    = {USER_WIDTH{1'b0}};
                end
            end
            S_SEND: begin
                if (handshake_done) begin
                    if (beat_cnt == max_beats - 1) begin
                        state_nxt    = S_LAST;
                        tlast_nxt    = 1'b1;
                    end else begin
                        beat_cnt_nxt = beat_cnt + 8'd1;
                        tdata_nxt    = data_i;
                    end
                end
            end
            S_LAST: begin
                if (handshake_done) begin
                    state_nxt    = S_IDLE;
                    tvalid_nxt   = 1'b0;
                    tlast_nxt    = 1'b0;
                end
            end
            default: begin
                state_nxt = S_IDLE;
            end
        endcase
    end

endmodule
```

### 11.2 Slave 端（接收端）

```verilog
module axis_slave #(
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter DEST_WIDTH = 4,
    parameter USER_WIDTH = 4
)(
    input  wire                      clk,
    input  wire                      rst_n,
    // AXI4-Stream Slave 接口
    input  wire [DATA_WIDTH-1:0]     s_axis_tdata,
    input  wire [DATA_WIDTH/8-1:0]   s_axis_tstrb,
    input  wire [DATA_WIDTH/8-1:0]   s_axis_tkeep,
    input  wire                      s_axis_tlast,
    input  wire [ID_WIDTH-1:0]       s_axis_tid,
    input  wire [DEST_WIDTH-1:0]     s_axis_tdest,
    input  wire [USER_WIDTH-1:0]     s_axis_tuser,
    input  wire                      s_axis_tvalid,
    output wire                      s_axis_tready
);

    // --- 内部信号 ---
    wire handshake_done = s_axis_tvalid & s_axis_tready;

    // --- Ready 产生逻辑 ---
    // 简单示例：只要内部 FIFO 不满就 ready
    wire fifo_not_full;
    assign s_axis_tready = fifo_not_full;

    // --- 数据接收 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位所有接收寄存器
        end else if (handshake_done) begin
            // 捕获数据到内部 FIFO 或处理逻辑
            // data_reg  <= s_axis_tdata;
            // tlast_reg <= s_axis_tlast;
            // tid_reg   <= s_axis_tid;
            // tdest_reg <= s_axis_tdest;
            // tuser_reg <= s_axis_tuser;
        end
    end

endmodule
```

### 11.3 顶层连接

```verilog
// 顶层模块中直连 Master 和 Slave
axis_master #(
    .DATA_WIDTH (128),
    .ID_WIDTH   (4),
    .DEST_WIDTH (4),
    .USER_WIDTH (4)
) u_master (
    .clk             (clk),
    .rst_n           (rst_n),
    .m_axis_tdata    (tdata),
    .m_axis_tstrb    (tstrb),
    .m_axis_tkeep    (tkeep),
    .m_axis_tlast    (tlast),
    .m_axis_tid      (tid),
    .m_axis_tdest    (tdest),
    .m_axis_tuser    (tuser),
    .m_axis_tvalid   (tvalid),
    .m_axis_tready   (tready)
);

axis_slave #(
    .DATA_WIDTH (128),
    .ID_WIDTH   (4),
    .DEST_WIDTH (4),
    .USER_WIDTH (4)
) u_slave (
    .clk             (clk),
    .rst_n           (rst_n),
    .s_axis_tdata    (tdata),
    .s_axis_tstrb    (tstrb),
    .s_axis_tkeep    (tkeep),
    .s_axis_tlast    (tlast),
    .s_axis_tid      (tid),
    .s_axis_tdest    (tdest),
    .s_axis_tuser    (tuser),
    .s_axis_tvalid   (tvalid),
    .s_axis_tready   (tready)
);
```

---

## 附录

### A. 缩略语

| 缩写 | 全称 |
|------|------|
| AXI | Advanced eXtensible Interface |
| AMBA | Advanced Microcontroller Bus Architecture |
| ARM | Advanced RISC Machines |
| CDC | Clock Domain Crossing |
| DMA | Direct Memory Access |
| DSP | Digital Signal Processing |
| FIFO | First In First Out |

### B. 参考文档

| 文档 | 编号 | 说明 |
|------|------|------|
| AMBA AXI4-Stream Protocol Specification | ARM IHI 0051A | 官方协议规范 |
| AMBA AXI Protocol Specification | ARM IHI 0022D | AXI4 通用规范 |
| AMBA AXI4-Lite Specification | ARM IHI 0022D | AXI4-Lite 规范 |
