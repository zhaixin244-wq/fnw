# 签核验证

> **用途**：芯片签核验证流程参考，供最终设计签核时检索
> **典型应用**：所有芯片签核验证

---

## 概述

签核验证是芯片流片前的最终检查，确保设计满足所有要求。

### 签核验证内容

| 验证类型 | 工具 | 检查内容 |
|----------|------|----------|
| STA | PrimeTime/Tempus | 时序检查 |
| DRC | Calibre | 设计规则检查 |
| LVS | Calibre | 版图与原理图一致性 |
| ERC | Calibre | 电气规则检查 |
| Antenna | Calibre | 天线效应检查 |
| IR Drop | RedHawk | 电压降分析 |
| EM | RedHawk | 电迁移分析 |

---

## 静态时序分析（STA）

### STA 概念

```
时序路径：
    ┌─────────┐     ┌─────────┐     ┌─────────┐
    │  Launch │     │  Logic  │     │ Capture │
    │  FF     │────→│  Cone   │────→│  FF     │
    └─────────┘     └─────────┘     └─────────┘
         │                               │
         └─────────────┬─────────────────┘
                       │
                  时钟路径
```

### 时序检查

| 检查类型 | 公式 | 说明 |
|----------|------|------|
| Setup | Tclk - Tck2q - Tlogic - Tsetup > 0 | 数据到达时间 |
| Hold | Tck2q + Tlogic - Thold > 0 | 数据保持时间 |

### Setup 时间检查

```
Setup 裕量 = Tclk - Tck2q - Tlogic - Tsetup - Tskew

其中：
- Tclk: 时钟周期
- Tck2q: 时钟到 Q 延迟
- Tlogic: 逻辑延迟
- Tsetup: 建立时间
- Tskew: 时钟偏移
```

### Hold 时间检查

```
Hold 裕量 = Tck2q + Tlogic - Thold - Tskew

其中：
- Tck2q: 时钟到 Q 延迟
- Tlogic: 逻辑延迟
- Thold: 保持时间
- Tskew: 时钟偏移
```

### STA 约束

```tcl
# 时钟定义
create_clock -name clk -period 1.0 [get_ports clk]
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]
set_clock_latency -source 0.5 [get_clocks clk]

# 输入延迟
set_input_delay -clock clk -max 0.5 [get_ports data_in]
set_input_delay -clock clk -min 0.1 [get_ports data_in]

# 输出延迟
set_output_delay -clock clk -max 0.5 [get_ports data_out]
set_output_delay -clock clk -min 0.1 [get_ports data_out]

# 伪路径
set_false_path -from [get_ports rst_n]
set_false_path -from [list clk1] -to [list clk2]

# 多周期路径
set_multicycle_path 2 -setup -from [get_pins reg1/Q] -to [get_pins reg2/D]
set_multicycle_path 1 -hold -from [get_pins reg1/Q] -to [get_pins reg2/D]
```

### STA 报告

```tcl
# 时序报告
report_timing -delay_type max -max_paths 10 > setup.rpt
report_timing -delay_type min -max_paths 10 > hold.rpt

# 时钟报告
report_clocks > clocks.rpt
report_clock_network > clock_network.rpt

# 违规报告
report_constraint -all_violators > violations.rpt
```

---

## OCV（片上变化）

### OCV 概念

- **工艺变化**：制造工艺偏差
- **电压变化**：供电电压波动
- **温度变化**：工作温度变化

### OCV 建模

```
OCV 因子：
- 早期（Late）：1.0 - α
- 晚期（Early）：1.0 + α

示例：
- α = 0.05
- 早期因子：0.95
- 晚期因子：1.05
```

### OCV 约束

```tcl
# AOCV（高级 OCV）
set_aocvm_coefficient -cell 0.05 -net 0.03

# SOCV（统计 OCV）
set_pocvm_coefficient -cell 0.05 -net 0.03

# OCV 表
set_timing_derate -late 1.05 -cell_delay
set_timing_derate -early 0.95 -cell_delay
set_timing_derate -late 1.03 -net_delay
set_timing_derate -early 0.97 -net_delay
```

---

## 信号完整性（SI）

### SI 概念

- **串扰**：相邻信号干扰
- **噪声**：电源/地噪声
- **反射**：阻抗不匹配

### 串扰分析

```
串扰影响：
1. 功能错误：逻辑状态翻转
2. 时序影响：延迟增加/减少
3. 毛刺：产生意外脉冲
```

### SI 约束

```tcl
# 串扰分析
set_si_aggressor_limit -max 0.2
set_si_noise_limit -max 0.1

# 串扰报告
report_noise > noise.rpt
report_si_aggressor > aggressor.rpt
```

