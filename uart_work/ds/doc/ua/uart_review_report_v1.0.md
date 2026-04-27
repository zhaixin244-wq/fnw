# UART 模块架构评审报告

> 基于 `quality-checklist-microarch.md` 和 `review-report-template.md` 执行，评审结果生成到 `ds/doc/ua/` 目录。

---

## 1. 评审信息

| 字段 | 内容 |
|------|------|
| **模块名称** | `uart` |
| **评审版本** | `v1.0` |
| **评审日期** | `2026-04-27` |
| **评审人** | `chip-arch-reviewer (AI)` |
| **对应文档** | FS `uart_FS_v1.0.md` + 7 份 UA 微架构文档 + 7 个 RTL 文件 + SVA + SDC |

---

## 2. 评审总结

### 2.1 检查项统计

| 检查类型 | 总数 | 通过 | 不通过 | 跳过 | 通过率 |
|----------|------|------|--------|------|--------|
| 交付物齐全性 | 8 | 8 | 0 | 0 | 100% |
| PR→FS 需求追溯 | 17 | 17 | 0 | 0 | 100% |
| FS→UA 一致性 | 12 | 9 | 3 | 0 | 75% |
| UA→RTL 一致性 | 15 | 13 | 2 | 0 | 87% |
| 编码规范检查 | 20 | 17 | 3 | 0 | 85% |
| FSM/FIFO 一致性 | 8 | 7 | 1 | 0 | 88% |
| SDC 一致性 | 4 | 4 | 0 | 0 | 100% |
| 架构缺陷扫描 | 10 | 6 | 4 | 0 | 60% |
| **合计** | **94** | **81** | **13** | **0** | **86%** |

### 2.2 评审结论

**当前结论**：⚠️ **有条件通过**

存在 3 个 Critical 问题和 5 个 Major 问题需修复后方可进入下一阶段。Critical 问题涉及功能正确性（IIR 编码错误、LSR.DR 信号错误），必须修复。

---

## 3. 交付物检查结果（Step 1）

| # | 交付物 | 文件路径 | 状态 |
|---|--------|----------|------|
| 1 | FS 文档 | `ds/doc/fs/uart_FS_v1.0.md` | ✅ 存在，1250 行 |
| 2 | UA 文档（7个） | `ds/doc/ua/uart_*_microarch_v1.0.md` | ✅ 全部存在 |
| 3 | RTL 源码（7个 .v） | `ds/rtl/uart_*.v` | ✅ 全部存在 |
| 4 | SVA 断言 | `ds/rtl/uart_sva.sv` | ✅ 存在，285 行 |
| 5 | SDC 约束 | `ds/run/uart.sdc` | ✅ 存在 |
| 6 | 文件列表（.f） | `ds/run/uart.f` | ✅ 存在 |
| 7 | Lint 脚本 | `ds/run/lint.sh` | ✅ 存在 |
| 8 | 综合脚本 | `ds/run/synth_yosys.tcl` | ✅ 存在 |

**结论**：所有 Must 交付物齐全，✅ 通过。

---

## 4. 一致性检查结果

### 4.1 PR→FS 需求追溯（Step 2）

| 需求 ID | PR 描述 | FS 对应章节 | FS RTM 状态 | 结果 |
|---------|---------|-------------|-------------|------|
| REQ-001 | 数据位 5/6/7/8 位可配 | §4.1, §7.2 LCR.WLS | Allocated | ✅ |
| REQ-002 | 停止位 1/1.5/2 可配 | §4.1, §7.2 LCR.STB | Allocated | ✅ |
| REQ-003 | 奇偶校验三种模式 | §4.1, §7.2 LCR.PEN/EPS | Allocated | ✅ |
| REQ-004 | 可编程波特率 | §4.1, §7.2 DLL/DLH/FCR_EXT | Allocated | ✅ |
| REQ-005 | TX FIFO 深度 ≥ 16 | §5.5, §8.3 | Allocated | ✅ |
| REQ-006 | RX FIFO 深度 ≥ 16 | §5.5, §8.3 | Allocated | ✅ |
| REQ-007 | 硬件流控 RTS/CTS | §5.6.3, §7.2 MCR.AFE | Allocated | ✅ |
| REQ-008 | 中断输出 | §5.6.3, §7.2 IER/IIR | Allocated | ✅ |
| REQ-009 | APB 从接口 32 位 | §5.1, §6.2 | Allocated | ✅ |
| REQ-010 | Loopback 自测试 | §4.2, §7.2 MCR.LOOP | Allocated | ✅ |
| REQ-011 | 自动波特率检测 | §4.2, §7.2 FCR_EXT.ABRD | Allocated | ✅ |
| REQ-012 | 波特率 9600~921600 | §8.1 | Allocated | ✅ |
| REQ-013 | 单时钟域 ≥ 50 MHz | §9, §8.1 | Allocated | ✅ |
| REQ-014 | 异步复位同步释放 | §9 | Allocated | ✅ |
| REQ-015 | RX 2 级同步器 | §5.4.1 | Allocated | ✅ |
| REQ-016 | FIFO 触发级别配置 | §7.2 FCR.RX_TRIG | Allocated | ✅ |
| REQ-017 | 16x/8x 过采样可配 | §7.2 FCR_EXT.OS_SEL | Allocated | ✅ |

