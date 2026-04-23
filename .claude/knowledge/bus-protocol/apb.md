# APB 接口协议

> **用途**：低功耗外设总线，用于寄存器访问
> **规范版本**：AMBA APB (ARM IHI 0024E, APB4)
> **典型应用**：外设寄存器访问、低速外设配置、SoC 外设桥

---

## 1. 协议概述

### 1.1 AMBA 总线层级定位

APB（Advanced Peripheral Bus）是 ARM AMBA 总线协议族中最低层级的总线，专为低带宽、低功耗外设寄存器访问设计。在整个 SoC 总线拓扑中，APB 处于最末端：

```
                    ┌─────────────┐
                    │   Processor │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │  AXI / AHB  │    ← 高性能系统总线（High-Performance Bus）
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │ AXI/AHB-to- │
                    │ APB Bridge  │    ← 总线桥接器（地址译码 + 协议转换）
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         ┌────┴────┐  ┌────┴────┐  ┌────┴────┐
         │ UART    │  │ SPI     │  │ GPIO    │  ← APB 外设
         │ Timer   │  │ I2C     │  │ Watchdog│
         └─────────┘  └─────────┘  └─────────┘
```

### 1.2 核心特征

| 特性 | 说明 |
|------|------|
| **低功耗** | 无流水线、无 burst、信号翻转少，静态功耗极低 |
| **简单** | 三状态 FSM（IDLE → SETUP → ACCESS），协议逻辑极简 |
| **无流水线** | 每次事务必须完成才能发起下一次，无 Outstanding 事务 |
| **无 Burst** | 每次传输只访问一个地址，不支持突发传输 |
| **从设备扩展** | 通过 PSELx 信号选择不同外设，支持多外设互联 |
| **APB4 扩展** | 新增 PREADY（等待扩展）、PSLVERR（错误响应）、PSTRB（字节选通） |

### 1.3 设计哲学

APB 的设计目标是**最小化外设接口复杂度**：
- 外设端只需解码少量信号即可完成寄存器读写
- 无握手协商开销（相比 AXI 的 valid/ready 握手）
- 总线桥负责与高性能总线的协议转换，外设只关心 APB 接口
- 适合 UART、Timer、GPIO、I2C、SPI、Watchdog 等低速控制寄存器

---

## 2. APB 状态机

APB 协议核心是一个三状态 FSM，所有事务由该状态机驱动：

```
                    PSELx=0
            ┌──────────────────────────┐
            │                          │
            ▼                          │
     ┌─────────────┐                  │
     │    IDLE     │                  │
     │  (空闲态)    │                  │
     └──────┬──────┘                  │
            │                         │
            │ PSELx=1                 │
            │ PENABLE=0               │
            ▼                         │
     ┌─────────────┐                  │
     │   SETUP     │                  │
     │  (建立态)    │                  │
     └──────┬──────┘                  │
            │                         │
            │ PSELx=1                 │
            │ PENABLE=1               │
            ▼                         │
     ┌─────────────┐                  │
     │   ACCESS    │                  │
     │  (访问态)    │──────────────────┘
     └─────────────┘      事务完成
         │                  (PREADY=1)
         │ PREADY=0
         │ (等待)
         ▼
     保持 ACCESS
     （插入等待周期）
```

**状态定义**：

| 状态 | PSELx | PENABLE | 说明 |
|------|-------|---------|------|
| **IDLE** | 0 | 0 | 默认空闲状态，总线无事务，外设不被选中 |
| **SETUP** | 1 | 0 | 地址和控制信号已建立，外设被选中，准备进入访问 |
| **ACCESS** | 1 | 1 | 使能信号拉高，完成读写操作。若 PREADY=0 则保持等待 |

**状态转移规则**：

| 当前状态 | 转移条件 | 次态 | 说明 |
|----------|----------|------|------|
| IDLE | 新事务发起 | SETUP | PSELx 拉高，地址/控制信号有效 |
| IDLE | 无事务 | IDLE | 保持空闲 |
| SETUP | 下一周期 | ACCESS | PENABLE 拉高，进入访问 |
| ACCESS | PREADY=1 | IDLE 或 SETUP | 事务完成；若有连续事务则回 SETUP，否则回 IDLE |
| ACCESS | PREADY=0 | ACCESS | 等待，插入 wait states |

