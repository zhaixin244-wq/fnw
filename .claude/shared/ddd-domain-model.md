# DDD 领域建模规范（共享）

> 本模板定义芯片设计中领域驱动设计（Domain-Driven Design）的建模规范。
> 供 chip-fs-writer（领域建模）、chip-microarch-writer（领域实现）、chip-code-writer（领域编码）、chip-verfi-arch（领域验证）共同引用。

---

## 1. 概述

DDD（Domain-Driven Design）在芯片设计中的应用：
- 用 **领域模型** 驱动模块划分和接口设计
- 用 **限界上下文** 定义模块边界和时钟域/功耗域边界
- 用 **统一语言** 确保信号命名和协议术语一致
- 用 **聚合/实体/值对象** 规范化数据结构和状态管理
- 用 **域事件** 形式化模块间交互

**铁律：领域模型是芯片架构的骨架，FS/UA/RTL 都必须与领域模型一致。**

---

## 2. DDD → 芯片设计映射表

| DDD 概念 | 芯片设计映射 | RTL 表现 | 验证映射 |
|----------|-------------|----------|----------|
| **Bounded Context（限界上下文）** | 模块边界 / 时钟域 / 功耗域 | 模块名 + 端口列表 | 独立验证域 |
| **Ubiquitous Language（统一语言）** | 命名规范 + 协议术语 | 信号命名规则 | 验证术语 |
| **Domain Model（领域模型）** | FS §4 功能描述 | 模块功能定义 | 验证目标 |
| **Aggregate（聚合）** | 共享状态的模块簇 | 同一 always 块簇的寄存器 | 原子性验证 |
| **Entity（实体）** | 有身份标识的对象 | 带 ID 的寄存器数组 | 身份追踪验证 |
| **Value Object（值对象）** | 无身份的数据结构 | 纯组合逻辑的数据结构 | 数据比对验证 |
| **Domain Event（域事件）** | 中断/状态变化/握手事件 | assign 中断/状态信号 | 事件序列覆盖 |
| **Repository（仓储）** | 寄存器映射/配置空间/空闲列表 | SRAM/寄存器文件 + 读写逻辑 | 读写验证 |
| **Service（领域服务）** | 无状态操作 | 纯组合逻辑模块 | 功能验证 |

---

## 3. 领域建模流程

### 3.1 五步建模法

```
Step 1: 识别 Entity 和 Value Object
  │
  ├─→ Step 2: 定义 Aggregate 聚合边界
  │     │
  │     ├─→ Step 3: 定义 Domain Event 域事件
  │     │     │
  │     │     ├─→ Step 4: 识别 Repository 和 Service
  │     │     │     │
  │     │     │     └─→ Step 5: 验证领域模型一致性
  │     │     │
  │     │     └─→ 域事件驱动模块间接口设计
  │     │
  │     └─→ 聚合驱动子模块划分
  │
  └─→ 实体/值对象驱动数据结构设计
```

### 3.2 Step 1：识别 Entity 和 Value Object

**判定规则**：

| 判定条件 | Entity | Value Object |
|----------|--------|-------------|
| 有唯一身份标识（ID） | ✅ | ❌ |
| 生命周期独立 | ✅ | ❌（随 Entity 创建/销毁） |
| 可变性 | 可变 | 不可变（用新值替换） |
| 比较方式 | 按 ID 比较 | 按属性值比较 |

**芯片设计示例**：

| 对象 | 类型 | 身份标识 | 示例 |
|------|------|----------|------|
| 通道 | Entity | ch_id | DMA 通道、PCIe RC 通道 |
| 标签 | Entity | tag_id | PCIe tag、MRd tag |
| 事务 | Entity | txn_id | AXI 事务、请求事务 |
| 包头 | Value Object | 无 | TLP header、descriptor |
| 数据载荷 | Value Object | 无 | payload_data |
| 配置参数 | Value Object | 无 | 寄存器位域值 |

**输出格式**：

```markdown
### 实体清单

| 实体名 | 身份标识 | 属性 | 生命周期 | 所属聚合 |
|--------|----------|------|----------|----------|
| Channel | ch_id | state, credit, config | 模块运行期 | ChannelManager |
| Tag | tag_id | owner, state, addr | 分配~回收期 | TagManager |

### 值对象清单

| 值对象名 | 属性 | 不可变性 | 用途 |
|----------|------|----------|------|
| Header | type, length, addr | 是 | 数据包头 |
| Descriptor | src, dst, size | 是 | DMA 描述符 |
```

