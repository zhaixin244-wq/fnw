# AXI4-Lite 接口协议

> **用途**：AXI4 简化版，用于寄存器访问等低带宽场景
> **规范版本**：AMBA AXI4-Lite (ARM IHI 0022E, §B2)
> **典型应用**：CSR 寄存器访问、外设配置、中断控制器、低速外设

---

## 1. 协议概述

AXI4-Lite 是 AXI4 协议的精简子集，专为低带宽、低复杂度的寄存器级访问场景设计。与 AXI4 Full 相比，AXI4-Lite 做了以下关键简化：

| 特性 | AXI4 Full | AXI4-Lite |
|------|-----------|-----------|
| 突发传输 | 支持（INCR / WRAP / FIXED） | **不支持**，仅单拍（single-beat） |
| ID 信号 | AWID / ARID / BID / RID | **无 ID 信号** |
| WLAST | 有（标记写数据最后一拍） | **无**（仅单拍，无需标记） |
| 数据位宽 | 8 / 16 / 32 / 64 / 128 / 256 / 512 / 1024 bit | **仅 32-bit 或 64-bit** |
| 地址位宽 | 最高 64-bit | 通常 **32-bit** |
| 缓存属性 | ARCACHE / AWCACHE | **无** |
| 保护属性 | ARPROT / AWPROT | **有**（3-bit，简化版） |
| QoS | ARQOS / AWQOS | **无** |
| Region | ARREGION / AWREGION | **无** |
| 用户信号 | ARUSER / AWUSER / WUSER / BUSER / RUSER | **无** |
| 事务顺序 | 乱序完成（基于 ID 排序） | **严格保序**（无 ID，FIFO 顺序） |

**核心特征总结**：

- 每次传输只有 **1 个 beat**，没有突发
- 没有 ID 信号，所有事务按发出顺序完成（严格保序）
- 数据宽度固定为 **32-bit** 或 **64-bit**
- 适合寄存器读写，不适合批量数据搬运
- 实现面积远小于 AXI4 Full Master/Slave

---

## 2. 通道信号表

AXI4-Lite 保留 5 个通道：Write Address (AW)、Write Data (W)、Write Response (B)、Read Address (AR)、Read Data (R)。

### 2.1 全局信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `ACLK` | I | 1 | 全局时钟，所有信号在 ACLK 上升沿采样 |
| `ARESETn` | I | 1 | 全局复位，低有效，异步复位同步释放 |

### 2.2 Write Address Channel (AW)

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `AWADDR` | Master → Slave | ADDR_WIDTH | 写事务地址，字节对齐 |
| `AWPROT` | Master → Slave | 3 | 保护属性：`[2]`=Privileged/User, `[1]`=Secure/Non-secure, `[0]`=Data/Instruction |
| `AWVALID` | Master → Slave | 1 | 地址有效信号 |
| `AWREADY` | Slave → Master | 1 | 从机就绪，可接收地址 |

### 2.3 Write Data Channel (W)

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `WDATA` | Master → Slave | DATA_WIDTH | 写数据（32 或 64 bit） |
| `WSTRB` | Master → Slave | DATA_WIDTH / 8 | 字节选通，每 bit 对应 WDATA 中一个字节，1=有效 |
| `WVALID` | Master → Slave | 1 | 写数据有效 |
| `WREADY` | Slave → Master | 1 | 从机就绪，可接收数据 |

### 2.4 Write Response Channel (B)

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `BRESP` | Slave → Master | 2 | 写响应码（见第 7 节） |
| `BVALID` | Slave → Master | 1 | 写响应有效 |
| `BREADY` | Master → Slave | 1 | 主机就绪，可接收响应 |

### 2.5 Read Address Channel (AR)

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `ARADDR` | Master → Slave | ADDR_WIDTH | 读事务地址，字节对齐 |
| `ARPROT` | Master → Slave | 3 | 保护属性（同 AWPROT） |
| `ARVALID` | Master → Slave | 1 | 地址有效信号 |
| `ARREADY` | Slave → Master | 1 | 从机就绪，可接收地址 |

### 2.6 Read Data Channel (R)

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `RDATA` | Slave → Master | DATA_WIDTH | 读数据（32 或 64 bit） |
| `RRESP` | Slave → Master | 2 | 读响应码（见第 7 节） |
| `RVALID` | Slave → Master | 1 | 读数据有效 |
| `RREADY` | Master → Slave | 1 | 主机就绪，可接收数据 |

---

## 3. 写事务时序

