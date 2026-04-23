# findfirstone

> 在位向量中找到最低位 1 的位置，输出索引和有效标志

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/findfirstone.md |

## 核心特性
- 纯组合逻辑，低位优先编码器
- 核心算法：`vec & (~vec + 1)` 提取最低有效 1，再编码
- valid 输出：`|vec`，全 0 时 valid=0 且 index 无意义
- 大位宽可分段处理降低关键路径

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | >=2 | 输入位向量位宽 |
| `INDEX_WIDTH` | $clog2(DATA_WIDTH) | 自动推导 | 输出索引位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `vec` | I | DATA_WIDTH | 输入位向量 |
| `index` | O | INDEX_WIDTH | 最低位 1 的索引 |
| `valid` | O | 1 | 存在有效位（vec!=0） |

## 典型应用场景
- 空闲 slot 检测：找第一个未占用的 buffer slot
- 低位优先仲裁：req 中最低位的 1 获 grant
- 中断优先级（编号越小优先级越高）
- 跳转表中第一个有效项查找

## 与其他实体的关系
- **findlastone**：互补模块，findfirstone 找最低位，findlastone 找最高位
- **onehot2bin**：onehot2bin 要求恰好 1 bit 有效，findfirstone 接受任意数量的 1
- **bin2onehot**：findfirstone 输出索引可直接输入 bin2onehot 转独热码

## 设计注意事项
- 纯组合逻辑，延迟随 DATA_WIDTH 增长，大位宽（128+）考虑分段或流水线
- 面积约 O(N × logN) 门

## 参考
- 原始文档：`.claude/knowledge/cbb/findfirstone.md`