---

## 3. 信号表

### 3.1 完整信号列表

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `PCLK` | Input | 1 | APB 总线时钟，所有信号在 PCLK 上升沿采样 |
| `PRESETn` | Input | 1 | 低有效异步复位 |
| `PADDR` | Master→Slave | ADDR_WIDTH | 地址总线，最大 32bit |
| `PSELx` | Master→Slave | 1 (每外设) | 外设选择信号，每个从设备独立一根 |
| `PENABLE` | Master→Slave | 1 | 使能信号，标识 ACCESS 阶段 |
| `PWRITE` | Master→Slave | 1 | 读写方向：1=写，0=读 |
| `PWDATA` | Master→Slave | DATA_WIDTH | 写数据总线（APB4 最大 32bit） |
| `PRDATA` | Slave→Master | DATA_WIDTH | 读数据总线 |
| `PREADY` | Slave→Master | 1 | 从设备就绪信号（APB4 新增）：1=完成，0=等待 |
| `PSLVERR` | Slave→Master | 1 | 从设备错误响应（APB4 新增）：1=错误 |
| `PSTRB` | Master→Slave | DATA_WIDTH/8 | 写字节选通（APB4 新增）：每 bit 对应一字节使能 |

### 3.2 信号时序属性

| 信号 | 采样时刻 | 驱动时刻 | 保持要求 |
|------|----------|----------|----------|
| PADDR | PCLK 上升沿（ACCESS） | SETUP 周期内稳定 | ACCESS 周期内保持不变 |
| PSELx | PCLK 上升沿 | 事务开始时拉高 | 事务期间保持高 |
| PENABLE | PCLK 上升沿 | ACCESS 周期拉高 | ACCESS 周期内保持高 |
| PWRITE | PCLK 上升沿（ACCESS） | SETUP 周期内稳定 | ACCESS 周期内保持不变 |
| PWDATA | PCLK 上升沿（ACCESS） | SETUP 周期内稳定 | ACCESS 周期内保持不变 |
| PRDATA | PCLK 上升沿（Master 采样） | ACCESS 周期（Slave 输出） | PREADY=1 时有效 |
| PREADY | PCLK 上升沿 | ACCESS 周期 | - |
| PSLVERR | PCLK 上升沿（与 PREADY 同时） | PREADY=1 时有效 | - |
| PSTRB | PCLK 上升沿（ACCESS） | SETUP 周期内稳定 | ACCESS 周期内保持不变 |

---

## 4. 写事务时序

### 4.1 基本写事务（零等待）

```
PCLK    ─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─
          └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘

PADDR   ─────────┤<  addr_w  >│<  addr_n  >├───────
PSELx   ─────────┐            ┌────────────┐
          ───────┘            └────────────┘
PENABLE ──────────────────────┐            ┌────────
          ────────────────────┘            └────────
PWRITE  ─────────┐            ┌────────────┐
          ───────┘            └────────────┘
PWDATA  ─────────┤< data_w    >│< data_n    >├───────
PREADY  ──────────────────────┐
          ────────────────────┘
                 │            │
          ──────SETUP────ACCESS─SETUP──ACCESS───────
```

**时序说明**：

| 周期 | 状态 | 动作 |
|------|------|------|
| T1 | IDLE | 无事务 |
| T2 | SETUP | PSELx=1, PADDR/PWRITE/PWDATA 建立，准备写入 |
| T3 | ACCESS | PENABLE=1, PREADY=1（默认），从设备在 PCLK 上升沿采样写入数据，事务完成 |
| T4 | IDLE 或 SETUP | 回到 IDLE 或发起下一个事务 |

### 4.2 写事务（带等待周期）

```
PCLK    ─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─
          └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘

PADDR   ─────────┤<        addr_w          >├───────
PSELx   ─────────┐                          ┌───────
          ───────┘                          └───────
PENABLE ──────────────────────┐
          ────────────────────┘
PWRITE  ─────────┐                          ┌───────
          ───────┘                          └───────
PWDATA  ─────────┤<       data_w            >├───────
PREADY  ──────────────────────┐  ┌──────────┐
          ────────────────────┘──┘          └───────
                 │            │  │          │
          ──────SETUP────ACCESS─WAIT──ACCESS─────────
                        (PREADY=0)  (PREADY=1)
```

