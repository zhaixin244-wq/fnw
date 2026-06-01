---
name: chip-sdc-generator
description: "Use when generating comprehensive SDC timing constraints from FS/microarch documents. Triggers on '生成SDC', 'SDC约束', 'timing constraints', '时序约束文件', 'write SDC', 'SDC文件'. Produces production-quality SDC covering clocks, I/O, design rules, timing exceptions, and area/power constraints."
---

# Chip SDC Generator

## 任务

根据 FS 功能规格书和微架构文档，生成完整的 SDC 时序约束文件。采用参数化模板方法，覆盖时钟定义、I/O 约束、设计规则、时序例外、面积/功耗约束全部类别。

**与 chip-impl-sdc-sva 的区别**：chip-impl-sdc-sva 是实现流水线中的快速 SDC 生成（仅从微架构 §6 提取基础时钟约束）；chip-sdc-generator 是独立的、全量 SDC 生成 skill，从 FS 提取完整约束需求，输出生产级 SDC 文件。

**与 chip-sta-analyst 的关系**：chip-sta-analyst 负责综合执行和时序分析；chip-sdc-generator 为其提供输入 SDC 文件。当用户需要"综合+时序分析"时，先用 chip-sdc-generator 生成 SDC，再交由 chip-sta-analyst 执行。

---

## 输入

| 输入 | 来源 | 必需 | 说明 |
|------|------|------|------|
| FS 文档 | `{module}_work/ds/doc/fs/{module}_FS_v{X}.md` | 是 | 时钟域、接口定义、PPA 指标、时序例外 |
| 微架构文档 | `{module}_work/ds/doc/ua/{module}_*_microarch_v{X}.md` | 否 | 关键路径分析、FIFO 参数、子模块时序 |
| RTL 文件 | `{module}_work/ds/rtl/*.v` | 否 | 端口列表自动提取（辅助） |
| 外部器件规格 | 用户提供或 FS §13 假设条件 | 否 | I/O delay 精确计算依据 |

---

## 知识检索

执行前必须完成以下 Wiki 检索（按需）：

1. `wiki/concepts/SDC-Generation-Methods.md` — 4 种生成方法和模板参考
2. `wiki/concepts/SDC-Best-Practices.md` — 编写顺序、常见陷阱、验证清单
3. `wiki/questions/Research SDC文件生成规则与方法.md` — 综合研究（工具链、经验参数）
4. `wiki/eda/synopsys/design-compiler/dc-constraints.md` — DC 工具 SDC 编写指南（如使用 DC）
5. `wiki/eda/synopsys/primetime/pt-constraints.md` — PT 约束编写指南（如使用 PT）

---

## 执行步骤

### Phase 0：前置检查

1. 用 `Glob` 搜索 `{module}_work/ds/doc/fs/*FS*.md` 获取 FS 文档
2. 若 FS 不存在，暂停并提示用户先完成 FS 编写
3. 用 `Glob` 搜索 `{module}_work/ds/doc/ua/*microarch*.md` 获取微架构文档（可选）
4. 用 `Glob` 搜索 `{module}_work/ds/rtl/*.v` 获取 RTL 文件列表（可选，用于端口提取）

### Phase 1：约束信息提取

从 FS 文档中提取以下信息：

| 提取项 | FS 来源 | 用途 |
|--------|---------|------|
| 时钟域定义 | §9 时钟与复位 | `create_clock` |
| 时钟频率 | §9 + §8.1 性能指标 | `-period` 参数 |
| PLL/分频器 | §9 + §5 子模块 | `create_generated_clock` |
| 时钟域关系 | §9 + §7 CDC | `set_clock_groups` |
| I/O 端口列表 | §6 顶层接口定义 | `set_input/output_delay` |
| 接口协议 | §6.1 接口列表 | I/O delay 精确建模 |
| PPA 指标 | §8 | 设计规则约束值 |
| 最大频率 | §8.1 | 时钟周期 |
| 功耗预算 | §8.2 | `set_max_dynamic_power` |
| 面积预算 | §8.3 | `set_max_area` |
| 设计约束 | §13 | 工艺节点、总线协议 |
| 时序例外 | §4.4 + §5.3 | `set_false_path` / `set_multicycle_path` |
| 复位策略 | §9 | 复位路径约束 |
| 异常处理 | §6.4 + §4.4 | 超时路径约束 |

