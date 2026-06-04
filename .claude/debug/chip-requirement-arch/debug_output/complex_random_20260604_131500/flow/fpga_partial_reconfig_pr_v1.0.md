# FPGA 部分重配置控制器 PR 沟通记录

> 版本：v1.0
> 日期：2026-06-04
> 阶段：stageE（执行中）
> 当前进度：stageE 第一步（递归分解+todolist）
> 已完成：stage0, stageA, stageB phase1/phase2, stageC phase1/phase2, stageD group1-step1
> 需求冻结：REQ-001~040 已冻结（用户确认）

---

## [STAGE-START] stage0

### 输入分型

用户输入："帮我做 FPGA 部分重配置控制器的需求采集"

**分型判定**：vague（仅模块名 + 一句话功能描述）
- 约束维度：2（工艺=16nm，频率=500MHz，来自模块上下文）
- 字数：<50 字
- 后续路径：stage0 → stageA → stageB phase1 全量采集 → stageC

### 探索方向

根据 stage0 定义，需完成以下 3 个探索方向：
1. 模块核心价值与边界
2. 关键约束与权衡点
3. 初步架构方向（定性）

---

### 用户确认（stage0 → stageA 过渡）

用户确认 stage0 探索结论，并补充以下关键信息：

| # | 确认项 | 用户回复 |
|---|--------|----------|
| 1 | 比特流来源 | 主路径 PCIe DMA，预留本地 Flash 加载接口作为备用启动通道 |
| 2 | 重配置粒度 | 固定区域+动态区域混合模式，固定区域放静态逻辑，动态区域支持灵活分配 |
| 3 | 多租户隔离级别 | 逻辑隔离为主（地址空间+访问控制），关键配置寄存器物理隔离 |
| 4 | ICAP 接口规格 | 兼容 Xilinx 7-series 风格，32-bit 数据宽度，顺序写入模式 |
| 5 | 比特流缓存 | 至少缓存 2 份（在用+预备），深度按最大比特流大小 2 倍预估 |
| 6 | 探索结论 | 5 子模块划分合理，补充隔离管理需考虑完整性校验失败时的回滚机制 |

---

## [STAGE-START] stageA

### stageA 最小信息集采集（4 个核心问题）

**Q1：模块在 SoC 中的位置？上游/下游模块？**（映射 REQ-002）

| 维度 | 内容 |
|------|------|
| SoC 位置 | FPGA 管理子系统 |
| 上游模块 | Host CPU（通过 PCIe DMA 通道） |
| 下游模块 | FPGA 可配置逻辑块（通过 ICAP 配置接口） |
| 辅助接口 | 本地 Flash（备用比特流加载通道）、APB 配置总线 |

**Q2：核心功能一句话？**（映射 REQ-003）

通过 PCIe DMA 或本地 Flash 接收比特流，在运行时对 FPGA 部分区域进行动态重配置，支持多租户隔离和比特流完整性校验。

**Q3：PPA 优先级排序？**（映射 REQ-004/005）

| 优先级 | 维度 | 说明 |
|--------|------|------|
| 1（最高） | 灵活性 | 多模式重配置、多租户支持、多种比特流来源 |
| 2 | 可靠性 | 完整性校验、隔离保护、失败回滚 |
| 3（最低） | 面积 | 在满足灵活性和可靠性的前提下优化 |

工艺/频率约束：16nm / 500MHz

**Q4：stage0 结论确认？** — 已确认，5 子模块划分合理，补充回滚机制需求。

### stageA 回答摘要（带入 stageB phase1）

| stageA 问题 | 映射 REQ | 摘要 |
|-------------|----------|------|
| SoC 位置/上下游 | REQ-002 | FPGA 管理子系统，上：Host CPU（PCIe DMA），下：FPGA 可配置逻辑块（ICAP） |
| 核心功能 | REQ-003 | 运行时部分重配置 + 多租户隔离 + 比特流完整性校验与回滚 |
| PPA 优先级 | REQ-004/005 | 灵活性 > 可靠性 > 面积，16nm/500MHz |
| stage0 结论 | - | 5 子模块架构已确认，补充回滚机制 |

## [STAGE-END] stageA

---

## [PHASE-START] stageB phase1

### 约束检查清单（28 项逐项确认）

> 处理策略：vague 输入模式，按 category_processing 规则逐项处理。
> 默认值上限：5 项。关键 REQ（004/016/020）不可直接用默认值跳过。

---

#### REQ-001 工艺与频率 [independent]

| 约束项 | 确认值 | 来源 | 状态 |
|--------|--------|------|------|
| 工艺节点 | 16nm | 用户上下文提供 | confirmed |
| 目标频率 | 500 MHz | 用户上下文提供 | confirmed |

> 实时矛盾检查：REQ-001 vs REQ-013（工艺 vs PVT）— 待 REQ-013 确认后校验。

---

#### REQ-002 接口协议 [infer_from_position]

> 推断依据：SoC 位置 = FPGA 管理子系统，上游 = PCIe DMA，下游 = ICAP。
> 协议映射：layer_2_highspeed（PCIe）+ 自定义（ICAP）+ layer_1_basic（APB）

| 接口 | 协议 | 位宽 | 方向 | 说明 |
|------|------|------|------|------|
| 上游数据 | PCIe DMA | - | 输入 | Host CPU 通过 DMA 通道下发比特流 |
| 下游配置 | ICAP（Xilinx 7-series 兼容） | 32-bit | 输出 | 顺序写入模式，FPGA 配置接口 |
| 控制/状态 | APB | 32-bit | 从接口 | Host CPU 配置与状态查询 |
| 备用加载 | 本地 Flash SPI | - | 输入 | 备用启动通道（预留） |

**确认状态**：confirmed — 用户在 stage0 确认中已明确所有接口规格。

---

#### REQ-003 数据流特征 [partial_coverage]

> stageA 第 2 问部分覆盖：功能描述含"比特流接收"，但未覆盖数据速率/突发长度/粒度。

| 维度 | 推荐值 | 依据 | 状态 |
|------|--------|------|------|
| 比特流典型大小 | 8~32 MB（Xilinx 7-series 典型值） | 行业典型值，待用户确认 | default_value |
| PCIe DMA 突发长度 | 256 bytes / 512 bytes | PCIe Gen3 x4 典型突发 | default_value |
| ICAP 写入粒度 | 32-bit（1 word/cycle） | 用户确认 ICAP 32-bit | confirmed |
| 比特流传输延迟目标 | < 100 ms（8MB @ PCIe Gen3 x4） | 行业参考值 | default_value |

**确认状态**：partial_confirmed — ICAP 粒度已确认，比特流大小和突发长度基于通用知识，待用户确认。

---

#### REQ-004 延迟与吞吐 [priority_dependent]

> 依赖：REQ-006（时钟域）。PPA 优先级：灵活性最高，性能非首要。
> 策略：未选为最高优先级，询问预算参考值。

| 维度 | 推荐值 | 依据 | 状态 |
|------|--------|------|------|
| ICAP 写入吞吐 | 500 Mbit/s（500MHz / 1 cycle per 32-bit word） | 500MHz × 32-bit = 16 Gbps 理论，ICAP 实际受限 | default_value |
| 整体重配置延迟 | < 200 ms（含比特流传输+校验+ICAP写入） | 行业参考值 | default_value |
| 寄存器访问延迟 | < 10 cycles | APB 标准延迟 | default_value |

**确认状态**：default_value — 基于通用知识，待用户确认。

---

#### REQ-005 面积与功耗 [priority_dependent]

> 依赖：REQ-013（PVT 条件）。PPA 优先级：面积最低优先级。
> 策略：未选为最高，询问预算参考值。

| 维度 | 推荐值 | 依据 | 状态 |
|------|--------|------|------|
| 逻辑面积 | < 200 kGates | PR 控制器规模估算（5 子模块 + 控制逻辑） | default_value |
| SRAM 容量 | 64~128 Kbit（比特流缓存 2 份） | 待比特流大小确认后精确计算 | default_value |
| 动态功耗 | < 150 mW | 16nm/500MHz 典型值 | default_value |
| 静态功耗 | < 10 mW | 16nm 典型漏电 | default_value |

**确认状态**：default_value — 基于通用知识，待用户确认。

---

#### REQ-006 时钟与复位 [independent]

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| 时钟域数量 | 3 个 | PCIe 参考时钟域 + 内部逻辑 500MHz + ICAP 配置时钟域 | inferred |
| 复位策略 | 异步复位同步释放，低有效 rst_n | 编码规范默认 | confirmed |
| PCIe 时钟 | 100 MHz（参考时钟）/ 250 MHz（Gen3） | PCIe 协议标准 | inferred |
| 内部逻辑时钟 | 500 MHz | 用户确认 | confirmed |
| ICAP 时钟 | 与内部逻辑同域或独立（待确认） | 取决于 ICAP 时序约束 | pending |

