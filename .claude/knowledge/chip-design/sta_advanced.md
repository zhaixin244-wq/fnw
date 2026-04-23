# 静态时序分析（STA）高级

> **用途**：静态时序分析高级概念参考，供复杂时序设计时检索
> **典型应用**：高性能芯片时序分析

---

## 概述

本节介绍 STA 的高级概念，包括 OCV、SI、高级时序优化等。

---

## AOCV（高级片上变化）

### AOCV 概念

AOCV 考虑路径深度和距离对时序变化的影响。

### AOCV 模型

```
AOCV 系数 = f(路径深度, 距离)

其中：
- 路径深度：逻辑级数
- 距离：物理距离

示例：
- 路径深度 1：系数 = 1.0
- 路径深度 5：系数 = 0.95
- 路径深度 10：系数 = 0.90
```

### AOCV 约束

```tcl
# AOCV 系数设置
set_aocvm_coefficient -cell 0.05 -net 0.03

# AOCV 表
set_aocvm_table -cell {1 0.05 5 0.03 10 0.02}
set_aocvm_table -net {1 0.03 5 0.02 10 0.01}
```

### AOCV 分析

```tcl
# AOCV 分析
set_timing_analysis_mode -aocvm true

# AOCV 报告
report_timing -aocvm > aocvm_timing.rpt
```

---

## SOCV（统计片上变化）

### SOCV 概念

SOCV 使用统计方法分析时序变化。

### SOCV 模型

```
SOCV 概率分布：
- 均值：标称延迟
- 标准差：变化范围

统计裕量：
- 3σ：99.7% 覆盖率
- 4σ：99.99% 覆盖率
```

### SOCV 约束

```tcl
# SOCV 系数设置
set_pocvm_coefficient -cell 0.05 -net 0.03

# SOCV 分析模式
set_timing_analysis_mode -socvm true
```

### SOCV 报告

```tcl
# SOCV 时序报告
report_timing -socvm > socvm_timing.rpt

# SOCV 统计报告
report_timing -format {startpoint endpoint delay mean sigma} > socvm_stats.rpt
```

---

## 信号完整性（SI）

### 串扰分析

```
串扰模型：
┌─────────────────────────────────────────────┐
│  Aggressor 1                                │
│  ───────────────────────────────            │
│                    │ 耦合电容               │
│  ───────────────────────────────            │
│  Victim                                     │
│  ───────────────────────────────            │
│                    │ 耦合电容               │
│  ───────────────────────────────            │
│  Aggressor 2                                │
└─────────────────────────────────────────────┘
```

### 串扰影响

| 影响类型 | 说明 | 后果 |
|----------|------|------|
| 功能错误 | 逻辑状态翻转 | 功能失效 |
| 时序影响 | 延迟增加/减少 | 时序违规 |
| 毛刺 | 产生意外脉冲 | 功能错误 |

### SI 分析流程

```tcl
# SI 设置
set_si_aggressor_limit -max 0.2
set_si_noise_limit -max 0.1

# SI 分析
set_si_analysis_mode -enable true

# SI 报告
report_si_noise > noise.rpt
report_si_aggressor > aggressor.rpt
report_si_delay > delay.rpt
```

### SI 优化

1. **增加间距**：减小耦合电容
2. **插入缓冲器**：减小串扰影响
3. **使用屏蔽线**：隔离敏感信号
4. **优化布线**：避免平行长距离布线

---

## 时钟树分析

### 时钟树质量指标

| 指标 | 定义 | 目标 |
|------|------|------|
| 偏移（Skew） | 最大-最小时钟到达时间 | < 100 ps |
| 抖动（Jitter） | 时钟周期变化 | < 50 ps |
| 转换时间 | 时钟信号转换时间 | < 200 ps |
| 功耗 | 时钟树功耗 | < 预算 |

### 时钟树报告

```tcl
# 时钟树报告
report_clock_network > clock_network.rpt

# 时钟偏移报告
report_clock_skew > clock_skew.rpt

# 时钟抖动报告
report_clock_jitter > clock_jitter.rpt
```

### 时钟树优化

1. **平衡树结构**：使用 H 树或鱼骨树
2. **插入缓冲器**：平衡时钟负载
3. **调整布局**：优化时钟路径
4. **使用专用时钟缓冲器**：减小时钟抖动

---

## 多角分析

### 多角概念

多角分析考虑不同工艺、电压、温度（PVT）条件下的时序。

### PVT 角

