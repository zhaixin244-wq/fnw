# MPLS (Multi-Protocol Label Switching) 协议知识文档

> **目标读者**：数字 IC 设计架构师（交换芯片、转发面设计方向）
> **版本**：v1.0
> **日期**：2026-04-15

---

## 1. 协议概述

MPLS（Multi-Protocol Label Switching，多协议标签交换）由 IETF 在 RFC 3031（2001）中定义，是一种介于 L2（数据链路层）和 L3（网络层）之间的 **2.5 层** 转发技术。

核心思想：**用短而定长的标签（Label）替代传统 IP 逐跳最长前缀匹配（LPM）查表**，实现快速转发。MPLS 不替代 IP，而是在 IP 报文前插入一个标签头部，路由器根据标签交换表（Label FIB）进行转发。

关键特性：
- **多协议**：承载 IP、IPv6、Ethernet、ATM、Frame Relay 等多种协议
- **标签转发**：基于固定长度标签的精确匹配（Exact Match），速度快于 IP 路由的 LPM
- **面向连接**：通过 LSP（Label Switched Path）建立端到端转发路径
- **支持流量工程**：显式路径规划、带宽预留、快速重路由（FRR）
- **支撑 VPN**：MPLS 是 L3VPN（RFC 4364）和 L2VPN（VPLS/EVPN）的基础

---

## 2. MPLS 标签格式（Shim Header）

