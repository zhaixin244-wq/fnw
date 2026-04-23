# linked_list_queue — 链表队列管理器

> 基于双向链表的有序 FIFO 队列，支持按优先级插入、任意位置删除和遍历

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/linked_list_queue.md |

## 核心特性
- 双向链表实现，支持 PRIORITY 排序和 FIFO 两种模式
- 优先级插入遍历找到首个 priority > enq_prio 的节点插入其前
- 支持任意节点删除（remove_node）
- 内部使用 `linked_list_free` 管理空闲节点
- 出队输出链表头节点数据

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DEPTH | 64 | - | 最大队列深度 |
| DATA_WIDTH | 32 | - | 队列数据位宽 |
| PRIO_WIDTH | 4 | - | 优先级位宽（0=最高） |
| ORDER_MODE | "PRIORITY" | PRIORITY/FIFO | 排序模式 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| enqueue | I | 1 | 入队请求 |
| enq_data | I | DATA_WIDTH | 入队数据 |
| enq_prio | I | PRIO_WIDTH | 入队优先级 |
| enq_full | O | 1 | 队列满 |
| dequeue | I | 1 | 出队请求 |
| deq_data | O | DATA_WIDTH | 出队数据 |
| deq_empty | O | 1 | 队列空 |
| remove | I | 1 | 删除指定节点 |
| remove_node | I | ADDR_WIDTH | 删除的节点索引 |
| count | O | ADDR_WIDTH+1 | 当前队列长度 |

## 典型应用场景
- 网络 QoS 优先级队列（8 级优先级）
- TCP 乱序段重组缓冲（序号作优先级）
- 任务调度队列

## 与其他实体的关系
- 内部使用 `linked_list_free` 管理空闲节点池
- `linked_list_circular` 为循环遍历版本，无方向性

## 设计注意事项
- 优先级插入最坏 O(DEPTH) 周期（链表遍历）
- 可限制遍历深度或使用分段链表降低最坏延迟
- 面积：DEPTH × (DATA_WIDTH + PRIO_WIDTH + 2×ADDR_WIDTH + 1) 触发器

## 参考
- 原始文档：`.claude/knowledge/cbb/linked_list_queue.md`