从微架构文档中补充：

| 提取项 | 微架构来源 | 用途 |
|--------|-----------|------|
| 关键路径 | §6 关键时序分析 | 过约束/放松判断 |
| FIFO 深度 | §5.5 | 流控路径约束 |
| 流水线级数 | §5.4 | multicycle path 判断 |
| 子模块时钟 | §7 | 子模块时钟约束 |

### Phase 2：SDC 生成

按以下顺序生成 SDC（遵循 SDC Best Practices 编写顺序）：

#### 2.1 文件头

```tcl
###############################################################################
# {module_name} SDC Constraints
# Version: v{X.Y}
# Date: YYYY-MM-DD
# Author: {author}
# Description: {简述}
# Source: {module_name}_FS_v{X}.md + {module_name}_microarch_v{X}.md
###############################################################################
```

#### 2.2 参数定义（参数化模板）

```tcl
#==============================================================================
# Parameters — 修改以下参数即可调整约束，无需修改命令
#==============================================================================
set CLK_NAME        {clk_name}          ;# 主时钟名
set CLK_PORT        {clk_port}          ;# 主时钟端口名
set CLK_PERIOD      {period_ns}         ;# 时钟周期 (ns)
set CLK_UNCERTAINTY_SETUP  [expr $CLK_PERIOD * 0.05]  ;# setup uncertainty (5%)
set CLK_UNCERTAINTY_HOLD   [expr $CLK_PERIOD * 0.02]  ;# hold uncertainty (2%)
set CLK_LATENCY_SRC        [expr $CLK_PERIOD * 0.10]  ;# source latency (10%)
set CLK_LATENCY_NET        [expr $CLK_PERIOD * 0.10]  ;# network latency (10%)
set IO_DELAY_PCT    0.20                ;# I/O delay 占周期比例
set MAX_FANOUT      16                  ;# 最大扇出
set MAX_TRANSITION  [expr $CLK_PERIOD * 0.10]  ;# 最大 transition
set MAX_CAPACITANCE 0.5                 ;# 最大电容 (pF)
set MAX_AREA        {area_value}        ;# 面积约束
```

#### 2.3 时钟定义

```tcl
#==============================================================================
# Clock Definition
#==============================================================================
# 基本时钟
create_clock -name $CLK_NAME -period $CLK_PERIOD [get_ports $CLK_PORT]

# 虚拟时钟（如有外部设备时钟不进入芯片）
#create_clock -name virt_ext_clk -period $EXT_CLK_PERIOD

# 生成时钟（PLL/分频器输出）
#create_generated_clock -name clk_div2 -divide_by 2 \
#    -source [get_pins {div_reg/CK}] [get_pins {div_reg/Q}]
```

**生成规则**：
- 从 FS §9 提取所有时钟域，每个时钟域一个 `create_clock`
- PLL 输出使用 `create_generated_clock`，`-source` 必须引用物理 pin/port
- 多时钟同端口使用 `-add` 参数
- 虚拟时钟用于外部设备 I/O 分析

#### 2.4 时钟属性

```tcl
#==============================================================================
# Clock Attributes
#==============================================================================
set_clock_uncertainty -setup $CLK_UNCERTAINTY_SETUP [get_clocks $CLK_NAME]
set_clock_uncertainty -hold  $CLK_UNCERTAINTY_HOLD  [get_clocks $CLK_NAME]
set_clock_latency -source $CLK_LATENCY_SRC [get_clocks $CLK_NAME]
set_clock_latency $CLK_LATENCY_NET [get_clocks $CLK_NAME]
#set_clock_transition 0.1 [get_clocks $CLK_NAME]
```

**经验参数**（来源：wiki/concepts/SDC-Best-Practices.md）：

| 参数 | 经验值 | 说明 |
|------|--------|------|
| uncertainty (setup) | 周期 × 5%~10% | jitter + skew |
| uncertainty (hold) | 周期 × 2%~3% | hold 裕量 |
| source latency | 周期 × 10% | 时钟源到定义点 |
| network latency | 周期 × 10% | 时钟网络延迟 |
| transition | 周期 × 10% | 时钟 transition |

#### 2.5 时钟组关系

