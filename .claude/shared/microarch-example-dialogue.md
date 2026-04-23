# 微架构编写示例对话

> 以下示例展示 FS 完整（complete）类型的微架构编写流程。实际执行时每次一个子模块。
> 供 chip-microarch-writer Agent 参考，不在 Agent 定义中内联。

---

## 示例 1：标准编写流程（连续模式）

```
用户：帮我写 DMA 引擎的微架构文档，FS 在 dma_FS_v1.0.md

Agent：
## 代办清单（连续模式）
| # | 步骤 | 预期输出 | 组 |
|---|------|----------|-----|
| 1 | 输入确认 | FS 完整性检查 | A |
| 2 | 子模块拆分 | 子模块列表 | A |
| 3 | 子模块1：DMA控制器 | 微架构文档 | B |
| 4 | 子模块2：AXI Master接口 | 微架构文档 | B |
| 5 | 集成一致性检查 | 检查报告 | C |
| 6 | 质量自检 | 自检报告 | C |

用户：确认

Agent：【输入确认】
FS 文档 dma_FS_v1.0.md 完整（§3~§14）。子模块划分从 §3.3 提取：
- DMA 控制器（控制逻辑+寄存器配置）
- AXI Master 接口（数据搬运）
A 组确认后执行，B 组逐个编写。

用户：确认

Agent：【子模块拆分】
子模块列表确认：
1. dma_ctrl — DMA 控制器（APB 从接口 + 通道控制 + 描述符解析）
2. dma_axi_master — AXI Master 接口（数据搬运 + 突发控制）
接口拓扑：dma_ctrl → dma_axi_master（内部数据请求接口）
A 组完成。开始 B 组，先写 dma_ctrl。

用户：继续

Agent：【子模块1：dma_ctrl 微架构 — 节选】

§3.1 功能定位：DMA 通道控制核心，接收 CPU 配置，解析传输描述符，向 AXI Master 发起数据搬运请求。

§4.1 端口列表：
| # | 信号名 | 方向 | 位宽 | 类型 | 时钟域 | 复位值 | 功能 |
|---|--------|------|------|------|--------|--------|------|
| 1 | clk | I | 1 | wire | - | - | 主时钟 |
| 2 | rst_n | I | 1 | wire | - | - | 异步复位 |
| 3 | apb_psel | I | 1 | wire | clk | 0 | APB 选择 |
| ... | ... | ... | ... | ... | ... | ... | ... |

§5.3 状态机：
| 当前状态 | 转移条件 | 次态 | 输出动作 |
|----------|----------|------|----------|
| S_IDLE | ch_en && !busy | S_FETCH | 拉高 desc_fetch_en |
| S_FETCH | desc_valid | S_XFER | 加载 src/dst/len |
| S_XFER | xfer_done | S_IDLE | 拉高 ch_done_irq |
| S_IDLE | default | S_IDLE | - |
（后续 §6~§13 略）

子模块1 完成。开始子模块2：dma_axi_master。

用户：继续
...
```

---

## 示例 2：集成一致性检查

```
Agent：【集成一致性检查】

检查结果：
✅ MA-01 数据通路连通：APB配置 → dma_ctrl → dma_axi_master → AXI4 Master → DDR
✅ MA-03 FIFO 深度匹配：cmd_fifo 深度8 ≥ B_max(4) + D_fb(2) × 1 = 6
✅ MA-05 FSM default：两个子模块状态机均有 default 分支
⚠️ MA-06 PPA 合计：逻辑面积 12kGates + 8kGates = 20kGates，FS 预算 25kGates → 通过
❌ MA-07 端口映射：dma_ctrl.dma_req 信号位宽 32bit，dma_axi_master.dma_req 位宽 16bit → 不一致

修复建议：统一为 DATA_WIDTH 参数。
```

---

## 示例 3：专项 agent 协作（CDC 输出继承）

```
Agent：【专项 agent 协作 — CDC architect 输出继承】

检测到 requirement-arch 阶段已执行 chip-cdc-architect，输出自动继承到 §7 CDC 处理：

§7.3 CDC 处理（继承自 chip-cdc-architect 输出）

| 信号/信号组 | 源时钟域 | 目标时钟域 | 位宽 | 同步策略 | 依据 |
|-------------|----------|------------|------|----------|------|
| dma_req | clk_core | clk_axi | 32 | 异步FIFO（深度4） | REQ-011 |
| dma_done | clk_axi | clk_core | 1 | 双触发器（2级） | REQ-011 |

补充子模块级 CDC 细节：
- dma_ctrl 侧：dma_req 写入异步 FIFO 前打一拍流水
- dma_axi_master 侧：FIFO 读出后增加 valid 打拍
```

---

## 示例 4：FS 变更→增量更新

```
用户：FS 文档从 v1.0 更新到 v1.1，变更内容：REQ-005 新增低功耗模式要求，§5.3 新增 power_down 子状态。请增量更新微架构文档。

Agent：【FS 变更检测 — 增量更新】

变更分析（对比 dma_FS_v1.0.md → dma_FS_v1.1.md）：
| 变更类型 | 影响范围 | 需更新章节 |
|----------|----------|-----------|
| REQ-005 新增低功耗模式 | dma_ctrl + dma_axi_master | §3.1 需求继承、§10 低功耗设计 |
| §5.3 新增 power_down 子状态 | dma_ctrl | §5.3 状态机、§6 时序分析 |
| 无接口变更 | - | §4 跳过 |
| 无 PPA 变更 | - | §8 跳过 |

增量更新计划：
1. 更新 dma_ctrl 微架构：§3.1（REQ-005 追加）、§5.3（新增 S_POWER_DOWN 状态）、§6（检查关键路径影响）
2. 更新 dma_axi_master 微架构：§3.1（REQ-005 追加）、§10（功耗域划分细化）
3. 重新运行 integration_check（MA-02 检查新增状态是否影响时序）
4. 更新中间状态 JSON（fs_version → v1.1）

开始执行。先更新 dma_ctrl §3.1...
```
