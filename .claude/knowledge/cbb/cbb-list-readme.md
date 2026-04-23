# CBB 模块库总览

> **CBB**（Cell Building Block）：芯片设计可复用基础模块库
> **用途**：为芯片架构设计提供标准化模块参考，支持 FS/微架构文档生成和 RTL 实现
> **总计**：52 个模块，覆盖 10 大类别

---

## 模块分类索引

### 1. 调度与仲裁（6 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `priority_encoder` | [priority_encoder.md](priority_encoder.md) | 优先级编码器：LOW/HIGH 优先级，lock/release，grant 输出 |
| `arbiter` | [arbiter.md](arbiter.md) | 固定优先级仲裁器：参数化请求者数量，单周期仲裁 |
| `wrr` | [wrr.md](wrr.md) | 加权轮询调度：静态/动态权重，按权重比例分配带宽 |
| `dwrr` | [dwrr.md](dwrr.md) | 缺损加权轮询：credit-based，变长包公平调度 |
| `robin_bucket` | [robin_bucket.md](robin_bucket.md) | 轮询桶调度：令牌桶 + 轮询，变长事务公平调度 |
| `bigrr` | [bigrr.md](bigrr.md) | 大位宽轮询仲裁：RAM bitmap，64-4096 请求者，两级流水搜索 |

**选型指南**：
- 请求者 ≤ 16，固定优先级 → `arbiter` / `priority_encoder`
- 请求者 ≤ 16，加权轮询 → `wrr`
- 变长包公平调度 → `dwrr` / `robin_bucket`
- 请求者 ≥ 128 → `bigrr`

---

### 2. 流量整形（1 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `shaper` | [shaper.md](shaper.md) | 令牌桶整形器：SHAPER/POLICER 模式，CIR/CBS 配置，流量限速与监管 |

---

### 3. 总线与互联（5 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `crossbar` | [crossbar.md](crossbar.md) | 交叉开关：N×M 非阻塞互联，从端独立仲裁 |
| `address_decoder` | [address_decoder.md](address_decoder.md) | 地址译码器：range/base 模式，per-slave 片选输出 |
| `bridge_axi_to_apb` | [bridge_axi_to_apb.md](bridge_axi_to_apb.md) | AXI-to-APB 桥：协议转换，APB 状态机控制 |
| `axi4_lite_reg_file` | [axi4_lite_reg_file.md](axi4_lite_reg_file.md) | AXI4-Lite 寄存器文件：RW/RO/W1C 类型，字节选通 |
| `axi4_stream_mux` | [axi4_stream_mux.md](axi4_stream_mux.md) | AXI-Stream 多路复用器：多端口仲裁，帧锁定 |

---

### 4. 存储器（6 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `ram_sp` | [ram_sp.md](ram_sp.md) | 单端口 RAM：同步读写，初始化文件支持 |
| `ram_dp` | [ram_dp.md](ram_dp.md) | 双端口 RAM：独立读写端口，同/异步时钟 |
| `ram_tp` | [ram_tp.md](ram_tp.md) | 真双端口 RAM：两端口均可读写，read_first/write_first 模式 |
| `ram_ro` | [ram_ro.md](ram_ro.md) | ROM：文件初始化，BLOCK/DISTRIBUTED 风格 |
| `sync_fifo` | [sync_fifo.md](sync_fifo.md) | 同步 FIFO：单时钟域，almost_full/empty，指针法满空判断 |
| `async_fifo` | [async_fifo.md](async_fifo.md) | 异步 FIFO：跨时钟域，Gray 码指针，双触发器同步 |

---

### 5. 编码与计算（7 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `bin2onehot` | [bin2onehot.md](bin2onehot.md) | 二进制转独热码：纯组合逻辑，移位实现 |
| `onehot2bin` | [onehot2bin.md](onehot2bin.md) | 独热码转二进制：优先级模式，valid/error 检查 |
| `findfirstone` | [findfirstone.md](findfirstone.md) | 查找最低有效位：优先编码器核心逻辑 |
| `findlastone` | [findlastone.md](findlastone.md) | 查找最高有效位：前导零计数 |
| `popcount` | [popcount.md](popcount.md) | 人口计数器：树形加法位计数，汉明距离计算 |
| `barrel_shifter` | [barrel_shifter.md](barrel_shifter.md) | 桶形移位器：SLL/SRL/SRA/ROR，单周期可变移位 |
| `bit_reverse` | [bit_reverse.md](bit_reverse.md) | 位反转：纯线重排，CRC/SPI/FFT 位反射 |

