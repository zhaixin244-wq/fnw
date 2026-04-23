# arm_core

> ARM Cortex 处理器 IP 选型参考，覆盖 Cortex-M/R/A 系列

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/arm_core.md |

## 核心特性
- Cortex-M 系列：超低功耗嵌入式（M0/M0+/M3/M4/M7/M23/M33/M55/M85）
- Cortex-R 系列：实时处理器（R4/R5/R7/R8/R52）
- Cortex-A 系列：高性能应用处理器（A55/A78/A710/X4/X925）
- DMIPS/MHz 范围：0.84（M0）到 6+（X925）
- TrustZone 安全世界支持

## 关键参数

| 核心 | 架构 | DMIPS/MHz | 面积(kGates) | 典型应用 |
|------|------|-----------|-------------|----------|
| Cortex-M0 | ARMv6-M | 0.84 | 12 | 超低功耗 MCU |
| Cortex-M4 | ARMv7E-M | 1.25+FPU | 43 | DSP+FPU |
| Cortex-A55 | ARMv8.2 | ~4 | - | 效率核 |
| Cortex-X4 | ARMv9.2 | ~6+ | - | 超大核 |

## 典型应用场景
- 手机 SoC（Cortex-A + Cortex-M）
- 汽车 ECU（Cortex-R）
- IoT 节点（Cortex-M0/M23）

## 与其他实体的关系
- **arm**：ARM 架构概述
- **riscv_core**：RISC-V 处理器 IP 对比

## 设计注意事项
- ARM IP 授权：授权费（$1M-$10M+）+ 版税（1-5%）
- 安全世界需要独立的地址空间和中断处理
- big.LITTLE 大小核架构需要任务调度器配合

## 参考
- 原始文档：`.claude/knowledge/IP/arm_core.md`
