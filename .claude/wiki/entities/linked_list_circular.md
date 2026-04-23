# linked_list_circular — 循环链表管理器

> 首尾相连的环形链表，支持插入、删除和轮转遍历，用于时间片调度和令牌环

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/linked_list_circular.md |

## 核心特性
- 尾节点 next 指向头节点，形成闭环
- current_ptr 指向当前轮转位置，advance 后移动到 next
- 支持在 current 后插入新节点和删除当前节点
- 内部使用 `linked_list_free` 管理空闲节点
- 删除后 current 自动移到 next（或 prev）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DEPTH | 16 | - | 最大节点数 |
| DATA_WIDTH | 32 | - | 节点数据位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| insert | I | 1 | 插入请求 |
| insert_data | I | DATA_WIDTH | 插入数据 |
| insert_node | O | ADDR_WIDTH | 分配的节点索引 |
| remove | I | 1 | 删除当前节点 |
| advance | I | 1 | 轮转前进 |
| current_node | O | ADDR_WIDTH | 当前节点索引 |
| current_data | O | DATA_WIDTH | 当前节点数据 |
| ring_empty | O | 1 | 环为空 |
| ring_count | O | ADDR_WIDTH+1 | 环中节点数 |

## 典型应用场景
- 时间片轮转调度（任务 ID + 参数）
- 环形 DMA 描述符链（描述符信息）
- 令牌环仲裁（端口使能掩码）

## 与其他实体的关系
- 内部使用 `linked_list_free` 管理空闲节点
- 与 `linked_list_queue` 区别：队列有方向（头出尾进），循环链表无固定方向

## 设计注意事项
- 单节点删除后环变空，ring_empty 拉高
- 面积：DEPTH × (DATA_WIDTH + 2×ADDR_WIDTH + 1) 触发器

## 参考
- 原始文档：`.claude/knowledge/cbb/linked_list_circular.md`