MPLS 标签插入在 L2 帧头和 L3 报文头之间，称为 **Shim Header**，长度 **4 字节（32 bit）**。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                Label                  |  TC |S|     TTL       |
|            (20 bits)                  |(3b) |1|   (8 bits)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|<--------- Label (20) -------->|<-TC->|<S>|<- TTL ->|
```

在 Ethernet + MPLS 帧中的位置：

```
+----------+-----------------+-----+------+----------+-----+
|  DMAC(6) |  SMAC(6) | Etype| MPLS Label  |  IP Hdr | FCS |
|          |          |0x8847|  4 bytes    |         |     |
+----------+----------+------+-------------+---------+-----+
```

---

## 3. 各字段详解

### 3.1 Label（20 bit）

标签值，用于标识 FEC（Forwarding Equivalence Class）。LSR 根据此值查表决定转发行为。

保留标签值（RFC 3032）：

| 值 | 含义 |
|----|------|
| 0 | IPv4 Explicit NULL（显式空标签），要求下游弹出 |
| 1 | Router Alert Label（路由器告警），类似 IP Router Alert |
| 2 | IPv6 Explicit NULL |
| 3 | Implicit NULL（隐式空标签），PHP 使用 |
| 4~15 | 保留 |
| 16~1048575 | 可分配的用户标签空间（2^20 - 16 = 1,048,560 个） |

**设计注意**：标签空间 = 1M 级别，交换芯片的标签转发表（Label FIB）需覆盖此范围。实际网络中标签分配数量远小于此，典型表项规模在万到十万级。

### 3.2 TC（Traffic Class，3 bit）

原称 **EXP（Experimental）** 字段，RFC 5462 重新命名为 TC。用于 QoS 标识：

- 类似 IP 报文的 DSCP / 802.1Q 的 PCP
- 用于 MPLS 网络内部的 DiffServ 分类：报文进入 MPLS 域时，将 DSCP 映射到 TC；离开 MPLS 域时，将 TC 映射回 DSCP
- 支持 **E-LSP**（EXP-LSP）：8 个 PHB（Per-Hop Behavior）直接由 TC 编码

**设计注意**：IC 设计需实现 TC 与 DSCP 之间的 **QoS 映射逻辑**，典型为查表映射（3 bit TC ↔ 6 bit DSCP 的子集映射）。

### 3.3 S（Bottom of Stack，1 bit）

标签栈（Label Stack）的栈底标记：
- `S=1`：**栈底标签**（最内层标签）
- `S=0`：**栈中/栈顶标签**（非最内层）

### 3.4 TTL（Time To Live，8 bit）

生存时间，防止环路。行为与 IP TTL 相同：
- Ingress LER：将 IP TTL 复制到 MPLS TTL（TTL propagation）
- 中间 LSR：每转发一跳 TTL 减 1，TTL=0 时丢弃并向源发 ICMP
- Egress LER：将 MPLS TTL 回写到 IP TTL（TTL propagation）

**TTL Propagation 选项**：运营商可在 LER 上配置关闭 TTL 传播（`no-propagate-ttl`），隐藏 MPLS 网络内部拓扑。

---

## 4. 标签栈（Label Stack）

MPLS 允许一个报文携带 **多层标签**（Label Stack），从栈顶（外层/先处理）到栈底（内层/最后处理）依次排列。通过 S bit 识别栈底。

```
+------------------+
|  Ethernet Header |
+------------------+
|  Label N (S=0)   |  <-- 栈顶（最外层）
+------------------+
|  Label N-1 (S=0) |
+------------------+
|       ...        |
+------------------+
|  Label 1 (S=1)   |  <-- 栈底（最内层）
+------------------+
|  IP Header       |
+------------------+
|  Payload         |
+------------------+
```

**典型多层标签场景**：

| 场景 | 标签层数 | 各层用途 |
|------|---------|---------|
| 普通 LSP | 1 层 | 转发标签 |
| MPLS L3VPN | 2 层 | 外层 = LSP 转发标签，内层 = VPN 路由标签（RD/RT） |
| MPLS L2VPN (VPLS) | 2 层 | 外层 = LSP 转发标签，内层 = PW（Pseudo-Wire）标签 |
| MPLS-TE + VPN | 3 层 | 外层 = TE 隧道标签，中层 = VPN 标签，内层 = PW 标签 |
| Segment Routing (SR) | 1~N 层 | 每层 Segment = 一个指令 |

**设计注意**：交换芯片需支持多层标签的递归解析/插入/弹出。典型要求支持 2~4 层标签，解析深度影响 TCAM 的关键宽度和流水线级数。

---

## 5. LSR 和 LER

### 5.1 LSR（Label Switch Router，标签交换路由器）

MPLS 网络**核心路由器**，功能：
- 接收带标签的报文
- 查 Label FIB（标签转发表），执行 SWAP 或 POP 操作
- 转发到下一跳
- 不解析 IP 头部

### 5.2 LER（Label Edge Router，标签边缘路由器）

MPLS 网络**边缘路由器**，分为两种角色：

**Ingress LER（入口）**：
- 接收普通 IP 报文
- 根据目的 IP 地址确定 FEC
- 压入（PUSH）MPLS 标签
- 转发到 MPLS 网络

**Egress LER（出口）**：
- 接收带标签的报文
- 弹出（POP）MPLS 标签
- 恢复为普通 IP 报文
- 转发到 IP 网络

---

## 6. MPLS 转发流程

```
             Ingress LER          LSR-1          LSR-2          Egress LER
             +-----------+     +---------+     +---------+     +-----------+
 IP Pkt ---> | PUSH L100 | --->| SWAP    | --->| SWAP    | --->| POP       | ---> IP Pkt
             | L100|IP...|     | L100→L200|    | L200→L300|    | 恢复 IP   |
             +-----------+     +---------+     +---------+     +-----------+
                  查 IP FIB      查 Label FIB    查 Label FIB    查 Label FIB
                  → Push L100    → Swap L200     → Swap L300     → Pop
```

详细转发步骤：

```
步骤 1: Ingress LER
  输入: 普通报文 (DA=1.1.1.1)
  查表: IP FIB → 目标属于 FEC-1.1.1.1/32, 出标签 = L100
  操作: PUSH(L100), 转发至 LSR-1
  输出: [L100 | IP Pkt]

步骤 2: LSR-1（中间节点）
  输入: [L100 | IP Pkt]
  查表: Label FIB → 入标签 L100 → 出标签 L200, 出接口 = toward LSR-2
  操作: SWAP(L100 → L200)
  输出: [L200 | IP Pkt]