**FS RTM 覆盖率**：17/17 = 100%，✅ 通过。

### 4.2 FS→UA 端口/参数一致性（Step 3）

#### uart_rx 端口不一致

| 检查项 | FS §5.4.2 | UA §4.1 / RTL | 结果 |
|--------|-----------|---------------|------|
| `rx_data` 位宽 | **8 bit** | **11 bit**（含 break/frame_err/parity） | ❌ **Critical** |
| `rts_n` 输出 | **未列出** | **存在**（20 号端口） | ❌ **Major** |

**问题 #1（Critical）**：FS §5.4.2 端口列表中 `rx_data` 位宽为 8，但 UA 和 RTL 实现为 11 bit（`{break_detect, frame_err, parity_rx, shift_reg}`）。FS §5.8.2 内部接口信号表中 `rx_fifo_data` 位宽为 11，与 UA/RTL 一致，但 §5.4.2 端口列表未同步更新。

**修复建议**：更新 FS §5.4.2 端口列表，将 `rx_data` 位宽改为 11，添加 `rts_n` 输出端口。

#### PPA 一致性

| 子模块 | FS §8.4 面积(kGates) | UA §8 面积(kGates) | 差异 |
|--------|---------------------|-------------------|------|
| uart_reg_mod | 1.0 | 1.0 | ✅ |
| uart_baud_gen | 0.5 | 0.5 | ✅ |
| uart_tx | 2.0 | 1.5 | ⚠️ Minor（UA 更保守） |
| uart_rx | 2.5 | 1.7 | ⚠️ Minor（UA 更保守） |
| uart_fifo(TX) | 1.0 | 0.9 | ✅ |
| uart_fifo(RX) | 1.0 | 1.0 | ✅ |
| uart_ctrl | 1.0 | 1.0 | ✅ |
| **合计** | **9.0** | **7.6** | ✅ 均 < 10 kGates 预算 |

**结论**：UA PPA 预估均在 FS 预算范围内，✅ 通过。

#### FS §5.4 子模块编号错误

**问题 #2（Minor）**：FS §5.4 uart_rx 章节中，5.4.1 功能描述的标题写成了 `5.3.1 功能描述`（应为 `5.4.1`），编号错位。

### 4.3 UA→RTL 实现一致性（Step 4）

#### uart_reg_mod：pready 信号驱动问题

**问题 #3（Major）**：RTL `uart_reg_mod.v` 中 `pready` 声明为 `reg`，在时序 always 块中复位为 1，但主逻辑 always 块中**未赋值**。虽然 `pready` 保持复位值 1（无等待状态），但这依赖隐式保持，不符合编码规范"组合逻辑必须赋默认值"的精神，且可能被 lint 工具警告。

**修复建议**：在读逻辑 always 块中显式赋值 `pready <= 1'b1;`，或改为 `assign pready = 1'b1;`（纯组合输出）。

#### uart_rx：rx_data 组合反馈

**问题 #4（Major）**：RTL `uart_rx.v` 第 269 行：
```verilog
rx_data <= {break_detect, !sample_majority, parity_rx, shift_reg};
```
此处 `break_detect` 和 `!sample_majority`（frame_err）在同一 always 块的同一 case 分支中刚刚赋值（第 265-267 行），使用的是**当前周期计算的值**而非寄存器值。虽然在时序逻辑中 `<=` 非阻塞赋值的 RHS 在赋值时求值，但 `break_detect` 和 `frame_err` 的新值要到下一个周期才更新到寄存器，所以此处 `rx_data` 实际使用的是**上一周期的旧值**。

