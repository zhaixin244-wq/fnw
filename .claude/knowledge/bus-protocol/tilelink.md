# TileLink 总线协议

> **适用读者**：数字 IC 架构师、SoC 总线设计工程师
> **协议版本**：TileLink Spec v1.8（UC Berkeley）
> **文档目标**：提供架构师所需的通道定义、消息类型、缓存一致性流程参考

---

## 1. 协议概述

TileLink 是由 UC Berkeley 开发的片上互联总线协议，是 RISC-V 生态（Rocket Chip / BOOM / Chipyard）的标准互联方案。协议采用分层设计，提供三个兼容级别：

| 级别 | 全称 | 缓存一致性 | 典型用途 |
|------|------|-----------|----------|
| **TL-UL** | TileLink Uncached Lightweight | 不支持 | 外设寄存器访问、简单从设备 |
| **TL-UH** | TileLink Uncached Heavyweight | 不支持 | 高性能 DMA、无缓存数据搬运 |
| **TL-C** | TileLink Cached | 支持（MESI-like） | CPU L1/L2 缓存、一致性域 |

三个级别向下兼容：TL-C master 可与 TL-UH/TL-UL slave 通信，TL-UH master 可与 TL-UL slave 通信。

**核心特性**：
- 基于消息的传输协议（非地址/数据分离，每个事务是一条消息）
- 支持 Outstanding 事务（多笔未完成请求并行）
- 支持 Burst 传输（Block 操作）
- 片上协议，无信号极性/三态等板级约束
- 通道独立的 Valid/Ready 流控

---

## 2. 协议层级对比

| 特性 | TL-UL | TL-UH | TL-C |
|------|-------|-------|------|
| 通道 | A, D | A, B, C, D | A, B, C, D, E |
| 缓存一致性 | 无 | 无 | 完整 MESI-like |
| 支持操作 | Get, Put | Get, Put, Atomic, Intent, Block | + Acquire, Probe, Release, Grant |
| Burst/Block | 无 | 支持（GetBlock/PutBlock） | 支持 |
| 原子操作 | 不支持 | 支持（Arithmetic/Logical） | 支持 |
| Hint/Intent | 不支持 | 支持（Prefetch 等） | 支持 |
| Outstanding | 支持 | 支持 | 支持 |
| 数据位宽 | 参数化 | 参数化 | 参数化 |
| 典型 Master | 简单外设 | DMA 控制器 | CPU Cache |
| 典型 Slave | 寄存器 | SRAM、片上存储 | Cache Controller |

---

## 3. 通道结构

TileLink 由最多五个独立通道组成，每个通道独立握手。通道间无时序依赖（可在不同周期完成）。

### 3.1 A 通道（Client → Manager）

A 通道承载从 Client（Master）到 Manager（Slave）的请求。

**TL-UL 信号**：

| 信号 | 位宽 | 描述 |
|------|------|------|
| `a_opcode` | 3 | 操作码 |
| `a_param` | 4 | 操作参数（子操作） |
| `a_size` | `size_width` | 传输大小（2^n bytes） |
| `a_source` | `source_width` | 事务源 ID（用于 Outstanding 匹配） |
| `a_address` | `address_width` | 目标地址 |
| `a_mask` | `data_width/8` | 字节掩码（Put 操作） |
| `a_data` | `data_width` | 写入数据 |
| `a_corrupt` | 1 | 数据是否损坏（ECC 错误） |
| `a_valid` | 1 | Valid 握手 |
| `a_ready` | 1 | Ready 握手 |

**TL-UH 额外信号**：

| 信号 | 位宽 | 描述 |
|------|------|------|
| `a_user` | `user_width` | 用户自定义字段 |

**A 通道操作码**：

| Opcode | 值 | 消息 | TL 级别 | 描述 |
|--------|-----|------|---------|------|
| PutFullData | 3'b000 | 0 | UL/UH/C | 全字写入（所有 mask bit 有效） |
| PutPartialData | 3'b001 | 1 | UL/UH/C | 部分字写入（mask 选通） |
| ArithmeticData | 3'b010 | 2 | UH/C | 原子算术操作 |
| LogicalData | 3'b011 | 3 | UH/C | 原子逻辑操作 |
| Get | 3'b100 | 4 | UL/UH/C | 读取请求 |
| Intent | 3'b101 | 5 | UH/C | Hint 操作（Prefetch 等） |
| AcquireBlock | 3'b110 | 6 | C | 获取缓存块并缓存 |
| AcquirePerm | 3'b111 | 7 | C | 获取缓存块权限（不需数据） |

### 3.2 B 通道（Manager → Client）

B 通道承载 Manager 到 Client 的反向请求，仅 TL-UH 和 TL-C 使用。