AXI4-Lite 写事务由 3 个阶段组成：地址握手 → 数据握手 → 响应握手。每阶段独立握手，共 3 次握手完成一次写操作。

### 3.1 写事务 ASCII 波形（最简情形，单周期握手）

```
          ___     ___     ___     ___     ___
ACLK    __|   |___|   |___|   |___|   |___|   |___
             ①       ②       ③       ④

AWADDR  ---<======= 地址 A ==================>-------
AWVALID _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\________________
AWREADY _____________/‾‾‾‾‾‾‾‾\____________________
                  ↑ AW 握手

WDATA   ---<======= 数据 D ==================>-------
WSTRB   ---<======= 选通 W ==================>-------
WVALID  _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_________________
WREADY  _____________/‾‾‾‾‾‾‾‾\____________________
                  ↑ W 握手

BRESP   -------------------<=== 响应 R ======>------
BVALID  _______________________/‾‾‾‾‾‾‾\____________
BREADY  _______________________/‾‾‾‾‾‾‾\____________
                            ↑ B 握手（写事务完成）
```

### 3.2 写事务流程

```
Master                          Slave
  |                               |
  |--- AWADDR, AWVALID=1 ------->|  ① Master 发写地址
  |                               |
  |<-- AWREADY=1 ----------------|  ② Slave 接收地址
  |                               |
  |--- WDATA, WSTRB, WVALID=1 -->|  ③ Master 发写数据
  |                               |
  |<-- WREADY=1 -----------------|  ④ Slave 接收数据
  |                               |
  |<-- BRESP, BVALID=1 ----------|  ⑤ Slave 发写响应
  |                               |
  |--- BREADY=1 ---------------->|  ⑥ Master 接收响应
  |                               |
  |         写事务完成             |
```

### 3.3 写事务时序约束

- AW 通道和 W 通道的握手**可以同时发生**（AWVALID + WVALID 同时拉高）
- BVALID 必须在 AW 握手和 W 握手**都完成后**才能拉高
- Master 收到 B 响应后，才能发起下一个写事务（保序要求）

### 3.4 写事务延迟情形

AW 和 W 通道握手可以在不同周期完成，常见三种情形：

**情形 1：AW 和 W 同时握手**
```
AWVALID ████████\___
AWREADY ████\___
WVALID  ████████\___
WREADY  ████\___
BVALID  __________████\___
BREADY  __________████\___
```

**情形 2：AW 先握手，W 后握手**
```
AWVALID ████████\___________
AWREADY ████\___
WVALID  __________███████\___
WREADY  __________████\___
BVALID  ____________________████\___
BREADY  ____________________████\___
```

**情形 3：W 先握手，AW 后握手**
```
WVALID  ████████\___________
WREADY  ████\___
AWVALID __________███████\___
AWREADY __________████\___
BVALID  ____________________████\___
BREADY  ____________________████\___
```

---

## 4. 读事务时序

AXI4-Lite 读事务由 2 个阶段组成：地址握手 → 数据握手。比写事务少一个响应阶段（读响应与读数据合并）。

### 4.1 读事务 ASCII 波形（最简情形，单周期握手）

```
          ___     ___     ___     ___     ___
ACLK    __|   |___|   |___|   |___|   |___|   |___
             ①       ②       ③       ④

ARADDR  ---<======= 地址 A ==================>-------
ARVALID _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_________________
ARREADY _____________/‾‾‾‾‾‾‾‾\____________________
                  ↑ AR 握手

RDATA   -------------------<=== 数据 D ========>----
RRESP   -------------------<=== 响应 R ========>----
RVALID  _______________________/‾‾‾‾‾‾‾\____________
RREADY  _______________________/‾‾‾‾‾‾‾\____________
                            ↑ R 握手（读事务完成）
```

### 4.2 读事务流程

```
Master                          Slave
  |                               |
  |--- ARADDR, ARVALID=1 ------->|  ① Master 发读地址
  |                               |
  |<-- ARREADY=1 ----------------|  ② Slave 接收地址
  |                               |
  |   （Slave 内部读取数据）        |
  |                               |
  |<-- RDATA, RRESP, RVALID=1 ---|  ③ Slave 返回数据+响应
  |                               |
  |--- RREADY=1 ---------------->|  ④ Master 接收数据
  |                               |
  |         读事务完成             |
```

### 4.3 读事务延迟情形

**情形 1：AR 和 R 在相邻周期握手（最小延迟）**
```
ARVALID ████████\___
ARREADY ████\___
RVALID  __________████\___
RREADY  __________████\___
```

