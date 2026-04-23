# signoff

> 芯片流片前的最终签核验证，确保设计满足所有要求

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 方法论 |
| 来源 | .claude/knowledge/chip-design/signoff.md |

## 核心特性
- 签核检查 7 大类：STA/DRC/LVS/ERC/Antenna/IR Drop/EM
- OCV（片上变化）建模：AOCV/SOCV 统计方法
- 信号完整性（SI）：串扰分析与优化
- 完整签核检查清单：时序/物理/功耗/功能四维度

## 关键参数

| 参数 | 目标值 | 说明 |
|------|--------|------|
| Setup 裕量 | > 0 | Tclk - Tck2q - Tlogic - Tsetup - Tskew |
| Hold 裕量 | > 0 | Tck2q + Tlogic - Thold - Tskew |
| 静态 IR Drop | < 5% | 平均电压降 |
| 动态 IR Drop | < 10% | 峰值电压降 |
| EM 寿命 | > 10 years | DC/AC 电流寿命 |
| 天线比率 | < 100 | 金属面积/栅面积 |

## 典型应用场景
- 流片前最终检查
- 时序签核（多角分析）
- 物理验证（DRC/LVS Clean）

## 与其他实体的关系
- **sta_basics/sta_advanced**：STA 是签核的核心环节
- **physical_design**：签核在物理设计完成后执行
- **dft_basics**：DFT 签核（扫描链/ATPG 覆盖率）

## 设计注意事项
- 签核必须覆盖所有 PVT 角（SS/FF/TT/SF/FS）
- DRC/LVS 必须 Clean，任何违规不可流片
- IR Drop 需要结合仿真波形做动态分析
- EM 分析需考虑 DC 和 AC 两种模式

## 参考
- 原始文档：`.claude/knowledge/chip-design/signoff.md`
