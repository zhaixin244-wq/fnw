# 形式验证高级

> **用途**：形式验证高级技术、模型检查、断言验证参考
> **典型应用**：复杂协议验证、状态空间验证、性能验证

---

## 概述

本节介绍形式验证的高级技术，包括模型检查、抽象、收敛策略等。

---

## 模型检查

### 模型检查原理

```
模型检查原理：
┌─────────────────────────────────────────────┐
│  系统模型                                    │
│  ┌─────────────────────────────────────┐    │
│  │  状态空间                            │    │
│  │  - 状态集合                          │    │
│  │  - 转移关系                          │    │
│  │  - 初始状态                          │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  性质 (CTL/LTL)                     │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  模型检查算法                        │    │
│  │  - 穷举搜索                          │    │
│  │  - 符号模型检查                      │    │
│  │  - 有界模型检查                      │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│         ┌───────────┼───────────┐           │
│         ▼           ▼           ▼           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ 满足     │ │ 不满足   │ │ 不确定   │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────────────────────────────────────┘
```

### CTL 时序逻辑

```systemverilog
// CTL 属性
// 路径量词：
// A - 所有路径
// E - 存在路径

// 时态算子：
// G - 全局 (Globally)
// F - 最终 (Finally)
// X - 下一个 (Next)
// U - 直到 (Until)

// CTL 属性示例：
// AG(req -> AF gnt) - 所有路径，最终都会得到授权
// AG(req -> A[req U gnt]) - 请求后一直保持直到授权
// EF(deadlock) - 存在死锁路径
```

### LTL 时序逻辑

```systemverilog
// LTL 属性
// 时态算子：
// G - 全局
// F - 最终
// X - 下一个
// U - 直到
// R - 释放 (Release)

// LTL 属性示例：
// G(req -> F gnt) - 请求最终得到授权
// G(req -> (req U gnt)) - 请求后保持直到授权
// F(error) - 最终会发生错误
```

---

## 状态空间抽象

### 抽象技术

```
抽象技术：
1. 数据抽象
   - 位宽缩减
   - 值域缩减
   - 符号抽象

2. 控制抽象
   - 状态合并
   - 路径合并
   - 循环抽象

3. 接口抽象
   - 接口简化
   - 协议抽象
   - 环境抽象
```

### 位宽抽象

```systemverilog
// 原始设计
module counter_original (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    output reg  [31:0] count
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 32'b0;
        else if (en)
            count <= count + 1;
    end
endmodule

// 抽象设计（4位）
module counter_abstract (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    output reg  [3:0] count
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 4'b0;
        else if (en)
            count <= count + 1;
    end
endmodule
```

### 值域抽象

```systemverilog
// 原始设计
module mux_original (
    input  wire [7:0] sel,
    input  wire [255:0] data,
    output wire [7:0] out
);
    assign out = data[sel*8 +: 8];
endmodule

// 抽象设计（2选1）
module mux_abstract (
    input  wire [0:0] sel,
    input  wire [15:0] data,
    output wire [7:0] out
);
    assign out = sel ? data[15:8] : data[7:0];
endmodule
```

---

## 收敛策略

### 收敛问题

```
收敛问题：
1. 状态空间爆炸
   - 状态数指数增长
   - 内存不足
   - 时间超限

2. 未证明属性
   - 属性过于复杂
   - 需要更强抽象
   - 需要辅助属性

3. 误报 (False Negative)
   - 抽象过度
   - 需要细化抽象
```

### 收敛策略

```
收敛策略：
1. 增强抽象
   - 粒度更粗
   - 合并更多状态
   - 减少状态空间

2. 分割验证
   - 分割设计
   - 分割属性
   - 分步验证

3. 辅助属性
   - 添加中间断言
   - 添加不变量
   - 添加约束

4. 引擎选择
   - 符号模型检查
   - 有界模型检查
   - 随机仿真
```

### 辅助属性

```systemverilog
// 辅助属性示例
// 原始属性
assert property (p_complex);

// 辅助属性
property p_helper1;
    @(posedge clk) disable iff (!rst_n)
    state == S_IDLE |-> !busy;
endproperty

property p_helper2;
    @(posedge clk) disable iff (!rst_n)
    busy |-> (count > 0);
endproperty

// 使用辅助属性
assert property (p_helper1);
assert property (p_helper2);
assert property (p_complex);
```

---

## 形式验证高级应用

### 协议验证

```systemverilog
// AXI 协议验证
property p_axi_valid_stable;
    @(posedge clk) disable iff (!rst_n)
    (axvalid && !axready) |=> axvalid;
endproperty

property p_axi_addr_stable;
    @(posedge clk) disable iff (!rst_n)
    (axvalid && !axready) |=> $stable(axaddr);
endproperty

property p_axi_handshake;
    @(posedge clk) disable iff (!rst_n)
    axvalid |-> ##[0:10] axready;
endproperty
```

### 状态机验证

