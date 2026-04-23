# linked_list_hash — 哈希链表（关联存储）

> 基于哈希桶 + 链表法实现 O(1) 平均查找/插入/删除的键值对关联存储

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/linked_list_hash.md |

## 核心特性
- 哈希表 + 链表法解决冲突，O(1) 平均操作复杂度
- 支持 XOR/CRC/MOD 三种哈希函数
- 桶内链表头插入（O(1)），遍历查找匹配 key
- 支持 lookup/insert/delete 三种操作
- 桶满时 insert_fail 信号指示

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| NUM_BUCKETS | 16 | 2^n | 哈希桶数量 |
| ENTRIES_PER_BUCKET | 4 | - | 每桶最大链表长度 |
| KEY_WIDTH | 32 | - | 键位宽 |
| VALUE_WIDTH | 32 | - | 值位宽 |
| HASH_TYPE | "XOR" | XOR/CRC/MOD | 哈希函数类型 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| lookup | I | 1 | 查找请求 |
| lookup_key | I | KEY_WIDTH | 查找键 |
| lookup_value | O | VALUE_WIDTH | 查找结果 |
| lookup_hit | O | 1 | 查找命中 |
| insert | I | 1 | 插入请求 |
| insert_key | I | KEY_WIDTH | 插入键 |
| insert_value | I | VALUE_WIDTH | 插入值 |
| insert_fail | O | 1 | 插入失败（桶满） |
| delete | I | 1 | 删除请求 |
| delete_key | I | KEY_WIDTH | 删除键 |
| entry_count | O | - | 当前总条目数 |
| table_full | O | 1 | 表满 |

## 典型应用场景
- 网络流表（5-tuple 为 key，CRC 哈希，64 桶 × 8 条目）
- ARP 缓存（IP 为 key，XOR 哈希，16 桶 × 4 条目）
- TLB 虚拟页表（页号为 key，MOD 哈希）

## 与其他实体的关系
- 与 `linked_list_free` 无关，本模块管理自己的桶内链表
- `ptr_alloc` 为槽位分配器，不提供键值查找

## 设计注意事项
- 查找延迟：平均 O(1)，最坏 O(ENTRIES_PER_BUCKET) 周期
- NUM_BUCKETS 应为 2 的幂，哈希函数取低位即可
- 老化需上层定期扫描 delete 过期条目
- 面积：TOTAL_ENTRIES × (KEY_WIDTH + VALUE_WIDTH + ADDR_WIDTH + 1) + NUM_BUCKETS × ADDR_WIDTH

## 参考
- 原始文档：`.claude/knowledge/cbb/linked_list_hash.md`
