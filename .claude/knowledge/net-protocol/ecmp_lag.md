# ECMP / LAG 负载均衡与链路聚合协议

> 面向数字 IC 设计架构师的参考文档
> 版本：v1.0 | 日期：2026-04-15

---

## 1. LAG (Link Aggregation Group)

### 1.1 协议概述

LAG 将多条物理以太网链路绑定为一条逻辑链路，实现：
- **带宽叠加**：N 条 25Gbps 链路 → 1 条逻辑 100Gbps 链路
- **链路冗余**：单条物理链路故障，流量自动切换到其余成员
- **负载分担**：流量按策略分布到各成员链路

标准演进：IEEE 802.3ad (2000) → IEEE 802.1AX-2008（独立标准）→ 802.1AX-2014/2020

核心概念：
- **聚合组 (Aggregation Group)**：一组绑定的物理端口
- **逻辑端口 (Logical Port)**：对外呈现的单一端口
- **成员端口 (Member Port)**：聚合组中的物理端口
- **Actor**：本端设备
- **Partner**：对端设备

### 1.2 LACP (Link Aggregation Control Protocol)

LACP 是 LAG 的控制平面协议，用于自动协商和维护聚合组。

#### LACPDU 报文格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Subtype=0x01 |  Version=0x01 |        TLV Type=0x01          | Actor Info
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Actor System Priority (2B)    |   Actor System ID / MAC (6B)   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Actor Key (2B)                | Actor Port Priority (2B)       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Actor Port (2B)               | Actor State (1B) | Reserved    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                             ...| Actor Info Length=0x14
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        TLV Type=0x02          | Partner System Priority (2B)   | Partner Info
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Partner System ID / MAC (6B)                                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Partner Key (2B)              | Partner Port Priority (2B)     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Partner Port (2B)             | Partner State (1B)| Reserved   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        TLV Type=0x03          | Collector Info (variable)      | Collector
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        TLV Type=0x00          |                               | Terminator
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

Actor/Partner State 字段（1B，各 bit 独立）：

| Bit | 名称 | 含义 |
|-----|------|------|
| [0] | LACP_Activity | 1=Active, 0=Passive |
| [1] | LACP_Timeout | 1=Short timeout, 0=Long timeout |
| [2] | Aggregation | 1=可聚合, 0=独立链路 |
| [3] | Synchronizing | 1=正在同步 |
| [4] | Collecting | 1=可接收帧 |
| [5] | Distributing | 1=可发送帧 |
| [6] | Defaulted | 1=使用默认 Partner 信息 |
| [7] | Expired | 1=Actor 信息已过期 |

#### Actor / Partner 系统优先级

- **System Priority** (2B)：数值越小优先级越高。用于决定聚合组的管理端
- **System ID** (6B)：通常是设备 MAC 地址
- **Port Priority** (2B)：数值越小优先级越高。决定端口在聚合组中的选择顺序
- **Key** (2B)：标识聚合组能力，相同 Key 的端口才能聚合

**协商规则**：Actor 端口的 Key 必须匹配 Partner 端口的 Key；Actor 的 System ID + Key 必须唯一对应一个聚合组。

#### Active / Passive 模式

| 模式 | 行为 |
|------|------|
| **Active** | 主动发送 LACPDU，无论是否收到对端 LACPDU |
| **Passive** | 仅在收到对端 LACPDU 后才响应发送 |

推荐配置：两端至少一端为 Active。两端均为 Passive 时无法建立聚合。

#### 聚合组状态协商

```
               Active LACPDU          Active LACPDU
    Actor ------------------> Partner ------------------> Actor
    (LACP_Active=1)           (LACP_Active=1)

    协商状态机：
    1. 端口 UP → 发送/接收 LACPDU
    2. Actor 和 Partner 信息匹配 → 进入 Attached 状态
    3. 双方 Synchronizing=1 → 进入 Synchronized 状态
    4. 双方 Collecting=1 && Distributing=1 → 端口可收发数据
    5. LACPDU 超时未收到 → 回到 Unselected 状态
```

