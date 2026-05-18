# CDC 方法论（共享）

> 本模板定义芯片设计中跨时钟域（Clock Domain Crossing）的统一方法论。
> 整合各 Agent 分散的 CDC 知识为统一规范。
> 供 `chip-code-writer`、`chip-microarch-writer`、`chip-arch-reviewer`、`chip-sta-analyst` 共同引用。

---

## 1. CDC 问题模型

```
时钟域 A (clk_a)              时钟域 B (clk_b)
    │                              │
    │  ┌─────────────────────┐     │
    ├─→│  CDC 信号            │────→├─→ 接收端
    │  │  (可能亚稳态)        │     │
    │  └─────────────────────┘     │
    │                              │
    └──────── 时钟域边界 ──────────┘
```

**问题**：不同时钟域的信号采样可能违反建立/保持时间，导致亚稳态传播。

**铁律：所有跨时钟域信号必须有同步方案，无一例外。**

---

## 2. CDC 信号分类与同步策略

### 2.1 单 bit 电平信号

**策略**：双触发器同步（2-FF Synchronizer）

```verilog
// 双触发器同步器
reg sig_sync1, sig_sync2;
always @(posedge clk_b or negedge rst_n) begin
    if (!rst_n) begin
        sig_sync1 <= 1'b0;
        sig_sync2 <= 1'b0;
    end else begin
        sig_sync1 <= sig_src;      // 第一级（可能亚稳态）
        sig_sync2 <= sig_sync1;    // 第二级（稳定）
    end
end
```

**约束**：
- 源信号必须在源时钟域稳定至少 1 个源时钟周期
- 同步链禁止插入组合逻辑
- MTBF 要求决定同步级数（通常 2 级足够，高可靠性需 3 级）

### 2.2 单 bit 脉冲信号

**策略**：脉冲展宽 + 双触发器同步

```verilog
// 源时钟域：脉冲展宽
reg pulse_en;
always @(posedge clk_a or negedge rst_n) begin
    if (!rst_n) pulse_en <= 1'b0;
    else if (pulse_src) pulse_en <= 1'b1;
    else if (pulse_ack) pulse_en <= 1'b0;  // 握手确认后释放
end

// 目标时钟域：双触发器同步 + 边沿检测
reg pulse_sync1, pulse_sync2, pulse_sync2_d;
always @(posedge clk_b or negedge rst_n) begin
    if (!rst_n) begin
        pulse_sync1 <= 1'b0;
        pulse_sync2 <= 1'b0;
        pulse_sync2_d <= 1'b0;
    end else begin
        pulse_sync1 <= pulse_en;
        pulse_sync2 <= pulse_sync1;
        pulse_sync2_d <= pulse_sync2;
    end
end
wire pulse_dst = pulse_sync2 & ~pulse_sync2_d;  // 上升沿检测
```

### 2.3 多 bit 数据信号

**策略**：异步 FIFO 或格雷码

| 方案 | 适用场景 | 实现方式 |
|------|----------|----------|
| 异步 FIFO | 数据流传输 | 双口 RAM + 格雷码指针 |
| 格雷码 | 计数器/指针 | 二进制→格雷码→同步→格雷码→二进制 |
| MUX 同步 | 配置寄存器 | 使能信号同步后采样 |

**异步 FIFO 格雷码指针**：
```verilog
// 写指针（二进制→格雷码）
wire [ADDR_W:0] wr_ptr_gray = wr_ptr ^ (wr_ptr >> 1);

// 读指针同步到写时钟域
reg [ADDR_W:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;
always @(posedge clk_wr or negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr_gray_sync1 <= 0;
        rd_ptr_gray_sync2 <= 0;
    end else begin
        rd_ptr_gray_sync1 <= rd_ptr_gray;
        rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
    end
end
```

### 2.4 复位信号同步

**策略**：异步复位同步释放

```verilog
// 异步复位同步释放
reg rst_sync1, rst_sync2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_sync1 <= 1'b0;
        rst_sync2 <= 1'b0;
    end else begin
        rst_sync1 <= 1'b1;
        rst_sync2 <= rst_sync1;
    end
end
wire rst_n_sync = rst_sync2;
```

---

## 3. CDC 检查清单

### 3.1 RTL CDC 检查

