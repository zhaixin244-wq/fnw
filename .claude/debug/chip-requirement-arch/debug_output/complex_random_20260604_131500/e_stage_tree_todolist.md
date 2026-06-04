# E 阶段树形 Todolist

> 本文件是 E 阶段递归分解的执行指南。Agent 必须按本文件定义的流程和顺序逐步执行。
> 所有子模块均为叶子节点（<3000 行），无需递归分解。

---

## 1. 递归分解结果

| ID | 名称 | 层级 | 父节点 | 预估行数 | 状态 | 执行顺序 | 依赖 | 全局 REQ |
|----|------|------|--------|----------|------|----------|------|----------|
| 0 | fpga_partial_reconfig | L0 | - | 3800 | completed | 0 | - | REQ-001~REQ-040 |
| 1 | bitstream_rx_engine | L1 | 顶层 | 700 | completed | 1 | - | REQ-002/003/012/015/037/038 |
| 2 | bitstream_val_mgr | L1 | 顶层 | 950 | completed | 2 | 1 | REQ-003/004/009/030/031/032/033 |
| 3 | icap_write_engine | L1 | 顶层 | 500 | completed | 3 | 2 | REQ-002/004/006/011/014/028/031/036 |
| 4 | isolation_mgr | L1 | 顶层 | 800 | completed | 4 | - | REQ-009/018/029/039 |
| 5 | reg_interface | L1 | 顶层 | 700 | completed | 5 | - | REQ-002/016/017/019/020/033/034/035/036 |

**状态说明**：pending -> in_progress -> completed -> skipped
**起始阶段**：所有子模块从 stageB phase2（头脑风暴）开始
**递归终止**：所有叶子节点预估行数 <3000，无需递归

---

## 2. 子模块 flow 定义

| 子模块 ID | 名称 | 必须执行的 flow | 交付文件 |
|-----------|------|----------------|----------|
| 1 | bitstream_rx_engine | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 2 | bitstream_val_mgr | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 3 | icap_write_engine | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 4 | isolation_mgr | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |
| 5 | reg_interface | stageB phase2 -> stageC phase1 -> stageC phase2 -> stageD | outputs/ 5 文件 + flow/ 4 文件 |

---

## 3. 子模块 REQ 分配详情

### 3.1 bitstream_rx_engine（比特流接收引擎）

**功能范围**：PCIe DMA 从接口、本地 Flash 接口（预留）、分段加载控制、进度查询

**全局 REQ 映射**：

| 全局 REQ | 子模块功能点 | 优先级 |
|----------|-------------|--------|
| REQ-002 | PCIe DMA 接口 + Flash 接口（预留） | Must |
| REQ-003 | 数据流特征（比特流大小/突发长度） | Should |
| REQ-012 | 外部 DDR 存储接口 | Should |
| REQ-015 | DMA 握手（256B 突发，递增地址） | Should |
| REQ-037 | 比特流加载进度查询 | Should |
| REQ-038 | 比特流分段加载 | Should |

### 3.2 bitstream_val_mgr（比特流校验管理）

**功能范围**：CRC-32 校验、LZ4 解压、版本管理、回滚机制、错误注入

**全局 REQ 映射**：

| 全局 REQ | 子模块功能点 | 优先级 |
|----------|-------------|--------|
| REQ-003 | 数据流特征（ICAP 32-bit 粒度） | Should |
| REQ-004 | 延迟约束（整体 <200ms） | Should |
| REQ-009 | CRC-32 校验 + 回滚机制 | Should |
| REQ-030 | LZ4 解压（Zlib 可选） | Should |
| REQ-031 | 传输-校验-写入流水线（校验段） | Should |
| REQ-032 | 比特流版本管理 | Should |
| REQ-033 | 错误注入（CRC 错误注入） | Should |

### 3.3 icap_write_engine（ICAP 写入引擎）

**功能范围**：ICAP 32-bit 驱动、写入排序、跨时钟域 CDC、超时检测

**全局 REQ 映射**：

