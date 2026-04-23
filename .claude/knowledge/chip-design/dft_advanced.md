# DFT（可测试性设计）高级

> **用途**：DFT 高级概念参考，供复杂芯片测试设计时检索
> **典型应用**：高性能芯片 DFT 设计

---

## 概述

本节介绍 DFT 的高级概念，包括诊断、低功耗测试、混合信号测试等。

---

## 故障诊断

### 诊断目的

- **定位故障**：确定故障位置
- **分析原因**：分析故障原因
- **改进设计**：改进设计或工艺

### 诊断流程

```
测试失败
    ↓
诊断向量生成
    ↓
故障仿真
    ↓
候选故障列表
    ↓
物理分析
    ↓
故障定位
```

### 诊断方法

| 方法 | 说明 | 应用 |
|------|------|------|
| 扫描诊断 | 基于扫描链诊断 | 逻辑故障 |
| BIST 诊断 | 基于 BIST 诊断 | 存储器故障 |
| 物理诊断 | 基于物理版图诊断 | 物理故障 |

### 诊断工具

```tcl
# Synopsys TetraMAX 诊断
run_diagnosis

# 报告诊断结果
report_diagnosis > diagnosis.rpt
```

---

## 低功耗测试

### 测试功耗问题

- **扫描移位功耗**：扫描链翻转功耗
- **捕获功耗**：测试向量捕获功耗
- **峰值功耗**：测试峰值功耗

### 低功耗测试技术

| 技术 | 说明 | 效果 |
|------|------|------|
| 扫描链分段 | 分段扫描链 | 降低移位功耗 |
| 测试向量排序 | 排序测试向量 | 降低捕获功耗 |
| 时钟门控 | 测试时钟门控 | 降低峰值功耗 |
| 电源门控 | 测试电源门控 | 降低静态功耗 |

### 扫描链分段

```
分段扫描链：
┌─────────────────────────────────────────────┐
│  Scan In                                    │
│     │                                       │
│     ├───────────┬───────────┬───────────┐   │
│     │           │           │           │   │
│     ▼           ▼           ▼           ▼   │
│  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐  │
│  │Seg1 │    │Seg2 │    │Seg3 │    │Seg4 │  │
│  └─────┘    └─────┘    └─────┘    └─────┘  │
│     │           │           │           │   │
│     └───────────┴───────────┴───────────┘   │
│                     │                       │
│                     ▼                       │
│                Scan Out                      │
└─────────────────────────────────────────────┘
```

### 低功耗 ATPG

```tcl
# 低功耗 ATPG 设置
set_atpg_power_limit -max_power 100mW

# 低功耗测试向量生成
run_atpg -low_power
```

---

## 混合信号测试

### 混合信号测试挑战

- **模拟精度**：模拟信号精度要求高
- **数字接口**：数字测试接口复杂
- **测试时间**：模拟测试时间长

### 混合信号测试方法

| 方法 | 说明 | 应用 |
|------|------|------|
| 功能测试 | 测试功能 | ADC/DAC |
| 参数测试 | 测试参数 | 精度测试 |
| BIST | 内建自测试 | 自动测试 |

### ADC 测试

```
ADC 测试方法：
1. 直流测试：偏移、增益误差
2. 交流测试：SNR、THD
3. 动态测试：DNL、INL
```

### DAC 测试

```
DAC 测试方法：
1. 直流测试：偏移、增益误差
2. 交流测试：建立时间、毛刺
3. 动态测试：DNL、INL
```

---

## 测试点插入

### 测试点类型

| 类型 | 说明 | 用途 |
|------|------|------|
| 控制点 | 增加可控性 | 控制内部节点 |
| 观测点 | 增加可观测性 | 观测内部节点 |

### 测试点插入

```
测试点插入：
┌─────────────────────────────────────────────┐
│  原始逻辑                                   │
│  ┌─────────┐                                │
│  │ Logic   │                                │
│  └─────────┘                                │
│                                             │
│  插入测试点后：                              │
│  ┌─────────┐    ┌─────────┐                │
│  │ Logic   │───→│ Control │                │
│  └─────────┘    │ Point   │                │
│                 └─────────┘                │
│                     │                       │
│                     ▼                       │
│                ┌─────────┐                  │
│                │ Observe │                  │
│                │ Point   │                  │
│                └─────────┘                  │
└─────────────────────────────────────────────┘
```

### 测试点插入工具