| 角 | 工艺 | 电压 | 温度 | 用途 |
|----|------|------|------|------|
| SS | 慢 | 低 | 高 | Setup 检查 |
| FF | 快 | 高 | 低 | Hold 检查 |
| TT | 标称 | 标称 | 标称 | 典型分析 |
| SF | 慢 | 快 | 标称 | 混合分析 |
| FS | 快 | 慢 | 标称 | 混合分析 |

### 多角约束

```tcl
# 多角设置
set_operating_conditions -min ff_1.1v_m40c -max ss_0.9v_125c

# 多角时序
set_timing_derate -late 1.05 -cell_delay
set_timing_derate -early 0.95 -cell_delay
```

### 多角报告

```tcl
# 多角时序报告
report_timing -delay_type max -nworst 5 > setup_multi.rpt
report_timing -delay_type min -nworst 5 > hold_multi.rpt

# 多角违规报告
report_constraint -all_violators > violations_multi.rpt
```

---

## 时序优化技术

### 逻辑优化

| 技术 | 说明 | 应用 |
|------|------|------|
| 重定时 | 移动寄存器位置 | 平衡路径延迟 |
| 逻辑复制 | 复制关键路径逻辑 | 减少扇出延迟 |
| 引脚交换 | 优化引脚连接 | 改善时序 |
| 逻辑重构 | 重构逻辑结构 | 优化关键路径 |

### 物理优化

| 技术 | 说明 | 应用 |
|------|------|------|
| 单元替换 | 替换为更快的单元 | 修复时序 |
| 缓冲器插入 | 插入缓冲器 | 修复时序 |
| 重布线 | 使用更快的布线层 | 修复时序 |
| 布局调整 | 移动关键单元 | 修复时序 |

### 时钟优化

| 技术 | 说明 | 应用 |
|------|------|------|
| 时钟偏移优化 | 减小时钟偏移 | 改善时序裕量 |
| 时钟树重构 | 重构时钟树 | 改善时钟质量 |
| 时钟门控优化 | 优化时钟门控 | 降低功耗 |

---

## 高级时序约束

### 跨时钟域约束

```tcl
# 跨时钟域路径
set_clock_groups -asynchronous -group [list clk1] -group [list clk2]

# 跨时钟域伪路径
set_false_path -from [get_clocks clk1] -to [get_clocks clk2]

# 跨时钟域多周期路径
set_multicycle_path 2 -setup -from [get_clocks clk1] -to [get_clocks clk2]
set_multicycle_path 1 -hold -from [get_clocks clk1] -to [get_clocks clk2]
```

### 复杂路径约束

```tcl
# 最大延迟约束
set_max_delay 2.0 -from [get_pins reg1/Q] -to [get_pins reg2/D]

# 最小延迟约束
set_min_delay 0.5 -from [get_pins reg1/Q] -to [get_pins reg2/D]

# 最大扇出约束
set_max_fanout 20 [get_cells u1]

# 最大转换时间约束
set_max_transition 0.2 [get_cells u1]
```

### 接口约束

```tcl
# 输入端口约束
set_input_delay -clock clk -max 0.5 [get_ports data_in]
set_input_delay -clock clk -min 0.1 [get_ports data_in]
set_input_transition 0.1 [get_ports data_in]

# 输出端口约束
set_output_delay -clock clk -max 0.5 [get_ports data_out]
set_output_delay -clock clk -min 0.1 [get_ports data_out]
set_load 0.1 [get_ports data_out]
```

---

## STA 调试技巧

### 时序违规调试

```tcl
# 查看违规路径
report_timing -delay_type max -max_paths 100 > setup_violations.rpt

# 查看关键路径
report_timing -delay_type max -nworst 10 > critical_paths.rpt

# 查看特定路径
report_timing -from [get_pins reg1/Q] -to [get_pins reg2/D] > specific_path.rpt
```

### 时钟问题调试

```tcl
# 查看时钟定义
report_clocks > clocks.rpt

# 查看时钟网络
report_clock_network > clock_network.rpt

# 查看时钟偏移
report_clock_skew > clock_skew.rpt
```

### 约束问题调试

```tcl
# 查看所有约束
report_sdc > sdc.rpt

# 查看违规约束
report_constraint -all_violators > constraint_violations.rpt

# 查看伪路径
report_false_path > false_path.rpt
```

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys PrimeTime User Guide | STA 工具 |
| REF-002 | Cadence Tempus User Guide | STA 工具 |
| REF-003 | Advanced STA Concepts | 高级时序分析概念 |
