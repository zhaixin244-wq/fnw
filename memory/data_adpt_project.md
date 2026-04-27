---
name: data_adpt 项目全貌
description: data_adpt模块的功能、架构、需求和设计决策全景记录
type: project
---
## 模块定位

data_adpt 是一个数据转换模块，从前级读到链式描述符，封装成后级可识别的包格式输出。通过一组接口访问4组存储数据的RAM，从RAM读回的数据经过切片送给加密模块，待加密模块返回后，进行CRC计算后格式化输出。

**在SoC中的位置**：
- 上游：描述符管理模块（via data_in_if）
- 下游：包调度/队列管理模块（via data_out_if）
- 侧向RAM：4个外部存储通道（via ram_if）
- 侧向加密：加密模块（via encry_if）
- 配置：APB总线

## 核心需求（REQ-001~026）

**关键约束**：
- 工艺：TSMC 4nm / 1GHz
- 性能：24Mpps / 800Gbps，单通道可达800Gbps
- 延迟：只关心持续吞吐，延迟不做硬约束
- 接口：6组点对点自定义Valid-Ready + APB
- 描述符：3种格式（btype/ntype/flush），链式描述符最大257个
- PPA优先级：性能 > 面积 > 功耗

## 全链路数据通路（7阶段）

```
[1] 描述符接收 → [2] RAM读请求 → [3] RAM返回(~1.8us) → [3a] 挤气泡+切片 → [3b] 汇聚FIFO → [4] 加密(3cycle) → [5] 全局buffer → [6] 格式化输出
```

### 加密模块架构（关键瓶颈优化）
- 4通道共享1个加密模块，纯pipeline无状态，通道切换0开销
- encrypt_slice_size可配置（APB寄存器）
- 加密模块无反压
- **汇聚FIFO**：8深度×128B，解耦4通道交织写入与加密连续读出
- 4通道挤气泡buffer各4行×1024bit，切片后写入汇聚FIFO
- 4通道ram_if返回天然错开，无FIFO写端口竞争

### 输出侧架构
- **就绪FIFO**：48项按包就绪顺序出包，read/write统一排队
- **BD链与payload pipeline并行**：不同SRAM端口不冲突，允许包间输出重叠
- **包间零气泡**：多包pipeline预读 + BD/payload端口并行
- **SRAM端口全部独立**：描述符SRAM(8R)+包元信息SRAM(1R)+sqe/hdr SRAM(1R)+全局buffer(1R+W)

### 输出拼包规则

| 包类型 | 第1拍内容 | 后续拍 | buffer |
|--------|----------|--------|--------|
| btype read | hdr(16B)+BD | 剩余BD | 不走buffer |
| btype write | hdr(16B)+BD | BD→padding→payload | buffer |
| ntype read | sqe(64B)+BD | 剩余BD | 不走buffer |
| ntype write(path=0) | sqe(64B)+BD | 剩余BD | 不走buffer |
| ntype write(path=1) | sqe(64B) | payload | buffer |
| ntype data_mng | sqe(64B)+BD | BD→payload | buffer |
| flush | 单拍 | - | 不走buffer |

## SRAM结构（v1.10）

| SRAM | 位宽 | 深度 | 说明 |
|------|------|------|------|
| 描述符SRAM | 112bit×8 | 132行 | 4通道共享 |
| 包元信息SRAM | 93bit | 48 | 4通道共享 |
| sqe/hdr SRAM | 512bit | 48 | 4通道共享 |
| 全局buffer | 1038bit(含ECC) | 1800 | 按拍链式管理 |

## 寄存器组（v1.10）

| 寄存器组 | 位宽 | 深度 | 说明 |
|----------|------|------|------|
| done_status | 1bit | 48 | 同链所有ram读请求完成标记（替代fly_hdr+fly_payload） |
| 包buffer状态表 | 34bit | 48 | head_ptr+tail_ptr+beat_cnt+last_flag |
| 空闲行链表指针 | 11bit | 1800 | 头尾分离管理 |
| buffer行链表指针 | 11bit | 1800 | 包数据链next_ptr |

## APB寄存器（v1.10，完整）

