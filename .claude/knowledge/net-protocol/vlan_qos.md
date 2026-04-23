# VLAN / QoS 协议知识文档

> **面向**：数字 IC 设计架构师
> **范围**：IEEE 802.1Q VLAN、802.1ad QinQ、802.1Qbb PFC、802.1Qaz ETS、DiffServ QoS
> **用途**：交换芯片 QoS 数据通路架构设计参考

---

## 1. VLAN (IEEE 802.1Q)

### 1.1 协议概述

VLAN (Virtual Local Area Network) 在 Layer 2 以太网帧中插入 4 字节 VLAN Tag，将物理网络划分为多个逻辑广播域。交换机依据 VID 转发，不同 VLAN 流量隔离。

### 1.2 VLAN Tag 格式

```
         16 bit              16 bit
 +-------------------+--------------------+
 |      TPID         |        TCI         |
 | (Tag Protocol ID) | (Tag Control Info) |
 +-------------------+--------------------+

                        TCI 展开：
         3 bit       1 bit      12 bit
    +-------------+---------+-------------+
    |    PCP      |   DEI   |    VID      |
    | (Priority)  | (Drop)  | (VLAN ID)   |
    +-------------+---------+-------------+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| **TPID** | 16 bit | Tag Protocol Identifier，标识帧携带 VLAN Tag |
| **PCP** | 3 bit | Priority Code Point，CoS 优先级 0-7 |
| **DEI** | 1 bit | Drop Eligible Indicator，拥塞时可丢弃标记 |
| **VID** | 12 bit | VLAN Identifier，0-4095 |

### 1.3 TPID 值

| TPID 值 | 标准 | 说明 |
|---------|------|------|
| `0x8100` | IEEE 802.1Q | 标准 VLAN Tag |
| `0x88A8` | IEEE 802.1ad | QinQ 外层 Tag (Service Tag) |
| `0x9100` | 厂商私有 | 部分厂商 QinQ 实现 |
| `0x9200` | 厂商私有 | 部分厂商 QinQ 实现 |

**IC 设计要点**：解析逻辑需匹配 TPID 判断是否携带 VLAN Tag，QinQ 场景需支持双层 TPID 匹配。

### 1.4 PCP (Priority Code Point)

3 bit 字段，定义 8 个优先级，对应 CoS (Class of Service)：

| PCP | 优先级 | 典型用途 | DiffServ 等效 |
|-----|--------|---------|---------------|
| 0 (000) | Best Effort | 普通数据 | BE (CS0) |
| 1 (001) | Background | 备份流量 | CS1 |
| 2 (010) | Excellent Effort | 重要业务数据 | AF23 |
| 3 (011) | Critical Applications | 信令、数据库 | AF31 |
| 4 (100) | Video | 视频会议、流媒体 | AF41 |
| 5 (101) | Voice | VoIP | EF |
| 6 (110) | Internetwork Control | 路由协议 | CS6 |
| 7 (111) | Network Control | STP、LLDP | CS7 |

### 1.5 DEI (Drop Eligible Indicator)

- 值为 1 表示该帧在拥塞时可优先丢弃
- 替代了原 802.1Q-1998 中的 CFI (Canonical Format Indicator)
- 与令牌桶 (Token Bucket) 配合：超限流量设置 DEI=1

### 1.6 VID (VLAN ID)

| VID | 说明 |
|-----|------|
| 0 | 优先级帧 (Priority Tagged)，不携带 VLAN 信息，仅使用 PCP |
| 1 | 默认 VLAN (PVID)，端口默认 VLAN |
| 2-4094 | 可用 VLAN ID |
| 4095 | 保留 (Reserved) |

### 1.7 VLAN 帧格式对比

**不带 Tag 的标准以太网帧**：
```
+----------+----------+--------+----------+-----+
| Dst MAC  | Src MAC  | EtherType | Payload | FCS |
|  6 Byte  |  6 Byte  |  2 Byte   | 46-1500 |  4  |
+----------+----------+-----------+---------+-----+
```

**带 VLAN Tag 的以太网帧**：
```
+----------+----------+------+--------+----------+-----+
| Dst MAC  | Src MAC  | TPID |  TCI   | EtherType| FCS |
|  6 Byte  |  6 Byte  | 2B   |  2B    |  2 Byte  |  4  |
+----------+----------+------+--------+----------+-----+
                         ^^^^^^^^^^^^
                         4 Byte VLAN Tag (插入在 Src MAC 之后)
