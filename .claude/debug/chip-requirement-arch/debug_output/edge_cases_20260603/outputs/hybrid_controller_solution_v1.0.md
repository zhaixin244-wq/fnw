# 混合控制器 架构方案文档

> 版本：v1.0
> 日期：2026-06-03
> 对应需求：hybrid_controller_requirement_summary_v1.0.md

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| 模块名称 | hybrid_controller（混合控制器） |
| 版本 | v1.0 |
| 文档编号 | FNW-SOL-hybrid_controller-v1.0 |
| 作者 | 苏启辰/Sean |
| 日期 | 2026-06-03 |
| 对应 REQ | REQ-001 ~ REQ-031 |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-06-03 | Sean | 初始版本 |

---

## 3. 架构概述

### 3.1 模块定位

hybrid_controller 是 SoC 中的多协议总线桥接器，负责将 APB（配置）、AXI（高速数据）、SPI（外部低速）三路上游访问，通过协议转换和地址空间映射，路由到 AXI4（DDR）或自定义流式 DMA（加速器）下游目标。

**关键约束**：
- SRAM 总量 ≤ 2KB（用户硬约束，REQ-005）
- 单时钟域 200MHz（REQ-006）
- 功能正确性 > 时序收敛 > 面积 > 功耗（REQ-005）

### 3.2 架构拓扑

采用**独立协议转换通路 + 地址解码路由**架构：

```
                    ┌─────────────────────────────────┐
                    │        hybrid_controller         │
                    │                                   │
  APB32 ──────────►│  ┌───────────┐                    │
                    │  │ apb_slave │──┐                 │
  AXI4(64bit) ────►│  └───────────┘  │  ┌───────────┐ │    AXI4(64bit)
                    │                 ├──►│addr_decode│ ├──► (DDR)
  SPI ────────────►│  ┌───────────┐  │  └───────────┘ │
                    │  │ spi_slave │──┤       │        │
                    │  └───────────┘  │  ┌────▼──────┐ │    自定义 DMA
                    │                 │  │ dma_master│ ├──► (加速器)
                    │  ┌───────────┐  │  └───────────┘ │
                    │  │ axi_slave │──┘                 │
                    │  └───────────┘                    │
                    │                                   │
                    │  ┌───────────┐  ┌──────────────┐ │
                    │  │ reg_file  │  │ int_ctrl     │ │
                    │  └───────────┘  └──────────────┘ │
                    └─────────────────────────────────┘
```

### 3.3 RTL 行数估算

| 子模块 | 功能 | 预估行数 |
|--------|------|----------|
| axi_slave_if | AXI4 从接口，burst 解析 | 350 |
| apb_slave_if | APB32 从接口，寄存器读写 | 200 |
| spi_slave_if | SPI 从接口，单拍接收 | 180 |
| addr_decode | 地址解码 + 路由 | 250 |
| axi_write_buf | AXI 写突发缓冲（512B SRAM） | 200 |
| spi_buf | SPI 接收缓冲（128B SRAM） | 150 |
| shared_read_buf | 共享读缓冲（1024B SRAM） | 250 |
| dma_master_if | 自定义 DMA 主接口 | 200 |
| axi_master_if | AXI4 主接口（写 DDR） | 250 |
| reg_file | 配置/状态寄存器 | 300 |
| int_ctrl | 中断控制 | 100 |
| burst_merge | AXI 写突发合并（REQ-029） | 150 |
| **合计** | | **~2580** |

**[STAGE-CONTINUE] RTL 行数 2580 ≤ 3000，继续标准 stageD 流程**

### 3.4 子模块划分