| 状态 | 条件 | 行为 |
|------|------|------|
| Unselected | LACPDU 未匹配/超时 | 端口不参与流量转发 |
| Selected | Actor/Partner 信息匹配 | 端口准备加入聚合组 |
| Standby | 匹配但聚合组端口数达上限 | 等待成为成员 |
| Active (in sync) | Collecting=1, Distributing=1 | 正常转发 |

超时机制：
- **Short Timeout**：3 秒（LACP_Timeout=1），适用于快速故障检测
- **Long Timeout**：90 秒（LACP_Timeout=0），适用于稳定性优先场景

### 1.3 静态 LAG

手动配置，无需 LACP 协商：
- 管理员手动将端口加入聚合组
- 无 LACPDU 交互，无自动故障检测
- 优点：配置简单，无协议开销
- 缺点：无法检测单向链路故障（如对端端口 DOWN 但本端 UP）
- 典型场景：与不支持 LACP 的设备互联

### 1.4 负载均衡策略

| 策略 | Hash 输入字段 | 典型场景 |
|------|--------------|---------|
| Src MAC | 源 MAC 地址 | 接入层 |
| Dst MAC | 目的 MAC 地址 | 接入层 |
| Src-Dst MAC | 源 MAC + 目的 MAC | 接入/汇聚层 |
| Src IP | 源 IP 地址 | L3 交换 |
| Dst IP | 目的 IP 地址 | L3 交换 |
| Src-Dst IP | 源 IP + 目的 IP | L3 交换（最常用） |
| L4 Port | TCP/UDP 源端口 + 目的端口 | 高粒度分流 |
| 5-Tuple | Src IP + Dst IP + Src Port + Dst Port + Protocol | 最精细分流 |

### 1.5 LAG 帧分发

```
                        ┌──────────────┐
  Incoming Frame ──────>│ Hash Engine  │
                        │              │
                        │ Hash(input)  │
                        │ mod N        │
                        └──────┬───────┘
                               │ hash_result (0 ~ N-1)
                               ▼
                        ┌──────────────┐
                        │ Member Port  │
                        │   Selector   │
                        │              │
                        └──┬───┬───┬───┘
                           │   │   │
              ┌────────────┘   │   └────────────┐
              ▼                ▼                 ▼
         ┌─────────┐     ┌─────────┐       ┌─────────┐
         │ Port 0  │     │ Port 1  │  ...  │ Port N-1│
         │ (25G)   │     │ (25G)   │       │ (25G)   │
         └─────────┘     └─────────┘       └─────────┘

  同一条流（相同 hash 值）始终从同一端口发出
  保证帧顺序（同一 session 无乱序）
```

---

## 2. ECMP (Equal-Cost Multi-Path)

### 2.1 协议概述

ECMP 是 IP 路由层面的负载均衡机制：当路由表中存在多个到达同一目的前缀的等价下一跳（相同 metric/cost）时，按流哈希选择下一跳。

核心特性：
- **等价路径**：所有下一跳的路由 cost 相同
- **按流分担**：同一数据流的包走同一路径，保证无序
- **最大支持 256 路**（RFC 2992），典型实现 16~64 路
- **与路由协议配合**：OSPF/IS-IS/BGP 自动发现等价路径

ECMP 与 LAG 的关系：
- ECMP = 路由层负载均衡（跨设备，IP 下一跳选择）
- LAG = 链路层负载均衡（单设备，物理端口选择）
- 两者可叠加使用：ECMP 选下一跳设备，LAG 选该设备的出口链路

### 2.2 ECMP 哈希算法

#### 输入字段选择

| 策略 | Hash 输入 | 颗粒度 | 适用场景 |
|------|----------|--------|---------|
| 2-Tuple | Src IP + Dst IP | 粗 | 简单分流、L3 转发 |
| 3-Tuple | Src IP + Dst IP + Protocol | 中 | 区分 TCP/UDP |
| 5-Tuple | Src IP + Dst IP + Src Port + Dst Port + Protocol | 细 | 数据中心、精细化分流 |
| Inner 5-Tuple | VXLAN/GRE inner header 的 5-tuple | 极细 | Overlay 网络 |

特殊处理：
- **TCP/UDP 无端口号**（如 ICMP）：使用 2/3-Tuple
- **SYN/FIN 包**：可降级为 3-Tuple 保证同流一致
- **隧道封装**：可选择 outer 或 inner header 哈希