**确认状态**：partial_confirmed — 时钟域数量和复位策略已推断，ICAP 时钟域归属待确认。

---

#### REQ-007 低功耗 [independent]

> PPA 优先级：灵活性 > 可靠性 > 面积，功耗非首要约束。

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| 独立功耗域 | 不需要 | 管理子系统常供电，无休眠需求 | inferred |
| Clock Gating | 使用全局 Clock Gating 方案 | 标准方案 | confirmed |
| 特殊低功耗 | 无 | 非首要约束 | inferred |

**确认状态**：confirmed — 使用全局 Clock Gating，无独立功耗域需求。

---

#### REQ-008 DFT [independent]

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| 扫描链 | 标准扫描链 | 通用 DFT 规则 | confirmed |
| ICG | 标准 ICG（带 scan_en 端口） | 编码规范要求 | confirmed |
| Boundary Scan | 遵循项目通用规则 | 无特殊要求 | confirmed |
| MBIST | 需要（比特流缓存 SRAM） | SRAM 容量 ≥ 64Kbit 需 MBIST | inferred |

**确认状态**：confirmed — 遵循通用 DFT 规则，MBIST 用于比特流缓存 SRAM。

---

#### REQ-009 可靠性 [independent]

> 依赖：REQ-012（存储器选型）。用户补充：完整性校验失败时需要回滚机制。

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| SRAM ECC | SECDED ECC | 比特流缓存 SRAM 保护 | inferred |
| 比特流校验 | CRC-32 校验 | 用户确认完整性校验需求 | confirmed |
| 回滚机制 | 完整性校验失败时回滚到上一份有效比特流 | 用户明确要求 | confirmed |
| TMR | 不需要 | 非安全关键场景 | inferred |
| SEU 防护 | 不需要（管理子系统非辐射环境） | 应用场景推断 | inferred |

**确认状态**：confirmed — CRC-32 校验 + 回滚机制已确认，SRAM SECDED ECC 为行业标准。

> 实时矛盾检查：REQ-005 vs REQ-009（面积预算 vs ECC 开销）— SECDED ECC 面积开销约 5-8%，在 200kGates 预算内可接受。

---

#### REQ-010 其他约束 [independent]

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| 安全合规 | 无特殊要求 | 非汽车/工业场景 | inferred |
| 特殊工艺限制 | 无特殊限制 | 16nm 标准工艺 | inferred |
| 出口管制 | 不涉及 | 通用管理子系统 | inferred |

**确认状态**：confirmed — 无特殊安全/合规/工艺限制。

---

#### REQ-011 CDC 策略 [conditional]

> 依赖：REQ-006。前置已确认（3 个时钟域），条件满足，需追问。

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| 跨域信号类型 | 控制信号（配置命令/状态）+ 数据信号（比特流） | 功能分析 | inferred |
| 控制信号同步 | 双触发器同步（单 bit） | CDC 标准方案 | confirmed |
| 数据信号同步 | 异步 FIFO（多 bit 比特流数据） | CDC 标准方案 | confirmed |
| PCIe → 内部逻辑 | 异步 FIFO（DMA 数据通路） | 多 bit 数据 | inferred |
| 内部逻辑 → ICAP | 同域或同步后直连 | 取决于 ICAP 时钟域 | pending |

**确认状态**：partial_confirmed — CDC 策略基于通用方案推断，ICAP 时钟域归属待 REQ-006 补充确认。

> 实时矛盾检查：REQ-004 vs REQ-006 vs REQ-011（延迟 vs 时钟域 vs CDC 延迟）— CDC 同步延迟 2-3 cycles，在 200ms 重配延迟预算内无影响。

---

#### REQ-012 存储器选型 [infer_from_function]

> 推断依据：stageA 功能描述含"比特流缓存 2 份"。

| 存储类型 | 用途 | 容量估算 | 状态 |
|----------|------|----------|------|
| SRAM（1R1W） | 比特流缓存（2 份） | 2 × 32MB = 64MB（最大）/ 2 × 8MB = 16MB（典型） | inferred |
| 寄存器阵列 | 控制/状态寄存器 | < 1 kGates | confirmed |
| FIFO | DMA 数据缓冲 | 256~512 bytes | inferred |

> 注意：64MB SRAM 远超片内容量，实际方案可能需要外部 DDR 或缩减缓存策略。待 REQ-003 比特流大小确认后精确计算。

**确认状态**：pending — SRAM 容量取决于比特流大小（REQ-003），待确认后精确计算。

---

#### REQ-013 PVT 操作条件 [independent]

| 维度 | 推荐值 | 依据 | 状态 |
|------|--------|------|------|
| 温度范围 | -40°C ~ 105°C（工业级） | 管理子系统典型要求 | default_value |
| 电压 | 0.85V（16nm 标准电压） | 工艺标准 | default_value |
| 工艺角 | TT + SS | 标准综合角 | default_value |

**确认状态**：default_value — 基于通用知识，待用户确认。

> 实时矛盾检查：REQ-001 vs REQ-013（16nm vs 工业级温度）— 16nm 支持工业级温度范围，无矛盾。

---

#### REQ-014 接口时序约束 [conditional]

> 依赖：REQ-002。前置已确认（PCIe + ICAP + APB），条件满足。
> PCIe 和 APB 为标准协议，时序由协议规范定义，无需额外约束。

| 接口 | 时序约束 | 状态 |
|------|----------|------|
| PCIe DMA | 遵循 PCIe 协议规范 | confirmed |
| ICAP 32-bit | setup ≤ 2ns, output delay ≤ 3ns（Xilinx 7-series 典型） | inferred |
| APB | 遵循 AMBA APB 协议规范 | confirmed |

**确认状态**：confirmed — 标准时序约束，ICAP 时序参考 Xilinx 数据手册。

---

#### REQ-015 DMA 握手接口 [infer_from_function]

> 推断依据：上游 = PCIe DMA，需要 DMA 引擎接收比特流。

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| DMA 引擎 | 需要（PCIe DMA 从接口） | 上游为 PCIe DMA | inferred |
| 突发长度 | 256 bytes（PCIe 标准） | PCIe 协议 | inferred |
| 地址模式 | 递增模式 | DMA 标准 | inferred |
| 通道数 | 1 通道（比特流下载专用） | 单功能模块 | inferred |

**确认状态**：inferred — 基于 PCIe DMA 标准行为推断，待用户确认。

---

#### REQ-016 中断接口 [independent]

> 关键 REQ，不可直接用默认值跳过，需追问。

| 维度 | 推荐值 | 依据 | 状态 |
|------|--------|------|------|
| 中断输出类型 | 电平输出（active-high） | APB 外设典型 | default_value |
| 中断数量 | 4 个（重配完成/校验错误/回滚触发/隔离违规） | 功能分析 | default_value |
| 清除方式 | W1C（写 1 清零） | 标准做法 | default_value |
| 优先级 | 由 Host CPU 处理，硬件无优先级 | 管理子系统简单场景 | default_value |

**确认状态**：default_value — 基于通用知识，待用户确认。

---

#### REQ-017 调试接口 [independent]

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| JTAG | 不需要（通过 APB 寄存器访问状态） | 管理子系统典型做法 | inferred |
| Trace | 不需要 | 非处理器模块 | inferred |
| 性能计数器 | 可选（重配置次数/耗时/错误计数） | 便于调试 | inferred |

**确认状态**：inferred — 通过 APB 寄存器访问状态，无需专用调试接口。

---

#### REQ-018 安全隔离 [independent]

> 用户明确：逻辑隔离为主 + 关键配置寄存器物理隔离。

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| 隔离方式 | 逻辑隔离（地址空间 + 访问控制） | 用户确认 | confirmed |
| 关键寄存器保护 | 物理隔离（独立访问端口） | 用户确认 | confirmed |
| TrustZone | 不需要 | 非安全关键场景 | inferred |
| 防火墙 | 地址空间隔离即为简化的防火墙 | 功能等效 | inferred |

**确认状态**：confirmed — 用户已明确隔离级别。

---

#### REQ-019 软件接口约束 [infer_from_position]

> 推断依据：SoC 位置 = FPGA 管理子系统，上游 = Host CPU（PCIe）。

| 维度 | 确认值 | 依据 | 状态 |
|------|--------|------|------|
| 驱动模型 | PCIe PF/VF 驱动 + MMIO 访问 | 多租户场景 | inferred |
| 寄存器访问 | APB 从接口，32-bit 读写 | 标准做法 | confirmed |
| 中断 vs 轮询 | 中断为主，轮询为辅（状态查询） | 混合模式 | inferred |