**影响**：`rx_data` 中的 break_detect 和 frame_err 位延迟 1 个周期，但这与 `rx_valid` 同时输出，功能上可接受（错误标志与数据对齐）。不过这与设计意图（使用当前帧的错误状态）可能存在偏差。

**修复建议**：将错误检测和 rx_data 组装逻辑分离，或在 rx_data 中直接使用组合值而非寄存器值。

#### uart_rx：LSR.DR 信号错误

**问题 #5（Critical）**：RTL `uart_ctrl.v` 第 127 行：
```verilog
lsr[0] <= !rx_fifo_full;  // DR: FIFO not empty
```
**LSR.DR（Data Ready）应为 `!rx_fifo_empty`**（FIFO 非空表示有数据），而非 `!rx_fifo_full`（FIFO 未满）。当前实现中，FIFO 半满时 DR=1（正确），但 FIFO 满时 DR=0（**错误**——满时肯定有数据，DR 应为 1）。

**修复建议**：改为 `lsr[0] <= !rx_fifo_empty;`，需要将 `rx_fifo_empty` 信号连接到 `uart_ctrl`。

#### uart_ctrl：rx_fifo_empty 信号缺失

**问题 #6（Major）**：`uart_ctrl` 模块端口中没有 `rx_fifo_empty` 输入信号，但 LSR.DR 需要它。当前通过 `!rx_fifo_full` 间接判断不正确。

**修复建议**：在 `uart_ctrl` 端口列表中添加 `input wire rx_fifo_empty`，在 `uart_top` 中连接 `u_rx_fifo.fifo_empty`，并修改 LSR[0] 赋值。

---

## 5. 编码规范检查结果（Step 5）

### 5.1 时序逻辑规范

| 检查项 | 结果 | 详情 |
|--------|------|------|
| `always @(posedge clk or negedge rst_n)` | ✅ | 所有模块均使用异步复位 |
| 时序逻辑使用 `<=` | ✅ | 所有时序 always 块使用 `<=` |
| 复位分支列出所有寄存器 | ✅ | 所有模块复位时列出全部寄存器 |

### 5.2 组合逻辑规范

| 检查项 | 结果 | 详情 |
|--------|------|------|
| `always @(*)` 赋默认值 | ✅ | uart_fifo/uart_ctrl/uart_tx/uart_rx 均赋默认值 |
| `case` 有 `default` | ✅ | 所有 case 语句均有 default |
| `if` 补全 `else` | ✅ | 所有 if-else 结构完整 |
| 组合逻辑使用 `=` | ✅ | 组合 always 块使用 `=` |

### 5.3 FSM 规范

| 检查项 | 结果 | 详情 |
|--------|------|------|
| `localparam` 定义状态 | ✅ | uart_tx/uart_rx 使用 localparam |
| 两段式 FSM | ✅ | 时序段 + 组合段分离 |
| 非法状态回收至 IDLE | ✅ | `default: state_nxt = S_IDLE` |
| 独热码（≤16 状态） | ✅ | 5 状态独热码 |

### 5.4 实例化规范

| 检查项 | 结果 | 详情 |
|--------|------|------|
| 名称关联 | ✅ | uart_top 所有子模块均使用名称关联 |
| 顶层无 always 块 | ✅ | uart_top 仅 assign + 实例化 |

### 5.5 禁止项检查

| 检查项 | 结果 | 详情 |
|--------|------|------|
| 无 `casex`/`casez` | ✅ | 全部使用 `case` |
| 无 `task` | ✅ | 无 task 定义 |
| 无门控时钟 | ✅ | 所有时钟直连 `clk` |
| generate 有标签 | ✅ | 无 generate 块（无需标签） |

### 5.6 SVA 规范

**问题 #7（Minor）**：SVA 文件使用独立 module 定义（如 `uart_fifo_sva`），而非标准的 `bind` 方式。编码规范 §11 要求"bind 绑定 RTL"。当前实现需要在仿真时手动实例化 SVA module，降低了易用性。