```

**IC 设计要点**：Tag 插入使帧长增加 4 字节，需支持 Baby Giant (1518+4=1522 Byte)，超长帧可能触发 Jumbo Frame 处理。

### 1.8 QinQ (IEEE 802.1ad)

双层 VLAN Tag，用于运营商网络中透传客户 VLAN。

```
+----------+----------+----------+------+----------+------+----------+-----+
| Dst MAC  | Src MAC  | Outer TPID | Outer TCI | Inner TPID | Inner TCI | Type | FCS |
|  6 Byte  |  6 Byte  |  2B(0x88A8)|  2B       |  2B(0x8100)|  2B       |  2B  |  4  |
+----------+----------+------------+-----------+------------+-----------+------+-----+
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                          8 Byte 双层 VLAN Tag
```

| 层级 | TPID | VID 范围 | 用途 |
|------|------|---------|------|
| 外层 (S-TAG) | `0x88A8` | 运营商分配 | 运营商网络转发 |
| 内层 (C-TAG) | `0x8100` | 客户分配 | 客户 VLAN 透传 |

**IC 设计要点**：解析需支持单层/双层 Tag 识别，转发引擎需区分 S-VID 和 C-VID，QinQ 帧最大长度 1526 Byte。

### 1.9 端口模式

| 模式 | 收帧处理 | 发帧处理 | 典型场景 |
|------|---------|---------|---------|
| **Access** | 无 Tag → 加 PVID；有 Tag → 仅接受 PVID | 剥除 Tag 发送 | 连接终端 PC |
| **Trunk** | 无 Tag → 加 PVID；有 Tag → 检查 VID 白名单 | 保留 Tag 发送 | 交换机互联 |
| **Hybrid** | 无 Tag → 加 PVID；有 Tag → 检查 VID 白名单 | 可配置每个 VID 是否剥 Tag | 混合场景 |

---

## 2. QoS (Quality of Service)

### 2.1 QoS 概述

QoS 保证网络服务质量，核心指标：

| 指标 | 说明 | 典型要求 |
|------|------|---------|
| 带宽 (Bandwidth) | 可用吞吐量 | VoIP: 100 kbps; Video: 5 Mbps |
| 延迟 (Latency) | 端到端传播时间 | VoIP: < 150 ms; Video: < 200 ms |
| 抖动 (Jitter) | 延迟变化 | VoIP: < 30 ms |
| 丢包率 (Packet Loss) | 丢失帧比例 | VoIP: < 1%; Data: < 0.1% |

### 2.2 DiffServ 模型

DSCP (Differentiated Services Code Point) 位于 IP 头部 ToS 字段的高 6 bit。

```
IP Header ToS 字段 (1 Byte):
  7   6   5   4   3   2   1   0
 +---+---+---+---+---+---+---+---+
 |   DSCP (6 bit)    |ECN (2 bit)|
 +---+---+---+---+---+---+---+---+
