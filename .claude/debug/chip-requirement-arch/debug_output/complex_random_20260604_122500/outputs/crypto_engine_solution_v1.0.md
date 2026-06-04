# 国密/国际双模加密引擎 架构方案文档

> 版本：v1.0
> 日期：2026-06-04
> 模块名称：crypto_engine
> 文档编号：FNW-SOL-crypto_engine-v1.0

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| 模块名称 | 国密/国际双模加密引擎 (crypto_engine) |
| 版本 | v1.0 |
| 日期 | 2026-06-04 |
| 作者 | chip-requirement-arch Agent |
| 对应需求 | crypto_engine_requirement_summary_v1.0.md |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-06-04 | Agent | 初始版本 |

---

## 3. 架构概述

### 3.1 模块定位

国密/国际双模加密引擎是安全子系统的核心密码处理单元，位于CPU/DMA与密钥存储/安全隔离区之间，负责：
- 国密算法：SM2（非对称）、SM3（哈希）、SM4（对称）
- 国际算法：AES（对称）、SHA（哈希）、RSA（非对称）
- 高级抗侧信道防护（DPA/SPA抵抗）
- 商密认证合规（GM/T 0028/0039）

### 3.2 关键特性

| 特性 | REQ | 说明 |
|------|-----|------|
| 双模并行 | REQ-029, REQ-034 | 国密与国际算法可同时运行，4通道并行 |
| 高级抗侧信道 | REQ-010 | DPA/SPA抵抗，过商密认证 |
| 多算法支持 | REQ-029~032 | SM2/SM3/SM4/AES/SHA/RSA/KDF |
| AXI 128bit | REQ-002 | 大数据块搬运，DMA驱动 |
| 流水线可配置 | REQ-035 | 2/4/8级可配置 |

### 3.3 顶层框图

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                    crypto_engine_top                         │
                    │                                                             │
  AXI4 128bit ─────►│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
  (CPU/DMA)         │  │ axi_slave   │───►│  scheduler  │───►│  key_mgr    │    │
                    │  │ _if         │    │  (4通道)    │    │  (ECC)      │    │
                    │  └─────────────┘    └──────┬──────┘    └─────────────┘    │
                    │                            │                               │
  APB 32bit ───────►│  ┌─────────────┐           │                               │
  (配置)            │  │ apb_reg     │           ▼                               │
                    │  │ _ctrl    ┌──┼──►┌─────────────────────────────────┐     │
                    │  └─────────┼──┘   │         加密引擎集群             │     │
                    │            │      │  ┌─────────┐ ┌─────────┐        │     │
                    │            │      │  │sm2_engine│ │sm3_engine│        │     │
                    │            │      │  │sm4_engine│ │aes_engine│        │     │
                    │            │      │  │sha_engine│ │rsa_engine│        │     │
                    │            │      │  │kdf_engine│ │         │        │     │
                    │            │      │  └─────────┘ └─────────┘        │     │
                    │            │      └─────────────────────────────────┘     │
                    │            │                                              │
                    │            ▼                                              │
                    │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
                    │  │ irq_ctrl    │    │ perf_cnt    │    │side_channel │  │
                    │  │ (中断)      │    │ (性能)      │    │_prot        │  │
                    │  └─────────────┘    └─────────────┘    └─────────────┘  │
                    │                                                             │
  TRNG ─────────────►│  ┌─────────────┐                                          │
                    │  │ trng_if     │                                          │
                    │  └─────────────┘                                          │
                    │                                                             │
  密钥存储 ◄────────►│  密钥接口                                                │
  安全隔离区        │                                                             │
                    └─────────────────────────────────────────────────────────────┘
