# linked_list_free — 空闲链表管理器

> 基于链表的空闲资源池管理，用于 buffer/descriptor 动态分配与回收，分配回收均 O(1)

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/linked_list_free.md |

## 核心特性
- 寄存器阵列实现链表指针，每节点存下一空闲节点索引
- 分配/回收均 O(1)，适合大容量资源池（64-256 项）
- 支持同周期 alloc+free，回收资源下一周期可用
- 可选信用计数（CREDIT_EN），实时跟踪空闲资源数
- SEQUENTIAL 或 FILE 两种初始化模式

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DEPTH | 256 | 2^n | 资源池大小 |
| INIT_MODE | "SEQUENTIAL" | SEQUENTIAL/FILE | 初始化方式 |
| CREDIT_EN | 1 | 0/1 | 信用计数使能 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| alloc | I | 1 | 分配请求（单周期脉冲） |
| alloc_idx | O | ADDR_WIDTH | 分配到的资源索引 |
| alloc_valid | O | 1 | 分配成功（链表非空） |
| free | I | 1 | 回收请求（单周期脉冲） |
| free_idx | I | ADDR_WIDTH | 回收的资源索引 |
| free_done | O | 1 | 回收完成 |
| free_list_empty | O | 1 | 空闲链表为空 |
| free_count | O | ADDR_WIDTH+1 | 当前空闲资源数（CREDIT_EN） |

## 典型应用场景
- 网络芯片 buffer 管理（DEPTH=256）
- DMA 描述符链表（DEPTH=64）
- 缓存行管理（DEPTH=128）

## 与其他实体的关系
- `linked_list_queue`/`linked_list_circular` 内部使用本模块管理空闲节点
- `ptr_alloc` 为 bitmap 方案的替代实现，DEPTH≤256 推荐 bitmap，>256 推荐链表

## 设计注意事项
- 空判断：`head_ptr == NULL_PTR`（NULL_PTR = DEPTH 的非法值）
- 满判断：`free_count == DEPTH`
- 面积：DEPTH × ADDR_WIDTH 个触发器 + head_ptr + 可选 free_count
- 同周期 alloc+free 时，回收资源在下一周期才可分配

## 参考
- 原始文档：`.claude/knowledge/cbb/linked_list_free.md`
