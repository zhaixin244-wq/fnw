# 调试 chip-requirement-arch

调试芯片需求探索 Agent 的流程与质量。通过双 Agent 自动对话验证流程完整性。

## 用法

```
/test-chip-requirement-arch [scenario_id]
```

## 可用场景

| 场景 ID | 名称 | 描述 | 用户角色 |
|---------|------|------|----------|
| `basic_dma` | 基础 DMA | 标准流程测试 | clear_expert |
| `complex_pcie` | 复杂 PCIe | 高级场景测试 | clear_expert |
| `vague_input` | 模糊输入 | 边界测试 | vague_beginner |
| `edge_cases` | 边界条件 | 异常处理测试 | challenging_reviewer |
| `complex_random` | 复杂模块随机 | 从 50 个 40k+ RTL 模块池随机选择，覆盖全部测试维度 | 随机（E/C/V） |

### 复杂模块池（complex_random）

50 个面向 4 万行以上 RTL 的复杂模块，覆盖 10 个技术领域：
- **互联**：PCIe Gen5 RC、CXL 3.0、UCIe、CHI、HBM3、NoC、PCIe Switch、PCIe/CXL 混合交换、PCIe Gen5 PHY
- **存储**：NVMe 2.0、DDR5、RAID、ZNS、压缩引擎、NVMe-oF、NAND Flash、DDR5 PHY
- **网络**：100G MAC、交换矩阵、DPU SmartNIC、P4 解析器、10G PHY、TSN、RDMA NIC
- **计算**：NPU 卷积、GPU Shader、RISC-V 向量/乱序、DSP、AI SoC 互联、张量核心、稀疏加速、Transformer
- **安全**：国密加密、安全飞地
- **多媒体**：8K 编解码、ISP、显示控制器、音频 DSP
- **汽车**：ADAS 融合、CAN-FD 网关
- **内存**：LLC、CXL 内存交换
- **可重构**：CGRA 加速器、FPGA 重配置
- **IO**：USB4 Hub、MIPI CSI-2、USB 3.2、HDMI 2.1
- **SoC 基础设施**：GICv4 中断控制器

详细模块列表和覆盖矩阵见 `scenarios/complex_modules/README.md`。

## 执行流程

1. **初始化**：读取场景配置和用户角色
2. **启动对话**：用户 Agent 发送初始输入
3. **循环执行**：双 Agent 交替对话直到完成
4. **质量评估**：检查流程完整性和交付物质量
5. **生成报告**：输出对话记录和评估报告

## 输出位置

```
.claude/debug/chip-requirement-arch/debug_output/{scenario}_{timestamp}/
├── dialog.md           # 完整对话记录
├── evaluation.md       # 质量评估报告
├── summary.md          # 调试摘要
└── outputs/            # 生成的交付物
```

## 示例

```bash
# 运行基础 DMA 场景
/test-chip-requirement-arch basic_dma

# 运行模糊输入场景
/test-chip-requirement-arch vague_input

# 运行复杂模块随机场景（从 50 个 40k+ RTL 模块中随机选择）
/test-chip-requirement-arch complex_random
```

## 评估标准

复用 `.claude/evaluation_criteria/chip-requirement-arch-eva.md` 中的评估标准。

---

## 执行指令

当用户调用此命令时，执行以下步骤：

### 1. 解析参数
```
scenario_id = $1 (默认: basic_dma)
```

### 2. 加载配置

**标准场景**（basic_dma / complex_pcie / vague_input / edge_cases）：
```
场景配置: .claude/debug/chip-requirement-arch/scenarios/{scenario_id}.json
用户角色: .claude/debug/chip-requirement-arch/user-personas/{user_persona}.json
```

**复杂模块随机场景**（complex_random）：
```
模块池: .claude/debug/chip-requirement-arch/scenarios/complex_modules/module_pool.json
覆盖矩阵: .claude/debug/chip-requirement-arch/scenarios/complex_modules/coverage_matrix.json

选择逻辑:
1. 读取 module_pool.json 的 modules 数组
2. 随机选择 1 个模块（可选：batch 模式选 5 个，balanced 模式按角色均衡选 8 个）
3. 将选中模块的 context + initial_input 作为场景配置
4. 根据模块的 user_persona 字段选择用户角色（E→clear_expert, C→challenging_reviewer, V→vague_beginner）
5. 使用模块的 timeout_minutes 和 max_dialog_rounds 作为超时和轮数限制
```

### 3. 创建调试会话
```
timestamp = 当前时间戳
work_dir = .claude/debug/chip-requirement-arch/debug_output/{scenario_id}_{timestamp}
mkdir -p {work_dir}/outputs
mkdir -p {work_dir}/flow
```

### 4. 启动双 Agent 对话

使用 Agent 工具启动两个 subagent（均 `run_in_background=true`）：

