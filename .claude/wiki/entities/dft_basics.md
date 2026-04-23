# dft_basics

> DFT（可测试性设计）基础概念，涵盖扫描链、ATPG、BIST、边界扫描

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 方法论 |
| 来源 | .claude/knowledge/chip-design/dft_basics.md |

## 核心特性
- 扫描链：MUX 型扫描触发器，SE=0 正常/SE=1 扫描移位
- ATPG：自动测试向量生成，故障模型（固定/跳变/桥接/路径延迟）
- BIST：LBIST（逻辑自测试）+ MBIST（存储器自测试）
- 边界扫描：JTAG 5 线接口（TCK/TMS/TDI/TDO/TRST）
- 测试压缩：编码压缩/广播扫描/虚拟扫描

## 关键参数

| 参数 | 目标值 | 说明 |
|------|--------|------|
| 故障覆盖率 | > 98% | ATPG 目标 |
| 扫描链长度 | 工具自动 | DFT Compiler 分配 |
| JTAG 频率 | ≤ 20MHz | IEEE 1149.1 标准 |

## 典型应用场景
- 芯片量产测试
- 逻辑故障检测
- 存储器自测试
- 板级边界扫描

## 与其他实体的关系
- **dft_advanced**：DFT 高级概念（诊断/低功耗测试/混合信号测试）
- **lfsr**：LBIST 中的伪随机模式生成器
- **jtag**：边界扫描的接口协议

## 设计注意事项
- 所有寄存器必须可接入扫描链，禁止异步置位
- 扫描模式下 ICG 必须由 scan_en 旁路
- MBIST 使用 March C- 算法覆盖 SAF/TF/AF/CF 故障

## 参考
- 原始文档：`.claude/knowledge/chip-design/dft_basics.md`
