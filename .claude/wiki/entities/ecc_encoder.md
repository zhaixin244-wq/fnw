# ecc_encoder

> 海明码 SECDED 编码器，对数据生成单纠错双检错 ECC 校验位

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/ecc_encoder.md |

## 核心特性
- 实现海明码扩展的 SECDED（单纠错双检错）编码
- 校验位占据 2^n 位置（1,2,4,8,16...），数据位填充其余位置
- 总奇偶位区分 1-bit 和 2-bit 错误
- 纯组合逻辑，无时钟延迟

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 32 | 8/16/32/64/128 | 数据位宽 |
| `ECC_WIDTH` | 自动计算 | 5~9 | ECC 校验位位宽 |
| `TOTAL_WIDTH` | DATA_WIDTH+ECC_WIDTH+1 | 自动推导 | 总输出位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `data_in` | I | DATA_WIDTH | 输入数据 |
| `ecc_out` | O | ECC_WIDTH | ECC 校验位输出 |
| `parity_out` | O | 1 | 总奇偶校验位 |
| `data_with_ecc` | O | TOTAL_WIDTH | 数据+ECC 完整输出 |

## 典型应用场景
- SRAM 写入时编码：数据+ECC 一起存储，防止 SEU
- AXI 总线 ECC 保护：ECC 位通过 sideband 传递
- 配置寄存器完整性校验：定期重算 ECC 比对

## 与其他实体的关系
- **crc_gen**：CRC 仅检错不纠错，ECC 可纠 1-bit 错+检 2-bit 错
- 需与 **ecc_decoder** 配对使用：编码器写入 → 存储 → 读出后解码器检测/纠错

## 设计注意事项
- 面积开销：32-bit 数据需 7 位 ECC = 22% 面积开销
- 编码延迟：ECC_WIDTH 级 XOR 门级联
- 面积约 ECC_WIDTH × ~DATA_WIDTH/2 个 XOR 门
- 不同 DATA_WIDTH 的校验位计算公式不同，综合工具自动推断

## 参考
- 原始文档：`.claude/knowledge/cbb/ecc_encoder.md`
