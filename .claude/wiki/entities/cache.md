# cache

> 处理器缓存层次结构设计，L1/L2/L3 多级缓存

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/cpu/cache.md |

## 核心特性
- 多级缓存层次：L1（最快最小）→ L2（中等）→ L3（最慢最大，共享）
- L1 通常分为 I-Cache（指令）和 D-Cache（数据）
- 关联方式：直接映射 / 组相联 / 全相联
- 替换策略：LRU / Random / Pseudo-LRU
- 写策略：Write-Back / Write-Through / Write-Allocate

## 关键参数

| 缓存级 | 典型容量 | 延迟 | 说明 |
|--------|----------|------|------|
| L1 | 32-64 KB | 1-4 cycles | I/D 分离 |
| L2 | 256KB-1MB | 10-20 cycles | 私有/共享 |
| L3 | 4-64 MB | 30-50 cycles | 多核共享 |

## 典型应用场景
- 所有 CPU 微架构设计
- SoC 缓存子系统设计
- 缓存一致性协议（MESI/MOESI）

## 与其他实体的关系
- **pipeline**：MEM 阶段访问缓存
- **ram_sp/ram_dp**：缓存 SRAM 存储介质
- **chi**：AMBA CHI 缓存一致性协议

## 设计注意事项
- 缓存行大小通常 64 字节
- 多核缓存一致性需要硬件协议支持
- 缓存容量和关联度影响命中率和面积

## 参考
- 原始文档：`.claude/knowledge/cpu/cache.md`
