# linked_list_hash — 哈希链表（关联存储）

> **用途**：基于哈希桶 + 链表实现的键值对查找、插入、删除
> **可综合**：是
> **语言**：Verilog

---

## 模块概述

哈希链表管理器使用哈希表 + 链表法解决冲突，实现 O(1) 平均查找/插入/删除的关联存储。每个哈希桶指向一个链表，冲突的键值对挂在同一桶的链表上。用于网络流表（Flow Table）、ARP 缓存、TLB、连接跟踪表等键值查找场景。

```
key ──> hash(key) ──> 桶索引 ──> ┌──────────┐ ──> value
                                 │ linked_  │
                                 │ list_hash│
                                 └──────────┘
```

---

## 参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `NUM_BUCKETS` | parameter | 16 | 哈希桶数量（2 的幂） |
| `ENTRIES_PER_BUCKET` | parameter | 4 | 每桶最大链表长度 |
| `KEY_WIDTH` | parameter | 32 | 键位宽 |
| `VALUE_WIDTH` | parameter | 32 | 值位宽 |
| `TOTAL_ENTRIES` | localparam | `NUM_BUCKETS × ENTRIES_PER_BUCKET` | 总容量 |
| `HASH_TYPE` | parameter | `"XOR"` | 哈希函数：`"XOR"` / `"CRC"` / `"MOD"` |

---

## 接口

| 信号名 | 方向 | 位宽 | 时钟域 | 说明 |
|--------|------|------|--------|------|
| `clk` | I | 1 | - | 主时钟 |
| `rst_n` | I | 1 | - | 低有效异步复位 |
| `lookup` | I | 1 | clk | 查找请求 |
| `lookup_key` | I | `KEY_WIDTH` | clk | 查找键 |
| `lookup_value` | O | `VALUE_WIDTH` | clk | 查找结果值 |
| `lookup_hit` | O | 1 | clk | 查找命中 |
| `lookup_done` | O | 1 | clk | 查找完成 |
| `insert` | I | 1 | clk | 插入请求 |
| `insert_key` | I | `KEY_WIDTH` | clk | 插入键 |
| `insert_value` | I | `VALUE_WIDTH` | clk | 插入值 |
| `insert_done` | O | 1 | clk | 插入完成 |
| `insert_fail` | O | 1 | clk | 插入失败（桶满） |
| `delete` | I | 1 | clk | 删除请求 |
| `delete_key` | I | `KEY_WIDTH` | clk | 删除键 |
| `delete_done` | O | 1 | clk | 删除完成 |
| `delete_hit` | O | 1 | clk | 删除命中 |
| `entry_count` | O | `$clog2(TOTAL_ENTRIES+1)` | clk | 当前总条目数 |
| `table_full` | O | 1 | clk | 表满 |

---

## 时序

### 查找（命中）

```
clk           __|‾|__|‾|__|‾|__|‾|__
lookup        _____|‾|_______________
lookup_key    _____| 0x1234__________
lookup_value  _________| 0xABCD______  (命中)
lookup_hit    _________| ‾ ‾ ‾ ‾ ‾ ‾ _
lookup_done   _________| ‾ ‾ ‾ ‾ ‾ ‾ _
```

### 插入 + 冲突处理

```
clk           __|‾|__|‾|__|‾|__|‾|__|‾|__
insert        _____|‾|___|‾|_____________
insert_key    _____|K1___|K2______________
insert_value  _____|V1___|V2______________
insert_done   _________|‾|___|‾|__________
              ↑ K1 插入桶0链表头
                ↑ K2 与 K1 哈希冲突，挂在桶0链表尾
```

### 删除

```
clk           __|‾|__|‾|__|‾|__|‾|__
delete        _____|‾|_______________
delete_key    _____|K1_______________
delete_done   _________|‾|___________
delete_hit    _________|‾|___________  (找到并删除)
```

---

## 用法

### 网络流表