**修复建议**：将 SVA module 改为使用 `bind` 语句绑定到对应 RTL module，或在文件中添加 bind 指令。

---

## 6. FSM/FIFO/SRAM 一致性（Step 6）

### 6.1 FSM 状态编码

| 模块 | 状态数 | 编码方式 | 状态值 | 结果 |
|------|--------|----------|--------|------|
| uart_tx | 5 | 独热码 | 5'b00001 ~ 5'b10000 | ✅ |
| uart_rx | 5 | 独热码 | 5'b00001 ~ 5'b10000 | ✅ |

### 6.2 FIFO 参数

| 实例 | DATA_WIDTH | DEPTH | CNT_WIDTH | 结果 |
|------|-----------|-------|-----------|------|
| u_tx_fifo | 10 | 16 | 5 | ✅ |
| u_rx_fifo | 11 | 16 | 5 | ✅ |

### 6.3 指针位宽

RTL 中 `wr_ptr`/`rd_ptr` 位宽 = `$clog2(16)+1` = 5 bit，多 1 位用于满/空判断。✅ 正确。

### 6.4 IIR 编码问题

**问题 #8（Critical）**：FS §5.6.3 和 RTL `uart_ctrl.v` 中，BI（Break）和 FE（Frame Error）的 IIR 编码**均为 `4'b0100`**，无法区分。根据 16550 标准，BI/FE/PE 应共享同一 IIR 编码（IID=011，优先级 1 的子类），但当前实现中 OE 编码为 `4'b0110`，BI/FE/PE 编码为 `4'b0100`，RxAvailable 也为 `4'b0100`——**BI/FE/PE 与 RxAvailable 编码冲突**。

**修复建议**：按 16550 标准修正 IIR 编码：
- OE/BI/FE/PE（LSR 中断）：IIR = `4'b0110`
- RxAvailable：IIR = `4'b0100`
- TxEmpty：IIR = `4'b0010`
- RTOI：IIR = `4'b1100`

---

## 7. SDC 约束一致性（Step 7）

| 检查项 | FS §8.1 | uart.sdc | 结果 |
|--------|---------|----------|------|
| 时钟周期 | 50 MHz (20ns) | `create_clock -period 20` | ✅ |
| 输入延迟 | ≤ 5 ns | `set_input_delay -max 5` | ✅ |
| 输出延迟 | ≤ 5 ns | `set_output_delay -max 5` | ✅ |
| rst_n false path | 异步复位 | `set_false_path -from rst_n` | ✅ |
| rxd false path | 异步输入 | `set_false_path -from rxd` | ✅ |
| cts_n false path | 异步输入 | `set_false_path -from cts_n` | ✅ |

**结论**：SDC 约束与 FS 一致，✅ 通过。

---

## 8. 架构缺陷扫描（Step 8）

### 8.1 组合环路风险

| 检查项 | 结果 | 详情 |
|--------|------|------|
| valid 依赖 ready | ✅ | uart_tx 中 tx_fifo_rd_en 不依赖 tx_fifo_empty 的组合反馈 |
| 顶层 assign 环路 | ✅ | `rxd_actual = loopback_en ? txd : rxd` 无环路 |

### 8.2 Latch 风险

| 检查项 | 结果 | 详情 |
|--------|------|------|
| always @(*) 默认值 | ✅ | 所有组合块赋默认值 |
| case default | ✅ | 所有 case 有 default |
| if 补 else | ✅ | 所有 if 有 else |

### 8.3 CDC 处理

| 检查项 | 结果 | 详情 |
|--------|------|------|
| rxd 2 级同步器 | ✅ | uart_rx 中 rxd_sync1/rxd_sync2 |
| rxd false path | ✅ | SDC 中 set_false_path |
| cts_n 边沿检测 | ✅ | uart_ctrl 中 cts_prev 比较 |

### 8.4 复位策略

| 检查项 | 结果 | 详情 |
|--------|------|------|
| 异步复位 | ✅ | `always @(posedge clk or negedge rst_n)` |
| 低有效 | ✅ | `if (!rst_n)` |
| 所有寄存器复位 | ✅ | 复位分支列出所有寄存器 |

### 8.5 功能缺陷

**问题 #9（Major）**：FS REQ-011（自动波特率检测）在 RTL 中**未实现**。FS §4.2 描述了自动波特率检测模式，FCR_EXT.ABRD 位已定义，但 RTL 中无相关逻辑。REQ-011 优先级为 Could，可接受延后实现，但需在 RTM 中标注状态。

