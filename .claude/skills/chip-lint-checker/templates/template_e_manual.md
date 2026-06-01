# Template E: LLM Manual Lint — 人工审查清单

当所有 EDA 工具不可用时，由 LLM 基于编码规范逐项审查。

## 检查清单

### 1. 模块声明与端口（编码规范 §3）

- [ ] 端口声明顺序：时钟复位 → 输入 → 输出
- [ ] 输入 `wire`，时序输出 `reg`，组合输出 `wire`
- [ ] 参数在端口前，派生用 `localparam`
- [ ] 子模块实例化名称关联（禁止位置关联）

### 2. 命名规范（编码规范 §2）

- [ ] 信号/端口：小写下划线
- [ ] 参数：大写下划线
- [ ] 时钟：`clk` 前缀
- [ ] 复位：`rst_xxx_n` 后缀，低有效 `_n` 结尾
- [ ] 使能/有效/就绪：`_en` / `_valid` / `_ready`
- [ ] 禁止：单字母名、Verilog 关键字、`tmp`/`temp`/`aux`

### 3. 时钟与复位（编码规范 §5）

- [ ] 异步复位同步释放：`always @(posedge clk or negedge rst_n)`
- [ ] 复位分支列所有寄存器
- [ ] 禁止门控时钟（用标准 ICG）
- [ ] CDC 信号有同步处理（双触发器/异步 FIFO）

### 4. 组合逻辑（编码规范 §6）

- [ ] `always @(*)` 所有输出先赋默认值（防 latch）
- [ ] `case` 必须有 `default`
- [ ] `if` 必须补全 `else`
- [ ] 组合逻辑只用 `=`，禁止 `<=`
- [ ] 禁止 `task`，`function` 仅纯组合计算

### 5. 状态机（编码规范 §7）

- [ ] `localparam` 定义状态，禁止 `define`
- [ ] ≤16 状态独热码，>16 二进制编码
- [ ] 两段式（时序存状态 + 组合算次态）
- [ ] 非法状态回收至 IDLE

### 6. 握手协议（编码规范 §8）

- [ ] `valid` 不依赖 `ready`（防组合环路）
- [ ] `ready` 优先仅依赖下游
- [ ] 握手：`valid & ready` 同高一拍完成

### 7. FIFO 设计（编码规范 §9）

- [ ] 指针多 1 位
- [ ] 满/空判断正确
- [ ] 深度为 2 的幂
- [ ] 深度有计算依据

### 8. 注释与代码风格（编码规范 §12）

- [ ] 注释覆盖率 >30%
- [ ] 缩进 4 空格（禁 Tab）
- [ ] 常量显式位宽（`8'd1` 而非 `1`）
- [ ] `generate` 块有标签
- [ ] 禁止注水注释

## 输出格式

```markdown
# Manual Lint Report — {module_name}

## Summary
- Total items checked: N
- Pass: N
- Fail: N
- N/A: N

## Findings

### [FAIL] §4.1 — {file}:{line}
**Issue:** always @(*) 中 out 未赋默认值
**Fix:** 在 always 块开头添加 `out = 0;`
```