步骤 3: LSR-2（中间节点）
  输入: [L200 | IP Pkt]
  查表: Label FIB → 入标签 L200 → 出标签 L300, 出接口 = toward Egress LER
  操作: SWAP(L200 → L300)
  输出: [L300 | IP Pkt]

步骤 4: Egress LER
  输入: [L300 | IP Pkt]
  查表: Label FIB → 入标签 L300 → 弹出
  操作: POP, 转发 IP FIB
  输出: 普通 IP Pkt
```

**PHP（Penultimate Hop Popping）优化**：

```
步骤 3 (with PHP): LSR-2（倒数第二跳）
  查表: Label FIB → 入标签 L200 → 隐式空标签 (Implicit NULL = 3)
  操作: POP（弹出标签）, 转发 [IP Pkt] 至 Egress LER

步骤 4: Egress LER
  输入: 普通 IP Pkt（无标签）
  操作: 直接 IP 转发, 无需 POP
```

---

## 7. LSP 建立

LSP（Label Switched Path）是从 Ingress 到 Egress 的端到端标签转发路径。建立方式有三种：

### 7.1 LDP（Label Distribution Protocol，RFC 5036）

- **逐跳（Hop-by-Hop）LSP**：沿 IGP 最优路径分配标签
- 每个 LSR 为每个 FEC 分配本地入标签，并向下游请求出标签
- 基于目的地址的 FEC 分类，行为最接近 IP 路由
- 适用于简单 MPLS 网络和 L3VPN

标签分配流程：

```
Egress LER:    为 FEC-1.1.1.1/32 分配入标签 L300
    ↓ LDP Label Mapping (L300)
LSR-2:         学习到 L300, 分配自己的入标签 L200, 绑定 L200→L300
    ↓ LDP Label Mapping (L200)
LSR-1:         学习到 L200, 分配自己的入标签 L100, 绑定 L100→L200
    ↓ LDP Label Mapping (L100)