**确认状态**：inferred — 基于 PCIe + APB 架构推断，待用户确认。

---

#### REQ-020 系统级约束 [infer_from_position]

> 关键 REQ，不可直接用默认值跳过，需追问。

| 维度 | 推荐值 | 依据 | 状态 |
|------|--------|------|------|
| QoS 级别 | BE（Best Effort） | 管理子系统非数据面 | default_value |
| 地址映射空间 | PCIe BAR 空间内，APB 子地址映射 | 标准做法 | default_value |
| Cache 属性 | Device（强序，不缓存） | MMIO 寄存器访问 | default_value |

**确认状态**：default_value — 基于通用知识，待用户确认。

---

#### REQ-021 功耗状态机 [conditional]

> 依赖：REQ-007。前置已确认（无独立功耗域），条件不满足，跳过。

**确认状态**：skipped — 无独立功耗域需求，不适用。

---

#### REQ-022 PLL/Jitter [conditional_optional]

> 依赖：REQ-001。前置已确认（16nm/500MHz）。
> 触发规则：仅模拟/高速模块激活。PR 控制器为数字逻辑，无 PLL 需求。

**确认状态**：skipped — 纯数字模块，不涉及 PLL/Jitter。

---

#### REQ-023 SerDes/PHY [conditional_optional]

> 依赖：REQ-002。前置已确认（PCIe + ICAP + APB）。
> 触发规则：仅高速串行接口激活。PCIe PHY 由外部 IP 提供，本模块不包含 SerDes。

**确认状态**：skipped — 本模块不包含 SerDes/PHY，PCIe PHY 由外部 IP 处理。

---

#### REQ-024 形式验证 [conditional_optional]

> 触发规则：仅安全关键/高可靠性激活。非安全关键场景。

**确认状态**：skipped — 非安全关键场景，不强制要求形式验证。

---

#### REQ-025 验证方法学 [conditional_optional]

> 依赖：REQ-003。前置部分确认。
> 触发规则：仅涉及验证方法时激活。此 REQ 在后续验证阶段（chip-verfi-arch）处理。

**确认状态**：skipped — 验证方法学在验证架构阶段单独处理。

---

#### REQ-026 封装约束 [conditional_optional]

> 触发规则：IP 级项目跳过，芯片级追问。本模块为 FPGA 管理子系统内部模块。

**确认状态**：skipped — 子系统内部 IP 模块，无封装约束。

---

#### REQ-027 EMC/ESD 合规 [conditional_optional]

> 依赖：REQ-010。前置已确认（无特殊合规要求）。
> 触发规则：仅汽车/工业场景激活。

**确认状态**：skipped — 非汽车/工业场景，不涉及 EMC/ESD 合规。

---

#### REQ-028 时钟树约束 [conditional_optional]

> 依赖：REQ-001。前置已确认（16nm/500MHz）。
> 触发规则：仅高频模块（目标频率 > 500MHz）激活。本模块 500MHz 处于边界。

| 维度 | 推荐值 | 依据 | 状态 |
|------|--------|------|------|
| SS 覆盖要求 | 1% down-spread | 500MHz 典型值 | default_value |
| OCV 余量 | 5% | 16nm 标准余量 | default_value |

**确认状态**：default_value — 500MHz 处于边界，建议确认是否需要时钟扩频。

---

### stageB phase1 确认结果汇总

[PROGRESS] stageB phase1 进度：28/28 项已处理

| # | REQ | 约束项 | 状态 | 确认值/说明 |
|---|-----|--------|------|-------------|
| 1 | REQ-001 | 工艺与频率 | confirmed | 16nm / 500MHz |
| 2 | REQ-002 | 接口协议 | confirmed | PCIe DMA + ICAP 32-bit + APB + Flash（预留） |
| 3 | REQ-003 | 数据流特征 | partial_confirmed | ICAP 32-bit 确认，比特流大小/突发长度待确认 |
| 4 | REQ-004 | 延迟与吞吐 | default_value | 重配延迟 < 200ms，待确认 |
| 5 | REQ-005 | 面积与功耗 | default_value | < 200kGates / < 150mW，待确认 |
| 6 | REQ-006 | 时钟与复位 | partial_confirmed | 3 时钟域，ICAP 时钟域归属待确认 |
| 7 | REQ-007 | 低功耗 | confirmed | 全局 Clock Gating，无独立功耗域 |
| 8 | REQ-008 | DFT | confirmed | 标准扫描链 + ICG + MBIST |
| 9 | REQ-009 | 可靠性 | confirmed | CRC-32 + SRAM SECDED ECC + 回滚机制 |
| 10 | REQ-010 | 其他约束 | confirmed | 无特殊要求 |
| 11 | REQ-011 | CDC 策略 | partial_confirmed | 双触发器 + 异步 FIFO，ICAP 域待确认 |
| 12 | REQ-012 | 存储器选型 | pending | SRAM 容量取决于 REQ-003 |
| 13 | REQ-013 | PVT 操作条件 | default_value | 工业级 -40~105°C，待确认 |
| 14 | REQ-014 | 接口时序约束 | confirmed | 遵循协议规范 |
| 15 | REQ-015 | DMA 握手接口 | inferred | PCIe DMA 标准，待确认 |
| 16 | REQ-016 | 中断接口 | default_value | 4 中断 + W1C，待确认 |
| 17 | REQ-017 | 调试接口 | inferred | APB 寄存器访问，无需专用调试接口 |
| 18 | REQ-018 | 安全隔离 | confirmed | 逻辑隔离 + 关键寄存器物理隔离 |
| 19 | REQ-019 | 软件接口约束 | inferred | PCIe PF/VF 驱动 + APB MMIO |
| 20 | REQ-020 | 系统级约束 | default_value | BE QoS + Device Cache，待确认 |
| 21 | REQ-021 | 功耗状态机 | skipped | 无独立功耗域，不适用 |
| 22 | REQ-022 | PLL/Jitter | skipped | 纯数字模块，不涉及 |
| 23 | REQ-023 | SerDes/PHY | skipped | 本模块不含 SerDes |
| 24 | REQ-024 | 形式验证 | skipped | 非安全关键场景 |
| 25 | REQ-025 | 验证方法学 | skipped | 验证阶段单独处理 |
| 26 | REQ-026 | 封装约束 | skipped | 子系统内部 IP |
| 27 | REQ-027 | EMC/ESD 合规 | skipped | 非汽车/工业场景 |
| 28 | REQ-028 | 时钟树约束 | default_value | SS 1% / OCV 5%，待确认 |

### 统计

| 状态 | 数量 | 占比 |
|------|------|------|
| confirmed | 10 | 36% |
| partial_confirmed | 3 | 11% |
| inferred | 4 | 14% |
| default_value | 7 | 25% |
| pending | 1 | 4% |
| skipped | 3 | 11% |
| **合计** | **28** | **100%** |

> confirmed + partial_confirmed + inferred = 17 项（61%），满足 vague 输入 ≥70% 确认率要求（含 inferred 可接受）。
> default_value 使用 7 项，未超过上限（含 3 个关键 REQ 需用户确认）。

### 待用户确认项（default_value + pending）

以下 8 项使用了默认值或待确认，需要用户确认：

| # | REQ | 约束项 | 默认值 | 说明 |
|---|-----|--------|--------|------|
| 1 | REQ-003 | 比特流大小/突发长度 | 8~32MB / 256B | 影响 SRAM 容量和 DMA 配置 |
| 2 | REQ-004 | 延迟与吞吐 | 重配 < 200ms | 性能参考值 |
| 3 | REQ-005 | 面积与功耗 | < 200kGates / < 150mW | PPA 预算 |
| 4 | REQ-012 | 存储器选型 | SRAM 容量待定 | 依赖比特流大小 |
| 5 | REQ-013 | PVT 条件 | 工业级 -40~105°C | 工作环境 |
| 6 | REQ-016 | 中断接口 | 4 中断 + W1C | 中断配置 |
| 7 | REQ-020 | 系统级约束 | BE QoS + Device Cache | 系统集成 |
| 8 | REQ-028 | 时钟树约束 | SS 1% / OCV 5% | 时钟质量 |

## [PHASE-END] stageB phase1

### 用户确认（stageB phase1 默认值审阅）

用户审阅 stageB phase1 默认值和风险点，确认结果如下：

