# address_decoder

> 纯组合逻辑地址解码器，将地址映射为从设备片选信号

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/address_decoder.md |

## 核心特性
- 纯组合逻辑，无寄存器延迟，零周期解码
- 支持 RANGE（地址掩码匹配）和 BASE（基址+大小）两种解码模式
- 输出片选、命中索引、本地地址和越界错误信号
- 多从设备同时命中时编号小的优先
- 可用于 AXI/AHB/APB 等多种总线互联

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `ADDR_WIDTH` | 32 | ≥8 | 地址位宽 |
| `NUM_SLAVES` | 4 | ≥1 | 从设备数量 |
| `DECODE_MODE` | "RANGE" | RANGE/BASE | 解码模式 |
| `DEC_ERR_EN` | 1 | 0/1 | 越界检测使能 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `addr` | I | ADDR_WIDTH | 输入地址 |
| `cs` | O | NUM_SLAVES | 从设备片选（独热） |
| `decode_err` | O | 1 | 地址越界（无命中） |
| `slave_idx` | O | $clog2(NUM_SLAVES) | 命中从设备索引 |
| `local_addr` | O | ADDR_WIDTH | 从设备本地地址 |
| `base_addr` | I | NUM_SLAVES×ADDR_WIDTH | 各从设备基址 |
| `addr_mask` | I | NUM_SLAVES×ADDR_WIDTH | 地址掩码（RANGE 模式） |
| `addr_size` | I | NUM_SLAVES×16 | 地址空间大小（BASE 模式） |

## 典型应用场景
- AXI 总线地址解码，主设备地址到从设备映射
- APB 外设地址译码，16 字节对齐
- 与 crossbar 配合，decode_err 产生 AXI DECERR 响应

## 与其他实体的关系
- crossbar 内部实例化 address_decoder 完成地址路由
- bridge_axi_to_apb 中用于 AXI 地址到 APB 从设备选择

## 设计注意事项
- RANGE 模式：`(addr & mask) == base`；BASE 模式：`addr >= base && addr < base + size`
- 地址空间必须不重叠，否则行为不确定，推荐用 SVA 检测重叠
- local_addr = addr - base_addr[slave_idx]，传递给从设备的本地偏移
- 面积：NUM_SLAVES × (ADDR_WIDTH × 2 比较器) + 编码器

## 参考
- 原始文档：`.claude/knowledge/cbb/address_decoder.md`
