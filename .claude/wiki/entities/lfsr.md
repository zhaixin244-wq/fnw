# lfsr — 线性反馈移位寄存器

> 伪随机数生成、CRC 计算、测试向量生成、扰码/解扰，支持 Galois 和 Fibonacci 结构

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/lfsr.md |

## 核心特性
- Galois（并行）：单周期完成移位+反馈，速度快
- Fibonacci（串行）：逐 bit 移位，适合串行输出
- 可配置多项式（POLY）和初始种子（INIT）
- 最大周期 2^LFSR_WIDTH - 1
- equal_seed 检测周期结束

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| LFSR_WIDTH | 16 | - | LFSR 位宽 |
| POLY | 16'hB400 | - | 多项式（反馈配置） |
| INIT | 16'hACE1 | 非零 | 初始种子 |
| LFSR_TYPE | "GALOIS" | GALOIS/FIBONACCI | 结构类型 |
| OUT_WIDTH | LFSR_WIDTH | - | 输出位宽 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| en | I | 1 | 移位使能 |
| load | I | 1 | 加载种子 |
| seed | I | LFSR_WIDTH | 种子值 |
| lfsr_out | O | OUT_WIDTH | LFSR 输出值 |
| lfsr_bit | O | 1 | 串行输出（Fibonacci） |
| equal_seed | O | 1 | 当前值等于种子 |

## 典型应用场景
- BIST 内建自测试伪随机向量生成
- PRBS-7 测试码型（PCIe/SerDes）
- 通信扰码器/解扰器

## 与其他实体的关系
- 无直接依赖，为独立功能模块

## 设计注意事项
- 种子不能为全 0（全 0 会永远锁死）
- POLY 格式：bit 位置表示异或反馈点
- 面积：LFSR_WIDTH 个触发器 + XOR 门（数量 = POLY 中 1 的个数）

## 参考
- 原始文档：`.claude/knowledge/cbb/lfsr.md`