| 全局 REQ | 子模块功能点 | 优先级 |
|----------|-------------|--------|
| REQ-002 | ICAP 32-bit 接口 | Must |
| REQ-004 | 延迟约束 | Should |
| REQ-006 | ICAP 独立时钟域（100~200MHz） | Must |
| REQ-011 | CDC 策略（主域→ICAP 异步 FIFO） | Should |
| REQ-014 | ICAP 时序约束（setup≤2ns, delay≤3ns） | Should |
| REQ-028 | 时钟树约束（SSC 1%） | Should |
| REQ-031 | 传输-校验-写入流水线（写入段） | Should |
| REQ-036 | ICAP 超时阈值 APB 可配 | Should |

### 3.4 isolation_mgr（隔离管理）

**功能范围**：多租户地址解码、访问控制、区域分配表、失败恢复、违规检测

**全局 REQ 映射**：

| 全局 REQ | 子模块功能点 | 优先级 |
|----------|-------------|--------|
| REQ-009 | 失败回滚机制 | Should |
| REQ-018 | 逻辑隔离 + 关键寄存器物理隔离 | Must |
| REQ-029 | 区域分配表管理 | Must |
| REQ-039 | 部分重配置失败恢复 | Should |

### 3.5 reg_interface（寄存器接口）

**功能范围**：APB 从接口、中断控制、性能计数器、状态观测、错误注入控制、超时配置

**全局 REQ 映射**：

| 全局 REQ | 子模块功能点 | 优先级 |
|----------|-------------|--------|
| REQ-002 | APB 32-bit 从接口 | Must |
| REQ-016 | 5 中断（重配完成/校验错误/回滚/隔离违规/DMA超时） | Should |
| REQ-017 | 调试接口（APB 寄存器访问） | Could |
| REQ-019 | 软件接口（PCIe PF/VF + APB MMIO） | Should |
| REQ-020 | 系统级约束（BE QoS / Device Cache） | Should |
| REQ-033 | 错误注入控制寄存器 | Should |
| REQ-034 | 状态机观测寄存器 | Should |
| REQ-035 | 性能计数器 | Should |
| REQ-036 | 超时阈值配置寄存器 | Should |

---

## 4. 执行顺序与依赖

```
bitstream_rx_engine (1)
        │
        ▼
bitstream_val_mgr (2) ◄── 依赖：rx_engine 输出数据格式
        │
        ▼
icap_write_engine (3) ◄── 依赖：val_mgr 输出校验后的比特流
        │
        ▼
isolation_mgr (4)    ◄── 无依赖，可并行
        │
        ▼
reg_interface (5)    ◄── 无依赖，可并行
```

**执行策略**：
- 子模块 1→2→3 有数据通路依赖，按顺序执行
- 子模块 4、5 无依赖，可在子模块 3 完成后并行执行
- 每个子模块完成后更新本 todolist 状态

---

## 5. 每个子模块的交付文件

### outputs/ 目录

| # | 文件 | 命名 | 说明 |
|---|------|------|------|
| 1 | PR 沟通记录 | {name}_pr_v1.0.md | stageB phase2~stageD 沟通记录 |
| 2 | 需求汇总表 | {name}_requirement_summary_v1.0.md | REQ 汇总 |
| 3 | 方案文档 | {name}_solution_v1.0.md | 详细方案 |
| 4 | ADR 文档 | {name}_ADR_v1.0.md | 架构决策记录 |
| 5 | 追溯图 | {name}_trace_graph.yaml | 需求追溯 |

### flow/ 目录

| # | 文件 | 说明 |
|---|------|------|
| 1 | stageB_phase2.md | 头脑风暴 Feature Discovery |
| 2 | stageC_phase1.md | 矛盾检测 |
| 3 | stageC.md | 需求确认汇总 |
| 4 | stageD.md | 方案细化 |

---

## 6. 执行进度跟踪

| 层级 | 模块 | 总数 | completed | in_progress | pending | 进度 |
|------|------|------|-----------|-------------|---------|------|
| L0 | 顶层 | 1 | 1 | - | - | 100% |
| L1 | 子模块 | 5 | 0 | 0 | 5 | 0% |
| **全局** | **所有** | **6** | **1** | **0** | **5** | **17%** |
