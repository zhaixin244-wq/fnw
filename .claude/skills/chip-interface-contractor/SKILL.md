---
name: chip-interface-contractor
description: "Use when defining module interface contracts. Triggers on '接口契约', 'interface contract', '信号列表', '接口定义', '端口定义', '接口时序'. Defines signal list, timing, protocol behavior and SVA for module interfaces."
---

# Chip Interface Contractor

## 任务
输出工业级精确的模块接口契约文档。

## 执行步骤
1. 确认接口类型（AXI4/ACE/CHI/TileLink/自定义握手/APB/AHB 等）。
2. 生成端口列表表格：
   | 信号名 | 方向 | 位宽 | 时钟域 | 复位值 | 描述 |
3. 定义时序参数表格：
   | 参数名 | 最小值 | 典型值 | 最大值 | 单位 | 条件 |
4. 描述事务级行为（VALID/READY 握手规则、突发传输顺序、原子操作支持）。
5. 生成关键协议的 SystemVerilog Assertion 模板（如握手不丢数据、无组合环路、复位后稳定等）。
6. 标注 CDC 相关信号（若为跨时钟域接口）及同步策略。

## 输出格式
1. 端口列表（Markdown 表格）
2. 时序参数表
3. 事务行为描述（条目式）
4. SVA 断言代码块（```systemverilog）
5. 接口约束与风险提示

## 使用示例

**示例 1**：
- 用户：「为公共模块的上游 AXI4 接口定义接口契约」
- 行为：确认 AXI4 协议和 Slave 角色，生成端口列表表格（信号名/方向/位宽/时钟域/复位值），定义时序参数（setup/hold），生成 SVA 断言模板

**示例 2**：
- 用户：「帮我定义 buf_mgr 与 ctrl_fsm 之间的自定义握手接口」
- 行为：按 Valid-Ready 协议生成端口列表，定义握手时序参数，生成握手稳定性 SVA（`valid && !ready |=> valid`），标注 CDC 信号

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 协议版本未指定 | 用户未明确 AXI4/ACE/CHI 版本 | 默认使用最新版本，标注 `[PROTO-ASSUMED]` |
| 接口类型未知 | 非标准协议且无参考文档 | 按自定义握手协议处理，标注 `[PROTO-CUSTOM]` |
| CDC 信号未标注 | 跨时钟域接口缺少同步策略 | 标注 `[CDC-TODO]`，提示用户补充同步方案 |

## 检查点

**检查前**：
- 确认接口类型（AXI4/APB/自定义等）已明确
- 确认模块角色（Master/Slave）已确定

**检查后**：
- 确认端口列表包含所有信号且位宽正确
- 确认时序参数表已生成
- 确认 SVA 断言覆盖握手稳定性和数据稳定性
