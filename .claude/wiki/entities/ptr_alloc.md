# ptr_alloc — 指针分配回收器

> 基于 bitmap 的指针/槽位动态分配与回收，单周期分配，适合中小规模资源池

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/ptr_alloc.md |

## 核心特性
- Bitmap 位图管理，每 bit 对应一个槽位（1=占用，0=空闲）
- 单周期分配：组合搜索 + 寄存器更新
- 支持 LOW/HIGH 搜索方向
- alloc+free 同周期：先回收再分配
- free_err 检测重复回收

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DEPTH | 64 | - | 资源槽位数 |
| SEARCH_DIR | "LOW" | LOW/HIGH | 搜索方向 |
| INIT_FILE | "" | - | 初始 bitmap 文件 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| alloc | I | 1 | 分配请求 |
| alloc_idx | O | ADDR_WIDTH | 分配到的索引 |
| alloc_valid | O | 1 | 分配成功 |
| alloc_fail | O | 1 | 分配失败（全部占用） |
| free | I | 1 | 回收请求 |
| free_idx | I | ADDR_WIDTH | 回收的索引 |
| free_done | O | 1 | 回收完成 |
| free_err | O | 1 | 回收错误（重复回收） |
| free_count | O | ADDR_WIDTH+1 | 空闲槽位数 |

## 典型应用场景
- 网络 buffer 指针池（DEPTH=256）
- 虚拟页分配（DEPTH=1024）
- 缓存路分配（DEPTH=4）

## 与其他实体的关系
- `linked_list_free` 为链表方案的替代实现
- 推荐：DEPTH ≤ 256 用 bitmap，DEPTH > 256 用链表

## 设计注意事项
- 面积：DEPTH 个触发器 + findfirstone 逻辑，约 O(N × logN) 门
- Bitmap 搜索延迟随 DEPTH 对数增长，链表分配为 O(1) 但需指针存储
- 同周期 alloc+free 时，free_idx 的 bit 清零后参与搜索

## 参考
- 原始文档：`.claude/knowledge/cbb/ptr_alloc.md`