```

**PHB (Per-Hop Behavior) 分类**：

| PHB | DSCP (十进制) | DSCP (二进制) | 用途 |
|-----|-------------|-------------|------|
| CS7 | 56 | 111000 | 网络控制 |
| CS6 | 48 | 110000 | 网间控制 |
| EF | 46 | 101110 | 加速转发 (VoIP) |
| AF41 | 34 | 100010 | 确保转发 4, 丢弃优先级 1 (视频) |
| AF42 | 36 | 100100 | 确保转发 4, 丢弃优先级 2 |
| AF43 | 38 | 100110 | 确保转发 4, 丢弃优先级 3 |
| AF31 | 26 | 011010 | 确保转发 3, 丢弃优先级 1 |
| AF32 | 28 | 011100 | 确保转发 3, 丢弃优先级 2 |
| AF33 | 30 | 011110 | 确保转发 3, 丢弃优先级 3 |
| AF21 | 18 | 010010 | 确保转发 2 |
| AF22 | 20 | 010100 | 确保转发 2 |
| AF23 | 22 | 010110 | 确保转发 2 |
| AF11 | 10 | 001010 | 确保转发 1 |
| CS1 | 8 | 001000 | Background |
| BE (CS0) | 0 | 000000 | 尽力而为 |

### 2.3 DSCP 到 802.1Q PCP 映射

| DSCP 范围 | PHB | PCP | CoS 队列 |
|-----------|-----|-----|---------|
| 56-63 | CS6/CS7 | 6/7 | 6/7 (控制) |
| 46 | EF | 5 | 5 (语音) |
| 34-38 | AF4x | 4 | 4 (视频) |
| 26-30 | AF3x | 3 | 3 (关键应用) |
| 18-22 | AF2x | 2 | 2 (优质数据) |
| 8-14 | CS1/AF1x | 1 | 1 (背景) |
| 0 | BE | 0 | 0 (尽力而为) |

**IC 设计要点**：需维护一张 DSCP-to-PCP 映射表 (LUT)，8 entry x 3 bit = 24 bit 存储，可软件配置。

### 2.4 流量整形 vs 流量监管

| 特性 | 流量整形 (Shaping) | 流量监管 (Policing) |
|------|-------------------|-------------------|
| 实现方式 | 缓冲 + 平滑发送 | 令牌桶 + 即时丢弃/重标记 |
| 超限处理 | 入队缓冲，延迟发送 | 丢弃或重标记 (DEI/RED) |
| 缓冲需求 | 需要缓冲区 (FIFO) | 不需要额外缓冲 |
| 延迟影响 | 增加延迟 | 不增加延迟 |
| 丢包 | 不丢包（缓冲未满时） | 可能丢包 |
| 位置 | 通常在 Egress | 通常在 Ingress |
| 实现复杂度 | 较高（需队列配合） | 较低（令牌桶即可） |

**令牌桶 (Token Bucket) 参数**：
- CIR (Committed Information Rate)：承诺信息速率，bps
- CBS (Committed Burst Size)：承诺突发大小，Bytes
- EIR (Excess Information Rate)：超额信息速率（双速率三色标记）
- EBS (Excess Burst Size)：超额突发大小

### 2.5 队列调度策略

| 策略 | 全称 | 原理 | 优点 | 缺点 | 适用场景 |
|------|------|------|------|------|---------|
| **SP** | Strict Priority | 高优先级队列严格优先 | 低延迟保证 | 低优先级饿死 | 控制面流量 |
| **WRR** | Weighted Round Robin | 按权重轮询 | 带宽保证 | 不精确（按包） | 普通数据 |
| **DWRR** | Deficit WRR | 按字节权重轮询 | 带宽精确分配 | 实现复杂 | 通用数据面 |
| **WFQ** | Weighted Fair Queue | 基于流的公平调度 | 公平性好 | 复杂度高 | 核心路由器 |
| **SP+WRR** | 混合 | 高队列 SP + 低队列 WRR | 兼顾延迟和带宽 | 配置复杂 | 交换芯片常用 |

**IC 设计要点**：交换芯片常用 SP+DWRR 混合调度，高优先级队列 (VoIP/Control) 使用 SP，数据队列使用 DWRR 保证带宽比例。

### 2.6 拥塞管理

| 机制 | 原理 | 优点 | 缺点 |
|------|------|------|------|
| **尾丢弃 (Tail Drop)** | 队列满后丢弃所有新入帧 | 实现简单 | 全局同步、TCP 吞吐震荡 |
| **WRED** (Weighted RED) | 基于队列深度概率丢弃 | 避免全局同步 | 参数调优复杂 |
| **ECN** (Explicit Congestion Notification) | 标记而非丢弃，通知端点降速 | 零丢包 | 需端点支持 ECN |

**WRED 丢弃概率曲线**：
```
丢弃
概率
100%|                          _______________
    |                        /
    |                      /
    |                    /
  0%|__________________/
    +-----------------+-----------------+--- 队列深度
                  min_thresh       max_thresh