| 子模块 | 职责 | 预估行数 | 关键接口 |
|--------|------|----------|----------|
| axi_slave_if | AXI4 从接口，解析写 burst，驱动写 buffer | 350 | AXI4 slave → addr_decode |
| apb_slave_if | APB32 从接口，寄存器读写 | 200 | APB slave → reg_file |
| spi_slave_if | SPI 从接口，接收外部低速数据 | 180 | SPI slave → spi_buf |
| addr_decode | 地址解码，路由到 AXI4 master 或 DMA master | 250 | 输入：三路请求；输出：两路目标 |
| axi_write_buf | AXI 写数据缓冲（512B SRAM） | 200 | AXI slave → AXI master |
| spi_buf | SPI 数据缓冲（128B SRAM） | 150 | SPI slave → DMA master |
| shared_read_buf | 三路共享读缓冲（1024B SRAM） | 250 | AXI4/DMA 读返回 → 各 slave |
| dma_master_if | 自定义流式 DMA 主接口 | 200 | addr_decode → DMA slave |
| axi_master_if | AXI4 主接口，写 DDR | 250 | addr_decode → AXI4 slave |
| reg_file | APB 可访问的配置/状态寄存器 | 300 | APB ↔ 寄存器阵列 |
| int_ctrl | 中断控制，W1C 清除 | 100 | 各模块 → 中断输出 |
| burst_merge | AXI 写突发合并（REQ-029） | 150 | AXI slave → AXI master |

---

## 4. 接口定义

### 4.1 接口列表

| 接口名称 | 协议类型 | 方向 | 位宽 | 时钟域 | 说明 |
|----------|----------|------|------|--------|------|
| apb_if | APB32 | Slave | 32bit | clk | 配置接口 |
| axi_s_if | AXI4 | Slave | 64bit | clk | 高速数据上游 |
| spi_if | SPI | Slave | 1bit | clk | 外部低速 |
| axi_m_if | AXI4 | Master | 64bit | clk | DDR 下游 |
| dma_if | 自定义流式 | Master | 64bit | clk | 加速器下游 |
| int_out | 电平 | Output | 1bit | clk | 中断输出 |

### 4.2 信号详细列表

