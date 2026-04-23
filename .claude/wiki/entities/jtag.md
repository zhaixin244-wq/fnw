# JTAG

芯片测试与调试标准接口，支持边界扫描和内部调试访问。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 测试/调试接口 |
| **版本** | IEEE Std 1149.1-2013 |
| **来源** | IEEE（Joint Test Action Group） |

## 核心特征

- **TAP 控制器**：16 状态 FSM，由 TMS 在 TCK 上升沿驱动
- **4/5 信号线**：TCK/TMS/TDI/TDO（+可选 TRST#）
- **边界扫描**：通过 BSR 测试 PCB 连线，无需物理探针
- **IR/DR 扫描**：指令寄存器选择数据寄存器，TDI→DR→TDO 链式移位
- **JTAG 链**：多芯片菊花链级联，共享信号线
- **ARM CoreSight**：JTAG-DP 调试访问端口

## 关键信号

| 信号 | 方向 | 说明 |
|------|------|------|
| `TCK` | Host→Device | 测试时钟，独立于系统时钟 |
| `TMS` | Host→Device | 模式选择，控制 TAP 状态机 |
| `TDI` | Host→Device | 数据输入（进入芯片） |
| `TDO` | Device→Host | 数据输出（离开芯片），TCK 下降沿驱动 |
| `TRST#` | Host→Device | 测试复位，低有效异步（可选） |

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| TCK 频率 | DC~50+ MHz | 取决于目标芯片 |
| TDI/TMS setup | ≤ 5 ns | 相对 TCK 上升沿 |
| TDO 输出延迟 | ≤ 15 ns | 相对 TCK 下降沿 |
| TAP 状态数 | 16 | 标准状态机 |
| 标准指令 | BYPASS/EXTEST/SAMPLE/IDCODE | 最小集 |

## 典型应用

- PCB 边界扫描测试
- 芯片内部调试（断点、单步）
- FPGA bitstream 编程
- Flash 编程

## 与其他协议的关系

- **SWD**：ARM 2 线调试接口（SWDIO/SWCLK），JTAG 的简化替代
- **ARM CoreSight**：基于 JTAG 的 SoC 调试架构

## 设计要点

- TMS 持续高 5 个 TCK 周期可复位 TAP 到 Test-Logic-Reset
- TDI 在 TCK 上升沿采样，TDO 在 TCK 下降沿驱动
- BYPASS 指令：1 bit 旁路寄存器，缩短扫描链
- IDCODE 指令：32 bit 器件标识
- JTAG 链：前一级 TDO 连接下一级 TDI