#### 哈希函数对比

| 算法 | 均匀性 | 硬件复杂度 | 速度 | 备注 |
|------|--------|-----------|------|------|
| CRC-32 | 优 | 中 | 高 | 广泛使用，需查表或迭代电路 |
| CRC-32c (Castagnoli) | 优 | 中 | 高 | SSE4.2 指令集加速 |
| Toeplitz Hash | 优 | 高（需预置 key） | 中 | Microsoft RSS 标准 |
| XOR | 差 | 极低 | 极高 | 仅适用于极少路径数 |
| xxHash | 优 | 中 | 高 | 软件定义网络常用 |
| Jenkins Hash | 良 | 中 | 中 | 老式路由器使用 |
| CRC-8 / CRC-16 | 中 | 低 | 高 | 嵌入式/低资源场景 |

**推荐**：数据中心交换芯片使用 CRC-32 或 Toeplitz Hash；嵌入式场景使用 CRC-8/16 平衡面积与均匀性。

### 2.3 ECMP 组表格式

```
ECMP Group Table:
┌─────────────────────────────────────────────┐
│ ECMP Group ID = 0                           │
│ Next-Hop Count (N) = 4                      │
│ Next-Hop[0]: NH_A (10.0.1.1, port A)       │
│ Next-Hop[1]: NH_B (10.0.1.2, port B)       │
│ Next-Hop[2]: NH_C (10.0.1.3, port C)       │
│ Next-Hop[3]: NH_D (10.0.1.4, port D)       │
│ Hash Function: CRC-32                       │
│ Hash Input: 5-Tuple                         │
└─────────────────────────────────────────────┘

选择算法：
  hash_value = CRC32(src_ip, dst_ip, src_port, dst_port, protocol)
  nh_index   = hash_value mod N
  next_hop   = Next-Hop[nh_index]
```

硬件实现流程：

```
  Packet Header ──> [5-Tuple Extract] ──> [Hash Engine] ──> [ECMP Table Lookup]
                                                                    │
                                                                    ▼
  Nexthop Info <── [Nexthop Table] <── Nexthop Index = hash mod N
```

### 2.4 ECMP 流量分布分析

#### Hash 冲突与不均衡

理想情况下，N 个路径各承担 1/N 流量。实际受限于：
- **流数量有限**：流数远小于 hash 空间时，分布不均匀
- **Hash 冲突**：不同流映射到同一路径
- **流大小差异**：大象流和老鼠流混杂，按流数均衡不等于按流量均衡

不均衡度量：

```
                    max(link_load) - avg(link_load)
  Imbalance Ratio = ─────────────────────────────────
                            avg(link_load)

  理想值 = 0%（完全均衡）
  实践中 5%~15% 可接受
  > 20% 需要优化 hash 算法或增加 entropy
```

#### 流量极化 (Polarization)

多跳 ECMP 路径中，使用相同 hash 算法会导致流量汇聚到同一路径：

```
  Hop 1:  Flow_A hash → Path 1 ──────────>
  Hop 2:  Flow_A hash → Path 1 ──────────>  （重复选择）
  Hop 3:  Flow_A hash → Path 1 ──────────>  （极化）

  解决方案：
  - 每跳使用不同的 hash seed
  - 使用 flow label (IPv6) 增加 entropy
  - 在隧道封装中插入 entropy field
```

### 2.5 Consistent Hashing (一致性哈希)

传统 ECMP 问题：增加/减少一个下一跳时，hash_value mod N 变化导致大量流重新映射（约 50%~80% 的流受影响）。

一致性哈希保证：增减节点时，仅有约 1/N 的流需要重新映射。

```
  传统哈希 (mod N):
    N=4 → N=5: 约 75% 的流重映射

  一致性哈希:
    N=4 → N=5: 约 20% 的流重映射

  实现方式：
  1. 虚拟节点：每个物理节点映射到 hash ring 上多个虚拟点
  2. Bounded-Load：限制每个节点的最大负载偏差
  3. Maglev Hash：Google 提出，预计算 lookup table
```