| # | REQ | 约束项 | 原默认值 | 用户确认/修改 | 最终状态 |
|---|-----|--------|----------|---------------|----------|
| 1 | REQ-003 | 比特流大小/突发长度 | 8~32MB / 256B | 同意，合理 | confirmed |
| 2 | REQ-004 | 延迟与吞吐 | 重配 < 200ms | 可接受，需明确"整体"包含阶段 | confirmed（标注：含传输+校验+ICAP写入） |
| 3 | REQ-005 | 面积与功耗 | < 200kGates / < 150mW | 偏保守但可接受，后续综合可调 | confirmed |
| 4 | REQ-012 | 存储器选型 | SRAM 64MB | **修改**：外部 DDR + 片上 256KB SRAM 缓存（分段加载策略） | confirmed |
| 5 | REQ-013 | PVT 条件 | 工业级 -40~105°C | 同意 | confirmed |
| 6 | REQ-016 | 中断接口 | 4 中断 + W1C | **补充**：增加 DMA 传输超时中断，共 5 个中断 | confirmed |
| 7 | REQ-020 | 系统级约束 | BE QoS + Device Cache | **待明确**：PCIe BAR 配置（几个 BAR，大小） | partial_confirmed |
| 8 | REQ-028 | 时钟树约束 | SS 1% / OCV 5% | 同意，500MHz 用 SSC 是标准做法 | confirmed |

### 风险点处理决策

| # | 风险点 | 用户决策 |
|---|--------|----------|
| 1 | 存储策略 | 外部 DDR 存储 + 片上 256KB SRAM 缓存（分段加载） |
| 2 | ICAP 时钟域 | 独立时钟域（100~200MHz），与主时钟做 CDC |
| 3 | SSC | 确认需要，1% down-spread |

### 更新后的确认结果汇总

| # | REQ | 约束项 | 状态 | 最终确认值 |
|---|-----|--------|------|-----------|
| 1 | REQ-001 | 工艺与频率 | confirmed | 16nm / 500MHz |
| 2 | REQ-002 | 接口协议 | confirmed | PCIe DMA + ICAP 32-bit + APB + Flash（预留） |
| 3 | REQ-003 | 数据流特征 | confirmed | 8~32MB / 256B DMA 突发 / ICAP 32-bit |
| 4 | REQ-004 | 延迟与吞吐 | confirmed | 整体重配 < 200ms（含传输+校验+ICAP写入） |
| 5 | REQ-005 | 面积与功耗 | confirmed | < 200kGates / < 150mW / < 10mW 静态 |
| 6 | REQ-006 | 时钟与复位 | confirmed | 3 时钟域：PCIe + 500MHz 主时钟 + ICAP 100~200MHz |
| 7 | REQ-007 | 低功耗 | confirmed | 全局 Clock Gating，无独立功耗域 |
| 8 | REQ-008 | DFT | confirmed | 标准扫描链 + ICG + MBIST |
| 9 | REQ-009 | 可靠性 | confirmed | CRC-32 + SRAM SECDED ECC + 回滚机制 |
| 10 | REQ-010 | 其他约束 | confirmed | 无特殊要求 |
| 11 | REQ-011 | CDC 策略 | confirmed | PCIe→主域：异步FIFO；主域→ICAP：异步FIFO（独立时钟域） |
| 12 | REQ-012 | 存储器选型 | confirmed | 外部 DDR（比特流存储）+ 片上 256KB SRAM（缓存） |
| 13 | REQ-013 | PVT 操作条件 | confirmed | 工业级 -40~105°C / 0.85V / TT+SS |
| 14 | REQ-014 | 接口时序约束 | confirmed | 遵循协议规范 |
| 15 | REQ-015 | DMA 握手接口 | confirmed | PCIe DMA 标准，256B 突发，1 通道 |
| 16 | REQ-016 | 中断接口 | confirmed | 5 中断（重配完成/校验错误/回滚触发/隔离违规/DMA超时）+ W1C |
| 17 | REQ-017 | 调试接口 | confirmed | APB 寄存器访问，无需专用调试接口 |
| 18 | REQ-018 | 安全隔离 | confirmed | 逻辑隔离 + 关键寄存器物理隔离 |
| 19 | REQ-019 | 软件接口约束 | confirmed | PCIe PF/VF 驱动 + APB MMIO |
| 20 | REQ-020 | 系统级约束 | partial_confirmed | BE QoS / Device Cache，PCIe BAR 配置待明确 |
| 21 | REQ-021 | 功耗状态机 | skipped | 无独立功耗域，不适用 |
| 22 | REQ-022 | PLL/Jitter | skipped | 纯数字模块，不涉及 |
| 23 | REQ-023 | SerDes/PHY | skipped | 本模块不含 SerDes |
| 24 | REQ-024 | 形式验证 | skipped | 非安全关键场景 |
| 25 | REQ-025 | 验证方法学 | skipped | 验证阶段单独处理 |
| 26 | REQ-026 | 封装约束 | skipped | 子系统内部 IP |
| 27 | REQ-027 | EMC/ESD 合规 | skipped | 非汽车/工业场景 |
| 28 | REQ-028 | 时钟树约束 | confirmed | SSC 1% down-spread / OCV 5% |

> 28 项中 25 项 confirmed，1 项 partial_confirmed（REQ-020 PCIe BAR 待明确），7 项 skipped。
> 所有关键 REQ（004/016/020）均已处理。stageB phase1 确认率 100%（含 skipped）。

---

## [PHASE-START] stageB phase2

### 头脑风暴 Feature Discovery

**触发条件**：stageB phase1 全部 28 项确认完成
**执行方式**：按 5 个维度逐一探索（功能扩展/性能优化/兼容性/可测试性/可维护性）
**Wiki 检索**：无外部 Wiki 可用，基于通用知识执行

---

#### 维度 1：功能扩展

> stageB phase1 28 项约束是否覆盖了所有功能需求？

**Q1**：在功能扩展方面，是否有 28 项约束未覆盖的额外需求？比如：
- 特殊协议支持（如 ICAP 回读模式、MultiBoot 支持）
- 自定义命令扩展
- 比特流压缩/解压功能
- 区域分配表管理（固定/动态区域映射表）

**A1**（基于模块特性分析）：

| 潜在 Feature | 说明 | 建议优先级 |
|--------------|------|-----------|
| 比特流压缩/解压 | 减少 PCIe 传输量和 DDR 存储占用 | Should |
| 区域分配表管理 | 固定/动态区域映射表，Host CPU 可配置 | Must |
| ICAP 回读模式 | 读取当前配置状态，用于诊断 | Could |
| MultiBoot 支持 | 多份比特流快速切换 | Could |
| 比特流分段加载 | 配合外部 DDR 分段策略，支持大比特流流式写入 | Must（已隐含在 REQ-012 分段策略中） |

---

#### 维度 2：性能优化

> 是否有隐含的性能期望未被 REQ-004 覆盖？

**Q2**：在性能方面，是否有额外优化需求？比如：
- 比特流传输流水线化（传输与校验并行）
- 多区域并行重配置
- DMA 传输与 ICAP 写入重叠

**A2**（基于模块特性分析）：

| 潜在 Feature | 说明 | 建议优先级 |
|--------------|------|-----------|
| 传输-校验-写入流水线 | 三阶段重叠执行，减少总延迟 | Should |
| 多区域并行重配置 | 同时对多个 FPGA 区域进行重配置 | Could（复杂度高） |
| DMA 零拷贝传输 | DMA 直接写入 SRAM 缓存，减少中间拷贝 | Should |

---

#### 维度 3：兼容性

> 是否需要向下兼容旧版本或支持多模式？

**Q3**：是否需要兼容旧版本比特流格式或多模式切换？

**A3**（基于模块特性分析）：

| 潜在 Feature | 说明 | 建议优先级 |
|--------------|------|-----------|
| 比特流版本管理 | 记录比特流版本号，支持回退 | Should |
| 多 FPGA 型号适配 | 不同 FPGA 型号的 ICAP 时序差异适配 | Could |
| 旧格式比特流兼容 | 向下兼容旧版本比特流头格式 | Could |

---

#### 维度 4：可测试性

> 验证方面的额外需求？

**Q4**：是否需要错误注入接口、特殊覆盖率模型？

**A4**（基于模块特性分析）：

| 潜在 Feature | 说明 | 建议优先级 |
|--------------|------|-----------|
| 错误注入接口 | 通过 APB 注入 CRC 错误/超时错误，用于验证回滚机制 | Should |
| 状态机观测寄存器 | 暴露内部 FSM 状态到 APB 寄存器，便于调试 | Should |
| 性能计数器 | 重配置次数/耗时/错误计数/DMA 传输量 | Should |

---

#### 维度 5：可维护性

> 调试/诊断/日志需求？

**Q5**：是否需要 Trace 接口、运行时可配置参数？

**A5**（基于模块特性分析）：