| 信号 | 位宽 | 描述 |
|------|------|------|
| `b_opcode` | 3 | 操作码 |
| `b_param` | 4 | 操作参数 |
| `b_size` | `size_width` | 传输大小 |
| `b_source` | `source_width` | 事务源 ID |
| `b_address` | `address_width` | 目标地址 |
| `b_mask` | `data_width/8` | 字节掩码 |
| `b_data` | `data_width` | 数据 |
| `b_corrupt` | 1 | 数据是否损坏 |
| `b_valid` | 1 | Valid 握手 |
| `b_ready` | 1 | Ready 握手 |

**B 通道操作码**：

| Opcode | 值 | 消息 | 描述 |
|--------|-----|------|------|
| PutFullData | 3'b000 | 0 | Manager 写 Client（全字） |
| PutPartialData | 3'b001 | 1 | Manager 写 Client（部分字） |
| ArithmeticData | 3'b010 | 2 | Manager 发起原子算术 |
| LogicalData | 3'b011 | 3 | Manager 发起原子逻辑 |
| Get | 3'b100 | 4 | Manager 读 Client |
| Intent | 3'b101 | 5 | Manager 发 Hint |
| ProbeBlock | 3'b110 | 6 | 缓存探测（要求返回数据） |
| ProbePerm | 3'b111 | 7 | 缓存探测（仅返回权限） |

### 3.3 C 通道（Client → Manager）

C 通道承载 Client 到 Manager 的响应/释放消息，TL-UH 和 TL-C 使用。

| 信号 | 位宽 | 描述 |
|------|------|------|
| `c_opcode` | 3 | 操作码 |
| `c_param` | 4 | 操作参数 |
| `c_size` | `size_width` | 传输大小 |
| `c_source` | `source_width` | 事务源 ID |
| `c_address` | `address_width` | 地址 |
| `c_data` | `data_width` | 数据（ReleaseData/ProbeAckData） |
| `c_corrupt` | 1 | 数据是否损坏 |
| `c_dirty` | 1 | 数据是否为 Dirty 状态 |
| `c_valid` | 1 | Valid 握手 |
| `c_ready` | 1 | Ready 握手 |

**C 通道操作码**：

| Opcode | 值 | 消息 | 描述 |
|--------|-----|------|------|
| AccessAck | 3'b000 | 0 | 对 Get/Put 的应答（无数据） |
| AccessAckData | 3'b001 | 1 | 对 Get 的数据应答 |
| HintAck | 3'b010 | 2 | 对 Intent 的应答 |
| ProbeAck | 3'b100 | 4 | 对 Probe 的应答（无数据，权限已降级） |
| ProbeAckData | 3'b101 | 5 | 对 Probe 的应答（含脏数据回写） |
| Release | 3'b110 | 6 | Client 主动释放缓存块（无数据） |
| ReleaseData | 3'b111 | 7 | Client 主动释放缓存块（含脏数据回写） |

### 3.4 D 通道（Manager → Client）

D 通道承载 Manager 到 Client 的响应/授予消息。

| 信号 | 位宽 | 描述 |
|------|------|------|
| `d_opcode` | 3 | 操作码 |
| `d_param` | 4 | 操作参数 |
| `d_size` | `size_width` | 传输大小 |
| `d_source` | `source_width` | 原始事务源 ID（回传匹配） |
| `d_sink` | `sink_width` | Manager 端 Sink ID（Grant 用） |
| `d_denied` | 1 | 事务是否被拒绝 |
| `d_data` | `data_width` | 读取数据 |
| `d_corrupt` | 1 | 数据是否损坏 |
| `d_valid` | 1 | Valid 握手 |
| `d_ready` | 1 | Ready 握手 |

**D 通道操作码**：

| Opcode | 值 | 消息 | 描述 |
|--------|-----|------|------|
| AccessAck | 3'b000 | 0 | 对 Put 的应答（无数据） |
| AccessAckData | 3'b001 | 1 | 对 Get 的数据应答 |
| HintAck | 3'b010 | 2 | 对 Intent 的应答 |
| Grant | 3'b100 | 4 | 缓存权限授予（无数据） |
| GrantData | 3'b101 | 5 | 缓存权限授予（含数据） |
| ReleaseAck | 3'b110 | 6 | 对 Release 的确认 |

### 3.5 E 通道（Client → Manager）

E 通道仅用于 TL-C，承载 GrantAck 消息，完成一致性事务。

| 信号 | 位宽 | 描述 |
|------|------|------|
| `e_sink` | `sink_width` | 匹配 D 通道 Grant 的 Sink ID |
| `e_valid` | 1 | Valid 握手 |
| `e_ready` | 1 | Ready 握手 |

