# crc_gen

> 可配置的 CRC 生成器，支持 CRC-8/16/32 等常见多项式，流式逐周期计算

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/crc_gen.md |

## 核心特性
- 基于 LFSR（线性反馈移位寄存器）的 CRC 计算
- 可配置多项式、初始值、输入/输出位反射、输出异或值
- 数据按 bit 或 byte 流式输入，每周期更新 CRC
- 单周期完成所有 DATA_WIDTH bit 计算，无流水线延迟
- crc_init 优先级最高，拉高时复位为 INIT 值

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `DATA_WIDTH` | 8 | 1/8/32 | 每周期输入数据位宽 |
| `CRC_WIDTH` | 32 | 8/16/32 | CRC 位宽 |
| `POLY` | 32'h04C11DB7 | - | CRC 多项式（CRC-32） |
| `INIT` | 全1 | - | CRC 初始值 |
| `REFLECT_IN` | 1 | 0/1 | 输入数据位序反转 |
| `REFLECT_OUT` | 1 | 0/1 | 输出 CRC 位序反转 |
| `XOR_OUT` | 全1 | - | 输出异或值 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | I | 1 | 主时钟 |
| `rst_n` | I | 1 | 低有效异步复位 |
| `data_in` | I | DATA_WIDTH | 输入数据 |
| `data_valid` | I | 1 | 数据有效 |
| `crc_init` | I | 1 | CRC 初始化（一周期复位） |
| `crc_out` | O | CRC_WIDTH | 当前 CRC 值 |
| `crc_final` | O | CRC_WIDTH | 最终 CRC（应用 XOR_OUT） |

## 典型应用场景
- 以太网 CRC-32 帧校验（残留值 0xDEBB20E3）
- HDLC/X.25 CRC-16/CCITT 校验
- SMBus CRC-8 校验
- 存储保护、数据链路完整性验证

## 与其他实体的关系
- **bit_reverse**：bit_reverse 常与 crc_gen 配合实现 REFLECT_IN 功能
- **ecc_encoder**：CRC 用于检错（不纠错），ECC 用于纠一检二

## 设计注意事项
- DATA_WIDTH=1 为串行 CRC，=8/32 综合工具自动优化为并行 CRC
- 面积：CRC_WIDTH 个触发器 + DATA_WIDTH × CRC_WIDTH 个 XOR 门
- 校验通过判定：输入含校验码时 crc_out 应为协议规定的残留值

## 参考
- 原始文档：`.claude/knowledge/cbb/crc_gen.md`
