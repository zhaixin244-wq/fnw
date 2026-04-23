# Wishbone

开源总线标准，简洁高效，适合 FPGA 和中小规模 ASIC。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 片上总线 |
| **版本** | Wishbone B4 (Rev B4) |
| **来源** | OpenCores 社区 |

## 核心特征

- **完全开源**：无版税（Royalty-Free），可自由使用
- **信号少**：最小配置约 30 个信号，实现简单
- **STB/ACK 握手**：Master 发 STB，Slave 回 ACK
- **两种模式**：Classic（简单）和 Pipelined（流水线）
- **CYC 总线所有权**：CYC_O 标识总线周期有效
- **无 OoO/无 Outstanding**：一切从简

## 关键信号

| 信号 | 方向 | 说明 |
|------|------|------|
| `CLK_I` | SYSCON→All | 系统时钟 |
| `RST_I` | SYSCON→All | 系统复位（**高有效**） |
| `ADR_O` | M→S | 地址输出 |
| `DAT_O/DAT_I` | M→S / S→M | 数据输出/输入 |
| `SEL_O` | M→S | 字节选通 |
| `WE_O` | M→S | 写使能：1=写，0=读 |
| `STB_O` | M→S | Strobe，标识事务发起 |
| `CYC_O` | M→S | Cycle，标识总线所有权 |
| `ACK_I` | S→M | 确认应答 |
| `ERR_I` | S→M | 错误信号（可选） |
| `RTY_I` | S→M | 重试信号（可选） |
| `STALL_I` | S→M | 流水线暂停（Pipelined 模式） |
| `CTI_O[2:0]` | M→S | Cycle Type（突发类型） |
| `BTE_O[1:0]` | M→S | Burst Type（LINEAR/WRAP4/8/16） |

## 关键参数

| 参数 | 范围 | 说明 |
|------|------|------|
| 数据位宽 | 8/16/32/64 | 参数化 |
| 地址位宽 | 参数化 | 自定义 |
| 面积 | 极小 | 信号最少的总线标准 |
| Outstanding | 不支持 | 严格顺序完成 |
| OoO | 不支持 | 无乱序能力 |

## 典型应用

- FPGA SoC 构建
- 开源处理器核（RISC-V）
- IP 集成互连
- 教学和科研

## 与其他协议的关系

- **AXI4**：AXI4 支持 OoO/Outstanding/QoS，复杂度高
- **AHB-Lite**：AHB 支持 burst，ARM IP 需授权
- **APB**：APB 类似简单度，但为 ARM 授权 IP

## 设计要点

- **高有效复位**（RST_I），与 AMBA 低有效不同
- Classic 模式：STB & ACK 同周期完成
- Pipelined 模式：STALL 暂停新请求，ACK 可延迟
- CTI_O 编码：010=常量地址 burst，011=递增 burst，111=结束 burst
- 无 QoS、无 ID、无乱序——需要更高性能时选择 AXI4
