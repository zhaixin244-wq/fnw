---
name: chip-ppa-formatter
description: "Use when formatting PPA specification tables. Triggers on 'PPA表', 'PPA格式', 'ppa formatter', '面积表', '功耗表', '性能表', 'PPA规格'. Outputs structured PPA specs with unit normalization and constraint expressions."
---

# Chip PPA Formatter

## 任务
以结构化、可量化的方式输出 PPA 规格。

## 执行步骤
1. 从用户输入或架构描述中提取四类指标：
   - **Performance**：Latency、Throughput、Frequency、Bandwidth
   - **Power**：Dynamic Power、Leakage Power、Energy/Op
   - **Area**：Gate Count、SRAM Size、Physical Area (mm²)
   - **Quality**：SNR、BER、覆盖率（验证）
2. 统一单位并标注工艺节点与 PVT 角（如 TT/0.85V/25°C）。
3. 区分 **Target**（目标值）、**Budget**（预算值）、**Estimated**（估算值）。
4. 对每项指标给出约束表达式（如 `Latency ≤ 10 cycles @ 1GHz`）。
5. 如需对比多方案，以表格形式列出各方案的 PPA 得分与帕累托优势。

## 输出格式
```markdown
### PPA 规格表（工艺：Xnm | PVT：TT/0.85V/25°C）

| 指标类别 | 指标名 | 数值 | 单位 | 约束类型 | 备注 |
|----------|--------|------|------|----------|------|
| Performance | 处理延迟 | ≤ 10 | cycles | Target | @ 1GHz |
| Power | 动态功耗 | < 10 | mW/GHz | Budget | 典型工况 |
| Area | 门数 | ~ 150 | kGates | Estimated | 含扫描链 |
```

## 使用示例

**示例 1：格式化 PPA 目标**
```
用户：帮我格式化公共模块的 PPA 规格，工艺 28nm，目标延迟 10 cycles @ 1GHz，面积 150kGates，功耗 15mW
```
预期行为：
1. 提取指标，统一单位
2. 区分 Target/Budget/Estimated
3. 输出标准 PPA 表格（含约束表达式和 PVT 角）

**示例 2：多方案 PPA 对比**
```
用户：对比方案 A（3级流水线）和方案 B（5级流水线）的 PPA
```
预期行为：生成对比表，标注帕累托优势，建议用 DSE Skill 进一步分析

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 指标缺失 | 用户只提供了部分 PPA | 列出缺失项，标注"待补充"，输出已有部分 |
| 单位不一致 | 混用 mW/W、Gates/kGates | 自动统一单位，在备注中标注原始值 |
| 工艺节点未知 | 未指定 PVT 角 | 使用典型值（TT/0.85V/25°C），标注"假设条件" |
| 多方案对比 | 有 2+ 个方案 | 生成对比表 + 帕累托标注，建议用 DSE Skill 进一步分析 |

## 检查点

- **格式化前**：展示提取到的原始指标列表，确认无遗漏
- **格式化后**：展示最终 PPA 表格，确认单位和约束类型正确