| 信号名 | 方向 | 位宽 | 时钟域 | 复位值 | 功能描述 |
|--------|------|------|--------|--------|----------|
| clk | I | 1 | - | - | 主时钟 200MHz |
| rst_n | I | 1 | - | - | 低有效异步复位 |
| apb_psel | I | 1 | clk | 0 | APB 选择 |
| apb_penable | I | 1 | clk | 0 | APB 使能 |
| apb_pwrite | I | 1 | clk | 0 | APB 写使能 |
| apb_paddr | I | 12 | clk | 0 | APB 地址 |
| apb_pwdata | I | 32 | clk | 0 | APB 写数据 |
| apb_prdata | O | 32 | clk | 0 | APB 读数据 |
| apb_pready | O | 1 | clk | 1 | APB 就绪 |
| apb_pslverr | O | 1 | clk | 0 | APB 从错误 |
| axi_s_awid | I | 4 | clk | 0 | AXI slave 写地址 ID |
| axi_s_awaddr | I | 32 | clk | 0 | AXI slave 写地址 |
| axi_s_awlen | I | 8 | clk | 0 | AXI slave 写突发长度 |
| axi_s_awsize | I | 3 | clk | 0 | AXI slave 写突发大小 |
| axi_s_awvalid | I | 1 | clk | 0 | AXI slave 写地址有效 |
| axi_s_awready | O | 1 | clk | 0 | AXI slave 写地址就绪 |
| axi_s_wdata | I | 64 | clk | 0 | AXI slave 写数据 |
| axi_s_wstrb | I | 8 | clk | 0 | AXI slave 写选通 |
| axi_s_wlast | I | 1 | clk | 0 | AXI slave 写最后 |
| axi_s_wvalid | I | 1 | clk | 0 | AXI slave 写数据有效 |
| axi_s_wready | O | 1 | clk | 0 | AXI slave 写数据就绪 |
| axi_s_bid | O | 4 | clk | 0 | AXI slave 写响应 ID |
| axi_s_bresp | O | 2 | clk | 0 | AXI slave 写响应 |
| axi_s_bvalid | O | 1 | clk | 0 | AXI slave 写响应有效 |
| axi_s_bready | I | 1 | clk | 0 | AXI slave 写响应就绪 |
| axi_s_arid | I | 4 | clk | 0 | AXI slave 读地址 ID |
| axi_s_araddr | I | 32 | clk | 0 | AXI slave 读地址 |
| axi_s_arlen | I | 8 | clk | 0 | AXI slave 读突发长度 |
| axi_s_arsize | I | 3 | clk | 0 | AXI slave 读突发大小 |
| axi_s_arvalid | I | 1 | clk | 0 | AXI slave 读地址有效 |
| axi_s_arready | O | 1 | clk | 0 | AXI slave 读地址就绪 |
| axi_s_rid | O | 4 | clk | 0 | AXI slave 读数据 ID |
| axi_s_rdata | O | 64 | clk | 0 | AXI slave 读数据 |
| axi_s_rresp | O | 2 | clk | 0 | AXI slave 读响应 |
| axi_s_rlast | O | 1 | clk | 0 | AXI slave 读最后 |
| axi_s_rvalid | O | 1 | clk | 0 | AXI slave 读数据有效 |
| axi_s_rready | I | 1 | clk | 0 | AXI slave 读数据就绪 |
| spi_sclk | I | 1 | clk | 0 | SPI 时钟（同步采样） |
| spi_mosi | I | 1 | clk | 0 | SPI 主出从入 |
| spi_csn | I | 1 | clk | 1 | SPI 片选（低有效） |
| axi_m_awid | O | 4 | clk | 0 | AXI master 写地址 ID |
| axi_m_awaddr | O | 32 | clk | 0 | AXI master 写地址 |
| axi_m_awlen | O | 8 | clk | 0 | AXI master 写突发长度 |
| axi_m_awsize | O | 3 | clk | 0 | AXI master 写突发大小 |
| axi_m_awvalid | O | 1 | clk | 0 | AXI master 写地址有效 |
| axi_m_awready | I | 1 | clk | 0 | AXI master 写地址就绪 |
| axi_m_wdata | O | 64 | clk | 0 | AXI master 写数据 |
| axi_m_wstrb | O | 8 | clk | 0 | AXI master 写选通 |
| axi_m_wlast | O | 1 | clk | 0 | AXI master 写最后 |
| axi_m_wvalid | O | 1 | clk | 0 | AXI master 写数据有效 |
| axi_m_wready | I | 1 | clk | 0 | AXI master 写数据就绪 |
| axi_m_bid | I | 4 | clk | 0 | AXI master 写响应 ID |
| axi_m_bresp | I | 2 | clk | 0 | AXI master 写响应 |
| axi_m_bvalid | I | 1 | clk | 0 | AXI master 写响应有效 |
| axi_m_bready | O | 1 | clk | 0 | AXI master 写响应就绪 |
| dma_valid | O | 1 | clk | 0 | DMA 数据有效 |
| dma_ready | I | 1 | clk | 0 | DMA 就绪 |
| dma_data | O | 64 | clk | 0 | DMA 数据 |
| dma_last | O | 1 | clk | 0 | DMA 包尾 |
| dma_addr | O | 32 | clk | 0 | DMA 地址 |
| dma_len | O | 8 | clk | 0 | DMA 长度 |
| int_out | O | 1 | clk | 0 | 中断输出 |

---

## 5. 数据通路与控制逻辑

### 5.1 数据通路

#### 写路径（上游 → 下游）

| 路径 | 源 | 目标 | 经过模块 | 延迟 | 说明 |
|------|-----|------|----------|------|------|
| WR-01 | AXI slave | AXI4 master (DDR) | axi_slave_if → axi_write_buf → burst_merge → axi_master_if | 3 cycles | AXI 写突发 |
| WR-02 | APB slave | AXI4 master (DDR) | apb_slave_if → axi_master_if | 2 cycles | APB 单拍写 |
| WR-03 | SPI slave | DMA master (加速器) | spi_slave_if → spi_buf → dma_master_if | 4 cycles | SPI 数据转发 |

#### 读路径（下游 → 上游）

| 路径 | 源 | 目标 | 经过模块 | 延迟 | 说明 |
|------|-----|------|----------|------|------|
| RD-01 | AXI4 master | AXI slave | axi_master_if → shared_read_buf → axi_slave_if | 3 cycles | AXI 读返回 |
| RD-02 | AXI4 master | APB slave | axi_master_if → shared_read_buf → apb_slave_if | 3 cycles | APB 读 DDR |
| RD-03 | DMA master | SPI slave | dma_master_if → shared_read_buf → spi_slave_if | 3 cycles | DMA 读返回 |

#### 地址解码规则