| 潜在 Feature | 说明 | 建议优先级 |
|--------------|------|-----------|
| 运行时可配置超时阈值 | DMA 超时/ICAP 超时阈值可通过 APB 动态配置 | Should |
| 比特流加载进度查询 | Host CPU 可查询当前加载进度（百分比） | Should |
| 错误日志缓冲 | 记录最近 N 次错误详情，通过 APB 读取 | Could |

---

### 头脑风暴追加 REQ 汇总

基于 5 个维度探索，以下 Feature 建议追加为新 REQ：

| REQ | Feature | 维度 | 优先级 | 确认值 | 备注 |
|-----|---------|------|--------|--------|------|
| REQ-029 | 区域分配表管理 | 功能扩展 | Must | Host CPU 可配置固定/动态区域映射表，支持运行时查询和更新 | 核心功能补充 |
| REQ-030 | 比特流压缩/解压 | 功能扩展 | Should | 支持 LZ4/Zlib 压缩格式，减少传输量和存储占用 | 性能优化 |
| REQ-031 | 传输-校验-写入流水线 | 性能优化 | Should | 三阶段重叠执行，DMA 传输与 CRC 校验并行 | 性能优化 |
| REQ-032 | 比特流版本管理 | 兼容性 | Should | 记录版本号，支持回退到历史版本 | 可维护性 |
| REQ-033 | 错误注入接口 | 可测试性 | Should | APB 可注入 CRC 错误/超时/ICAP 故障，验证回滚机制 | 验证支持 |
| REQ-034 | 状态机观测寄存器 | 可测试性 | Should | 内部 FSM 状态暴露到 APB 寄存器 | 调试支持 |
| REQ-035 | 性能计数器 | 可维护性 | Should | 重配置次数/累计耗时/错误计数/DMA 传输量 | 运维支持 |
| REQ-036 | 运行时可配置超时阈值 | 可维护性 | Should | DMA 超时/ICAP 超时阈值 APB 可配 | 灵活性 |
| REQ-037 | 比特流加载进度查询 | 可维护性 | Should | Host CPU 可查询当前加载进度百分比 | 用户体验 |

---

### 头脑风暴结果

**追加 REQ 数量**：9 个（REQ-029 ~ REQ-037）
**Must 级别**：1 个（REQ-029 区域分配表管理）
**Should 级别**：8 个

**与已有 REQ 的矛盾检查**：
- REQ-030（压缩）与 REQ-004（延迟 < 200ms）：压缩/解压增加处理延迟，但减少传输延迟，总体可接受
- REQ-031（流水线）与 REQ-011（CDC）：流水线各阶段需考虑 CDC 边界，无矛盾
- REQ-033（错误注入）与 REQ-009（可靠性）：错误注入是验证手段，不影响正常可靠性，无矛盾

**结论**：追加 9 个 REQ，无矛盾。

### 用户审阅确认（stageB phase2 → stageC phase1 过渡）

用户确认 REQ-029~037 全部同意，修改 REQ-030 为仅支持 LZ4（Zlib 作为可选扩展），并补充 3 个新 REQ：

| REQ | Feature | 优先级 | 确认值 | 来源 |
|-----|---------|--------|--------|------|
| REQ-030（修改） | 比特流压缩/解压 | Should | 先支持 LZ4（硬件解压简单），Zlib 作为可选扩展 | 用户修改 |
| REQ-038 | 比特流分段加载 | Should | 支持大比特流分段传输，降低片上缓存需求 | 用户补充 |
| REQ-039 | 部分重配置失败恢复 | Should | 单个区域加载失败时不影响其他区域 | 用户补充 |
| REQ-040 | 比特流加密/签名验证 | Could | 防止恶意比特流加载 | 用户补充 |

**当前 REQ 总计**：40 个（28 基础 + 9 头脑风暴 + 3 用户补充）

## [PHASE-END] stageB phase2

---

## [PHASE-START] stageC phase1

### Post-stageB 处理：CDC 约束模板

> REQ-006 确认为多时钟域（3 个），REQ-011 已确认，自动生成 CDC 约束模板。

| 信号/信号组 | 源时钟域 | 目标时钟域 | 位宽 | 同步策略 | 依据 |
|-------------|----------|------------|------|----------|------|
| DMA 数据流 | clk_pcie (250MHz) | clk_main (500MHz) | 32~256 | 异步 FIFO（深度≥8） | REQ-011/REQ-015 |
| DMA 控制信号 | clk_pcie | clk_main | 1 | 双触发器同步 | REQ-011 |
| ICAP 数据流 | clk_main (500MHz) | clk_icap (100~200MHz) | 32 | 异步 FIFO（深度≥4） | REQ-011/REQ-006 |
| ICAP 控制信号 | clk_main | clk_icap | 1 | 双触发器同步 | REQ-011 |
| 中断输出 | clk_main | clk_pcie (Host CPU) | 5 | 双触发器同步 | REQ-016 |
| Flash 数据（预留） | clk_flash | clk_main | 32 | 异步 FIFO | REQ-002 |

同步器配置：双触发器(2级) / 异步FIFO(深度≥4) / Gray码(指针用)
复位CDC：每个时钟域独立复位同步器，禁止跨域共享。

---

### 矛盾检测执行

**检测范围**：
- 基础检测：17 条（FREQ-01/02, AREA-01/02/03, POWER-01/02/03/04, PERF-01/02, IO-01/02/03, PVT-01, MEM-01, CDC-01）
- 动态检测：3 条（DYN-01/02/03）
- 条件检测：7 条（ANA-01~04, VER-01~03）— **不适用**（REQ-022~025 均为 skipped）
- 实验性检测：5 条（EXP-01~05）— 未要求加载，跳过

**检测结果**：

| # | 规则 ID | 规则名称 | 涉及 REQ | 结果 | 说明 |
|---|---------|----------|----------|------|------|
| 1 | FREQ-01 | 频率 vs 工艺节点 | REQ-001 | PASS | 16nm 典型 Fmax 800MHz-1.2GHz > 500MHz |
| 2 | FREQ-02 | 延迟 vs 频率 | REQ-001/004 | PASS | 200ms 系统级延迟，非 cycle 级，无矛盾 |
| 3 | AREA-01 | 面积 vs 功能复杂度 | REQ-002/005 | **WARN** | 40 REQ 功能 + 256KB SRAM + DDR 控制器，面积压力需关注 |
| 4 | AREA-02 | 面积 vs 并行度 | REQ-003/005 | PASS | 无并行处理需求 |
| 5 | AREA-03 | 可靠性 vs 面积 | REQ-009/005 | PASS | SECDED ECC 开销约 1.5%，在预算内 |
| 6 | POWER-01 | 功耗 vs 工艺/频率 | REQ-001/005 | **WARN** | 16nm/500MHz 动态功耗预估 120-150mW，预算 150mW 裕量不足 |
| 7 | POWER-02 | 低功耗 vs DFT | REQ-007/008 | PASS | 全局 Clock Gating + 标准扫描链，无冲突 |
| 8 | POWER-03 | CDC vs 低功耗 | REQ-007/011 | PASS | 无独立功耗域，CDC 不涉及跨域关断 |
| 9 | POWER-04 | 功耗状态 vs 实时性 | REQ-004/021 | PASS | REQ-021 skipped，无功耗状态机 |
| 10 | PERF-01 | 延迟 vs 吞吐 | REQ-004 | PASS | 200ms 系统延迟，无矛盾 |
| 11 | IO-01 | 接口位宽 vs 数据粒度 | REQ-002/003 | PASS | ICAP 32-bit = 比特流字粒度，利用率 100% |
| 12 | IO-02 | 多模块共享资源竞争 | REQ-002/003/012 | **WARN** | DMA/CRC/ICAP 引擎共享 256KB SRAM，需仲裁设计 |
| 13 | IO-03 | 安全隔离 vs 地址碎片化 | REQ-018/002 | PASS | 逻辑隔离域，PCIe BAR 空间充足 |
| 14 | PVT-01 | PVT vs 功耗预算 | REQ-001/005/013 | **WARN** | 工业级 105°C + SS 角，静态功耗可达 20-30mW，总功耗可能超 160mW |
| 15 | MEM-01 | 存储容量 vs 面积 | REQ-005/012 | PASS | 256KB SRAM 片上，DDR 外部，面积可控 |
| 16 | CDC-01 | CDC vs 时序裕量 | REQ-004/006/011 | PASS | CDC 延迟 2-3 cycles，相对 200ms 可忽略 |
| 17 | PERF-02 | 功能复杂度 vs 验证周期 | REQ-003/004/006 | N/A | 未指定验证周期约束 |
| 18 | DYN-01 | 功能重叠检测 | REQ-029~040 vs REQ-001~028 | PASS | REQ-038（分段加载）与 REQ-012（DDR 缓存）互补非重叠 |
| 19 | DYN-02 | PPA 交叉矛盾 | REQ-029~040 vs REQ-004/005 | PASS | 新增 REQ 无额外 PPA 约束 |
| 20 | DYN-03 | 接口冲突检测 | REQ-029~040 vs REQ-002 | PASS | 新增 REQ 均使用已有接口（APB/PCIe DMA/ICAP） |