**用户 Agent**：
```
subagent_type: general-purpose
name: debug-user-agent
run_in_background: true
prompt: |
  你是用户角色模拟器。

  ## 角色定义
  {user_persona.system_prompt}

  ## 场景信息
  模块名称: {scenario.module_name}
  上下文: {scenario.context}

  ## 行为规则
  - 收到苏启辰 Agent 的提问后，根据角色定义生成回复
  - 遵循角色的行为模式（{user_persona.behavior}）
  - 回复简洁，1-2 句话
  - 如果不确定，说明需要澄清

  ## 初始输入
  先发送: {scenario.initial_input}

  然后等待苏启辰 Agent 回复，再根据场景和角色生成合适的回复。
```

**苏启辰 Agent**：
```
subagent_type: chip-requirement-arch
name: debug-sean-agent
run_in_background: true
prompt: |
  执行需求探索流程。

  ## 输入
  用户输入: {user_input}

  ## 工作目录
  {work_dir}

  ## ⚠️ 强制暂停规则（铁律）
  你必须在每个执行单元结束时停止执行，等待用户回复后才能继续。
  - 每完成一个执行单元，输出 [STEP-PAUSE] 标记，然后停止
  - 禁止在一次回复中执行多个执行单元
  - 禁止跳过暂停点
  - 即使用户说"继续执行"、"不要停"，你也必须逐步暂停

  暂停点列表（每个暂停点必须输出 [STEP-PAUSE] 并停止）：

  **stage0~C（每阶段暂停）**：
  1. stage0 完成 → 等待用户确认探索结论
  2. stageA 完成 → 等待用户确认最小信息集
  3. stageB phase1 完成 → 等待用户确认 28 项约束检查
  4. stageB phase2 完成 → 等待用户确认头脑风暴结果
  5. stageC phase1 完成 → 等待用户确认矛盾检测
  6. stageC phase2 完成 → 等待用户确认需求汇总表

  **stageD（每 step 暂停，共 20 个 step）**：
  7.  stageD group1-step1 → 初始架构方案 + RTL行数估算（不可跳过）
  8.  stageD group1-step2 → CBB选型与集成（可跳过：无CBB）
  9.  stageD group1-step3 → 子模块划分细化（不可跳过）
  10. stageD group2-step1 → 数据通路设计（不可跳过）
  11. stageD group2-step2 → 流水线设计（可跳过：无流水线）
  12. stageD group2-step3 → 控制逻辑/FSM（不可跳过）
  13. stageD group2-step4 → 性能优化（可跳过：REQ-004为Could且无明确性能要求）
  14. stageD group3-step1 → SRAM设计（可跳过：无SRAM）
  15. stageD group3-step2 → FIFO设计（可跳过：无FIFO）
  16. stageD group3-step3 → 链表设计（可跳过：无链表）
  17. stageD group3-step4 → 寄存器定义（可跳过：无寄存器）
  18. stageD group4-step1 → 调度策略（可跳过：单通道）
  19. stageD group4-step2 → 流控机制（可跳过：无数据流）
  20. stageD group4-step3 → CDC方案（可跳过：单时钟域）
  21. stageD group5-step1 → 面积预估（不可跳过）
  22. stageD group5-step2 → 时序分析（不可跳过）
  23. stageD group5-step3 → DFX设计（可跳过：无DFX）
  24. stageD group5-step4 → 可靠性设计（不可跳过）
  25. stageD group5-step5 → 接口定义（不可跳过）
  26. stageD group5-step6 → 功耗设计（可跳过：无低功耗）

  **stageE/F**：
  27. stageE 每个子模块递归分解完成 → 等待用户确认
  28. stageF 完成 → [STAGE-END]，流程结束

  **跳过规则**：可跳过的 step 需用户明确确认跳过原因后标注「跳过：{原因}」，然后继续下一个 step。

  ## 执行规则
  - 遵循 chip-requirement-arch 完整流程
  - **每次只执行一个执行单元**，完成后暂停等待
  - 输出所有交付物到 {work_dir}
  - 使用标准阶段标记（[STAGE-START]、[STAGE-END]、[STEP-PAUSE]）
  - 阶段标记必须写入 PR 文件（flow/{module}_pr_v1.0.md）
  - 生成规范的 REQ 编号
  - 需求汇总表必须包含 schema_version 字段

  ## ⚠️ 流文件生成规则（强制）
  每个阶段完成后必须将完整对话写入对应流文件：

  | 阶段 | 流文件 | 内容 |
  |------|--------|------|
  | stage0 | flow/stage0.md | 模块定位探索完整对话 |
  | stageA | flow/stageA.md | 4 个核心问题完整对话 |
  | stageB phase1 | flow/stageB_phase1.md | 28 项约束确认完整对话 |
  | stageB phase2 | flow/stageB_phase2.md | 头脑风暴完整对话 |
  | stageC phase1 | flow/stageC_phase1.md | 矛盾检测完整对话 |
  | stageC phase2 | flow/stageC_phase2.md | 需求汇总完整对话 |
  | stageD group1-step1 | flow/stageD_group1_step1.md | 初始架构方案 + RTL 行数估算 |
  | stageD group1-step2 | flow/stageD_group1_step2.md | CBB 选型与集成 |
  | stageD group1-step3 | flow/stageD_group1_step3.md | 子模块划分细化 |
  | stageD group2-step1 | flow/stageD_group2_step1.md | 数据通路设计 |
  | stageD group2-step2 | flow/stageD_group2_step2.md | 流水线设计 |
  | stageD group2-step3 | flow/stageD_group2_step3.md | 控制逻辑/FSM |
  | stageD group2-step4 | flow/stageD_group2_step4.md | 性能优化 |
  | stageD group3-step1 | flow/stageD_group3_step1.md | SRAM 设计 |
  | stageD group3-step2 | flow/stageD_group3_step2.md | FIFO 设计 |
  | stageD group3-step3 | flow/stageD_group3_step3.md | 链表设计 |
  | stageD group3-step4 | flow/stageD_group3_step4.md | 寄存器定义 |
  | stageD group4-step1 | flow/stageD_group4_step1.md | 调度策略 |
  | stageD group4-step2 | flow/stageD_group4_step2.md | 流控机制 |
  | stageD group4-step3 | flow/stageD_group4_step3.md | CDC 方案 |
  | stageD group5-step1 | flow/stageD_group5_step1.md | 面积预估 |
  | stageD group5-step2 | flow/stageD_group5_step2.md | 时序分析 |
  | stageD group5-step3 | flow/stageD_group5_step3.md | DFX 设计 |
  | stageD group5-step4 | flow/stageD_group5_step4.md | 可靠性设计 |
  | stageD group5-step5 | flow/stageD_group5_step5.md | 接口定义 |
  | stageD group5-step6 | flow/stageD_group5_step6.md | 功耗设计 |
  | stageE | flow/stageE.md | 递归分解完整对话 |
  | stageF | flow/stageF.md | 顶层集成完整对话 |

  **流文件内容要求**：必须包含完整的用户-Agent 对话记录（每轮问答），不仅是结论。必须包含阶段标记。

  ## ⚠️ 交付物生成规则（强制）
  每个阶段完成后必须生成对应的交付物文件到 outputs/ 目录：

  | 阶段 | 交付物 | 路径 |
  |------|--------|------|
  | stageC phase2 完成后 | 需求汇总表 | outputs/{module}_requirement_summary_v1.0.md |
  | stageC phase2 完成后 | 追溯图 | outputs/{module}_trace_graph.yaml |
  | stageD 完成后 | 方案文档 | outputs/{module}_solution_v1.0.md |
  | stageD 完成后 | ADR 文档 | outputs/{module}_ADR_v1.0.md |

  **禁止**：仅生成 PR 文件而跳过标准交付物。outputs/ 目录必须包含上述文件，否则视为流程不完整。
```