```tcl
#==============================================================================
# Clock Groups
#==============================================================================
# 异步时钟域（从 FS §9 CDC 处理提取）
#set_clock_groups -asynchronous \
#    -group [get_clocks clk_a] \
#    -group [get_clocks clk_b]

# 互斥时钟（MUX 选择）
#set_clock_groups -logically_exclusive \
#    -group [get_clocks clk_a_mux] \
#    -group [get_clocks clk_b_mux]
```

**生成规则**：
- 从 FS §9 和 §7（CDC 处理）提取时钟域关系
- 异步时钟域必须用 `-asynchronous` 隔离
- MUX 选择的时钟用 `-logically_exclusive`
- 同源但不同时激活的时钟用 `-physically_exclusive`

#### 2.6 I/O 约束

```tcl
#==============================================================================
# I/O Constraints
#==============================================================================
# 输入延迟（排除时钟和复位端口）
set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] [get_ports $CLK_PORT]]
set non_reset_inputs [lsearch -inline -all -not -exact $non_clock_inputs [get_ports rst_n]]
set_input_delay -clock $CLK_NAME -max [expr $CLK_PERIOD * $IO_DELAY_PCT] $non_reset_inputs
set_input_delay -clock $CLK_NAME -min [expr $CLK_PERIOD * 0.05] $non_reset_inputs

# 输出延迟
set_output_delay -clock $CLK_NAME -max [expr $CLK_PERIOD * $IO_DELAY_PCT] [all_outputs]
set_output_delay -clock $CLK_NAME -min [expr $CLK_PERIOD * 0.05] [all_outputs]

# 驱动强度
set_driving_cell -lib_cell BUFX2 -pin Y $non_reset_inputs

# 负载
set_load [expr $MAX_CAPACITANCE * 0.5] [all_outputs]
```

**I/O delay 精确计算**（当有外部器件规格时）：

```
Input Delay  = T_co(外部器件) + T_trace(PCB走线)
Output Delay = T_trace(PCB走线) + T_setup(外部器件)
```

**经验值**（来源：wiki/sources/learnvlsi-sdc-constraints.md）：

| 约束项 | 经验值 | 说明 |
|--------|--------|------|
| I/O delay | 周期 × 20%~60% | 视外部器件速度 |
| feed-through delay | 周期 × 35% | 输入直通到输出 |

#### 2.7 设计规则约束

```tcl
#==============================================================================
# Design Rule Constraints
#==============================================================================
set_max_fanout $MAX_FANOUT [current_design]
set_max_transition $MAX_TRANSITION [current_design]
set_max_capacitance $MAX_CAPACITANCE [current_design]
#set_max_area $MAX_AREA
```

**来源**：FS §8 PPA 指标和 §13 设计约束。

#### 2.8 时序例外

```tcl
#==============================================================================
# Timing Exceptions
#==============================================================================

#--- False Paths ---
# 异步复位（低有效异步复位同步释放）
set_false_path -from [get_ports rst_n]

# 异步时钟域间路径（如已用 set_clock_groups 则自动处理，此处显式声明备用）
#set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# 配置寄存器路径（静态配置，无需时序分析）
#set_false_path -from [get_pins cfg_reg*/Q]

#--- Multicycle Paths ---
# 示例：慢速采样路径
#set_multicycle_path -setup 4 -from [get_pins slow_reg/Q] -to [get_pins fast_reg/D]
#set_multicycle_path -hold  3 -from [get_pins slow_reg/Q] -to [get_pins fast_reg/D]
# 注意：hold = setup - 1

#--- Max/Min Delay ---
# 输入到输出直通路径（组合路径）
#set_max_delay [expr $CLK_PERIOD * 0.8] -from [get_ports data_in] -to [get_ports data_out]
```

**生成规则**：
- 异步复位 `rst_n` 必须设 `set_false_path`（异步复位同步释放架构）
- 从 FS §4.4 异常处理和 §5.3 状态机提取时序例外需求
- 从微架构 §5.4 流水线提取 multicycle path
- **multicycle path 必须同时设 setup 和 hold**，hold = setup - 1
- 每条 false path 必须有明确工程理由

#### 2.9 面积与功耗约束

```tcl
#==============================================================================
# Area & Power Constraints
#==============================================================================
#set_max_area $MAX_AREA
#set_max_dynamic_power 0 mW
```

