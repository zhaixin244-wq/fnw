---
name: chip-rtl-bug-checker
description: RTL Bug 模式检查 Skill。基于 data_adpt 实战经验，检查 RTL 代码中的 6 大类常见 Bug 模式（流水线/状态机、输入锁存、接口连接、FIFO/流控、位域/宽度、资源冲突）。当 chip-code-writer 完成 RTL 编码后自动调用，交付前必须通过。
tools:
  - Read
  - Grep
  - Glob
---

# RTL Bug 检查器

> 基于 data_adpt 实战经验的 RTL Bug 模式检查。chip-code-writer 在每个子模块 RTL 编写完成后调用。

## 输入

| 参数 | 类型 | 必需 | 说明 |
|------|------|------|------|
| rtl_files | file_path[] | 是 | 待检查的 RTL 文件路径列表 |
| microarch_doc | file_path | 否 | 微架构文档，用于交叉验证 |

## 输出

| 参数 | 类型 | 说明 |
|------|------|------|
| bug_check_report | object | 每项检查的 PASS/FAIL 结果 + 详情 |
| summary | string | 总结：通过/失败/警告数量 |

## 检查项（6 大类）

### A. 流水线与状态机

| # | 检查项 | 检查方法 | 严重级别 |
|---|--------|----------|----------|
| A1 | FSM 遍历链表时，是否先检查边界再推进指针？ | grep FSM 状态转移，检查边界条件 | Critical |
| A2 | 多周期操作（3+周期）期间，共享状态是否被保护？ | 检查多周期操作中的状态锁存 | Critical |
| A3 | 流水线各级之间是否有正确的数据传递？ | 检查 `_r1`/`_r2` 等流水线寄存器传递链 | Major |

### B. 输入锁存

| # | 检查项 | 检查方法 | 严重级别 |
|---|--------|----------|----------|
| B1 | 组合逻辑输出的端口值，是否在时钟沿前锁存？ | 检查组合输出是否在时序逻辑中捕获 | Critical |
| B2 | 跨状态使用的数据，是否在入口处捕获？ | 检查 FSM 入口处的数据锁存 | Major |
| B3 | RAM 请求的地址/长度是否来自锁存的上下文？ | 检查 RAM 操作地址来源 | Major |

### C. 接口连接

| # | 检查项 | 检查方法 | 严重级别 |
|---|--------|----------|----------|
| C1 | 新增端口是否在顶层正确连接？ | 对比子模块端口与顶层实例化 | Critical |
| C2 | APB 读回路径是否包含所有状态寄存器？ | 检查 reg_rd_data mux 覆盖范围 | Major |
| C3 | credit_cnt 等状态信号是否可被软件读取？ | 检查状态寄存器的读回路径 | Major |

### D. FIFO 与流控

| # | 检查项 | 检查方法 | 严重级别 |
|---|--------|----------|----------|
| D1 | FIFO 读使能是否依赖下游就绪信号？ | 检查 rd_en 的组合逻辑依赖 | Critical |
| D2 | FIFO 深度是否为 2 的幂？ | 检查 DEPTH 参数值 | Major |
| D3 | 满/空判断是否使用多1位指针法？ | 检查 full/empty 判断逻辑 | Major |

### E. 位域与宽度

| # | 检查项 | 检查方法 | 严重级别 |
|---|--------|----------|----------|
| E1 | 寄存器位域是否使用 localparam 定义偏移？ | grep 硬编码数字索引 | Major |
| E2 | 赋值两侧位宽是否匹配？ | 检查赋值语句位宽一致性 | Critical |
| E3 | 截位/扩展是否显式标注？ | 检查位宽转换是否有显式操作 | Major |

### F. 资源冲突

| # | 检查项 | 检查方法 | 严重级别 |
|---|--------|----------|----------|
| F1 | 同一寄存器数组是否有同周期多写端口？ | 检查数组赋值的 always 块数量 | Critical |
| F2 | alloc/reclaim 冲突时是否有优先级？ | 检查冲突场景的 if-else 优先级 | Critical |
| F3 | 写冲突是否有互斥逻辑？ | 检查同地址写入的互斥条件 | Critical |

## 执行流程

```
读取 RTL 文件 → 第一轮自动化 Grep → 第二轮 LLM 审查 → 汇总结果 → 输出报告
```

### 第一轮：自动化 Grep 检查

对每个 RTL 文件执行以下 Grep 命令，结果自动判定 PASS/FAIL：