**E 通道操作码**：

| Opcode | 值 | 消息 | 描述 |
|--------|-----|------|------|
| GrantAck | - | - | 对 Grant 的确认（完成一致性转移） |

### 3.6 各级别通道汇总

| 通道 | 方向 | TL-UL | TL-UH | TL-C |
|------|------|-------|-------|------|
| A | Client → Manager | **支持** | **支持** | **支持** |
| B | Manager → Client | - | **支持** | **支持** |
| C | Client → Manager | - | **支持** | **支持** |
| D | Manager → Client | **支持** | **支持** | **支持** |
| E | Client → Manager | - | - | **支持** |

---

## 4. 握手规则

TileLink 使用与 AXI 相同的 Valid/Ready 握手机制：

**规则 1：Valid 信号稳定性**
- 源端拉高 `valid` 后，必须保持为高，直到握手完成（`valid && ready`）
- `valid` 不能依赖 `ready` 的组合逻辑（防止组合环路）

**规则 2：Ready 信号行为**
- `ready` 可以依赖 `valid`（推荐）
- `ready` 可以在 `valid` 之前或之后拉高

**规则 3：握手完成**
- 传输在 `valid && ready` 同时为高的时钟上升沿完成
- 与 AXI 完全一致

```
        ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐
clk     │   │   │   │   │   │   │   │   │   │
    ────┘   └───┘   └───┘   └───┘   └───┘   └───

        ┌───────────────────┐
valid   │                   │
    ────┘                   └───────────────────

                    ┌───────┐
ready   ────────────┘       └───────────────────

                    ‖
              handshake (data transferred here)
```

**通道独立性**：A/B/C/D/E 五个通道独立握手，无跨通道时序依赖。例如 D 通道的 AccessAck 可以在 A 通道的 Get 握手之前、同时或之后发生。

**Outstanding 事务**：通过 `source` 字段匹配请求-响应对。Client 分配唯一 `source` ID，Manager 在 D 通道响应中回传相同 `source`。Client 可并发发出多笔不同 `source` 的请求。

---

## 5. 消息类型编码表

### 5.1 A 通道 Opcode

| 编码 | 名称 | 参数位宽 | 适用级别 | 说明 |
|------|------|----------|----------|------|
| 3'b000 | PutFullData | a_param = 0 | UL/UH/C | 全字写 |
| 3'b001 | PutPartialData | a_param = 0 | UL/UH/C | 部分字写（mask 选通） |
| 3'b010 | ArithmeticData | a_param[2:0] | UH/C | 原子操作 |
| 3'b011 | LogicalData | a_param[2:0] | UH/C | 逻辑原子操作 |
| 3'b100 | Get | a_param = 0 | UL/UH/C | 读请求 |
| 3'b101 | Intent | a_param[1:0] | UH/C | Hint 操作 |
| 3'b110 | AcquireBlock | a_param[2:0] | C | 获取块+数据 |
| 3'b111 | AcquirePerm | a_param[2:0] | C | 获取权限 |

**ArithmeticData a_param 编码**：

| 值 | 操作 | 说明 |
|----|------|------|
| 3'b000 | MIN | 有符号最小值 |
| 3'b001 | MAX | 有符号最大值 |
| 3'b010 | MINU | 无符号最小值 |
| 3'b011 | MAXU | 无符号最大值 |
| 3'b100 | ADD | 加法 |

**LogicalData a_param 编码**：

| 值 | 操作 |
|----|------|
| 3'b000 | XOR |
| 3'b001 | OR |
| 3'b010 | AND |
| 3'b011 | SWAP |

**Intent a_param 编码**：

| 值 | 操作 | 说明 |
|----|------|------|
| 2'b00 | PrefetchRead | 预取（读后可丢弃） |
| 2'b01 | PrefetchWrite | 预取（写后可丢弃） |

**Acquire a_param 编码**：

| 值 | 请求权限 | 说明 |
|----|----------|------|
| 3'b000 | NtoB | None → Branch（只读共享） |
| 3'b001 | NtoT | None → Tip（独占读写） |
| 3'b010 | BtoT | Branch → Tip（升级为独占） |

### 5.2 B 通道 Opcode

| 编码 | 名称 | 说明 |
|------|------|------|
| 3'b000 | PutFullData | Manager 写 Client |
| 3'b001 | PutPartialData | Manager 部分写 Client |
| 3'b010 | ArithmeticData | Manager 发起原子操作 |
| 3'b011 | LogicalData | Manager 发起逻辑原子 |
| 3'b100 | Get | Manager 读 Client |
| 3'b101 | Intent | Manager 发 Hint |
| 3'b110 | ProbeBlock | 探测缓存块（要求返回数据） |
| 3'b111 | ProbePerm | 探测缓存块（仅降级权限） |

