# barrel_shifter

> 单周期可变位数移位/旋转操作，log2(N) 级 MUX 级联实现

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/barrel_shifter.md |

## 核心特性
- 纯组合逻辑，单周期完成任意位数移位
- 支持 4 种移位类型：SLL（逻辑左移）、SRL（逻辑右移）、SRA（算术右移）、ROR（循环右移）
- log2(N) 级 MUX 级联，每级处理 2^i 位移位
- 可配置是否启用循环移位（ROTATE_EN）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | >=2 | 数据位宽 |
| `SHIFT_WIDTH` | $clog2(DATA_WIDTH) | 自动推导 | 移位量位宽 |
| `ROTATE_EN` | 1 | 0/1 | 循环移位使能 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `data_in` | I | DATA_WIDTH | 输入数据 |
| `shift_amt` | I | SHIFT_WIDTH | 移位量 |
| `shift_type` | I | 2 | 00=SLL, 01=SRL, 10=SRA, 11=ROR |
| `data_out` | O | DATA_WIDTH | 移位结果 |

## 典型应用场景
- ALU 移位指令：SLL/SRL/SRA 对应 RISC-V 移位操作
- 浮点尾数对齐：较小指数的尾数右移对齐
- AXI 数据对齐：非对齐地址数据重排

## 与其他实体的关系
- **bit_reverse**：barrel_shifter 按位移位，bit_reverse 完全翻转所有 bit 顺序（纯连线）

## 设计注意事项
- 面积约 3 × N × log2(N) 个门（含旋转支持的 3:1 MUX）
- 组合延迟 = log2(N) × MUX 延迟，大位宽（64+）可插入流水线
- SRA 高位补符号位 data_in[MSB]，ROR 移出的低位循环到高位

## 参考
- 原始文档：`.claude/knowledge/cbb/barrel_shifter.md`