| 偏移 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 0x00 | CTRL | RW | bit[0]全局使能, bit[1]加密使能, bit[3:2]encrypt_slice_size |
| 0x04 | INT_STATUS | W1C | 中断状态（32bit，每位一个中断源） |
| 0x08 | INT_MASK | RW | 中断屏蔽 |
| 0x0C | CREDIT_CFG | RW | 每通道credit数(拍)，4×8=32bit |
| 0x10 | ENCRYPT_CFG | RW | 加密使能+slice_size配置 |
| 0x14 | BP_STATUS | RO | 4通道反压状态 |
| 0x20~0x2C | WM_LINK[0..3] | RW | per-ramid链接水线阈值 |
| 0x30~0x3C | WM_BUF[0..3] | RW | per-ramid buffer水线阈值 |
| 0x40 | WM_ENC_FIFO | RW | 加密FIFO水线 |
| 0x44 | WM_DQID | RW | dqid水线 |
| 0x48~0x54 | DESC_SRAM_RANGE[0..3] | RW | per-ramid描述符SRAM起始+结束地址 |
| 0x100+0x4*N | SQINFO[N] | RW | 16384项sqinfo表（外部SRAM） |
| 0x200+0x4*N | DQINFO[N] | RW | 256项dqinfo表（外部SRAM） |

## 瓶颈分析结论

| 瓶颈 | 状态 | 优化方案 |
|------|------|---------|
| 加密4通道交织 | **已解决** | 汇聚FIFO(8×128B) |
| 加密零裕量 | **已解决** | pipeline无状态+汇聚FIFO连续供给 |
| 全局buffer块间气泡 | **已解决** | 按拍管理+预读pipeline |
| 包间切换气泡 | **已解决** | 多包预读+BD/payload并行 |
| 空闲行链表竞争 | **已解决** | 头尾分离 |
| SRAM端口冲突 | **已解决** | 全部独立端口 |
| btype payload串行延迟 | **已解决** | cycle0 bd_read_flag决策，hdr/payload并行读 |
| ram_if info冗余 | **已解决** | info 64bit→8bit |
| fly状态面积 | **已解决** | done_bit替代fly_hdr/fly_payload，96bit→48bit |

## 已解决关键问题清单

- 描述符SRAM位宽1024bit→112bit
- SRAM端口1R1W TP RAM
- bd_num位宽9bit（最大链长257）
- 输出时序6cycle首拍+1cycle/拍流水
- BD→payload零气泡（预读pipeline 3行）
- 加密pipeline无气泡
- flush按sqid独立排序
- btype/ntype互斥复用sqe/hdr SRAM
- fly状态用寄存器不用SRAM
- SRAM读写冲突W2优先W1反压
- 全局buffer按拍链式管理
- crc_en=0 padding对齐128B
- 加密模块前汇聚FIFO
- 输出就绪FIFO按序出包
- BD链与payload pipeline并行输出
- btype payload cycle0并行决策
- ram_if info 64bit→8bit
- done_bit替代fly_hdr/fly_payload（同链全序返回约束）

## RTL 实现状态（v1.2，2026-04-23）

### 已生成文件

| 文件 | 行数 | always块数 | 状态 |
|------|------|-----------|------|
| `data_adpt.v` | 599 | 6 | 顶层，实例化5子模块+sqinfo SRAM+free list+APB |
| `input_if_mod.v` | 374 | 12 | 入口控制，3状态FSM，6个语义always块 |
| `bd_cache_mod.v` | 159 | 1 | SRAM存储，实例化`sram_1r1w_tpram` CBB |
| `ram_if_mod.v` | 408 | 13 | RAM访问，4通道RR仲裁+credit+挤气泡+汇聚FIFO |
| `encry_if_mod.v` | 112 | 4 | 加密适配，3周期pipeline |
| `output_if_mod.v` | 484 | 16 | 输出控制，就绪FIFO+BD链+格式化 |

### RTL 自检状态

| 检查项 | 状态 |
|--------|------|
| IC-01~IC-13 编码规范 | 通过 |
| IC-36 always块行数≤30 | 通过（重构后） |
| IC-37 always块信号数<5 | 通过（重构后） |
| IC-04 case有default | 通过 |
| CBB复用（sram_1r1w_tpram） | 通过 |
| Verilator lint | 待执行 |
| SVA断言文件 | 待生成 |
| Testbench文件 | 待生成 |
| UA文档交叉验证(IC-V01~V06) | 待手动验证 |

### 关键架构决策（RTL实现）

- **always块拆分策略**：input_if_mod从1个115行→6个≤30行，按语义域（ctx_vld/pending、ctx数组、SRAM写、sqinfo控制、desc写、写指针）拆分
- **CBB复用**：bd_cache_mod实例化`sram_1r1w_tpram`，删除自建`sram_1r1w_tp.v`
- **sqinfo SRAM**：顶层data_adpt.v中用行为级模型（16384×297bit），非CBB
- **free list**：顶层data_adpt.v中用行为级模型（48节点链表）
- **done_bit**：顶层data_adpt.v中用寄存器组（48×1bit）
