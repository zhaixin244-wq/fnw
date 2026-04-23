# virtualization

> 处理器虚拟化机制，两阶段地址转换与虚拟机支持

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/mmu/virtualization.md |

## 核心特性
- 全虚拟化：完全模拟硬件，传统虚拟化方案
- 半虚拟化：修改 Guest OS，Xen 等方案
- 硬件辅助虚拟化：现代方案，两阶段地址转换
- Guest OS 管理 Guest VA→Guest PA，Hypervisor 管理 Guest PA→Host PA

## 关键参数

| 架构 | Stage-1 页表 | Stage-2 页表 | VPID 支持 | 典型应用 |
|------|-------------|-------------|-----------|----------|
| ARM VHE | 4 级 | 4 级 | VNCR | 服务器虚拟化 |
| RISC-V H-ext | Sv39/Sv48 | Sv39x4 | HGATP | RISC-V 虚拟化 |
| Intel EPT | 4 级 | 4 级 | VPID | x86 服务器 |
| AMD NPT | 4 级 | 4 级 | ASID | x86 服务器 |

## 典型应用场景
- 服务器虚拟化平台
- 云服务基础设施
- DPU/IPU 虚拟化加速
- 嵌入式 Hypervisor

## 与其他实体的关系
- **page_table**：两阶段页表实现地址转换
- **tlb**：TLB 需支持 VPID/ASID 区分虚拟机
- **memory_protection**：IOMMU 保护设备内存
- **address_space**：虚拟化扩展地址空间层次

## 设计注意事项
- 两阶段转换增加 TLB miss 代价
- 需要支持 VM Entry/Exit 指令
- 虚拟中断注入是性能关键路径
- 嵌套虚拟化（Nested）复杂度高

## 参考
- 原始文档：`.claude/knowledge/mmu/virtualization.md`