| 地址范围 | 路由目标 | 说明 |
|----------|----------|------|
| 0x0000_0000 ~ 0x3FFF_FFFF | AXI4 master (DDR) | DDR 地址空间 |
| 0x4000_0000 ~ 0x7FFF_FFFF | DMA master (加速器) | 加速器地址空间 |
| 其他 | 错误响应 | 地址解码错误 |

### 5.2 控制逻辑

#### 控制信号列表

| 控制信号 | 位宽 | 产生源 | 功能描述 |
|----------|------|--------|----------|
| addr_decode_err | 1 | addr_decode | 地址解码错误标志 |
| wr_buf_full | 1 | axi_write_buf | 写缓冲满标志 |
| rd_buf_empty | 1 | shared_read_buf | 读缓冲空标志 |
| spi_buf_avail | 1 | spi_buf | SPI 缓冲有数据 |
| dma_busy | 1 | dma_master_if | DMA 忙标志 |
| axi_busy | 1 | axi_master_if | AXI master 忙标志 |
| err_inject_en | 1 | reg_file | 错误注入使能（REQ-030） |

#### 流控机制

| 流控类型 | 接口方向 | 机制 | 背压路径 |
|----------|----------|------|----------|
| 背压 | AXI slave 写 | ready = !wr_buf_full | wr_buf_full → awready/wready 拉低 |
| 背压 | AXI slave 读 | ready = !rd_buf_empty | rd_buf_empty → rvalid 拉低 |
| 握手 | DMA 输出 | valid/ready | dma_busy → dma_valid 保持 |
| 信用 | SPI 输入 | spi_csn 低有效期间持续采样 | 无背压（SPI 为被动接收） |

### 5.3 状态机设计

#### addr_decode 状态机

| 状态 | 编码 | 描述 | 转移条件 |
|------|------|------|----------|
| S_IDLE | 001 | 空闲，等待请求 | 有请求 → S_DECODE |
| S_DECODE | 010 | 地址解码 | 解码完成 → S_ROUTE |
| S_ROUTE | 100 | 路由到目标 | 目标就绪 → S_IDLE |

编码方式：独热码（3 状态 ≤ 16）

#### burst_merge 状态机（REQ-029）

| 状态 | 编码 | 描述 | 转移条件 |
|------|------|------|----------|
| S_IDLE | 001 | 空闲 | AXI 写请求 → S_ACCUM |
| S_ACCUM | 010 | 累积写数据 | wlast 或 buffer 满 → S_MERGE |
| S_MERGE | 100 | 合并发出 | 下游 ready → S_IDLE |

编码方式：独热码（3 状态 ≤ 16）

### 5.4 流水线设计

本模块为协议桥接器，数据通路为单拍/突发传输，不采用多级流水线。各协议转换通路为组合逻辑 + 寄存器的两拍结构：
- 第 1 拍：输入锁存 + 地址解码
- 第 2 拍：路由 + 输出

---

## 6. 关键时序分析

### 关键路径

| 路径 ID | 起点 | 终点 | 组合逻辑级数 | 预估延迟 | 关键路径 |
|---------|------|------|-------------|----------|----------|
| CP-001 | axi_s_awaddr/Q | axi_m_awvalid/D | 3 级（解码+路由+输出） | 1.5ns | 是 |
| CP-002 | apb_paddr/Q | axi_m_awvalid/D | 2 级（解码+输出） | 1.0ns | 否 |
| CP-003 | axi_m_rvalid/Q | axi_s_rvalid/D | 2 级（buffer+输出） | 1.0ns | 否 |

### 时序裕量

**裕量公式**：Tslack = Tclk - Tcq - Tlogic - Tsetup - Tskew

| 路径 | Tclk | Tcq | Tlogic | Tsetup | Tslack | 是否满足 |
|------|------|-----|--------|--------|--------|----------|
| CP-001 | 5.0ns | 0.3ns | 1.5ns | 0.2ns | **3.0ns** | 是 |
| CP-002 | 5.0ns | 0.3ns | 1.0ns | 0.2ns | **3.5ns** | 是 |
| CP-003 | 5.0ns | 0.3ns | 1.0ns | 0.2ns | **3.5ns** | 是 |

