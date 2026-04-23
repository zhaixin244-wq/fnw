# Skills 目录完整介绍

> 共 230 个 Skill，按功能领域分类。每个 Skill 位于 `.claude/skills/{skill-name}/SKILL.md`。
>
> 生成日期：2026-04-15

---

## 目录

- [芯片设计专用 (Chip Design)](#芯片设计专用-chip-design)
- [通用工程工作流 (Engineering Workflow)](#通用工程工作流-engineering-workflow)
- [Agent 系统 (Agent System)](#agent-system-agent-system)
- [知识与记忆 (Knowledge & Memory)](#知识与记忆-knowledge--memory)
- [代码质量与测试 (Code Quality & Testing)](#代码质量与测试-code-quality--testing)
- [编程语言与框架 (Languages & Frameworks)](#编程语言与框架-languages--frameworks)
- [前端与 UI (Frontend & UI)](#前端与-ui-frontend--ui)
- [DevOps 与基础设施 (DevOps & Infra)](#devops-与基础设施-devops--infra)
- [安全 (Security)](#安全-security)
- [API 与集成 (API & Integration)](#api-与集成-api--integration)
- [内容与写作 (Content & Writing)](#内容与写作-content--writing)
- [商业与运营 (Business & Ops)](#商业与运营-business--ops)
- [Obsidian 集成 (Obsidian)](#obsidian-集成-obsidian)
- [ECC 工具链 (ECC Tools)](#ecc-工具链-ecc-tools)
- [其他 (Miscellaneous)](#其他-miscellaneous)

---

## 芯片设计专用 (Chip Design)

14 个专用 Skill，覆盖芯片架构设计全流程。

| Skill | 说明 |
|-------|------|
| [chip-budget-allocator](skills/chip-budget-allocator/SKILL.md) | 将芯片系统级 PPA 指标（延迟、吞吐、功耗、面积）按层级拆解到子模块。含闭合检查（总和 ≤ 系统目标，建议 85-100%） |
| [chip-cdc-architect](skills/chip-cdc-architect/SKILL.md) | 定义时钟域划分、CDC 信号识别与同步策略。支持单 bit（2-flop）、多 bit（异步 FIFO/Gray 码）、脉冲、复位信号 |
| [chip-design-space-explorer](skills/chip-design-space-explorer/SKILL.md) | 在面积/性能/功耗三维设计空间中寻找帕累托最优解。输出 DSE 报告 + 推荐设计点 |
| [chip-diagram-generator](skills/chip-diagram-generator/SKILL.md) | 生成 Mermaid 框图、Wavedrom 时序图、状态机图。支持模块框图、数据通路、NoC 拓扑 |
| [chip-doc-structurer](skills/chip-doc-structurer/SKILL.md) | 设计芯片微架构规格书的章节结构、内容权重与模板继承 |
| [chip-interface-contractor](skills/chip-interface-contractor/SKILL.md) | 精确定义接口契约：端口列表、时序参数、协议行为、SVA 断言模板 |
| [chip-low-power-architect](skills/chip-low-power-architect/SKILL.md) | 定义功耗管理架构：Power Domain 划分、Isolation、Retention、低功耗状态机（PSM）、UPF 意图 |
| [chip-ppa-formatter](skills/chip-ppa-formatter/SKILL.md) | 结构化输出 PPA 规格表，含 Target/Budget/Estimated 三级分类与 PVT corner 标注 |
| [chip-protocol-compliance-checker](skills/chip-protocol-compliance-checker/SKILL.md) | 深度检查 AXI/ACE/CHI/TileLink/APB/AHB 协议合规性。逐条核对握手规则、事务排序、突发传输 |
| [chip-reliability-architect](skills/chip-reliability-architect/SKILL.md) | 评估可靠性风险：SEU（ECC/TMR）、老化（BTI/HCI）、IR Drop、EM、热热点、ESD/Latch-up |
| [chip-review-checklister](skills/chip-review-checklister/SKILL.md) | 9 维度评审清单 + Schema 级完整性校验。覆盖架构/接口/PPA/时序/CDC/低功耗/可靠性/验证/RTL |
| [chip-rtl-guideline-generator](skills/chip-rtl-guideline-generator/SKILL.md) | 生成 RTL 编码规范：Clock/Reset 策略、可综合性、编码风格、DFT 友好性、SVA 断言 |
| [chip-traceability-linker](skills/chip-traceability-linker/SKILL.md) | 建立需求追溯矩阵（RTM）：需求 → 架构决策 → 接口 → PPA → 验证策略。含覆盖率统计 |
| [chip-version-diff-generator](skills/chip-version-diff-generator/SKILL.md) | 对比架构文档版本差异（v1.0 → v1.1），生成变更影响分析（RTL/验证/后端/软件） |

---

## 通用工程工作流 (Engineering Workflow)

核心开发流程 Skill，涵盖计划、执行、调试、评审。

| Skill | 说明 |
|-------|------|
| [brainstorming](skills/brainstorming/SKILL.md) | 头脑风暴：9 步硬门控流程（探索→提问→方案→设计→spec）。未获批准前禁止实现 |
| [writing-plans](skills/writing-plans/SKILL.md) | 编写实现计划：无占位符、精确文件路径、完整代码、TDD。保存到 `docs/superpowers/plans/` |
| [executing-plans](skills/executing-plans/SKILL.md) | 在独立会话中执行实现计划，含 review 检查点 |
| [make-plan](skills/make-plan/SKILL.md) | 创建分阶段实现计划，含文档发现 |
| [do](skills/do/SKILL.md) | 使用子 Agent 执行分阶段实现计划 |
| [subagent-driven-development](skills/subagent-driven-development/SKILL.md) | 每任务一个新子 Agent + 两阶段 review（spec 合规 → 代码质量）。同会话执行 |
| [dispatching-parallel-agents](skills/dispatching-parallel-agents/SKILL.md) | 并行调度独立域的 Agent。每个 Agent 获得精确的独立上下文 |
| [systematic-debugging](skills/systematic-debugging/SKILL.md) | 四阶段调试：根因调查 → 模式分析 → 假设测试 → 实现。铁律：无根因不准修复 |
| [verification-before-completion](skills/verification-before-completion/SKILL.md) | "证据先于声明"铁律：完成声明前必须运行验证命令并确认输出 |
| [verification-loop](skills/verification-loop/SKILL.md) | 综合验证系统，覆盖 Claude Code 会话 |
| [finishing-a-development-branch](skills/finishing-a-development-branch/SKILL.md) | 实现完成后决定如何集成：merge、PR 或清理 |
| [receiving-code-review](skills/receiving-code-review/SKILL.md) | 接收代码审查反馈，技术严谨性优先于表演性同意 |
| [requesting-code-review](skills/requesting-code-review/SKILL.md) | 完成任务或合并前请求代码审查 |
| [test-driven-development](skills/test-driven-development/SKILL.md) | TDD：实现功能或 bugfix 前先写测试 |
| [tdd-workflow](skills/tdd-workflow/TDD-workflow.md) | TDD 工作流：80%+ 覆盖率，含单元/集成/E2E 测试 |
| [architecture-decision-records](skills/architecture-decision-records/SKILL.md) | 结构化 ADR：自动检测决策时刻，记录上下文、备选方案、理由。Nygard 格式 |
| [using-git-worktrees](skills/using-git-worktrees/SKILL.md) | 创建隔离 git worktree，用于功能开发或计划执行 |
| [smart-explore](skills/smart-explore/SKILL.md) | AST 结构化代码搜索（tree-sitter），4-8x token 节省。替代 Glob→Grep→Read |
| [writing-skills](skills/writing-skills/SKILL.md) | 创建/编辑/验证 Skill 文件 |
| [rules-distill](skills/rules-distill/SKILL.md) | 从 Skill 中提取跨领域原则并提炼为规则文件 |
| [strategic-compact](skills/strategic-compact/SKILL.md) | 在逻辑间隔处建议手动上下文压缩，避免任意自动压缩 |
| [search-first](skills/search-first/SKILL.md) | 编码前搜索：先找现有工具/库/模式，再写自定义代码 |
| [using-superpowers](skills/using-superpowers/SKILL.md) | 会话启动指南：如何发现和使用 Skill，要求先调用 Skill 工具再回答 |

---

## Agent 系统 (Agent System)

Agent 构建、评估、调试、编排。

| Skill | 说明 |
|-------|------|
| [agent-eval](skills/agent-eval/SKILL.md) | 编码 Agent 头对头对比：Claude Code vs Aider vs Codex，含通过率/成本/时间/一致性指标 |
| [agent-harness-construction](skills/agent-harness-construction/SKILL.md) | 设计 Agent 动作空间、工具定义、观测格式，提高完成率 |
| [agent-introspection-debugging](skills/agent-introspection-debugging/SKILL.md) | Agent 失败的结构化自调试：捕获→诊断→恢复→报告 |
| [agent-payment-x402](skills/agent-payment-x402/SKILL.md) | 为 Agent 添加 x402 支付执行：任务级预算、支出控制、非托管钱包 |
| [agent-sort](skills/agent-sort/SKILL.md) | 为特定仓库生成 ECC 安装计划，将 Skill/规则/hooks 分类为 DAILY vs LIBRARY |
| [autonomous-agent-harness](skills/autonomous-agent-harness/SKILL.md) | 将 Claude Code 转为全自主 Agent 系统：持久记忆、定时操作、计算机使用、任务队列 |
| [autonomous-loops](skills/autonomous-loops/SKILL.md) | 自主 Agent 循环模式：从简单顺序管道到 RFC 驱动的多 Agent DAG 系统 |
| [claude-devfleet](skills/claude-devfleet/SKILL.md) | 通过 Claude DevFleet 编排多 Agent 编码任务：计划→并行调度→监控→报告 |
| [continuous-agent-loop](skills/continuous-agent-loop/SKILL.md) | 持续自主 Agent 循环模式，含质量门、评估和恢复控制 |
| [dmux-workflows](skills/dmux-workflows/SKILL.md) | 使用 dmux（tmux 面板管理器）的多 Agent 编排：并行 Agent 工作流 |
| [gan-style-harness](skills/gan-style-harness/SKILL.md) | GAN 风格的 Generator-Evaluator Agent 框架，自主构建高质量应用 |
| [iterative-retrieval](skills/iterative-retrieval/SKILL.md) | 渐进式上下文检索模式，解决子 Agent 上下文问题 |
| [ralphinho-rfc-pipeline](skills/ralphinho-rfc-pipeline/SKILL.md) | RFC 驱动的多 Agent DAG 执行：质量门、合并队列、工作单元编排 |
| [santa-method](skills/santa-method/SKILL.md) | 多 Agent 对抗验证 + 收敛循环：两个独立审查 Agent 都通过才交付 |
| [team-builder](skills/team-builder/SKILL.md) | 交互式 Agent 选择器：组合和调度并行团队 |
| [agentic-engineering](skills/agentic-engineering/SKILL.md) | 作为 Agent 工程师操作：评估优先执行、分解、成本感知模型路由 |
| [ai-first-engineering](skills/ai-first-engineering/SKILL.md) | AI Agent 生成大量实现输出的团队工程操作模型 |
| [eval-harness](skills/eval-harness/SKILL.md) | Claude Code 会话的正式评估框架，实现评估驱动开发（EDD） |

---

## 知识与记忆 (Knowledge & Memory)

跨会话记忆、知识库、RAG。

| Skill | 说明 |
|-------|------|
| [mem-search](skills/mem-search/SKILL.md) | 搜索 claude-mem 的持久跨会话记忆数据库 |
| [knowledge-agent](skills/knowledge-agent/SKILL.md) | 从 claude-mem 观察构建和查询 AI 知识库 |
| [knowledge-ops](skills/knowledge-ops/SKILL.md) | 知识库管理：多存储层（本地/MCP/向量/Git）的保存/组织/同步/去重/搜索 |
| [ck](skills/ck/SKILL.md) | 每项目持久记忆：会话启动时自动加载项目上下文 |
| [rag-query](skills/rag-query/SKILL.md) | 查询个人 LightRAG 知识图谱（跨会话持久记忆） |
| [rag-remember](skills/rag-remember/SKILL.md) | 立即存储事实/决策/观察到个人 LightRAG 知识图谱 |
| [rag-sync](skills/rag-sync/SKILL.md) | 会话结束时审查并同步学习内容到个人 LightRAG |
| [rag-project-query](skills/rag-project-query/SKILL.md) | 查询项目级 LightRAG 知识图谱 |
| [rag-project-remember](skills/rag-project-remember/SKILL.md) | 存储项目特定知识到项目级 LightRAG |
| [rag-project-sync](skills/rag-project-sync/SKILL.md) | 会话结束时同步项目学习内容到项目级 LightRAG |
| [rag-setup-project](skills/rag-setup-project/SKILL.md) | 为 Cursor 项目设置 LightRAG 持久记忆 + MCP 配置 |
| [timeline-report](skills/timeline-report/SKILL.md) | 从 claude-mem 时间线生成项目开发历程叙事报告 |
| [continuous-learning](skills/continuous-learning/SKILL.md) | 自动从 Claude Code 会话提取可复用模式并保存为已学 Skill |
| [continuous-learning-v2](skills/continuous-learning-v2/SKILL.md) | 基于直觉的学习系统：观察会话→创建原子直觉→演化为 Skill。v2.1 支持项目级隔离 |

---

## 代码质量与测试 (Code Quality & Testing)

测试模式、代码审查、质量保证。

| Skill | 说明 |
|-------|------|
| [ai-regression-testing](skills/ai-regression-testing/SKILL.md) | AI 辅助开发的回归测试策略：沙盒 API 测试、自动 bug 检查、AI 盲点捕获 |
| [benchmark](skills/benchmark/SKILL.md) | 测量性能基线、检测回归、对比技术栈替代方案 |
| [browser-qa](skills/browser-qa/SKILL.md) | 使用浏览器自动化进行视觉测试和 UI 交互验证 |
| [canary-watch](skills/canary-watch/SKILL.md) | 监控部署 URL 的回归：部署/合并/依赖升级后检测 |
| [coding-standards](skills/coding-standards/SKILL.md) | 跨项目编码约定基线：命名、可读性、不变性 |
| [cpp-coding-standards](skills/cpp-coding-standards/SKILL.md) | 基于 C++ Core Guidelines 的编码标准 |
| [cpp-testing](skills/cpp-testing/SKILL.md) | C++ 测试：GoogleTest/CTest、诊断失败/flaky 测试、覆盖率/sanitizer |
| [csharp-testing](skills/csharp-testing/SKILL.md) | C#/.NET 测试：xUnit、FluentAssertions、mocking、集成测试 |
| [database-migrations](skills/database-migrations/SKILL.md) | 数据库迁移最佳实践：schema 变更、数据迁移、回滚、零停机部署 |
| [e2e-testing](skills/e2e-testing/SKILL.md) | Playwright E2E 测试：Page Object Model、CI/CD 集成、flaky 测试策略 |
| [golang-testing](skills/golang-testing/SKILL.md) | Go 测试：表驱动测试、子测试、基准、模糊测试、覆盖率 |
| [java-coding-standards](skills/java-coding-standards/SKILL.md) | Java 编码标准：命名、不可变性、Optional、Streams、异常、泛型 |
| [kotlin-testing](skills/kotlin-testing/SKILL.md) | Kotlin 测试：Kotest、MockK、协程测试、属性测试、Kover 覆盖率 |
| [laravel-tdd](skills/laravel-tdd/SKILL.md) | Laravel TDD：PHPUnit/Pest、factory、数据库测试、fakes |
| [laravel-verification](skills/laravel-verification/SKILL.md) | Laravel 验证循环：环境检查、lint、静态分析、测试、安全扫描 |
| [perl-testing](skills/perl-testing/SKILL.md) | Perl 测试：Test2::V0、Test::More、prove、mocking、Devel::Cover |
| [plankton-code-quality](skills/plankton-code-quality/SKILL.md) | Plankton 写时代码质量强制：自动格式化、lint、Claude 驱动修复 |
| [python-testing](skills/python-testing/SKILL.md) | Python 测试：pytest、TDD、fixtures、mocking、参数化、覆盖率 |
| [repo-scan](skills/repo-scan/SKILL.md) | 跨栈源代码资产审计：分类文件、检测嵌入式第三方库、四级裁决 |
| [rust-testing](skills/rust-testing/SKILL.md) | Rust 测试：单元/集成/异步/属性测试、mocking、覆盖率 |
| [springboot-tdd](skills/springboot-tdd/SKILL.md) | Spring Boot TDD：JUnit 5、Mockito、MockMvc、Testcontainers、JaCoCo |
| [springboot-verification](skills/springboot-verification/SKILL.md) | Spring Boot 验证循环：构建、静态分析、测试、安全扫描、diff 审查 |
| [django-tdd](skills/django-tdd/SKILL.md) | Django 测试：pytest-django、factory_boy、mocking、DRF 测试 |
| [django-verification](skills/django-verification/SKILL.md) | Django 验证循环：迁移、lint、测试、安全扫描、部署就绪 |
| [golang-patterns](skills/golang-patterns/SKILL.md) | Go 惯用模式、最佳实践和约定 |
| [security-review](skills/security-review/SKILL.md) | 添加认证/处理用户输入/处理密钥/API 端点时的安全检查清单 |
| [security-scan](skills/security-scan/SKILL.md) | 扫描 Claude Code 配置（.claude/）的安全漏洞和注入风险 |
| [gateguard](skills/gateguard/SKILL.md) | 事实强制门：阻止 Edit/Write/Bash，要求具体调查后才允许操作 |

---

## 编程语言与框架 (Languages & Frameworks)

各语言/框架的架构模式和最佳实践。

| Skill | 说明 |
|-------|------|
| [android-clean-architecture](skills/android-clean-architecture/SKILL.md) | Android/KMP Clean Architecture：模块结构、依赖规则、UseCases、Repositories |
| [backend-patterns](skills/backend-patterns/SKILL.md) | 后端架构模式：API 设计、数据库优化、Node.js/Express/Next.js |
| [bun-runtime](skills/bun-runtime/SKILL.md) | Bun 运行时：包管理器、打包器、测试运行器。Bun vs Node 选择指南 |
| [compose-multiplatform-patterns](skills/compose-multiplatform-patterns/SKILL.md) | Compose Multiplatform / Jetpack Compose：状态管理、导航、主题、性能 |
| [dart-flutter-patterns](skills/dart-flutter-patterns/SKILL.md) | Dart/Flutter 生产模式：null 安全、状态管理（BLoC/Riverpod/Provider）、GoRouter、Freezed |
| [django-patterns](skills/django-patterns/SKILL.md) | Django 架构模式：DRF REST API、ORM、缓存、信号、中间件 |
| [django-security](skills/django-security/SKILL.md) | Django 安全：认证、授权、CSRF、SQL 注入、XSS 防护 |
| [dotnet-patterns](skills/dotnet-patterns/SKILL.md) | C#/.NET 惯用模式：DI、async/await、最佳实践 |
| [flutter-dart-code-review](skills/flutter-dart-code-review/SKILL.md) | Flutter/Dart 代码审查清单：Widget、状态管理、性能、安全 |
| [frontend-patterns](skills/frontend-patterns/SKILL.md) | 前端模式：React、Next.js、状态管理、性能优化、UI 最佳实践 |
| [hexagonal-architecture](skills/hexagonal-architecture/SKILL.md) | 六边形架构（Ports & Adapters）：TS/Java/Kotlin/Go 实现 |
| [jpa-patterns](skills/jpa-patterns/SKILL.md) | JPA/Hibernate：实体设计、关系、查询优化、事务、审计、分页 |
| [kotlin-coroutines-flows](skills/kotlin-coroutines-flows/SKILL.md) | Kotlin 协程和 Flow：结构化并发、Flow 操作符、StateFlow、错误处理 |
| [kotlin-exposed-patterns](skills/kotlin-exposed-patterns/SKILL.md) | JetBrains Exposed ORM：DSL 查询、DAO、事务、HikariCP、Flyway |
| [kotlin-ktor-patterns](skills/kotlin-ktor-patterns/SKILL.md) | Ktor 服务器：路由 DSL、插件、认证、Koin DI、WebSocket |
| [kotlin-patterns](skills/kotlin-patterns/SKILL.md) | Kotlin 惯用模式：协程、null 安全、DSL 构建器 |
| [laravel-patterns](skills/laravel-patterns/SKILL.md) | Laravel 架构：路由/控制器、Eloquent ORM、服务层、队列、事件 |
| [laravel-plugin-discovery](skills/laravel-plugin-discovery/SKILL.md) | 通过 LaraPlugins.io MCP 发现和评估 Laravel 包 |
| [laravel-security](skills/laravel-security/SKILL.md) | Laravel 安全：认证/授权、CSRF、批量赋值、文件上传、密钥 |
| [nestjs-patterns](skills/nestjs-patterns/SKILL.md) | NestJS 架构：模块、控制器、提供者、DTO 验证、守卫、拦截器 |
| [nextjs-turbopack](skills/nextjs-turbopack/SKILL.md) | Next.js 16+ 和 Turbopack：增量打包、FS 缓存、开发速度 |
| [nuxt4-patterns](skills/nuxt4-patterns/SKILL.md) | Nuxt 4：水合安全、性能、路由规则、懒加载、SSR 安全数据获取 |
| [perl-patterns](skills/perl-patterns/SKILL.md) | Perl 5.36+ 现代惯用模式和最佳实践 |
| [python-patterns](skills/python-patterns/SKILL.md) | Python 惯用模式：PEP 8、类型提示、最佳实践 |
| [pytorch-patterns](skills/pytorch-patterns/SKILL.md) | PyTorch 深度学习：训练管道、模型架构、数据加载最佳实践 |
| [rust-patterns](skills/rust-patterns/SKILL.md) | Rust 惯用模式：所有权、错误处理、trait、并发 |
| [springboot-patterns](skills/springboot-patterns/SKILL.md) | Spring Boot 架构：REST API、分层服务、数据访问、缓存、异步 |
| [springboot-security](skills/springboot-security/SKILL.md) | Spring Security：认证/授权、CSRF、密钥、头部、速率限制 |
| [swift-actor-persistence](skills/swift-actor-persistence/SKILL.md) | Swift actor 线程安全数据持久化：内存缓存 + 文件存储 |
| [swift-concurrency-6-2](skills/swift-concurrency-6-2/SKILL.md) | Swift 6.2 可接近并发：默认单线程、@concurrent 显式后台 |
| [swift-protocol-di-testing](skills/swift-protocol-di-testing/SKILL.md) | Swift 协议依赖注入：Mock 文件系统/网络/API |
| [swiftui-patterns](skills/swiftui-patterns/SKILL.md) | SwiftUI 架构：@Observable 状态管理、视图组合、导航、性能 |
| [foundation-models-on-device](skills/foundation-models-on-device/SKILL.md) | Apple FoundationModels 框架：设备端 LLM、@Generable 引导生成 |
| [liquid-glass-design](skills/liquid-glass-design/SKILL.md) | iOS 26 Liquid Glass 设计系统：SwiftUI/UIKit/WidgetKit 动态玻璃材质 |

---

## 前端与 UI (Frontend & UI)

前端设计、动画、演示。

| Skill | 说明 |
|-------|------|
| [accessibility](skills/accessibility/SKILL.md) | WCAG 2.2 Level AA 无障碍设计、实现和审计 |
| [frontend-design](skills/frontend-design/SKILL.md) | 创建独特、生产级前端界面：视觉设计与代码质量并重 |
| [frontend-slides](skills/frontend-slides/SKILL.md) | 从零或从 PPT 创建动画丰富的 HTML 演示文稿 |
| [design-system](skills/design-system/SKILL.md) | 生成或审计设计系统，检查视觉一致性 |
| [ui-demo](skills/ui-demo/SKILL.md) | 使用 Playwright 录制 UI 演示视频：WebM、可见光标、自然节奏 |
| [manim-video](skills/manim-video/SKILL.md) | Manim 技术概念动画：图表、系统图、产品演示 |
| [remotion-video-creation](skills/remotion-video-creation/SKILL.md) | Remotion 视频创建：3D、动画、音频、字幕、图表、转场 |
| [video-editing](skills/video-editing/SKILL.md) | AI 辅助视频编辑：FFmpeg、Remotion、ElevenLabs、fal.ai |
| [videodb](skills/videodb/SKILL.md) | 视频/音频 See-Understand-Act：摄取、索引、搜索、转码、编辑、生成 |

---

## DevOps 与基础设施 (DevOps & Infra)

部署、CI/CD、容器化、监控。

| Skill | 说明 |
|-------|------|
| [deployment-patterns](skills/deployment-patterns/SKILL.md) | 部署工作流：CI/CD 管道、Docker、健康检查、回滚策略 |
| [docker-patterns](skills/docker-patterns/SKILL.md) | Docker/Compose 模式：本地开发、容器安全、网络、卷策略 |
| [git-workflow](skills/git-workflow/SKILL.md) | Git 工作流模式：分支策略、提交约定、merge vs rebase、冲突解决 |
| [github-ops](skills/github-ops/SKILL.md) | GitHub 操作：Issue 分诊、PR 管理、CI/CD、发布管理、安全监控 |
| [jira-integration](skills/jira-integration/SKILL.md) | Jira 集成：检索票据、分析需求、更新状态、转换 Issue |
| [dashboard-builder](skills/dashboard-builder/SKILL.md) | 构建监控仪表板（Grafana/SigNoz），回答真正的运维问题 |
| [mcp-server-patterns](skills/mcp-server-patterns/SKILL.md) | 构建 MCP 服务器：Node/TS SDK、工具/资源/提示、Zod 验证 |
| [configure-ecc](skills/configure-ecc/SKILL.md) | ECC 交互式安装器：选择和安装 Skill/规则，验证路径 |
| [workspace-surface-audit](skills/workspace-surface-audit/SKILL.md) | 审计仓库、MCP 服务器、插件、连接器，推荐高价值 Skill |
| [hookify-rules](skills/hookify-rules/SKILL.md) | Hookify 规则创建指南：语法、模式和配置 |
| [version-bump](skills/version-bump/SKILL.md) | 自动语义版本化和发布工作流：版本递增、构建验证、git 标签、GitHub 发布 |
| [code-tour](skills/code-tour/SKILL.md) | 创建 CodeTour .tour 文件：面向角色的分步演练 |
| [codebase-onboarding](skills/codebase-onboarding/SKILL.md) | 分析陌生代码库，生成结构化入门指南和 CLAUDE.md |
| [context-budget](skills/context-budget/SKILL.md) | 审计 Claude Code 上下文窗口消耗，识别膨胀和冗余 |
| [token-budget-advisor](skills/token-budget-advisor/SKILL.md) | Token 预算建议 |

---

## 安全 (Security)

应用安全、审计、合规。

| Skill | 说明 |
|-------|------|
| [security-review](skills/security-review/SKILL.md) | 安全审查：认证、用户输入、密钥、API 端点、支付功能的检查清单 |
| [security-scan](skills/security-scan/SKILL.md) | 扫描 Claude Code 配置的安全漏洞、误配置和注入风险 |
| [security-bounty-hunter](skills/security-bounty-hunter/SKILL.md) | 猎取可利用的安全漏洞：聚焦远程可达的可报告问题 |
| [safety-guard](skills/safety-guard/SKILL.md) | 防止在生产系统或自主 Agent 运行时的破坏性操作 |
| [defi-amm-security](skills/defi-amm-security/SKILL.md) | Solidity AMM 合约安全检查：重入、CEI、捐赠攻击、Oracle 操纵 |
| [hipaa-compliance](skills/hipaa-compliance/SKILL.md) | HIPAA 合规：PHI 处理、覆盖实体、BAA、泄露态势 |
| [healthcare-phi-compliance](skills/healthcare-phi-compliance/SKILL.md) | PHI/PII 合规：数据分类、访问控制、审计跟踪、加密 |
| [llm-trading-agent-security](skills/llm-trading-agent-security/SKILL.md) | 自主交易 Agent 安全：提示注入、支出限制、预发送模拟、断路器 |
| [perl-security](skills/perl-security/SKILL.md) | Perl 安全：污染模式、输入验证、安全进程执行、DBI 参数化查询 |
| [nodejs-keccak256](skills/nodejs-keccak256/SKILL.md) | 防止以太坊哈希 bug：Node sha3-256 ≠ Ethereum Keccak-256 |
| [evm-token-decimals](skills/evm-token-decimals/SKILL.md) | 防止 EVM 链间静默小数位不匹配 bug |

---

## API 与集成 (API & Integration)

API 设计、连接器、外部服务集成。

| Skill | 说明 |
|-------|------|
| [api-design](skills/api-design/SKILL.md) | REST API 设计：资源命名、状态码、分页、过滤、错误响应、版本控制 |
| [api-connector-builder](skills/api-connector-builder/SKILL.md) | 构建 API 连接器：匹配目标仓库的现有集成模式 |
| [claude-api](skills/claude-api/SKILL.md) | Anthropic Claude API：Messages API、流式、工具使用、vision、扩展思考、批处理、提示缓存 |
| [clickhouse-io](skills/clickhouse-io/SKILL.md) | ClickHouse 数据库模式：查询优化、分析、数据工程 |
| [exa-search](skills/exa-search/SKILL.md) | Exa MCP 神经搜索：网页、代码、公司研究、人员查找 |
| [deep-research](skills/deep-research/SKILL.md) | 多源深度研究：firecrawl + exa MCP，含引用和来源归属 |
| [documentation-lookup](skills/documentation-lookup/SKILL.md) | 通过 Context7 MCP 使用最新库/框架文档 |
| [google-workspace-ops](skills/google-workspace-ops/SKILL.md) | 操作 Google Drive/Docs/Sheets/Slides |
| [jira-integration](skills/jira-integration/SKILL.md) | Jira API 集成：MCP 或 REST 调用 |
| [x-api](skills/x-api/SKILL.md) | X/Twitter API：发推、时间线、搜索、分析、OAuth |
| [nutrient-document-processing](skills/nutrient-document-processing/SKILL.md) | Nutrient DWS API：PDF/DOCX/XLSX 处理、OCR、提取、编辑、签名 |
| [defuddle](skills/defuddle/SKILL.md) | 使用 Defuddle CLI 从网页提取干净 markdown，去除杂乱和导航 |

---

## 内容与写作 (Content & Writing)

内容创作、文案、SEO。

| Skill | 说明 |
|-------|------|
| [article-writing](skills/article-writing/SKILL.md) | 写文章/指南/博客/教程/通讯：独特声音、结构化、可信度 |
| [brand-voice](skills/brand-voice/SKILL.md) | 从真实帖子构建源派生写作风格档案，跨内容复用 |
| [content-engine](skills/content-engine/SKILL.md) | 平台原生内容系统：X/LinkedIn/TikTok/YouTube/Newsletter |
| [crosspost](skills/crosspost/SKILL.md) | 多平台内容分发：X/LinkedIn/Threads/Bluesky，每平台适配 |
| [seo](skills/seo/SKILL.md) | SEO 审计和实施：技术 SEO、页面优化、结构化数据、Core Web Vitals |
| [social-graph-ranker](skills/social-graph-ranker/SKILL.md) | 加权社交图谱排名：温暖路径发现、桥梁评分、网络缺口分析 |
| [lead-intelligence](skills/lead-intelligence/SKILL.md) | AI 原生线索智能和外展管道：信号评分、互排名、声音建模 |
| [investor-materials](skills/investor-materials/SKILL.md) | 创建 pitch deck、投资者备忘录、财务模型、融资材料 |
| [investor-outreach](skills/investor-outreach/SKILL.md) | 起草冷邮件、热介绍、跟进邮件、投资者沟通 |

---

## 商业与运营 (Business & Ops)

业务运营、物流、金融。

| Skill | 说明 |
|-------|------|
| [automation-audit-ops](skills/automation-audit-ops/SKILL.md) | 自动化清单和重叠审计：哪些 job/hooks/连接器是活的/坏的/冗余的 |
| [customer-billing-ops](skills/customer-billing-ops/SKILL.md) | 客户计费工作流：订阅、退款、流失分诊、计费门户恢复 |
| [email-ops](skills/email-ops/SKILL.md) | 邮箱分诊、起草、发送验证、已发邮件安全跟进 |
| [enterprise-agent-ops](skills/enterprise-agent-ops/SKILL.md) | 长期 Agent 工作负载操作：可观测性、安全边界、生命周期管理 |
| [finance-billing-ops](skills/finance-billing-ops/SKILL.md) | 收入、定价、退款、团队计费、计费模型真相工作流 |
| [messages-ops](skills/messages-ops/SKILL.md) | 实时消息工作流：读短信/DM、恢复一次性代码、检查线程 |
| [project-flow-ops](skills/project-flow-ops/SKILL.md) | GitHub + Linear 执行流：Issue 分诊、PR 管理、链接活动工作 |
| [research-ops](skills/research-ops/SKILL.md) | 当前状态研究工作流：新鲜事实、比较、丰富、推荐 |
| [terminal-ops](skills/terminal-ops/SKILL.md) | 仓库执行工作流：运行命令、检查仓库、调试 CI 失败、推送修复 |
| [unified-notifications-ops](skills/unified-notifications-ops/SKILL.md) | 统一通知操作：GitHub/Linear/桌面警报/hooks 的路由/去重/升级 |
| [product-capability](skills/product-capability/SKILL.md) | 将 PRD 意图转化为实现就绪的能力计划：约束、不变量、接口 |
| [product-lens](skills/product-lens/SKILL.md) | 构建前验证"为什么"：产品诊断、方向压力测试 |
| [cost-aware-llm-pipeline](skills/cost-aware-llm-pipeline/SKILL.md) | LLM API 成本优化：按任务复杂度路由模型、预算跟踪、重试、提示缓存 |
| [ecc-tools-cost-audit](skills/ecc-tools-cost-audit/SKILL.md) | ECC Tools 成本审计：PR 创建失控、配额绕过、模型泄漏 |
| [market-research](skills/market-research/SKILL.md) | 市场研究：竞争分析、投资者尽职调查、行业情报 |
| [data-scraper-agent](skills/data-scraper-agent/SKILL.md) | 全自动 AI 数据采集 Agent：定时抓取、LLM 富化、Notion/Sheets 存储 |

---

## Obsidian 集成 (Obsidian)

Obsidian 笔记生态系统集成。

| Skill | 说明 |
|-------|------|
| [obsidian-bases](skills/obsidian-bases/SKILL.md) | 创建/编辑 Obsidian Bases（.base 文件）：视图、过滤、公式、摘要 |
| [obsidian-cli](skills/obsidian-cli/SKILL.md) | Obsidian CLI：读/创建/搜索/管理笔记、任务、属性。支持插件开发 |
| [obsidian-markdown](skills/obsidian-markdown/SKILL.md) | Obsidian Flavored Markdown：wikilinks、embeds、callouts、properties |
| [json-canvas](skills/json-canvas/SKILL.md) | 创建/编辑 JSON Canvas 文件：节点、边、组、连接 |

---

## ECC 工具链 (ECC Tools)

Everything Claude Code 生态系统工具。

| Skill | 说明 |
|-------|------|
| [configure-ecc](skills/configure-ecc/SKILL.md) | ECC 交互式安装器 |
| [agent-sort](skills/agent-sort/SKILL.md) | ECC 安装计划排序 |
| [automation-audit-ops](skills/automation-audit-ops/SKILL.md) | ECC 自动化审计 |
| [ecc-tools-cost-audit](skills/ecc-tools-cost-audit/SKILL.md) | ECC Tools 成本审计 |
| [nanoclaw-repl](skills/nanoclaw-repl/SKILL.md) | NanoClaw v2 REPL：零依赖会话感知 REPL |
| [openclaw-persona-forge](skills/openclaw-persona-forge/SKILL.md) | OpenClaw 角色锻造 |
| [skill-comply](skills/skill-comply/SKILL.md) | 可视化 Skill/规则/Agent 定义是否被遵循：合规率报告 |
| [skill-stocktake](skills/sill-stocktake/SKILL.md) | Skill 质量审计：快速扫描和全量盘点 |
| [using-superpowers](skills/using-superpowers/SKILL.md) | 使用 Skill 工具的会话启动指南 |
| [workspace-surface-audit](skills/workspace-surface-audit/SKILL.md) | 工作区表面审计 |

---

## 其他 (Miscellaneous)

| Skill | 说明 |
|-------|------|
| [blueprint](skills/blueprint/SKILL.md) | 蓝图（内容待完善） |
| [carrier-relationship-management](skills/carrier-relationship-management/SKILL.md) | 承运商关系管理 |
| [connections-optimizer](skills/connections-optimizer/SKILL.md) | X/LinkedIn 网络重组：审查优先修剪、添加/关注建议 |
| [customs-trade-compliance](skills/customs-trade-compliance/SKILL.md) | 海关贸易合规 |
| [energy-procurement](skills/energy-procurement/SKILL.md) | 能源采购 |
| [inventory-demand-planning](skills/inventory-demand-planning/SKILL.md) | 库存需求规划 |
| [logistics-exception-management](skills/logistics-exception-management/SKILL.md) | 物流异常管理 |
| [opensource-pipeline](skills/opensource-pipeline/SKILL.md) | 开源管道：fork→清理→打包私有项目为公开发布 |
| [prompt-optimizer](skills/prompt-optimizer/SKILL.md) | 提示优化器（内容待完善） |
| [quality-nonconformance](skills/quality-nonconformance/SKILL.md) | 质量不合格管理 |
| [regex-vs-llm-structured-text](skills/regex-vs-llm-structured-text/SKILL.md) | 正则 vs LLM 结构化文本解析决策框架 |
| [returns-reverse-logistics](skills/returns-reverse-logistics/SKILL.md) | 退货逆向物流 |
| [production-scheduling](skills/production-scheduling/SKILL.md) | 生产排程 |
| [visa-doc-translate](skills/visa-doc-translate/SKILL.md) | 签证申请文件翻译（图片→英文双语 PDF） |
| [healthcare-cdss-patterns](skills/healthcare-cdss-patterns/SKILL.md) | CDSS 开发模式：药物交互、剂量验证、临床评分 |
| [healthcare-emr-patterns](skills/healthcare-emr-patterns/SKILL.md) | EMR/EHR 开发模式：临床安全、处方生成、无障碍 UI |
| [healthcare-eval-harness](skills/healthcare-eval-harness/SKILL.md) | 医疗安全评估框架：CDSS 准确性、PHI 暴露、临床工作流完整性 |
