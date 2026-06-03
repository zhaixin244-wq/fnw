# chip-requirement-arch 示例：stage0→stageD 压缩对话

> 从 Agent 定义文件外置，减少常驻 context 消耗。
> 本示例展示一个完整的 vague 类型输入的需求采集流程。实际执行时每次只问一个问题。
> Agent 需要参考本示例时，按需 Read 本文件。

---

## 输入

```
用户：帮我做一下 DMA 引擎的需求采集
```

## 代办清单

```
Agent：
## 代办清单（步进模式）
| # | 步骤 | 预期输出 | 执行组 | 状态 |
|---|------|----------|--------|------|
| 1 | 前置探索（stage0，含 search-first） | 探索结论 + 已有方案评估 | A | ⬜ |
| 2 | 最小信息集（stageA） | 4问回答 | A | ⬜ |
| 3 | 约束检查（stageB phase1） | 28项确认 | B | ⬜ |
| 4 | 头脑风暴（stageB phase2） | 追加REQ | B | ⬜ |
| 5 | 矛盾检测（stageC phase1） | 检测结果 | B | ⬜ |
| 6 | 需求汇总（stageC phase2） | 需求汇总表 | C | ⬜ |
| 7 | 规格自检 | 自检报告（5项） | C | ⬜ |
| 8 | stageD group1-step1 初始架构方案 | 架构框图+子模块列表 | D | ⬜ |
| 9 | stageD group1-step2~group5-step6 方案细化 | 方案文档各章节 | D | ⬜ |
| 10 | 对抗性评审 | 风险清单+补充建议 | E | ⬜ |

用户：确认
```

## stage0 - 前置探索

```
Agent：【stage0 - 前置探索】
这个 DMA 引擎在 SoC 中的角色是什么？是从外设搬运数据到内存，还是内存到内存？

用户：主要是外设到内存，传感器数据采集场景

Agent：好的。数据搬运的粒度通常多大？比如传感器一次产生多少数据？

用户：单次 4~64 bytes，可变长度

Agent：明白了。初步方向是：单通道 DMA + APB 控制寄存器 + AXI4 Master 数据端口。这个方向是否 OK？

用户：OK

Agent：【记录 stage0 结论，进入 stageA】
```

## stageA - 最小信息集

```
【stageA - 最小信息集】

Q1：模块在 SoC 中的位置？上游/下游模块？

用户：挂在 APB 总线上，CPU 配置。上游是传感器接口（SPI），下游是主存（DDR，通过 AXI 总线）

Agent：Q2：核心功能一句话？

用户：自动搬运 SPI 传感器数据到 DDR 内存，支持可变长度

Agent：Q3：PPA 优先级排序？性能/功耗/面积，选最重要的一项。

用户：面积最重要

Agent：Q4：确认 stage0 探索结论——单通道 DMA + APB控制 + AXI4 Master，是否需要调整？

用户：没问题

Agent：【记录 stageA 摘要，进入 stageB phase1】
```

## stageB phase1 - 约束检查（节选前3项）

```
【stageB phase1 - 约束检查（节选前3项）】

REQ-001 工艺与频率：工艺节点和目标频率是多少？

用户：28nm，目标 200MHz

Agent：✅ 记录。REQ-002 接口协议：上游 SPI 接口版本？AXI4 数据端口位宽？

用户：SPI 从模式，AXI4 32bit

Agent：✅ 记录。REQ-003 数据流特征：数据速率和突发长度？

用户：SPI 最高 50Mbps，突发长度 4~16 拍

Agent：✅ 记录。...
（后续逐项确认直到 REQ-021，每项只问一次）
```

## stageC phase1 - 矛盾检测

```
【stageC phase1 - 矛盾检测】

Agent：基础检测（17项）全部通过。由于 REQ-007（低功耗）和 REQ-018（安全隔离）均已确认，加载实验性规则 EXP-05（功耗域隔离 vs 安全隔离）...

EXP-05 检测触发：功耗域 Isolation Cell 钳位值为协议默认值（AXI RESP OKAY），但安全隔离要求零值 → 存在矛盾。

**调和方案**：
| 方案 | 调整 | 影响 |
|------|------|------|
| A | Isolation Cell 钳位值改为零值 | 安全合规，但违反 AXI 协议默认值 |
| B | 安全域增加额外过滤逻辑 | 协议兼容，增加面积开销 |

EXP-05 [功耗域隔离 vs 安全隔离] 已触发。请确认：
1. 是否为真矛盾？（是/否）
2. 如否，是否为误报？
3. 补充说明（可选）

用户：是真矛盾，选方案 A

Agent：✅ EXP-05 反馈已记录（true_contradiction=true）。进入需求汇总。
```

## stageC phase2 - 需求确认汇总 + 规格自检

