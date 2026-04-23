# mips_io

> MIPS 架构 IO 协议与总线接口参考，SoC 集成指南

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/IO-protocol/mips-io.md |

## 核心特性
- MIPS 架构 IO 协议与总线接口设计参考
- 支持 AHB/APB/AXI/OCP 等多种总线接口
- 涵盖从嵌入式 MCU 到高性能 SoC 的 IO 需求
- 系统级 IO 拓扑与中断、DMA 集成

## 关键参数

| MIPS 代际 | IO 总线 | 典型应用 |
|-----------|---------|----------|
| MIPS32/MIPS64 | AHB, OCP, AXI | 嵌入式 SoC |
| MIPS microAptiv | AHB-Lite, APB | MCU 级 |
| MIPS interAptiv | AHB, AXI | 多核 SoC |
| MIPS proAptiv | AXI, OCP | 高性能 SoC |
| MIPS I-class | AXI4, ACE | AI/网络 |

## 典型应用场景
- MIPS SoC 外设集成
- MIPS 多核 IO 一致性
- MIPS 嵌入式系统总线设计

## 与其他实体的关系
- **mips**：MIPS 指令集架构
- **ahb**：AHB 总线协议
- **axi4**：AXI4 总线协议
- **apb**：APB 外设总线

## 设计注意事项
- MIPS 不同代际总线接口差异大
- 中断控制器需要与 MIPS CP0 Cause 寄存器配合
- DMA 需要考虑缓存一致性

## 参考
- 原始文档：`.claude/knowledge/IO-protocol/mips-io.md`
