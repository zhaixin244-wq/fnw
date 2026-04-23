# 形式验证基础

> **用途**：形式验证基础概念、等价性检查、属性检查参考
> **典型应用**：RTL 验证、门级验证、协议验证

---

## 概述

形式验证使用数学方法证明设计正确性，无需运行测试用例。

### 形式验证类型

| 类型 | 说明 | 应用 |
|------|------|------|
| 等价性检查 | 比较两个设计 | RTL vs 门级 |
| 属性检查 | 验证属性 | 功能验证 |
| 模型检查 | 穷举状态空间 | 协议验证 |

---

## 等价性检查

### 等价性检查流程

```
等价性检查流程：
┌─────────────────────────────────────────────┐
│  参考设计 (RTL)                              │
│  ┌─────────────────────────────────────┐    │
│  │  RTL 源码                           │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  综合工具                            │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  门级网表                            │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  等价性检查工具                      │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  等价/不等价                         │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### Synopsys Formality

```tcl
# Formality 等价性检查
# 设置参考设计
read_verilog -r ref_design.v
set_top ref_design

# 设置实现设计
read_verilog -i imp_design.v
set_top imp_design

# 匹配点
match

# 验证
verify

# 报告
report_failing_points
report_aborted_points
```

### Cadence Conformal

```tcl
# Conformal 等价性检查
# 加载设计
load_design -reference ref_design.v -golden
load_design -implementation imp_design.v -revised

# 设置顶层
set_top ref_design -golden
set_top imp_design -revised

# 匹配
match

# 验证
verify

# 报告
report_failing_points
report_aborted_points
```

### 等价性检查问题

```
常见等价性检查问题：
1. 不匹配点
   - 寄存器不匹配
   - 组合逻辑不匹配
   - 接口不匹配

2. 未匹配点
   - 多余逻辑
   - 缺失逻辑
   - 重命名信号

3. 验证失败
   - 逻辑错误
   - 时序问题
   - 优化错误
```

---

## 属性检查

### SVA 属性

```systemverilog
// 基本属性
property p_valid_ready;
    @(posedge clk) disable iff (!rst_n)
    (valid && !ready) |=> valid;
endproperty

// 序列属性
property p_sequence;
    @(posedge clk) disable iff (!rst_n)
    req |-> ##[1:5] gnt;
endproperty

// 数据属性
property p_data_range;
    @(posedge clk) disable iff (!rst_n)
    valid |-> (data inside {[0:255]});
endproperty

// 互斥属性
property p_mutex;
    @(posedge clk) disable iff (!rst_n)
    !(req_a && req_b);
endproperty
```

### SVA 序列

```systemverilog
// 基本序列
sequence s_req_gnt;
    req ##[1:5] gnt;
endsequence

// 重复序列
sequence s_repeat;
    req ##1 req ##1 req;
endsequence

// 交叠序列
sequence s_overlap;
    req [*3];
endsequence

// 非交叠序列
sequence s_non_overlap;
    req [->3];
endsequence
```

### SVA 断言

```systemverilog
// 断言
assert property (p_valid_ready);
assert property (p_sequence);
assert property (p_data_range);

// 覆盖
cover property (p_valid_ready);
cover property (p_sequence);

// 假设
assume property (p_valid_ready);
assume property (p_sequence);
```

---

## 形式验证工具

### Synopsys VC Formal

```tcl
# VC Formal 属性检查
# 加载设计
read_verilog design.v
set_top design

# 加载属性
read_sva design.sva

# 运行验证
verify

# 报告
report_results
report_covered_properties
report_uncovered_properties
```

### Cadence JasperGold

```tcl
# JasperGold 属性检查
# 加载设计
analyze -format sverilog design.sv
elaborate design

# 加载属性
source properties.tcl

# 运行验证
prove

# 报告
report
report -status
report -vacuity
```

### 形式验证策略

```
形式验证策略：
1. 属性驱动验证
   - 从规格提取属性
   - 编写 SVA 断言
   - 运行形式验证