### SDC 约束建议

```tcl
create_clock -name clk -period 5.0 [get_ports clk]
set_input_delay  -clock clk -max 0.5 [get_ports {axi_s_* apb_* spi_*}]
set_input_delay  -clock clk -min 0.1 [get_ports {axi_s_* apb_* spi_*}]
set_output_delay -clock clk -max 1.0 [get_ports {axi_m_* dma_* int_out}]
set_output_delay -clock clk -min 0.1 [get_ports {axi_m_* dma_* int_out}]
set_false_path   -from [get_ports rst_n]
```

---

## 7. 寄存器定义与 CDC 方案

### 7.1 寄存器定义

#### 地址映射表

| 偏移地址 | 名称 | 访问类型 | 复位值 | 描述 |
|----------|------|----------|--------|------|
| 0x000 | CTRL | RW | 0x0000_0000 | 控制寄存器 |
| 0x004 | STATUS | RO | 0x0000_0000 | 状态寄存器 |
| 0x008 | INT_STATUS | W1C | 0x0000_0000 | 中断状态 |
| 0x00C | INT_MASK | RW | 0x0000_0000 | 中断屏蔽 |
| 0x010 | ADDR_MAP_LO | RW | 0x0000_0000 | 地址映射低位（DDR 基址） |
| 0x014 | ADDR_MAP_HI | RW | 0x4000_0000 | 地址映射高位（DMA 基址） |
| 0x018 | ERR_INJECT | RW | 0x0000_0000 | 错误注入控制（REQ-030） |
| 0x01C | AXI_WR_CNT | RO | 0x0000_0000 | AXI 写事务计数（REQ-031） |
| 0x020 | AXI_RD_CNT | RO | 0x0000_0000 | AXI 读事务计数（REQ-031） |
| 0x024 | SPI_RX_CNT | RO | 0x0000_0000 | SPI 接收计数（REQ-031） |
| 0x028 | DMA_TX_CNT | RO | 0x0000_0000 | DMA 发送计数（REQ-031） |
| 0x02C | ERR_CNT | RO | 0x0000_0000 | 错误计数（REQ-031） |
| 0x030 | WR_BUF_STS | RO | 0x0000_0000 | 写缓冲状态 |
| 0x034 | RD_BUF_STS | RO | 0x0000_0000 | 读缓冲状态 |
| 0x038~0x0FC | RSVD | - | - | 保留 |

#### 寄存器位域定义

**CTRL（偏移 0x000）**：模块控制

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | MODULE_EN | RW | 0 | 模块使能 |
| [1] | AXI_WR_EN | RW | 1 | AXI 写通路使能 |
| [2] | SPI_RX_EN | RW | 1 | SPI 接收使能 |
| [3] | DMA_TX_EN | RW | 1 | DMA 发送使能 |
| [4] | BURST_MERGE_EN | RW | 0 | 突发合并使能（REQ-029） |
| [31:5] | RSVD | - | 0 | 保留 |

**STATUS（偏移 0x004）**：模块状态

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | AXI_WR_BUSY | RO | 0 | AXI 写忙 |
| [1] | SPI_RX_BUSY | RO | 0 | SPI 接收忙 |
| [2] | DMA_TX_BUSY | RO | 0 | DMA 发送忙 |
| [3] | ADDR_DECODE_ERR | RO | 0 | 地址解码错误 |
| [4] | WR_BUF_FULL | RO | 0 | 写缓冲满 |
| [5] | RD_BUF_EMPTY | RO | 1 | 读缓冲空 |
| [31:6] | RSVD | - | 0 | 保留 |

**INT_STATUS（偏移 0x008）**：中断状态（W1C）

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | AXI_WR_DONE_IRQ | W1C | 0 | AXI 写完成中断 |
| [1] | SPI_RX_DONE_IRQ | W1C | 0 | SPI 接收完成中断 |
| [2] | DMA_TX_DONE_IRQ | W1C | 0 | DMA 发送完成中断 |
| [3] | ADDR_ERR_IRQ | W1C | 0 | 地址错误中断 |
| [4] | BUF_OVERFLOW_IRQ | W1C | 0 | 缓冲溢出中断 |
| [31:5] | RSVD | - | 0 | 保留 |