```

### 2.7 PFC (IEEE 802.1Qbb)

Priority-based Flow Control，逐优先级 Pause，8 个 CoS 队列独立反压。

**Pause 帧格式**（以太网 Type = `0x8808`）：

```
+----------+----------+--------+----------+----------+-----+
| Dst MAC  | Src MAC  | Type   | Opcode   | Class-En | FCS |
| 01-80-C2 | (any)    | 0x8808 | 0x0101   | Vector   |  4  |
| -00-01-  |          |        | (Pause)  | + Timers |     |
|  00-00   |          |        |          |          |     |
+----------+----------+--------+----------+----------+-----+
```

**PFC Class Enable Vector** (2 Byte)：每个 bit 对应一个 CoS 队列

| Bit | CoS 队列 | 说明 |
|-----|---------|------|
| 0 | Queue 0 | BE 流量 |
| 1 | Queue 1 | Background |
| ... | ... | ... |
| 5 | Queue 5 | VoIP |
| 7 | Queue 7 | 网络控制 |

**PFC Timer**：每个使能的 CoS 对应一个 2 Byte 暂停时间 (以 512 bit-time 为单位)，`0xFFFF` 表示永久暂停。

**IC 设计要点**：
- 接收 Pause：解析 PFC 帧，对应 CoS 队列停止发送
- 发送 Pause：本端队列到达阈值，生成 PFC 帧通知上游
- 8 个 CoS 需要 8 套独立的反压逻辑
- Pause 帧处理优先级高于数据帧

### 2.8 ETS (IEEE 802.1Qaz)

Enhanced Transmission Selection，带宽分配调度，DCB (Data Center Bridging) 核心组件之一。

**核心概念**：
- 将 8 个 TC (Traffic Class) 分组为 TC Group
- 同一 TC Group 内使用 DWRR 按权重分配带宽
- TC Group 之间可配置为 SP 或 DWRR

**ETS 带宽分配示例**：

| TC Group | TC | 带宽比例 | 调度方式 |
|----------|-----|---------|---------|
| Group 0 | TC 6-7 | 0% (SP) | Strict Priority |
| Group 1 | TC 4-5 | 50% | DWRR |
| Group 2 | TC 0-3 | 50% | DWRR |

**DCB 协商**：通过 DCBX (Data Center Bridging Exchange) 协议 LLDP TLV 交换 ETS 配置。

---

## 3. 交换芯片 QoS 数据通路

```
 Ingress Port
      |
      v
 +------------------+
 |  Classification   |  DSCP/PCP/五元组 → Traffic Class
 |  (分类器)         |
 +------------------+
      |
      v
 +------------------+
 |  Metering        |  Token Bucket (CIR/CBS)
 |  (监管/Policer)  |  超限 → 丢弃 / 重标记 DEI
 +------------------+
      |
      v
 +------------------+
 |  Marking         |  重写 DSCP / PCP / DEI
 |  (标记)          |
 +------------------+
      |
      v
 +------------------+
 |  Queue           |  每端口 8 个优先级队列
 |  (入队)          |  WRED / Tail Drop 拥塞处理
 +------------------+
      |
      v
 +------------------+
 |  Scheduling      |  SP + DWRR / WFQ
 |  (调度)          |
 +------------------+
      |
      v
 +------------------+
 |  Shaping         |  Token Bucket (CIR/CBS)
 |  (整形)          |  平滑发送
 +------------------+
      |
      v
 +------------------+
 |  Egress          |  VLAN Tag 插入/删除
 |  (出口处理)      |  FCS 重计算
 +------------------+
      |
      v
 Egress Port