**问题 #10（Minor）**：`uart_ctrl.v` 第 54 行 `int_rto = 1'b0; // TODO: timeout`，接收超时中断（RTOI）未实现。FS §5.6.3 中断优先级表中 RTOI 列为优先级 7，但 RTL 中硬编码为 0。

---

## 9. 问题清单

### 9.1 已发现问题

| # | 优先级 | 检查项 | 问题描述 | 修复建议 | 状态 |
|---|--------|--------|----------|----------|------|
| 1 | **Critical** | FS-UA 一致性 | FS §5.4.2 `rx_data` 位宽为 8，UA/RTL 为 11；`rts_n` 端口未在 FS 列出 | 更新 FS §5.4.2 端口列表 | 待修复 |
| 2 | Minor | FS 编号 | FS §5.4 标题编号错误（5.3.1→5.4.1） | 修正编号 | 待修复 |
| 3 | **Major** | UA-RTL 一致性 | `uart_reg_mod.v` 中 `pready` 未在主逻辑中赋值，依赖隐式保持 | 显式赋值 `pready <= 1'b1;` | 待修复 |
| 4 | **Major** | UA-RTL 一致性 | `uart_rx.v` 中 `rx_data` 使用同一周期计算的 break_detect/frame_err 值 | 分离错误检测和数据组装逻辑 | 待修复 |
| 5 | **Critical** | 架构缺陷 | `uart_ctrl.v` LSR[0] 使用 `!rx_fifo_full` 而非 `!rx_fifo_empty` | 改为 `!rx_fifo_empty` | 待修复 |
| 6 | **Major** | 架构缺陷 | `uart_ctrl` 缺少 `rx_fifo_empty` 输入端口 | 添加端口并在 top 中连接 | 待修复 |
| 7 | Minor | SVA 规范 | SVA 使用独立 module 而非 bind 方式 | 改用 bind 语句 | 待修复 |
| 8 | **Critical** | FSM/FIFO | IIR 编码中 BI/FE/PE 与 RxAvailable 均为 4'b0100，无法区分 | 按 16550 标准修正 IIR 编码 | 待修复 |
| 9 | **Major** | 功能缺失 | REQ-011 自动波特率检测未实现 | 在 RTM 中标注 Waived 或后续版本实现 | 待确认 |
| 10 | Minor | 功能缺失 | RTOI 接收超时中断未实现（TODO） | 后续版本实现 | 待确认 |
| 11 | Minor | PPA 差异 | FS 与 UA 子模块面积预估有差异（uart_tx 2.0 vs 1.5, uart_rx 2.5 vs 1.7） | 综合后以实际结果为准 | 已忽略 |
| 12 | Minor | 图表缺失 | 所有 D2/Wavedrom 图表标记为"待生成" | 使用 chip-png-d2-gen / chip-png-wavedrom-gen 生成 | 待修复 |
| 13 | Minor | 文档引用 | UA 文档中所有图表引用的 PNG 文件不存在 | 生成图表后更新引用 | 待修复 |

### 9.2 修复记录

| # | 问题编号 | 修复内容 | 修复文件 | 修复日期 |
|---|----------|----------|----------|----------|
| - | - | （评审报告生成，待用户确认后修复） | - | - |

---

## 10. 人工审核清单（待确认）

> 以下检查项需要人工逐项确认（涉及主观判断、外部信息依赖或专家经验），确认后在状态列标注 ✅ 或 ❌。

### 10.1 架构设计审核

| # | 检查项 | 检查内容 | 审核状态 | 备注 |
|---|--------|----------|----------|------|
| 1 | 子模块划分合理性 | 7 个子模块功能职责是否清晰，边界是否合理（reg_mod/baud_gen/tx/rx/fifo/ctrl/top） | ⬜ | 子模块划分遵循经典 UART 架构，职责清晰 |
| 2 | 接口设计合理性 | 子模块间接口是否简洁，有无冗余信号 | ⬜ | 内部接口信号约 20 个，无明显冗余 |
| 3 | 流控机制有效性 | RTS/CTS 流控是否能防止数据丢失 | ⬜ | flow_ctrl_en 控制，RTS 基于 almost_full |

### 10.2 PPA 审核