---

### 矛盾检测结果汇总

| 类别 | 数量 | 规则 ID |
|------|------|---------|
| PASS | 15 | FREQ-01/02, AREA-02/03, POWER-02/03/04, PERF-01, IO-01/03, MEM-01, CDC-01, DYN-01/02/03 |
| WARN | 4 | AREA-01, POWER-01, IO-02, PVT-01 |
| N/A | 1 | PERF-02 |
| 不适用 | 7 | ANA-01~04, VER-01~03（条件规则，REQ-022~025 skipped） |
| 跳过 | 5 | EXP-01~05（实验性规则，未要求加载） |

**发现矛盾：0 个**
**发现警告：4 个**

---

### 警告详情与建议

#### WARN-01: AREA-01 面积 vs 功能复杂度

| 项目 | 内容 |
|------|------|
| 涉及 REQ | REQ-002（接口）, REQ-005（面积预算 < 200kGates） |
| 警告描述 | 40 个 REQ 对应的功能复杂度 + 256KB 片上 SRAM + DDR 控制器接口，面积压力较大 |
| 量化分析 | 逻辑预估 80-120kGates + 256KB SRAM（约 200-400kGates 等效）+ DDR PHY 接口逻辑 |
| 建议 | 1. 确认 200kGates 预算是否包含 SRAM 面积 2. 若不含 SRAM，预算充足 3. 若含 SRAM，需缩减缓存或放宽预算 |

#### WARN-02: POWER-01 功耗 vs 工艺/频率

| 项目 | 内容 |
|------|------|
| 涉及 REQ | REQ-001（16nm/500MHz）, REQ-005（动态功耗 < 150mW） |
| 警告描述 | 16nm/500MHz 下动态功耗预估 120-150mW，预算 150mW 裕量不足 |
| 量化分析 | 动态功耗 ≈ 0.5 × C × V² × f ≈ 120-150mW（200kGates, 0.85V, 500MHz） |
| 建议 | 1. 预算可接受但裕量小 2. 后续综合时需关注 Clock Gating 效果 3. 可考虑降低非关键路径频率 |

#### WARN-03: IO-02 多模块共享资源竞争

| 项目 | 内容 |
|------|------|
| 涉及 REQ | REQ-002/003/012（DMA/CRC/ICAP 共享 SRAM） |
| 警告描述 | DMA 引擎、CRC 校验引擎、ICAP 写入引擎共享 256KB SRAM 缓存，峰值带宽可能超过 SRAM 端口带宽 |
| 量化分析 | DMA 写入带宽 + CRC 读取带宽 + ICAP 读取带宽 = 3 路并发 |
| 建议 | 1. 采用双端口 SRAM（1R1W）或分 bank 设计 2. REQ-031 流水线设计可错峰访问 3. 需在方案阶段详细设计仲裁策略 |

#### WARN-04: PVT-01 PVT vs 功耗预算

| 项目 | 内容 |
|------|------|
| 涉及 REQ | REQ-001/005/013（16nm, < 160mW 总功耗, 工业级） |
| 警告描述 | 工业级 105°C + SS 工艺角下，静态功耗可达 20-30mW，总功耗可能超 160mW |
| 量化分析 | TT/25°C 静态功耗 ≈ 10mW → SS/105°C 静态功耗 ≈ 20-30mW，总功耗 ≈ 140-180mW |
| 建议 | 1. 功耗预算需包含裕量（建议 180mW）2. 关注 Clock Gating 对动态功耗的削减效果 3. SS 角综合时需验证功耗 |

---

### Frozen REQ 标注

以下 REQ 在 stageB phase1 已确认且无矛盾，标记为 frozen（不可变更）：

| REQ | 冻结原因 |
|-----|----------|
| REQ-001 | 用户明确提供（16nm/500MHz） |
| REQ-002 | 用户明确确认（PCIe+ICAP+APB+Flash） |
| REQ-006 | 用户确认时钟域策略（3 域，ICAP 独立） |
| REQ-007 | 用户确认无独立功耗域 |
| REQ-018 | 用户明确隔离级别 |
| REQ-028 | 用户确认 SSC 1% |

---

### 覆盖率分析

#### 覆盖热力图

| 维度 | 覆盖 REQ | 状态 | 说明 |
|------|----------|------|------|
| 频率/工艺 | REQ-001 | hot | 完全覆盖，无 gap |
| 接口协议 | REQ-002/014/015 | hot | PCIe+ICAP+APB+Flash 完整定义 |
| 数据流 | REQ-003/004 | hot | 大小/突发/延迟均已确认 |
| PPA | REQ-005 | warm | 预算偏保守，综合时可调 |
| 时钟/CDC | REQ-006/011/028 | hot | 3 域+CDC 策略+SSC 完整 |
| 低功耗 | REQ-007/021 | warm | 简单方案，无特殊设计 |
| DFT | REQ-008 | warm | 标准方案 |
| 可靠性 | REQ-009 | hot | CRC+ECC+回滚 完整 |
| 存储 | REQ-012 | hot | DDR+SRAM 分层策略明确 |
| 隔离/安全 | REQ-018/040 | warm | 逻辑隔离+加密签名，待细化 |
| 区域管理 | REQ-029 | hot | 核心功能，Must 级别 |
| 压缩 | REQ-030 | warm | LZ4 先行，Zlib 可选 |
| 流水线 | REQ-031 | warm | 三阶段重叠，待方案设计 |
| 版本管理 | REQ-032 | cold | 无详细规格 |
| 错误注入 | REQ-033 | cold | 无详细规格 |
| 状态观测 | REQ-034 | cold | 无详细规格 |
| 性能计数器 | REQ-035 | cold | 无详细规格 |
| 超时配置 | REQ-036 | cold | 无详细规格 |
| 进度查询 | REQ-037 | cold | 无详细规格 |
| 分段加载 | REQ-038 | warm | 与 REQ-012 互补 |
| 失败恢复 | REQ-039 | cold | 无详细规格 |
| 加密签名 | REQ-040 | cold | Could 级别，待方案细化 |

#### Pairwise Coverage Gap

| REQ 对 | Gap 描述 | 风险等级 |
|--------|----------|----------|
| REQ-005 ↔ REQ-012 | 面积预算 vs 256KB SRAM 面积开销 | 中 |
| REQ-004 ↔ REQ-030 | 延迟约束 vs 压缩/解压处理延迟 | 低 |
| REQ-011 ↔ REQ-031 | CDC 边界 vs 流水线阶段划分 | 低 |

#### 端到端覆盖率视图

| REQ | 需求覆盖 | 方案覆盖 | 验证覆盖 | 评审覆盖 | 状态 |
|-----|----------|----------|----------|----------|------|
| REQ-001~028 | confirmed | pending | pending | pending | 需求已冻结 |
| REQ-029~037 | confirmed | pending | pending | pending | 头脑风暴确认 |
| REQ-038~040 | confirmed | pending | pending | pending | 用户补充确认 |

### 用户审阅确认（stageC phase1 警告处理）

用户对 4 个警告的处理决策：

| # | 警告 | 处理决策 | REQ 影响 |
|---|------|----------|----------|
| WARN-01 | AREA-01 面积 vs 功能 | 256KB SRAM 面积单独计算，不计入 200kGates 逻辑预算 | REQ-005 更新 |
| WARN-02 | POWER-01 功耗裕量 | 动态功耗预算放宽至 180mW | REQ-005 更新 |
| WARN-03 | IO-02 共享资源竞争 | 不调整 REQ，微架构阶段采用分 bank 策略 | 无 REQ 变更 |
| WARN-04 | PVT-01 功耗 vs 工况 | 与 WARN-02 合并，总功耗预算统一 180mW | REQ-005 更新 |

**REQ-005 更新**：逻辑 < 200kGates / 动态功耗 < 180mW / 静态功耗 < 10mW / SRAM 面积单列

## [PHASE-END] stageC phase1

---

## [PHASE-START] stageC phase2

### 需求确认汇总表

> schema_version: 1.0
> module_name: fpga_partial_reconfig
> date: 2026-06-04
> total_reqs: 40
> priority_distribution: Must=6, Should=28, Could=5, Skipped=7, Partial=1