**情形 2：Slave 延迟返回数据**
```
ARVALID ████████\___
ARREADY ████\___
RVALID  ______________________████\___
RREADY  ______________________████\___
```

**情形 3：Master 延迟接收（背压）**
```
ARVALID ████████\___
ARREADY ████\___
RVALID  __________████████████████\___
RREADY  ______________________████\___
          Slave 等待 Master 准备好
```

---

## 5. 握手规则

AXI4-Lite 遵循标准的 Valid/Ready 握手机制，规则与 AXI4 完全一致。

### 5.1 握手完成条件

一次握手在 **ACLK 上升沿** 同时检测到 `VALID=1` 且 `READY=1` 时完成（单周期）。

```
          ___     ___     ___
ACLK    __|   |___|   |   |   |___
                  ↑
            这个上升沿采样到 VALID=1 & READY=1
            → 握手完成，数据被采样
```

### 5.2 核心规则

**规则 1：VALID 信号一旦拉高，必须保持直到握手完成**

```
// 正确：VALID 保持稳定
VALID   _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
READY   _________________/‾‾‾‾\___
                              ↑ 握手完成，VALID 可以拉低

// 错误：VALID 在 READY 之前拉低（违反协议）
VALID   _______/‾‾‾‾‾‾‾\___
READY   _________________/‾‾‾‾\___
                        ↑ VALID 已拉低但 READY 还没来 → 协议违规
```

**规则 2：READY 可以依赖 VALID，也可以不依赖**

- Slave 可以在检测到 VALID 后才拉高 READY（依赖 VALID）
- Slave 也可以默认就拉高 READY（不依赖 VALID）
- 两种行为都符合协议

**规则 3：VALID 不能依赖 READY（防止组合环路）**

```
// 错误：VALID 的产生逻辑包含 READY
assign aw_valid = aw_ready && some_condition;  // 违反规则！

// 正确：VALID 独立产生
assign aw_valid = has_pending_write;
```

### 5.3 SVA 断言

```systemverilog
// VALID 稳定性断言
property p_valid_stable;
    @(posedge ACLK) disable iff (!ARESETn)
    ($rose(awvalid) && !awready) |=> awvalid;
endproperty
assert_valid_stable: assert property (p_valid_stable);
```

---

## 6. 字节选通（WSTRB）

### 6.1 WSTRB 信号定义

`WSTRB` 是写数据通道的字节选通信号，位宽为 `DATA_WIDTH / 8`。每个 bit 对应 `WDATA` 中的一个字节：

- `WSTRB[i] = 1`：`WDATA[8*i+7 : 8*i]` 字节有效，Slave 应写入
- `WSTRB[i] = 0`：`WDATA[8*i+7 : 8*i]` 字节无效，Slave 应忽略

### 6.2 32-bit 数据宽度的 WSTRB 编码

```
WSTRB   WDATA 字节选择
[3:0]   [31:24] [23:16] [15:8] [7:0]
 0001    —        —       —     ✓    仅写 byte[0]
 0010    —        —      ✓      —    仅写 byte[1]
 0100    —       ✓       —      —    仅写 byte[2]
 1000   ✓        —       —      —    仅写 byte[3]
 0011    —        —      ✓      ✓    写 byte[1:0]（半字）
 1100   ✓        ✓       —      —    写 byte[3:2]（半字）
 1111   ✓        ✓       ✓      ✓    写全部（全字）
 1010   ✓        —       ✓      —    非对齐选通（特殊用法）
```

### 6.3 使用示例

```verilog
// 写入偏移地址 0x04 的寄存器，仅写入低 16 bit
AWADDR  = 32'h0000_0004;
WDATA   = 32'hDEAD_BEEF;
WSTRB   = 4'b0011;      // 仅 byte[1:0] = 0xEF 0xBE 被写入
                         // byte[3:2] 被忽略

// 写入偏移地址 0x08 的寄存器，写入全部 32 bit
AWADDR  = 32'h0000_0008;
WDATA   = 32'h1234_5678;
WSTRB   = 4'b1111;      // 全字写入
```

### 6.4 读事务没有 WSTRB

读事务不支持字节选通——每次读操作返回完整的 `DATA_WIDTH` 数据。软件侧通过移位和掩码提取需要的字节：

```c
// C 语言示例：读取 32-bit 寄存器，提取 byte[2]
uint32_t val = *(volatile uint32_t*)(base + offset);
uint8_t byte2 = (val >> 16) & 0xFF;
```

