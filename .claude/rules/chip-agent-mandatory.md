# 芯片任务必须使用专用 Agent

> 以下规则为强制约束，任何芯片相关任务必须通过对应专用 Agent 完成，禁止手动生成。

---

## Agent 调用映射表

| 任务类型 | 必须调用的 Agent | 触发关键词 | 禁止行为 |
|----------|-----------------|-----------|---------|
| RTL 代码生成/完善/重构 | `chip-code-writer` | 生成rtl、写rtl、完善rtl、实现rtl、补全代码 | 手动编写 Verilog/SystemVerilog 可综合代码 |
| FS 功能规格书编写 | `chip-fs-writer` | 编写FS、写功能规格、生成功能规格书 | 手动编写 FS 文档 |
| UA 微架构文档编写 | `chip-microarch-writer` | 编写UA、写微架构、生成微架构文档 | 手动编写 UA 文档 |
| 架构评审/检查 | `chip-arch-reviewer` | 评审、review、检查架构、检查rtl | 手动评审代码或文档 |
| 需求探索/方案论证 | `chip-requirement-arch` | 需求讨论、方案比选、架构探索、头脑风暴 | 手动做需求分析或方案对比 |
| 验证架构/测试点分解/用例规划 | `chip-verfi-arch` | 测试点、验证计划、用例规划、覆盖率、验证环境方案 | 手动编写验证计划或测试点分解 |
| 验证环境/TB 代码生成/完善 | `chip-env-writer` | 生成TB、写验证环境、生成UVM、编写driver、编写monitor、编写scoreboard、完善验证环境 | 手动编写 UVM 验证环境代码（Agent/Driver/Monitor/Scoreboard/Coverage/Env/Test/TB Top） |
| 综合/时序分析/SDC 约束 | `chip-sta-analyst` | 综合、时序分析、SDC约束、lint检查、面积预估、时序违例 | 手动编写 SDC 约束或手动运行综合/时序分析 |
| 顶层集成/接口对齐 | `chip-top-integrator` | 顶层集成、接口对齐、系统lint、连线检查 | 手动编写顶层模块或手动进行接口对齐 |
| 低功耗设计/UPF | `chip-lowpower-designer` | 低功耗、UPF、功耗域、clock gating、power gating、isolation | 手动编写 UPF 文件或手动进行功耗分析 |
| DFT 设计/扫描链/MBIST | `chip-dft-engineer` | DFT、扫描链、MBIST、LBIST、ATPG、测试向量 | 手动编写 DFT 方案或手动进行测试插入 |
| 项目管理/风险管控/汇报 | `chip-project-lead` | 项目管理、风险评估、进度跟踪、汇报、协调、门控检查 | 手动编写项目计划或风险报告（由项目总负责人统筹） |

---

## 调用规范

1. **上下文传递**：调用 Agent 时必须传入完整的参考文档路径（FS/UA/编码规范）和目标输出路径
2. **逐模块处理**：多模块任务按子模块逐个调用，每个模块独立生成完整文件后再处理下一个
3. **结果验证**：Agent 生成完成后，主会话应读取输出文件确认完整性，而非盲信 Agent 报告
4. **禁止绕过**：即使任务看似简单（如"只改一行"），只要涉及芯片 RTL/FS/UA 内容，仍必须调用对应 Agent

---

## 例外情况

以下场景允许主会话直接处理，无需调用专用 Agent：
- 仅读取/搜索现有代码（用 Read/Grep/Glob 工具）
- 仅回答关于代码的解释性问题
- 任务明确要求"手动修改"且修改量极小（<5行）
- 非芯片任务（如项目管理、git 操作、文档格式调整）