**Probe b_param 编码**：

| 值 | 操作 | 说明 |
|----|------|------|
| 3'b000 | toN | 降级到 None（收回全部权限） |
| 3'b001 | toB | 降级到 Branch（保留只读） |
| 3'b010 | toT | 降级到 Tip（很少使用） |

### 5.3 C 通道 Opcode

| 编码 | 名称 | 说明 |
|------|------|------|
| 3'b000 | AccessAck | 对 B 通道请求的应答（无数据） |
| 3'b001 | AccessAckData | 对 B 通道请求的数据应答 |
| 3'b010 | HintAck | 对 B 通道 Intent 的应答 |
| 3'b011 | 保留 | - |
| 3'b100 | ProbeAck | Probe 应答（无数据） |
| 3'b101 | ProbeAckData | Probe 应答（含脏数据） |
| 3'b110 | Release | Client 释放缓存块（无数据） |
| 3'b111 | ReleaseData | Client 释放缓存块（含脏数据） |

**ProbeAck/Release c_param 编码**：

| 值 | 报告权限 | 说明 |
|----|----------|------|
| 3'b000 | TtoB | Tip → Branch（降级但仍共享） |
| 3'b001 | TtoN | Tip → None（全部释放） |
| 3'b010 | BtoN | Branch → None（释放共享） |
| 3'b011 | TtoT | Tip → Tip（报告但不降级） |
| 3'b100 | BtoB | Branch → Branch（报告但不降级） |
| 3'b101 | NtoN | None → None（无副本，报告 miss） |

### 5.4 D 通道 Opcode

| 编码 | 名称 | 说明 |
|------|------|------|
| 3'b000 | AccessAck | 对 A 通道 Put 的确认 |
| 3'b001 | AccessAckData | 对 A 通道 Get 的数据返回 |
| 3'b010 | HintAck | 对 A 通道 Intent 的确认 |
| 3'b011 | 保留 | - |
| 3'b100 | Grant | 授予缓存权限（无数据） |
| 3'b101 | GrantData | 授予缓存权限（含数据） |
| 3'b110 | ReleaseAck | 对 Release 的确认 |
| 3'b111 | 保留 | - |

**Grant d_param 编码**：

| 值 | 授权权限 | 说明 |
|----|----------|------|
| 3'b000 | toB | 授予 Branch 权限 |
| 3'b001 | toT | 授予 Tip 权限 |
| 3'b010 | toN | 授予 None（用于 NtoN 的 ReleaseAck 场景） |

### 5.5 E 通道

E 通道仅有一个消息：`GrantAck`。无 opcode 字段，仅靠 `e_sink` 匹配 D 通道的 `d_sink`。

---

## 6. 基本读写事务流程

### 6.1 Get（读）事务 — TL-UL

```
Client (A channel)              Manager (D channel)
    │                               │
    │── PutFullData/Get ───────────>│  A: Get(addr, source=S0, size=4B)
    │   valid=1, ready=1           │
    │                               │
    │                               │  (Manager 查找数据)
    │                               │
    │<──────── AccessAckData ──────│  D: AccessAckData(source=S0, data=...)
    │   valid=1, ready=1           │
    │                               │
    事务完成                         事务完成
```

### 6.2 PutFullData（写）事务 — TL-UL

```
Client (A channel)              Manager (D channel)
    │                               │
    │── PutFullData ───────────────>│  A: PutFullData(addr, source=S0, data=..., mask=0xFF)
    │   valid=1, ready=1           │
    │                               │
    │                               │  (Manager 写入数据)
    │                               │
    │<──────── AccessAck ──────────│  D: AccessAck(source=S0)
    │   valid=1, ready=1           │
    │                               │
    事务完成                         事务完成
```

### 6.3 PutPartialData（部分写）事务 — TL-UL

```
Client (A channel)              Manager (D channel)
    │                               │
    │── PutPartialData ────────────>│  A: PutPartialData(addr, source=S1, data=0xABCD, mask=0x03)
    │   valid=1, ready=1           │
    │                               │
    │<──────── AccessAck ──────────│  D: AccessAck(source=S1)
    │                               │
    事务完成
```

### 6.4 Outstanding 事务示例

```
Client                                  Manager
    │                                       │
    │── Get(addr0, src=S0) ───────────────>│
    │── Get(addr1, src=S1) ───────────────>│   两笔并发
    │── Get(addr2, src=S2) ───────────────>│
    │                                       │
    │<── AccessAckData(src=S1, data1) ─────│   响应可乱序
    │<── AccessAckData(src=S0, data0) ─────│
    │<── AccessAckData(src=S2, data2) ─────│
```