---

## 7. 响应码（BRESP / RRESP）

### 7.1 响应码定义

| 编码 | 名称 | 含义 |
|------|------|------|
| `2'b00` | **OKAY** | 访问成功。正常读写操作完成 |
| `2'b01` | **EXOKAY** | 独占访问成功（AXI4-Lite 中极少使用） |
| `2'b10` | **SLVERR** | Slave 错误。地址可达但访问出错（如写只读寄存器、访问未初始化硬件） |
| `2'b11` | **DECERR** | 解码错误。地址不可达（地址映射中不存在该地址的 Slave） |

### 7.2 响应码使用场景

| 场景 | BRESP / RRESP | 说明 |
|------|---------------|------|
| 正常写寄存器 | OKAY | 写入成功 |
| 正常读寄存器 | OKAY | 返回有效数据 |
| 写只读寄存器 | SLVERR | 写操作被拒绝 |
| 读只写寄存器 | SLVERR | 返回数据无效 |
| 地址越界 | DECERR | Interconnect 产生 |
| 硬件故障 | SLVERR | Slave 内部错误 |
| 访问未连接地址 | DECERR | Interconnect 默认从机产生 |

### 7.3 设计建议

- Slave 模块在正常操作时始终返回 `OKAY`
- 对非法访问（如写只读地址）返回 `SLVERR`，而非静默忽略
- Interconnect 应对未映射地址返回 `DECERR`
- 软件侧应检查响应码，不应对所有响应无条件视为成功

---

## 8. 与 AXI4 Full 的对比表

| 对比项 | AXI4 Full | AXI4-Lite |
|--------|-----------|-----------|
| **数据宽度** | 8/16/32/64/128/256/512/1024 bit | 32 或 64 bit |
| **地址宽度** | 最高 64-bit | 通常 32-bit |
| **突发传输** | 支持 INCR/WRAP/FIXED，最大 256 beat | 不支持，仅单拍 |
| **突发长度** | AXLEN[7:0] (1~256) | 固定 1 |
| **突发大小** | AXSIZE[2:0] (1~128 byte) | 固定 4 或 8 byte |
| **ID 信号** | AWID/ARID/BID/RID | 无 |
| **事务排序** | 基于 ID 的乱序完成 | 严格保序 |
| **WLAST** | 有 | 无（单拍无需标记） |
| **字节选通** | WSTRB | WSTRB（相同） |
| **缓存属性** | ARCACHE/AWCACHE[3:0] | 无 |
| **保护属性** | ARPROT/AWPROT[2:0] | ARPROT/AWPROT[2:0]（保留） |
| **QoS** | ARQOS/AWQOS[3:0] | 无 |
| **Region** | ARREGION/AWREGION[3:0] | 无 |
| **用户信号** | xUSER | 无 |
| **写响应** | 支持 interleaving（AXI4 取消） | 不支持 interleaving |
| **原子操作** | 不支持（AXI4 不支持） | 不支持 |
| **典型延迟** | 1+ cycle（突发传输多拍） | 3~5 cycle（AW+W+B） |
| **实现面积** | 大（需 ID 匹配、burst 计数等） | **极小** |
| **典型用途** | DMA、存储控制器、高速数据通路 | CSR、配置寄存器、中断控制器 |

**一句话总结**：AXI4-Lite = AXI4 去掉突发 + 去掉 ID + 强制单拍，换取极简实现。

---

## 9. 设计注意事项

### 9.1 为什么不用突发

AXI4-Lite 的设计哲学是**极简**：

- **寄存器访问不需要突发**：读写一个寄存器只需单拍，突发传输反而增加复杂度
- **无 ID = 严格保序**：对寄存器访问，保序是自然需求，无需 ID 排序机制
- **面积优势显著**：省去 burst 计数器、ID 匹配逻辑、地址递增逻辑，面积可减少 50% 以上
- **时序更优**：控制逻辑简单，关键路径更短

如果需要批量数据传输（如 DMA），应使用 AXI4 Full 而非 AXI4-Lite。

### 9.2 寄存器文件实现建议

