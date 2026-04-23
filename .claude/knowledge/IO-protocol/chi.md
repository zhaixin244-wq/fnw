# AMBA CHI (Coherent Hub Interface) 协议参考

> **版本**：v1.0
> **日期**：2026-04-15
> **面向读者**：数字 IC 设计架构师
> **参考规格**：ARM AMBA CHI Specification (Issue C/I)

---

## 1. 协议概述

ARM AMBA CHI (Coherent Hub Interface) 是 ARM 推出的高性能缓存一致性互联协议，是 AMBA 5 规范的核心组成部分。CHI 设计用于支持大规模多核、多 cluster 的一致性系统，提供硬件级缓存一致性维护机制。

**核心定位**：CHI 是 ACE (AXI Coherency Extensions) 的继承者，解决了 ACE 在扩展性上的瓶颈。ACE 基于集中式 snoop 机制，CHI 引入了基于事务的点对点互联架构，支持分布式一致性管理。

**CHI 版本演进**：

| 版本 | 发布时间 | 核心新增特性 |
|------|----------|-------------|
| **CHI-A** | 2013 | 初始版本，定义 RN/HN/SN 架构、四通道 (REQ/RSP/SNP/DAT)、基本一致性事务 |
| **CHI-B** | 2016 | Distributed Snoop Filter 支持、MPAM (Memory System Resource Partitioning and Monitoring)、增强的 Ordering 模型 |
| **CHI-C** | 2019 | PBR (Persistent Buffer Requirements)、增强的 WriteNoSnpPtl、Stash 事务增强 |
| **CHI-D** | 2021 | IDE (Integrity and Data Encryption) 安全扩展、增强的 MPAM、CHI to AXI bridge 增强、Endpoint Persist |

**关键设计目标**：
- 支持数百个核心的一致性扩展
- 点对点事务化互联，替代 ACE 的广播 snoop
- 分布式归属节点 (HN)，避免中心瓶颈
- 高带宽、低延迟的片上互联
- 可选的一致性粒度（Snoop Filter / Directory）

---

## 2. CHI 在 AMBA 家族中的定位

### 2.1 AMBA 一致性协议演进

```
AXI3/AXI4          ACE              CHI
(非一致性)     (一致性扩展)    (独立一致性协议)
    |                |                |
    v                v                v
 单 master       广播 snoop      点对点事务
 无缓存维护     集中一致性       分布式一致性
 低扩展性       中等扩展性       高扩展性
```

| 协议 | 一致性模型 | 互联方式 | 适用场景 | 扩展性 |
|------|-----------|---------|---------|--------|
| **AXI4** | 无一致性 | 共享总线/交叉开关 | 单核/简单 SoC | 低 |
| **ACE** (AXI Coherency Extensions) | 硬件一致性 | 广播 snoop + 集中仲裁 | 多核 cluster (≤8 核) | 中 |
| **ACE-Lite** | I/O 一致性 | 单向 snoop (不被 snoop) | GPU/DMA 访问 CPU 缓存 | 中 |
| **CHI** | 硬件一致性 | 点对点事务 + 分布式 HN | 大规模多核/多 cluster | 高 |

### 2.2 典型系统拓扑

```
                  +-----------+    +-----------+
                  | CPU Clus. |    | CPU Clus. |
                  |  (RN-F)   |    |  (RN-F)   |
                  +-----+-----+    +-----+-----+
                        |                |
                  +-----+-----+    +-----+-----+
                  |    HN-F    |    |    HN-F    |     (一致性 Home Node)
                  | (Snoop     |    | (Snoop     |
                  |  Filter)   |    |  Filter)   |
                  +-----+-----+    +-----+-----+
                        |                |
                  +-----+----------------+------+
                  |          System Interconnect |
                  +-----+----------------+------+
                        |                |
                  +-----+-----+    +-----+-----+
                  |   SN-F    |    |   SN-I    |      (Subordinate Node)
                  | (DDR Ctrl)|    | (外设桥)   |
                  +-----------+    +-----------+
```

---

## 3. CHI 架构组件

