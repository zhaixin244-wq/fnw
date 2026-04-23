# page_table

> 处理器页表结构设计参考，多级页表与地址转换

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/mmu/page_table.md |

## 核心特性
- 页表是虚拟地址到物理地址映射的数据结构
- 多级页表节省内存：只映射使用的部分
- 页表项（PTE）包含物理页号和权限位
- 支持超级页（Superpage/Hugepage）减少 TLB 压力

## 关键参数

| 页表格式 | 级数 | 页大小 | VPN 宽度 | PPN 宽度 | 典型应用 |
|----------|------|--------|----------|----------|----------|
| Sv39 | 3 | 4KB | 27-bit | 44-bit | 通用 RISC-V |
| Sv48 | 4 | 4KB | 36-bit | 44-bit | 服务器 |
| AArch64 4KB | 4 | 4KB | 36-bit | 36-bit | ARM 服务器 |
| x86-64 4级 | 4 | 4KB | 36-bit | 36-bit | x86 服务器 |

## 典型应用场景
- 操作系统虚拟内存管理
- 进程隔离与内存保护
- 大页（Hugepage）优化 TLB 命中率

## 与其他实体的关系
- **tlb**：TLB 缓存页表项加速转换
- **address_space**：页表映射虚拟地址到物理地址
- **memory_attributes**：PTE 包含内存属性位
- **memory_protection**：PTE 权限位控制访问

## 设计注意事项
- 页表遍历延迟高（3-4 周期/级），需要 TLB 加速
- 超级页可减少 TLB miss，但需要对齐
- 页表更新需要 TLB 失效（TLB Flush）

## 参考
- 原始文档：`.claude/knowledge/mmu/page_table.md`
