# DDR/LPDDR

双倍数据率同步动态随机存储器接口协议。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 存储器接口 |
| **版本** | JEDEC DDR3/DDR4/DDR5/LPDDR4/LPDDR5/LPDDR5X |
| **来源** | JEDEC |

## 核心特征

- **双沿采样**：时钟上升沿和下降沿均传输数据
- **Bank 交织**：多 Bank/Bank Group 并行操作，隐藏访问延迟
- **行缓冲架构**：ACTIVATE → READ/WRITE → PRECHARGE 流程
- **数据训练**：Write Leveling、Read DQ Calibration 保证信号完整性
- **DFI 接口**：控制器与 PHY 之间的标准接口
- **代际演进**：DDR3→4→5，LPDDR4→5→5X，速率持续提升

## 关键信号（DDR3/4/5）

| 信号 | 方向 | 说明 |
|------|------|------|
| `CK/CK#` | Ctrl→DRAM | 差分时钟 |
| `CS#` | Ctrl→DRAM | 片选，低有效 |
| `RAS#/CAS#/WE#` | Ctrl→DRAM | 命令编码 |
| `A[17:0]` | Ctrl→DRAM | 地址总线（Row/Column 复用） |
| `BA/BG` | Ctrl→DRAM | Bank/Bank Group 地址 |
| `DQ[15:0]` | 双向 | 数据总线 |
| `DQS/DQS#` | 双向 | 差分数据选通 |
| `DM/DBI#` | Ctrl→DRAM | 数据掩码/总线翻转 |
| `ODT` | Ctrl→DRAM | 片上终结电阻使能 |

## 关键参数

| 参数 | DDR3 | DDR4 | DDR5 | LPDDR5 | LPDDR5X |
|------|------|------|------|--------|---------|
| 最高速率 | 2133 MT/s | 3200 MT/s | 7200 MT/s | 6400 MT/s | 8533 MT/s |
| 电压 | 1.5V | 1.2V | 1.1V/1.8V | 1.05V/0.5V | 1.05V/0.5V |
| Burst Length | 8 | 8 | 16 | 16 | 16 |
| Bank Group | 无 | 4 BG | 4 BG | 无 | 无 |
| Channel | 单 | 单 | 双 | 双 | 双 |
| 片内 ECC | 无 | 无 | 有 | 无 | 无 |

## 典型应用

- SoC 主存接口
- 服务器/PC 内存
- 移动设备内存（LPDDR）
- GPU/NPU 显存

## 与其他协议的关系

- **AXI4**：DDR 控制器通常提供 AXI4 接口
- **DFI**：DDR PHY Interface，控制器与 PHY 的标准接口
- DDR 控制器负责 AXI→DDR 命令转换和调度

## 设计要点

- 时序参数：tRCD/tRP/tRAS/tRFC/tCCD 等必须严格满足
- FR-FCFS 调度策略：先服务已打开行的请求
- Bank 状态管理：追踪每个 Bank 的当前行和状态
- Write Leveling：补偿 DDR3+ Fly-by 拓扑的时钟偏斜
- 刷新管理：Auto Refresh 周期性执行，影响带宽