### 3.1 节点类型总览

| 节点类型 | 全称 | 角色 | 典型实例 |
|----------|------|------|---------|
| **RN** | Request Node | 发起一致性请求 | CPU Cluster、GPU |
| **HN** | Home Node | 地址归属节点，管理一致性 | 互联内部的地址管理模块 |
| **SN** | Subordinate Node | 最终存储/外设节点 | DDR 控制器、外设桥 |

### 3.2 Request Node (RN) 子类型

| 子类型 | 全称 | 能力 | 典型实例 |
|--------|------|------|---------|
| **RN-F** | Full Coherent RN | 可发起请求、可被 snoop、维护本地缓存一致性 | CPU Cluster (Cortex-A) |
| **RN-I** | I/O Coherent RN | 可发起请求、可被 snoop、无本地缓存 | I/O 控制器、PCIe EP |
| **RN-D** | DMA RN | 可发起请求、不可被 snoop | DMA 引擎 |

**RN-F 核心能力**：
- 发起 Read/Write/Atomic 事务
- 响应 Snoop 请求并返回缓存数据
- 维护本地缓存状态 (UC/SC/UD/SD/I)
- 支持 DVM (Distributed Virtual Memory) 操作

**RN-I 核心能力**：
- 发起 Read/Write 事务（无缓存，不能回写脏数据）
- 响应 Snoop（但始终返回 SnpResp = I，无数据）
- 用于设备 I/O 一致性访问

### 3.3 Home Node (HN) 子类型

| 子类型 | 全称 | 能力 | 典型实例 |
|--------|------|------|---------|
| **HN-F** | Full HN | 地址归属 + 一致性管理 + Snoop Filter/Directory | 互联中的 HN 模块 |
| **HN-I** | I/O HN | 地址归属 + 事务转发（无一致性管理） | 连接非一致性外设的桥 |

**HN-F 核心功能**：
- 地址解码：确定目标 SN
- 一致性仲裁：对同一地址的并发请求排序
- Snoop 管理：向相关 RN 发送 Snoop 命令
- 数据路由：将 Snoop 数据转发给请求 RN
- 写入 SN：将 WriteBack 数据写入内存

### 3.4 Subordinate Node (SN) 子类型

| 子类型 | 全称 | 能力 | 典型实例 |
|--------|------|------|---------|
| **SN-F** | Full SN | 支持持久化写入、读取 | DDR 控制器 (带 persist 支持) |
| **SN-I** | I/O SN | 基本读写、无持久化保证 | 外设寄存器、SRAM |

---

## 4. CHI 接口层次

### 4.1 四通道架构

CHI 定义了四个独立的通道，所有事务通过这四个通道的组合完成：

```
  RN (Request Node)                          HN (Home Node)
  +------------+                             +------------+
  |            | ---- REQ (请求通道) -------->|            |
  |            |<--- RSP (响应通道) ----------|            |
  |            |<--- SNP (Snoop 通道) --------|            |
  |            |<==> DAT (数据通道) <=======>|            |
  +------------+                             +------------+
```

| 通道 | 方向 | 功能 | 包含信息 |
|------|------|------|---------|
| **REQ** | RN → HN | 请求通道：发起事务 | TxnID、Opcode、Addr、Size、Order、AllowRetry |
| **RSP** | HN → RN 或 RN → HN | 响应通道：确认/完成 | TxnID、RespErr、Resp、FwdState、DataPull |
| **SNP** | HN → RN | Snoop 通道：一致性探测 | TxnID、Opcode、Addr、FwdNodeID、DoNotGoToSD |
| **DAT** | 双向 | 数据通道：传输数据 | TxnID、Data、Resp、BE、DataSource、HomeNID |

**通道握手**：所有通道使用 Valid/Ready 握手机制。
- Valid 拉高后必须保持稳定直到 Ready 握手
- Ready 可以依赖 Valid（推荐）或不依赖

### 4.2 Link Layer 与 Transaction Layer

CHI 协议分为两层：