---

## 7. 缓存一致性流程（TL-C）

### 7.1 Acquire 流程（Client 请求缓存权限）

Client 需要缓存某个地址的数据，向 Manager 发送 Acquire 请求。

**AcquireBlock NtoT（获取独占权限 + 数据）**：

```
Client                                      Manager
    │                                           │
    │── A: AcquireBlock(NtoT, addr, src=S0) ──>│   Client 请求独占
    │                                           │
    │   (Manager 可能需要先 Probe 其他 Client)    │
    │                                           │
    │<── D: GrantData(toT, src=S0, sink=K0) ───│   Manager 授予权限+数据
    │                                           │
    │── E: GrantAck(sink=K0) ─────────────────>│   Client 确认
    │                                           │
    Client 持有 Tip 权限                         事务完成
```

**AcquireBlock NtoB（获取共享权限 + 数据）**：

```
Client                                      Manager
    │                                           │
    │── A: AcquireBlock(NtoB, addr, src=S1) ──>│   Client 请求共享
    │                                           │
    │<── D: GrantData(toB, src=S1, sink=K1) ───│   Manager 授予共享+数据
    │                                           │
    │── E: GrantAck(sink=K1) ─────────────────>│   Client 确认
    │                                           │
    Client 持有 Branch 权限                      事务完成
```

**AcquirePerm BtoT（权限升级，已有共享数据）**：

```
Client                                      Manager
    │                                           │
    │── A: AcquirePerm(BtoT, addr, src=S2) ──>│   Client 已有 Branch，升级 Tip
    │                                           │
    │   (Manager 先 Probe 其他 Client 收回副本)   │
    │                                           │
    │<── D: Grant(toT, src=S2, sink=K2) ───────│   仅授予权限，无数据
    │                                           │
    │── E: GrantAck(sink=K2) ─────────────────>│   Client 确认
    │                                           │
    Client 持有 Tip 权限                         事务完成
```

### 7.2 Probe 流程（Manager 回收/降级 Client 权限）

Manager 需要回收某个 Client 的缓存权限（因为另一个 Client 请求独占权）。

**ProbeBlock toN（强制收回）**：

```
Manager                                     Client
    │                                           │
    │── B: ProbeBlock(toN, addr, src=M0) ─────>│   Manager 要求收回
    │                                           │
    │   (Client 写回脏数据，降级权限)              │
    │                                           │
    │<── C: ProbeAckData(TtoN, addr, src=M0) ──│   Client 返回脏数据+释放
    │                                           │
    Client 权限降为 None                          事务完成
```

**ProbeBlock toB（降级为共享）**：

```
Manager                                     Client
    │                                           │
    │── B: ProbeBlock(toB, addr, src=M1) ─────>│   Manager 要求降级
    │                                           │
    │<── C: ProbeAck(TtoB, addr, src=M1) ──────│   Client 降级（无脏数据）
    │                                           │
    Client 权限降为 Branch                        事务完成
```

**ProbeBlock toB（有脏数据需回写）**：

```
Manager                                     Client
    │                                           │
    │── B: ProbeBlock(toB, addr, src=M2) ─────>│   Manager 要求降级
    │                                           │
    │<── C: ProbeAckData(TtoB, addr, src=M2) ──│   Client 回写脏数据，保留 Branch
    │                                           │
    Client 权限降为 Branch                        事务完成
```

### 7.3 Release 流程（Client 主动释放缓存块）

Client 出于替换策略（eviction）主动释放缓存块。

**ReleaseData（含脏数据回写）**：

```
Client                                      Manager
    │                                           │
    │── C: ReleaseData(TtoN, addr, src=S3, ──>│   Client 主动释放
    │              data=dirty_data)             │
    │                                           │
    │<── D: ReleaseAck(src=S3) ────────────────│   Manager 确认
    │                                           │
    Client 权限降为 None                          事务完成
```

**Release（无脏数据）**：

```
Client                                      Manager
    │                                           │
    │── C: Release(BtoN, addr, src=S4) ──────>│   Client 释放共享副本
    │                                           │
    │<── D: ReleaseAck(src=S4) ────────────────│   Manager 确认
    │                                           │
    Client 权限降为 None                          事务完成
```

### 7.4 完整一致性事务：两 Client 竞争同一块

Client A 持有 Tip 权限（脏数据），Client B 请求独占：

