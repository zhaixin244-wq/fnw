---
name: chip-spyglass-cdc-chk
description: "Use when running SpyGlass CDC checks on RTL. Triggers on 'cdc检查', 'cdc check', 'spyglass cdc', '跨时钟域检查', 'cdc验证', 'clock domain crossing', 'cdc setup', 'cdc_verify'. Generates SGDC constraints, runs CDC goals, produces violation reports."
---

# Chip SpyGlass CDC Checker

使用 SpyGlass 工具对 RTL 执行 CDC（Clock Domain Crossing）检查。

## When to Use

- 多时钟域设计的 RTL 完成后
- 需要验证跨时钟域信号是否正确同步
- CDC 签核（sign-off）前的检查
- 子模块交付前的 CDC 验证

## 工具路径

| 工具 | 路径 |
|------|------|
| SpyGlass | 系统 PATH（需安装 Synopsys SpyGlass） |

## 目录约定

| 项目 | 路径 |
|------|------|
| CDC 脚本 | `{module}_work/ds/run/run_cdc.sh` |
| SGDC 约束 | `{module}_work/ds/run/{module}.sgdc` |
| 报告目录 | `{module}_work/ds/report/cdc/` |
| Waiver 文件 | `{module}_work/ds/run/{module}.cdc.waiver` |
| 模板目录 | `.claude/skills/chip-spyglass-cdc-chk/templates/` |

## 核心工作流

```
Phase 0: 输入确认
  ├─ 确认顶层模块名和 RTL 文件列表
  ├─ 确认时钟域信息（来自 FS/微架构文档）
  └─ 确认 Black Box 模块列表

Phase 1: 生成 SGDC 约束
  ├─ 基于时钟域信息生成 clock/reset 定义
  ├─ 生成 abstract_port（Black Box 端口）
  ├─ 生成 set_case_analysis（MUX 选择端）
  └─ 生成 quasi_static（配置寄存器）

Phase 2: 执行 CDC Setup
  ├─ 运行 cdc_setup Goal
  ├─ 检查 autoclocks.sgdc / autoresets.sgdc
  ├─ 人工审查推导结果，删除非时钟/复位信号
  └─ 合并到主 SGDC 文件

Phase 3: 执行 CDC Setup Check
  ├─ 运行 cdc_setup_check Goal
  ├─ 修复所有 Error
  └─ 确保所有 Flip-Flop 有时钟

Phase 4: 执行 Clock/Reset Integrity
  ├─ 运行 clock_reset_integrity Goal
  └─ 修复 Glitch/Race 问题

Phase 5: 执行 CDC Verify
  ├─ 运行 cdc_verify_struct（结构检查）
  ├─ 运行 cdc_verify（功能检查）
  └─ 按优先级分类违例

Phase 6: 报告汇总
  ├─ 生成 cdc_summary.log
  └─ 输出违例分类统计
```

## Phase 0：输入确认

1. 从微架构文档或用户指定提取：
   - 顶层模块名
   - RTL 文件列表
   - 时钟域信息（时钟名、频率、来源）
   - 复位信息（复位名、极性、同步/异步）
   - Black Box 模块列表（PLL、第三方 IP 等）

2. 用 `Glob` 验证 RTL 文件存在

3. 检查是否已有 SGDC 文件，有则复用

## Phase 1：生成 SGDC 约束

根据输入信息生成 `{module}.sgdc`，参考模板 `templates/template_cdc_setup.sh`。

### SGDC 必须包含

```tcl
# 1. 顶层模块
current_design {module}

# 2. 时钟定义（从 FS/微架构获取）
clock -name "clk_main" -period 10 -edge 0 5
clock -name "clk_bus"  -period 20 -edge 0 10

# 3. 复位定义
reset -name "rst_n" -value 0

# 4. Black Box 端口约束（如有 Black Box）
abstract_port -module pll_top -ports clk_out -clock clk_main

# 5. MUX 选择端约束（时钟 MUX）
set_case_analysis -value 0 [get_ports test_mode]

# 6. 准静态信号（配置寄存器）
quasi_static -name "cfg_*"
```

### SGDC 编写规则

| 规则 | 说明 |
|------|------|
| 时钟必须定义周期 | `clock -name clk -period 10`，不写周期会导致 CDC 分析不完整 |
| 复位必须定义极性 | `reset -name rst_n -value 0` |
| Black Box 必须约束端口 | 使用 `abstract_port` 或 `signal_in_domain` |
| 位信号不能用 `[*]` | 必须写 `[1023:0]`，不能写 `[*]` |
| 表达式不能有计算 | 必须写 `[1023:0]`，不能写 `[1024-1:0]` |
| SDC 可转 SGDC | 使用 `sdc2sgdc` 命令，但需补充复位和 CDC 特有约束 |

