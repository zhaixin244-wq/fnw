# chip-code-writer Agent 优化总结

> 优化日期：2026-04-23
> 优化目标：
> 1. 把 RTL 的 Lint 与综合检查设置为强制项目
> 2. 优化 RTL 开发流程，支持并行开发

---

## 一、强制质量门禁

### 1.1 修改内容

| 文件 | 修改内容 |
|------|----------|
| `chip-code-writer.md` | 添加强制质量门禁声明章节 |
| `impl-flow-template.json` | 添加 `mandatory_gate: true` 和 `gate_policy` |
| `quality-checklist-impl.md` | 添加强制质量门禁声明 |
| `chip-arch-reviewer.md` | 添加维度 D：质量门禁检查 |

### 1.2 强制门禁规则

| 门禁类型 | 强制级别 | 通过标准 | 失败行为 | 跳过权限 |
|----------|----------|----------|----------|----------|
| **Lint 检查** | **MUST** | `lint_summary.log` 输出 ALL PASS | 必须进入自愈循环修复，禁止交付 | **禁止跳过** |
| **综合检查** | **MUST** | `synth_summary.log` 输出 ALL PASS + 面积差异 <50% | 必须进入自愈循环优化，禁止交付 | **禁止跳过** |
| **自检** | **MUST** | IC-01~39 + IM-01~08 全部通过 | 必须逐项修复后重新自检 | **禁止跳过** |

### 1.3 违反后果

- 交付物视为无效
- chip-arch-reviewer 有权拒绝评审
- 必须补充质量报告后才能继续

---

## 二、并行 RTL 开发流程

### 2.1 流程概述

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Plan Mode 分析阶段                                    │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │ PR/FS/UA    │ →  │ CBB 清单    │ →  │ 模块清单    │ →  │ 任务分解    │   │
│  │ 需求分析    │    │ 依赖分析    │    │ 划分确认    │    │ 并行度评估  │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                        并行 Subagent 开发阶段                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │ Subagent 1  │    │ Subagent 2  │    │ Subagent N  │    │ 独立 Lint   │   │
│  │ 模块 A RTL  │    │ 模块 B RTL  │    │ 模块 N RTL  │    │ + 综合检查  │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                        顶层集成阶段                                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │ 顶层 Lint   │ →  │ 顶层综合    │ →  │ PR/FS/UA    │ →  │ RTL Review  │   │
│  │ 检查        │    │ 检查        │    │ 整体确认    │    │ 启动        │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 阶段 1：Plan Mode 分析

**输入**：
- PR（Product Requirement）产品需求文档
- FS（Function Specification）功能规格书
- UA（User Acceptance）用户验收标准

**输出**：
| 输出项 | 内容 | 格式 |
|--------|------|------|
| `cbb_dependency.md` | CBB 依赖清单 | 列表 + RAG 检索结果 |
| `module_list.md` | 待开发模块清单 | 模块名 + 依赖关系 + 复杂度评估 |
| `task_breakdown.md` | 任务分解表 | 模块 → 子任务 → 预估工时 |
| `parallel_strategy.md` | 并行策略 | 可并行模块分组 + 依赖链 |

### 2.3 阶段 2：并行 Subagent 开发

**调用规范**：
```
Agent({
  description: "RTL 开发 - {模块名}",
  subagent_type: "chip-code-writer",
  prompt: `
    开发 {module_name} 模块 RTL。

    输入：
    - 微架构文档：{path_to_microarch}
    - 编码规范：.claude/rules/coding-style.md
    - CBB 清单：{cbb_list_path}

    输出要求：
    - RTL 源码：{module}_work/rtl/{submodule}.v
    - SVA 断言：{module}_work/rtl/{submodule}_sva.sv
    - SDC 约束：{module}_work/syn/{submodule}.sdc
    - CBB 清单：{module}_work/ds/doc/{submodule}_cbb_list.md

    强制门禁：
    - 必须通过 Lint 检查（ALL PASS）
    - 必须通过综合检查（ALL PASS + 面积差异 <50%）
    - 禁止跳过质量门禁

    交付条件：
    - Lint 报告：{module}_work/ds/report/lint/lint_summary.log
    - 综合报告：{module}_work/ds/report/syn/synth_summary.log
    - 两个报告均显示 ALL PASS
  `
})
```

