# 分支预测器设计

> **用途**：处理器分支预测器架构设计参考，供高性能 CPU 微架构设计时检索
> **典型应用**：高性能 CPU、超标量处理器

---

## 概述

分支预测是现代处理器性能的关键。预测准确率直接影响流水线效率，每 1% 的准确率提升可带来 ~1% 的 IPC 提升。

### 为什么需要分支预测

- **控制冒险**：分支指令需到 EX/MEM 阶段才确定目标
- **流水线惩罚**：预测失败需 Flush 流水线，惩罚 2-5+ 周期
- **分支密度**：程序中 ~15-25% 的指令是分支
- **性能影响**：10% 的分支预测失败 → ~2% IPC 损失

---

## 预测器分类

### 1. 静态预测

| 策略 | 准确率 | 说明 |
|------|--------|------|
| 总是预测不跳转 | ~50% | 最简单 |
| 总是预测跳转 | ~50% | 最简单 |
| 后向跳转预测跳转 | ~60% | 循环友好 |
| 前向跳转预测不跳转 | ~60% | if 语句友好 |
| 基于 hint 指令 | ~70% | 编译器提示 |

### 2. 动态预测

| 类型 | 准确率 | 硬件开销 | 说明 |
|------|--------|---------|------|
| 1-bit BHT | ~85% | 小 | 简单历史 |
| 2-bit BHT | ~90% | 小 | 饱和计数器 |
| BTB + BHT | ~95% | 中 | 缓存目标地址 |
| Gshare | ~95% | 中 | 全局历史 XOR |
| Tournament | ~96% | 中大 | 多预测器竞争 |
| TAGE | ~97% | 大 | 多级几何历史 |
| Perceptron | ~97% | 大 | 神经网络预测 |

---

## 2-bit 饱和计数器

### 状态机

```
  强不跳转 (00)  ←→  弱不跳转 (01)  ←→  弱跳转 (10)  ←→  强跳转 (11)
        │                  │                  │                  │
        │   实际跳转        │   实际跳转        │   实际跳转        │
        ├─────────────────→├─────────────────→├─────────────────→│
        │                  │                  │                  │
        │   实际不跳转      │   实际不跳转      │   实际不跳转      │
        │←─────────────────│←─────────────────│←─────────────────│
```

### 预测逻辑

- 状态 00, 01 → 预测不跳转
- 状态 10, 11 → 预测跳转

### 实现

```verilog
// 2-bit 饱和计数器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        bht[index] <= 2'b01;  // 弱不跳转
    else if (branch_resolved)
        if (branch_taken)
            bht[index] <= (bht[index] == 2'b11) ? 2'b11 : bht[index] + 1;
        else
            bht[index] <= (bht[index] == 2'b00) ? 2'b00 : bht[index] - 1;
end

assign prediction = bht[index][1];  // 最高位为预测
```

---

## BTB（分支目标缓冲）

### 结构

```
┌─────────────────────────────────────────────┐
│  BTB (Branch Target Buffer)                 │
│  ┌─────────┬─────────┬─────────┬─────────┐  │
│  │  Index  │   Tag   │  Target │  Valid  │  │
│  ├─────────┼─────────┼─────────┼─────────┤  │
│  │   0     │ 0x1000  │ 0x2000  │    1    │  │
│  │   1     │ 0x1004  │ 0x3000  │    1    │  │
│  │   2     │    -    │    -    │    0    │  │
│  │  ...    │  ...    │  ...    │   ...   │  │
│  └─────────┴─────────┴─────────┴─────────┘  │
└─────────────────────────────────────────────┘
```

### 工作流程

1. **查找**：用 PC[低位] 索引，PC[高位] 比较 Tag
2. **命中且有效**：预测跳转，目标 = Target
3. **未命中**：预测不跳转，PC += 指令长度
4. **更新**：分支解决后更新 BTB 条目

### 实现

```verilog
// BTB 查找
wire [INDEX_W-1:0] btb_index = pc[INDEX_W+1:2];
wire [TAG_W-1:0]   btb_tag   = pc[TAG_W+INDEX_W+1:INDEX_W+2];

wire btb_hit = btb_valid[btb_index] && (btb_tag_array[btb_index] == btb_tag);
wire [31:0] predicted_pc = btb_hit ? btb_target[btb_index] : pc + 4;

// BTB 更新
always @(posedge clk) begin
    if (branch_resolved && branch_taken) begin
        btb_valid[btb_index]   <= 1'b1;
        btb_tag_array[btb_index] <= btb_tag;
        btb_target[btb_index]  <= branch_target;
    end
end
```

---

## Gshare 预测器

### 原理

- 全局分支历史寄存器（GHR）记录最近 N 次分支结果
- GHR 与 PC 异或（XOR）生成索引
- 查找 BHT 获取预测

### 结构

```
PC[INDEX_W-1:0]  ──────┐
                       │ XOR
GHR[INDEX_W-1:0] ──────┘
                       │
                       ▼
                ┌──────────┐
                │   BHT    │
                │ (2-bit)  │
                └──────────┘
                       │
                       ▼
                   prediction
```

### 实现

```verilog
// Gshare 索引
wire [INDEX_W-1:0] gshare_index = pc[INDEX_W+1:2] ^ ghr;

// 全局历史寄存器更新
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ghr <= {INDEX_W{1'b0}};
    else if (branch_resolved)
        ghr <= {ghr[INDEX_W-2:0], branch_taken};
end

// BHT 查找
wire [1:0] bht_entry = bht[gshare_index];
wire prediction = bht_entry[1];
```

---

## Tournament 预测器

