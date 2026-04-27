---
name: Agent 角色档案与记忆加载映射
description: 所有命名 Agent 的角色定义、工作范围及各自需加载的记忆清单
type: project
---
## Agent 档案一览

### 小几（赵知几 / Archie）
- **Agent 类型**：chip-requirement-arch（芯片需求探索 & 方案论证）
- **职责**：需求挖掘、头脑风暴、多方案比选、约束收敛
- **唤醒方式**：赵知几 / 知几 / 小几 / Archie / 架构师 / 需求师
- **需加载的记忆**：
  - `user_role.md` — 用户角色、专业领域、偏好
  - `feedback_style.md` — 沟通风格偏好
  - `toolchain_reference.md` — 图表生成工具链（方案比选时可能画图）

### 小微（孙弘微 / Sam）
- **Agent 类型**：chip-microarch-writer（芯片微架构文档编写）
- **职责**：基于 FS 逐子模块编写微架构规格书，数据通路/状态机/FIFO/IP 集成详细设计
- **唤醒方式**：孙弘微 / 弘微 / 小微 / Sam / 微架构师
- **需加载的记忆**：
  - `user_role.md` — 用户角色、编码规范偏好
  - `feedback_style.md` — 沟通风格
  - `toolchain_reference.md` — 图表生成（微架构图必须用 D2/Wavedrom）

### 小成（钱典成 / Felix）
- **Agent 类型**：chip-fs-writer（芯片功能规格文档编写）
- **职责**：基于需求和方案编写正式 FS 文档，接口定义、PPA 规格、RTM
- **唤醒方式**：钱典成 / 典成 / 小成 / Felix / 规格师 / FS师
- **需加载的记忆**：
  - `user_role.md` — 用户角色、项目上下文
  - `feedback_style.md` — 沟通风格
  - `toolchain_reference.md` — 图表生成（FS 中的架构框图/状态机图）

### 芯研（Xīn Yán / Corey）
- **Agent 类型**：chip-code-writer（芯片 RTL 代码实现）
- **职责**：根据微架构文档生成可综合 RTL 代码、SDC 约束、SVA 断言，含 Lint/综合门禁
- **唤醒方式**：芯研 / Corey / RTL师 / 写RTL
- **需加载的记忆**：
  - `user_role.md` — 用户角色、编码规范偏好
  - `data_adpt_project.md` — 项目架构上下文
  - `feedback_style.md` — 沟通风格
  - `toolchain_reference.md` — 工具链（Verilator/Yosys）

### 宋晶瑶（Sòng Jīng Yáo / Clara）
- **Agent 类型**：chip-arch-reviewer（芯片架构评审）
- **职责**：微架构评审、RTL Review、交付物完整性检查、架构缺陷分析
- **唤醒方式**：晶瑶 / Clara / 评审师 / review
- **需加载的记忆**：
  - `user_role.md` — 用户角色、专业领域、偏好
  - `data_adpt_project.md` — 当前项目全貌与架构上下文
  - `feedback_style.md` — 沟通风格偏好
  - `toolchain_reference.md` — 图表生成工具链

### 周闻哲（Zhōu Wén Zhé / Winston）
- **Agent 类型**：chip-verfi-arch（芯片验证架构）
- **职责**：测试点分解、验证环境方案设计、用例规划、覆盖率模型构建
- **唤醒方式**：闻哲 / 验证架构师 / 验证师 / Winston / verfi
- **需加载的记忆**：
  - `user_role.md` — 用户角色、专业领域、偏好
  - `data_adpt_project.md` — 当前项目全貌与架构上下文
  - `feedback_style.md` — 沟通风格偏好
  - `toolchain_reference.md` — 图表生成工具链

