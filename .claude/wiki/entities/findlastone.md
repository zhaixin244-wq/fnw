# findlastone

> 在位向量中找到最高位 1 的位置，输出索引、有效标志和前导零计数

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/findlastone.md |

## 核心特性
- 纯组合逻辑，高位优先编码器
- 从最高位向下扫描，使用二分查找树降低逻辑级数
- 可选 lz_count 输出（前导零计数），用于浮点归一化
- 与 findfirstone 互补

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | >=2 | 输入位向量位宽 |
| `INDEX_WIDTH` | $clog2(DATA_WIDTH) | 自动推导 | 输出索引位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `vec` | I | DATA_WIDTH | 输入位向量 |
| `index` | O | INDEX_WIDTH | 最高位 1 的索引 |
| `valid` | O | 1 | 存在有效位（vec!=0） |
| `lz_count` | O | INDEX_WIDTH+1 | 前导零计数（可选） |

## 典型应用场景
- 高位优先仲裁：编号越大优先级越高
- 最高中断检测：32 个中断中最高编号的有效中断
- 前导零计数（CLZ）：浮点运算归一化
- 大小比较器：找最大值所在通道

## 与其他实体的关系
- **findfirstone**：互补模块，findfirstone 找最低位，findlastone 找最高位
- **popcount**：popcount 统计所有 1 的数量，findlastone 找最高位 1 的位置

## 设计注意事项
- lz_count = DATA_WIDTH - 1 - index（valid=1 时），全 0 时 lz_count = DATA_WIDTH
- 二分优化：DATA_WIDTH=2^n 时分 n 级，每级判断半区是否有 1
- 面积与 findfirstone 相当，仅优先级顺序不同

## 参考
- 原始文档：`.claude/knowledge/cbb/findlastone.md`