### 原理

- 多个预测器（局部、全局）并行预测
- 选择器（Chooser）根据历史选择最佳预测器

### 结构

```
┌─────────────┐  ┌─────────────┐
│ Local Pred  │  │ Global Pred │
│  (BHT)      │  │ (Gshare)    │
└──────┬──────┘  └──────┬──────┘
       │                │
       ▼                ▼
    pred_L           pred_G
       │                │
       └───────┬────────┘
               │
        ┌──────▼──────┐
        │  Chooser    │
        │ (2-bit per  │
        │   entry)    │
        └──────┬──────┘
               │
               ▼
           prediction
```

### 选择器更新

- 如果局部预测正确、全局预测错误 → 选择器偏向局部
- 如果全局预测正确、局部预测错误 → 选择器偏向全局

---

## TAGE 预测器

### 原理

- 多级预测表，每级使用不同历史长度
- 历史长度几何增长：L1, L2, L4, L8, L16, L32, ...
- 最长匹配优先（Most Useful）

### 结构

```
PC ──────────────────────────────────────────┐
                                             │
    ┌──────────┐  ┌──────────┐  ┌──────────┐│
    │  T0      │  │  T1      │  │  T2      ││
    │ (base)   │  │ (L=2)   │  │ (L=4)   ││
    │ 2-bit    │  │ tag+ctr │  │ tag+ctr ││
    └──────────┘  └──────────┘  └──────────┘│
          │            │            │        │
          ▼            ▼            ▼        │
       pred_0      pred_1      pred_2       │
          │            │            │        │
          └────────────┼────────────┘        │
                       │                     │
                ┌──────▼──────┐              │
                │  最长匹配    │◄─────────────┘
                │  选择逻辑    │
                └──────┬──────┘
                       │
                       ▼
                   prediction
```

### 关键参数

| 参数 | 说明 | 典型值 |
|------|------|--------|
| 历史级数 | 预测表数量 | 4-12 |
| 历史长度 | 几何增长 | 2, 4, 8, 16, 32, 64, 128, 256 |
| 表大小 | 每级条目数 | 1K-8K |
| Tag 宽度 | 标签位数 | 8-12 bit |
| 计数器 | 饱和计数器 | 3-bit |

### 更新策略

1. **分配**：预测错误时，在更长历史级分配新条目
2. **更新**：预测正确时，更新对应计数器
3. **衰减**：定期衰减 useful 计数器，淘汰无用条目

---

## 间接分支预测

### 问题

- 间接分支（如虚函数调用、switch 语句）目标地址不固定
- BTB 无法有效预测

### 解决方案

| 方案 | 说明 | 准确率 |
|------|------|--------|
| 简单 BTB | 缓存最近目标 | ~50% |
| 多目标 BTB | 缓存多个历史目标 | ~70% |
| ITP（Indirect Target Predictor） | 使用历史目标序列 | ~85% |
| VPC（Virtual Program Counter） | 使用路径历史 | ~90% |

---

## 返回地址栈（RAS）

### 原理

- 函数调用（CALL/BL）将返回地址压栈
- 函数返回（RET/POP PC）从栈顶弹出地址
- 预测函数返回目标

### 实现

```verilog
// RAS 栈
reg [31:0] ras_stack [0:RAS_DEPTH-1];
reg [RAS_PTR_W-1:0] ras_ptr;

// CALL：压栈
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ras_ptr <= 0;
    else if (is_call) begin
        ras_stack[ras_ptr + 1] <= return_addr;
        ras_ptr <= ras_ptr + 1;
    end
end

// RET：弹栈
wire [31:0] ras_top = ras_stack[ras_ptr];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ras_ptr <= 0;
    else if (is_ret)
        ras_ptr <= ras_ptr - 1;
end

assign predicted_ret_addr = ras_top;
```

---

## 预测器评估指标

### 准确率

```
准确率 = 正确预测次数 / 总分支次数

影响因素：
- 分支类型（条件分支、间接分支、函数返回）
- 程序特性（循环、递归、虚函数）
- 历史长度（越长越准确，但有饱和）
```

### MPKI（Mispredictions Per Kilo-Instructions）

```
MPKI = (预测失败次数 / 总指令数) × 1000

典型值：
- 简单预测器：MPKI = 10-20
- 中等预测器：MPKI = 5-10
- 高级预测器：MPKI = 2-5
```

### 面积开销

| 预测器 | 面积 (KB) | 准确率 |
|--------|----------|--------|
| 2-bit BHT (4K) | 1 | ~90% |
| Gshare (16K) | 4 | ~95% |
| Tournament (32K) | 8 | ~96% |
| TAGE (64K) | 16 | ~97% |

---

## 设计注意事项

### RTL 实现要点

1. **时序**：预测逻辑在 IF 阶段，需单周期完成
2. **更新时机**：分支解决后更新，可能延迟数周期
3. **别名问题**：不同分支映射同一表项，需 Tag 区分
4. **历史管理**：异常/中断时需恢复历史状态
5. **功耗**：大预测表访问功耗高，需时钟门控

### 常见陷阱

1. **冷启动**：预测器初始准确率低，需预热
2. **别名冲突**：不同分支共享表项，互相干扰
3. **历史污染**：异常/中断可能污染历史
4. **间接分支**：条件分支预测器无法预测间接分支
5. **函数返回**：RAS 深度有限，递归可能溢出

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | TAGE 预测器 | 原始论文 |
| REF-002 | CBP 竞赛 | 分支预测竞赛结果 |
| REF-003 | Intel 分支预测 | 商业处理器预测器分析 |