```
Client A                    Manager                    Client B
    │                           │                           │
    │                           │<── A: AcquireBlock(NtoT)──│  B 请求独占
    │                           │                           │
    │<── B: ProbeBlock(toN) ───│                           │  Manager 探测 A
    │                           │                           │
    │── C: ProbeAckData ──────>│                           │  A 回写脏数据+释放
    │   (TtoN, dirty data)      │                           │
    │                           │                           │
    │                      (Manager 更新内存)                │
    │                           │                           │
    │                           │── D: GrantData(toT) ─────>│  Manager 授予 B
    │                           │    (updated data)         │
    │                           │                           │
    │                           │<── E: GrantAck ──────────│  B 确认
    │                           │                           │
                               事务完成                     B 持有 Tip
```

---

## 8. 权限模型

TileLink 缓存一致性使用四级权限模型：

| 权限 | 值 | 读 | 写 | 说明 |
|------|-----|----|----|------|
| **None** | 2'b00 | 否 | 否 | 无本地副本 |
| **Branch** | 2'b01 | 是 | 否 | 只读共享副本（可多 Client 共存） |
| **Trunk** | 2'b10 | 是 | 否 | 未定义行为——实际规范中未使用 |
| **Dirty (Tip)** | 2'b11 | 是 | 是 | 独占读写（全局唯一副本） |

> 注：规范中 Tip = 拥有最新数据的独占权限。某些实现将 Tip 编码为 Trunk+Dirty 组合。常用表述为 Branch/Trunk/Dirty/Tip 四级。

### 权限状态转移图

```
                  ┌───────────────────────────────────┐
                  │           Manager 主导              │
                  │  (Probe: toN / toB / toT)          │
                  │  (Grant: toB / toT)                │
                  │                                     │
                  │                                     │
    ┌─────────────┴──┐       Probe(toB)       ┌────────┴───────┐
    │                │◄───────────────────────│                │
    │     None       │                        │    Branch      │
    │   (无副本)      │       Probe(toN)       │  (只读共享)     │
    │                │◄───────────────────────│                │
    └───┬───────┬────┘                        └───┬────────┬───┘
        │       │                                 │        │
        │ Acq   │ Acq                             │ Acq    │ Probe
        │ NtoB  │ NtoT                            │ BtoT   │ toN
        │       │                                 │        │
        ▼       │                                 ▼        │
    ┌───────────┴──┐                        ┌────┴──────────┴──┐
    │   Branch     │                        │                  │
    │  (只读共享)   │                        │     Tip          │
    │              │                        │  (独占读写)       │
    └──────────────┘                        │                  │
                  ▲                         └──────────────────┘
                  │                                │    ▲
                  │             Probe(toB/toN)     │    │
                  │             Release(TtoN)      │    │ Acq
                  │             ProbeAck(TtoB/N)   │    │ NtoT
                  └────────────────────────────────┘    │
                                                        │
                                              Client 主导释放/请求
```

**转移条件汇总**：

| 当前权限 | 操作 | 条件 | 结果权限 | 发起方 |
|----------|------|------|----------|--------|
| None | AcquireBlock NtoB | - | Branch | Client |
| None | AcquireBlock NtoT | - | Tip | Client |
| None | AcquirePerm NtoT | 已有数据 | Tip | Client |
| Branch | AcquirePerm BtoT | - | Tip | Client |
| Branch | Probe toN | Manager 需要 | None | Manager |
| Tip | Probe toB | 其他 Client 需读 | Branch | Manager |
| Tip | Probe toN | 其他 Client 需写 | None | Manager |
| Tip | ReleaseData TtoN | Eviction | None | Client |
| Tip | Release TtoN | Eviction（无脏数据） | None | Client |
| Branch | Release BtoN | Eviction | None | Client |

---

## 9. 地址空间

### 9.1 Manager ID 与地址映射

TileLink 使用 Manager ID + 地址来定位目标设备。系统全局维护一个地址映射表：

| Manager ID | 地址范围 | 大小 | 设备类型 |
|------------|----------|------|----------|
| 0 | 0x0000_0000 - 0x0FFF_FFFF | 256 MB | 片上 SRAM |
| 1 | 0x1000_0000 - 0x1000_0FFF | 4 KB | UART |
| 2 | 0x1000_1000 - 0x1000_1FFF | 4 KB | SPI |
| 3 | 0x2000_0000 - 0x2FFF_FFFF | 256 MB | DDR（可缓存） |
| 4 | 0x3000_0000 - 0x3000_0FFF | 4 KB | CLINT |
| 5 | 0x3000_1000 - 0x3000_1FFF | 4 KB | PLIC |

### 9.2 地址参数化

TileLink 地址宽度通过参数化定义：

```verilog
parameter ADDRESS_WIDTH = 32;   // 地址位宽，通常 32 或 64
parameter DATA_WIDTH    = 64;   // 数据位宽，通常 32/64/128/256
parameter SOURCE_WIDTH  = 4;    // 源 ID 位宽，决定 outstanding 深度
parameter SINK_WIDTH    = 3;    // Sink ID 位宽，TL-C Grant 匹配
parameter SIZE_WIDTH    = 4;    // 传输大小位宽，2^SIZE bytes
```