当从设备需要额外时间处理时，拉低 PREADY 插入等待周期。Master 和 Slave 的控制信号在等待期间保持不变。

---

## 5. 读事务时序

### 5.1 基本读事务（零等待）

```
PCLK    ─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─
          └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘

PADDR   ─────────┤<  addr_r  >│<  addr_n  >├───────
PSELx   ─────────┐            ┌────────────┐
          ───────┘            └────────────┘
PENABLE ──────────────────────┐            ┌────────
          ────────────────────┘            └────────
PWRITE  ─────────┘            └────────────┘
                    (PWRITE=0 读)
PWDATA  ─────────────────────────────────────────────
          (写数据线不使用)
PRDATA  ──────────────────────┤< data_r    >├───────
                                        (Slave 输出)
PREADY  ──────────────────────┐
          ────────────────────┘
                 │            │
          ──────SETUP────ACCESS─────────────────────
```

**读时序说明**：

| 周期 | 状态 | 动作 |
|------|------|------|
| T1 | IDLE | 无事务 |
| T2 | SETUP | PSELx=1, PADDR 建立，PWRITE=0 标识读操作 |
| T3 | ACCESS | PENABLE=1, 从设备在 ACCESS 周期输出 PRDATA，PREADY=1 时 Master 采样 PRDATA |

### 5.2 读事务（带等待周期）

```
PCLK    ─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─
          └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘

PADDR   ─────────┤<        addr_r          >├───────
PSELx   ─────────┐                          ┌───────
          ───────┘                          └───────
PENABLE ──────────────────────┐
          ────────────────────┘
PWRITE  ─────────┘                          └───────
PRDATA  ─────────────────────────────────┤< data_r >├
PREADY  ──────────────────────┐  ┌──────────┐
          ────────────────────┘──┘          └───────
                 │            │  │          │
          ──────SETUP────ACCESS─WAIT──ACCESS─────────
                        (PREADY=0)  (PREADY=1)
```

PRDATA 在 PREADY=1 的 ACCESS 周期才有效。Master 仅在 PREADY=1 时采样 PRDATA。

---

## 6. PREADY 等待机制

### 6.1 PREADY 行为规则

PREADY 是 APB4 新增的关键信号，允许从设备扩展 ACCESS 周期：

| PREADY 值 | 行为 | 说明 |
|-----------|------|------|
| 1 | 事务在当前周期完成 | 默认行为（从设备组合逻辑驱动为 1） |
| 0 | 插入 wait state | ACCESS 状态保持，所有信号不变 |

**关键规则**：
- PREADY 仅在 ACCESS 状态采样，在 SETUP/IDLE 状态忽略
- 等待期间 PADDR、PWRITE、PWDATA、PSELx、PENABLE 全部保持不变
- 从设备实现 PREADY 时，**必须提供默认高值**（即无等待时 PREADY=1），避免总线死锁
- 等待周期数无上限，由从设备决定

### 6.2 典型等待场景

```
场景                    PREADY 行为
─────────────────────────────────────────────────
寄存器直接访问           PREADY 硬件接高（1'b1），零等待
SRAM 访问               PREADY = !sram_busy，1~2 周期等待
跨时钟域外设             PREADY = sync_done，多周期等待
DMA 通道状态查询         PREADY = 1'b1（固定）
```

### 6.3 PREADY 默认接高

对于简单外设（大多数情况），PREADY 直接接常高：

```verilog
// 简单外设：PREADY 恒为 1，零等待
assign pready = 1'b1;
```

---

## 7. PSLVERR 错误响应

### 7.1 PSLVERR 行为规则

PSLVERR 是 APB4 新增的错误指示信号：

| PSLVERR 值 | 含义 |
|-----------|------|
| 0 | 事务正常完成（默认） |
| 1 | 事务错误，数据无效 |