---

### 6. CRC 与 ECC（2 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `crc_gen` | [crc_gen.md](crc_gen.md) | CRC 生成器：CRC-8/16/32，可配置多项式、反射、XOR |
| `ecc_encoder` | [ecc_encoder.md](ecc_encoder.md) | ECC 编码器：SECDED Hamming 码，可配置数据宽度 |

---

### 7. 外设接口（4 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `spi_master` | [spi_master.md](spi_master.md) | SPI 主机：4 种 SPI 模式，时钟分频，多 CS 支持 |
| `i2c_master` | [i2c_master.md](i2c_master.md) | I2C 主机：7/10 位寻址，时钟拉伸，命令式控制 |
| `uart_core` | [uart_core.md](uart_core.md) | UART 核心：可配置波特率/数据/校验/停止位，TX/RX FIFO |
| `pwm_gen` | [pwm_gen.md](pwm_gen.md) | PWM 生成器：左/中心对齐，多通道，占空比控制 |

---

### 8. 跨时钟域 CDC（4 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `cdc_sync` | [cdc_sync.md](cdc_sync.md) | CDC 双触发器同步：单 bit 跨域，可配置级数 |
| `cdc_handshake_bus` | [cdc_handshake_bus.md](cdc_handshake_bus.md) | CDC 握手总线：多 bit 数据跨域，toggle 同步 |
| `cdc_pulse_stretch` | [cdc_pulse_stretch.md](cdc_pulse_stretch.md) | CDC 脉冲展宽：展宽窄脉冲后再跨域同步 |
| `gray_converter` | [gray_converter.md](gray_converter.md) | Gray 码转换器：bin↔gray，纯组合逻辑，异步 FIFO 指针用 |

**选型指南**：
- 单 bit 信号跨域 → `cdc_sync`
- 多 bit 数据跨域（低频） → `cdc_handshake_bus`
- 脉冲信号跨域 → `cdc_pulse_stretch` + `cdc_sync`
- 异步 FIFO 指针 → `gray_converter`（内嵌于 async_fifo）

---

### 9. 链表与资源管理（6 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `linked_list_free` | [linked_list_free.md](linked_list_free.md) | 空闲链表：分配/回收 O(1)，指针式资源池 |
| `linked_list_queue` | [linked_list_queue.md](linked_list_queue.md) | 链表队列：优先级排序插入，任意移除 |
| `linked_list_circular` | [linked_list_circular.md](linked_list_circular.md) | 循环链表：轮询遍历，令牌环应用 |
| `linked_list_hash` | [linked_list_hash.md](linked_list_hash.md) | 哈希链表：关联存储，流表/ARP 缓存/TLB |
| `ptr_alloc` | [ptr_alloc.md](ptr_alloc.md) | 指针分配回收器：bitmap 方式，单周期分配，DEPTH≤256 |
| `wide_entry_wr` | [wide_entry_wr.md](wide_entry_wr.md) | 宽表项写入器：窄数据合写宽表项，原子提交 |

**选型指南**：
- DEPTH ≤ 256 → `ptr_alloc`（bitmap，面积小）
- DEPTH > 256 → `linked_list_free`（指针链表，O(1) 分配）
- 需要排序 → `linked_list_queue`
- 需要轮询遍历 → `linked_list_circular`
- 需要查表 → `linked_list_hash`

---

### 10. 基础时序与逻辑（9 个）

