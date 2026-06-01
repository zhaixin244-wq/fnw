---
name: chip-lint-checker
description: "Use when running RTL lint checks. Triggers on 'lint', 'verilator', 'verible', 'spyglass', '语法检查', '可综合性', '组合环路', 'latch检查', 'rtl lint', 'lint检查'. Supports multiple EDA tools with auto-detection."
---

# Chip Lint Checker

## 任务

对 RTL 代码执行 Lint 检查。根据配置或自动检测的 EDA 工具，调用对应模板执行。

## 工具分层

| 层级 | 工具 | 检查范围 | 模板 |
|------|------|----------|------|
| L2 综合 | Verilator | 可综合性/位宽/latch/组合环路 | `templates/template_a_verilator.sh` |
| L3 风格 | Verible | 命名/风格/编码规范 | `templates/template_b_verible.sh` |
| L2 综合 | Yosys | 组合环路/多驱动/综合可行性 | `templates/template_c_yosys.sh` |
| L4 专业 | SpyGlass | CDC/Lint/RDC | `templates/template_d_spyglass.sh` |
| L5 兜底 | LLM Manual | 人工审查 | `templates/template_e_manual.md` |

## 目录约定

| 项目 | 路径 |
|------|------|
| Lint 脚本 | `{module}_work/ds/run/run_lint.sh` |
| 报告目录 | `{module}_work/ds/report/lint/` |
| 配置文件 | `{module}_work/ds/run/lint_config.json`（可选） |
| 模板目录 | `.claude/skills/chip-lint-checker/templates/` |

## 工具路径

| 工具 | 路径 |
|------|------|
| Verilator | `tools/oss-cad-suite/bin/verilator` |
| Verible | `tools/verible/verible-verilog-lint.exe` |
| iverilog | `tools/oss-cad-suite/bin/iverilog` |
| Yosys | `tools/oss-cad-suite/bin/yosys` |
| SpyGlass | 系统 PATH（需安装） |

## 执行步骤

### Phase 0：工具检测

检查本地工具可用性，确定执行层级：

```bash
HAS_VERILATOR=0; HAS_VERIBLE=0; HAS_YOSYS=0; HAS_IV=0
tools/oss-cad-suite/bin/verilator --version >/dev/null 2>&1 && HAS_VERILATOR=1
tools/verible/verible-verilog-lint.exe --version >/dev/null 2>&1 && HAS_VERIBLE=1
tools/oss-cad-suite/bin/yosys --version >/dev/null 2>&1 && HAS_YOSYS=1
tools/oss-cad-suite/bin/iverilog -V >/dev/null 2>&1 && HAS_IV=1
```

选择逻辑：

| 条件 | 执行模板 |
|------|----------|
| 用户指定 SpyGlass | D（跳过检测） |
| Verilator + Verible 可用 | A + B（首选组合） |
| 仅 Verilator 可用 | A |
| 仅 Yosys 可用 | C |
| 均不可用 | E（LLM Manual） |

### Phase 1：确定输入

1. 从微架构文档或用户指定提取顶层模块名和 RTL 文件列表
2. 用 `Glob` 验证 RTL 文件存在，不存在则暂停
3. 检查 `lint_config.json` 中 `blackbox_modules` 配置（如有）

### Phase 2：组装 run_lint.sh

根据选定模板组装脚本。**按需加载模板**，仅读取需要的模板文件：

```
run_lint.sh = 文件头 + [模板A] + [模板B] + [模板C] + [模板D] + 汇总
```

每个模板独立自包含，有自己的变量定义和退出码处理。

### Phase 3：执行

```bash
mkdir -p {module}_work/ds/report/lint/
cd {module}_work && bash ds/run/run_lint.sh {top} {rtl_files}
```

### Phase 4：报告汇总

读取 `ds/report/lint/lint_summary.log`，格式：

```
=== Lint Summary ===
Phase A (Verilator):  PASS/FAIL
Phase B (Verible):    PASS/FAIL
Phase C (Yosys Lint): PASS/FAIL
Phase D (Yosys Synth):PASS/FAIL
Phase E (SpyGlass):   SKIP/PASS/FAIL
Overall: PASS/HAS FAILURES
```

## Warning 分级

| 级别 | 处理 |
|------|------|
| **Critical** | 必须修复（组合环路/多驱动/语法 error） |
| **Major** | 必须修复或标注 waive（未声明信号/位宽截断/隐式 latch） |
| **Minor** | 建议修复（端口未连接/敏感列表冗余） |
| **Info** | 仅记录（参数未使用/信号仅赋值未读取） |

## 工具能力对比

| 检查项 | Verilator | Verible | Yosys | SpyGlass | LLM |
|--------|-----------|---------|-------|----------|-----|
| 语法检查 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 可综合性 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 位宽检查 | ✅ | ❌ | ❌ | ✅ | ✅ |
| latch 检测 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 组合环路 | ✅ | ❌ | ✅ | ✅ | ❌ |
| 命名规范 | ❌ | ✅ | ❌ | ✅ | ✅ |
| 代码风格 | ❌ | ✅ | ❌ | ✅ | ✅ |
| CDC 检查 | ❌ | ❌ | ❌ | ✅ | ❌ |

## 使用示例

**示例 1**：自动检测
- 用户：「data_adpt RTL 写完了，跑一下 Lint」
- 行为：检测到 Verilator+Verible，加载模板 A+B，生成 run_lint.sh，执行

**示例 2**：指定 SpyGlass
- 用户：「用 SpyGlass 跑 buf_mgr 的 CDC 检查」
- 行为：加载模板 D，生成 SGDC 约束文件，执行 `cdc/cdc` goal

**示例 3**：仅风格检查
- 用户：「检查 data_adpt 的编码风格」
- 行为：仅加载模板 B（Verible），执行

## 异常处理

| 场景 | 处理 |
|------|------|
| 工具不可用 | 降级到 L5 LLM Manual，标注 `[LINT-MANUAL]` |
| 部分工具不可用 | 执行可用模板，跳过不可用阶段，标注 `[LINT-DEGRADED]` |
| Critical 错误 | 标注 FAIL，逐条分析并给出修复建议 |
| RTL 文件为空 | 暂停，提示先完成 RTL 实现 |
| SpyGlass 无 SGDC | 自动生成基础模板，标注 `[SGDC-AUTO]` |

## 检查点

**检查前**：RTL 文件非空、至少一个工具可用
**检查后**：lint_summary.log 已生成、Critical/Major 已列出、降级已标注

## 调用时机

| 时机 | 触发条件 |
|------|----------|
| 子模块 RTL 完成 | 每个子模块写完后 |
| 所有子模块完成 | quality_check 阶段入口 |
| 修复后复检 | Lint 报告有 Critical/Major |
| CDC 检查 | 多时钟域设计完成后（需 SpyGlass） |

## CBB Ref

- Verilator: `tools/oss-cad-suite/bin/verilator`
- Verible: `tools/verible/verible-verilog-lint.exe`
- Verible Rules: `tools/verible/verible-lint.rules`
- Yosys: `tools/oss-cad-suite/bin/yosys`
- SpyGlass: 需单独安装（Synopsys）