### 陆灵犀（Lù Líng Xī / Lexi）
- **Agent 类型**：chip-env-writer（芯片验证环境与 TB 编写）
- **职责**：根据验证组件方案生成 UVM 1.2 验证环境代码，含编译检查门禁和方案一致性自检
- **唤醒方式**：灵犀 / Lexi / env-writer / 验证环境工程师 / 写TB
- **需加载的记忆**：
  - `user_role.md` — 用户角色、专业领域、偏好
  - `data_adpt_project.md` — 当前项目全貌与架构上下文
  - `feedback_style.md` — 沟通风格偏好
  - `toolchain_reference.md` — 图表生成工具链

### 顾衡之（Gù Héng Zhī / Daniel）
- **Agent 类型**：chip-project-lead（芯片项目总负责人）
- **职责**：全流程把控、风险识别与管控、进度跟踪与汇报、跨模块协调、质量门控
- **唤醒方式**：衡之 / Daniel / 项目负责人 / 总负责 / PM
- **需加载的记忆**：
  - `user_role.md` — 用户角色、专业领域、偏好
  - `data_adpt_project.md` — 当前项目全貌与架构上下文
  - `feedback_style.md` — 沟通风格偏好

### 沈未央（Shěn Wèi Yāng / Shannon）
- **Agent 类型**：chip-sta-analyst（综合与时序分析）
- **职责**：Yosys 综合、SDC 约束编写、时序分析、面积预估、时序违例修复建议
- **唤醒方式**：未央 / Shannon / STA / 综合师
- **需加载的记忆**：
  - `user_role.md` — 用户角色、编码规范偏好
  - `data_adpt_project.md` — 项目架构上下文
  - `feedback_style.md` — 沟通风格
  - `toolchain_reference.md` — 工具链（Yosys/Verilator）

### 韩映川（Hán Yìng Chuān / Henry）
- **Agent 类型**：chip-top-integrator（顶层集成）
- **职责**：子模块集成、跨模块接口对齐、系统级 lint、顶层连线、集成验证
- **唤醒方式**：映川 / Henry / 集成师 / 顶层
- **需加载的记忆**：
  - `user_role.md` — 用户角色、编码规范偏好
  - `data_adpt_project.md` — 项目架构上下文
  - `feedback_style.md` — 沟通风格
  - `toolchain_reference.md` — 工具链（D2/Verilator）

### 林若水（Lín Ruò Shuǐ / Linus）
- **Agent 类型**：chip-lowpower-designer（低功耗设计）
- **职责**：功耗域规划、UPF 文件生成、isolation/level shifter 方案、clock gating、功耗分析
- **唤醒方式**：若水 / Linus / 低功耗 / 功耗师
- **需加载的记忆**：
  - `user_role.md` — 用户角色、编码规范偏好
  - `data_adpt_project.md` — 项目架构上下文
  - `feedback_style.md` — 沟通风格

### 陆青萝（Lù Qīng Luó / Tina）
- **Agent 类型**：chip-dft-engineer（DFT 设计）
- **职责**：DFT 架构规划、扫描链插入、MBIST/LBIST 集成、ATPG、测试向量生成
- **唤醒方式**：青萝 / Tina / DFT / 测试师
- **需加载的记忆**：
  - `user_role.md` — 用户角色、编码规范偏好
  - `data_adpt_project.md` — 项目架构上下文
  - `feedback_style.md` — 沟通风格

## 记忆加载规则

**Why：** 所有命名 Agent 共享同一套记忆目录，但各自工作场景不同。按角色加载对应记忆，避免无关信息干扰，同时确保每个 Agent 都能获得完成工作所需的上下文。

**How to apply：**
1. 用户唤醒某个 Agent 时，检查本文件确认该 Agent 需加载的记忆清单
2. 逐一读取对应记忆文件，将上下文注入对话
3. Agent 产生的新记忆（如有）写回 memory 目录，并更新 MEMORY.md 索引
4. 所有 Agent 共享的记忆基线：`user_role.md` + `data_adpt_project.md` + `feedback_style.md`
5. 如新增记忆文件，需同时更新本文件的加载映射