2. 覆盖率驱动验证
   - 定义覆盖点
   - 运行覆盖分析
   - 补充未覆盖属性

3. 迭代验证
   - 运行验证
   - 分析失败原因
   - 修复设计或属性
```

---

## 形式验证流程

### 基本流程

```
形式验证流程：
┌─────────────────────────────────────────────┐
│  设计导入                                    │
│  ┌─────────────────────────────────────┐    │
│  │  RTL/门级设计                        │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  属性定义                            │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  形式验证引擎                        │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│         ┌───────────┼───────────┐           │
│         ▼           ▼           ▼           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ 通过     │ │ 反例     │ │ 未知     │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────────────────────────────────────┘
```

### 验证结果

```
验证结果类型：
1. 通过 (Pass)
   - 属性在所有状态下成立
   - 设计满足属性

2. 反例 (Counterexample)
   - 存在状态使属性不成立
   - 提供反例轨迹

3. 未知 (Unknown)
   - 状态空间过大
   - 需要更长时间或更多资源

4. 中止 (Aborted)
   - 内存不足
   - 时间超限
   - 设计问题
```

---

## 形式验证最佳实践

### 属性编写

```systemverilog
// 好的属性：具体、可验证
property p_req_gnt;
    @(posedge clk) disable iff (!rst_n)
    req |-> ##[1:5] gnt;
endproperty

// 不好的属性：模糊、不可验证
property p_bad;
    @(posedge clk)
    req |-> gnt;  // 何时 gnt？
endproperty

// 好的属性：覆盖边界条件
property p_boundary;
    @(posedge clk) disable iff (!rst_n)
    (cnt == 8'hFF) |=> (cnt == 8'h00);
endproperty

// 好的属性：检查互斥
property p_mutex;
    @(posedge clk) disable iff (!rst_n)
    !(req_a && req_b);
endproperty
```

### 验证策略

```
验证策略：
1. 渐进验证
   - 从简单属性开始
   - 逐步增加复杂度
   - 验证核心功能

2. 分层验证
   - 模块级验证
   - 系统级验证
   - 协议级验证

3. 覆盖率驱动
   - 定义覆盖点
   - 分析未覆盖区域
   - 补充属性

4. 迭代优化
   - 分析失败原因
   - 优化属性
   - 优化设计
```

### 调试技巧

```
调试技巧：
1. 反例分析
   - 查看反例轨迹
   - 定位问题时间点
   - 分析信号行为

2. 属性调试
   - 简化属性
   - 分步验证
   - 添加中间检查

3. 设计调试
   - 检查时钟复位
   - 验证接口协议
   - 分析状态机
```

---

## 形式验证覆盖率

### 覆盖率类型

```
覆盖率类型：
1. 属性覆盖率
   - 通过属性数/总属性数
   - 衡量验证完整性

2. 状态覆盖率
   - 访问状态数/总状态数
   - 衡量状态空间探索

3. 转移覆盖率
   - 访问转移数/总转移数
   - 衡量状态机覆盖
```

### 覆盖率分析

```tcl
# VC Formal 覆盖率分析
report_covered_properties
report_uncovered_properties
report_coverage_percentage

# JasperGold 覆盖率分析
report -status
report -coverage
```

### 覆盖率改进

```
覆盖率改进：
1. 补充属性
   - 添加未覆盖功能
   - 添加边界条件
   - 添加异常场景

2. 优化属性
   - 简化复杂属性
   - 分解长序列
   - 添加辅助属性

3. 调整策略
   - 增加验证时间
   - 使用更强大引擎
   - 分割设计
```

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys VC Formal User Guide | 形式验证工具 |
| REF-002 | Cadence JasperGold User Guide | 形式验证工具 |
| REF-003 | Synopsys Formality User Guide | 等价性检查 |
| REF-004 | Cadence Conformal User Guide | 等价性检查 |
| REF-005 | IEEE 1800-2017 | SystemVerilog 标准 |