**Link Layer（链路层）**：
- 管理通道间的流控信用 (Credit)
- 定义 LCrdV（Link Credit Valid）机制
- 处理 Retry 操作
- 保证通道不会死锁

**Transaction Layer（事务层）：
- 定义事务类型和状态转移
- 管理一致性语义
- 处理 Ordering 和 Completion

### 4.3 事务标识

| 字段 | 位宽 | 说明 |
|------|------|------|
| `TxnID` | 12 bit | 事务标识，用于关联 REQ/RSP/DAT |
| `SrcID` | 7 bit | 源节点 ID |
| `TgtID` | 7 bit | 目标节点 ID |
| `ReturnNID` | 7 bit | 数据返回节点 ID（用于 Snoop 数据转发） |
| `StashNID` | 7 bit | Stash 目标节点 ID |
| `HomeNID` | 7 bit | Home 节点 ID（用于 Snoop 数据返回） |

---

## 5. CHI 事务类型

### 5.1 Read 事务

| Opcode | 名称 | 语义 | 缓存状态变更 | 典型用途 |
|--------|------|------|-------------|---------|
| `ReadShared` | 读共享 | 请求共享副本，可能被其他 RN 持有 | 获取 SC 状态 | CPU 读 miss |
| `ReadClean` | 读干净 | 请求独占副本，其他 RN 必须失效 | 获取 UC 状态 | CPU 写前预取 |
| `ReadOnce` | 读一次 | 读取但不缓存（设备访问） | 不变更本地状态 | I/O 读 |
| `ReadNoSnp` | 非一致性读 | 读取不需 snoop（已知无副本） | N/A | RN-D 读 |
| `ReadUnique` | 读独占 | 获取独占权限，可能需要 snoop | 获取 UD 状态 | 原子操作读 |
| `ReadPreferUnique` | 优选独占 | 优先获取独占，否则共享 | UC 或 SC | 写后读优化 |
| `CleanUnique` | 清理独占 | 获取独占并清脏（无数据传输） | UC 状态 | 降级为干净独占 |
| `MakeUnique` | 独占化 | 获取独占权限，不读取数据 | UC 状态 | 写独占 |
| `StashOnceShared` | Stash 共享 | 数据推送到目标 RN 缓存（共享） | SC (目标 RN) | 预取优化 |
| `StashOnceUnique` | Stash 独占 | 数据推送到目标 RN 缓存（独占） | UC (目标 RN) | 预取优化 |

### 5.2 Write 事务

| Opcode | 名称 | 语义 | 典型用途 |
|--------|------|------|---------|
| `WriteBack` | 写回 | 将缓存行脏数据写回 HN，放弃副本 | 缓存替换写回 |
| `WriteClean` | 写清理 | 将脏数据写回 HN，保留共享副本 | 维护一致性 |
| `WriteUnique` | 写独占 | 写入新数据，使其他副本失效 | CPU store miss |
| `WriteNoSnp` | 非一致性写 | 不需 snoop 的写入 | RN-D 写 |
| `WriteNoSnpPtl` | 部分非一致性写 | 不需 snoop 的部分写入 | RN-D 部分写 |
| `WriteUniqueFull` | 完整写独占 | 完整 cache line 写入 | 整行覆盖写 |
| `WriteUniquePtl` | 部分写独占 | 部分 cache line 写入 | 部分字段写 |
| `Evict` | 驱逐 | 通知 HN 缓存行被驱逐（干净行） | 清理缓存目录 |
| `WriteEvictFull` | 写驱逐完整 | 驱逐脏数据，写回 HN | 与 WriteBack 类似 |
| `WriteEvictOrEvict` | 写/纯驱逐 | 根据脏标记选择行为 | 灵活驱逐 |
| `StashOnceSepShared` | Stash 分离共享 | 数据通过数据通道传输 | Stash 增强 |
| `StashOnceSepUnique` | Stash 分离独占 | 数据通过数据通道传输 | Stash 增强 |
| `CMO` | 缓存维护操作 | Clean/Invalidate/Zero by VA | 缓存管理 |

### 5.3 Atomic 事务

