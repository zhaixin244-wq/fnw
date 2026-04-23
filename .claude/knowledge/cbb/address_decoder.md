# address_decoder — 地址解码器

> **用途**：将地址映射到从设备选择信号，用于总线地址译码
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

地址解码器根据输入地址产生从设备片选信号。支持地址范围匹配和固定基址+偏移两种模式。每个从设备配置一个地址范围（base ~ base+size），地址命中时对应的片选拉高。用于 AXI/AHB/APB 总线互联中主设备地址到从设备的映射。

```
addr[31:0] ──> ┌────────────────┐ ──cs[0]──> Slave 0 片选
               │ address_decoder│ ──cs[1]──> Slave 1 片选
               │   (N 从设备)    │ ──cs[2]──> Slave 2 片选
               └────────────────┘ ──decode_err──> 地址越界
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `ADDR_WIDTH` | parameter | 32 | 地址位宽 |
| `NUM_SLAVES` | parameter | 4 | 从设备数量 |
| `DECODE_MODE` | parameter | `"RANGE"` | 解码模式：`"RANGE"` = 地址范围，`"BASE"` = 基址+大小 |
| `DEC_ERR_EN` | parameter | 1 | 越界检测使能 |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `addr` | I | `ADDR_WIDTH` | - | 输入地址 |
| `cs` | O | `NUM_SLAVES` | - | 从设备片选（独热或位向量） |
| `decode_err` | O | 1 | - | 地址越界（无从设备命中） |
| `slave_idx` | O | `$clog2(NUM_SLAVES)` | - | 命中从设备索引 |
| `local_addr` | O | `ADDR_WIDTH` | - | 从设备本地地址（减去基址） |

> **注意**：本模块为纯组合逻辑，无时钟/复位。

### 地址范围配置（参数或端口输入）

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `base_addr` | I | `NUM_SLAVES × ADDR_WIDTH` | 各从设备基址 |
| `addr_mask` | I | `NUM_SLAVES × ADDR_WIDTH` | 地址掩码（RANGE 模式） |
| `addr_size` | I | `NUM_SLAVES × 16` | 地址空间大小（BASE 模式，字节） |

---

## 地址映射示例

| 从设备 | 基址 | 大小 | 地址范围 | 说明 |
|--------|------|------|----------|------|
| S0 (SRAM) | 0x0000_0000 | 64KB | 0x0000_0000 ~ 0x0000_FFFF | 内部 SRAM |
| S1 (ROM) | 0x0001_0000 | 32KB | 0x0001_0000 ~ 0x0001_7FFF | Boot ROM |
| S2 (APB) | 0x4000_0000 | 16MB | 0x4000_0000 ~ 0x40FF_FFFF | 外设配置 |
| S3 (DDR) | 0x8000_0000 | 2GB | 0x8000_0000 ~ 0xFFFF_FFFF | 外部 DDR |

---

## 时序

```
addr        ___|0x0000_1234______|0x4000_0008____|0x1234_5678______
cs          ___|4'b0001_________|4'b0100_________|4'b0000___________
slave_idx   _________| 0        | 2             |___
local_addr  _________|0x1234___| 0x0008________|___
decode_err  ________________| 0 _____________| 1 ___
              ↑ 命中 S0(SRAM)  ↑ 命中 S2(APB)  ↑ 越界
```

---

## 用法

### AXI 总线地址解码

```verilog
address_decoder #(
    .ADDR_WIDTH  (32),
    .NUM_SLAVES  (4),
    .DECODE_MODE ("BASE"),
    .DEC_ERR_EN  (1)
) u_axi_decoder (
    .addr        (axi_araddr),
    .cs          ({ddr_cs, apb_cs, rom_cs, sram_cs}),
    .decode_err  (axi_dec_err),
    .slave_idx   (target_slave),
    .local_addr  (slave_local_addr),
    // 地址配置
    .base_addr   ({32'h8000_0000, 32'h4000_0000, 32'h0001_0000, 32'h0000_0000}),
    .addr_mask   ({32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF}),
    .addr_size   ({16'h8000, 16'h0100, 16'h8000, 16'h0001})  // 单位 KB
);
```

### 带掩码的地址范围匹配

```verilog
// RANGE 模式：(addr & mask) == base 即命中
address_decoder #(
    .ADDR_WIDTH  (16),
    .NUM_SLAVES  (3),
    .DECODE_MODE ("RANGE")
) u_apb_decoder (
    .addr        (paddr),
    .cs          ({timer_cs, i2c_cs, uart_cs}),
    .decode_err  (),
    .slave_idx   (),
    .local_addr  (peri_local_addr),
    .base_addr   ({16'h0030, 16'h0020, 16'h0010}),
    .addr_mask   ({16'hFFF0, 16'hFFF0, 16'hFFF0}),   // 16 字节对齐
    .addr_size   ()
);
```

### 与交叉开关配合

```verilog
// 地址解码 → 交叉开关 slave 选择
address_decoder #(
    .ADDR_WIDTH  (32),
    .NUM_SLAVES  (8)
) u_noc_decoder (
    .addr        (m_addr),
    .cs          (slave_select),
    .decode_err  (addr_error),
    .slave_idx   (target_port),
    .local_addr  (local_offset),
    .base_addr   (cfg_base_addrs),
    .addr_mask   (cfg_addr_masks),
    .addr_size   ()
);

// decode_err → 返回 AXI DECERR
assign m_axi_rresp = addr_error ? 2'b11 : 2'b00;
```

---

## 关键实现细节

- **RANGE 模式**：`cs[i] = ((addr & addr_mask[i]) == base_addr[i])`
- **BASE 模式**：`cs[i] = (addr >= base_addr[i]) && (addr < base_addr[i] + addr_size[i])`
- **优先级**：多个从设备同时命中时，编号小的优先（需保证地址空间不重叠）
- **local_addr**：`addr - base_addr[slave_idx]`，传递给从设备的本地偏移
- **decode_err**：`~(|cs)` — 无任何从设备命中
- **纯组合逻辑**：无寄存器延迟
- **面积**：NUM_SLAVES × (ADDR_WIDTH × 2 比较器) + 编码器
- **注意事项**：地址空间必须不重叠，否则行为不确定；推荐用 SVA 检测