**Maglev Hashing**（Google，2016）：

```
  输入：N 个节点，M 个 bucket（M 为质数，典型 65537）
  输出：大小为 M 的 lookup table

  对每个节点 j，生成长度为 M 的 permutation 数组
  轮流填充 bucket table，直到所有 bucket 满

  查表：hash_value = Hash(flow) mod M → bucket → 节点

  增减节点：仅重计算受影响的 bucket，约 1/N 变化
```

**对 IC 设计的意义**：一致性哈希需要更大的查找表（SRAM），但可显著减少路由变化时的流量抖动，适用于 SDN/可编程交换芯片。

### 2.6 WCMP (Weighted Cost Multi-Path)

WCMP 允许不同下一跳具有不同权重，适用于路径带宽不等或链路质量差异的场景。

```
  Next-Hop A: weight = 3  →  承载 3/(3+2+1) = 50% 流量
  Next-Hop B: weight = 2  →  承载 2/(3+2+1) = 33% 流量
  Next-Hop C: weight = 1  →  承载 1/(3+2+1) = 17% 流量

  实现方式：
  1. 虚拟节点法：将 NH_A 复制 3 份放入 ECMP 组，NH_B 复制 2 份
     ECMP 组: [A, A, A, B, B, C] → hash mod 6
  2. 加权取模法：hash_value 与累积权重表比较
  3. 流表级：OpenFlow group_select 类型直接支持 weight
```

### 2.7 Adaptive ECMP

基于实时链路利用率动态调整 ECMP 路径选择。

```
  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
  │ Hash-Based   │    │ Utilization  │    │ Weight       │
  │ ECMP Select  │◄───│ Monitor      │───>│ Adjustment   │
  │              │    │              │    │              │
  └──────────────┘    └──────────────┘    └──────────────┘
         │                                       │
         └─────────── 调整 hash 权重 ◄────────────┘

  监控指标：
  - 链路带宽利用率（端口计数器 / 时间窗口）
  - 队列深度（丢包/ECN 标记）
  - 延迟（通过 PTP/INT 测量）

  调整方式：
  - 拥塞链路降权 → 新流优先选低负载路径
  - 利用 PFC pause frame 触发的背压信号
  - 注意：已有流保持路径不变（避免乱序）
```

---

## 3. 设计注意事项（交换芯片实现）

### 3.1 哈希引擎设计

#### 5-Tuple 提取

```verilog
// 从 packet header 中提取 5-tuple
wire [31:0] src_ip   = ipv4_header[127:96];
wire [31:0] dst_ip   = ipv4_header[95:64];
wire [15:0] src_port = tcp_header[31:16];
wire [15:0] dst_port = tcp_header[15:0];
wire [7:0]  protocol = ipv4_header[79:72];

// Hash 输入拼接（304 bit 宽，含 padding）
wire [HASH_INPUT_WIDTH-1:0] hash_input = {
    src_ip, dst_ip, protocol,
    src_port, dst_port,
    {padding}
};
```

隧道场景（VXLAN/GRE）：需解析 inner header，提取内层 5-tuple 作为 hash 输入。解析逻辑需要额外 2~4 级流水线。

#### 并行 CRC

```verilog
// CRC-32 并行计算（组合逻辑，无迭代）
// 输入 8-bit，输出 32-bit，单周期完成
function [31:0] crc32_parallel;
    input [7:0]  data;
    input [31:0] crc_in;
    // 多项式: 0x04C11DB7 (normal) / 0xEDB88320 (reversed)
    reg [31:0] c;
    begin
        c = crc_in ^ {24'b0, data};
        crc32_parallel = {
            c[30]^c[26]^c[25]^c[24]^c[23]^c[22]^c[20]^c[18]^c[15]^c[13]^c[12]^c[11]^c[10]^c[9]^c[8]^c[6]^c[5]^c[4]^c[2]^c[0],
            // ... 完整展开（略）
        };
    end
endfunction

// 多字节并行：一次处理 32-bit / 64-bit / 128-bit
// 通过预计算多项式矩阵展开
```

硬件架构选择：