---

## DRC（设计规则检查）

### DRC 检查内容

| 规则类型 | 说明 | 示例 |
|----------|------|------|
| 宽度规则 | 最小线宽 | M1: 0.02μm |
| 间距规则 | 最小间距 | M1: 0.02μm |
| 面积规则 | 最小面积 | Via: 0.01μm² |
| 密度规则 | 金属密度 | 20%-80% |
| 天线规则 | 天线比率 | < 100 |

### DRC 流程

```
物理版图
    ↓
DRC 工具（Calibre）
    ↓
DRC 违规报告
    ↓
修复违规
    ↓
DRC Clean
```

### DRC 报告

```
DRC 违规示例：
- M1.Width < 0.02μm
- M1.Space < 0.02μm
- Via1.Area < 0.01μm²
- M1.Density < 20%
```

---

## LVS（版图与原理图一致性）

### LVS 检查内容

| 检查类型 | 说明 |
|----------|------|
| 器件匹配 | 器件类型和数量 |
| 连接匹配 | 连接关系 |
| 参数匹配 | 器件参数 |
| 电源/地匹配 | 电源/地连接 |

### LVS 流程

```
物理版图 + 门级网表
    ↓
LVS 工具（Calibre）
    ↓
LVS 报告
    ↓
修复不匹配
    ↓
LVS Clean
```

### LVS 报告

```
LVS 不匹配示例：
- 器件不匹配：缺少 MOS 管
- 连接不匹配：短路/开路
- 参数不匹配：W/L 不同
```

---

## IR Drop 分析

### IR Drop 概念

- **静态 IR Drop**：平均电流引起的电压降
- **动态 IR Drop**：瞬态电流引起的电压降

### IR Drop 分析流程

```
物理版图 + 门级网表 + 仿真波形
    ↓
IR Drop 工具（RedHawk）
    ↓
IR Drop 热图
    ↓
修复违规
    ↓
IR Drop 满足
```

### IR Drop 目标

| 类型 | 目标 | 说明 |
|------|------|------|
| 静态 IR Drop | < 5% | 平均电压降 |
| 动态 IR Drop | < 10% | 峰值电压降 |

### IR Drop 优化

1. **增加电源条带**：减小电源网络电阻
2. **增加去耦电容**：减小动态电压降
3. **分散高功耗单元**：减小局部电流密度
4. **优化电源网络**：改善电源分布

---

## EM（电迁移）分析

### EM 概念

- **定义**：高电流密度导致金属原子迁移
- **影响**：开路/短路故障
- **寿命**：芯片可靠性

### EM 分析流程

```
物理版图 + 电流数据
    ↓
EM 工具（RedHawk）
    ↓
EM 报告
    ↓
修复违规
    ↓
EM 满足
```

### EM 目标

| 类型 | 目标 | 说明 |
|------|------|------|
| DC EM | < 10 years | 直流电流寿命 |
| AC EM | < 10 years | 交流电流寿命 |

### EM 优化

1. **增加线宽**：减小电流密度
2. **增加通孔**：减小通孔电流密度
3. **优化布线**：分散电流路径
4. **增加金属层**：提供更多电流路径

---

## 天线效应检查

### 天线效应概念

- **定义**：制造过程中积累电荷
- **影响**：栅氧化层击穿
- **防护**：天线二极管

### 天线规则

```
天线比率 = 金属面积 / 栅面积

目标：天线比率 < 100
```

### 天线效应修复

1. **插入天线二极管**：提供放电路径
2. **跳线**：跳到更高金属层
3. **增加缓冲器**：减小金属面积

---

## 签核检查清单

### 时序签核

- [ ] Setup 时间满足（所有角）
- [ ] Hold 时间满足（所有角）
- [ ] 时钟偏移 < 目标
- [ ] 时钟抖动 < 目标
- [ ] 无时序违规

### 物理签核

- [ ] DRC Clean
- [ ] LVS Clean
- [ ] ERC Clean
- [ ] Antenna 满足
- [ ] Density 满足

### 功耗签核

- [ ] 静态 IR Drop < 5%
- [ ] 动态 IR Drop < 10%
- [ ] EM 满足
- [ ] 功耗 < 预算

### 功能签核

- [ ] 门级仿真通过
- [ ] 形式验证通过
- [ ] 功能覆盖率 > 95%

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys PrimeTime User Guide | STA 工具 |
| REF-002 | Siemens Calibre User Guide | 物理验证工具 |
| REF-003 | Ansys RedHawk User Guide | IR Drop/EM 分析 |
| REF-004 | Cadence Tempus User Guide | STA 工具 |