### 3.3 Step 2：定义 Aggregate 聚合边界

**聚合定义**：一组相关对象的集合，作为数据变更的一致性边界。

**聚合判定规则**：

| 判定条件 | 同一聚合 | 不同聚合 |
|----------|----------|----------|
| 共享状态（同一 SRAM/寄存器组） | ✅ | ❌ |
| 原子性操作（同拍读写） | ✅ | ❌ |
| 时钟域 | 同一时钟域 | 可不同 |
| 功耗域 | 同一功耗域 | 可不同 |

**芯片设计示例**：

| 聚合名 | 包含实体/值对象 | 聚合根 | 一致性规则 |
|--------|----------------|--------|-----------|
| TagManager | Tag, FreeList | Tag | 分配/回收原子性 |
| ChannelManager | Channel, CreditPool | Channel | 信用更新原子性 |
| CplBuffer | CplEntry, Metadata | CplEntry | 写入/读出原子性 |

**输出格式**：

```markdown
### 聚合划分表

| 聚合名 | 聚合根 | 包含对象 | 一致性规则 | 所属子模块 |
|--------|--------|----------|-----------|-----------|
| TagManager | Tag | Tag, FreeList | 分配/回收同拍完成 | tag_mgr |
| ChannelManager | Channel | Channel, CreditPool | 信用更新同拍完成 | ch_mgr |
| CplBuffer | CplEntry | CplEntry, Metadata | 写入/读出同拍完成 | cpl_buf |
```

### 3.4 Step 3：定义 Domain Event 域事件

**域事件定义**：领域中发生的有意义的状态变化或动作完成。

**域事件分类**：

| 类别 | 芯片映射 | 信号类型 | 示例 |
|------|----------|----------|------|
| 分配事件 | 资源分配完成 | 脉冲信号 | tag_alloc_done, ch_grant |
| 回收事件 | 资源回收完成 | 脉冲信号 | tag_free_done, credit_return |
| 状态事件 | 状态变化 | 电平信号 | ch_state_change, err_detected |
| 握手事件 | 事务完成 | 握手信号 | valid & ready, req & ack |
| 超时事件 | 超时触发 | 脉冲信号 | timeout_irq |
| 完成事件 | 处理完成 | 脉冲信号 | cpl_complete, dma_done |

**输出格式**：

```markdown
### 域事件清单

| 事件名 | 类别 | 触发条件 | 信号名 | 影响聚合 | 后续动作 |
|--------|------|----------|--------|----------|----------|
| TagAllocated | 分配 | tag 分配成功 | tag_alloc_done | TagManager | 更新 FreeList |
| TagFreed | 回收 | tag 回收完成 | tag_free_done | TagManager | 更新 FreeList |
| CplReceived | 完成 | CPL 数据写入 | cpl_write_done | CplBuffer | 更新 Metadata |
| TimeoutDetected | 超时 | 握手超时 | timeout_irq | - | 报错/重试 |
```

### 3.5 Step 4：识别 Repository 和 Service

**Repository（仓储）**：管理 Entity 的持久化存储。

| 类型 | 芯片映射 | RTL 表现 | 示例 |
|------|----------|----------|------|
| 寄存器仓储 | 配置寄存器组 | `reg_r[addr]` | CTRL, STATUS, INT_MASK |
| SRAM 仓储 | 数据缓冲区 | SRAM macro | CPL buffer, FIFO |
| 空闲列表仓储 | 资源池 | SRAM 或寄存器链表 | tag_free_list, credit_pool |

**Service（领域服务）**：无状态的操作逻辑。

| 类型 | 芯片映射 | RTL 表现 | 示例 |
|------|----------|----------|------|
| 仲裁服务 | 多源仲裁 | 纯组合逻辑 | RR arbiter, WRR arbiter |
| 编码服务 | 数据编码 | 纯组合逻辑 | CRC, ECC, encryption |
| 解码服务 | 数据解码 | 纯组合逻辑 | address decode, header parse |
| 比较服务 | 数据比对 | 纯组合逻辑 | addr_match, data_compare |

**输出格式**：