| Opcode | 名称 | 语义 |
|--------|------|------|
| `AtomicStore` | 原子存储 | 原子写入，返回旧值 |
| `AtomicLoad` | 原子加载 | 原子读取并执行操作 |
| `AtomicSwap` | 原子交换 | 原子交换值 |
| `AtomicCompare` | 原子比较交换 | CAS 操作，比较成功则写入 |

Atomic 事务的 `AtomicOpcode` 字段指定具体操作：
- `ADD`, `BIC`, `EOR`, `ORR`, `SMAX`, `SMIN`, `UMAX`, `UMIN`

### 5.4 Snoop 事务

| Opcode | 名称 | 语义 | RN 返回数据 |
|--------|------|------|------------|
| `SnpShared` | Snoop 共享 | 请求共享副本数据 | SC 状态返回数据 |
| `SnpClean` | Snoop 清理 | 获取干净副本 | UC/UD 状态返回数据 |
| `SnpUnique` | Snoop 独占 | 使所有其他副本失效 | 所有状态返回数据 |
| `SnpMakeInvalid` | Snoop 使之无效 | 纯失效，不要求数据 | 仅返回响应 |
| `SnpOnce` | Snoop 一次 | 读取但不改变 RN 状态 | 按当前状态返回 |
| `SnpNotSharedDirty` | Snoop 非共享脏 | 获取共享脏数据副本 | SD 状态返回数据 |
| `SnpStashUnique` | Snoop Stash 独占 | 推送数据到指定 RN | 返回数据 |
| `SnpStashShared` | Snoop Stash 共享 | 推送数据到指定 RN | 返回数据 |
| `SnpPreferUnique` | Snoop 优选独占 | 优先独占，否则共享 | 返回数据 |
| `SnpCleanShared` | Snoop 清理共享 | 降级脏为共享 | UD/SD 状态返回数据 |
| `SnpCleanInvalid` | Snoop 清理无效 | 清理并无效 | 返回数据 |
| `SnpMakeInvalidStash` | Snoop 无效 Stash | Stash + 无效化 | 返回数据 |
| `SnpUniqueStash` | Snoop 独占 Stash | Stash + 独占化 | 返回数据 |

### 5.5 事务完成响应 (CompResp)

| 响应值 | 名称 | 说明 |
|--------|------|------|
| `Comp_UC` | 完成 - Unique Clean | 获取 UC 状态 |
| `Comp_SC` | 完成 - Shared Clean | 获取 SC 状态 |
| `Comp_SD` | 完成 - Shared Dirty | 获取 SD 状态（snoop 数据转发时） |
| `Comp_I` | 完成 - Invalid | 无有效数据 |

---

## 6. 缓存状态模型

### 6.1 五态模型

CHI 定义了五种缓存行状态：

| 状态 | 缩写 | 含义 | 是否唯一副本 | 是否脏 | 说明 |
|------|------|------|------------|--------|------|
| **Unique Clean** | UC | 独占干净 | 是 | 否 | 唯一副本，与内存一致 |
| **Unique Dirty** | UD | 独占脏 | 是 | 是 | 唯一副本，比内存新 |
| **Shared Clean** | SC | 共享干净 | 否 | 否 | 可能有多个副本，与内存一致 |
| **Shared Dirty** | SD | 共享脏 | 否 | 是 | 共享副本之一为脏（该 RN 持有脏副本） |
| **Invalid** | I | 无效 | - | - | 缓存行无效 |

### 6.2 状态转移图