---

### Phase 3：SDC 输出

1. 生成 SDC 文件：`{module}_work/ds/run/{module}.sdc`
2. 生成参数覆盖文件（可选）：`{module}_work/ds/run/{module}_sdc_params.tcl`
   - 用于多配置场景，仅包含参数定义，主 SDC `source` 此文件
3. 创建输出目录：`mkdir -p {module}_work/ds/run/`

### Phase 4：验证检查

按以下清单逐项检查生成的 SDC：

| # | 检查项 | 检查方法 | 来源 |
|---|--------|----------|------|
| 1 | 所有时钟端口已定义 `create_clock` | 与 FS §9 时钟表对比 | SDC Best Practices |
| 2 | PLL/分频器已定义 `create_generated_clock` | 与 FS §9 + 微架构 §7 对比 | SDC Best Practices |
| 3 | 异步时钟域已用 `set_clock_groups` 隔离 | 与 FS §9 CDC 对比 | SDC Best Practices |
| 4 | 所有非时钟输入已设 `set_input_delay` | 与 FS §6 端口列表对比 | SDC Best Practices |
| 5 | 所有输出已设 `set_output_delay` | 与 FS §6 端口列表对比 | SDC Best Practices |
| 6 | 复位路径已正确约束 | `set_false_path -from rst_n` | SDC Best Practices |
| 7 | multicycle path 同时设 setup 和 hold | grep 检查配对 | SDC Best Practices |
| 8 | 每条 false path 有明确理由 | 人工审查 | SDC Best Practices |
| 9 | 设计规则约束已设置 | fanout/transition/capacitance | SDC Best Practices |
| 10 | 时钟周期与 FS §8.1 一致 | 数值对比 | 质量检查 |

---

## 输出

| 文件 | 路径 | 说明 |
|------|------|------|
| SDC 文件 | `{module}_work/ds/run/{module}.sdc` | 完整 SDC 约束文件 |
| 参数文件 | `{module}_work/ds/run/{module}_sdc_params.tcl` | 参数覆盖文件（可选） |
| 验证报告 | `{module}_work/ds/report/sdc/sdc_check.md` | 约束覆盖检查报告 |

---

## SDC 命令速查表

| 类别 | 命令 | 用途 | 优先级 |
|------|------|------|--------|
| 时钟定义 | `create_clock` | 基本时钟 | 最高 |
| 时钟定义 | `create_generated_clock` | PLL/分频器 | 最高 |
| 时钟属性 | `set_clock_uncertainty` | jitter/skew 裕量 | 高 |
| 时钟属性 | `set_clock_latency` | 时钟延迟 | 高 |
| 时钟关系 | `set_clock_groups` | 异步/互斥 | 高 |
| I/O 约束 | `set_input_delay` | 输入时序 | 高 |
| I/O 约束 | `set_output_delay` | 输出时序 | 高 |
| I/O 约束 | `set_driving_cell` | 输入驱动强度 | 中 |
| I/O 约束 | `set_load` | 输出负载 | 中 |
| 设计规则 | `set_max_fanout` | 扇出限制 | 中 |
| 设计规则 | `set_max_transition` | transition 限制 | 中 |
| 设计规则 | `set_max_capacitance` | 电容限制 | 中 |
| 时序例外 | `set_false_path` | 无效路径 | 高 |
| 时序例外 | `set_multicycle_path` | 多周期路径 | 高 |
| 时序例外 | `set_max_delay` | 最大延迟 | 中 |
| 时序例外 | `set_min_delay` | 最小延迟 | 中 |
| 面积 | `set_max_area` | 面积约束 | 低 |
| 功耗 | `set_max_dynamic_power` | 功耗约束 | 低 |

---

## 使用示例

**示例 1**：
- 用户：「为 data_adpt 生成 SDC 约束文件」
- 行为：
  1. 读取 `data_adpt_work/ds/doc/fs/data_adpt_FS_v1.0.md`
  2. 提取 §9 时钟域（1 个主时钟 250MHz）、§6 接口（AXI4 Slave + APB）、§8 PPA（Fmax 250MHz, 面积 50kGates）
  3. 生成 `data_adpt.sdc`：参数化模板 + create_clock(250MHz) + set_input/output_delay + set_false_path(rst_n) + 设计规则
  4. 执行验证清单，输出 `sdc_check.md`

