---
name: chip-rtl-guideline-generator
description: 从微架构生成 RTL 编码规范与可综合性实现指导。
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
2. 提取关键实现约束（数据宽度、流水线级数、状态机数量、特殊单元需求）。
3. 针对每项约束生成对应的 RTL 编码规则与代码片段示例。
4. 输出《RTL 实现指导书》Markdown 文档。

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
| RTL-001 | 所有时序逻辑统一使用 `always_ff` | Must | ... |

#### 4. 可综合性检查点
- ...
```
