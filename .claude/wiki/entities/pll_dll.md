# pll_dll

> 时钟生成 IP 选型参考，PLL 和 DLL 对比与选型

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/pll_dll.md |

## 核心特性
- PLL（Phase-Locked Loop）：可倍频/分频，抖动较高，面积较大
- DLL（Delay-Locked Loop）：仅分频，抖动较低，面积较小
- PLL 应用：时钟生成、频率合成
- DLL 应用：时钟对齐、DDR 接口

## 关键参数

| 特性 | PLL | DLL |
|------|-----|-----|
| 原理 | 相位锁定 | 延迟锁定 |
| 频率 | 可倍频/分频 | 仅分频 |
| 抖动 | 较高（~ps） | 较低（<1ps） |
| 面积 | 较大 | 较小 |
| 应用 | 时钟生成 | 时钟对齐 |

## 典型应用场景
- SoC 时钟系统（PLL）
- DDR 接口时钟对齐（DLL）
- 高速串行接口参考时钟（PLL）

## 与其他实体的关系
- **clk_div**：时钟分频器 CBB
- **clk_gating**：时钟门控 CBB
- **ddr_ip**：DDR 接口需要 DLL

## 设计注意事项
- PLL 锁定时间通常 10-100 μs
- 抖动预算需要与系统时序裕量匹配
- 多 PLL 可用于不同时钟域

## 参考
- 原始文档：`.claude/knowledge/IP/pll_dll.md`
