# tlb

> TLB（后备转换缓冲）架构设计，页表缓存与地址转换加速

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/mmu/tlb.md |

## 核心特性
- TLB 缓存最近使用的虚拟→物理地址映射
- TLB 命中：1 周期完成地址转换
- 页表遍历：3-4 周期/级，多级需多次内存访问
- 支持多级 TLB（L1 TLB + L2 TLB）

## 关键参数

| 参数 | 典型值 | 说明 |
|------|--------|------|
| L1 ITLB | 32-64 条目 | 指令 TLB，全相联 |
| L1 DTLB | 32-64 条目 | 数据 TLB，全相联 |
| L2 TLB | 256-4096 条目 | 统一 TLB，组相联 |
| TLB 延迟 | 1 cycle | L1 命中延迟 |
| TLB miss 代价 | 10-100 cycles | 页表遍历延迟 |

## 典型应用场景
- 高性能 CPU 地址转换
- 服务器虚拟内存优化
- 大页（Hugepage）支持

## 与其他实体的关系
- **page_table**：TLB 缓存页表项
- **address_space**：TLB 实现虚拟→物理映射
- **cache**：TLB miss 触发页表遍历，访问缓存/内存
- **memory_protection**：TLB 存储权限位

## 设计注意事项
- TLB Flush 时机：进程切换、页表更新、内存属性变更
- ASID（地址空间 ID）避免进程切换时全量 Flush
- 多级 TLB 设计平衡面积和命中率
- TLB 一致性维护是硬件/软件协同的难点

## 参考
- 原始文档：`.claude/knowledge/mmu/tlb.md`
