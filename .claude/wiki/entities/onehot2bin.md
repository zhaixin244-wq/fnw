# onehot2bin

> 将独热码转换为二进制编码，支持高位/低位优先级模式

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/onehot2bin.md |

## 核心特性
- 纯组合逻辑，无时钟/复位
- 支持优先级模式：多 bit 有效时按 HIGH/LOW 优先级输出
- 内置输入有效性检查（VALID_CHECK）：检测 0 bit 或多 bit 异常
- 与 bin2onehot 互逆：编码器（独热→二进制）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `ONEHOT_WIDTH` | 8 | >=2 | 独热码输入位宽 |
| `BIN_WIDTH` | $clog2(ONEHOT_WIDTH) | 自动推导 | 二进制输出位宽 |
| `PRIORITY` | "HIGH" | "HIGH"/"LOW" | 多 bit 有效时的优先级 |
| `VALID_CHECK` | 1 | 0/1 | 是否检查输入有效性 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `onehot_in` | I | ONEHOT_WIDTH | 独热码输入 |
| `bin_out` | O | BIN_WIDTH | 二进制编码输出 |
| `valid_out` | O | 1 | 至少 1 bit 输入有效 |
| `error` | O | 1 | 输入无效（0 bit 或多 bit） |

## 典型应用场景
- 仲裁器结果编码：独热 grant → 二进制索引驱动数据 MUX
- 中断优先级编码：irq_pending → 最高优先级中断号
- 与 bin2onehot 配对做互逆验证

## 与其他实体的关系
- **bin2onehot**：互逆操作
- **findfirstone/findlastone**：功能类似但适用场景不同——onehot2bin 要求独热输入，findfirstone 接受任意位向量

## 设计注意事项
- 低位优先用 for 循环从 bit0 扫描，高位优先从 MSB 向下扫描
- error 信号：`~(|onehot_in) | (onehot_in & (onehot_in-1))`，建议连接以检测上游异常
- 面积约 BIN_WIDTH × ONEHOT_WIDTH/2 个门

## 参考
- 原始文档：`.claude/knowledge/cbb/onehot2bin.md`
