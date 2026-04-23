# memory_protection

> 处理器内存保护机制，PMP/MPU/IOMMU 设计参考

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/mmu/memory_protection.md |

## 核心特性
- 页保护：通过页表权限位控制 R/W/X 权限
- PMP（物理内存保护）：RISC-V 特有，无 MMU 时使用
- MPU（内存保护单元）：ARM Cortex-M 系列，简单高效
- IOMMU：I/O 设备内存保护，支持设备直通

## 关键参数

| 保护机制 | 保护粒度 | 保护条目 | 典型架构 |
|----------|----------|----------|----------|
| 页保护 | 4KB | 页表项 | RISC-V/ARM/x86 |
| PMP | 4B-4GB | 16 条 | RISC-V |
| MPU | 32B-4GB | 8-16 条 | ARM Cortex-M |
| IOMMU | 4KB | 页表项 | RISC-V/ARM/x86 |

## 典型应用场景
- 嵌入式系统内存保护（PMP/MPU）
- 操作系统进程隔离（页保护）
- 虚拟化设备直通（IOMMU）
- 安全 SoC 可信执行环境

## 与其他实体的关系
- **page_table**：页保护通过页表实现
- **tlb**：TLB 缓存权限位
- **address_space**：保护机制作用于地址空间
- **virtualization**：IOMMU 支持设备虚拟化

## 设计注意事项
- PMP 优先级高于页表保护
- IOMMU 需要与系统 IOMMU 页表一致
- 保护粒度越细，硬件开销越大
- 违规访问需要产生异常（Load/Store/Fetch Access Fault）

## 参考
- 原始文档：`.claude/knowledge/mmu/memory_protection.md`