**ERR_INJECT（偏移 0x018）**：错误注入控制（REQ-030）

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | ERR_INJECT_EN | RW | 0 | 错误注入使能 |
| [1] | INJECT_ADDR_ERR | RW | 0 | 注入地址解码错误 |
| [2] | INJECT_BUF_OVERFLOW | RW | 0 | 注入缓冲溢出 |
| [31:3] | RSVD | - | 0 | 保留 |

### 7.2 CDC 方案

本模块为单时钟域（200MHz），无跨时钟域信号，CDC 方案不适用。

---

## 8. PPA 预估

### 8.1 性能指标

| 指标 | 数值 | 单位 | 约束类型 | 条件 |
|------|------|------|----------|------|
| AXI→AXI4 写延迟 | 3 | cycles | Target | 连续 burst |
| APB→AXI4 写延迟 | 2 | cycles | Target | 单拍 |
| SPI→DMA 延迟 | 4 | cycles | Target | 单拍 |
| AXI 写吞吐 | 1 | beat/cycle | Target | 持续 burst |
| 最大频率 | ≥200 | MHz | Target | Fmax |

### 8.2 功耗预估（PVT：TT / 0.9V / 25°C / 200MHz）

| 指标 | 预估 | 单位 | 依据 |
|------|------|------|------|
| 动态功耗 | ~8 | mW | α×C×V²×f（α≈0.15, C≈3pF, V=0.9V, f=200MHz） |
| 静态功耗 | ~1 | mW | 漏电×V（28nm TT 25°C） |
| **合计** | **~9** | **mW** | < 15mW 预算 |

### 8.3 面积预估

| 组成 | 预估(kGates) | 计算依据 |
|------|-------------|----------|
| 数据通路逻辑 | 18 | axi_slave/apb_slave/spi_slave/addr_decode/dma_master/axi_master 各 ~3kGates |
| 控制逻辑 | 5 | burst_merge + int_ctrl + 状态机 |
| 寄存器 | 4 | ~50 regs × 6 GE + 读写逻辑 |
| SRAM | 8 | 1920B SRAM @ 28nm ≈ 8kGates |
| **合计** | **~35** | < 50kGates 预算 |

---

## 9. DFX 设计

遵循项目通用 DFT 规则：
- 所有寄存器可入扫描链
- 标准 ICG 用于 Clock Gating（REQ-007）
- 无异步置位
- 无组合反馈环

---

## 10.1 可靠性设计

- SRAM 使用 Parity 保护（REQ-009）
- 无 ECC/TMR（面积优先）
- 地址解码错误检测 + 中断上报

---

## 10.2 低功耗设计

使用全局 Clock Gating 方案（REQ-007）：
- 各子模块独立 ICG，由 CTRL 寄存器控制使能
- 无独立功耗域
- 无功耗状态机

---

## 11. 存储设计

### 11.1 SRAM 设计

| 实例名称 | 类型 | 位宽 | 深度 | 容量 | 用途 |
|----------|------|------|------|------|------|
| axi_wr_buf | 1R1W | 64bit | 64 | 512B | AXI 写数据暂存 |
| spi_rx_buf | 1R1W | 8bit | 128 | 128B | SPI 接收数据暂存 |
| shared_rd_buf | 1R1W | 64bit | 128 | 1024B | 三路共享读返回缓冲 |
| addr_map_tbl | 1R1W | 32bit | 64 | 256B | 地址映射表 |
| **合计** | | | | **1920B** | **< 2KB 满足** |

### 11.2 FIFO 设计

本模块使用 SRAM 实现缓冲，不使用独立 FIFO。各 buffer 的满/空判断通过读写指针实现（多 1 位指针法）。

| Buffer | 满判断 | 空判断 |
|--------|--------|--------|
| axi_wr_buf | wr_ptr[6]!=rd_ptr[6] && wr_ptr[5:0]==rd_ptr[5:0] | wr_ptr==rd_ptr |
| spi_rx_buf | wr_ptr[7]!=rd_ptr[7] && wr_ptr[6:0]==rd_ptr[6:0] | wr_ptr==rd_ptr |
| shared_rd_buf | wr_ptr[7]!=rd_ptr[7] && wr_ptr[6:0]==rd_ptr[6:0] | wr_ptr==rd_ptr |

