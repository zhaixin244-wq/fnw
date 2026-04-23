# bin2onehot

> 将 N 位二进制编码转换为 2^N 位独热码，用于 grant/选择信号生成

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/bin2onehot.md |

## 核心特性
- 纯组合逻辑，无时钟/复位，零寄存器延迟
- 核心实现为移位操作：`assign onehot_out = (1 << bin_in)`
- 可选 valid 信号传递（valid_in 直连 valid_out）
- 与 onehot2bin 互逆：bin2onehot 是解码器，onehot2bin 是编码器
- 面积极小，综合后为移位网络

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `BIN_WIDTH` | 4 | >=1 | 二进制输入位宽 |
| `ONEHOT_WIDTH` | 1<<BIN_WIDTH | 自动推导 | 独热码输出位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `bin_in` | I | BIN_WIDTH | 二进制编码输入 |
| `onehot_out` | O | ONEHOT_WIDTH | 独热码输出 |
| `valid_in` | I | 1 | 输入有效（可选） |
| `valid_out` | O | 1 | 输出有效（可选） |

## 典型应用场景
- 仲裁器 grant 信号生成：grant_idx(二进制) → grant(独热)
- 多路选择器地址解码：sel_idx → sel_onehot 驱动 MUX
- 与 valid 配合的流水线控制

## 与其他实体的关系
- **onehot2bin**：互逆操作，bin2onehot 解码，onehot2bin 编码
- **findfirstone**：findfirstone 输出索引可直接输入 bin2onehot 转为独热码

## 设计注意事项
- bin_in 超出范围时仍会置位对应 onehot 位，需上游保证输入合法
- 纯组合逻辑，大位宽时注意组合延迟对时序的影响

## 参考
- 原始文档：`.claude/knowledge/cbb/bin2onehot.md`