### 9.3 地址对齐

- 传输大小由 `a_size` 决定：实际大小 = `2^a_size` bytes
- 地址必须按传输大小对齐
- Block 操作（GetBlock/PutBlock）的大小由系统参数 `block_size` 决定（通常 64 bytes，即 cache line）

---

## 10. 与 AXI4 / CHI 对比

| 特性 | TileLink | AXI4 | CHI (AMBA) |
|------|----------|------|------------|
| **开发者** | UC Berkeley | Arm | Arm |
| **典型生态** | RISC-V (Rocket/BOOM) | ARM Cortex / 通用 SoC | ARM DynamIQ / 大型 SoC |
| **通道数** | 5 (A/B/C/D/E) | 5 (AR/AW/R/W/B) | 6 (REQ/RSP/SNP/DAT) + |
| **缓存一致性** | TL-C 完整支持 | 需 ACE/CHI 扩展 | 原生支持 |
| **一致性粒度** | 缓存行级 | 缓存行级 (ACE) | 缓存行级 |
| **一致性协议** | 类 MESI (Branch/Tip) | MESI (ACE) | MOESI (Snoop) |
| **原子操作** | 原生支持 (UH/C) | 原生支持 (AXI4) | 原生支持 |
| **消息类型** | 基于消息（opcode） | 基于通道分离 | 基于消息（opcode） |
| **Burst 传输** | Block 操作 | INCR/WRAP | 支持 |
| **QoS** | 无原生支持 | AxQOS[3:0] | QoS 支持 |
| **Ordering** | 无排序保证 | 可选排序 | 灵活排序模型 |
| **Outstanding** | 无限制（source ID） | 无限制（ID） | 无限制 |
| **复杂度** | 中等 | 低（UL/UH）/ 高（C） | 高 |
| **适用场景** | RISC-V 片上互联 | 通用 SoC 互联 | 大规模多核 SoC |
| **桥接** | TileLink↔AXI 桥可用 | - | CHI↔AXI 桥可用 |

### 关键差异总结

- **TileLink vs AXI4**：AXI4 是通道-地址分离模型（AR/AW 通道发地址，R/W 通道传数据），TileLink 是消息模型（每笔事务携带完整信息）。AXI4 本身不支持缓存一致性，需要 ACE 扩展。TileLink TL-C 原生支持一致性。
- **TileLink vs CHI**：CHI 是 Arm 面向大规模多核的一致性协议，支持 Snoop Filter、目录结构等高级特性。TileLink 更轻量，适合中小规模 RISC-V 多核。CHI 协议复杂度显著高于 TileLink。

---

## 11. 设计注意事项

### 11.1 RISC-V SoC 集成

**Rocket Chip / BOOM 集成**：
- Rocket Chip 默认使用 TileLink 作为内部互联
- 外部设备通过 TileLink-to-AXI4 桥接器连接
- System Bus（TL） → Periphery Bus（TL） → 外设桥（AXI/APB）是典型拓扑

**典型 SoC 拓扑**：

```
┌──────────┐  ┌──────────┐
│  Core 0  │  │  Core 1  │  (TL-C)
│  L1 Cache│  │  L1 Cache│
└────┬─────┘  └────┬─────┘
     │              │
┌────┴──────────────┴────┐
│    L2 Cache / Coherence │  (TL-C Manager)
│    Manager              │
└────────┬────────────────┘
         │ System Bus (TileLink)
    ┌────┴────┬──────────┬──────────┐
    │         │          │          │
┌───┴──┐ ┌───┴──┐  ┌────┴───┐ ┌───┴───┐
│ SRAM │ │ DDR  │  │ TL→AXI │ │ CLINT │
│      │ │ Ctrl │  │  Bridge │ │ PLIC  │
└──────┘ └──────┘  └───┬────┘ └───────┘
                       │ AXI4
                  ┌────┴────┐
                  │ 外设总线  │
                  │ UART/SPI│
                  │ GPIO    │
                  └─────────┘
```

### 11.2 TL-to-AXI4 桥接方案

**读事务映射**：

| TileLink | AXI4 | 说明 |
|----------|------|------|
| Get | AR channel | a_addr → araddr, a_size → arsize, a_source → arid |
| AccessAckData | R channel | rdata → d_data, rid → d_source |

**写事务映射**：

| TileLink | AXI4 | 说明 |
|----------|------|------|
| PutFullData | AW + W channels | a_addr → awaddr, a_data → wdata |
| AccessAck | B channel | bid → d_source |