| 架构 | 处理位宽 | 延迟 | 面积 | 适用 |
|------|---------|------|------|------|
| 串行 CRC | 8-bit/cycle | 多周期 | 极小 | 低吞吐嵌入式 |
| 并行 CRC-32 | 32-bit/cycle | 1 周期 | 中 | 常规交换 |
| 并行 CRC-64 | 64-bit/cycle | 1 周期 | 较大 | 高速交换 |
| 并行 CRC-128 | 128-bit/cycle | 1 周期 | 大 | 400G+ 交换 |

#### Toeplitz Hash

```verilog
// Toeplitz Hash（Microsoft RSS 标准）
// 使用预置的 320-bit key（40 bytes）
// 对每个输入 bit 与 key 进行 XOR-reduce

function [31:0] toeplitz_hash;
    input [HASH_INPUT_WIDTH-1:0] data;
    input [HASH_INPUT_WIDTH+31:0] key;  // 预置 key
    integer i;
    reg [31:0] result;
    begin
        result = 32'b0;
        for (i = 0; i < HASH_INPUT_WIDTH; i = i + 1) begin
            if (data[i])
                result = result ^ key[i+31:i];
        end
        toeplitz_hash = result;
    end
endfunction

// 硬件优化：展开为 32 个并行 XOR tree
// 每个输出 bit 独立计算
```

### 3.2 ECMP 组表存储

```
  Route Table (TCAM/SRAM)
    ├── Prefix Match → ECMP Group ID
    │
    ▼
  ECMP Group Table (SRAM)
    ├── Group 0: NH_count=4, NH[0]=0x100, NH[1]=0x200, ...
    ├── Group 1: NH_count=8, NH[0]=0x300, NH[1]=0x400, ...
    └── Group K: ...
    │
    ▼
  Nexthop Table (SRAM)
    ├── NH[0x100]: DIP=10.0.1.1, DMAC=xx:xx:xx, Egress=Port3
    ├── NH[0x200]: DIP=10.0.2.1, DMAC=yy:yy:yy, Egress=Port7
    └── ...
```

存储容量规划：

| 表项 | 典型条目数 | 每条目宽度 | 存储类型 |
|------|-----------|-----------|---------|
| ECMP Group Table | 4K~16K | 16+64×N bit | SRAM |
| Nexthop Table | 64K~256K | 128~256 bit | SRAM |
| Hash Seed Table | 1~8 | 320 bit | 寄存器 |

### 3.3 LAG 成员端口表

```
  LAG Member Port Table (per aggregation group):
  ┌────────────────────────────────────────────┐
  │ Group ID: 0                                │
  │ Member Count: 4                            │
  │ Port Bitmap: {Port0, Port2, Port5, Port7} │
  │ Hash Function: CRC-32, input=Src-Dst MAC   │
  │ Failover: Port2 -> Port8 (backup)          │
  └────────────────────────────────────────────┘
```

### 3.4 Hash 均衡性验证

验证指标和方法：

| 指标 | 公式 | 目标 |
|------|------|------|
| 负载不均衡比 | (max - avg) / avg | < 10% |
| Hash 冲突率 | 同桶流数 / 总流数 | < 2× 理想值 |
| 流分布标准差 | stddev(各桶流数) | 越小越好 |

测试方法：
1. **仿真测试**：使用真实流量 trace（如 CAIDA），统计各端口流数
2. **Chi-Square 检验**：验证 hash 分布是否近似均匀分布
3. **扫描测试**：遍历所有 5-tuple 组合，检查桶占用分布
4. **大象流测试**：高流量流混合测试，观察是否出现单端口饱和

### 3.5 流量极化与 Entropy 增加

问题：多跳网络中相同 hash 算法导致流量汇聚。

解决方案（IC 实现角度）：

| 方案 | 实现方式 | 复杂度 |
|------|---------|--------|
| 每级不同 hash seed | ECMP 级配置不同 Toeplitz key | 低 |
| IPv6 Flow Label | 利用 IPv6 header 中 20-bit flow label | 低 |
| VXLAN Entropy | 在 VXLAN reserved field 插入 hash 值 | 中 |
| MPLS Entropy Label | 插入 MPLS entropy label (RFC 6790) | 中 |
| 带内遥测 (INT) | INT header 中携带流标识 | 高 |