```tcl
# Synopsys DFT Compiler
set_dft_insertion_configuration -test_points enable
insert_dft

# 报告测试点
report_test_points > test_points.rpt
```

---

## 存储器 BIST 高级

### 存储器故障模型

| 故障模型 | 说明 | 检测方法 |
|----------|------|----------|
| SAF | 固定故障 | March C- |
| TF | 转换故障 | March C- |
| AF | 地址故障 | March C- |
| CFin | 耦合故障 | March C- |
| CFid | 无关耦合故障 | March C- |
| SOF | 粘滞故障 | March C- |

### March 算法

```
March C- 算法：
1. ⇑(w0)
2. ⇑(r0,w1)
3. ⇑(r1,w0)
4. ⇓(r0,w1)
5. ⇓(r1,w0)
6. ⇑(r0)
```

### MBIST 控制器

```verilog
// MBIST 控制器示例
module mbist_controller (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg  done,
    output reg  pass
);

// 状态定义
localparam IDLE   = 3'b000;
localparam MARCH0 = 3'b001;
localparam MARCH1 = 3'b010;
localparam MARCH2 = 3'b011;
localparam MARCH3 = 3'b100;
localparam MARCH4 = 3'b101;
localparam MARCH5 = 3'b110;
localparam DONE   = 3'b111;

reg [2:0] state;
reg [ADDR_W-1:0] addr;
reg direction;

// 状态机
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else case (state)
        IDLE: if (start) state <= MARCH0;
        MARCH0: if (addr == MAX_ADDR) state <= MARCH1;
        MARCH1: if (addr == MAX_ADDR) state <= MARCH2;
        MARCH2: if (addr == MAX_ADDR) state <= MARCH3;
        MARCH3: if (addr == 0) state <= MARCH4;
        MARCH4: if (addr == 0) state <= MARCH5;
        MARCH5: if (addr == MAX_ADDR) state <= DONE;
        DONE: state <= IDLE;
    endcase
end

endmodule
```

---

## 测试经济学

### 测试成本

```
测试成本 = 测试时间 × 测试设备成本 + 测试向量存储成本

优化目标：
- 减少测试时间
- 减少测试数据量
- 提高故障覆盖率
```

### 测试时间优化

| 方法 | 说明 | 效果 |
|------|------|------|
| 并行测试 | 多芯片并行测试 | 减少测试时间 |
| 测试压缩 | 压缩测试数据 | 减少测试时间 |
| BIST | 内建自测试 | 减少测试时间 |

### 测试成本分析

```tcl
# 测试时间估算
set test_time [expr {$scan_length * $num_patterns * $clock_period}]

# 测试成本估算
set test_cost [expr {$test_time * $tester_cost_per_second}]
```

---

## 测试标准

### IEEE 标准

| 标准 | 说明 | 应用 |
|------|------|------|
| IEEE 1149.1 | JTAG | 边界扫描 |
| IEEE 1149.6 | AC JTAG | 高速接口 |
| IEEE 1500 | 嵌入式测试 | IP 测试 |
| IEEE 1687 | IJTAG | 内部测试 |

### IEEE 1500

```
IEEE 1500 结构：
┌─────────────────────────────────────────────┐
│  Wrapper                                    │
│  ┌─────────────────────────────────────┐    │
│  │  WBR (Wrapper Boundary Register)    │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  WIP (Wrapper Instruction Port)     │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  WIR (Wrapper Instruction Register) │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  Core                               │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## 测试调试

### 测试失败调试

```
测试失败调试流程：
1. 确认测试失败
2. 分析失败向量
3. 定位故障位置
4. 分析故障原因
5. 修复故障
```

### 调试工具

| 工具 | 用途 | 供应商 |
|------|------|--------|
| TetraMAX 诊断 | 故障诊断 | Synopsys |
| Modus 诊断 | 故障诊断 | Cadence |
| 物理分析工具 | 物理定位 | Synopsys/Cadence |

### 调试技巧

1. **分析失败模式**：确定故障类型
2. **使用诊断工具**：自动定位故障
3. **物理分析**：物理版图分析
4. **改进设计**：根据故障改进设计

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys TetraMAX User Guide | ATPG/诊断工具 |
| REF-002 | Cadence Modus User Guide | DFT/诊断工具 |
| REF-003 | IEEE 1149.1 | JTAG 标准 |
| REF-004 | IEEE 1500 | 嵌入式测试标准 |