| # | 检查项 | 检查内容 | 审核状态 | 备注 |
|---|--------|----------|----------|------|
| 4 | 性能指标合理性 | 50 MHz 下 921600 bps 是否满足，APB 单周期访问是否可行 | ⬜ | 50MHz/16/921600≈3.37，可实现 |
| 5 | 功耗预算可行性 | 动态 < 5 mW 是否在合理范围内 | ⬜ | 低速外设，预算充裕 |

### 10.3 可靠性审核

| # | 检查项 | 检查内容 | 审核状态 | 备注 |
|---|--------|----------|----------|------|
| 6 | CDC 设计正确性 | rxd 2 级同步器 + false_path 是否足够 | ⬜ | 标准做法，cts_n 也做了 false_path |

### 10.4 可实现性审核

| # | 检查项 | 检查内容 | 审核状态 | 备注 |
|---|--------|----------|----------|------|
| 7 | IP/CBB 集成可行性 | FIFO 作为独立 CBB 参数化设计是否可复用 | ⬜ | 参数化设计，可独立验证 |
| 8 | 验证策略完整性 | SVA 覆盖是否充分，验证场景是否覆盖所有需求 | ⬜ | SVA 覆盖 FIFO/TX/RX/REG/CTRL，但 bind 方式待改进 |

### 10.5 审核结论

| 审核人 | 审核日期 | 审核结论 | 备注 |
|--------|----------|----------|------|
| {姓名} | YYYY-MM-DD | ⬜ 待确认 | 请逐项确认后更新 |

---

## 11. 附录

### 11.1 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | `uart_FS_v1.0.md` | 功能规格书 |
| REF-002 | `uart_*_microarch_v1.0.md` (×7) | 微架构文档 |
| REF-003 | `rules/coding-style.md` | RTL 编码规范 |
| REF-004 | `shared/quality-checklist-microarch.md` | 微架构质量检查清单 |
| REF-005 | `rules/review-report-template.md` | 评审报告模板 |

### 11.2 RTL 文件清单

| 文件 | 行数 | 子模块数 | SVA 覆盖 |
|------|------|----------|----------|
| `uart_fifo.v` | 119 | - | ✅ 有 SVA |
| `uart_baud_gen.v` | 116 | - | ✅ 有 SVA |
| `uart_tx.v` | 242 | - | ✅ 有 SVA |
| `uart_rx.v` | 287 | - | ✅ 有 SVA |
| `uart_reg_mod.v` | 183 | - | ✅ 有 SVA |
| `uart_ctrl.v` | 187 | - | ✅ 有 SVA |
| `uart_top.v` | 319 | 7 实例 | - |
| `uart_sva.sv` | 285 | 6 SVA module | - |

### 11.3 评审流程执行记录

| Step | 检查内容 | 结果 |
|------|----------|------|
| Step 1 | 交付物齐全性 | ✅ 8/8 通过 |
| Step 2 | PR→FS 需求追溯 | ✅ 17/17 覆盖 |
| Step 3 | FS→UA 一致性 | ⚠️ 3 项不通过（rx_data 位宽、rts_n 缺失、编号错误） |
| Step 4 | UA→RTL 一致性 | ⚠️ 2 项不通过（pready 驱动、rx_data 组合反馈） |
| Step 5 | 编码规范 | ⚠️ 3 项不通过（pready、SVA bind、LSR.DR） |
| Step 6 | FSM/FIFO 一致性 | ⚠️ 1 项不通过（IIR 编码冲突） |
| Step 7 | SDC 一致性 | ✅ 全部通过 |
| Step 8 | 架构缺陷扫描 | ⚠️ 4 项不通过（LSR.DR、rx_fifo_empty、ABRD 未实现、RTOI 未实现） |
| Step 9 | 评审报告生成 | ✅ 本报告 |

---

> **评审报告生成时间**：2026-04-27
>
> **下一步行动**：
> 1. 修复 3 个 Critical 问题（#1 rx_data 位宽、#5 LSR.DR、#8 IIR 编码）
> 2. 修复 5 个 Major 问题（#3 pready、#4 rx_data 组合反馈、#6 rx_fifo_empty 端口、#9 ABRD、#10 RTOI）
> 3. 修复后重新运行 lint 检查确认无警告
> 4. 人工确认 §10 审核清单