| 模块 | 文件 | 功能概述 |
|------|------|----------|
| `edge_detect` | [edge_detect.md](edge_detect.md) | 边沿检测器：RISING/FALLING/BOTH，1 周期脉冲输出 |
| `pulse_extend` | [pulse_extend.md](pulse_extend.md) | 脉冲展宽器：ONESHOT/RETRIGGER 模式，可配置宽度 |
| `reset_sync` | [reset_sync.md](reset_sync.md) | 复位同步器：异步复位同步释放，可配置级数 |
| `pipeline_reg` | [pipeline_reg.md](pipeline_reg.md) | 流水线寄存器：stall/flush 支持，valid 追踪 |
| `counter` | [counter.md](counter.md) | 可配置计数器：FREE/MODULO/UPDOWN 模式，load/clear |
| `clk_div` | [clk_div.md](clk_div.md) | 时钟分频器：偶数/奇数分频，50% 占空比，动态/固定 |
| `clk_gating` | [clk_gating.md](clk_gating.md) | 时钟门控 ICG：锁存器去毛刺，scan 使能 |
| `lfsr` | [lfsr.md](lfsr.md) | 线性反馈移位寄存器：Galois/Fibonacci，PRBS 生成，加扰 |
| `mux_onehot` | [mux_onehot.md](mux_onehot.md) | 独热码多路选择器：AND-OR 选择，可选流水线 |
| `valid_ready_delay` | [valid_ready_delay.md](valid_ready_delay.md) | Valid/Ready 延迟：可配置 valid 和 ready 路径延迟，仿真用 |
| `watchdog` | [watchdog.md](watchdog.md) | 看门狗定时器：reset/IRQ/BOTH 动作，lock/unlock 机制 |
| `intc` | [intc.md](intc.md) | 中断控制器：电平/边沿触发，优先级，enable/pending/W1C |

---

## 模块关系速查

```
                    ┌─────────────────────────────────────────┐
                    │            调度与仲裁                    │
                    │  priority_encoder ← arbiter             │
                    │  wrr → dwrr → robin_bucket              │
                    │  bigrr (大规模)                          │
                    └──────────────┬──────────────────────────┘
                                   │ grant
    ┌──────────────┐    ┌─────────▼──────────┐    ┌──────────────┐
    │  流量整形     │───>│    总线与互联       │───>│   存储器      │
    │  shaper      │    │  crossbar           │    │  ram_*       │
    └──────────────┘    │  address_decoder    │    │  sync_fifo   │
                        │  bridge_axi_to_apb  │    │  async_fifo  │
                        │  axi4_lite_reg_file │    └──────────────┘
                        │  axi4_stream_mux    │
                        └────────────────────┘
                                   │
    ┌──────────────┐    ┌─────────▼──────────┐    ┌──────────────┐
    │  外设接口     │    │    编码与计算       │    │  CRC/ECC     │
    │  spi_master  │    │  bin2onehot         │    │  crc_gen     │
    │  i2c_master  │    │  onehot2bin         │    │  ecc_encoder │
    │  uart_core   │    │  findfirstone       │    └──────────────┘
    │  pwm_gen     │    │  findlastone        │
    └──────────────┘    │  popcount           │
                        │  barrel_shifter     │    ┌──────────────┐
    ┌──────────────┐    │  bit_reverse        │    │  资源管理     │
    │  CDC 跨域     │    └────────────────────┘    │  ptr_alloc   │
    │  cdc_sync    │                               │  linked_list │
    │  cdc_hand... │    ┌────────────────────┐    │  wide_entry  │
    │  cdc_pulse.. │    │    基础时序与逻辑    │    └──────────────┘
    │  gray_conv.. │    │  edge_detect        │
    └──────────────┘    │  pulse_extend       │    ┌──────────────┐
                        │  reset_sync         │    │  系统管理     │
                        │  pipeline_reg       │    │  watchdog    │
                        │  counter            │    │  intc        │
                        │  clk_div / clk_gate │    └──────────────┘
                        │  lfsr / mux_onehot  │
                        └────────────────────┘
```

---

## 使用方式

每个 CBB 文档包含以下标准章节：

| 章节 | 内容 |
|------|------|
| 模块概述 | 功能描述、应用场景、框图 |
| 参数 | 可配置参数及默认值 |
| 接口 | 信号列表：方向、位宽、时钟域、说明 |
| 时序 | 波形图或时序描述 |
| 用法 | 2-4 个典型应用场景的 Verilog 实例化示例 |
| 关键实现细节 | 面积、时序、设计注意事项 |

**配合 chip-arch agent 使用**：在生成 FS/微架构文档时，agent 会检索本目录下的 CBB 文档作为 IP/CBB 集成参考。
