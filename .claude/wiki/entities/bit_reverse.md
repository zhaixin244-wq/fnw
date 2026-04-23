# bit_reverse

> 将数据位序完全翻转（MSB↔LSB），纯连线操作，零延迟零面积

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/bit_reverse.md |

## 核心特性
- 纯连线逻辑（assign），无逻辑门，零延迟零面积
- 核心实现：`genvar i; for (i=0; i<DATA_WIDTH; i=i+1) assign data_out[i] = data_in[DATA_WIDTH-1-i];`
- 对称性：反转两次恢复原值
- 综合工具优化掉，不占用任何门

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 8 | >=2 | 数据位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `data_in` | I | DATA_WIDTH | 输入数据 |
| `data_out` | O | DATA_WIDTH | 位序反转后的数据 |

## 典型应用场景
- CRC 位反射输入：CRC-32 (Ethernet) 要求输入数据位反射
- SPI LSB-first 转换：MSB-first 设备转 LSB-first
- FFT 蝶形地址生成：基-2 时间抽取的位反转地址排列

## 与其他实体的关系
- **barrel_shifter**：barrel_shifter 按位移位（有逻辑门），bit_reverse 完全翻转（纯连线）
- **crc_gen**：bit_reverse 常与 crc_gen 配合实现 REFLECT_IN 功能

## 设计注意事项
- 这是纯连线操作，综合后不占面积，是最高效的位反转实现
- 注意 bit 反转 ≠ 字节序转换，字节序需用 byte 反转：`{be[7:0], be[15:8], ...}`

## 参考
- 原始文档：`.claude/knowledge/cbb/bit_reverse.md`