```
【stageC phase2 - 需求确认汇总 + 规格自检】

## 需求确认汇总
| 编号 | 约束项 | 确认值 | 备注 |
|------|--------|--------|------|
| REQ-001 | 工艺与频率 | 28nm / 200MHz | Must |
| REQ-002 | 接口协议 | SPI从 + APB控制 + AXI4 32bit | Must |
| REQ-003 | 数据流特征 | 50Mbps / 4-16拍突发 | Should |
| ... | ... | ... | ... |

### 规格自检报告
| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | 占位符扫描 | ✅ | 无"待定"/"TODO"/"TBD" |
| 2 | 内部一致性 | ✅ | 各需求项无矛盾 |
| 3 | 范围检查 | ✅ | 聚焦单模块（DMA引擎） |
| 4 | 模糊性检查 | ✅ | 所有需求项唯一解释 |
| 5 | REQ 覆盖度 | ✅ | REQ-001~REQ-021 全覆盖 |

以上为需求理解汇总和自检报告，请确认是否准确、有无遗漏。确认后我将进入方案设计阶段。

用户：确认

Agent：【研究优先 - search-first】
检查是否有类似的 DMA 引擎设计可参考...
- Wiki 知识库：AXI4 DMA 相关条目已检索
- 项目内：无类似设计
- 行业实践：基于通用知识（标准 DMA 架构）
```

## stageD - 方案细化（节选）

```
【stageD 方案细化】

--- stageD group1-step1: 初始架构方案 + RTL 行数估算 ---
Agent：基于需求汇总，初步架构方向为：单通道 DMA + APB 控制 + AXI4 Master。
子模块划分建议：
1. dma_reg_mod — APB 寄存器模块
2. dma_ctrl — DMA 控制状态机
3. dma_datapath — 数据搬运通路
单模块预估 ≤ 500 行 RTL，是否 OK？

用户：OK，数据通路和控制分开好

✅ stageD group1-step1 记录。

--- stageD group1-step2: CBB 选型（跳过） ---
✅ stageD group1-step2 跳过（无可用 CBB，模块为纯自研逻辑）。
ADR 标注：「### stageD group1-step2: CBB 选型\n**状态**：跳过\n**原因**：无可用 CBB，模块为纯自研逻辑\n**影响**：无 CBB 集成面积/功耗开销\n**替代方案**：全部自研逻辑，面积估算按纯逻辑计算」

--- stageD group1-step3: 子模块划分细化 ---
Agent：细化子模块职责边界。dma_ctrl 负责状态机和配置寄存器解析，dma_datapath 负责 SPI 采样和 AXI 写出，dma_reg_mod 负责 APB 从接口。子模块间接口采用 Valid-Ready 握手。是否 OK？

用户：OK

✅ stageD group1-step3 记录。

--- stageD group2-step1: 数据通路设计 ---
Agent：数据从 SPI 到 DDR 的路径：SPI 采样 → 内部缓冲 → AXI4 写出。
缓冲深度建议 16 bytes（4 拍 × 4 bytes），是否满足？

用户：可以

✅ stageD group2-step1 记录。

--- stageD group2-step4: 控制逻辑/FSM ---
Agent：DMA 控制状态机：IDLE → FETCH → TRANSFER → DONE。FETCH 状态读取描述符，TRANSFER 状态执行数据搬运，DONE 状态更新状态寄存器。是否 OK？

用户：OK

✅ stageD group2-step4 记录。

--- stageD group3-step1: SRAM 设计 ---
Agent：本模块无 SRAM 使用，纯寄存器实现。跳过。
✅ stageD group3-step1 跳过（无 SRAM）。
ADR 标注：「### stageD group3-step1: SRAM 设计\n**状态**：跳过\n**原因**：模块无 SRAM 使用，纯寄存器实现\n**影响**：无 SRAM 面积和 MBIST 需求\n**替代方案**：内部缓冲使用寄存器阵列实现」

--- stageD group4-step2: 流控机制 ---
Agent：数据流控采用 Valid-Ready 握手。SPI 侧 ready 由内部缓冲空决定，AXI 侧 ready 由 AXI 从设备决定。是否 OK？

用户：OK

✅ stageD group4-step2 记录。

--- stageD group5-step2: 时序分析 ---
Agent：关键路径：SPI 采样 → 缓冲写入（2 级组合逻辑），@200MHz 余量充足（预估 3ns < 5ns）。无需额外优化。

用户：OK

✅ stageD group5-step2 记录。

--- stageD group5-step4: 可靠性设计 ---
Agent：异常检测需求：AXI 写响应错误、SPI 超时、DMA 传输超时。是否需要更多？

用户：够了

✅ stageD group5-step4 记录。

--- stageD group5-step5: 接口定义 ---
Agent：上游 SPI 接口采用 Valid-Ready 握手？还是直接采样 SPI 信号？

用户：直接采样 SPI 信号，SPI 从模式

✅ stageD group5-step5 记录。方案细化完成。
```

## 对抗性评审

```
【对抗性评审 - devils-advocate gentle（方案挑战）】
对方案文档执行 gentle 级别挑战...
- 假设盲点：传感器数据速率是否可能超过 50Mbps？
- 风险点：单通道 DMA 在高负载场景下可能成为瓶颈
- 补充建议：考虑预留多通道扩展接口

【对抗性评审 - devils-advocate balanced（ADR 挑战）】
对 ADR 文档执行 balanced 级别挑战...

（用户可选：用 debate 进行跨模型审查）
用户：用 debate 审查一下方案
Agent：调用 debate skill，使用 plan 模式进行跨模型审查...
```