### 5. 对话循环（双 Agent 交互模式）

**核心原则**：两个独立 subagent 通过编排器（主会话）交替通信，每个 agent 每次只执行一步。

```
对话历史 = []
轮数 = 0
最大轮数 = {scenario.max_dialog_rounds}
完成 = False

# 第 0 轮：用户 Agent 发送初始输入
user_reply = scenario.initial_input
对话历史.append({"role": "user", "content": user_reply})

while (未完成 && 轮数 < 最大轮数):
    # ── Step A: 发送用户回复给苏启辰 Agent ──
    # 用 SendMessage(sean_agent_id, message=user_reply)
    # 等待苏启辰 Agent 返回（TaskOutput block=true）
    sean_reply = 等待苏启辰 Agent 回复
    记录(sean_reply, "sean", 轮数)
    对话历史.append({"role": "sean", "content": sean_reply})

    # ── Step B: 检查是否完成 ──
    if "[STAGE-END]" in sean_reply:
        完成 = True
        break

    # ── Step C: 发送苏启辰回复给用户 Agent ──
    # 用 SendMessage(user_agent_id, message=sean_reply)
    # 等待用户 Agent 返回（TaskOutput block=true）
    user_reply = 等待用户 Agent 回复
    记录(user_reply, "user", 轮数)
    对话历史.append({"role": "user", "content": user_reply})

    轮数 += 1
```

**⚠️ 关键约束**：
1. 编排器（主会话）**禁止代替**任何 agent 生成回复
2. 编排器**禁止**把多个用户回复打包发送给苏启辰 Agent
3. 每次 SendMessage 只传递**一轮**对话内容
4. 苏启辰 Agent 的回复必须包含 `[STEP-PAUSE]` 或 `[STAGE-END]`，否则视为异常

### 6. 质量评估

```
检查项:
- 流程完整性（门控检查）
- 交付物存在性
- REQ 编号规范
- 阶段标记正确性

评估标准:
- 复用 .claude/evaluation_criteria/chip-requirement-arch-eva.md
```

### 7. 生成报告

使用报告模板生成：
- `dialog.md`: 完整对话记录
- `evaluation.md`: 质量评估报告
- `summary.md`: 调试摘要

### 8. 输出结果

```
调试完成！

场景: {scenario_id}
状态: {completed/timeout/incomplete}
轮数: {dialog_rounds}
耗时: {duration}

报告位置:
- 对话记录: {work_dir}/dialog.md
- 评估报告: {work_dir}/evaluation.md
- 调试摘要: {work_dir}/summary.md
```