#### A1: FSM 边界检查
```bash
# 检查 FSM 状态转移是否有 default 分支回收非法状态
grep -n "case.*state" {file} | head -5
grep -n "default" {file} | head -5
# 判定：case 块无 default → FAIL
```

#### B1: 输入锁存检查
```bash
# 检查组合 always 块输出是否有默认值（防 latch）
grep -cn "always @(\*)" {file}
grep -A 2 "always @(\*)" {file} | grep -c "= 0\|= 'b0\|= 1'b0"
# 判定：组合块数 > 默认值赋值数 → WARN（需 LLM 确认）
```

#### D2: FIFO 深度检查
```bash
# 检查 FIFO 深度是否为 2 的幂
grep -n "parameter.*DEPTH\|localparam.*DEPTH" {file}
# 判定：DEPTH 值不是 2^n → FAIL
```

#### E1: 硬编码位域检查
```bash
# 检查寄存器位域是否有硬编码数字索引（应用 localparam）
grep -Pn "\[\d+:\d+\]" {file} | grep -v "parameter\|localparam\|genvar\|// "
# 判定：有硬编码索引且非参数/注释 → WARN
```

#### E2: 位宽匹配检查
```bash
# 检查常量是否指定位宽
grep -Pn "\b\d+'[dhb]" {file} | head -10
# 反向检查：无位宽的裸数字常量
grep -Pn "(?<!\d'|\w)\b\d{2,}\b(?![dhb])" {file} | grep -v "//\|parameter\|localparam" | head -10
# 判定：有裸数字常量用于赋值 → WARN
```

#### F1: 多写端口检查
```bash
# 检查同一数组是否有多个 always 块赋值
grep -Pn "\w+\[\w+\]\s*<=" {file} | awk '{print $1}' | sort | uniq -d
# 判定：同一数组在多个 always 块中被赋值 → FAIL（需优先级检查）
```

#### C1: 端口连接检查（需顶层文件）
```bash
# 检查子模块实例化端口是否完整
grep -n "\..*(" {file} | wc -l
# 与子模块端口数对比，差异 > 0 → WARN
```

#### IC-36: always 块行数检查
```bash
# 统计每个 always 块的行数
awk '/^always/{start=NR; block=""} start{block=block"\n"$0} /^end/{if(start){lines=NR-start; if(lines>100) print "WARN: always at line "start" has "lines" lines"; start=0}}' {file}
# 判定：> 200 行 → FAIL，100~200 行 → WARN
```

### 第二轮：LLM 审查

对第一轮标记为 WARN 的项，以及以下无法自动化的检查项，读取 RTL 代码逐项审查：

| # | 检查项 | 审查要点 |
|---|--------|----------|
| A2 | 多周期操作保护 | 3+ 周期操作期间共享状态是否被锁定 |
| A3 | 流水线数据传递 | `_r1`/`_r2` 寄存器传递链是否完整 |
| B2 | 跨状态数据捕获 | FSM 入口处是否锁存所有必需数据 |
| B3 | RAM 地址来源 | RAM 请求地址是否来自锁存的上下文 |
| C2 | APB 读回路径 | reg_rd_data mux 是否覆盖所有状态寄存器 |
| C3 | 状态可读性 | credit_cnt 等状态信号是否可被软件读取 |
| D1 | FIFO 读使能依赖 | rd_en 是否依赖下游 ready（组合环路风险） |
| D3 | 满/空判断逻辑 | 是否使用多 1 位指针法 |
| E3 | 截位/扩展标注 | 位宽转换是否有显式操作符 |
| F2 | alloc/reclaim 优先级 | 冲突时是否有明确的 if-else 优先级 |
| F3 | 写冲突互斥 | 同地址写入是否有互斥条件 |

## 判定标准

| 结果 | 条件 |
|------|------|
| **PASS** | 所有 Critical 项通过，Major 项 ≤ 2 个警告 |
| **WARN** | 所有 Critical 项通过，Major 项 > 2 个警告 |
| **FAIL** | 任何 Critical 项失败 |

## 输出格式

```markdown
## RTL Bug 检查报告

| 类别 | # | 检查项 | 结果 | 详情 |
|------|---|--------|------|------|
| A | A1 | FSM 边界检查 | PASS/FAIL | {详情} |
| ... | ... | ... | ... | ... |

**总结**：{PASS/WARN/FAIL} | Critical: {N}/{N} | Major: {N}/{N}
```

## 降级处理

- Grep 扫描失败 → 跳过自动化检查，全部转为 LLM 审查
- RTL 文件不可读 → 标注 `[FILE-UNREADABLE]`，跳过该文件