**并行调度规则**：
| 规则 | 说明 |
|------|------|
| **依赖优先** | 有依赖的模块必须等待依赖完成 |
| **无依赖并行** | 无依赖模块可同时启动多个 subagent |
| **独立工作目录** | 每个模块使用独立 `{module}_work/` 目录 |
| **独立 Lint/综合** | 每个模块独立执行 Lint 和综合检查 |
| **状态同步** | 主 agent 跟踪所有 subagent 状态 |

### 2.4 阶段 3：顶层集成与确认

**触发条件**：所有子模块 Lint + 综合检查均通过

**执行方式**：
```bash
# 顶层 Lint
cd {module}_work && bash ds/run/run_lint.sh {top_module} rtl/*.v

# 顶层综合
cd {module}_work && bash ds/run/run_synth.sh {top_module} rtl/*.v
```

**检查内容**：
| 检查项 | 标准 | 失败行为 |
|--------|------|----------|
| 模块间接口一致性 | 端口名、位宽、方向匹配 | 定位不匹配模块，修复后重跑 |
| 层次结构完整性 | 所有子模块已实例化 | 补充缺失实例化 |
| 顶层面积汇总 | 与各模块面积之和对比 | 分析差异原因 |
| 顶层时序路径 | 关键路径识别 | 优化关键路径 |

### 2.5 PR/FS/UA 整体确认

**确认内容**：
| 确认维度 | 检查方法 | 输出 |
|----------|----------|------|
| 功能覆盖 | 对照 FS §4 功能列表 | 功能覆盖矩阵 |
| 接口一致 | 对照 FS §6 接口定义 | 接口一致性报告 |
| PPA 达标 | 对照 FS §8 PPA 规格 | PPA 达标报告 |
| 需求追溯 | 对照 RTM（FS §14） | 需求覆盖率 |

### 2.6 RTL Review 启动

**启动条件**：
- 所有模块 Lint + 综合检查通过 ✅
- 顶层 Lint + 综合检查通过 ✅
- PR/FS/UA 整体确认完成 ✅

**启动方式**：
```
启动 chip-arch-reviewer 进行 RTL 评审。

评审输入：
- 顶层 RTL：{module}_work/rtl/{top_module}.v
- 子模块 RTL：{module}_work/rtl/*.v
- SVA 断言：{module}_work/rtl/*_sva.sv
- CBB 清单：{module}_work/ds/doc/*_cbb_list.md
- Lint 报告：{module}_work/ds/report/lint/lint_summary.log
- 综合报告：{module}_work/ds/report/syn/synth_summary.log
- 确认报告：{module}_work/ds/doc/rtl_implementation_report.md
```

---

## 三、修改文件清单

| 文件 | 修改类型 | 修改内容 |
|------|----------|----------|
| `.claude/agents/chip-code-writer.md` | 更新 | 添加强制质量门禁声明、并行开发流程、更新示例 |
| `.claude/shared/flow/impl-flow-template.json` | 更新 | 添加 mandatory_gate、gate_policy、mandatory_reports |
| `.claude/shared/quality-checklist-impl.md` | 更新 | 添加强制质量门禁声明、更新执行顺序 |
| `.claude/agents/chip-arch-reviewer.md` | 更新 | 添加维度 D：质量门禁检查、更新标准步骤 |

---

## 四、使用示例

### 4.1 单模块开发

