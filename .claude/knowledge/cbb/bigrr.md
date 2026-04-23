# bigrr — 大位宽位图轮询仲裁器（RAM 存储版）

> **用途**：大规模位图轮询仲裁器，使用 RAM 存储 bitmap 优化面积和时序
> **可综合**：是
> **语言** : Verilog

---

## 模块概述

BIGRR（BIG Round Robin）解决大位宽（64-4096 请求者）轮询仲裁的时序和面积问题。传统寄存器 bitmap 方案在 N>128 时 findfirstone 逻辑级数过深、面积过大。BIGRR 将 bitmap 存储在 Block RAM 中，通过"mask + 二次查找"两阶段搜索策略，将关键路径拆分为两级流水线，实现大位宽下的高频率仲裁。

```
req[1023:0] ──> ┌──────────────┐ ──grant──> 独热授权
                │    bigrr      │ ──grant_idx──> 二进制索引
                │ (RAM bitmap) │ ──grant_valid
                └──────────────┘
     bitmap 存在 RAM → 两阶段搜索 → 流水线仲裁
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_REQ` | parameter | 1024 | 请求者数量（必须为 2 的幂） |
| `DATA_WIDTH` | localparam | 32 | RAM 数据位宽（每字 32 bit） |
| `ADDR_WIDTH` | localparam | `$clog2(NUM_REQ/DATA_WIDTH)` | RAM 地址位宽 |
| `PIPE_STAGE` | parameter | 2 | 流水线级数（1=单周期，2=两级流水线） |
| `RESET_VAL` | parameter | `"ALL_IDLE"` | 复位值：`"ALL_IDLE"` = 全空闲，`"FILE"` = 文件加载 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `req` | I | `NUM_REQ` | clk | 请求向量 |
| `grant` | O | `NUM_REQ` | clk | 独热授权 |
| `grant_idx` | O | `$clog2(NUM_REQ)` | clk | 授权索引 |
| `grant_valid` | O | 1 | clk | 授权有效 |
| `set_idle` | I | 1 | clk | 请求完成后标记空闲 |
| `set_idle_idx` | I | `$clog2(NUM_REQ)` | clk | 标记空闲的索引 |

### 内部 RAM 端口（自动生成）

| 信号 | 位宽 | 说明 |
|------|------|------|
| `bm_ram_addr` | `ADDR_WIDTH` | bitmap RAM 地址 |
| `bm_ram_wdata` | `DATA_WIDTH` | 写数据 |
| `bm_ram_rdata` | `DATA_WIDTH` | 读数据 |
| `bm_ram_we` | 1 | 写使能 |

---

## 时序

### 两级流水线仲裁（PIPE_STAGE=2）

```
clk         __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
req         ___|req[1023:0]__________________|

// 第一级：读 RAM bitmap + 段内搜索
bm_ram_addr _________|段0|段1|段2|...|_________
bm_ram_rdata_____________|W0 |W1 | W2|_________

// 第二级：精确位置 + 输出
grant_idx   _______________________|512|______  (pipeline=2, 延迟 2 cycle)
grant_valid _________________________| ‾ |______
set_idle    _________________________| ‾ |______
set_idle_idx_________________________|512|
```

### 单周期仲裁（PIPE_STAGE=1）

```
clk         __|‾|__|‾|__|‾|__|‾|__
req         ___|req[1023:0]________|
grant_idx   _________| 256       |__  (延迟 1 cycle)
grant_valid _________| ‾ ‾ ‾ ‾ ‾ _|__
```

---

## 两阶段搜索算法

```
阶段 1（段级搜索）：
  对 bitmap 的每个 32-bit 段做 OR 归约
  findfirstone 找到第一个非零段的段地址 seg_addr

阶段 2（位级搜索）：
  读出 seg_addr 对应的 32-bit word
  findfirstone 找到段内最低位 bit_offset
  grant_idx = seg_addr × 32 + bit_offset
```

**时序优势**：阶段 1 为 log2(NUM_SEGMENTS) 级逻辑，阶段 2 为 log2(32)=5 级逻辑。总级数 ≈ log2(N/32)+5，比直接 log2(N) 更扁平。

---

## 用法

### 千端口仲裁器

```verilog
bigrr #(
    .NUM_REQ    (1024),
    .PIPE_STAGE (2),
    .RESET_VAL  ("ALL_IDLE")
) u_1024_arb (
    .clk           (clk),
    .rst_n         (rst_n),
    .req           (port_req),            // 1024-bit 请求
    .grant         (port_grant),
    .grant_idx     (port_grant_idx),
    .grant_valid   (port_grant_valid),
    .set_idle      (port_tx_done),
    .set_idle_idx  (port_grant_idx)        // 传输完成标记空闲
);
```

### 网络交换芯片端口仲裁

```verilog
// 256 端口交换芯片输出仲裁
bigrr #(
    .NUM_REQ    (256),
    .PIPE_STAGE (2)
) u_switch_arb (
    .clk           (clk),
    .rst_n         (rst_n),
    .req           (ingress_req),
    .grant         (egrant),
    .grant_idx     (egrant_idx),
    .grant_valid   (egrant_valid),
    .set_idle      (egrant_done),
    .set_idle_idx  (egrant_idx)
);
```

### 大规模中断仲裁

```verilog
bigrr #(
    .NUM_REQ    (512),
    .PIPE_STAGE (1)                // 中断不需高频率
) u_irq_arb (
    .clk           (clk),
    .rst_n         (rst_n),
    .req           (irq_pending),
    .grant         (),
    .grant_idx     (active_irq),
    .grant_valid   (irq_valid),
    .set_idle      (irq_ack),
    .set_idle_idx  (active_irq)
);
```

---

## 关键实现细节

- **RAM bitmap**：NUM_REQ/DATA_WIDTH 个 DATA_WIDTH-bit word，每 bit 对应一个请求者的 "已被服务" 状态
- **有效请求**：`active_req = req & ~bitmap` — 请求中但尚未被服务的
- **两阶段搜索**：先找非零段（段级 OR），再找段内最低位（5 级逻辑）
- **轮询更新**：grant 后 bitmap 对应位置 1，set_idle 时清零
- **RAM 读写仲裁**：搜索读 RAM 和 bitmap 更新写 RAM 不能同时，需要仲裁或双端口 RAM
- **PIPE_STAGE=2**：阶段 1 在 cycle 1 完成（读 RAM），阶段 2 在 cycle 2 完成（精确搜索 + 输出）
- **面积**：NUM_REQ bit 的 RAM（= NUM_REQ/8 字节）+ 2 个 findfirstone + 控制逻辑
- **相比寄存器 bitmap**：RAM 版面积小 N 倍（触发器 vs bit），时序更优（分段搜索）
- **适用范围**：NUM_REQ ≥ 128 推荐 BIGRR，< 128 用寄存器 priority_encoder 即可