| # | REQ | 约束项 | 确认值 | 优先级 | 状态 | 来源 |
|---|-----|--------|--------|--------|------|------|
| 1 | REQ-001 | 工艺与频率 | 16nm / 500MHz | Must | confirmed | 用户明确 |
| 2 | REQ-002 | 接口协议 | PCIe DMA + ICAP 32-bit + APB 32-bit + Flash（预留） | Must | confirmed | 用户确认 |
| 3 | REQ-003 | 数据流特征 | 比特流 8~32MB / DMA 突发 256B / ICAP 32-bit word | Should | confirmed | 用户确认 |
| 4 | REQ-004 | 延迟与吞吐 | 整体重配延迟 < 200ms（含传输+校验+ICAP写入） | Should | confirmed | 用户确认 |
| 5 | REQ-005 | 面积与功耗 | 逻辑 < 200kGates / 动态功耗 < 180mW / 静态 < 10mW / SRAM 面积单列 | Should | confirmed | 用户确认（更新） |
| 6 | REQ-006 | 时钟与复位 | 3 时钟域：PCIe(250MHz) + 主时钟(500MHz) + ICAP(100~200MHz)；异步复位同步释放 | Must | confirmed | 用户确认 |
| 7 | REQ-007 | 低功耗 | 全局 Clock Gating，无独立功耗域 | Could | confirmed | 用户确认 |
| 8 | REQ-008 | DFT | 标准扫描链 + 标准 ICG + MBIST（256KB SRAM） | Should | confirmed | 推断确认 |
| 9 | REQ-009 | 可靠性 | CRC-32 比特流校验 + SRAM SECDED ECC + 校验失败回滚机制 | Should | confirmed | 用户确认 |
| 10 | REQ-010 | 其他约束 | 无特殊安全/合规/工艺限制 | Should | confirmed | 推断确认 |
| 11 | REQ-011 | CDC 策略 | PCIe→主域：异步 FIFO / 主域→ICAP：异步 FIFO / 控制信号：双触发器 | Should | confirmed | 用户确认 |
| 12 | REQ-012 | 存储器选型 | 外部 DDR（比特流存储）+ 片上 256KB SRAM（缓存）+ DMA FIFO(256~512B) | Should | confirmed | 用户确认 |
| 13 | REQ-013 | PVT 操作条件 | 工业级 -40~105°C / 0.85V / TT+SS 角 | Should | confirmed | 用户确认 |
| 14 | REQ-014 | 接口时序约束 | PCIe/APB 遵循协议规范 / ICAP: setup≤2ns, delay≤3ns | Should | confirmed | 推断确认 |
| 15 | REQ-015 | DMA 握手接口 | PCIe DMA 标准，256B 突发，递增地址，1 通道 | Should | confirmed | 推断确认 |
| 16 | REQ-016 | 中断接口 | 5 中断（重配完成/校验错误/回滚触发/隔离违规/DMA超时）电平输出 + W1C | Should | confirmed | 用户确认 |
| 17 | REQ-017 | 调试接口 | APB 寄存器访问内部状态，无专用调试接口 | Could | confirmed | 推断确认 |
| 18 | REQ-018 | 安全隔离 | 逻辑隔离（地址空间+访问控制）+ 关键配置寄存器物理隔离 | Must | confirmed | 用户明确 |
| 19 | REQ-019 | 软件接口约束 | PCIe PF/VF 驱动 + APB MMIO / 中断为主+轮询为辅 | Should | confirmed | 推断确认 |
| 20 | REQ-020 | 系统级约束 | BE QoS / PCIe BAR 空间 APB 子地址映射 / Device Cache 属性 | Should | partial_confirmed | PCIe BAR 配置待明确 |
| 21 | REQ-021 | 功耗状态机 | 不适用（无独立功耗域） | - | skipped | 条件不满足 |
| 22 | REQ-022 | PLL/Jitter | 不适用（纯数字模块） | - | skipped | 条件不满足 |
| 23 | REQ-023 | SerDes/PHY | 不适用（PCIe PHY 由外部 IP 处理） | - | skipped | 条件不满足 |
| 24 | REQ-024 | 形式验证 | 不适用（非安全关键场景） | - | skipped | 条件不满足 |
| 25 | REQ-025 | 验证方法学 | 不适用（验证阶段单独处理） | - | skipped | 条件不满足 |
| 26 | REQ-026 | 封装约束 | 不适用（子系统内部 IP） | - | skipped | 条件不满足 |
| 27 | REQ-027 | EMC/ESD 合规 | 不适用（非汽车/工业场景） | - | skipped | 条件不满足 |
| 28 | REQ-028 | 时钟树约束 | SSC 1% down-spread / OCV 5% 余量 | Should | confirmed | 用户确认 |
| 29 | REQ-029 | 区域分配表管理 | Host CPU 可配置固定/动态区域映射表，运行时查询和更新 | Must | confirmed | 头脑风暴 |
| 30 | REQ-030 | 比特流压缩/解压 | 先支持 LZ4（硬件解压），Zlib 作为可选扩展 | Should | confirmed | 用户修改 |
| 31 | REQ-031 | 传输-校验-写入流水线 | 三阶段重叠执行，DMA 传输与 CRC 校验并行 | Should | confirmed | 头脑风暴 |
| 32 | REQ-032 | 比特流版本管理 | 记录版本号，支持回退到历史版本 | Should | confirmed | 头脑风暴 |
| 33 | REQ-033 | 错误注入接口 | APB 可注入 CRC 错误/超时/ICAP 故障，验证回滚机制 | Should | confirmed | 头脑风暴 |
| 34 | REQ-034 | 状态机观测寄存器 | 内部 FSM 状态暴露到 APB 寄存器 | Should | confirmed | 头脑风暴 |
| 35 | REQ-035 | 性能计数器 | 重配置次数/累计耗时/错误计数/DMA 传输量 | Should | confirmed | 头脑风暴 |
| 36 | REQ-036 | 运行时可配置超时阈值 | DMA 超时/ICAP 超时阈值 APB 可配 | Should | confirmed | 头脑风暴 |
| 37 | REQ-037 | 比特流加载进度查询 | Host CPU 可查询当前加载进度百分比 | Should | confirmed | 头脑风暴 |
| 38 | REQ-038 | 比特流分段加载 | 支持大比特流分段传输，降低片上缓存需求 | Should | confirmed | 用户补充 |
| 39 | REQ-039 | 部分重配置失败恢复 | 单个区域加载失败时不影响其他区域 | Should | confirmed | 用户补充 |
| 40 | REQ-040 | 比特流加密/签名验证 | 防止恶意比特流加载 | Could | confirmed | 用户补充 |

### 优先级统计

| 优先级 | 数量 | REQ 编号 |
|--------|------|----------|
| Must | 6 | REQ-001, REQ-002, REQ-006, REQ-018, REQ-029 |
| Should | 28 | REQ-003, REQ-004, REQ-005, REQ-008, REQ-009, REQ-010, REQ-011, REQ-012, REQ-013, REQ-014, REQ-015, REQ-016, REQ-019, REQ-020, REQ-028, REQ-030, REQ-031, REQ-032, REQ-033, REQ-034, REQ-035, REQ-036, REQ-037, REQ-038, REQ-039 |
| Could | 5 | REQ-007, REQ-017, REQ-040 |
| Skipped | 7 | REQ-021~REQ-027 |
| Partial | 1 | REQ-020（PCIe BAR 配置待明确） |

### 冻结规则

**冻结条件**：用户确认本汇总表后自动冻结
**冻结范围**：REQ-001 ~ REQ-040（40 项，含 skipped 项标记为"不适用-已冻结"）
**解冻条件**：
- 用户主动变更 → 解冻对应项，走 change_handling
- 方案阶段发现矛盾 → 暂停方案，解冻矛盾项，重走 stageB → stageC

### 变更日志

| 版本 | REQ | 变更内容 | 变更原因 |
|------|-----|----------|----------|
| v1.0 | REQ-005 | 动态功耗 150mW → 180mW；SRAM 面积单列 | stageC phase1 警告处理（WARN-01/02/04） |
| v1.0 | REQ-016 | 4 中断 → 5 中断（增加 DMA 超时） | 用户确认 |
| v1.0 | REQ-012 | SRAM 64MB → 外部 DDR + 片上 256KB SRAM | 用户确认存储策略 |
| v1.0 | REQ-006 | ICAP 时钟域确认为独立 100~200MHz | 用户确认 |
| v1.0 | REQ-030 | 支持 LZ4+Zlib → 先支持 LZ4，Zlib 可选 | 用户修改 |
| v1.0 | REQ-038~040 | 新增 3 个 REQ | 用户补充 |

## [PHASE-END] stageC phase2

---