```
用户：帮我为 axi_bridge 模块的 buf_mgr 子模块写 RTL

Agent 执行流程：
1. 输入确认
2. RAG 检索
3. 模块结构规划
4. 数据通路+控制+CBB+接口实现
5. SDC/SVA/TB 编写
6. Lint 检查（强制）→ ALL PASS
7. 综合检查（强制）→ ALL PASS
8. 自检（强制）→ 全部通过
9. 交付
```

### 4.2 多模块并行开发

```
用户：帮我为 axi_bridge 模块开发所有子模块的 RTL

Agent 执行流程：
1. Plan Mode 分析
   - 分析 PR/FS/UA
   - 确定 CBB 依赖
   - 划分模块
   - 评估并行度

2. 并行 Subagent 开发
   - 启动 Subagent 1：buf_mgr 模块
   - 启动 Subagent 2：ctrl_fsm 模块
   - 每个 subagent 独立执行 Lint + 综合检查

3. 顶层集成
   - 启动顶层集成 subagent
   - 执行顶层 Lint + 综合检查
   - PR/FS/UA 整体确认

4. RTL Review
   - 启动 chip-arch-reviewer
   - 检查质量门禁
   - 四维度评审
```

---

## 五、注意事项

1. **质量门禁不可跳过**：任何情况下不得跳过或降级 Lint、综合、自检门禁
2. **并行开发需谨慎**：确保模块间无依赖关系才能并行开发
3. **状态同步**：主 agent 必须跟踪所有 subagent 的状态
4. **报告完整性**：每个模块必须包含 Lint 和综合报告
5. **评审前置条件**：chip-arch-reviewer 必须首先检查质量门禁

---

## 六、后续优化方向

1. **自动化测试集成**：将 TB 仿真集成到质量门禁中
2. **CDC 检查集成**：将 CDC 检查集成到质量门禁中
3. **覆盖率报告**：添加功能覆盖率报告
4. **持续集成**：与 CI/CD 流程集成

---

## 七、质量门禁落地修复（2026-04-24）

### 7.1 问题

原 agent 定义中"强制质量门禁"仅为声明性文字，实际执行依赖 `chip-impl-quality-gate` 等 Skill，但这些 Skill **从未创建**（`.claude/skills/` 下无 `chip-impl-*` 文件）。导致：
- RTL 生成后不自动生成 run 脚本
- RTL 生成后不执行 Lint 检查
- RTL 生成后不执行综合检查

### 7.2 修复方案

将质量门禁从"依赖外部 Skill"改为"**内联可执行指令**"：

| 文件 | 修改内容 |
|------|----------|
| `chip-code-writer.md` | 新增 `## 质量门禁执行流程（内联）` 章节：Step 1 生成 run 脚本 → Step 2 执行 Lint → Step 3 执行综合 → Step 4 自愈循环。更新代办清单为 10 步 |
| `impl-flow-stages.json` | `sdc_sva` → `sdc_sva_scripts`（含 run 脚本生成）；`quality_check` 标记 `skill: "inline"`，新增 `inline_steps` |
| `agent-config.json` | 路径修正：`syn/` → `run/`；工具名：`iverilog` → `verilator`；新增 run 目录条目 |
| `skills-registry-impl.md` | `chip-impl-quality-gate` 标注"内联在 agent 定义中" |

### 7.3 新流程

```
RTL 代码实现 (B)
    ↓
SVA + Run 脚本生成 (C)  ← 自动生成 .f / .sdc / lint.sh / synth_yosys.tcl
    ↓
执行 Lint 检查 (D)      ← 自动运行 Verilator，ALL PASS 才继续
    ↓
执行综合检查 (D)        ← 自动运行 Yosys，ALL PASS 才继续
    ↓
自检 (D)
    ↓
交付 (D)
```

### 7.4 自愈循环规则

- 最大迭代 10 次，超过暂停等待用户确认
- 同一错误反复 3 次 → 暂停，输出根因分析
- 修复范围仅限当前错误，不引入新逻辑
- 架构冻结：自愈修复不得改变架构设计
