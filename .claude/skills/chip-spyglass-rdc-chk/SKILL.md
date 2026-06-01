---
name: chip-spyglass-rdc-chk
description: "Use when running SpyGlass RDC checks on RTL. Triggers on 'rdc检查', 'rdc check', 'spyglass rdc', '复位域交叉检查', 'rdc验证', 'reset domain crossing', 'rdc setup', 'rdc_verify'. Generates RDC constraints, runs RDC goals, produces violation reports."
---

# Chip SpyGlass RDC Checker

使用 SpyGlass 工具对 RTL 执行 RDC（Reset Domain Crossing）检查。

## When to Use

- 多复位域设计的 RTL 完成后
- 需要验证跨复位域信号是否正确处理
- RDC 签核（sign-off）前的检查
- 子模块交付前的 RDC 验证
- CDC 检查完成后，补充 RDC 检查

## 工具路径

| 工具 | 路径 |
|------|------|
| SpyGlass | 系统 PATH（需安装 Synopsys SpyGlass） |

## 目录约定

| 项目 | 路径 |
|------|------|
| RDC 脚本 | `{module}_work/ds/run/run_rdc.sh` |
| RDC 约束 | `{module}_work/ds/run/{module}.rdc.tcl` |
| 报告目录 | `{module}_work/ds/report/rdc/` |
| Waiver 文件 | `{module}_work/ds/run/{module}.rdc.waiver` |
| 模板目录 | `.claude/skills/chip-spyglass-rdc-chk/templates/` |

## 核心工作流

```
Phase 0: 输入确认
  ├─ 确认顶层模块名和 RTL 文件列表
  ├─ 确认复位域信息（来自 FS/微架构文档）
  ├─ 确认复位释放顺序
  └─ 确认 Black Box 模块列表

Phase 1: 生成 RDC 约束
  ├─ 基于复位域信息生成 reset 定义
  ├─ 生成 set_rdc_define_assertion_sequence（复位释放顺序）
  ├─ 生成 set_reset_groups（复位分组）
  ├─ 生成 rdc_qualifier（阻断信号）
  └─ 复用 CDC 的时钟/常量/准静态约束

Phase 2: 执行 RDC Setup
  ├─ 运行 rdc_setup Goal
  ├─ 检查复位定义完整性
  └─ 修复所有 Setup Error

Phase 3: 执行 RDC Verify
  ├─ 运行 rdc_verify（亚稳态检查）
  ├─ 运行 rdc_verify_corrupt（数据损坏检查）
  └─ 按优先级分类违例

Phase 4: 报告汇总
  ├─ 生成 rdc_summary.log
  └─ 输出违例分类统计
```

## Phase 0：输入确认

1. 从微架构文档或用户指定提取：
   - 顶层模块名
   - RTL 文件列表
   - 复位域信息（复位名、极性、同步/异步、所属功耗域）
   - 复位释放顺序（哪个复位先释放、哪个后释放）
   - 复位分组（哪些复位属于同一组）
   - RDC Qualifier 信号列表（阻断 RDC 路径的信号）
   - Black Box 模块列表

2. 用 `Glob` 验证 RTL 文件存在

3. 检查是否已有 CDC 约束（SGDC），RDC 可复用时钟/常量/准静态约束

## Phase 1：生成 RDC 约束

根据输入信息生成 `{module}.rdc.tcl`，参考模板 `templates/template_rdc_setup.sh`。

### RDC 约束必须包含

```tcl
# 1. 复用 CDC 约束（时钟/复位/常量/准静态）
source {module}.sgdc

# 2. RDC 复位定义
create_reset -name rst_n -active_low -async
create_reset -name rst_sw -active_high -sync

# 3. 复位释放顺序（最重要）
set_rdc_define_assertion_sequence \
    -from_reset {rst_sw} \
    -to_reset {rst_n}

# 4. 复位分组
set_reset_groups -name grp_por -group {rst_n}
set_reset_groups -name grp_func -group {rst_sw rst_dbg}

# 5. RDC Qualifier（阻断信号）
rdc_qualifier -signal cfg_rdc_gate -value 1

# 6. Scenario-Based（降噪）
configure_rdc_scenario -name func_mode \
    -active_resets {rst_sw rst_dbg} \
    -inactive_resets {rst_n}

# 7. Reset-less Flop 处理
configure_rdc_corrupt -skip_resetless_flops true
```

### RDC 约束编写规则

