# 覆盖率分析

> **用途**：功能覆盖率、代码覆盖率、断言覆盖率分析参考
> **典型应用**：验证质量评估、验证收敛分析

---

## 概述

覆盖率是衡量验证质量的关键指标，用于评估设计被验证的程度。

### 覆盖率类型

| 类型 | 说明 | 目标 |
|------|------|------|
| 代码覆盖率 | 代码执行程度 | > 95% |
| 功能覆盖率 | 功能点覆盖 | > 95% |
| 断言覆盖率 | 断言触发程度 | > 90% |
| 翻转覆盖率 | 信号翻转 | > 90% |

---

## 代码覆盖率

### 代码覆盖率类型

```
代码覆盖率类型：
1. 行覆盖率
   - 代码行执行比例
   - 衡量代码执行程度

2. 分支覆盖率
   - if/else 分支覆盖
   - case 分支覆盖

3. 条件覆盖率
   - 条件表达式覆盖
   - 真值表覆盖

4. 状态机覆盖率
   - 状态覆盖
   - 转移覆盖

5. 表达式覆盖率
   - 表达式求值
   - 操作符覆盖
```

### VCS 覆盖率

```bash
# VCS 覆盖率收集
vcs -full64 -sverilog \
    -debug_access+all \
    -cm line+cond+fsm+tgl+branch \
    -cm_dir ./coverage \
    -f filelist.f \
    -o simv

# 运行仿真
./simv +UVM_TESTNAME=my_test \
       -cm line+cond+fsm+tgl+branch \
       -cm_dir ./coverage

# 生成报告
urg -dir ./coverage \
    -report coverage_report \
    -format both
```

### Xcelium 覆盖率

```bash
# Xcelium 覆盖率收集
xrun -64bit -sv -uvm \
     -coverage all \
     -covoverwrite \
     -covwork ./coverage

# 运行仿真
xrun -64bit -sv -uvm \
     +UVM_TESTNAME=my_test \
     -coverage all \
     -covwork ./coverage

# 生成报告
imc -exec merge_cov.tcl
```

### Questa 覆盖率

```bash
# Questa 覆盖率收集
vcover merge -out merged_coverage.ucdb \
     coverage1.ucdb coverage2.ucdb

# 生成报告
vcover report -html -output coverage_report \
     merged_coverage.ucdb
```

---

## 功能覆盖率

### 功能覆盖率定义