## Phase 2-4：执行 CDC Setup 和检查

参考模板 `templates/template_cdc_verify.sh`。

### 执行顺序

```bash
# Step 1: CDC Setup（自动推导时钟/复位）
spyglass -project {module}_cdc.prj -goal cdc/cdc_setup

# Step 2: 检查推导结果
# 审查 spyglass_reports/clock_reset/auto*.sgdc
# 删除非时钟/复位信号，合并到主 SGDC

# Step 3: CDC Setup Check
spyglass -project {module}_cdc.prj -goal cdc/cdc_setup_check

# Step 4: Clock/Reset Integrity
spyglass -project {module}_cdc.prj -goal cdc/clock_reset_integrity

# Step 5: CDC Verify（结构+功能）
spyglass -project {module}_cdc.prj -goal cdc/cdc_verify_struct
spyglass -project {module}_cdc.prj -goal cdc/cdc_verify
```

## Phase 5：CDC Verify 违例分类

按修复优先级排序：

| 优先级 | 规则 | 类型 | 处理方式 |
|--------|------|------|----------|
| **P0** | Ac_unsync01/02 | 未同步跨域 | **必须修复，禁止 waive** |
| **P1** | Ac_conv01~05 | 信号收敛 | 分析是否真收敛，用 gray_signals 或修复 |
| **P2** | Ac_glitch* / Clock_glitch* | 毛刺 | 同步器输入必须来自寄存器 |
| **P3** | Ac_cdc01 | 信号宽度 | 快→慢时钟需要脉冲展宽 |
| **P4** | Ac_datahold01a | 数据保持 | qualifier 保护下数据必须稳定 |
| **P5** | Ac_cdc08 | 数据相关性 | 多 bit 信号需用异步 FIFO |
| **P6** | Ar_* | 复位同步 | 异步复位同步释放 |
| **P7** | Ac_fifo01 | FIFO 识别 | 确认异步 FIFO 正确性 |

## Phase 6：报告汇总

生成 `cdc_summary.log`：

```
=== CDC Summary ===
Module: {module}
Date: YYYY-MM-DD
SGDC: {module}.sgdc

Setup Check:     PASS/FAIL
Reset Integrity: PASS/FAIL
Struct Verify:   PASS ({N} violations)
Func Verify:     PASS ({N} violations)

Violation Breakdown:
  P0 (Ac_unsync):    {N} — MUST FIX
  P1 (Ac_conv):      {N} — REVIEW
  P2 (Ac_glitch):    {N} — REVIEW
  P3 (Ac_cdc01):     {N} — REVIEW
  P4 (Ac_datahold):  {N} — REVIEW
  P5 (Ac_cdc08):     {N} — REVIEW
  P6 (Ar_*):         {N} — REVIEW
  P7 (Ac_fifo):      {N} — REVIEW
  Total:             {N}

Next: Run chip-spyglass-cdc-resolver to analyze violations
```

## 异常处理

| 场景 | 处理 |
|------|------|
| SpyGlass 未安装 | 暂停，提示安装 Synopsys SpyGlass |
| SGDC 未提供 | 自动生成基础模板，标注 `[SGDC-AUTO]` |
| Setup Check 有 Error | 暂停 CDC Verify，先修复 Setup |
| 大量相似违例 | 提示检查 setup（时钟/复位/quasi_static） |
| Black Box 无约束 | 提示补充 `abstract_port`/`signal_in_domain` |

## 调用时机

| 时机 | 触发条件 |
|------|----------|
| 子模块 RTL 完成 | 每个含多时钟域的子模块 |
| 所有子模块完成 | CDC 签核前 |
| 修复后复检 | CDC 报告有 P0/P1 违例 |
| SoC 集成 | 子模块 Abstract View 生成后 |

## 输出文件

| 文件 | 用途 |
|------|------|
| `{module}.sgdc` | CDC 约束文件 |
| `cdc_summary.log` | CDC 检查汇总报告 |
| `spyglass_reports/` | SpyGlass 原始报告 |
| `{module}.cdc.waiver` | Waiver 文件（由 resolver 生成） |

## 与 chip-spyglass-cdc-resolver 的关系

本 skill 负责**执行 CDC 检查**，生成报告。报告分析和修复建议由 `chip-spyglass-cdc-resolver` 负责。

```
chip-spyglass-cdc-chk → 生成 cdc_summary.log
                    ↓
chip-spyglass-cdc-resolver → 分析违例 → 生成修复建议 + waiver 文件
```
