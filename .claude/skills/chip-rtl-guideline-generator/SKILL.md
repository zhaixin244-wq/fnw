---
name: chip-rtl-guideline-generator
description: "Use when generating RTL coding guidelines from microarchitecture. Triggers on '编码规范', 'coding guideline', 'RTL指导', '实现指导', '可综合性', 'rtl guideline', '编码指南', 'coding guide'. Generates RTL coding standards and synthesizability implementation guidance from microarch design."
---

# Chip RTL Guideline Generator

## 任务
从微架构设计生成可执行的 RTL 编码规范与实现指导。

## 规范维度
1. **Clock/Reset 策略**
   - 单一时钟域优先，多时钟域明确 CDC 方案
   - 同步复位或异步复位同步释放
   - 禁止门控时钟直接驱动组合逻辑
2. **可综合性**
   - 避免不可综合结构（initial、delay、floating 端口）
   - 禁止使用 latch（除低功耗保持单元外）
   - 时序逻辑与组合逻辑分离
3. **编码风格**
   - 参数化设计（可配置的 DATA_WIDTH、DEPTH、PIPELINE_STAGES）
   - 模块化接口封装（ready/valid 握手标准模板）
   - 状态机采用两段式或三段式，优先使用 `enum`/`localparam`
4. **DFT 友好性**
   - 所有触发器接入扫描链（或预留扫描端口）
   - 避免异步置位/复位与组合反馈环
   - 时钟门控使用标准 ICG 单元
5. **断言与验证接口**
   - 关键协议点插入 SVA（握手、边界条件、不变量）
   - 提供可配置的数据通路旁路（BYPASS）用于验证加速

## 执行步骤
1. 读取微架构设计描述或框图。
2. **读取项目编码规范**：必须先读取 `.claude/rules/coding-style.md`，确保生成的规则不与项目规范冲突。
3. 提取关键实现约束（数据宽度、流水线级数、状态机数量、特殊单元需求）。
4. 针对每项约束生成对应的 RTL 编码规则与代码片段示例。**所有代码示例必须使用 Verilog-2005 语法**（`always @(posedge clk)` 而非 `always_ff`）。
5. 关联 `quality-checklist-impl.md` 的 IC 编号，确保编码规则与项目质量体系对齐。
6. 输出《RTL 实现指导书》Markdown 文档到 `{module}_work/ds/doc/ua/`。

## 输出格式
```markdown
### RTL 实现指导（模块：XXX）

#### 1. Clock/Reset
- 主时钟：`clk_core`（频率：X MHz）
- 复位策略：异步复位同步释放，复位同步器深度为 2。

#### 2. 参数定义
```systemverilog
localparam DATA_WIDTH = 64;
localparam FIFO_DEPTH = 16;
```

#### 3. 关键编码规则
| 规则 ID | 规则描述 | 优先级 | 示例/备注 |
|---------|----------|--------|-----------|
| RTL-001 | 所有时序逻辑统一使用 `always @(posedge clk or negedge rst_n)` | Must | Verilog-2005 语法，见 coding-style.md §5 |

#### 4. 可综合性检查点
- ...
```

## 使用示例

**示例 1**：
- 用户：「从公共模块微架构生成 RTL 编码指导」
- 行为：读取微架构提取关键约束（数据宽度、流水线级数、FSM 数量），生成 Clock/Reset 策略、参数定义、编码规则表、可综合性检查点

**示例 2**：
- 用户：「帮我为 buf_mgr 生成 DFT 友好性编码规范」
- 行为：聚焦 DFT 维度，生成扫描链接入规则、ICG 使用规范、异步置位禁止规则，输出编码指导文档

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 微架构文档缺失 | 文件路径无效 | 暂停，提示先完成微架构设计 |
| 约束信息不足 | 微架构无详细时序/面积约束 | 基于通用规范生成，标注 `[GUIDE-GENERAL]` |
| 编码风格冲突 | 项目编码规范与生成规则矛盾 | 以项目编码规范为准，标注差异项 |

## 检查点

**检查前**：
- 确认微架构文档路径有效（用 Glob 搜索 `ds/doc/ua/*.md`）
- 确认项目编码规范 `.claude/rules/coding-style.md` 已读取

**检查后**：
- 确认 5 个规范维度均已覆盖
- 确认编码规则表包含规则 ID、描述、优先级
- 确认所有代码示例使用 Verilog-2005 语法（非 SystemVerilog）
- 确认可综合性检查点已列出

## 降级策略

| 场景 | 行为 |
|------|------|
| 微架构文档缺失 | 暂停，提示先完成微架构设计 |
| 约束信息不足 | 基于通用规范生成，标注 `[GUIDE-GENERAL]` |
| 编码风格冲突 | 以项目编码规范 `coding-style.md` 为准，标注差异项 |