### 3.6 与 PFC/ECN 的配合

- **PFC (Priority-based Flow Control)**：当链路拥塞时 PFC pause 可导致 ECMP 路径不可用。设计时需考虑 pause 状态下的路径降权
- **ECN (Explicit Congestion Notification)**：ECMP 可利用 ECN 标记作为 adaptive 调整的信号，将拥塞路径的流量重分布
- **配合策略**：ECMP hash 选择时，排除 PFC pause 状态的端口；收到 ECN 标记的流优先考虑切换路径

### 3.7 统计计数器

每个 ECMP 组 / LAG 组需维护的计数器：

| 计数器 | 位宽 | 说明 |
|--------|------|------|
| Tx Byte Count | 64-bit | 各成员端口发送字节数 |
| Tx Packet Count | 64-bit | 各成员端口发送包数 |
| Rx Byte Count | 64-bit | 各成员端口接收字节数 |
| Rx Packet Count | 64-bit | 各成员端口接收包数 |
| Drop Count | 32-bit | 聚合组丢包数 |
| Hash Collision Count | 32-bit | 冲突到同一端口的流数（可选） |
| Member Status Bitmap | N-bit | 各成员端口 UP/DOWN 状态 |

---

## 4. 对比表

### 4.1 LAG vs ECMP

| 对比项 | LAG | ECMP |
|--------|-----|------|
| **网络层级** | L2 链路层 | L3 路由层 |
| **范围** | 单设备，端口绑定 | 跨设备，路由下一跳 |
| **标准** | IEEE 802.1AX | RFC 2991/2992 + IGP |
| **控制协议** | LACP (可选) | OSPF/IS-IS/BGP |
| **负载粒度** | 帧 (Frame) | 包 (Packet) / 流 (Flow) |
| **Hash 输入** | MAC / IP / L4 | IP / L4 5-tuple |
| **最大路径** | 8~32 (典型) | 16~256 (RFC 限制) |
| **故障切换** | LACP 超时 + 成员剔除 | 路由收敛 (秒级/毫秒级) |
| **乱序风险** | 低（单跳） | 低（按流），高（per-packet） |
| **典型应用** | 服务器到 ToR 交换机 | 数据中心 Fabric 内部 |
| **叠加关系** | 可与 ECMP 叠加 | 可与 LAG 叠加 |

### 4.2 Hash 算法对比

| 算法 | 均匀性 | 速度 (Gbps 吞吐) | 硬件面积 (kGE) | 可配置性 | 推荐场景 |
|------|--------|-----------------|---------------|---------|---------|
| XOR | 差 | >1000 | <1 | 无 | 极简 2 路分流 |
| CRC-8 | 中 | >800 | <2 | 低 | 嵌入式低资源 |
| CRC-16 | 中 | >800 | ~3 | 低 | 嵌入式中等 |
| CRC-32 | 优 | >400 | ~8 | 中 | **通用推荐** |
| CRC-32c | 优 | >400 | ~8 | 中 | 与软件 RSS 兼容 |
| Toeplitz | 优 | >200 | ~15 | 高（可配置 key） | **Windows RSS 互操作** |
| xxHash-32 | 优 | >300 | ~12 | 中 | SDN / 可编程交换 |
| xxHash-64 | 优 | >200 | ~20 | 中 | 64-bit hash 空间 |
| Jenkins | 良 | >300 | ~6 | 低 | 老式路由器 |

> 面积估算基于 ASIC 综合，kGE = 千等效 NAND2 门。

---

## 5. 附录：缩略语

| 缩写 | 全称 |
|------|------|
| ECMP | Equal-Cost Multi-Path |
| LAG | Link Aggregation Group |
| LACP | Link Aggregation Control Protocol |
| LACPDU | LACP Data Unit |
| RSS | Receive-Side Scaling |
| WCMP | Weighted Cost Multi-Path |
| INT | In-band Network Telemetry |
| PFC | Priority-based Flow Control |
| ECN | Explicit Congestion Notification |
| TCAM | Ternary Content-Addressable Memory |
| ToR | Top of Rack |
| GE | Gate Equivalent |
| kGE | kilo Gate Equivalent |
