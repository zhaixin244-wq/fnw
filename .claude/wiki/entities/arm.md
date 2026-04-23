# arm

> ARM 处理器架构设计参考，覆盖 Cortex-A/R/M 系列，ARMv8-A/ARMv9-A

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 协议 |
| 版本 | ARMv8-A / ARMv9-A |
| 来源 | .claude/knowledge/cpu/arm.md |

## 核心特性
- 最广泛使用的商业处理器 ISA，成熟生态
- 多系列：Cortex-A（应用）、Cortex-R（实时）、Cortex-M（嵌入式）
- TrustZone 安全世界、EL2 硬件虚拟化
- 向量扩展：NEON（128-bit）→ SVE/SVE2（可变长度）
- ARMv9 引入 RME（Realm Management Extension）

## 关键参数

| 系列 | 架构 | 流水线 | 典型频率 | 应用场景 |
|------|------|--------|----------|----------|
| Cortex-M0/M0+ | ARMv6-M | 2-3 级 | 50-100 MHz | 超低功耗 MCU |
| Cortex-M3 | ARMv7-M | 3 级 | 50-200 MHz | 通用 MCU |
| Cortex-M7 | ARMv7E-M | 6 级 | 100-600 MHz | 高性能 MCU |
| Cortex-A55 | ARMv8.2 | 8 级 | ~2 GHz | 效率核 |
| Cortex-A78 | ARMv8.2 | 11+ 级 | ~3 GHz | 性能核 |
| Cortex-X4 | ARMv9.2 | 10+ 级 | ~3.5 GHz | 超大核 |

## 典型应用场景
- 手机 SoC（Cortex-A 系列）
- 汽车 MCU（Cortex-R 系列）
- IoT/嵌入式（Cortex-M 系列）

## 与其他实体的关系
- **arm_core**：ARM 处理器 IP 选型
- **cache**：ARM 缓存层次设计
- **pipeline**：ARM 流水线微架构

## 设计注意事项
- ARM IP 授权模式：授权费 + 版税
- TrustZone 需要安全世界和普通世界隔离
- AArch64 和 AArch32 可在同一核心共存

## 参考
- 原始文档：`.claude/knowledge/cpu/arm.md`