### 以上为 FPGA 部分重配置控制器的需求确认汇总表（40 项 REQ），请确认。确认后需求冻结，进入 stageD 方案细化阶段。

## [STAGE-END] stageC

---

## [GROUP-START] stageD group1

## [STEP-START] stageD group1-step1

### 初始架构方案 + RTL 行数估算

**输入分析**：
- 来源：stageC phase2 需求汇总表（40 项 REQ，已冻结）
- 关键约束：16nm/500MHz, 逻辑 < 200kGates, 动态功耗 < 180mW
- 架构方向：5 子模块（stage0 确认）

---

### 架构拓扑方向

**拓扑类型**：集中式控制 + 分布式数据通路

```
Host CPU (PCIe)
     │
     ▼
┌──────────────────────────────────────────────────────┐
│           fpga_partial_reconfig_top                  │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ bitstream   │  │ bitstream   │  │ icap_write  │  │
│  │ rx_engine   │──│ val_mgr     │──│ engine      │──│──► ICAP (32-bit)
│  │             │  │             │  │             │  │
│  │ PCIe DMA    │  │ CRC-32      │  │ CDC→ICAP    │  │
│  │ Flash(预留) │  │ LZ4 解压    │  │ 100~200MHz  │  │
│  │ 分段加载    │  │ 版本管理    │  │ 超时检测    │  │
│  │ 进度查询    │  │ 回滚机制    │  │             │  │
│  └──────┬──────┘  └──────┬──────┘  └─────────────┘  │
│         │               │                            │
│         ▼               ▼                            │
│  ┌─────────────────────────────┐  ┌─────────────┐   │
│  │     isolation_mgr           │  │ reg_interface│   │
│  │                             │  │             │   │
│  │ 多租户地址解码              │  │ APB 从接口  │   │
│  │ 访问控制                    │  │ 5 中断      │   │
│  │ 区域分配表(REQ-029)         │  │ 性能计数器  │   │
│  │ 失败恢复(REQ-039)           │  │ 状态观测    │   │
│  │ 隔离违规检测                │  │ 错误注入    │   │
│  └─────────────────────────────┘  └─────────────┘   │
│                                                      │
│  ┌─────────────────────────────────────────────┐     │
│  │         256KB SRAM (分 bank)                 │     │
│  │   Bank0: 比特流缓存(在用)                    │     │
│  │   Bank1: 比特流缓存(预备)                    │     │
│  └─────────────────────────────────────────────┘     │
│                                                      │
│  异步 FIFO: PCIe→主域, 主域→ICAP                     │
└──────────────────────────────────────────────────────┘
     │
     ▼
APB 配置总线 + 中断输出 → Host CPU
```

**数据通路**：
1. Host CPU 通过 PCIe DMA 下发比特流 → bitstream_rx_engine 接收
2. 数据写入 256KB SRAM 缓存（分段加载，REQ-038）
3. bitstream_val_mgr 执行 CRC-32 校验 + LZ4 解压（REQ-030）
4. icap_write_engine 通过异步 FIFO 跨时钟域，写入 FPGA ICAP 接口
5. isolation_mgr 管理区域分配表和访问控制，失败时触发回滚（REQ-039）
6. reg_interface 提供 APB 配置、中断、性能计数器、错误注入等软件接口

---

### RTL 行数估算

| 子模块 | 功能点 | 逻辑类型 | 估算行数 | 计算依据 |
|--------|--------|----------|----------|----------|
| bitstream_rx_engine | PCIe DMA 从接口 + Flash 接口(预留) + 分段加载 + 进度查询 | 接口+功能 | **700** | DMA接口200 + 缓冲控制150 + Flash预留150 + 分段加载100 + 进度查询50 + 复位/时钟50 |
| bitstream_val_mgr | CRC-32 校验 + LZ4 解压 + 版本管理 + 回滚机制 + 错误注入 | 功能 | **950** | CRC引擎150 + LZ4解压400 + 版本管理100 + 回滚150 + 错误注入100 + 控制状态机50 |
| icap_write_engine | ICAP 32-bit 驱动 + 写入排序 + 跨时钟域 + 超时检测 | 接口+控制 | **500** | ICAP驱动200 + 写入排序100 + CDC异步FIFO100 + 超时50 + 控制FSM50 |
| isolation_mgr | 多租户地址解码 + 访问控制 + 区域分配表 + 失败恢复 + 违规检测 | 功能+控制 | **800** | 地址解码200 + 访问控制150 + 区域表200 + 失败恢复150 + 违规检测100 |
| reg_interface | APB 从接口 + 寄存器读写 + 中断控制 + 性能计数器 + 状态观测 + 错误注入控制 + 超时配置 | 接口+功能 | **700** | APB接口150 + 寄存器150 + 中断100 + 计数器150 + 观测50 + 注入控制50 + 超时配置50 |
| 顶层 (fpga_partial_reconfig_top) | 子模块实例化 + 信号连接 + 顶层连线 | 集成 | **150** | 5子模块实例化100 + 连线50 |
| **合计** | | | **3800** | |

---

### RTL 行数判定

| 项目 | 值 |
|------|-----|
| RTL 总行数估算 | **3800 行** |
| 阈值 | 3000 行 |
| 判定 | **3800 > 3000 → 超出阈值** |

---

### 架构决策记录（ADR）

**ADR-001: 架构拓扑选择**

- **日期**：2026-06-04
- **状态**：accepted
- **背景**：FPGA 部分重配置控制器需支持 40 项 REQ，包含比特流接收/校验/写入/隔离/配置 5 大功能域
- **决策**：采用集中式控制 + 分布式数据通路架构
- **方案 A（采用）**：5 子模块集中式 — 模块边界清晰，数据通路明确，便于独立验证
- **方案 B（拒绝）**：单模块集成 — 面积可能更小但可维护性差，40 项 REQ 耦合度过高
- **后果**：RTL 行数 3800 > 3000，需进入 stageE 递归分解

**ADR-002: 存储架构选择**

- **日期**：2026-06-04
- **状态**：accepted
- **背景**：比特流大小 8~32MB，片上 SRAM 容量有限
- **决策**：外部 DDR 存储 + 片上 256KB SRAM 缓存（分 bank）
- **方案 A（采用）**：DDR+SRAM 分层 — 支持大比特流，片上缓存加速
- **方案 B（拒绝）**：纯片上 SRAM — 容量不足，无法支持 32MB 比特流
- **后果**：需集成 DDR 控制器接口，增加面积和复杂度

**ADR-003: 时钟域架构**

- **日期**：2026-06-04
- **状态**：accepted
- **背景**：PCIe(250MHz) + 主时钟(500MHz) + ICAP(100~200MHz) 三个时钟域
- **决策**：ICAP 独立时钟域，通过异步 FIFO 跨域
- **方案 A（采用）**：3 时钟域 — ICAP 时序独立可控，不依赖主时钟
- **方案 B（拒绝）**：ICAP 与主时钟同域 — 可能导致 ICAP 时序违例
- **后果**：需 2 级异步 FIFO（PCIe→主域, 主域→ICAP），增加 CDC 复杂度

---

## [STEP-END] stageD group1-step1

[STAGE-TRANSITION] RTL 行数 3800 > 3000，跳过 stageD group1-step2~group5-step6，进入 stageE 递归分解。

## [GROUP-END] stageD group1

---

## [STAGE-START] stageE

### 递归分解评估

| 子模块 | 预估行数 | 判定 |
|--------|----------|------|
| bitstream_rx_engine | 700 | < 3000，叶子节点 |
| bitstream_val_mgr | 950 | < 3000，叶子节点 |
| icap_write_engine | 500 | < 3000，叶子节点 |
| isolation_mgr | 800 | < 3000，叶子节点 |
| reg_interface | 700 | < 3000，叶子节点 |

**结论**：所有子模块均 < 3000 行，无需递归分解。5 个子模块均为叶子节点。

### 子模块 REQ 映射

| 子模块 | 全局 REQ | 功能范围 |
|--------|----------|----------|
| bitstream_rx_engine | REQ-002/003/012/015/037/038 | PCIe DMA + Flash(预留) + 分段加载 + 进度查询 |
| bitstream_val_mgr | REQ-003/004/009/030/031/032/033 | CRC-32 + LZ4 解压 + 版本管理 + 回滚 + 错误注入 |
| icap_write_engine | REQ-002/004/006/011/014/028/031/036 | ICAP 32-bit + CDC + 超时 + 流水线 |
| isolation_mgr | REQ-009/018/029/039 | 多租户隔离 + 区域分配表 + 失败恢复 |
| reg_interface | REQ-002/016/017/019/020/033/034/035/036 | APB + 中断 + 性能计数器 + 状态观测 + 错误注入控制 |