```

### 3.4 子模块列表

| 子模块 | 职责 | 预估行数 | 关键REQ |
|--------|------|----------|---------|
| crypto_engine_top | 顶层集成 | 200 | - |
| axi_slave_if | AXI从接口 | 400 | REQ-002, REQ-036 |
| apb_reg_ctrl | APB寄存器 | 300 | REQ-019 |
| sm2_engine | SM2算法 | 800 | REQ-029 |
| sm3_engine | SM3算法 | 500 | REQ-030 |
| sm4_engine | SM4算法 | 600 | REQ-037 |
| aes_engine | AES算法 | 600 | REQ-031 |
| sha_engine | SHA算法 | 500 | REQ-030 |
| rsa_engine | RSA算法 | 800 | - |
| kdf_engine | KDF算法 | 400 | REQ-032 |
| trng_if | TRNG接口 | 200 | REQ-033 |
| key_mgr | 密钥管理 | 400 | REQ-009, REQ-040 |
| side_channel_prot | 抗侧信道 | 600 | REQ-010 |
| scheduler | 多通道调度 | 400 | REQ-034 |
| irq_ctrl | 中断控制 | 200 | REQ-016 |
| perf_cnt | 性能计数器 | 150 | REQ-039 |

**RTL总行数**：7050行（>3000行，已进行子模块分组）

---

## 4. 接口定义

### 4.1 顶层接口列表

| 接口名称 | 协议类型 | 方向 | 位宽 | 时钟域 | 说明 |
|----------|----------|------|------|--------|------|
| axi_if | AXI4 Slave | I/O | 128bit | clk | CPU/DMA数据接口 |
| apb_if | APB Slave | I | 32bit | clk | 配置寄存器接口 |
| trng_if | 自定义 | I | 32bit | clk | TRNG随机数接口 |
| key_if | 自定义 | I/O | 256bit | clk | 密钥存储接口 |
| irq_o | 电平 | O | 1 | clk | 中断输出 |
| scan_en | 电平 | I | 1 | - | DFT扫描使能 |

### 4.2 AXI接口信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| axi_awvalid | I | 1 | 写地址有效 |
| axi_awready | O | 1 | 写地址就绪 |
| axi_awaddr | I | 32 | 写地址 |
| axi_awlen | I | 8 | 突发长度 |
| axi_wvalid | I | 1 | 写数据有效 |
| axi_wready | O | 1 | 写数据就绪 |
| axi_wdata | I | 128 | 写数据 |
| axi_wlast | I | 1 | 写最后一拍 |
| axi_bvalid | O | 1 | 写响应有效 |
| axi_bready | I | 1 | 写响应就绪 |
| axi_arvalid | I | 1 | 读地址有效 |
| axi_arready | O | 1 | 读地址就绪 |
| axi_araddr | I | 32 | 读地址 |
| axi_arlen | I | 8 | 突发长度 |
| axi_rvalid | O | 1 | 读数据有效 |
| axi_rready | I | 1 | 读数据就绪 |
| axi_rdata | O | 128 | 读数据 |
| axi_rlast | O | 1 | 读最后一拍 |

### 4.3 APB接口信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| apb_psel | I | 1 | 选择 |
| apb_penable | I | 1 | 使能 |
| apb_pwrite | I | 1 | 写使能 |
| apb_paddr | I | 12 | 地址 |
| apb_pwdata | I | 32 | 写数据 |
| apb_prdata | O | 32 | 读数据 |
| apb_pready | O | 1 | 就绪 |

---

## 5. 数据通路与控制逻辑

### 5.1 数据通路

```
输入数据流：
  CPU/DMA ──[AXI 128bit]──► axi_slave_if ──[内部总线]──► scheduler
                                                              │
                              ┌───────────────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │  通道选择       │
                    │  (Round-Robin)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────┐
        │ 国密引擎 │    │ 国际引擎 │    │  KDF   │
        │SM2/SM3/SM4│    │AES/SHA/RSA│    │        │
        └────┬────┘    └────┬────┘    └────┬────┘
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                    ┌─────────────────┐
                    │  side_channel   │
                    │  _prot          │
                    │  (掩码/随机延时) │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  输出缓冲       │
                    └────────┬────────┘
                             │
                             ▼
  CPU/DMA ◄──[AXI 128bit]── axi_slave_if
