# memory_attributes

> 处理器内存属性设计，缓存策略与共享性控制

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/mmu/memory_attributes.md |

## 核心特性
- 内存属性定义缓存策略、共享性和访问特性
- RISC-V PMA（物理内存属性）定义物理区域属性
- ARM MAIR（内存属性间接寄存器）支持 8 种属性配置
- 属性决定 Write-Back/Write-Through/Uncacheable 等策略

## 关键参数

| 属性类型 | 可选值 | 说明 |
|----------|--------|------|
| Cache 策略 | WB / WT / UC / WC | Write-Back/Write-Through/Uncacheable/Write-Combining |
| 共享性 | Inner/Outer/Non | 多核共享范围 |
| 内存类型 | Normal / Device / Strongly-Ordered | ARM 内存类型 |

## 典型应用场景
- 缓存子系统策略配置
- 设备寄存器映射（Uncacheable）
- DMA 缓冲区一致性维护

## 与其他实体的关系
- **page_table**：PTE 包含内存属性位
- **tlb**：TLB 缓存内存属性
- **cache**：属性决定缓存行为
- **memory_protection**：属性与权限位配合

## 设计注意事项
- 不同架构内存属性模型差异大
- 缓存一致性需要软件维护（Cache Flush/Clean）
- 设备内存通常标记为 Uncacheable + Non-shareable

## 参考
- 原始文档：`.claude/knowledge/mmu/memory_attributes.md`