| 规则 | 说明 |
|------|------|
| 复位必须定义极性和类型 | `create_reset -name rst -active_low -async` |
| 复位释放顺序必须声明 | `set_rdc_define_assertion_sequence` 是降噪核心 |
| 同组复位必须分组 | `set_reset_groups` 消除组内 RDC |
| Qualifier 必须声明 | `rdc_qualifier` 消除已保护路径 |
| 复用 CDC 约束 | `source {module}.sgdc` 避免重复定义时钟 |
| Scenario 降噪 | 区分 PoR/Functional 场景减少噪声 |

## Phase 2-3：执行 RDC Setup 和 Verify

参考模板 `templates/template_rdc_verify.sh`。

### 执行顺序

```bash
# Step 1: RDC Setup（复位定义检查）
spyglass -project {module}_rdc.prj -goal rdc/rdc_setup

# Step 2: RDC Verify（亚稳态检查）
spyglass -project {module}_rdc.prj -goal rdc/rdc_verify

# Step 3: RDC Verify Corrupt（数据损坏检查）
spyglass -project {module}_rdc.prj -goal rdc/rdc_verify_corrupt
```

## Phase 4：RDC Verify 违例分类

按处理优先级排序：

| 优先级 | 类型 | 处理方式 |
|--------|------|----------|
| **P0** | 异步复位释放亚稳态 | **必须修复**：添加复位同步器或设置 reset ordering |
| **P1** | Reset-less path 数据损坏 | **分析判断**：添加 qualifier 或 safe-stating 逻辑 |
| **P2** | RDC on Clock Path | **必须修复**：复位信号禁止组合逻辑驱动时钟 |
| **P3** | 复位收敛问题 | **分析判断**：检查复位是否正确分组 |
| **P4** | Power Domain RDC | **分析判断**：需 UPF 确认隔离/开关 |

## 报告汇总

生成 `rdc_summary.log`：

```
=== RDC Summary ===
Module: {module}
Date: YYYY-MM-DD
RDC Constraints: {module}.rdc.tcl

Setup Check:     PASS/FAIL
RDC Verify:      PASS ({N} violations)
RDC Corrupt:     PASS ({N} violations)

Violation Breakdown:
  P0 (Async Reset Metastability):  {N} — MUST FIX
  P1 (Reset-less Path Corruption): {N} — REVIEW
  P2 (RDC on Clock Path):         {N} — MUST FIX
  P3 (Reset Convergence):          {N} — REVIEW
  P4 (Power Domain RDC):           {N} — REVIEW
  Total:                           {N}

Next: Run chip-spyglass-rdc-resolver to analyze violations
```

## 异常处理

| 场景 | 处理 |
|------|------|
| SpyGlass 未安装 | 暂停，提示安装 Synopsys SpyGlass |
| RDC 约束未提供 | 自动生成基础模板，标注 `[RDC-AUTO]` |
| 复位定义不完整 | 提示从 FS/微架构补充复位信息 |
| 大量相似违例 | 提示检查 reset ordering/grouping |
| CDC 约束不存在 | 提示先运行 chip-spyglass-cdc-chk |

## 调用时机

| 时机 | 触发条件 |
|------|----------|
| CDC 检查完成后 | 每个含多复位域的子模块 |
| 所有子模块完成 | RDC 签核前 |
| 修复后复检 | RDC 报告有 P0/P2 违例 |
| SoC 集成 | 子模块 Abstract View 生成后 |

## 输出文件

| 文件 | 用途 |
|------|------|
| `{module}.rdc.tcl` | RDC 约束文件 |
| `rdc_summary.log` | RDC 检查汇总报告 |
| `spyglass_reports/` | SpyGlass 原始报告 |
| `{module}.rdc.waiver` | Waiver 文件（由 resolver 生成） |

## 与 chip-spyglass-rdc-resolver 的关系

```
chip-spyglass-rdc-chk → 生成 rdc_summary.log
                    ↓
chip-spyglass-rdc-resolver → 分析违例 → 生成修复建议 + waiver 文件
```

## 与 chip-spyglass-cdc-chk 的关系

RDC 检查在 CDC 检查之后执行，复用 CDC 的时钟/复位/常量约束：

```
chip-spyglass-cdc-chk → CDC 验证 → cdc_summary.log + {module}.sgdc
                    ↓
chip-spyglass-rdc-chk → RDC 验证 → rdc_summary.log（复用 .sgdc 约束）
```