```systemverilog
// 功能覆盖率
class my_coverage extends uvm_subscriber #(my_transaction);
    `uvm_component_utils(my_coverage)

    my_transaction tx;

    // 覆盖组
    covergroup cg_transaction;
        // 数据覆盖点
        data: coverpoint tx.data {
            bins zero = {0};
            bins max = {8'hFF};
            bins small = {[1:127]};
            bins large = {[128:254]};
        }

        // 控制信号覆盖点
        valid: coverpoint tx.valid;
        ready: coverpoint tx.ready;

        // 交叉覆盖
        cross_data_valid: cross data, valid;
        cross_data_ready: cross data, ready;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_transaction = new();
    endfunction

    virtual function void write(my_transaction t);
        tx = t;
        cg_transaction.sample();
    endfunction

endclass
```

### 覆盖点定义

```systemverilog
// 覆盖点类型
covergroup cg_example;
    // 基本覆盖点
    basic: coverpoint tx.data;

    // 带 bins 的覆盖点
    with_bins: coverpoint tx.data {
        bins zero = {0};
        bins max = {8'hFF};
        bins others = default;
    }

    // 范围 bins
    range_bins: coverpoint tx.data {
        bins low = {[0:63]};
        bins mid = {[64:191]};
        bins high = {[192:255]};
    }

    // 过渡 bins
    transition_bins: coverpoint tx.state {
        bins idle_to_work = (0 => 1);
        bins work_to_done = (1 => 2);
        bins done_to_idle = (2 => 0);
    }

    // 忽略 bins
    ignore_bins: coverpoint tx.data {
        bins ignore = {8'hAA, 8'h55};
    }

    // 非法 bins
    illegal_bins: coverpoint tx.data {
        bins illegal = {8'hFF};
    }
endgroup
```

### 交叉覆盖

```systemverilog
// 交叉覆盖
covergroup cg_cross;
    data: coverpoint tx.data {
        bins zero = {0};
        bins max = {8'hFF};
        bins others = default;
    }

    mode: coverpoint tx.mode {
        bins read = {0};
        bins write = {1};
    }

    // 交叉覆盖
    cross_data_mode: cross data, mode;

    // 排除特定交叉
    cross_data_mode_excl: cross data, mode {
        ignore_bins ignore = binsof(data.zero) intersect {1};
    }
endgroup
```

---

## 断言覆盖率

### SVA 覆盖

```systemverilog
// SVA 覆盖
module sva_coverage;
    logic clk, rst_n, valid, ready, data;

    // 断言
    property p_valid_ready;
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> valid;
    endproperty

    property p_data_stable;
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> $stable(data);
    endproperty

    // 覆盖
    cover property (p_valid_ready);
    cover property (p_data_stable);

    // 覆盖组
    covergroup cg_assertion;
        coverpoint valid;
        coverpoint ready;
        cross valid, ready;
    endgroup

endmodule
```

### 断言覆盖率报告

```tcl
# VC Formal 断言覆盖率
report_covered_properties
report_uncovered_properties
report_coverage_percentage

# JasperGold 断言覆盖率
report -status
report -coverage
```

---

## 翻转覆盖率

### 翻转覆盖率定义

```systemverilog
// 翻转覆盖率
covergroup cg_toggle;
    // 信号翻转
    data_toggle: coverpoint tx.data {
        bins transition_0_1 = (0 => 1);
        bins transition_1_0 = (1 => 0);
    }

    // 多位翻转
    data_multi_toggle: coverpoint tx.data {
        bins transition_00_01 = (2'b00 => 2'b01);
        bins transition_01_10 = (2'b01 => 2'b10);
        bins transition_10_11 = (2'b10 => 2'b11);
        bins transition_11_00 = (2'b11 => 2'b00);
    }
endgroup
```

### 翻转覆盖率收集

```bash
# VCS 翻转覆盖率
vcs -full64 -sverilog \
    -cm tgl \
    -cm_dir ./coverage \
    -f filelist.f \
    -o simv

# Xcelium 翻转覆盖率
xrun -64bit -sv -uvm \
     -coverage toggle \
     -covwork ./coverage
```

---

## 覆盖率分析

### 覆盖率报告

```tcl
# VCS 覆盖率报告
urg -dir ./coverage \
    -report coverage_report \
    -format both

# Xcelium 覆盖率报告
imc -exec merge_cov.tcl

# Questa 覆盖率报告
vcover report -html -output coverage_report \
     merged_coverage.ucdb
```

### 覆盖率分析流程

```
覆盖率分析流程：
1. 收集覆盖率
   - 运行仿真
   - 收集覆盖率数据

2. 生成报告
   - 代码覆盖率报告
   - 功能覆盖率报告
   - 断言覆盖率报告

3. 分析报告
   - 识别未覆盖区域
   - 分析原因
   - 制定改进计划

4. 改进验证
   - 补充测试用例
   - 优化约束
   - 添加断言
```

### 覆盖率收敛

```
覆盖率收敛曲线：
┌─────────────────────────────────────────────┐
│  覆盖率                                      │
│  │                                          │
│  │  ╱───────────────────────                │
│  │  ╱                                      │
│  │  ╱                                       │
│  │  ╱                                        │
│  │╱                                          │
│  └──────────────────────────────────────────│
│                     验证时间                 │
└─────────────────────────────────────────────┘

收敛策略：
1. 增加测试用例
2. 优化约束随机
3. 添加定向测试
4. 补充断言
```

---

## 覆盖率驱动验证

### 覆盖率驱动验证流程

```
覆盖率驱动验证流程：
1. 定义覆盖率目标
   - 代码覆盖率 > 95%
   - 功能覆盖率 > 95%
   - 断言覆盖率 > 90%

2. 设计覆盖率模型
   - 功能覆盖点
   - 交叉覆盖
   - 边界条件

3. 运行验证
   - 约束随机测试
   - 定向测试
   - 回归测试

4. 分析覆盖率
   - 生成覆盖率报告
   - 识别未覆盖区域
   - 分析原因

5. 改进验证
   - 补充测试用例
   - 优化约束
   - 添加断言

6. 迭代直到满足目标
```

### 覆盖率驱动测试

```systemverilog
// 覆盖率驱动测试
class coverage_driven_test extends uvm_test;
    `uvm_component_utils(coverage_driven_test)

    my_env env;

    virtual task run_phase(uvm_phase phase);
        my_sequence seq;
        real coverage;

        phase.raise_objection(this);

        // 运行直到覆盖率满足
        forever begin
            seq = my_sequence::type_id::create("seq");
            seq.start(env.agent.sequencer);

            // 检查覆盖率
            coverage = env.coverage.cg_transaction.get_coverage();
            if (coverage >= 95.0) begin
                `uvm_info("TEST", $sformatf("Coverage reached: %0f%%", coverage), UVM_LOW)
                break;
            end
        end

        phase.drop_objection(this);
    endtask

endclass
```

---

## 覆盖率最佳实践

### 覆盖率模型设计

```
覆盖率模型设计最佳实践：
1. 功能覆盖点
   - 覆盖所有功能点
   - 覆盖边界条件
   - 覆盖异常场景

2. 交叉覆盖
   - 覆盖信号组合
   - 覆盖状态组合
   - 覆盖模式组合

3. 过渡覆盖
   - 覆盖状态转移
   - 覆盖模式切换
   - 覆盖信号变化

4. 忽略和非法
   - 忽略无效组合
   - 标记非法状态
   - 减少噪声
```

### 覆盖率分析

```
覆盖率分析最佳实践：
1. 定期分析
   - 每轮回归后分析
   - 里程碑节点分析
   - 签核前分析

2. 深入分析
   - 分析未覆盖原因
   - 分析覆盖率趋势
   - 分析覆盖率分布

3. 改进行动
   - 补充测试用例
   - 优化约束
   - 添加断言
   - 调整策略

4. 文档记录
   - 记录覆盖率目标
   - 记录覆盖率结果
   - 记录改进措施
```

### 常见问题

```
常见覆盖率问题：
1. 覆盖率低
   - 测试用例不足
   - 约束过于严格
   - 设计复杂度高

2. 覆盖率不收敛
   - 未覆盖区域难以到达
   - 需要特殊条件
   - 需要定向测试

3. 覆盖率假高
   - 覆盖点定义不准确
   - 忽略重要场景
   - 需要细化覆盖点

4. 覆盖率分析困难
   - 报告格式不友好
   - 缺乏可视化工具
   - 需要改进工具
```

---

## 覆盖率工具

### 覆盖率收集工具

| 工具 | 供应商 | 特点 |
|------|--------|------|
| VCS | Synopsys | 快速、广泛使用 |
| Xcelium | Cadence | 多核仿真 |
| Questa | Siemens | UVM 支持好 |

### 覆盖率分析工具

| 工具 | 供应商 | 特点 |
|------|--------|------|
| URG | Synopsys | 覆盖率报告生成 |
| IMC | Cadence | 覆盖率分析 |
| Vcover | Siemens | 覆盖率合并分析 |

### 覆盖率可视化

```
覆盖率可视化：
1. 代码覆盖率
   - 源码标注
   - 行覆盖率
   - 分支覆盖率

2. 功能覆盖率
   - 覆盖点分布
   - 交叉覆盖矩阵
   - 过渡覆盖图

3. 断言覆盖率
   - 断言状态
   - 触发统计
   - 时间分布
```

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys VCS Coverage User Guide | VCS 覆盖率 |
| REF-002 | Cadence Xcelium Coverage User Guide | Xcelium 覆盖率 |
| REF-003 | Siemens Questa Coverage User Guide | Questa 覆盖率 |
| REF-004 | UVM User Guide | UVM 框架 |
| REF-005 | IEEE 1800-2017 | SystemVerilog 标准 |
