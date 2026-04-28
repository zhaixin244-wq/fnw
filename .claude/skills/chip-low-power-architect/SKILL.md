---
name: chip-low-power-architect
description: "Use when designing low-power architecture for chip modules. Triggers on '低功耗', 'UPF', '功耗域', 'power domain', 'isolation', 'retention', 'clock gating', 'power gating'. Designs power domain partitioning, isolation/retention strategy and UPF."
---

# Chip Low-Power Architect

## 任务
输出模块级低功耗架构方案。

## 执行步骤
1. 分析应用场景中的功耗模式（Active/Idle/Sleep/Deep-Sleep/Shutdown）。
2. 定义 Power Domain 划分：
   - 常开域（Always-On）
   - 可关断域（Switchable）
   - 保持域（Retention）
3. 为每个域边界定义隔离策略（Isolation Cell 类型、默认值、使能信号）。
4. 定义保持策略（Retention Register 类型、保存/恢复触发条件）。
5. **Clock Gating 规划**：
   - 识别可门控的时钟域和对应使能条件
   - 指定 ICG Cell 名称（如 `CKLNQD1`），实例化模板：`CKLNQD1 u_icg (.CP(clk), .E(en), .TE(scan_en), .Q(gated_clk))`
   - 标注 DFT `scan_en` 端口需求
   - 遵循编码规范 §5：禁止门控时钟直接驱动组合逻辑，必须通过标准 ICG
6. 设计低功耗状态机（Power State Machine / PSM），标注状态转换条件、转换延迟、硬件/软件触发源。
7. 评估状态转换期间的毛刺、竞争、上电时序风险。
8. 给出 UPF/CPF 意图描述建议与验证策略（低功耗仿真、形式验证）。

## 输出格式
```markdown
### 低功耗架构设计

#### Power Domain 划分
| Domain | 电压 | 状态 | 隔离 | 保持 | 备注 |
|--------|------|------|------|------|------|

#### 隔离策略
| 信号 | 源域 | 目标域 | Iso 类型 | 默认值 | 使能信号 |
|------|------|--------|----------|--------|----------|

#### Clock Gating 方案
| 时钟域 | ICG Cell | 使能条件 | Scan Enable | 备注 |
|--------|----------|----------|-------------|------|
| `clk` | `CKLNQD1` | `{en}` | `scan_en` | 标准 ICG，DFT 友好 |

#### 低功耗状态机
> 使用 `chip-png-d2-gen` 生成 D2 状态机图（`wd_{module}_psm.d2`），编译为 PNG。禁止使用 Mermaid。
>
> 状态定义：Active → Sleep → Deep-Sleep → Shutdown，标注转换条件和延迟。

#### 风险与缓解
- ...
```

## 使用示例

**示例 1**：
- 用户：「为公共模块设计低功耗架构方案」
- 行为：分析功耗模式（Active/Sleep），定义 Always-On 和可关断域，设计隔离策略和保持策略，输出功耗状态机和 UPF 意图

**示例 2**：
- 用户：「buf_mgr 需要支持 Clock Gating，帮我规划」
- 行为：评估模块级 Clock Gating 可行性，定义 ICG 使能条件，标注 DFT scan_en 端口需求，输出低功耗方案表格

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 功耗模式未指定 | 用户未明确 Active/Sleep 模式 | 按默认 Active+Sleep 两模式设计，标注 `[LP-ASSUMED]` |
| 电压域信息缺失 | 未指定工艺电压 | 使用通用电压假设，标注 `[LP-NO-VOLTAGE]` |
| UPF 工具不可用 | 无 UPF 验证环境 | 仅输出意图描述，标注 `[LP-INTENT-ONLY]` |

## 检查点

**检查前**：
- 确认模块功能和接口已了解
- 确认功耗模式需求已明确

**检查后**：
- 确认 Power Domain 划分表已输出
- 确认隔离策略和保持策略已定义
- 确认 Clock Gating 方案已包含 ICG Cell 和 scan_en
- 确认功耗状态机转换条件已标注

## 降级策略

| 场景 | 行为 |
|------|------|
| 无电压域信息 | 使用通用电压假设，标注 `[LP-NO-VOLTAGE]` |
| UPF 工具不可用 | 仅输出意图描述，标注 `[LP-INTENT-ONLY]` |
| 功耗模式未指定 | 按 Active+Sleep 两模式设计，标注 `[LP-ASSUMED]` |