| # | 检查项 | 判定标准 | 检查方式 |
|---|--------|----------|----------|
| CDC-01 | 所有跨域信号有同步方案 | 100% 覆盖 | SVA + 形式验证 |
| CDC-02 | 单 bit 使用双触发器 | 无例外 | 代码审查 |
| CDC-03 | 多 bit 使用异步 FIFO 或格雷码 | 无例外 | 代码审查 |
| CDC-04 | 同步链无组合逻辑插入 | `assign` 或 `always` 内无组合 | 代码审查 |
| CDC-05 | 复位使用异步复位同步释放 | 所有模块 | 代码审查 |
| CDC-06 | 同步器在同一时钟域内 | 无跨域同步器 | 代码审查 |

### 3.2 SVA CDC 断言

```systemverilog
// CDC-01: 跨域信号必须稳定（源域保持至少 1 周期）
property p_cdc_stable;
    @(posedge clk_b) disable iff (!rst_n)
    $rose(sig_sync2) |-> $stable(sig_src);
endproperty
assert_cdc_stable: assert property (p_cdc_stable);

// CDC-04: 同步链无组合逻辑（通过代码审查保证，SVA 无法直接检查）
// CDC-05: 复位同步（通过代码审查保证）
```

### 3.3 形式验证 CDC 检查

```bash
# 检查同步器 MTBF
# 使用 SymbiYosys 检查双触发器同步器的稳定性
sby -f cdc_sync.sby prove
```

---

## 4. CDC 设计规则

### 4.1 禁止行为

| 禁止项 | 原因 | 替代方案 |
|--------|------|----------|
| 直接采样跨域信号 | 亚稳态传播 | 双触发器同步 |
| 跨域信号参与组合逻辑 | 亚稳态传播到多路径 | 先同步再组合 |
| 同步链插入组合逻辑 | 增加亚稳态窗口 | 纯寄存器同步链 |
| 跨域信号做时钟 | 时钟质量不可控 | 用 ICG + 同步使能 |
| 异步复位不做同步释放 | 复位释放时序不可控 | 异步复位同步释放 |

### 4.2 推荐实践

| 实践 | 说明 |
|------|------|
| CDC 集中管理 | 所有 CDC 同步器集中在独立模块 |
| CDC 模块命名 | `{signal}_cdc_sync` |
| CDC 注释标注 | 每个同步器标注源/目标时钟域 |
| CDC 形式验证 | 对同步器做形式验证 |
| CDC 仿真验证 | 仿真中注入亚稳态模型 |

---

## 5. CDC 在微架构中的体现

### 5.1 UA §7 时钟与复位

**CDC 信号表**（必须在 UA 中定义）：

| 信号名 | 位宽 | 源时钟域 | 目标时钟域 | 同步策略 | 风险等级 |
|--------|------|----------|-----------|----------|----------|
| `{signal}` | {W} | clk_a | clk_b | 双触发器/异步FIFO/格雷码 | L/M/H |

### 5.2 CDC 在模块连接图中的标注

```
┌─────────────┐         ┌─────────────┐
│  模块 A      │         │  模块 B      │
│  (clk_a)     │──CDC──→│  (clk_b)     │
│              │  同步器  │              │
└─────────────┘         └─────────────┘
```

---

## 6. CDC 验证策略

### 6.1 仿真验证

| 验证内容 | 方法 | 工具 |
|----------|------|------|
| 功能正确性 | CDC 信号注入亚稳态延迟 | 仿真器 |
| MTBF 评估 | 统计亚稳态发生概率 | 专用工具 |
| 时序裕量 | 检查建立/保持时间 | 时序分析 |

### 6.2 形式验证

| 验证内容 | 方法 | 工具 |
|----------|------|------|
| 同步器正确性 | 形式证明同步器稳定 | SymbiYosys |
| 格雷码正确性 | 形式证明格雷码单 bit 变化 | SymbiYosys |
| FIFO 正确性 | 形式证明满/空条件 | SymbiYosys |

---

## 7. 各 Agent CDC 职责

| Agent | CDC 职责 |
|-------|----------|
| `chip-microarch-writer` | UA §7 定义 CDC 信号表、同步策略 |
| `chip-code-writer` | RTL 实现 CDC 同步器、SVA 断言 |
| `chip-arch-reviewer` | CDC 方案审查（ruthless 强度） |
| `chip-sta-analyst` | CDC 时序分析、建立/保持检查 |

---

## 8. 与现有规范的关系

| 现有规范 | CDC 增强 |
|----------|----------|
| coding-style.md §5 | CDC 规则统一为独立方法论 |
| microarchitecture-template.md §7 | CDC 信号表强制定义 |
| sva-first-methodology.md | CDC 断言纳入 SVA 体系 |
| formal-verification-methodology.md | CDC 形式验证纳入体系 |
| chip-arch-reviewer.md | CDC 审查强度提升为 ruthless |