**注意事项**：
- AXI4 的 ID 位宽需匹配 TileLink 的 source 位宽
- AXI4 Burst 类型映射：INCR 对应 TileLink 的 size 扩展
- TileLink 的 mask（PutPartialData）直接映射 AXI4 的 wstrb
- Atomic 操作需 AXI4 原子操作支持，否则桥接器需串行化
- TL-C 一致性操作无法直接桥接到 AXI4（AXI4 无一致性），需外部一致性管理

### 11.3 参数化设计要点

```verilog
// TileLink 参数化模板
module tilelink_agent #(
    parameter ADDR_WIDTH   = 32,    // 地址宽度
    parameter DATA_WIDTH   = 64,    // 数据宽度（8 的倍数）
    parameter SOURCE_WIDTH = 4,     // 源 ID 宽度（log2 of outstanding）
    parameter SINK_WIDTH   = 3,     // Sink ID 宽度（TL-C 用）
    parameter SIZE_WIDTH   = 4,     // 传输大小宽度
    parameter MASK_WIDTH   = DATA_WIDTH / 8,  // 字节掩码宽度
    parameter USER_WIDTH   = 0      // 用户自定义字段宽度
)(
    // A channel
    input  wire [2:0]              a_opcode,
    input  wire [3:0]              a_param,
    input  wire [SIZE_WIDTH-1:0]   a_size,
    input  wire [SOURCE_WIDTH-1:0] a_source,
    input  wire [ADDR_WIDTH-1:0]   a_address,
    input  wire [MASK_WIDTH-1:0]   a_mask,
    input  wire [DATA_WIDTH-1:0]   a_data,
    input  wire                    a_corrupt,
    input  wire                    a_valid,
    output wire                    a_ready,
    // D channel
    output wire [2:0]              d_opcode,
    output wire [3:0]              d_param,
    output wire [SIZE_WIDTH-1:0]   d_size,
    output wire [SOURCE_WIDTH-1:0] d_source,
    output wire [SINK_WIDTH-1:0]   d_sink,
    output wire                    d_denied,
    output wire [DATA_WIDTH-1:0]   d_data,
    output wire                    d_corrupt,
    output wire                    d_valid,
    input  wire                    d_ready
    // ... B/C/E channels for TL-C
);
```

### 11.4 常见设计陷阱

| 陷阱 | 说明 | 解决方案 |
|------|------|----------|
| source ID 耗尽 | Outstanding 事务数超过 source ID 范围 | 增大 SOURCE_WIDTH 或阻塞新请求 |
| Probe 死锁 | Manager 等待 Probe 响应，Client 等待新请求 | 确保 Client 能及时处理 Probe |
| GrantAck 丢失 | E 通道 GrantAck 丢失导致 sink ID 泄漏 | D/E 通道流控保证 |
| 跨级别互联 | TL-C Master 连 TL-UL Slave | 桥接器自动降级，确保不发一致性消息 |
| 地址对齐 | Block 操作地址未按 block_size 对齐 | 在 master 端检查对齐 |
| mask 不匹配 | PutPartialData mask 全 0 | SVA 断言检查 mask 非零 |

### 11.5 验证建议

- 使用 SVA 断言检查 Valid/Ready 握手稳定性
- 验证 Outstanding 事务的 source ID 唯一性
- TL-C 场景需验证 Probe/Grant/Release 的权限转移正确性
- 验证 TL-to-AXI 桥接的地址/数据映射正确性
- 使用 Spike（RISC-V ISS）作为 reference model 验证一致性行为

---

## 附录 A. 缩略语

| 缩写 | 全称 |
|------|------|
| TL | TileLink |
| TL-UL | TileLink Uncached Lightweight |
| TL-UH | TileLink Uncached Heavyweight |
| TL-C | TileLink Cached |
| FSM | Finite State Machine |
| CDC | Clock Domain Crossing |
| SVA | SystemVerilog Assertion |
| DMA | Direct Memory Access |
| CLINT | Core Local Interruptor |
| PLIC | Platform-Level Interrupt Controller |
| MESI | Modified Exclusive Shared Invalid |
| MOESI | Modified Owned Exclusive Shared Invalid |
| ISS | Instruction Set Simulator |

## 附录 B. 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | TileLink Spec v1.8 (UC Berkeley) | 协议官方规范 |
| REF-002 | Rocket Chip Documentation | RISC-V SoC 生成器 |
| REF-003 | SiFive TileLink Interconnect Manual | 商业实现参考 |
| REF-004 | AXI4 Protocol Spec (ARM IHI 0022) | 对比参考 |
| REF-005 | AMBA CHI Specification (ARM) | 对比参考 |