**关键规则**：
- PSLVERR 仅在 ACCESS 状态且 PREADY=1 时采样
- PSLVERR 为 1 时，读数据 PRDATA 无意义（Master 应丢弃）
- 写事务也可以返回 PSLVERR（表示写入失败）
- PSLVERR 不影响 APB 状态机，事务正常结束
- 从设备应默认输出 PSLVERR=0

### 7.2 典型错误场景

| 错误场景 | 触发条件 |
|----------|----------|
| 地址越界 | 访问不存在的寄存器偏移 |
| 写保护 | 写入只读寄存器 |
| 外设故障 | 外设处于复位或异常状态 |
| 访问冲突 | 正在进行中的操作被中断 |

### 7.3 与 AXI SLVERR 的关系

APB 的 PSLVERR 通过 Bridge 映射为 AXI 的 SLVERR 响应，保持端到端错误传递。

---

## 8. PSTRB 字节选通

### 8.1 PSTRB 行为规则

PSTRB 是 APB4 新增的写字节使能信号，每 bit 对应 PWDATA 中一个字节：

| PSTRB[bit] | 对应 PWDATA 字节 | 行为 |
|------------|-----------------|------|
| PSTRB[0] | PWDATA[7:0] | 1=写入 byte 0 |
| PSTRB[1] | PWDATA[15:8] | 1=写入 byte 1 |
| PSTRB[2] | PWDATA[23:16] | 1=写入 byte 2 |
| PSTRB[3] | PWDATA[31:24] | 1=写入 byte 3 |

### 8.2 PSTRB 使用规则

- **仅写事务有效**：读事务时 PSTRB 无意义（可为任意值）
- **至少一位为高**：写事务时 PSTRB 不能全 0（否则无字节被写入）
- **典型用法**：处理器对非对齐地址的字节/半字写操作
- **从设备实现**：需根据 PSTRB 生成字节级写使能

```verilog
// 从设备字节写入逻辑
always @(posedge PCLK) begin
    if (PSELx && PENABLE && PWRITE && PREADY) begin
        if (PSTRB[0]) reg_q[7:0]   <= PWDATA[7:0];
        if (PSTRB[1]) reg_q[15:8]  <= PWDATA[15:8];
        if (PSTRB[2]) reg_q[23:16] <= PWDATA[23:16];
        if (PSTRB[3]) reg_q[31:24] <= PWDATA[31:24];
    end
end
```

### 8.3 PSTRB 编码示例（32bit 数据总线）

| 操作 | PSTRB | 说明 |
|------|-------|------|
| 32bit 写 | 4'b1111 | 全字写入 |
| 16bit 写低半字 | 4'b0011 | 半字写入 |
| 16bit 写高半字 | 4'b1100 | 半字写入 |
| 8bit 写 byte 0 | 4'b0001 | 字节写入 |
| 8bit 写 byte 2 | 4'b0100 | 字节写入 |

---

## 9. APB 与 AXI4-Lite 对比

| 特性 | APB (APB4) | AXI4-Lite |
|------|-----------|-----------|
| **通道数** | 单通道（地址/数据复用） | 5 通道（AW/W/B/AR/R 独立） |
| **握手机制** | 无标准握手（PREADY 简化版） | Valid/Ready 双向握手 |
| **流水线** | 无，串行执行 | 读写通道独立并行 |
| **Outstanding** | 不支持 | 支持（可发多笔未完成事务） |
| **Burst** | 不支持 | 不支持（AXI4-Lite） |
| **字节选通** | PSTRB（APB4） | WSTRB |
| **错误响应** | PSLVERR | SLVERR (BRESP/RRESP) |
| **等待扩展** | PREADY | Ready 握手 |
| **总线宽度** | 最大 32bit | 可扩展到 64/128bit |
| **地址宽度** | 最大 32bit | 最大 64bit |
| **面积** | 极小（~500 gates） | 较大（~5k gates） |
| **功耗** | 极低 | 中等 |
| **时钟门控友好度** | 极好（信号翻转少） | 一般 |
| **典型延迟** | 2 cycles（零等待） | 3~5 cycles（单事务） |
| **适用场景** | 外设寄存器访问 | 外设寄存器访问（性能要求稍高） |

**选择建议**：