```systemverilog
// 状态机验证
property p_fsm_reachable;
    @(posedge clk) disable iff (!rst_n)
    EF(state == S_DONE);
endproperty

property p_fsm_no_deadlock;
    @(posedge clk) disable iff (!rst_n)
    AG(EF(state == S_IDLE));
endproperty

property p_fsm_liveness;
    @(posedge clk) disable iff (!rst_n)
    AG(start -> AF(done));
endproperty
```

### 安全性验证

```systemverilog
// 安全性验证
property p_no_overflow;
    @(posedge clk) disable iff (!rst_n)
    (count < 8'hFF) |=> (count != 8'h00);
endproperty

property p_no_underflow;
    @(posedge clk) disable iff (!rst_n)
    (count > 8'h00) |=> (count != 8'hFF);
endproperty

property p_no_deadlock;
    @(posedge clk) disable iff (!rst_n)
    AG(!deadlock);
endproperty
```

---

## 形式验证调试

### 反例分析

```
反例分析流程：
1. 获取反例
   - 形式验证工具提供反例轨迹
   - 包含状态序列和信号值

2. 分析轨迹
   - 定位违反时间点
   - 分析信号行为
   - 追踪问题根源

3. 定位问题
   - 设计错误
   - 属性错误
   - 约束错误

4. 修复问题
   - 修复设计
   - 修复属性
   - 添加约束
```

### 反例调试

```tcl
# VC Formal 反例调试
report_failing_properties
report_counterexample -property p_name

# JasperGold 反例调试
report -counterexample
report -trace -property p_name
```

### 属性调试

```systemverilog
// 属性调试技巧
// 1. 简化属性
property p_simple;
    @(posedge clk) disable iff (!rst_n)
    req |-> gnt;  // 简化版本
endproperty

// 2. 添加中间检查
property p_debug;
    @(posedge clk) disable iff (!rst_n)
    req |-> ##1 (state == S_REQ) ##[1:5] gnt;
endproperty

// 3. 分步验证
property p_step1;
    @(posedge clk) disable iff (!rst_n)
    req |-> ##1 (state == S_REQ);
endproperty

property p_step2;
    @(posedge clk) disable iff (!rst_n)
    (state == S_REQ) |-> ##[1:5] gnt;
endproperty
```

---

## 形式验证与仿真结合

### 混合验证

```
混合验证流程：
┌─────────────────────────────────────────────┐
│  形式验证                                    │
│  ┌─────────────────────────────────────┐    │
│  │  属性检查                            │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  覆盖率分析                          │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  仿真补充                            │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### 形式驱动仿真

```systemverilog
// 形式驱动仿真
class formal_driven_test extends uvm_test;
    `uvm_component_utils(formal_driven_test)

    virtual task run_phase(uvm_phase phase);
        // 从形式验证获取反例
        // 使用反例驱动仿真
        // 验证反例在仿真中可复现
    endtask
endclass
```

### 仿真驱动形式

```systemverilog
// 仿真驱动形式
class simulation_driven_formal extends uvm_test;
    `uvm_component_utils(simulation_driven_formal)

    virtual task run_phase(uvm_phase phase);
        // 运行仿真获取覆盖率
        // 分析未覆盖区域
        // 针对未覆盖区域运行形式验证
    endtask
endclass
```

---

## 形式验证最佳实践

### 属性编写最佳实践

```
属性编写最佳实践：
1. 具体明确
   - 避免模糊描述
   - 明确时间关系
   - 明确条件关系

2. 可验证性
   - 属性可在有限时间内验证
   - 避免无限循环
   - 避免指数增长

3. 覆盖性
   - 覆盖核心功能
   - 覆盖边界条件
   - 覆盖异常场景

4. 可调试性
   - 属性可分解
   - 有中间检查点
   - 有辅助属性
```

### 验证策略最佳实践

```
验证策略最佳实践：
1. 渐进验证
   - 从简单到复杂
   - 从核心到外围
   - 从模块到系统

2. 分层验证
   - 协议层验证
   - 功能层验证
   - 实现层验证

3. 覆盖率驱动
   - 定义覆盖率目标
   - 分析覆盖率报告
   - 补充未覆盖属性

4. 迭代优化
   - 分析失败原因
   - 优化属性
   - 优化设计
```

### 调试最佳实践

```
调试最佳实践：
1. 系统化调试
   - 收集信息
   - 分析问题
   - 定位根源
   - 验证修复

2. 工具辅助
   - 使用波形查看器
   - 使用调试器
   - 使用日志分析

3. 知识积累
   - 记录问题和解决方案
   - 分享经验
   - 建立知识库
```

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys VC Formal User Guide | 形式验证工具 |
| REF-002 | Cadence JasperGold User Guide | 形式验证工具 |
| REF-003 | Model Checking | 模型检查理论 |
| REF-004 | Temporal Logic | 时序逻辑 |
| REF-005 | IEEE 1800-2017 | SystemVerilog 标准 |
