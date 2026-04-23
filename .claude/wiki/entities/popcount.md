# popcount

> 统计位向量中 1 的个数，使用树形加法结构

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/popcount.md |

## 核心特性
- 纯组合逻辑，树形加法逐级归约
- log2(DATA_WIDTH) 级加法器级联
- 输出位宽 = $clog2(DATA_WIDTH) + 1，可表示 0 到 DATA_WIDTH
- 大位宽（128+）可插入寄存器做流水线

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | >=2 | 输入位向量位宽 |
| `COUNT_WIDTH` | $clog2(DATA_WIDTH)+1 | 自动推导 | 输出计数位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `vec` | I | DATA_WIDTH | 输入位向量 |
| `count` | O | COUNT_WIDTH | 1 的计数值 |

## 典型应用场景
- 资源占用统计：统计 N 个 slot 中被占用的数量
- 汉明距离计算：`popcount(a ^ b)` 得到不同 bit 数
- 权重投票：统计赞成票数是否过半
- 条件掩码计数：统计满足条件的通道数

## 与其他实体的关系
- **findfirstone/findlastone**：find* 找特定位置的 1，popcount 统计所有 1 的数量

## 设计注意事项
- 组合延迟 = log2(N) × 加法器延迟，大位宽需评估时序
- 面积约 DATA_WIDTH × log(N) 个门（DATA_WIDTH/2 个全加器逐级归约）
- DATA_WIDTH=128+ 时建议插入流水线寄存器

## 参考
- 原始文档：`.claude/knowledge/cbb/popcount.md`