```verilog
// 典型 AXI4-Lite Slave 寄存器文件结构
module axi_lite_reg_file #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // AXI4-Lite Slave 端口（简化表示）
    input  wire [ADDR_WIDTH-1:0] awaddr,
    input  wire                  awvalid,
    output reg                   awready,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [DATA_WIDTH/8-1:0] wstrb,
    input  wire                  wvalid,
    output reg                   wready,
    output reg  [1:0]            bresp,
    output reg                   bvalid,
    input  wire                  bready,
    input  wire [ADDR_WIDTH-1:0] araddr,
    input  wire                  arvalid,
    output reg                   arready,
    output reg  [DATA_WIDTH-1:0] rdata,
    output reg  [1:0]            rresp,
    output reg                   rvalid,
    input  wire                  rready
);
```

**关键实现要点**：

1. **写地址锁存**：AW 握手后锁存 awaddr，供后续 W 握手时写入对应寄存器
2. **WSTRB 部分写入**：按 bit 选择性更新寄存器的对应字节
3. **读路径组合逻辑**：AR 握手后，根据 araddr 组合读出寄存器值，直连 rdata
4. **写优先**：同一地址同时读写时，返回刚写入的数据（bypass）
5. **响应码**：合法地址返回 OKAY，非法地址返回 SLVERR

### 9.3 握手时序要求

**写事务握手顺序**：

- AW 和 W 通道**可以同时握手**，也可以分开握手（两种方式均合法）
- BVALID 必须在 **AW 和 W 都握手完成后**才能拉高
- 不要求 AW 必须先于 W 握手（W 可以先于 AW）

**读事务握手顺序**：

- AR 握手后，Slave 内部读取数据，然后拉高 RVALID
- RVALID 可以在 AR 握手后的**任意周期**拉高（取决于 Slave 延迟）
- R 握手完成后，才能发起下一个读事务（或可在 R 握手前发起新的 AR——如果 Slave 支持 pipeline）

**常见错误**：

```
// 错误：BVALID 在 W 握手之前就拉高
always @(posedge clk) begin
    if (aw_handshake && !w_handshake)
        bvalid <= 1'b1;  // W 还没握手！协议违规
end

// 正确：等 AW 和 W 都完成
always @(posedge clk) begin
    if (aw_handshake && w_handshake)
        bvalid <= 1'b1;
end
```

### 9.4 Interconnect 注意事项

- AXI4-Lite Interconnect 通常很简单：地址解码 + MUX 选择
- 无 ID 信号意味着不能做事务重排序，Interconnect 必须保序
- 多 Master 场景需要仲裁（固定优先级或轮询）
- 未映射地址应返回 DECERR（通常接入一个默认 Slave）

### 9.5 复位行为

- `ARESETn` 拉低时，Master 的所有 VALID 信号必须拉低
- Slave 的 READY 信号在复位期间可以为任意值（规范不约束）
- 复位释放后，第一个事务可以在下一个 ACLK 上升沿发起

---

## 10. 典型实例化代码片段

### 10.1 AXI4-Lite Slave 简化实现（Verilog）

```verilog
module axi_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    localparam STRB_WIDTH = DATA_WIDTH / 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // AW Channel
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,
    // W Channel
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [STRB_WIDTH-1:0] s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,
    // B Channel
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,
    // AR Channel
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,
    // R Channel
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready
);

    // --- 地址偏移定义 ---
    localparam [ADDR_WIDTH-1:0] REG_CTRL   = 4'h0;
    localparam [ADDR_WIDTH-1:0] REG_STATUS = 4'h4;

    // --- 寄存器 ---
    reg [DATA_WIDTH-1:0] reg_ctrl;
    reg [DATA_WIDTH-1:0] reg_status;

    // --- 写地址锁存 ---
    reg [ADDR_WIDTH-1:0] awaddr_latch;
    reg                  aw_en;

    // === AW Channel 握手 ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            awaddr_latch  <= {ADDR_WIDTH{1'b0}};
            aw_en         <= 1'b1;
        end else begin
            if (s_axi_awvalid && aw_en && !s_axi_awready) begin
                s_axi_awready <= 1'b1;
                awaddr_latch  <= s_axi_awaddr;
                aw_en         <= 1'b0;
            end else begin
                s_axi_awready <= 1'b0;
                if (s_axi_bvalid && s_axi_bready) begin
                    aw_en <= 1'b1;
                end
            end
        end
    end

    // === W Channel 握手 + 写寄存器 ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_wready <= 1'b0;
            reg_ctrl     <= {DATA_WIDTH{1'b0}};
        end else begin
            if (s_axi_wvalid && s_axi_awready && !s_axi_wready) begin
                s_axi_wready <= 1'b1;
                // 按 WSTRB 字节写入
                case (awaddr_latch[3:0])
                    REG_CTRL: begin
                        if (s_axi_wstrb[0]) reg_ctrl[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_ctrl[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_ctrl[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_ctrl[31:24] <= s_axi_wdata[31:24];
                    end
                    default: ; // 无操作
                endcase
            end else begin
                s_axi_wready <= 1'b0;
            end
        end
    end

    // === B Channel 握手 ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (s_axi_awready && s_axi_awvalid && ~s_axi_bvalid
                && s_axi_wready && s_axi_wvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // === AR Channel 握手 ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

    // === R Channel 握手 + 读数据 ===
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= {DATA_WIDTH{1'b0}};
        end else begin
            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00; // OKAY
                case (s_axi_araddr[3:0])
                    REG_CTRL:   s_axi_rdata <= reg_ctrl;
                    REG_STATUS: s_axi_rdata <= reg_status;
                    default:    s_axi_rdata <= {DATA_WIDTH{1'b0}};
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
```