| 场景 | 推荐总线 | 原因 |
|------|----------|------|
| UART/SPI/I2C 寄存器 | APB | 面积小、功耗低、协议简单 |
| Timer/GPIO/Watchdog | APB | 低速控制寄存器，APB 足够 |
| DMA 控制寄存器 | AXI4-Lite | 需要更快的寄存器访问 |
| 高性能外设数据通路 | AXI4（Full） | 需要 Burst 和 Outstanding |
| 安全相关寄存器 | APB + PSLVERR | 错误响应机制简单可靠 |

---

## 10. 多外设互联

### 10.1 AXI/AHB-to-APB Bridge 架构

```
     ┌─────────────────────────────────────────────────────┐
     │                AXI/AHB-to-APB Bridge                │
     │                                                     │
     │  ┌───────────┐    ┌───────────┐    ┌─────────────┐ │
     │  │ AXI/AHB   │    │  地址     │    │ APB Master  │ │
     │  │ Slave     │───▶│  译码器   │───▶│ 控制逻辑    │ │
     │  │ Interface │    │           │    │             │ │
     │  └───────────┘    └─────┬─────┘    └──────┬──────┘ │
     │                         │                  │        │
     └─────────────────────────┼──────────────────┼────────┘
                               │                  │
            ┌──────────────────┼──────────────────┤
            │                  │                  │
     ┌──────▼──────┐    ┌──────▼──────┐    ┌─────▼───────┐
     │    PSEL0    │    │    PSEL1    │    │    PSEL2    │
     │             │    │             │    │             │
     │  UART       │    │  SPI        │    │  GPIO       │
     │  0x4000_0000│    │  0x4001_0000│    │  0x4002_0000│
     └─────────────┘    └─────────────┘    └─────────────┘

         PADDR, PWRITE, PWDATA, PENABLE, PREADY, PRDATA
         ──────────── 共享总线 ────────────────────────────
```

### 10.2 地址译码

地址译码在 Bridge 中完成，根据高位地址生成 PSELx：

```
PSEL0 = (PADDR[31:16] == 16'h4000)    // UART  @ 0x4000_0000
PSEL1 = (PADDR[31:16] == 16'h4001)    // SPI   @ 0x4001_0000
PSEL2 = (PADDR[31:16] == 16'h4002)    // GPIO  @ 0x4002_0000
```

### 10.3 PREADY 汇聚

当多个外设共享总线时，Bridge 需要汇聚所有外设的 PREADY：

```
PREADY_bus = PSEL0 ? PREADY_0 :
             PSEL1 ? PREADY_1 :
             PSEL2 ? PREADY_2 :
             1'b1;              // 无外设被选中时默认就绪
```

同理，PRDATA 和 PSLVERR 也需要 MUX 汇聚。

---

## 11. 设计注意事项

### 11.1 低功耗设计

APB 天然适合低功耗设计：

| 策略 | 实现方法 |
|------|----------|
| **总线无事务时门控 PCLK** | PSELx 全为 0 时可门控 APB 时钟域 |
| **信号保持** | SETUP→ACCESS 期间信号不变，减少动态功耗 |
| **寄存器写入门控** | 用 `PSELx && PENABLE && PWRITE && PREADY` 做写使能，避免无意义翻转 |
| **PRDATA 低功耗** | 未被选中时 PRDATA 输出 0 或保持，减少翻转 |

### 11.2 无 Outstanding 事务

APB 不支持 Outstanding，这意味着：
- 每笔事务必须在下一笔发起前完成
- Bridge 需要等待当前 APB 事务完成才能发起下一个
- **影响**：高频访问 APB 外设时，Bridge 成为瓶颈
- **缓解**：将高频访问外设挂在 AXI/AHB 上，低速外设才走 APB

### 11.3 地址对齐

| 规则 | 说明 |
|------|------|
| PADDR 必须字对齐 | 32bit 总线时 PADDR[1:0] 应为 2'b00 |
| 非对齐访问 | 通过 PSTRB 实现字节/半字写入 |
| 读操作无 PSTRB | 从设备始终返回完整 32bit，由 Master 裁剪 |

### 11.4 复位行为