```
                    ReadShared
          +---------------------------+
          |                           v
          |    +-----+  WriteBack  +-----+
          |    |  I  |<----------- |  SC |
          |    +-----+             +-----+
          |      | ^                 | ^
          |      | | ReadClean       | | SnpUnique/SnpMakeInvalid
          |      | |                 | |
          |      v |                 v |
          |    +-----+             +-----+
          +--->|  UC |             | UD  |
               +-----+             +-----+
                 | ^                 | ^
                 | | WriteBack       | | WriteBack
                 | | Evict           | | WriteClean
                 | v                 v |
               +-----+             +-----+
               |  UD | --Write-->  |  SD |
               +-----+   Clean     +-----+
                               (Shared Dirty 仅出现在 snoop 数据转发时)

    状态转移关键路径：
    I  → UC : ReadClean / ReadUnique / MakeUnique
    I  → SC : ReadShared
    UC → UD : 本地写入
    SC → UD : ReadClean (使其他副本无效) + 本地写入
    UD → I  : WriteBack (写回脏数据)
    UD → UC : WriteClean (写回脏数据，保留副本)
    UC → I  : Evict (驱逐干净行)
    SD → I  : SnpUnique / SnpMakeInvalid (被 snoop 夺走)
    UD → SD : SnpShared (snoop 请求共享副本)
```

### 6.3 snoop 与状态转移

| 当前状态 | 收到 Snoop | RN 行为 | 新状态 | 是否返回数据 |
|---------|-----------|---------|--------|------------|
| I | 任何 Snoop | 返回 SnpResp=I | I | 否 |
| SC | SnpShared | 返回 SnpResp=SC | SC | 否（不返回脏数据） |
| SC | SnpClean | 返回 SnpResp=SC | SC | 否 |
| SC | SnpUnique | 返回 SnpResp=I | I | 否 |
| SC | SnpMakeInvalid | 返回 SnpResp=I | I | 否 |
| UC | SnpShared | 返回数据 + SnpResp=SC | SC | 是 |
| UC | SnpClean | 返回数据 + SnpResp=SC | SC | 是 |
| UC | SnpUnique | 返回数据 + SnpResp=I | I | 是 |
| UC | SnpMakeInvalid | 返回 SnpResp=I | I | 否 |
| UD | SnpShared | 返回数据 + SnpResp=SD | SD | 是 |
| UD | SnpClean | 返回数据 + SnpResp=SC | SC | 是 |
| UD | SnpUnique | 返回数据 + SnpResp=I | I | 是 |
| UD | SnpMakeInvalid | 返回数据 + SnpResp=I | I | 是 |
| SD | SnpShared | 返回数据 + SnpResp=SD | SD | 是 |
| SD | SnpUnique | 返回数据 + SnpResp=I | I | 是 |
| SD | SnpMakeInvalid | 返回数据 + SnpResp=I | I | 是 |

---

## 7. 一致性流程示例

### 7.1 ReadShared 流程（RN-A 读，RN-B 有脏数据副本）

场景：RN-A 发起 ReadShared，HN-F 查找目录发现 RN-B 持有 UD 状态副本。

```
  RN-A              HN-F              RN-B              SN-F
   |                  |                 |                 |
   |-- ReadShared --->|                 |                 |
   |  (Addr, TxnID=X) |                 |                 |
   |                  |                 |                 |
   |                  |-- SnpShared --->|                 |
   |                  |  (TxnID=Y)      |                 |
   |                  |                 |                 |
   |                  |<-- SnpResp_I ---|                 |
   |                  |  (DataPull=1)   |                 |
   |                  |                 |                 |
   |<== CompData_SC ==|<== SnpData_SC ==|                 |
   |  (TxnID=X,数据)   |  (TxnID=Y,数据)  |                 |
   |                  |                 |                 |
   |                  |-- CompAck ---->|                 |
   |                  |  (TxnID=X)      |                 |
   |                  |                 |                 |

   说明：
   1. RN-A 发 ReadShared 到 HN-F
   2. HN-F 查 snoop filter / directory，发现 RN-B 有 UD 副本
   3. HN-F 向 RN-B 发 SnpShared
   4. RN-B 返回 SnpResp_I (DataPull=1) + 数据（SnpData）
   5. HN-F 将数据直接转发给 RN-A（CompData），同时写入 SN-F
   6. RN-A 收到 CompData，状态变为 SC
   7. RN-A 发 CompAck 确认完成
```

### 7.2 WriteBack 流程（RN 写回脏数据）

场景：RN-A 持有 UD 状态的脏数据，需要写回内存。

