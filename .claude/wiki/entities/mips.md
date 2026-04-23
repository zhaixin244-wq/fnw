# mips

> MIPS 经典 RISC 架构，MIPS32r6/MIPS64r6，主要应用于网络设备和嵌入式

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 协议 |
| 版本 | MIPS32r6 / MIPS64r6 |
| 来源 | .claude/knowledge/cpu/mips.md |

## 核心特性
- 经典 RISC：Load/Store 架构，固定长度指令
- DSP ASE 提供 SIMD 运算
- MT ASE 支持硬件多线程
- VZ ASE 支持硬件虚拟化
- 2018 年 MIPS Open 开源，生态已逐渐被 RISC-V 超越

## 关键参数

| 版本 | 位宽 | 寄存器 | 典型应用 |
|------|------|--------|----------|
| MIPS32r2 | 32-bit | 32 GPR | 经典嵌入式 |
| MIPS32r6 | 32-bit | 32 GPR | 新一代嵌入式 |
| MIPS64r2 | 64-bit | 32 GPR | 高端网络设备 |
| MIPS64r6 | 64-bit | 32 GPR | 服务器/网络 |

## 典型应用场景
- 网络设备（路由器、网关）
- 嵌入式系统
- 学术研究

## 与其他实体的关系
- **mips-io**：MIPS IO 系统架构
- **pipeline**：MIPS 流水线设计（经典五级流水线起源）

## 设计注意事项
- r6 版本移除了分支延迟槽，引入紧凑分支
- MIPS Open 已停止维护，新设计建议考虑 RISC-V

## 参考
- 原始文档：`.claude/knowledge/cpu/mips.md`