| 信号 | 复位值 | 说明 |
|------|--------|------|
| PSELx | 0 | 复位期间不选中任何外设 |
| PENABLE | 0 | 复位期间不使能 |
| PADDR | 不关心 | 复位期间无意义 |
| PWRITE | 不关心 | 复位期间无意义 |
| PWDATA | 不关心 | 复位期间无意义 |
| PSTRB | 不关心 | 复位期间无意义 |

### 11.5 从设备设计要点

- PREADY 必须有默认高值（`assign pready = 1'b1` 或寄存器默认值为 1）
- PSLVERR 必须默认输出 0
- 寄存器写入使能必须包含 PSELx && PENABLE && PREADY 条件
- 读数据 PRDATA 在 ACCESS 周期输出，PREADY=1 时有效

### 11.6 CDC 注意事项

APB 本身是单时钟域协议，跨时钟域外设的处理：
- Bridge 负责将系统总线时钟域转换到 APB 时钟域
- 如果外设内部需要慢时钟，通过 PREADY 等待来同步
- 不要直接在 APB 总线上做 CDC，应在 Bridge 级别处理

---

## 12. 典型实例化

### 12.1 APB Slave 寄存器模块

```verilog
// ============================================================================
// Module   : apb_slave_reg
// Function : APB4 Slave with 4 x 32-bit RW registers
// Author   : arch
// Date     : 2026-04-15
// Revision : v1.0
// ============================================================================

module apb_slave_reg #(
    parameter  ADDR_WIDTH = 12,
    parameter  DATA_WIDTH = 32,
    localparam STRB_WIDTH = DATA_WIDTH / 8
)(
    // Clock & Reset
    input  wire                  PCLK,
    input  wire                  PRESETn,

    // APB Interface
    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire                  PSELx,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [DATA_WIDTH-1:0] PWDATA,
    input  wire [STRB_WIDTH-1:0] PSTRB,
    output wire [DATA_WIDTH-1:0] PRDATA,
    output wire                  PREADY,
    output wire                  PSLVERR,

    // Register outputs
    output wire [DATA_WIDTH-1:0] reg0_out,
    output wire [DATA_WIDTH-1:0] reg1_out,
    output wire [DATA_WIDTH-1:0] reg2_out,
    output wire [DATA_WIDTH-1:0] reg3_out
);

    // --- Address decode ---
    wire sel_reg0 = (PADDR[3:2] == 2'd0);
    wire sel_reg1 = (PADDR[3:2] == 2'd1);
    wire sel_reg2 = (PADDR[3:2] == 2'd2);
    wire sel_reg3 = (PADDR[3:2] == 2'd3);
    wire sel_valid = sel_reg0 | sel_reg1 | sel_reg2 | sel_reg3;

    // --- APB control ---
    wire wr_en = PSELx & PENABLE & PWRITE & PREADY;
    wire rd_en = PSELx & PENABLE & (~PWRITE) & PREADY;

    // PREADY: always ready (zero wait states)
    assign PREADY = 1'b1;

    // PSLVERR: error when address out of range
    assign PSLVERR = PSELx & PENABLE & (~sel_valid);

    // --- Registers ---
    reg [DATA_WIDTH-1:0] reg0, reg1, reg2, reg3;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg0 <= {DATA_WIDTH{1'b0}};
            reg1 <= {DATA_WIDTH{1'b0}};
            reg2 <= {DATA_WIDTH{1'b0}};
            reg3 <= {DATA_WIDTH{1'b0}};
        end else if (wr_en) begin
            if (sel_reg0) begin
                if (PSTRB[0]) reg0[7:0]   <= PWDATA[7:0];
                if (PSTRB[1]) reg0[15:8]  <= PWDATA[15:8];
                if (PSTRB[2]) reg0[23:16] <= PWDATA[23:16];
                if (PSTRB[3]) reg0[31:24] <= PWDATA[31:24];
            end
            if (sel_reg1) begin
                if (PSTRB[0]) reg1[7:0]   <= PWDATA[7:0];
                if (PSTRB[1]) reg1[15:8]  <= PWDATA[15:8];
                if (PSTRB[2]) reg1[23:16] <= PWDATA[23:16];
                if (PSTRB[3]) reg1[31:24] <= PWDATA[31:24];
            end
            if (sel_reg2) begin
                if (PSTRB[0]) reg2[7:0]   <= PWDATA[7:0];
                if (PSTRB[1]) reg2[15:8]  <= PWDATA[15:8];
                if (PSTRB[2]) reg2[23:16] <= PWDATA[23:16];
                if (PSTRB[3]) reg2[31:24] <= PWDATA[31:24];
            end
            if (sel_reg3) begin
                if (PSTRB[0]) reg3[7:0]   <= PWDATA[7:0];
                if (PSTRB[1]) reg3[15:8]  <= PWDATA[15:8];
                if (PSTRB[2]) reg3[23:16] <= PWDATA[23:16];
                if (PSTRB[3]) reg3[31:24] <= PWDATA[31:24];
            end
        end
    end

    // --- Read mux ---
    reg [DATA_WIDTH-1:0] prdata_r;

    always @(*) begin
        prdata_r = {DATA_WIDTH{1'b0}};    // 默认值
        case (PADDR[3:2])
            2'd0: prdata_r = reg0;
            2'd1: prdata_r = reg1;
            2'd2: prdata_r = reg2;
            2'd3: prdata_r = reg3;
            default: prdata_r = {DATA_WIDTH{1'b0}};
        endcase
    end

    assign PRDATA = prdata_r;

    // --- Output assignments ---
    assign reg0_out = reg0;
    assign reg1_out = reg1;
    assign reg2_out = reg2;
    assign reg3_out = reg3;

    // === SVA Assertions ===
    `ifdef ASSERT_ON

    // PREADY must not be X or Z
    assert_pready_known: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        PSELx |-> !$isunknown(PREADY)
    );

    // PSLVERR must not be X or Z when active
    assert_pslverr_known: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (PSELx && PENABLE) |-> !$isunknown(PSLVERR)
    );

    // PSTRB must not be all-zero during write
    assert_pstrb_not_zero: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        (PSELx && PENABLE && PWRITE && PREADY) |-> (PSTRB != {STRB_WIDTH{1'b0}})
    );

    // PENABLE must be high in ACCESS (PSELx=1 for 2nd cycle)
    assert_penable_after_setup: assert property (
        @(posedge PCLK) disable iff (!PRESETn)
        $rose(PSELx) |=> PENABLE
    );

    `endif

endmodule
```

### 12.2 APB 信号连接示例

```verilog
// APB Master (Bridge) 连接到 Slave
apb_slave_reg #(
    .ADDR_WIDTH (12),
    .DATA_WIDTH (32)
) u_uart_reg (
    .PCLK       (pclk),
    .PRESETn    (presetn),
    .PADDR      (paddr),
    .PSELx      (psel_uart),       // Bridge 地址译码输出
    .PENABLE    (penable),
    .PWRITE     (pwrite),
    .PWDATA     (pwdata),
    .PSTRB      (pstrb),
    .PRDATA     (prdata_uart),     // MUX 汇聚到 Bridge
    .PREADY     (pready_uart),     // MUX 汇聚到 Bridge
    .PSLVERR    (pslverr_uart),    // MUX 汇聚到 Bridge
    .reg0_out   (uart_ctrl),
    .reg1_out   (uart_baud),
    .reg2_out   (uart_status),
    .reg3_out   (uart_irq_en)
);
```

---

## 附录 A. APB 协议版本演进

| 版本 | AMBA 规范 | 新增特性 |
|------|-----------|----------|
| APB1 | AMBA 2 (1999) | 基本读写协议，无 PREADY/PSLVERR/PSTRB |
| APB2 | AMBA 3 (2003) | 无重大变化 |
| APB3 | AMBA 3 (2004) | 新增 PREADY（等待扩展）、PSLVERR（错误响应） |
| APB4 | AMBA 4 (2010) | 新增 PSTRB（字节选通）、PPROT（保护，未列出） |

当前设计应全部遵循 **APB4** 规范。

## 附录 B. 缩略语

| 缩写 | 全称 |
|------|------|
| APB | Advanced Peripheral Bus |
| AMBA | Advanced Microcontroller Bus Architecture |
| AXI | Advanced eXtensible Interface |
| AHB | Advanced High-performance Bus |
| PPROT | Protection signaling (not listed in signal table, APB4 optional) |