Ingress LER:   学习到 L100, 绑定 IP FIB → L100
```

### 7.2 RSVP-TE（RFC 3209）

- **显式路径 LSP（Explicit Path）**：指定经过的节点或链路
- 支持 **带宽预留**（Bandwidth Reservation）
- 支持 **快速重路由**（FRR，RFC 4090）：预先建立备份路径，切换时间 < 50ms
- 支持 **流量工程**（Traffic Engineering）：优化带宽利用率、避免热点
- 适用于运营商骨干网、专线业务

### 7.3 Segment Routing（SR-MPLS，RFC 8402）

- **源路由**（Source Routing）：Ingress 节点编码整条路径为 Segment 列表（标签栈）
- 每个 Segment = 一个标签 = 一个指令（节点、链路、功能）
- **无状态**核心网络：中间节点只需执行栈顶 Segment，无需维护路径状态
- 依赖 IGP 扩展（IS-IS/OSPF 扩展）分发 Segment ID
- 与 RSVP-TE 相比，简化了核心网络的控制平面复杂度

| 特性 | LDP | RSVP-TE | SR-MPLS |
|------|-----|---------|---------|
| 路径类型 | 逐跳（IGP 最短路径） | 显式路径 | 源路由（标签栈编码） |
| 核心状态 | 每 FEC 有标签状态 | 每 LSP 有软状态 | 无状态 |
| 流量工程 | 有限 | 强 | 支持（SR-TE） |
| 快速重路由 | 需额外机制 | 原生支持 | TI-LFA（IGP 计算） |
| 控制面复杂度 | 中 | 高 | 低 |
| 部署复杂度 | 低 | 高 | 中 |

---

## 8. 标签操作

| 操作 | 含义 | 典型执行位置 | 描述 |
|------|------|------------|------|
| **PUSH** | 压入标签 | Ingress LER | 在 IP 报文前插入一个或多个 MPLS 标签 |
| **SWAP** | 替换标签 | LSR（核心节点） | 将栈顶标签替换为新标签值 |
| **POP** | 弹出标签 | Egress LER / PHP 节点 | 移除栈顶标签 |

**PHP（Penultimate Hop Popping）**：
- Egress LER 分配 **Implicit NULL（标签值 3）** 给上游
- 上游（倒数第二跳）收到 Implicit NULL 后，在转发前弹出栈顶标签
- 目的：减轻 Egress LER 的处理负担（少一次标签查找和 POP 操作）
- 对于需要保留标签的场景（如 VPN），Egress 分配 **Explicit NULL（标签值 0/2）**，要求保留标签

---

## 9. FEC（Forwarding Equivalence Class）

FEC 是一组以**相同方式转发**的报文集合。MPLS 基于 FEC 分配标签——同一 FEC 的报文获得相同的标签。

**FEC 的分类依据**：

| FEC 类型 | 分类依据 | 典型应用 |
|----------|---------|---------|
| 目的地址前缀 | IP 目的地址 / 掩码 | 普通 L3 转发（LDP） |
| 主机路由 | 单个 IP 地址 | 特定主机的 LSP |
| VPN 路由 | RD + 前缀（VRF 内） | L3VPN |
| PW（Pseudo-Wire） | AC（Attachment Circuit）标识 | L2VPN / VPLS |
| TE 隧道 | 显式路径约束 | 流量工程 |

**设计注意**：FEC 的定义方式直接影响 Label FIB 的组织结构和查找方式。IC 设计中，Label FIB 通常用 **TCAM（标签精确匹配）** 或 **Hash Table** 实现。

---

## 10. MPLS 应用场景

### 10.1 MPLS L3VPN（RFC 4364）

- **PE（Provider Edge）路由器** 为每个客户维护独立的 **VRF（Virtual Routing and Forwarding）** 表
- 客户路由通过 **RD（Route Distinguisher）** 全局唯一化
- 通过 **RT（Route Target）** 控制路由导入/导出
- 报文携带 **2 层标签**：外层 = LSP 转发标签，内层 = VPN 路由标签
- 是运营商最广泛部署的 VPN 技术

### 10.2 VPLS / EVPN（L2VPN）

- **VPLS（Virtual Private LAN Service）**：在 MPLS 网络上模拟以太网 LAN
- 通过 **PW（Pseudo-Wire）** 在 PE 之间建立点对点以太网隧道
- EVPN 作为 VPLS 的演进，引入控制面学习 MAC 地址，支持多活（Multi-Homing）
- 报文携带 **2 层标签**：外层 = LSP 转发标签，内层 = PW 标签

### 10.3 MPLS-TP（Transport Profile，RFC 5654）

- 面向连接的传输：为每条 LSP 建立 **OAM（Operations, Administration, Maintenance）** 通道
- 无需 IP 控制面，可静态配置 LSP（类似 SDH/SONET）
- 支持线性保护（1+1/1:1）和环网保护
- 目标：替代 SDH/SONET 用于运营商承载网

### 10.4 Traffic Engineering

- **带宽优化**：将流量分散到多条路径，避免单链路拥塞
- **路径保护**：FRR（Fast Reroute）< 50ms 切换
- **约束路由**：根据链路带宽、延迟、策略等约束计算路径
- SR-TE 使用标签栈编码路径，简化了控制面

---

## 11. PHP（Penultimate Hop Popping）

PHP 是 MPLS 优化 Egress LER 性能的关键机制。

**原理**：
1. Egress LER 为某个 FEC 分配 **Implicit NULL 标签（值 3）** 向上游宣告
2. 倒数第二跳（Penultimate Hop）收到 Implicit NULL 标签
3. 倒数第二跳在转发时弹出栈顶标签，将剥离标签后的报文发给 Egress LER
4. Egress LER 收到无标签报文，直接进行 IP 路由查表

**隐式空标签 vs 显式空标签**：

| 标签 | 值 | 行为 | 使用场景 |
|------|----|------|---------|
| Implicit NULL | 3 | 倒数第二跳弹出，Egress 收到无标签报文 | 普通 LSP |
| Explicit NULL (v4) | 0 | 倒数第二跳不弹出，Egress 收到带标签 0 的报文，自行弹出 | 需保留 TC/TTL 信息（QoS 场景） |
| Explicit NULL (v6) | 2 | 同上 | IPv6 MPLS |

**为什么需要 Explicit NULL**：Implicit NULL 的情况下，倒数第二跳弹出标签时，TC 信息丢失。若 Egress 需要基于 TC 做 QoS 决策（如调度或标记），则需使用 Explicit NULL 保留 TC 信息到最后一跳。

**设计注意**：交换芯片需支持 Implicit NULL 和 Explicit NULL 两种行为。对 Explicit NULL，Egress 需额外做一次 POP 操作并提取 TC/TTL。

---

## 12. 设计注意事项（交换芯片 MPLS 处理）

### 12.1 标签解析（MPLS Parser）

| 设计项 | 要求 |
|--------|------|
| 标签识别 | EtherType 0x8847 (MPLS Unicast) / 0x8848 (MPLS Multicast) |
| 标签层数 | 支持 2~4 层标签递归解析（由 S bit 控制终止） |
| 解析位置 | L2 Parser 之后，L3 Parser 之前 |
| 解析输出 | 栈顶标签值、TC、S bit、TTL、标签栈层数 |
| 解析深度 | 需提前确定最大解析层数，影响流水线宽度 |

### 12.2 标签操作

| 操作 | 硬件实现 |
|------|---------|
| PUSH | 在 L2 Header 后、IP Header 前插入 4N 字节（N = 标签数），需修改报文长度 |
| SWAP | 修改栈顶标签的 Label 字段（20 bit），TTL 减 1 |
| POP | 移除栈顶 4 字节，后续头部前移，TTL 回写（如需） |

**报文修改（Packet Edit）**：PUSH/POP 操作改变报文长度，硬件需支持在转发流水线中动态增删字节，通常通过 **Header Edit Engine** 实现。

### 12.3 标签转发表（Label FIB）

| 设计项 | 方案 |
|--------|------|
| 查找方式 | TCAM（精确匹配，标签值 = Key）或 Hash Table |
| 表项规模 | 典型 16K~256K 条目（取决于芯片定位：接入/汇聚/核心） |
| 关键字 | {入标签值, 入端口/VPN} → {出标签值, 出接口, 操作类型} |
| 查找宽度 | 20 bit 标签 + VPN ID（如支持 VRF） |
| 更新方式 | 控制面下发（LDP/RSVP-TE），支持在线更新 |

### 12.4 多层标签处理

| 要求 | 描述 |
|------|------|
| 解析深度 | 取决于应用：普通 LSP=1 层，VPN=2 层，SR-MPLS=N 层 |
| 标签操作组合 | 支持 POP+SWAP（如 VPN 网络中，弹出外层转发标签后查内层 VPN 标签） |
| 嵌套标签操作 | SR-MPLS 中可能需要 POP 多个 Segment 标签 |
| 栈深度限制 | 需与芯片解析能力匹配，超深标签栈需软件辅助 |

### 12.5 MPLS OAM

| 功能 | 协议/工具 | 说明 |
|------|----------|------|
| 连通性检测（CC） | BFD for MPLS | 快速故障检测，典型 50ms 间隔 |
| 环回（Ping） | MPLS LSP Ping (RFC 8029) | 验证 LSP 连通性 |
| 路径追踪（Trace） | MPLS LSP Traceroute | 逐跳跟踪 LSP 路径 |
| 性能测量 | MPLS-TP PM | 延迟、抖动、丢包率测量 |

**设计注意**：交换芯片需支持 BFD 报文的快速生成和处理（通常在硬件转发面实现），OAM 报文使用特定标签值或 G-ACh（Generic Associated Channel）标识。

### 12.6 QoS 映射

| 映射方向 | 源字段 | 目标字段 | 说明 |
|----------|--------|---------|------|
| IP → MPLS | DSCP | TC | Ingress LER 入方向 |
| MPLS → IP | TC | DSCP | Egress LER 出方向 |
| Ethernet → MPLS | PCP | TC | L2 接入场景 |
| MPLS → Ethernet | TC | PCP | L2 出方向 |

**设计注意**：QoS 映射表需可编程配置，典型实现为 3 bit TC 到 6 bit DSCP（仅使用 64 种组合中的 8~16 种）的查表映射。

### 12.7 与 IP 路由的共存

| 场景 | 处理方式 |
|------|---------|
| 标签报文到达 | EtherType = 0x8847 → MPLS 转发路径 |
| IP 报文到达 | EtherType = 0x0800 → IP 路由路径 |
| 标签弹出后 | S=1 且下层为 IP → 递归进入 IP 转发路径 |
| 混合转发 | 同一芯片需同时支持 Label FIB 和 IP FIB 查表 |

---

## 13. 与 Segment Routing v6（SRv6）的关系

SRv6（RFC 8986）是 Segment Routing 在 IPv6 上的实现，可被视为 MPLS 的演进/替代方案：

| 特性 | MPLS / SR-MPLS | SRv6 |
|------|---------------|------|
| 转发平面 | 标签交换（Shim Header） | IPv6 Header + SRH（Segment Routing Header） |
| 路径编码 | 标签栈（固定 4 字节/标签） | SRH 中的 Segment 列表（128 bit/Segment） |
| 节点标识 | 20 bit 标签值 | 128 bit SID（Segment Identifier，含 Locator + Function + Args） |
| 程序能力 | 有限（标签 = 转发指令） | **强**（Function 编码：End, End.X, End.DT4, End.DT6 等） |
| 中间节点 | 需要 MPLS 支持 | 标准 IPv6 转发（无需特殊硬件） |
| 封装开销 | 4 字节/标签 | 40 字节 IPv6 + 16*N 字节 SRH |
| 部署成熟度 | 成熟，全球广泛部署 | 较新，正在推广 |
| 与现有网络 | 需要 MPLS 基础设施 | 基于 IPv6，与 IP 网络天然融合 |

**关系判断**：
- SRv6 并非简单替代 MPLS，两者可共存
- SR-MPLS 是 MPLS 与 SR 的结合，标签栈本身就是 SR 的路径编码
- SRv6 的优势在于**编程能力**（network programming）和**与 IPv6 生态融合**
- 短期内 MPLS 仍是运营商骨干网主流，SRv6 在新建网络和数据中心中增长

**设计注意**：下一代交换芯片需同时支持 MPLS 和 SRv6 转发平面，或者提供从 MPLS 到 SRv6 的迁移路径。SRv6 SRH 的处理（解析、插入、修改）与 MPLS Shim Header 的处理有相似之处，可复用部分 Header Edit 逻辑。

---

## 参考标准

| 编号 | 文档 | 说明 |
|------|------|------|
| RFC 3031 | MPLS Architecture | MPLS 架构总定义 |
| RFC 3032 | MPLS Label Stack Encoding | 标签格式与编码 |
| RFC 5036 | LDP Specification | LDP 协议规范 |
| RFC 3209 | RSVP-TE | 基于 RSVP 的流量工程 |
| RFC 4090 | Fast Reroute Extensions to RSVP-TE | 快速重路由 |
| RFC 4364 | BGP/MPLS IP VPNs (L3VPN) | L3VPN 架构 |
| RFC 4761 / 4762 | VPLS | L2VPN 虚拟专用 LAN |
| RFC 5654 | MPLS-TP Requirements | 传输 Profile 需求 |
| RFC 5462 | MPLS TC Field | TC 字段定义 |
| RFC 8402 | Segment Routing Architecture | SR 架构 |
| RFC 8986 | SRv6 Network Programming | SRv6 网络编程 |
