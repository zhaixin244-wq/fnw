---
name: chip-impl-quality-gate
description: "Use when running lint checks, synthesis, or quality gates on RTL code. Triggers on '综合', 'lint', 'synth', 'quality gate', '质量门禁', '门禁', 'verilator', 'yosys', '自检', 'check'. Executes lint+synth checks with auto-heal loop on failures."
---

# 质量门禁 Skill

## 任务
执行 Lint 和综合检查，不通过时自动进入自愈循环修复。

## 强制门禁声明
> **铁律：Lint 和综合检查是 RTL 交付的强制前置条件，不可跳过、不可降级。**

| 门禁 | 强制级别 | 通过标准 | 失败行为 |
|------|----------|----------|----------|
| **Lint** | **MUST** | `lint_summary.log` ALL PASS | 进入自愈循环修复 |
| **综合** | **MUST** | `synth_summary.log` ALL PASS + 面积差异 <50% | 进入自愈循环优化 |

## 输入
- `rtl_files`: RTL 文件列表
- `sdc_file`: SDC 约束文件
- `work_dir`: 工作目录路径

## 执行步骤

0. **文件发现**：用 `Glob` 搜索 `{module}_work/ds/rtl/*.v` 获取 RTL 文件列表。若文件不存在，暂停并提示用户。同时验证 lint/synth 脚本（`{module}_work/ds/run/run_lint.sh`、`{module}_work/ds/run/run_synth.sh`）存在

1. **环境检测**：检查工具可用性，缺失时提示安装：
```bash
# 检查 iverilog
command -v .claude/tools/oss-cad-suite/bin/iverilog >/dev/null 2>&1 || \
  command -v iverilog >/dev/null 2>&1 || \
  { echo "[ENV-MISSING] iverilog not found. Install oss-cad-suite or add to PATH."; exit 1; }

# 检查 yosys
command -v .claude/tools/oss-cad-suite/bin/yosys >/dev/null 2>&1 || \
  command -v yosys >/dev/null 2>&1 || \
  { echo "[ENV-MISSING] yosys not found. Install oss-cad-suite or add to PATH."; exit 1; }
```
**工具路径优先级**：项目本地 `.claude/tools/oss-cad-suite/bin/` > 系统 PATH。
检测失败 → 暂停，标注 `[ENV-MISSING]`，提示用户安装。

2. **Lint 检查**：
   ```bash
   cd {module}_work && bash ds/run/run_lint.sh {top} rtl/*.v
   ```
   读取 `ds/report/lint/lint_summary.log`：
   - ALL PASS → 进入步骤 2
   - HAS FAILURES → 进入 Lint 修复

3. **综合检查**：
   ```bash
   cd {module}_work && bash ds/run/run_synth.sh {top} rtl/*.v
   ```
读取 `ds/report/syn/synth_summary.log`：
- ALL PASS + 面积差异 <50% → 门禁通过
- 面积差异 >50% → **暂停确认**
- HAS FAILURES → 进入综合优化

## 自愈循环

```
Lint → ALL PASS? → Synthesis → ALL PASS? → 通过
         ↓ No              ↓ No
    Lint 分析          Synth 分析
         ↓                  ↓
    修复 RTL           优化 RTL
         ↓                  ↓
    重跑 Lint          重跑 Synth
```

### Lint 修复规则

**Critical（必须修复）**：
| 错误类型 | 识别特征 | 修复规则 |
|----------|----------|----------|
| 语法 error | `1_iverilog.log` 中 error 行 | 补分号/修正端口声明 |
| 组合环路 | `2_yosys_lint.log` 中 `combinational loop` | 插入时序寄存器打断 |
| 多驱动 | `2_yosys_lint.log` 中 `multiple driver` | 合并到单个 always 块 |

**Major（必须修复或 waive）**：
| 错误类型 | 识别特征 | 修复规则 |
|----------|----------|----------|
| 未声明信号 | `not declared` | 补 wire/reg 声明 |
| 位宽截断 | `width mismatch` | 修正位宽或显式截位 |
| 隐式 latch | `inferred latch` | 默认值+else+default |

### 综合优化规则

**面积优化（差异 20~50%）**：
- 寄存器阵列→SRAM 推断
- 位宽收紧
- 运算符复用
- 冗余寄存器合并

**面积差异 >50%**：**Critical — 暂停**，等用户决定。

**时序优化**：
- 关键路径识别→插入流水线
- 逻辑深度过大→重定时
- 扇出过大→插 buffer

## 迭代控制

| 条件 | 行为 |
|------|------|
| `total_iterations < 10` | 继续自动循环 |
| `total_iterations >= 10` | **暂停**，输出迭代历史，等用户确认 |
| 连续 3 次 Lint↔Synth 交替失败 | 暂停，标记 `[OPT-OSCILLATE]`，回滚到上次双通过 |
| `total_iterations >= 30` | **强制退出**，标记 `[OPT-EXHAUSTED]` |

## 输出
- `lint_report`: Lint 报告路径
- `synth_report`: 综合报告路径

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/quality_check.json`：
```json
{"stage_id": "quality_check", "duration_ms": 0, "iteration_count": 1}
```
`iteration_count` 记录自愈循环实际迭代次数。

## 工具
| 工具 | 路径 | 用途 |
|------|------|------|
| iverilog | `.claude/tools/oss-cad-suite/bin/iverilog` | 语法 Lint |
| yosys | `.claude/tools/oss-cad-suite/bin/yosys` | 综合 Lint + 面积估计 |

## 商业工具（可选）
| 工具 | 用途 | 优先级 |
|------|------|--------|
| SpyGlass | Lint + CDC 形式验证 | 高于 verilator |
| Design Compiler | 综合 | 高于 yosys |
| Genus | 综合（Cadence） | 高于 yosys |

## 使用示例

**示例 1**：
- 用户：「公共模块 RTL 写完了，跑一下质量门禁」
- 行为：Step 0 检测工具可用性，Step 1 执行 Lint 检查，Step 2 执行综合检查，失败则进入自愈循环修复，最终输出 lint_report 和 synth_report

**示例 2**：
- 用户：「buf_mgr 综合面积超标了，帮我优化」
- 行为：读取综合报告分析面积差异，若 20~50% 则尝试寄存器阵列→SRAM 推断、位宽收紧等优化，若 >50% 则暂停等待用户确认

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 工具不可用 | iverilog/yosys 不在 PATH 且无本地安装 | 暂停，标注 `[ENV-MISSING]`，提示安装 oss-cad-suite |
| 自愈循环超限 | 迭代次数 ≥30 | 强制退出，标注 `[OPT-EXHAUSTED]`，输出迭代历史 |
| 振荡失败 | 连续 3 次 Lint↔Synth 交替失败 | 暂停，标注 `[OPT-OSCILLATE]`，回滚到上次双通过 |
| 面积差异 >50% | 综合面积远超预估 | Critical 暂停，等待用户决定是否继续优化 |

## 检查点

**检查前**：
- 确认 RTL 文件列表非空
- 确认 SDC 约束文件存在
- 确认 iverilog/yosys 工具可用

**检查后**：
- 确认 `lint_summary.log` 为 ALL PASS
- 确认 `synth_summary.log` 为 ALL PASS + 面积差异 <50%
- 确认自愈循环迭代次数已记录到 metrics