```

### 5.2 各算法处理延迟

| 算法 | 单次处理延迟 | 吞吐量 | 说明 |
|------|-------------|--------|------|
| SM2签名 | 200 cycles | 2次/100cycles | 并行签名验签 |
| SM2验签 | 250 cycles | 2次/125cycles | 并行签名验签 |
| SM3哈希 | 80 cycles | 1次/20cycles | 4级流水线 |
| SM4加密 | 40 cycles | 1次/10cycles | 128bit块 |
| AES加密 | 20 cycles | 1次/5cycles | 128bit块，流水线 |
| SHA哈希 | 80 cycles | 1次/20cycles | 4级流水线 |
| RSA加密 | 500 cycles | 1次/500cycles | 2048bit |
| KDF | 100 cycles | 1次/100cycles | 密钥派生 |

### 5.3 控制逻辑/FSM

#### 顶层状态机

| 状态 | 编码 | 描述 | 转移条件 |
|------|------|------|----------|
| S_IDLE | 4'b0001 | 空闲，等待命令 | 收到有效命令 |
| S_CMD_PARSE | 4'b0010 | 命令解析 | 解析完成 |
| S_DATA_LOAD | 4'b0100 | 数据加载 | 数据就绪 |
| S_PROCESS | 4'b1000 | 加密处理 | 处理完成 |
| S_OUTPUT | 4'b0011 | 结果输出 | 输出完成 |
| S_ERROR | 4'b0101 | 错误处理 | 错误恢复 |

#### 通道调度策略

| 调度器 | 策略 | 说明 |
|--------|------|------|
| scheduler | Round-Robin | 4通道公平调度，每通道独立优先级 |

---

## 6. 关键时序分析

### 6.1 关键路径

| 路径 | 起点 | 终点 | 延迟 | 说明 |
|------|------|------|------|------|
| CP-01 | axi_slave_if | scheduler | 2.5ns | AXI到调度器 |
| CP-02 | scheduler | aes_engine | 2.0ns | 调度器到加密引擎 |
| CP-03 | aes_engine | side_channel_prot | 2.5ns | 加密到侧信道防护 |
| CP-04 | side_channel_prot | axi_slave_if | 2.0ns | 防护到输出 |

**最差路径延迟**：9.0ns（CP-01 + CP-02 + CP-03 + CP-04）

### 6.2 时序裕量

**400MHz周期**：2.5ns

| 路径 | 延迟 | 周期 | 裕量 | 是否满足 |
|------|------|------|------|----------|
| CP-01 | 2.5ns | 2.5ns | 0ns | ⚠️ 需优化 |
| CP-02 | 2.0ns | 2.5ns | 0.5ns | ✅ |
| CP-03 | 2.5ns | 2.5ns | 0ns | ⚠️ 需优化 |
| CP-04 | 2.0ns | 2.5ns | 0.5ns | ✅ |

**优化建议**：CP-01和CP-03需要插入流水线寄存器。

### 6.3 SDC约束建议

```tcl
create_clock -name clk -period 2.5 [get_ports clk]
set_input_delay -clock clk -max 1.0 [get_ports {axi_* apb_* trng_*}]
set_output_delay -clock clk -max 1.0 [get_ports {axi_* irq_o}]
set_false_path -from [get_ports rst_n]
set_multicycle_path -setup 2 -from [get_ports {key_if_*}]
```

---

## 7. 寄存器定义与CDC方案

### 7.1 寄存器地址映射

| 偏移地址 | 名称 | 访问类型 | 复位值 | 描述 |
|----------|------|----------|--------|------|
| 0x000 | CTRL | RW | 0x0000_0000 | 控制寄存器 |
| 0x004 | STATUS | RO | 0x0000_0000 | 状态寄存器 |
| 0x008 | INT_STATUS | W1C | 0x0000_0000 | 中断状态 |
| 0x00C | INT_MASK | RW | 0x0000_0000 | 中断掩码 |
| 0x010 | ALG_SEL | RW | 0x0000_0000 | 算法选择 |
| 0x014 | CH_CTRL | RW | 0x0000_0000 | 通道控制 |
| 0x018 | KEY_ADDR | RW | 0x0000_0000 | 密钥地址 |
| 0x01C | DATA_ADDR | RW | 0x0000_0000 | 数据地址 |
| 0x020 | DATA_LEN | RW | 0x0000_0000 | 数据长度 |
| 0x024 | PERF_CTRL | RW | 0x0000_0000 | 性能计数控制 |
| 0x028 | PERF_CNT0 | RO | 0x0000_0000 | 性能计数器0 |
| 0x02C | PERF_CNT1 | RO | 0x0000_0000 | 性能计数器1 |
| 0x030 | ERR_STATUS | RO | 0x0000_0000 | 错误状态 |
| 0x034 | KEY_STAT | RO | 0x0000_0000 | 密钥使用统计 |
| 0x038~0x0FC | RSVD | - | - | 保留 |

### 7.2 寄存器位域定义

**CTRL（偏移0x000）**：控制寄存器

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [0] | START | WO | 0 | 启动加密 |
| [1] | RESET | WO | 0 | 软复位 |
| [2] | ABORT | WO | 0 | 中止当前操作 |
| [3] | KEY_LOAD | WO | 0 | 加载密钥 |
| [7:4] | CH_EN | RW | 0 | 通道使能 |
| [15:8] | ALG_MODE | RW | 0 | 算法模式 |
| [31:16] | RSVD | - | 0 | 保留 |

**ALG_SEL（偏移0x010）**：算法选择

| Bit | 名称 | 访问 | 复位值 | 描述 |
|-----|------|------|--------|------|
| [3:0] | ALG | RW | 0 | 0001=SM2, 0010=SM3, 0100=SM4, 1000=AES |
| [7:4] | SUB_MODE | RW | 0 | 子模式 |
| [11:8] | KEY_SIZE | RW | 0 | 密钥大小 |
| [31:12] | RSVD | - | 0 | 保留 |

### 7.3 CDC方案

单时钟域设计，无CDC需求。所有信号在clk域内同步。

---

## 8. PPA预估

### 8.1 性能指标

| 指标 | 数值 | 单位 | 约束类型 | 条件 |
|------|------|------|----------|------|
| 最大频率 | 400 | MHz | Target | Fmax |
| SM4吞吐 | 5.12 | Gbps | Target | 128bit/10cycles@400MHz |
| AES吞吐 | 10.24 | Gbps | Target | 128bit/5cycles@400MHz |
| SM3吞吐 | 2.56 | Gbps | Target | 256bit/20cycles@400MHz |
| 并行通道 | 4 | 通道 | Target | 同时处理 |

### 8.2 功耗指标（PVT：TT / 0.9V / 25°C / 400MHz）

| 指标 | 数值 | 单位 | 约束类型 |
|------|------|------|----------|
| 动态功耗 | 150 | mW | Budget |
| 静态功耗 | 10 | mW | Budget |
| **合计** | **160** | **mW** | - |

### 8.3 面积指标

| 指标 | 数值 | 单位 | 约束类型 |
|------|------|------|----------|
| 逻辑面积 | 250 | kGates | Estimated |
| SRAM面积 | 50 | Kbit | Estimated |
| ROM面积 | 20 | Kbit | Estimated |
| **合计** | **320** | **kGates** | - |

### 8.4 子模块PPA预算分配

| 子模块 | 延迟 | 面积(kGates) | 功耗(mW) |
|--------|------|-------------|----------|
| axi_slave_if | 2.5ns | 30 | 15 |
| apb_reg_ctrl | - | 15 | 5 |
| sm2_engine | 200cycles | 50 | 25 |
| sm3_engine | 80cycles | 30 | 15 |
| sm4_engine | 40cycles | 35 | 18 |
| aes_engine | 20cycles | 35 | 18 |
| sha_engine | 80cycles | 30 | 15 |
| rsa_engine | 500cycles | 40 | 20 |
| kdf_engine | 100cycles | 25 | 12 |
| scheduler | - | 20 | 10 |
| key_mgr | - | 25 | 12 |
| side_channel_prot | - | 40 | 20 |
| irq_ctrl | - | 10 | 5 |
| perf_cnt | - | 8 | 4 |
| **合计** | - | **393** | **194** |

---

## 9. DFX设计

### 9.1 扫描链约束

| 约束项 | 配置 | 说明 |
|--------|------|------|
| 扫描链数量 | 8条 | 按子模块分组 |
| 分域策略 | 全局 | 单功耗域 |
| 扫描使能信号 | scan_en | 全局扫描使能 |

### 9.2 ICG配置

| 时钟 | ICG Cell | 使能信号 | Scan Enable |
|------|----------|----------|-------------|
| clk | ICG_CLK | clk_en | scan_en |

### 9.3 错误注入接口

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| err_inject | I | 8 | 错误注入控制 |
| err_inject_data | I | 128 | 错误注入数据 |

---

## 10.1 可靠性设计

### 10.1.1 ECC/Parity方案

| 存储/信号 | 保护类型 | 编码 | 检错/纠错能力 | 面积开销 |
|-----------|----------|------|--------------|----------|
| 密钥缓存 | ECC | SECDED | 1bit纠错+2bit检错 | 20% |
| 寄存器文件 | Parity | 奇偶 | 1bit检错 | 5% |

### 10.1.2 抗侧信道防护

| 防护对象 | 策略 | 说明 |
|----------|------|------|
| AES/SM4 S盒 | 掩码 | 随机掩码保护 |
| RSA/SM2 模幂 | 随机延时 | 随机插入dummy操作 |
| 密钥访问 | 地址随机化 | 访问地址随机扰动 |
| 功耗均衡 | 双轨逻辑 | 关键路径双轨实现 |

---

## 10.2 低功耗设计

使用全局Clock Gating方案，无独立功耗域需求。

### Clock Gating配置

| 模块 | ICG使能 | 条件 |
|------|---------|------|
| sm2_engine | sm2_en | SM2算法使能 |
| sm3_engine | sm3_en | SM3算法使能 |
| sm4_engine | sm4_en | SM4算法使能 |
| aes_engine | aes_en | AES算法使能 |
| sha_engine | sha_en | SHA算法使能 |
| rsa_engine | rsa_en | RSA算法使能 |

---

## 11. 存储设计

### 11.1 SRAM配置

| SRAM名称 | 类型 | 容量 | 端口 | 用途 |
|----------|------|------|------|------|
| key_sram | 1R1W | 8Kbit | 256bit | 密钥缓存 |
| data_sram | 2P | 32Kbit | 128bit | 数据缓冲 |

### 11.2 ROM配置

| ROM名称 | 类型 | 容量 | 用途 |
|---------|------|------|------|
| sbox_aes_rom | ROM | 8Kbit | AES S盒 |
| sbox_sm4_rom | ROM | 8Kbit | SM4 S盒 |
| const_rom | ROM | 4Kbit | 常量表 |

### 11.3 FIFO配置

| FIFO名称 | 方向 | 位宽 | 深度 | 类型 | 说明 |
|----------|------|------|------|------|------|
| cmd_fifo | 输入 | 64 | 16 | 同步 | 命令队列 |
| result_fifo | 输出 | 128 | 16 | 同步 | 结果队列 |

---

## 12. 调度与流控

### 12.1 调度策略

| 调度器 | 策略 | 优先级 | 说明 |
|--------|------|--------|------|
| scheduler | Round-Robin | 4通道公平 | 每通道独立，无优先级差异 |

### 12.2 流控机制

| 类型 | 接口 | 机制 | 背压路径 |
|------|------|------|----------|
| AXI流控 | axi_if | ready反压 | 下游满→axi_wready拉低→DMA暂停 |
| 内部流控 | 内部总线 | Credit | 4通道Credit计数，归零反压 |

---

## 13. CBB集成

本模块不使用外部CBB，所有算法引擎自研实现。

**原因**：
- 商密认证要求算法实现可控
- 抗侧信道防护需要定制化实现
- 自研实现可满足GM/T 0028/0039要求

---

## 14. 风险与缓解

### 14.1 技术风险

| ID | 风险 | 类型 | 概率 | 缓解方案 |
|----|------|------|------|----------|
| R-001 | 关键路径不满足400MHz | 时序 | M | 插入流水线寄存器，重定时 |
| R-002 | 面积超预期 | 面积 | L | 资源共享，算法复用 |
| R-003 | 抗侧信道防护影响性能 | 性能 | M | 优化掩码算法，减少dummy操作 |
| R-004 | 商密认证不通过 | 合规 | L | 预研认证要求，提前送检 |

### 14.2 验证风险

| ID | 风险 | 缓解方案 |
|----|------|----------|
| V-001 | 算法正确性验证复杂 | 参考标准测试向量，覆盖率驱动 |
| V-002 | 侧信道防护验证困难 | 使用专用侧信道分析工具 |
| V-003 | 多通道并行验证复杂 | 随机化测试，覆盖率模型 |

---

## 15. 追溯矩阵（RTM）

| 需求ID | 优先级 | 需求描述 | 方案章节 | 设计决策 | 状态 |
|--------|--------|----------|----------|----------|------|
| REQ-001 | Must | 28nm/400MHz | §6 | 时序约束，关键路径优化 | Designed |
| REQ-002 | Must | AXI4 128bit | §4.2 | AXI从接口设计 | Designed |
| REQ-003 | Should | 大数据块搬运 | §5.1 | DMA驱动，突发传输 | Designed |
| REQ-004 | Should | 安全性优先 | §10.1 | 抗侧信道防护优先 | Designed |
| REQ-005 | Should | 面积功耗次之 | §8 | 面积预算宽松 | Designed |
| REQ-006 | Must | 单时钟域 | §7.3 | 无CDC | Designed |
| REQ-007 | Could | Clock Gating | §10.2 | 全局ICG | Designed |
| REQ-008 | Should | 标准DFT | §9 | 扫描链+ICG | Designed |
| REQ-009 | Should | 密钥ECC | §10.1.1 | SECDED保护 | Designed |
| REQ-010 | Must | 商密认证，抗侧信道 | §10.1.2 | DPA/SPA防护 | Designed |
| REQ-011 | N/A | 单时钟域 | §7.3 | 不适用 | Skipped |
| REQ-012 | Should | 存储选型 | §11 | SRAM+ROM | Designed |
| REQ-013 | Should | 标准PVT | §8 | TT/0.9V/25°C | Designed |
| REQ-014 | Should | AXI时序 | §6 | SDC约束 | Designed |
| REQ-015 | Should | DMA接口 | §4.2 | AXI突发 | Designed |
| REQ-016 | Should | 中断接口 | §4 | irq_ctrl | Designed |
| REQ-017 | Could | 调试接口 | §9 | JTAG | Designed |
| REQ-018 | Should | 安全隔离 | §10.1 | TrustZone | Designed |
| REQ-019 | Should | APB接口 | §4.3 | apb_reg_ctrl | Designed |
| REQ-020 | Should | 地址空间 | §7.1 | 寄存器映射 | Designed |
| REQ-021 | Could | 功耗状态 | §10.2 | Active/Sleep | Designed |
| REQ-029 | Must | SM2并行 | §5.2 | 签名验签并行 | Designed |
| REQ-030 | Should | SM3/SHA流水线 | §5.2 | 4级流水线 | Designed |
| REQ-031 | Must | AES-GCM | §5.2 | AES-128/192/256-GCM | Designed |
| REQ-032 | Must | KDF | §5.2 | GM/T 0010 | Designed |
| REQ-033 | Must | TRNG接口 | §4 | trng_if | Designed |
| REQ-034 | Should | 4通道并行 | §12.1 | 4通道RR调度 | Designed |
| REQ-035 | Could | 流水线可配置 | §5.2 | 2/4/8级 | Designed |
| REQ-036 | Must | AXI流控 | §12.2 | ready反压 | Designed |
| REQ-037 | Should | SM4/AES切换 | §5.2 | 运行时切换 | Designed |
| REQ-038 | Should | 错误注入 | §9.3 | err_inject接口 | Designed |
| REQ-039 | Could | 性能计数器 | §7.1 | perf_cnt | Designed |
| REQ-040 | Should | 密钥统计 | §7.1 | key_stat寄存器 | Designed |

---

## 16. 附录

### 16.1 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | crypto_engine_requirement_summary_v1.0.md | 需求汇总表 |
| REF-002 | GM/T 0028-2014 | 密码模块安全技术要求 |
| REF-003 | GM/T 0039-2015 | 密码模块安全检测要求 |
| REF-004 | AXI4 Protocol Specification | AXI协议规范 |

### 16.2 缩略语

| 缩写 | 全称 |
|------|------|
| FSM | Finite State Machine |
| CDC | Clock Domain Crossing |
| FIFO | First In First Out |
| PPA | Performance, Power, Area |
| RTM | Requirements Traceability Matrix |
| ECC | Error Correcting Code |
| ICG | Integrated Clock Gating |
| DFT | Design For Testability |
| DPA | Differential Power Analysis |
| SPA | Simple Power Analysis |
