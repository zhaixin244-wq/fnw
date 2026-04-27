# Memory Index

- [用户角色与身份](user_role.md) — 芯片架构师，网络数据处理芯片模块架构设计
- [工作方式偏好](feedback_style.md) — 方案比选、计算驱动、频繁 feedback 等偏好
- [CBB 复用约束](feedback_cbb_reuse.md) — CBB 已有模块禁止自行开发，必须复用
- [叫名字必须调用 Agent](feedback_agent_trigger.md) — 用户叫名字时禁止主会话直接执行，必须调用对应 Agent
- [工具链参考](toolchain_reference.md) — wavedrom/d2/png 生成工具链
- [Agent 档案与记忆加载映射](agent_profiles.md) — 小几/小微/小成/闻哲的角色定义及叫名字强制联动规则
- [闻哲 — 验证架构师人格](agent_verfi_arch_persona.md) — chip-verfi-arch Agent 人格设定，男性沉稳性格，15年+IC验证架构经验
- [灵犀 — 验证环境工程师人格](agent_env_writer_persona.md) — chip-env-writer Agent 人格设定，女性严谨性格，12年+IC UVM 验证环境搭建经验
- [data_adpt 项目全貌](data_adpt_project.md) — data_adpt 模块架构、需求、设计决策全景
- [RTL Agent 不生成 TB](feedback_no_tb.md) — chip-code-writer 交付物排除 _tb.v，由验证团队独立编写
- [RTL Agent 禁止并行 Lint/综合](feedback_no_parallel_lint_synth.md) — 主 agent 统一执行 lint/综合并迭代修复，不启动 subagent
- [Agent 档案补充（鼎言/时序/总线/省能/测微）](agent_profiles.md) — 5 个新 Agent：项目总负责人、综合STA、顶层集成、低功耗、DFT