```
  RN-A              HN-F              SN-F
   |                  |                 |
   |-- WriteBack --->|                 |
   |  (Addr, TxnID=X, NCWrite=0)       |
   |                  |                 |
   |<== CompData ==---|                 |
   |  (TxnID=X)       |                 |
   |                  |                 |
   |  (WriteData) ==> |                 |
   |  (TxnID=X)       |                 |
   |                  |                 |
   |                  |-- WriteNoSnp -->|
   |                  |  (Addr, 数据)     |
   |                  |                 |
   |                  |<-- Comp_I ------|
   |                  |                 |
   |  RN-A 状态 → I    |                 |

   说明：
   1. RN-A 发 WriteBack 到 HN-F
   2. HN-F 返回 CompData 表示接受
   3. RN-A 通过 DAT 通道发送脏数据
   4. HN-F 将数据通过 WriteNoSnp 写入 SN-F (DDR)
   5. SN-F 返回 Comp 表示写入完成
   6. RN-A 缓存行状态变为 I
```

### 7.3 Snoop 数据转发流程（Request Forwarding）

场景：RN-A 发 ReadShared，HN-F 目录发现 RN-B 有 UD 数据，数据直接从 RN-B 转发给 RN-A。

```
  RN-A              HN-F              RN-B
   |                  |                 |
   |-- ReadShared --->|                 |
   |                  |                 |
   |                  |-- SnpShared --->|
   |                  | (FwdNodeID=RN-A)|
   |                  |                 |
   |                  |<-- SnpResp_SD --|
   |                  | (DataPull=1)    |
   |                  |                 |
   |<== SnpData_SC ===|                 |
   |  (来自 RN-B 直传)  |                 |
   |                  |                 |
   |                  |<-- CompData_SC--| (或 RN-B 写回)
   |                  |                 |
   |  状态 → SC        |  状态 → I        |

   说明：
   1. HN-F 在 SnpShared 中携带 FwdNodeID = RN-A 的 NodeID
   2. RN-B 的脏数据通过 DAT 通道直接发给 RN-A（snoop 数据转发）
   3. 减少了 HN-F 作为数据中转的延迟
   4. RN-A 获得 SC 状态，RN-B 状态变为 I
```

---

## 8. CHI 与 ACE 对比

| 对比维度 | ACE | CHI |
|---------|-----|-----|
| **通道结构** | 5 通道 (AW/AR/W/R/B) + AC/snoop 扩展 | 4 通道 (REQ/RSP/SNP/DAT)，独立设计 |
| **Snoop 机制** | 广播式 snoop (AC 通道)，所有 RN 收到 | 点对点 snoop (SNP 通道)，仅相关 RN 收到 |
| **一致性管理** | 集中仲裁器，广播后等待所有响应 | 分布式 HN + Snoop Filter/Directory |
| **地址路由** | 基于地址范围的固定路由 | HN 归属 + 动态目录查找 |
| **Ordering** | 基于 AW/AR 通道的 ordering | 基于 Order 字段的显式 ordering（Endpoint Order、Request Order） |
| **原子操作** | Load-Exclusive / Store-Exclusive (LL/SC) | 原生 Atomic 事务（AtomicStore/Load/Swap/Compare） |
| **数据传输** | 写数据和响应在同一事务中 | REQ/RSP/DAT 分离，支持流水化 |
| **扩展性** | 受限于广播 snoop 延迟 | 支持数百节点，HN 分布式部署 |
| **Retry 机制** | 无（必须接受） | 有（HN 可返回 RetryAck，避免阻塞） |
| **I/O 一致性** | ACE-Lite（单向 snoop） | RN-I（可被 snoop，无缓存） |
| **DMA 一致性** | ACE-Lite | RN-D（无 snoop 能力） |
| **WriteNoSnp** | 不存在（所有写都需要 snoop） | 原生支持（已知无副本时跳过 snoop） |
| **Stash 操作** | 不支持 | 支持（数据推送到指定 RN 缓存） |
| **DVM 操作** | 支持（通过 AC 通道） | 支持（通过 REQ 通道） |
| **链路层** | 无（基于 AXI 握手） | 有（Credit-based 流控，支持 Retry） |
| **互联拓扑** | 主要交叉开关 | 网络 (NoC)、交叉开关、环形等 |
| **典型节点数** | ≤ 8-16 RN | 数十个至数百个 RN |

