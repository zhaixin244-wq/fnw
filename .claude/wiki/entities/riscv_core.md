# riscv_core

> RISC-V 处理器 IP 选型参考，商业和开源方案对比

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/riscv_core.md |

## 核心特性
- 商业 IP：SiFive（E/S/U/P 系列）、Andes（A25/A45/Ax45）、T-Head（C906/C910/C920）
- 开源 IP：BOOM（乱序）、Rocket（顺序）、CVA6（6 级流水线）、VexRiscv（可配置）
- DMIPS/MHz 范围：1（低端）到 6+（高端）
- 可扩展自定义指令

## 关键参数

| 系列 | 定位 | DMIPS/MHz | 典型应用 |
|------|------|-----------|----------|
| SiFive E2/E3 | 低端嵌入式 | 1-2 | IoT、传感器 |
| SiFive U74 | 高性能 | 4-5 | 应用处理器 |
| SiFive P65 | 超高性能 | 5-6 | 服务器、AI |
| BOOM | 乱序开源 | ~5 | 研究/高性能 |
| Rocket | 顺序开源 | ~1.5 | 嵌入式 |

## 典型应用场景
- 嵌入式/IoT（E 系列/开源 Rocket）
- AI 加速器（P 系列/BOOM）
- 服务器（P 系列）

## 与其他实体的关系
- **riscv**：RISC-V ISA 架构
- **arm_core**：ARM 处理器 IP 对比

## 设计注意事项
- 开源 IP 需自行验证和维护
- 商业 IP 通常提供验证过的 RTL 和工具链
- 自定义扩展需要编译器和工具链支持

## 参考
- 原始文档：`.claude/knowledge/IP/riscv_core.md`