### 11.3 链表设计

本模块无链表管理需求。Buffer 管理使用简单的环形指针。

---

## 12. 调度与流控

### 12.1 调度策略

本模块三路上游访问不同地址空间，不存在多源仲裁。地址解码为纯组合逻辑，无需调度。

| 场景 | 策略 | 说明 |
|------|------|------|
| AXI 和 APB 同时访问不同地址 | 无冲突 | 独立通路并行处理 |
| AXI 和 APB 同时访问同一地址 | AXI 优先 | AXI 带宽更高，APB 等待 1 cycle |
| SPI 和 AXI 同时写入 | 无冲突 | 目标不同（DMA vs AXI4） |

### 12.2 流控机制

| 流控类型 | 接口 | 机制 | 背压路径 |
|----------|------|------|----------|
| 写背压 | AXI slave | wr_buf_full → awready/wready 拉低 | 下游 AXI4 反压 → wr_buf 满 → AXI slave 停止 |
| 读背压 | AXI slave | shared_rd_buf 空 → rvalid 拉低 | 下游返回慢 → 读 buf 空 → AXI slave 等待 |
| DMA 握手 | DMA master | valid/ready | 加速器反压 → dma_ready 拉低 → DMA master 保持 |

---

## 13. CBB 集成

本模块为纯自研设计，不使用外部 CBB/IP。SRAM 使用标准 SRAM compiler 生成。

---

## 14. 风险与缓解

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | SRAM 容量紧张，后续功能扩展可能超 2KB | 面积 | 中 | 地址映射表可用组合逻辑替代（省 256B） |
| R-002 | AXI 写突发合并增加写路径延迟 | 性能 | 低 | 合并为可选功能，可通过寄存器关闭 |
| R-003 | 共享读缓冲可能成为带宽瓶颈 | 性能 | 低 | 三路读返回时间片复用，增加 buffer 深度 |
| R-004 | 地址映射表硬编码灵活性不足 | 功能 | 低 | 使用 SRAM 存储映射表，APB 可运行时修改 |

---

## 15. 追溯矩阵（RTM）

| 需求 ID | 优先级 | 需求描述 | 方案章节 | 关键设计决策 |
|---------|--------|----------|----------|-------------|
| REQ-001 | Must | 28nm / 200MHz | §3.1, §6 | 单时钟域，5ns 周期 |
| REQ-002 | Must | APB32+AXI4+SPI → AXI4+DMA | §3.2, §4 | 独立协议转换通路 |
| REQ-003 | Should | AXI 16beat/32B, SPI 单拍 | §5.1 | 写 buffer 512B |
| REQ-004 | Must | AXI ≤4cycles, SPI ≤6cycles | §5.1, §6 | 两拍结构满足延迟 |
| REQ-005 | Must | 面积 ≤50kGates, SRAM ≤2KB | §8.3, §11.1 | SRAM 1920B + 逻辑 35kGates |
| REQ-006 | Must | 单时钟域 200MHz | §7.2 | 无 CDC |
| REQ-007 | Could | 全局 Clock Gating | §10.2 | ICG 控制 |
| REQ-008 | Should | 标准扫描链+ICG | §9 | DFT 友好设计 |
| REQ-009 | Should | SRAM Parity | §10.1 | Parity 保护 |
| REQ-012 | Must | SRAM 1920B + RegFile ~128B | §11.1 | 4 个 SRAM 实例 |
| REQ-015 | Should | 自定义 DMA Valid-Ready | §4, §12.2 | 流式握手 |
| REQ-016 | Should | 1 路中断 W1C | §7.1 | INT_STATUS W1C |
| REQ-019 | Should | APB 寄存器访问 | §7.1 | 14 个寄存器 |
| REQ-020 | Must | 固定地址映射 | §5.1 | 两段地址空间 |
| REQ-029 | Should | AXI 写突发合并 | §5.3 | burst_merge FSM |
| REQ-030 | Could | 错误注入寄存器 | §7.1 | ERR_INJECT 寄存器 |
| REQ-031 | Should | 事务计数器 | §7.1 | 5 个计数寄存器 |