---

## 9. CHI-B/C/D 新特性

### 9.1 CHI-B 新特性

| 特性 | 说明 |
|------|------|
| **Distributed Snoop Filter (DSF)** | HN 可使用分布式 snoop filter 替代集中式 directory，降低面积 |
| **MPAM** (Memory System Resource Partitioning and Monitoring) | 内存系统资源分区和监控，支持 QoS |
| **增强 Ordering 模型** | 显式 Endpoint Order / Request Order，替代 ACE 的隐式 ordering |
| **Persist 事务** | WriteNoSnpPtl 携带 Persist 标记，确保写入持久化 |
| **Stash 事务增强** | StashOnceShared / StashOnceUnique |
| **独立 Link Layer** | Credit-based 流控独立于 Transaction Layer |

### 9.2 CHI-C 新特性

| 特性 | 说明 |
|------|------|
| **PBR** (Persistent Buffer Requirements) | 持久化缓冲要求，确保写入在断电前到达 SN |
| **WriteNoSnpPtl 增强** | 更细粒度的部分写入支持 |
| **Stash 事务增强** | StashOnceSepShared / StashOnceSepUnique（数据和 snoop 分离） |
| **Endpoint Persist** | 端点持久化保证 |
| **CMO 增强** | Cache Maintenance Operations by VA |
| **MPAM 增强** | 更多 MPAM 分区字段 |

### 9.3 CHI-D 新特性

| 特性 | 说明 |
|------|------|
| **IDE** (Integrity and Data Encryption) | 数据完整性和加密，防止总线嗅探和篡改 |
| **IDE 扩展** | REQ/RSP/SNP/DAT 通道均可加密 |
| **MPAM 增强** | Extended MPAM，支持更多分区和监控维度 |
| **CHI-to-AXI Bridge 增强** | 改进的 CHI-AXI 协议转换桥 |
| **Endpoint Persist 增强** | 更完善的持久化保证模型 |
| **Trusted Address Space** | 可信地址空间隔离 |

---

## 10. 设计注意事项

### 10.1 CHI 互联设计核心要素

#### 10.1.1 HN 一致性管理策略

| 策略 | 说明 | 面积 | 延迟 | 适用场景 |
|------|------|------|------|---------|
| **Snoop Filter** | 记录每个地址被哪些 RN 缓存 | 中 | 低 | 中等规模系统 |
| **Full Directory** | 记录每个地址的所有 RN 状态 | 高 | 低 | 大规模系统 |
| **Bloom Filter** | 近似记录，可能有假阳性 | 低 | 低 | 面积敏感设计 |
| **Broadcast** | 向所有 RN 广播 snoop | 低 | 高 | 小规模系统 |

**Snoop Filter 设计要点**：
- 容量：通常按 cache 容量的 1/8 至 1/16 设置
- 关联度：组相联或全相联
- 替换策略：LRU 或近似 LRU
- 需要考虑 alias 问题（不同 VA 映射到同一 PA）

#### 10.1.2 通道路由设计

```
REQ 路由：RN → HN（基于地址解码到目标 HN）
SNP 路由：HN → RN（基于 snoop filter / directory 查表）
RSP 路由：RN → HN 或 HN → RN（基于 TxnID 关联）
DAT 路由：双向，基于 TxnID 关联 + 数据转发路径
```

**路由设计关键点**：
- REQ 通道路由基于地址，需要地址解码逻辑
- SNP 通道路由基于一致性目录查找结果
- DAT 通道支持直接转发（RN → RN），减少 HN 中转延迟
- 需要考虑多 HN 系统的地址交织

#### 10.1.3 Ordering 逻辑

CHI 定义了三种 Ordering 模式：

| 模式 | 说明 | 保证范围 |
|------|------|---------|
| **Endpoint Order** | 同一 RN 的事务按发出顺序到达 SN | 请求发出顺序 |
| **Request Order** | HN 保证同一 RN 的请求按序处理 | HN 处理顺序 |
| **No Order** | 无序，软件负责一致性 | 无 |

