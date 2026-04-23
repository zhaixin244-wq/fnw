# multicore

> 多核处理器架构设计，拓扑结构与缓存一致性

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/cpu/multicore.md |

## 核心特性
- 多核优势：并行处理、能效比、可扩展、共享资源
- 拓扑结构：总线（Bus）、环形（Ring）、网格（Mesh）、交叉开关（Crossbar）
- 缓存一致性：Snooping 协议（MESI/MOESI）、Directory 协议
- 核间通信：共享内存、消息传递、中断

## 典型应用场景
- 多核 SoC 设计
- 服务器 CPU 架构
- AI 加速器多核阵列

## 与其他实体的关系
- **cache**：多核共享 L3 缓存和缓存一致性
- **crossbar**：多核互联的交叉开关
- **chi**：AMBA CHI 缓存一致性协议
- **tilelink**：RISC-V 生态的缓存一致性协议

## 设计注意事项
- 核数增加时缓存一致性开销急剧上升
- Directory 协议可扩展性优于 Snooping
- 核间中断延迟影响多核同步效率

## 参考
- 原始文档：`.claude/knowledge/cpu/multicore.md`