**示例 2**：
- 用户：「buf_mgr 有两个时钟域 clk_core 200MHz 和 clk_ddr 400MHz，生成 SDC」
- 行为：
  1. 读取 FS 文档
  2. 生成双时钟 SDC：2 个 create_clock + set_clock_groups -asynchronous
  3. I/O 约束按各时钟域分别设置
  4. 标注 CDC 路径需要额外处理（提示使用 chip-cdc-architect）

**示例 3**：
- 用户：「根据微架构关键路径分析，调整 SDC 约束」
- 行为：
  1. 读取微架构 §6 关键时序分析
  2. 识别关键路径（Tslack < 0.1ns）和宽松路径
  3. 对关键路径适当放松（multicycle）或过约束（更紧的 max_delay）
  4. 更新 SDC 文件并重新验证

---

## 常见陷阱提醒

| 陷阱 | 后果 | 本 Skill 防护 |
|------|------|--------------|
| multicycle 只设 setup | hold 检查位置错误 | Phase 2.8 模板强制配对 |
| false path 滥用 | 真实违例被隐藏 | Phase 4 验证清单 #8 |
| 忘记 create_generated_clock | PLL 输出路径无约束 | Phase 1 从 FS 自动提取 |
| I/O delay 用错参考时钟 | 时序分析基准错误 | Phase 2.6 按时钟域分组 |
| uncertainty 设为 0 | 忽略 jitter/skew | Phase 2.4 默认 5% |
| 过约束 | 面积/功耗浪费 | 经验参数默认值 |

---

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| FS 文档缺失 | `{module}_work/ds/doc/fs/` 为空 | 暂停，提示先完成 FS 编写 |
| 时钟信息不完整 | FS §9 无时钟频率 | 暂停，列出缺失项，提示补充 |
| 接口信息缺失 | FS §6 无端口列表 | 使用 RTL 端口提取（如可用），否则暂停 |
| 外部器件规格缺失 | 无 I/O delay 精确计算依据 | 使用经验值（周期 × 20%~60%），标注 `[IO-ESTIMATED]` |
| 多时钟域复杂 | ≥3 个时钟域 | 逐时钟域生成，标注 CDC 路径需 chip-cdc-architect 处理 |
| 微架构文档缺失 | 无法获取关键路径信息 | 仅生成基础 SDC，标注 `[SDC-BASIC]`，建议补充微架构后重新生成 |

---

## 检查点

**检查前**：
- 确认 FS 文档存在且包含 §6（接口）、§8（PPA）、§9（时钟复位）
- 确认时钟频率、I/O 端口列表已提取

**检查后**：
- 确认 SDC 时钟周期与 FS §8.1 一致
- 确认所有 FS §6 端口已约束（输入有 set_input_delay，输出有 set_output_delay）
- 确认同步复位/异步复位路径约束正确
- 确认 multicycle path setup/hold 配对完整
- 确认验证清单 10 项全部通过
- 确认 SDC 文件保存到 `{module}_work/ds/run/{module}.sdc`

---

## Gate

| 门禁 | 条件 | 阻断级别 |
|------|------|----------|
| FS 完整性 | FS §6/§8/§9 存在 | 阻断（无 FS 无法生成） |
| 时钟周期一致 | SDC CLK_PERIOD = FS §8.1 Fmax 倒数 | 阻断（不一致需修正） |
| 端口覆盖率 | 所有 FS §6 端口已约束 | 警告（缺失时标注） |

---

## Metrics

执行完成后记录到 `{module}_work/ds/report/metrics/sdc_gen.json`：
```json
{
  "stage_id": "sdc_gen",
  "duration_ms": 0,
  "iteration_count": 1,
  "clock_count": 0,
  "io_constraint_count": 0,
  "exception_count": 0,
  "validation_pass_count": 0,
  "validation_fail_count": 0
}
```

---

## CBB Ref

- SDC 规范：Synopsys SDC 2.2 Application Note
- SDC Best Practices：`wiki/concepts/SDC-Best-Practices.md`
- SDC Generation Methods：`wiki/concepts/SDC-Generation-Methods.md`
- SDC Research：`wiki/questions/Research SDC文件生成规则与方法.md`
