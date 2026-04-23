# cdc_handshake_bus — 多 bit CDC 握手总线

> **用途**：多 bit 数据跨时钟域安全传输，基于请求-应答握手协议
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

多 bit CDC 握手总线将多个 bit 数据从源时钟域安全传递到目标时钟域。相比异步 FIFO 更节省面积（无存储阵列），但吞吐较低。适用于不频繁的配置参数传递、状态上报、命令下发等场景。数据在源域保持稳定 → 发送请求 → 目标域同步请求 → 锁存数据 → 返回应答 → 源域清除请求。

```
src_clk 域                      dst_clk 域
data_src ──> ┌──────────────────┐ ──> data_dst
valid_src──> │ cdc_handshake_bus│ ──> valid_dst
ready_src<── │   (DATA_WIDTH)   │ <── ready_dst
             └──────────────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `DATA_WIDTH` | parameter | 32 | 数据位宽 |
| `SYNC_STAGES` | parameter | 2 | 同步器级数 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk_src` | I | 1 | - | 源时钟域 |
| `rst_src_n` | I | 1 | - | 源域异步复位 |
| `clk_dst` | I | 1 | - | 目标时钟域 |
| `rst_dst_n` | I | 1 | - | 目标域异步复位 |
| `data_src` | I | `DATA_WIDTH` | clk_src | 源数据 |
| `valid_src` | I | 1 | clk_src | 数据有效（请求） |
| `ready_src` | O | 1 | clk_src | 传输完成（应答） |
| `data_dst` | O | `DATA_WIDTH` | clk_dst | 目标数据 |
| `valid_dst` | O | 1 | clk_dst | 数据有效 |
| `ready_dst` | I | 1 | clk_dst | 目标就绪 |

---

## 时序

```
clk_src    __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
valid_src  _______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|______
data_src   _______| D1 (保持稳定)             |_______
req_toggle _______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (toggle 翻转)
ready_src  _________________________________|‾|_______
                                        ↑ 握手完成
clk_dst    ___|‾|___|‾|___|‾|___|‾|___|‾|___|‾|___
req_sync   _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (2FF 同步)
ack_toggle _________________________|‾‾‾‾‾‾‾‾‾‾‾‾‾  (应答 toggle)
valid_dst  _________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
data_dst   _________________| D1                  ‾‾
ready_dst  _________________________|‾‾‾‾‾‾‾‾‾‾‾‾‾
```

- **原理**：src req → toggle 翻转 → 2FF 同步 → dst valid；dst ready → toggle 翻转 → 2FF 同步 → src ready
- **延迟**：最少 4 个慢时钟周期（取决于两个时钟频率）
- **吞吐**：较低（每次传输需要完整握手往返）
- **数据稳定**：data_src 必须在 valid_src=1 期间保持不变

---

## 用法

### 配置参数传递

```verilog
// 配置域传递 32-bit 配置到工作域
cdc_handshake_bus #(
    .DATA_WIDTH  (32),
    .SYNC_STAGES (2)
) u_cfg_cdc (
    .clk_src     (clk_cfg),
    .rst_src_n   (rst_cfg_n),
    .clk_dst     (clk_core),
    .rst_dst_n   (rst_core_n),
    .data_src    (cfg_reg),
    .valid_src   (cfg_update),
    .ready_src   (cfg_done),
    .data_dst    (core_cfg),
    .valid_dst   (core_cfg_valid),
    .ready_dst   (core_cfg_ready)
);
```

### 命令下发

```verilog
// CPU 域下发 16-bit 命令到 DMA 域
cdc_handshake_bus #(
    .DATA_WIDTH  (16),
    .SYNC_STAGES (2)
) u_cmd_cdc (
    .clk_src     (clk_cpu),
    .rst_src_n   (rst_cpu_n),
    .clk_dst     (clk_dma),
    .rst_dst_n   (rst_dma_n),
    .data_src    (cpu_cmd),
    .valid_src   (cpu_cmd_valid),
    .ready_src   (cpu_cmd_done),
    .data_dst    (dma_cmd),
    .valid_dst   (dma_cmd_valid),
    .ready_dst   (dma_cmd_ready)
);
```

### 状态上报

```verilog
// 工作域上报 8-bit 状态到监控域
cdc_handshake_bus #(
    .DATA_WIDTH  (8),
    .SYNC_STAGES (3)             // 高可靠性场景用 3 级
) u_status_cdc (
    .clk_src     (clk_work),
    .rst_src_n   (rst_work_n),
    .clk_dst     (clk_mon),
    .rst_dst_n   (rst_mon_n),
    .data_src    (work_status),
    .valid_src   (status_update),
    .ready_src   (status_ack),
    .data_dst    (mon_status),
    .valid_dst   (mon_status_valid),
    .ready_dst   (mon_ready)
);
```

---

## 关键实现细节

- **请求路径**：src valid → toggle 翻转（`req_tog <= ~req_tog`）→ 2FF 同步到 dst → dst 边沿检测 → dst valid
- **应答路径**：dst ready → toggle 翻转（`ack_tog <= ~ack_tog`）→ 2FF 同步到 src → src 边沿检测 → src ready
- **数据锁存**：dst 域在 req_sync 边沿锁存 data_src（数据已在 src 域稳定）
- **dst ready 背压**：ready_dst=0 时 valid_dst 保持，不丢失数据
- **src valid 背压**：ready_src=0 期间 valid_src 可保持或撤销
- **最低延迟**：2（req 同步）+ 1（dst 锁存）+ 2（ack 同步）= 5 cycles（慢时钟）
- **面积**：DATA_WIDTH 个触发器（数据锁存）+ 4 个同步触发器 + 边沿检测逻辑
- **适用场景**：低频配置传递（每秒几十到几千次），不适合高频数据流（用异步 FIFO）