```markdown
### 仓储清单

| 仓储名 | 类型 | 管理实体 | 存储介质 | 容量 | 访问方式 |
|--------|------|----------|----------|------|----------|
| TagFreeList | 空闲列表 | Tag | SRAM | 1K | 读写 |
| CplBuffer | 数据缓冲 | CplEntry | SRAM | 1MB | 读写 |
| RegFile | 寄存器 | Config | 寄存器 | 32×32bit | 读写 |

### 服务清单

| 服务名 | 类型 | 输入 | 输出 | 纯组合 | 示例 |
|--------|------|------|------|--------|------|
| TagAllocator | 分配服务 | alloc_req | tag_id, alloc_done | 是 | tag 分配 |
| RRArbiter | 仲裁服务 | req[N] | gnt[N] | 是 | RR 仲裁 |
| CRCCalculator | 编码服务 | data_in | crc_out | 是 | CRC32 计算 |
```

---

## 4. 领域模型文档模板

> 供 chip-fs-writer 在 FS §4 阶段使用，输出到 FS 文档的 §4.5 领域模型章节。

```markdown
### 4.5 领域模型（DDD）

#### 4.5.1 实体与值对象

| 对象名 | 类型 | 身份标识 | 属性 | 生命周期 |
|--------|------|----------|------|----------|
| {name} | Entity/VO | {id} | {attrs} | {lifecycle} |

#### 4.5.2 聚合划分

| 聚合名 | 聚合根 | 包含对象 | 一致性规则 | 所属子模块 |
|--------|--------|----------|-----------|-----------|
| {name} | {root} | {objects} | {rule} | {submodule} |

#### 4.5.3 域事件

| 事件名 | 类别 | 触发条件 | 信号名 | 影响聚合 | 后续动作 |
|--------|------|----------|--------|----------|----------|
| {name} | {type} | {condition} | {signal} | {aggregate} | {action} |

#### 4.5.4 仓储与服务

| 名称 | 类型 | 管理对象 | 存储介质/纯组合 | 容量 |
|------|------|----------|----------------|------|
| {name} | Repository/Service | {object} | {type} | {capacity} |
```

---

## 5. 聚合边界判定规则

### 5.1 同一聚合的条件

1. **共享状态**：对象共享同一 SRAM 或寄存器组
2. **原子性**：操作必须同拍完成（如分配+更新）
3. **一致性**：状态变更必须在同一时钟域内完成
4. **生命周期**：对象生命周期由聚合根管理

### 5.2 不同聚合的条件

1. **独立状态**：对象有独立的存储
2. **异步交互**：通过域事件异步通信
3. **不同时钟域**：跨时钟域的对象属于不同聚合
4. **不同功耗域**：跨功耗域的对象属于不同聚合

### 5.3 聚合间通信

聚合间通过 **域事件** 通信，不直接共享状态：

```
聚合A --[域事件]--> 聚合B
  │                    │
  └-- 独立状态 --       └-- 独立状态 --
```

**RTL 表现**：
- 聚合内部：同一 always 块簇，直接信号连接
- 聚合间：通过 assign 或同步寄存器传递域事件信号

---

## 6. 与现有规范的关系

| 现有规范 | DDD 增强 |
|----------|----------|
| FS 模板 §4 | 新增 §4.5 领域模型章节 |
| UA 模板 §5 | 数据通路/控制逻辑使用 DDD 概念 |
| coding-style.md | Entity→寄存器数组命名、Value Object→组合逻辑命名 |
| SDD 追溯规范 | 领域模型元素纳入追溯链路 |
| BDD 场景模板 | 域事件驱动 BDD 场景生成 |

---

## 7. DDD 与 SDD/BDD 的关系

```
SDD（规格驱动）
  │
  ├─→ FS §4.5 领域模型（DDD）
  │     │
  │     ├─→ Entity/Value Object → 数据结构设计
  │     ├─→ Aggregate → 子模块划分
  │     ├─→ Domain Event → BDD 场景生成（BDD）
  │     └─→ Repository/Service → 微架构设计
  │
  └─→ REQ→FS→BDD→UA→RTL→SVA→UVM（全链路追溯）
```

**DDD 是 SDD/BDD 的补充**：
- SDD 定义"追溯什么"（REQ→实现）
- BDD 定义"验证什么"（Given-When-Then）
- DDD 定义"如何建模"（Entity/Aggregate/Event）