### 10.2 AXI4-Lite Master 简化实现（Verilog）

```verilog
module axi_lite_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    localparam STRB_WIDTH = DATA_WIDTH / 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // 用户接口
    input  wire                  wr_req,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire [STRB_WIDTH-1:0] wr_strb,
    output reg                   wr_done,
    input  wire                  rd_req,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output reg                   rd_done,
    // AXI4-Lite Master 端口
    output reg  [ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg                   m_axi_awvalid,
    input  wire                  m_axi_awready,
    output reg  [DATA_WIDTH-1:0] m_axi_wdata,
    output reg  [STRB_WIDTH-1:0] m_axi_wstrb,
    output reg                   m_axi_wvalid,
    input  wire                  m_axi_wready,
    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_bvalid,
    output reg                   m_axi_bready,
    output reg  [ADDR_WIDTH-1:0] m_axi_araddr,
    output reg                   m_axi_arvalid,
    input  wire                  m_axi_arready,
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rvalid,
    output reg                   m_axi_rready
);

    // === 写事务状态机 ===
    localparam [1:0] W_IDLE = 2'd0, W_ADDR = 2'd1,
                     W_DATA = 2'd2, W_RESP = 2'd3;
    reg [1:0] w_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state       <= W_IDLE;
            m_axi_awvalid <= 1'b0;
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;
            wr_done       <= 1'b0;
        end else begin
            wr_done <= 1'b0;
            case (w_state)
                W_IDLE: begin
                    m_axi_bready <= 1'b0;
                    if (wr_req) begin
                        m_axi_awaddr  <= wr_addr;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata   <= wr_data;
                        m_axi_wstrb   <= wr_strb;
                        m_axi_wvalid  <= 1'b1;
                        w_state       <= W_ADDR;
                    end
                end
                W_ADDR: begin
                    // 等待 AW 和 W 都完成握手
                    if (m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wready)  m_axi_wvalid  <= 1'b0;
                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        m_axi_bready <= 1'b1;
                        w_state      <= W_RESP;
                    end
                end
                W_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        wr_done      <= 1'b1;
                        w_state      <= W_IDLE;
                    end
                end
                default: w_state <= W_IDLE;
            endcase
        end
    end

    // === 读事务状态机 ===
    localparam [1:0] R_IDLE = 2'd0, R_ADDR = 2'd1, R_DATA = 2'd2;
    reg [1:0] r_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state       <= R_IDLE;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            rd_done       <= 1'b0;
        end else begin
            rd_done <= 1'b0;
            case (r_state)
                R_IDLE: begin
                    m_axi_rready <= 1'b0;
                    if (rd_req) begin
                        m_axi_araddr  <= rd_addr;
                        m_axi_arvalid <= 1'b1;
                        m_axi_rready  <= 1'b1;
                        r_state       <= R_ADDR;
                    end
                end
                R_ADDR: begin
                    if (m_axi_arready) m_axi_arvalid <= 1'b0;
                    if (m_axi_rvalid) begin
                        rd_data      <= m_axi_rdata;
                        m_axi_rready <= 1'b0;
                        rd_done      <= 1'b1;
                        r_state      <= R_IDLE;
                    end
                end
                default: r_state <= R_IDLE;
            endcase
        end
    end

endmodule
```

---

## 参考文档

- ARM IHI 0022E: AMBA AXI and ACE Protocol Specification, Section B2 (AXI4-Lite)
- ARM IHI 0022E: AMBA AXI and ACE Protocol Specification, Appendix B (Signal List)
- Xilinx PG059: AXI Reference Guide (UG1037)