```

---

## 4. IC 设计注意事项

### 4.1 VLAN 解析与插入逻辑

**解析 (Ingress)**：
1. 从以太网帧 Src MAC 后读取 2 字节，与 TPID 比较
2. 匹配 `0x8100` → 标准 VLAN，提取 PCP/DEI/VID
3. 匹配 `0x88A8` → QinQ 外层，继续解析内层 Tag
4. 未匹配 → Untagged 帧，使用端口 PVID
5. VID 提供给查找引擎用于 VLAN-aware 转发

**插入/删除 (Egress)**：
1. 查表决定出端口模式 (Access/Trunk/Hybrid)
2. Access 端口：剥除 VLAN Tag
3. Trunk 端口：保留 Tag，可改写 PCP
4. Hybrid 端口：按 VID 配置决定是否剥 Tag

**位宽对齐**：VLAN 解析模块输入为 64-bit (8 Byte/cycle) 或 256-bit 数据通路，需处理 Tag 跨 cycle 边界的情况。

### 4.2 QoS 分类

分类优先级链路：
1. 五元组 (IP Src/Dst, Protocol, L4 Port) → ACL → DSCP
2. DSCP → PCP 映射 → Traffic Class
3. PCP (L2) 直接 → Traffic Class
4. 端口默认优先级 → Traffic Class

**IC 设计要点**：分类逻辑通常在 Ingress Pipeline 第一级，需在 1-2 cycle 内完成查找。

### 4.3 队列管理

- 每端口 8 个 CoS 队列 (对应 PCP 0-7)
- 队列存储使用 SRAM 或寄存器 FIFO
- 队列深度由报文缓冲区 (Packet Buffer) 动态分配
- 支持 Head-of-Line Blocking 避免：入队基于出端口+CoS

### 4.4 PFC 处理

**接收方向**：
1. 识别 Pause 帧 (DA = `01-80-C2-00-01-00`, Type = `0x8808`)
2. 解析 Class Enable Vector 和 Timer
3. 对应 CoS 队列停止出队，启动计时器
4. 计时器超时恢复发送

**发送方向**：
1. 监控每个 CoS 队列的 XOFF/XON 阈值
2. 队列深度 > XOFF 阈值 → 生成 PFC Pause (Timer = 0xFFFF 持续暂停)
3. 队列深度 < XON 阈值 → 生成 PFC Pause (Timer = 0x0000 恢复)
4. Pause 帧生成需要独立的发送通路，优先级高于数据帧

### 4.5 Policer / Token Bucket 实现

```
                +----------+
 ref_time ----->| Token    |----> tokens >= pkt_size ?
                | Bucket   |         | yes: GREEN
                +----------+         | no: RED/YELLOW
                     ^                v
                CIR (token/clk)   处理动作:
                                   - 通过
                                   - 丢弃
                                   - 重标记 DEI
```

**双速率三色标记 (Two-Rate Three-Color Marker, RFC 2698)**：
- CIR + CBS：承诺桶
- CIR + EBS：超额桶
- tokens >= pkt_size in CBS → GREEN
- tokens >= pkt_size in EBS (not CBS) → YELLOW
- tokens < pkt_size in EBS → RED

**IC 设计要点**：Token Bucket 为纯组合逻辑，每个时钟周期补充 token，每包消费 token。需注意定点数精度：CIR 单位 bps 需转换为 token/cycle。

### 4.6 统计计数器

| 计数器 | 位宽 | 用途 |
|--------|------|------|
| Per-Queue Rx Packets | 64 bit | 接收包计数 |
| Per-Queue Tx Packets | 64 bit | 发送包计数 |
| Per-Queue Dropped Packets | 64 bit | 丢弃包计数 (WRED/Tail Drop) |
| Per-Queue Rx Octets | 64 bit | 接收字节计数 |
| Per-Queue Tx Octets | 64 bit | 发送字节计数 |
| Per-Port Pause Rx/Tx | 32 bit | PFC Pause 帧计数 |
| Policer Green/Yellow/Red | 32 bit | 三色标记计数 |

**IC 设计要点**：计数器使用双端口 SRAM 或寄存器堆，需支持原子读清 (Read-Clear) 操作，位宽防溢出。

---

## 5. 关键标准参考

| 标准 | 标题 | 核心内容 |
|------|------|---------|
| IEEE 802.1Q | VLAN Bridging | VLAN Tag 格式、PCP、VID |
| IEEE 802.1ad | Provider Bridges | QinQ 双层 VLAN |
| IEEE 802.1Qbb | Priority-based Flow Control | PFC 逐优先级 Pause |
| IEEE 802.1Qaz | Enhanced Transmission Selection | ETS 带宽分配、DCBX |
| IEEE 802.1Qau | Congestion Notification | 端到端拥塞通知 |
| RFC 2474 | DiffServ Architecture | DSCP 字段定义 |
| RFC 2698 | Two-Rate Three-Color Marker | 双速率令牌桶 |
| RFC 3168 | ECN | 显式拥塞通知 |