```verilog
linked_list_hash #(
    .NUM_BUCKETS       (64),
    .ENTRIES_PER_BUCKET(8),
    .KEY_WIDTH         (96),       // 5-tuple: {src_ip, dst_ip, src_port, dst_port, proto}
    .VALUE_WIDTH        (32),       // 流 ID
    .HASH_TYPE         ("CRC")
) u_flow_table (
    .clk           (clk),
    .rst_n         (rst_n),
    // 查找
    .lookup        (rx_flow_lookup),
    .lookup_key    ({rx_src_ip, rx_dst_ip, rx_src_port, rx_dst_port, rx_proto}),
    .lookup_value  (flow_id),
    .lookup_hit    (flow_found),
    .lookup_done   (lookup_done),
    // 插入新流
    .insert        (new_flow_insert),
    .insert_key    ({rx_src_ip, rx_dst_ip, rx_src_port, rx_dst_port, rx_proto}),
    .insert_value  (new_flow_id),
    .insert_done   (),
    .insert_fail   (flow_table_full),
    // 删除老化流
    .delete        (flow_aged_out),
    .delete_key    (aged_flow_key),
    .delete_done   (),
    .delete_hit    (),
    .entry_count   (active_flows),
    .table_full    ()
);
```

### ARP 缓存

```verilog
linked_list_hash #(
    .NUM_BUCKETS       (16),
    .ENTRIES_PER_BUCKET(4),
    .KEY_WIDTH         (32),       // IP 地址
    .VALUE_WIDTH        (48),       // MAC 地址
    .HASH_TYPE         ("XOR")
) u_arp_cache (
    .clk           (clk),
    .rst_n         (rst_n),
    .lookup        (arp_query),
    .lookup_key    (dst_ip),
    .lookup_value  (dst_mac),
    .lookup_hit    (arp_hit),
    .lookup_done   (arp_done),
    .insert        (arp_learn),
    .insert_key    (learned_ip),
    .insert_value  (learned_mac),
    .insert_done   (),
    .insert_fail   (arp_cache_full),
    .delete        (arp_age),
    .delete_key    (aged_ip),
    .delete_done   (),
    .delete_hit    (),
    .entry_count   (arp_entries),
    .table_full    ()
);
```

### TLB（Translation Lookaside Buffer）

```verilog
linked_list_hash #(
    .NUM_BUCKETS       (32),
    .ENTRIES_PER_BUCKET(2),
    .KEY_WIDTH         (20),       // 虚拟页号
    .VALUE_WIDTH        (20),       // 物理页号
    .HASH_TYPE         ("MOD")
) u_tlb (
    .clk           (clk),
    .rst_n         (rst_n),
    .lookup        (tlb_lookup),
    .lookup_key    (vpage_num),
    .lookup_value  (ppage_num),
    .lookup_hit    (tlb_hit),
    .lookup_done   (tlb_done),
    .insert        (tlb_fill),
    .insert_key    (fill_vpage),
    .insert_value  (fill_ppage),
    .insert_done   (),
    .insert_fail   (tlb_full),
    .delete        (tlb_flush),
    .delete_key    (flush_vpage),
    .delete_done   (),
    .delete_hit    (),
    .entry_count   (),
    .table_full    ()
);
```

---

## 关键实现细节

- **哈希函数**：XOR 折叠（key 异或折叠到桶位宽）、CRC 取低位、MOD 取模
- **链表法冲突解决**：同一桶的条目用链表串联，每个条目含 {key, value, next_ptr, valid}
- **查找**：hash(key) → 遍历桶内链表 → 匹配 key 返回 value
- **插入**：hash(key) → 链表头插入（O(1)），桶满时 insert_fail
- **删除**：hash(key) → 遍历链表找到 key → 断开连接 → 归还节点
- **老化**：上层定期扫描 delete 过期条目
- **面积**：TOTAL_ENTRIES × (KEY_WIDTH + VALUE_WIDTH + ADDR_WIDTH + 1) + NUM_BUCKETS × ADDR_WIDTH
- **查找延迟**：平均 O(1)，最坏 O(ENTRIES_PER_BUCKET) 周期（链表遍历）
- **桶数选择**：NUM_BUCKETS 应为 2 的幂，哈希函数取低位即可