**Ordering 实现要点**：
- HN 内部需要 per-RN 请求队列
- 同一地址的访问需要串行化（地址冲突检测）
- 不同地址的访问可以并行处理

#### 10.1.4 Retry 机制

```
  RN                  HN
   |                   |
   |-- ReadShared ---->|
   |                   | (HN 资源不足)
   |<-- RetryAck ------|
   |                   |
   |                   | (一段时间后)
   |<-- PCrdGrant -----|
   |                   |
   |-- ReadShared ---->|
   |  (携带 PCrdType)   |
   |<-- CompData ------|
```

**Retry 设计要点**：
- HN 在资源不足时返回 RetryAck，不阻塞通道
- RN 保存事务上下文，等待 PCrdGrant 后重发
- 需要管理 per-channel 的 credit 池
- 避免活锁：设置重试超时和优先级提升

### 10.2 CHI 与 AXI 外设桥接

CHI-to-AXI Bridge 设计要点：

| 项目 | 说明 |
|------|------|
| ReadOnce → AR | ReadOnce 映射为 AXI AR 通道读请求 |
| WriteNoSnp → AW+W | WriteNoSnp 映射为 AXI 写事务 |
| Atomic → AR+AW | 原子操作需要 AXI Lock 支持或软件模拟 |
| Response 映射 | CHI CompResp 映射为 AXI RRESP/BRESP |
| Ordering 适配 | CHI Endpoint Order 映射为 AXI 读写顺序保证 |
| Outstanding | 桥接模块需要缓存未完成事务的上下文 |

### 10.3 SN 接口与 DDR 控制器

| 项目 | 说明 |
|------|------|
| SN-F 接口 | 直接连接 DDR 控制器，使用 CHI SN 协议 |
| 地址映射 | 需要地址交织和 bank 管理 |
| 写合并 | SN 前端可做 WriteNoSnp 的写合并 |
| 读重排序 | SN 可以对不同地址的读请求重排序 |
| 持久化 | SN-F 支持 Persist 操作（CHI-C/D） |
| 性能监控 | SN 端可集成 MPAM 计数器 |

### 10.4 常见设计陷阱

| 陷阱 | 后果 | 规避方法 |
|------|------|---------|
| Snoop Filter 与实际缓存状态不一致 | 一致性破坏 | 使用 snoop 作为状态更新的唯一途径 |
| Retry 导致活锁 | 系统挂起 | 设置重试优先级提升机制 |
| DAT 通道死锁 | 互联挂起 | 独立 credit 管理，避免循环依赖 |
| 地址交织错误 | 数据写入错误位置 | 严格验证地址解码逻辑 |
| 跨 HN 地址边界的访问 | 部分写入丢失 | 确保 cache line 对齐 |
| Order 逻辑过于严格 | 性能下降 | 只在必要时使用 Endpoint Order |
| Stash 目标 RN 不存在 | 事务超时 | HN 验证 StashNID 有效性 |
| Snoop 数据转发丢失 | 数据不一致 | 确保转发路径完整性和重试机制 |

### 10.5 验证关键场景

| 场景 | 说明 | 优先级 |
|------|------|--------|
| 同地址并发访问 | 多 RN 同时读写同一 cache line | Critical |
| 缓存替换竞态 | 替换过程中收到 snoop | Critical |
| Retry 流程 | 资源不足时的 retry 和重发 | High |
| Snoop 数据转发 | RN-to-RN 直接数据传输 | High |
| 原子操作 | AtomicLoad / AtomicCompare 的原子性 | High |
| 写持久化 | WriteBack 到 SN-F 的持久化保证 | Medium |
| 死锁/活锁 | 通道 credit 耗尽和恢复 | Critical |
| 边界条件 | 最大 outstanding 数、地址边界 | High |
| CHI-AXI 桥接 | 协议转换的正确性和性能 | Medium |
| DVM 操作 | TLB invalidation 广播 | Medium |
