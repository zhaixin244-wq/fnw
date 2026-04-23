# DDR/LPDDR SDRAM 接口协议参考

> **适用对象**：数字 IC 设计架构师
> **版本**：v1.0
> **日期**：2026-04-15

---

## 1. 协议概述

### 1.1 SDRAM 基本原理

SDRAM（Synchronous Dynamic Random-Access Memory）是以时钟同步方式进行数据存取的动态随机存储器。DDR（Double Data Rate）在时钟的上升沿和下降沿均采样数据，实现每个时钟周期传输 2 bit 数据。

**存储阵列组织**：

```
Channel (LPDDR5 支持双通道)
  └── Rank（CS# 片选，一个 Rank = 一组 Bank Group）
       └── Bank Group（DDR4/5 引入）
            └── Bank（最小独立操作单元）
                 └── Row（行地址）
                      └── Column（列地址，最小寻址粒度 = BL × 数据宽度 / 8）
```

**基本操作流程**：

1. **ACTIVATE（行激活）**：打开指定 Bank 的指定 Row，将 Row 数据加载到 Sense Amplifier（行缓冲）
2. **READ/WRITE（列访问）**：在已激活的 Row 内进行 Column 读写
3. **PRECHARGE（预充电）**：关闭当前 Row，将 Sense Amplifier 数据写回，为下次 ACTIVATE 做准备
4. **REFRESH（刷新）**：周期性刷新所有 Bank 的 Row，保持数据不丢失

### 1.2 双沿采样（Double Data Rate）

DDR 在时钟的上升沿和下降沿同时采样/驱动数据信号（DQ），配合数据选通信号（DQS/DQS#）进行边沿对齐。

```
时钟 CK/CK#：  ──┐  ┌──┐  ┌──┐  ┌──
                └──┘  └──┘  └──┘
采样边沿：       ↑     ↓     ↑     ↓
DQ 数据：       D0    D1    D2    D3
```

- **写操作**：DQS 与 DQ 边沿对齐（Center-Aligned），DDR 控制器驱动
- **读操作**：DQS 与 DQ 边沿对齐（Edge-Aligned），DDR DRAM 驱动，控制器用 DQS 采样 DQ

### 1.3 预充电与刷新

| 操作 | 说明 |
|------|------|
| **PRECHARGE** | 关闭一个或全部 Bank 的当前 Row，将 Sense Amplifier 中数据写回存储阵列 |
| **Auto Refresh** | DDR 控制器周期性发出 REF 命令，DRAM 内部自动执行刷新，无需指定 Row 地址 |
| **Self Refresh** | DRAM 进入低功耗自主刷新模式，控制器不再管理刷新时序 |

---

## 2. DDR 代际对比

| 参数 | DDR3 | DDR4 | DDR5 | LPDDR4 | LPDDR5 | LPDDR5X |
|------|------|------|------|--------|--------|---------|
| **最高速率 (MT/s)** | 2133 | 3200 | 7200 | 4266 | 6400 | 8533 |
| **工作电压** | 1.5V | 1.2V | 1.1V (VDD) / 1.8V (VDDQ) | 1.1V (VDD1) / 0.6V (VDD2) | 1.05V / 0.5V | 1.05V / 0.5V |
| **数据宽度/Channel** | x4/x8/x16 | x4/x8/x16 | x4/x8/x16 | x16/x32 | x16/x32 | x16/x32 |
| **Bank 数** | 8 | 4 BG × 4 Bank = 16 | 4 BG × 4 Bank = 16 | 8 (per Channel) | 16 (per Channel) | 16 |
| **Burst Length** | 8 (BC4/BL8) | 8 (BL8) | 16 (BL16) | 16 (BL16) | 16 (BL16) | 16 |
| **Bank Group** | 无 | 有 (4 BG) | 有 (4 BG) | 无 | 无 | 无 |
| **Channel** | 单 | 单 | 双 | 双 | 双 | 双 |
| **Prefetch** | 8n | 8n | 16n | 16n | 16n | 16n |
| **ODT** | 有 (20/30/40/60/120 ohm) | 有 (240/n) | 有 (240/n) | 有 | 有 | 有 |
| **数据速率范围 (MT/s)** | 800-2133 | 1600-3200 | 3200-7200 | 1600-4266 | 3200-6400 | 4266-8533 |
| **VDDQ** | 1.5V | 1.2V | 1.1V | 0.6V | 0.5V | 0.5V |
| **CA 总线** | CMOS | CMOS | CMOS | LVSTL | LVSTL | LVSTL |
| **数据总线** | SSTL | POD | POD | LVSTL | LVSTL | LVSTL |
| **DBI** | 无 | 可选 | 标配 | 有 | 有 | 有 |
| **ECC** | 无 | 无（片外可选） | 片内 ECC | 无 | 无 | 无 |

> **说明**：
> - LPDDR4/LPDDR5 使用双通道设计，每个 Channel 独立的 CA/DQ 总线
> - DDR5 引入片内 ECC（On-Die ECC），每 128bit 数据附加 8bit ECC
> - LPDDR5X 为 LPDDR5 的超频版本，速率可达 8533 MT/s

---

## 3. 关键信号列表

### 3.1 DDR3/DDR4/DDR5 通用信号

| 信号名 | 方向 | 说明 |
|--------|------|------|
| **CK/CK#** | Controller → DRAM | 差分时钟输入，所有命令和地址在 CK 上升沿采样 |
| **CS#** | Controller → DRAM | 片选信号，低有效。拉高时 DRAM 忽略所有命令 |
| **RAS#** | Controller → DRAM | 行地址选通，与 CAS#、WE# 组合编码命令 |
| **CAS#** | Controller → DRAM | 列地址选通 |
| **WE#** | Controller → DRAM | 写使能 |
| **BA[2:0]** | Controller → DRAM | Bank 地址（DDR3）/ Bank 地址（DDR4/5，配合 BG） |
| **BG[1:0]** | Controller → DRAM | Bank Group 地址（DDR4/DDR5 引入） |
| **A[17:0]** | Controller → DRAM | 地址总线。ACTIVATE 时为 Row 地址；READ/WRITE 时为 Column 地址 |
| **DQ[15:0]** | 双向 | 数据总线，宽度取决于 x4/x8/x16 配置 |
| **DQS/DQS#** | 双向 | 差分数据选通。写操作时 Controller 驱动，读操作时 DRAM 驱动 |
| **DM/DBI#** | Controller → DRAM / 双向 | 数据掩码（DM：写时屏蔽字节）或数据总线翻转（DBI：低有效翻转） |
| **ODT** | Controller → DRAM | 片上终结使能，高有效 |
| **CKE** | Controller → DRAM | 时钟使能，低有效时进入 Power-Down 或 Self-Refresh |
| **RESET#** | Controller → DRAM | 异步复位，低有效（DDR4/DDR5 引入） |
| **ACT#** | Controller → DRAM | DDR4/DDR5：替代 RAS# 的激活命令指示，低有效 |
| **PAR** | Controller → DRAM | DDR4/DDR5：命令/地址奇偶校验 |
| **ALERT_n** | DRAM → Controller | DDR4/DDR5：CRC 错误或奇偶校验错误报警 |

### 3.2 LPDDR4/LPDDR5 特有信号

| 信号名 | 方向 | 说明 |
|--------|------|------|
| **CK_t / CK_c** | Controller → DRAM | 差分时钟（LPDDR 术语） |
| **CS[1:0]** | Controller → DRAM | 片选（LPDDR5 支持双 Rank） |
| **CA[5:0]** | Controller → DRAM | 命令/地址复用总线，6-bit。ACTIVATE 需要 2 个时钟周期传递 Row 地址 |
| **DQ[31:0]** | 双向 | 数据总线（x16 或 x32） |
| **DQS_t / DQS_c** | 双向 | 差分数据选通 |
| **DMI** | 双向 | Data Mask Inversion：写时为 DM（字节掩码），读时为 DBI（总线翻转指示） |
| **CSIT / CSIB** | DRAM → Controller | LPDDR5：DQS 调整反馈引脚 |
| **ZQ** | - | 外接校准电阻，用于 ODT/驱动阻抗校准 |

---

## 4. 命令编码表

### 4.1 DDR3/DDR4 命令编码

DDR4 用 ACT# 替代 RAS# 功能。以下为 DDR3 编码（CS#=0 前提）：

| 命令 | CS# | RAS# | CAS# | WE# | 说明 |
|------|-----|------|------|-----|------|
| **ACTIVATE** | 0 | 0 | 1 | 1 | 激活指定 Bank 的指定 Row |
| **READ** | 0 | 1 | 0 | 1 | 从指定 Column 读数据（A10=0：无自动预充电） |
| **READ w/ Auto Precharge** | 0 | 1 | 0 | 1 | A10=1：读完后自动预充电 |
| **WRITE** | 0 | 1 | 0 | 0 | 向指定 Column 写数据（A10=0） |
| **WRITE w/ Auto Precharge** | 0 | 1 | 0 | 0 | A10=1：写完后自动预充电 |
| **PRECHARGE** | 0 | 0 | 1 | 0 | 关闭 Row。A10=1 时关闭所有 Bank |
| **PRECHARGE ALL** | 0 | 0 | 1 | 0 | A[10]=1，预充电全部 Bank |
| **REFRESH** | 0 | 0 | 0 | 1 | Auto Refresh |
| **SELF REFRESH ENTRY** | 0 | 0 | 0 | 1 | CKE 拉低 + REF 命令 → 进入 Self-Refresh |
| **MRS** | 0 | 0 | 0 | 0 | Mode Register Set，通过 BA/A 地址选择 MR 和配置位 |
| **ZQCL** | 0 | 1 | 1 | 0 | ZQ 校准长（Long Calibration） |
| **ZQCS** | 0 | 1 | 1 | 0 | ZQ 校准短（Short Calibration，A10=0） |
| **DES (Deselect)** | 1 | x | x | x | 取消选择，忽略所有输入 |
| **NOP** | 0 | 1 | 1 | 1 | 无操作 |

### 4.2 DDR5 命令编码

DDR5 使用 ACT# + RAS#/CAS#/WE# 四线编码：

| 命令 | ACT# | RAS# | CAS# | WE# | 说明 |
|------|------|------|------|-----|------|
| **ACTIVATE** | 0 | x | x | x | ACT#=0 即为 ACTIVATE，RAS#/CAS#/WE# 编码 Bank 信息 |
| **READ** | 1 | 1 | 0 | 1 | 列读 |
| **WRITE** | 1 | 1 | 0 | 0 | 列写 |
| **PRECHARGE** | 1 | 0 | 1 | 0 | 预充电 |
| **REFRESH** | 1 | 0 | 0 | 1 | 自动刷新 |
| **MRS** | 1 | 0 | 0 | 0 | 模式寄存器设置 |
| **VREFCA** | 1 | 0 | 1 | 1 | CA 参考电压调整 |

### 4.3 LPDDR4/LPDDR5 命令编码（CA 总线）

LPDDR 使用 CA[5:0] 复用总线，不同命令在不同周期放置不同字段：

**LPDDR5 CA 编码（简化）**：

| 命令 | CA[5] | CA[4:0] (Cycle 1) | CA[4:0] (Cycle 2) | 说明 |
|------|-------|--------------------|--------------------|------|
| **ACTIVATE** | 0 | Bank[2:0] + Row[高位] | Row[低位] | 2-cycle 命令 |
| **READ** | 1 | Bank[2:0] + Column[高位] | Column[低位] | 2-cycle 命令 |
| **WRITE** | 1 | Bank[2:0] + Column[高位] | Column[低位] | 2-cycle 命令 |
| **PRECHARGE** | 1 | 编码 | - | 单/双 Bank |
| **REFRESH** | 1 | 编码 | - | All Bank 或 Per Bank |
| **MRW** | 1 | OP Code / MR Address | - | Mode Register Write |
| **MRR** | 1 | MR Address | - | Mode Register Read |
| **SLEEP / WAKE** | 1 | 编码 | - | 低功耗进入/退出 |
| **PDE (Power Down Entry)** | 1 | 编码 | - | 进入 Power-Down |
| **PDX (Power Down Exit)** | 1 | 编码 | - | 退出 Power-Down |

---

## 5. 读时序

### 5.1 标准读操作（ACTIVATE → READ → 数据返回）

```
时序参数：tRCD（ACT 到 READ 的最小间隔）
          CL（CAS Latency：READ 命令到第一个数据返回的延迟）
          tRP（PRECHARGE 持续时间）
          BL（Burst Length：DDR3=8, DDR4=8, DDR5=16）

     CLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
              └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

     CS#    ──┐     ┌───────────────────────────────────────┐
              └─────┘                                       └──────

     RAS#   ──┐  ┌──────────────────────────────────────────┐
              └──┘                                          └──────

     CAS#   ──────────┐  ┌──────────────────────────────────┐
                      └──┘                                  └──────

     WE#    ──────────────────────────────────────────────────────────

     BA     ──<== BK ===><======================== BK =================>
     A      ──<== ROW ===========================><== COL ============>

             |← ACTIVATE →|←  tRCD  →|← READ →|← CL →|← D0 →|← D1 →|
                                                          ↕       ↕
     DQ                                          ──────< D0 >< D1 >────
                                                  (DDR3 BL8: D0-D7)

     DQS/DQS#                                    ──┐  ┌─┐  ┌─┐  ┌──
                                                    └──┘ └──┘ └──┘

     |← tRCD (min) →|
     |←         ACT to READ minimum interval        →|
```

**DDR3/DDR4 读时序要点**：

| 参数 | 含义 | 典型值 |
|------|------|--------|
| **tRCD** | ACTIVATE 到 READ/WRITE 的最小间隔 | DDR3@1600: 13.75ns (11T) |
| **CL** | CAS Latency：READ 命令到第一个数据 DQS 切换 | DDR3@1600: CL=11 |
| **tRP** | PRECHARGE 到下一个 ACTIVATE 的最小间隔 | DDR3@1600: 13.75ns |
| **tCCD** | 连续两个 READ/WRITE 命令的最小间隔 | DDR3: 4T, DDR4: 4T (same BG) |

### 5.2 LPDDR5 读时序

```
LPDDR5 使用 CA 总线，READ 为 2-cycle 命令。

     CLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
              └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──

     CS     ──┐  ┌──────────────────────────────────────────────────┐
              └──┘                                                   └──

     CA     ──< ACT+BA+ROW_H  >< ROW_L        >< RD+BA+COL_H  >< COL_L   >
              (Cycle 1)         (Cycle 2)        (Cycle 1)        (Cycle 2)

              |←──── tRCD ─────→|               |← tCCD →|
                                                     |← RD→|←rL→|
                                                            ↕
     DQ                                                  < D0 >< D1 >
     DQS/DQS#                                             ┌─┐┌─┐
                                                           └─┘└─┘
```

---

## 6. 写时序

### 6.1 标准写操作（ACTIVATE → WRITE → 数据写入）

```
时序参数：WL（Write Latency：WRITE 命令到第一个 DQS 边沿的延迟）
          tWR（Write Recovery：最后一个写数据到 PRECHARGE 的最小间隔）
          tWTR（Write-to-Read：最后一个写数据到 READ 命令的最小间隔）

     CLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
              └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

     CS#    ──┐     ┌───────────────────────────┐
              └─────┘                           └────────────────────

     RAS#   ──┐  ┌──────────────────────────────┐
              └──┘                               └───────────────────

     CAS#   ──────────┐  ┌──────────────────────┐
                      └──┘                       └───────────────────

     WE#    ──────────┐  ┌───────────────────────┐
                      └──┘                       └───────────────────

     BA     ──<== BK ===><================= BK ======================>
     A      ──<== ROW ====================><== COL ==================>

             |← ACTIVATE →|← tRCD →|←WRITE→|← WL →|← D0 →|← D1 →|
                                                    ↕       ↕
     DQ                                   ──────< D0 >< D1 >───────
                                                    ↕       ↕
     DQS/DQS#                               ──┐  ┌─┐  ┌─┐  ┌─────
                                                └──┘ └──┘ └──┘

     DM/DBI#                                    ──<  mask  >───────

                    |← tWR →|
                              |← PRECHARGE (tRP) →|→ 下一个 ACTIVATE
```

**写时序参数**：

| 参数 | 含义 | 典型值 |
|------|------|--------|
| **WL** | Write Latency = CL - 1 (DDR3) | DDR3@1600: WL=10 |
| **tWR** | Write Recovery Time | DDR3: 15ns, DDR4: 15ns |
| **tWTR** | Write-to-Read delay | DDR3: 7.5ns (不同 Bank) |
| **tWPRE** | Write Preamble | DDR4: 1T, DDR5: 2T |

### 6.2 CRC 和 Data Mask

**写操作中的 DM（Data Mask）**：
- DM 信号与 DQ 同步，DM=1 对应的字节被屏蔽（不写入）
- 每个 DQ 字节通道对应 1-bit DM

**DDR4 CRC**：
- DDR4 可选使能 CRC，控制器在写数据末尾追加 8-bit CRC
- DRAM 校验 CRC，若错误通过 ALERT_n 信号报错

---

## 7. 刷新操作

### 7.1 Auto Refresh

```
     CLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
              └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──

     CS#    ──┐  ┌──────────────────────────────────────────┐  ┌───
              └──┘                                          └──┘

     RAS#   ──┐  ┌──────────────────────────────────────────┐
              └──┘                                          └───────

     CAS#   ──┐  ┌──────────────────────────────────────────┐
              └──┘                                          └───────

     WE#    ─────────────────────────────────────────────────────────
                    ↑                                   ↑
                 REF 命令                          下一个命令（REF 之后需等待 tRFC）
                    |←           tRFC             →|
```

**刷新时序**：

| 参数 | 含义 | 典型值 |
|------|------|--------|
| **tREFI** | 刷新间隔（Refresh Interval） | DDR3: 7.8us (正常), DDR4: 7.8us |
| **tRFC** | Refresh Cycle Time（REF 命令到下一个 ACT 的最小间隔） | DDR3-1600: 260ns, DDR4-3200: 350ns, DDR5: 295ns |
| **tRFCpb** | Per-Bank Refresh Cycle Time | DDR5 引入，小于 tRFC |

**刷新率计算**：
- DDR3/DDR4：8192 行/64ms 刷新窗口 → tREFI = 64ms / 8192 = 7.8us
- 温度补偿：高温时 tREFI 需减半（从 7.8us → 3.9us）

### 7.2 Self Refresh

```
进入 Self Refresh：
  1. 等待所有 Bank 空闲（所有 Row 已 Precharge）
  2. 发出 REFRESH 命令的同时拉低 CKE
  3. DRAM 进入 Self-Refresh，内部振荡器接管刷新时序

退出 Self Refresh：
  1. 拉高 CKE
  2. 等待 tXS（Exit Self-Refresh to any command）
  3. 发出 MRS / ZQ 校准等初始化命令（如需）
```

| 参数 | 含义 | 典型值 |
|------|------|--------|
| **tXS** | Self-Refresh Exit 到首条命令 | DDR3: tRFC + 10ns |
| **tCKSRE** | Self-Refresh Entry 后时钟稳定时间 | DDR3: 5T |

---

## 8. 模式寄存器（Mode Register）

### 8.1 DDR3 Mode Register Map

DDR3 有 4 个 Mode Register（MR0-MR3），通过 MRS 命令写入：

**MR0 — CL / BL / WR / DLL Reset**：

| Bit | 字段 | 含义 |
|-----|------|------|
| [1:0] | BL | Burst Length: 00=8(fixed), 01=4 or 8(on-the-fly), 10=BC4, 11=Reserved |
| [2] | CL[0] | CAS Latency bit 0 |
| [3] | DLL Reset | 0=No, 1=Reset DLL |
| [6:4] | CL[3:1] | CAS Latency bit 3:1 |
| [8:7] | TM | Test Mode: 00=Normal |
| [9] | DLL | DLL Control: 0=Enable, 1=Disable |
| [12:11] | WR | Write Recovery: 编码值 = (tWR/tCK) 舍入取整后的编码查表 |
| [13] | PD | Power-Down: 0=Slow Exit(ODT off), 1=Fast Exit(ODT on) |

**CL 编码示例（DDR3）**：

| CL 值 | MR0[6:4,2] 编码 |
|-------|----------------|
| 5 | 000_0 |
| 6 | 001_0 |
| 7 | 010_0 |
| 8 | 011_0 |
| 9 | 100_0 |
| 10 | 101_0 |
| 11 | 110_0 |
| 13 | 111_0 |

**MR1 — ODT / 驱动强度 / AL**：

| Bit | 字段 | 含义 |
|-----|------|------|
| [0] | DLL Enable | 0=Enable, 1=Disable |
| [5,1] | ODT | Rtt_Nom: 00=Disabled, 01=RZQ/4(60Ω), 10=RZQ/2(120Ω), 11=RZQ/6(40Ω) |
| [4:3] | AL | Posted CAS Additive Latency: 0=0, 01=CL-1, 10=CL-2 |
| [9,6,2] | DIC | Output Driver Impedance: 00=RZQ/7(34Ω), 01=RZQ/5(48Ω) |
| [12:11] | RTT_WR | Dynamic ODT: 00=Disabled, 01=RZQ/4, 10=RZQ/2 |

**MR2 — CWL / SRT / 动态 ODT**：

| Bit | 字段 | 含义 |
|-----|------|------|
| [5:3] | CWL | CAS Write Latency (编码查表) |
| [7:6] | SRT | Self-Refresh Temperature Range |
| [10:9] | RTT_WR | Dynamic ODT (Rtt_WR) |

**MR3 — MPR**：

| Bit | 字段 | 含义 |
|-----|------|------|
| [0] | MPR | Multi-Purpose Register Enable |
| [2:1] | MPR Loc | MPR Read Location |

### 8.2 DDR4/DDR5 模式寄存器

DDR4 扩展到 7 个 MR（MR0-MR6），DDR5 扩展到约 22 个 MR。核心差异：
- DDR4 引入 **DBI** 使能（MR5 bit[11]）
- DDR4 引入 **CRC** 使能（MR2 bit[12]）
- DDR5 引入 **片内 ECC** 配置
- DDR5 增加 **VREFCA/VREFDQ** 校准寄存器
- LPDDR4/LPDDR5 使用 **MRW（Mode Register Write）** 和 **MRR（Mode Register Read）**，共 256 个 MR（8-bit 地址）

---

## 9. Bank 交错（Bank Interleaving）

### 9.1 原理

Bank Interleaving 通过在不同 Bank 之间交替执行命令，**隐藏 tRCD 和 tRP 延迟**，提高总线利用率。

```
不使用 Bank Interleaving（单 Bank 串行）：

时间 →  |← ACT →|← tRCD →|← RD →|← CL+BL →|← PRE →|← tRP →|← ACT →|...
        |  B0    |  wait  |  B0  |  data   |  B0   |  wait  |  B1   |
利用率低：大量等待周期。

使用 Bank Interleaving（多 Bank 并行）：

时间 →  |← ACT →|← ACT →|← ACT →|← ACT →|← RD →|← RD →|← RD →|← RD →|
        |  B0    |  B1    |  B2    |  B3    |  B0   |  B1   |  B2   |  B3  |
                        |←── tRCD ──→|
利用率高：B1/B2/B3 的 ACT 隐藏了 B0 的 tRCD 延迟。
```

### 9.2 最佳实践

| 要点 | 说明 |
|------|------|
| **最小 Bank 数** | 至少 4 个 Bank 交替才能完全隐藏 tRCD |
| **Row 命中** | 同一 Bank 内连续访问同一 Row 时，无需重新 ACTIVATE（Row Hit） |
| **Row 冲突** | 访问不同 Row 需要 PRECHARGE + ACTIVATE（Row Conflict），引入 tRP + tRCD 延迟 |
| **调度策略** | 优先调度 Row Hit 命令，其次是 Row Empty，最后是 Row Conflict |
| **DDR4/5 Bank Group** | 不同 Bank Group 之间允许更小的 tCCD（tCCD_S），同 Bank Group 需要 tCCD_L |

### 9.3 DDR4/DDR5 Bank Group 交错

```
DDR4 tCCD_L (同 BG): 4T (default)
DDR4 tCCD_S (不同 BG): 4T (但时序要求更宽松)

BG0:  RD ──────────── RD ────────────
BG1:      RD ──────────── RD ────────
BG2:         RD ──────────── RD ─────
BG3:            RD ──────────── RD ───

通过交错 BG，即使 tCCD_L 较大也能保持 DQ 总线连续输出。
```

---

## 10. 时序参数表

### 10.1 DDR3 @1600 MT/s (CL11) 典型值

| 参数 | 含义 | 典型值 | 单位 |
|------|------|--------|------|
| **tRCD** | ACT to READ/WRITE | 13.75 | ns |
| **tRP** | PRECHARGE period | 13.75 | ns |
| **tRAS** | ACT to PRECHARGE (minimum) | 35 | ns |
| **tRC** | ACT to ACT (same Bank) = tRAS + tRP | 48.75 | ns |
| **tRFC** | REFRESH cycle time | 260 | ns |
| **tCCD** | Column to Column delay | 4 | Tck |
| **tWR** | Write recovery time | 15 | ns |
| **tRTP** | READ to PRECHARGE | 7.5 | ns |
| **tFAW** | Four ACTIVATE Window | 35 | ns |
| **tRRD** | ACT to ACT (different Bank) | 7.5 | ns |
| **tREFI** | REFRESH interval | 7.8 | us |
| **tXPDLL** | Exit power-down (DLL on) | 10 | Tck |
| **tCKE** | CKE pulse width (min) | 5 | Tck |
| **tDAL** | Auto-precharge WR + PRE | WR + tRP (in Tck) | Tck |

### 10.2 DDR4 @3200 MT/s (CL22) 典型值

| 参数 | 含义 | 典型值 | 单位 |
|------|------|--------|------|
| **tRCD** | ACT to READ/WRITE | 13.75 | ns |
| **tRP** | PRECHARGE period | 13.75 | ns |
| **tRAS** | ACT to PRECHARGE (minimum) | 32 | ns |
| **tRC** | ACT to ACT | 45.75 | ns |
| **tRFC** | REFRESH cycle time | 350 | ns |
| **tRFCpb** | Per-Bank REFRESH cycle | 160 | ns |
| **tCCD_L** | Column to Column (same BG) | 8 | Tck |
| **tCCD_S** | Column to Column (diff BG) | 4 | Tck |
| **tWR** | Write recovery time | 15 | ns |
| **tRTP** | READ to PRECHARGE | 7.5 | ns |
| **tFAW** | Four ACTIVATE Window | 28 | ns |
| **tRRD_L** | ACT to ACT (same BG) | 6.4 | ns |
| **tRRD_S** | ACT to ACT (diff BG) | 4 | ns |

### 10.3 DDR5 @5600 MT/s (CL40) 典型值

| 参数 | 含义 | 典型值 | 单位 |
|------|------|--------|------|
| **tRCD** | ACT to READ/WRITE | 14.25 | ns |
| **tRP** | PRECHARGE period | 14.25 | ns |
| **tRAS** | ACT to PRECHARGE | 32 | ns |
| **tRC** | ACT to ACT | 46.25 | ns |
| **tRFC** | REFRESH cycle time | 295 | ns |
| **tRFCpb** | Per-Bank REFRESH | 110 | ns |
| **tCCD_L** | Column to Column (same BG) | 8 | Tck |
| **tCCD_S** | Column to Column (diff BG) | 4 | Tck |
| **tWR** | Write recovery | 30 | ns |
| **tRTP** | READ to PRECHARGE | 7.5 | ns |
| **tFAW** | Four ACTIVATE Window | 20 | ns |
| **tRRD_L** | ACT to ACT (same BG) | 5.625 | ns |
| **tRRD_S** | ACT to ACT (diff BG) | 3.75 | ns |

### 10.4 LPDDR5 @6400 MT/s 典型值

| 参数 | 含义 | 典型值 | 单位 |
|------|------|--------|------|
| **tRCD** | ACT to READ/WRITE | 18 | ns |
| **tRP** | PRECHARGE period | 18 | ns |
| **tRAS** | ACT to PRECHARGE | 42 | ns |
| **tRCpb** | ACT to ACT (same Bank) | 18 | ns |
| **tRFCab** | All-Bank REFRESH | 180 | ns |
| **tRFCpb** | Per-Bank REFRESH | 90 | ns |
| **tCCD** | Column to Column | 8 | Tck |
| **tWR** | Write recovery | 18 | ns |
| **tRTP** | READ to PRECHARGE | 7.5 | ns |
| **tFAW** | Four ACTIVATE Window | 30 | ns |
| **tRRD** | ACT to ACT (diff Bank) | 10 | ns |

---

## 11. 数据训练（Data Training）

数据训练是 DDR 初始化过程中的关键步骤，用于补偿 PCB 走线延迟差异和信号完整性问题。

### 11.1 Write Leveling

**目的**：调整每个 DQS 对 CK 的延迟，使所有 DQS 的到达时间一致（补偿 PCB 长度差异）。

```
流程：
  1. 控制器通过 MRS 使能 Write Leveling 模式（DDR3 MR1 bit[7]=1）
  2. DRAM 将 DQ[0] 配置为输出反馈信号
  3. 控制器发送 DQS 脉冲，DRAM 在 CK 上升沿采样 DQS
  4. DRAM 将采样结果输出到 DQ[0]
  5. 控制器读取 DQ[0]，调整 DQS 延迟
  6. 反复迭代直到 DQ[0] 从 0→1 跳变，记录该延迟值

     CK     ──┐  ┌──┐  ┌──┐  ┌──┐
              └──┘  └──┘  └──┘  └──┘

     DQS    ────────────────┐  ┌────────────  (Controller 发送)
                             └──┘

     DQ[0]  ────────────────────────< 1 >────  (DRAM 反馈采样结果)
                                        ↑
                                  DQS 被 CK 上升沿采样成功
```

### 11.2 Read DQ Calibration

**目的**：训练读数据采样中心点，补偿 DQ 与 DQS 之间的偏移（skew）。

```
流程：
  1. DRAM 通过 MPR（Multi-Purpose Register）发送已知数据模式
  2. 控制器在不同 DQS 延迟设置下读取 DQ
  3. 找到数据有效窗口的中心点
  4. 将 DQS 延迟设置为窗口中心

     有效窗口示意（眼图）：

     DQS delay:  -4  -3  -2  -1   0  +1  +2  +3  +4
     读取结果:    0    0    1    1    1    1    1    0    0
                        |←─ 有效窗口 (5 个 step) ─→|
                                    ↑
                              采样中心 = delay 0
```

### 11.3 CA Training（LPDDR4/LPDDR5）

**目的**：训练 CA 总线的时序，使控制器和 DRAM 对 CA 信号的采样点对齐。

```
流程：
  1. 控制器通过 MRW 使能 CA Training 模式
  2. 控制器发送 CA 训练模式（交替 010101...）
  3. DRAM 通过 DQ 总线反馈 CA 采样结果
  4. 控制器调整 CA 输出延迟，找到有效窗口
```

### 11.4 DDR5 新增训练

DDR5 引入更多训练项：
- **DFE Training**：Decision Feedback Equalization 训练
- **Receiver Training**：接收端均衡器系数优化
- **Duty Cycle Correction**：时钟占空比校正
- **Coarse Write Training**：粗粒度写训练（减少细调迭代次数）

---

## 12. LPDDR 特性

### 12.1 低功耗设计

| 特性 | 说明 |
|------|------|
| **双通道架构** | LPDDR4/5 采用双独立 Channel，可独立控制功耗 |
| **低电压** | VDDQ = 0.6V (LPDDR4) / 0.5V (LPDDR5)，远低于 DDR 的 1.1-1.5V |
| **VDD2 分离** | LPDDR4 将 I/O 电压 (VDDQ=0.6V) 与核心电压 (VDD1=1.1V) 分离 |
| **DBI（Data Bus Inversion）** | 当翻转数据总线可减少 0 的数量时自动翻转，降低功耗 |
| **DVFS** | 动态电压频率缩放，运行时可切换速率/电压等级 |

### 12.2 低功耗状态

```
                    正常操作
                       │
           ┌───────────┼───────────┐
           ▼           ▼           ▼
        Power-Down   Deep Sleep   Self-Refresh
        (CKE=0,      (CKE=0,     (CKE=0,
         CLK on)      CLK off)    CLK off, 内部刷新)
           │           │           │
           └───────────┼───────────┘
                       ▼
                  唤醒 (CKE=1)
                       │
                  等待 tXP/tXSR
                       │
                  恢复正常操作
```

| 状态 | 进入方式 | 功耗 (typ.) | 唤醒延迟 |
|------|---------|------------|---------|
| **Active** | 正常操作 | ~100mW | - |
| **Power-Down** | CKE=0, CLK 保持 | ~30mW | tXP: ~7.5ns (LPDDR5) |
| **Deep Sleep** | CKE=0, CLK 停止 | ~10mW | tXSR: ~180ns (LPDDR5) |
| **Self-Refresh** | CKE=0 + 命令 | ~5mW | tXSR: ~180ns |
| **Hibernate** | 最低功耗保留模式 | <1mW | ~1ms（DDR5） |

### 12.3 数据总线翻转（DBI）

```
DBI 原理：当一组数据中 0 的数量 > 50% 时，翻转整个数据并拉低 DBI 信号。

原始数据:    8'b0000_1111  (4个0, 4个1) → DBI=1, 不翻转
原始数据:    8'b0000_0011  (6个0, 2个1) → DBI=0, 翻转为 8'b1111_1100

效果：减少总线上的 0 翻转次数 → 降低动态功耗
适用：LPDDR4/LPDDR5 和 DDR4（可选）/DDR5（标配）
```

### 12.4 LPDDR5 新特性

| 特性 | 说明 |
|------|------|
| **WCK（Write Clock）** | 引入差分 Write Clock (WCK_t/WCK_c)，用于数据采样，CK 仅用于 CA |
| **读写速率解耦** | WCK 频率可以与 CK 频率不同，支持读写不同速率 |
| **Burst Length** | 固定 BL16，32B 突发（x16） |
| **ECC** | LPDDR5X 支持 Link ECC（可选） |
| **DFI 5.0** | 支持 DFI 5.0 接口规范 |

---

## 13. DDR 控制器设计要点

### 13.1 总体架构

```
              ┌──────────────────────────────────────────────┐
              │              DDR Controller                   │
              │                                              │
  AXI4 ──────→│  ┌──────────┐  ┌───────────┐  ┌──────────┐ │──→ DDR PHY ──→ DRAM
  Slave Port  │  │ AXI      │  │ Command   │  │ Timing   │ │
              │  │ Bridge   │→│ Scheduler │→│ Checker  │ │
              │  │ (Reorder)│  │ (Queue)   │  │ (Enforce)│ │
              │  └──────────┘  └───────────┘  └──────────┘ │
              │       ↑              ↑              ↑       │
              │  ┌──────────┐  ┌───────────┐  ┌──────────┐ │
              │  │ Bank     │  │ Refresh   │  │ ZQ Cal   │ │
              │  │ State    │  │ Manager   │  │ Manager  │ │
              │  │ Tracker  │  │           │  │          │ │
              │  └──────────┘  └───────────┘  └──────────┘ │
              └──────────────────────────────────────────────┘
```

### 13.2 调度算法

| 算法 | 说明 | 适用场景 |
|------|------|---------|
| **FR-FCFS** | First-Ready First-Come First-Served。优先执行 Row Hit 命令，同优先级按到达顺序 | 通用，带宽利用率高 |
| **Bank-Parallel** | 各 Bank 独立队列，并行调度 | 高带宽场景 |
| **Read-Write-Read** | 将连续读/写分组，减少总线方向切换开销（tWTR/tRTW 开销） | 吞吐优化 |
| **Priority-based** | 命令分级：紧急刷新 > 数据完整性命令 > 读 > 写 > 刷新 > 空闲 | 实时性要求高 |

### 13.3 命令队列

```verilog
// 命令队列条目示例
typedef struct {
    logic [ADDR_WIDTH-1:0]  addr;       // 完整物理地址
    logic [2:0]             bank;       // Bank 地址
    logic [1:0]             bg;         // Bank Group (DDR4/5)
    logic [ROW_WIDTH-1:0]   row;        // Row 地址
    logic [COL_WIDTH-1:0]   col;        // Column 地址
    logic                   is_write;   // 1=Write, 0=Read
    logic [7:0]             burst_len;  // 突发长度
    logic [1:0]             priority;   // 优先级
    logic                   row_hit;    // Row 缓存命中标记
    logic                   valid;      // 条目有效
} cmd_queue_entry_t;
```

### 13.4 Bank 状态管理

每个 Bank 维护一个状态机：

```
Idle → Active → (读写操作) → Precharge → Idle
  ↑                                   │
  └─── tRP ───────────────────────────┘

状态变量（per Bank）：
  - current_row: 当前激活的 Row（无效时表示 Idle 状态）
  - activate_time: 最近 ACTIVATE 的时间戳（用于检查 tRAS/tRC）
  - read_time / write_time: 最近读写时间（用于检查 tRTP/tWR）

Row Hit 判断：
  incoming_addr.row == bank[i].current_row → Row Hit
  bank[i].current_row == INVALID → Row Empty
  else → Row Conflict
```

### 13.5 时序校验（Timing Checker）

在发出命令前，必须检查以下时序约束：

| 检查项 | 条件 | 违规后果 |
|--------|------|---------|
| ACT → ACT (同一 Bank) | elapsed >= tRC | 数据损坏 |
| ACT → READ/WRITE | elapsed >= tRCD | 读写失败 |
| ACT → PRE | elapsed >= tRAS | 数据丢失 |
| PRE → ACT | elapsed >= tRP | 行冲突 |
| REF → ACT | elapsed >= tRFC | 刷新未完成 |
| WR → PRE | elapsed >= tWR | 写数据丢失 |
| RD → PRE | elapsed >= tRTP | 读数据丢失 |
| 4 ACT 窗口 | 4 个 ACT 在 tFAW 内 | 过多激活电流 |
| ACT-ACT (不同 Bank) | elapsed >= tRRD | 过多激活电流 |
| RD → WR | elapsed >= tRTW | 总线方向切换 |
| WR → RD | elapsed >= tWTR | 写数据未完成 |

### 13.6 刷新管理

```
刷新策略：
  1. 维护 tREFI 计数器（每个 Bank 独立或全局）
  2. 计数器到达 tREFI - 安全裕量时，调度刷新命令
  3. 发出 REF 命令后，冻结该 Bank（或所有 Bank）直到 tRFC 到期
  4. DDR4/5 支持 Per-Bank Refresh（tRFCpb < tRFC），减少阻塞
  5. 紧急刷新：tREFI 超时时发出 All-Bank Refresh

刷新窗口计算：
  每 64ms 需要刷新 8192 行 → tREFI = 7.8us
  实际控制器中使用 7.8us × 0.9 = 7.02us 作为调度点（留 10% 裕量）
```

---

## 14. 与 AXI 接口的桥接

### 14.1 系统级框图

```
┌──────────┐    AXI4     ┌───────────────┐    DFI     ┌──────────┐    DDR Bus    ┌──────────┐
│  CPU /   │───────────→│ DDR Controller │──────────→│ DDR PHY  │────────────→│ DDR/LPDDR│
│  DMA /   │            │               │            │          │             │  DRAM    │
│  GPU     │←───────────│               │←───────────│          │←────────────│          │
└──────────┘  Response   └───────────────┘  Read Data └──────────┘  Read Data  └──────────┘
```

### 14.2 AXI → DDR 地址映射

```
AXI 地址（如 32-bit）映射到 DDR 物理地址空间：

  AXI Addr[31:0]
    ├─ [31:COL_BITS+ROW_BITS+BG_BITS+BA_BITS] → Rank/Channel 选择
    ├─ [ROW_BITS+COL_BITS+BG_BITS+BA_BITS-1 : COL_BITS+BG_BITS+BA_BITS] → ROW
    ├─ [BG_BITS+BA_BITS-1 : BA_BITS] → Bank Group
    ├─ [BA_BITS-1 : 0] → Bank
    └─ [COL_BITS-1 : 0] → Column（通常最低位对齐到 Burst 长度）

典型映射（DDR4, 1GB, x8, BG+BA=6, COL=10, ROW=14）：
  Addr[9:0]   → Column[9:0]
  Addr[15:10] → Bank[3:0] (含 BG)
  Addr[29:16] → Row[13:0]
  Addr[31:30] → Rank
```

### 14.3 DFI 接口

DFI（DDR PHY Interface）是控制器与 PHY 之间的标准接口，由 JEDEC 定义。

| DFI 信号组 | 说明 |
|-----------|------|
| **dfi_address** | 地址/命令总线 |
| **dfi_bank** | Bank 地址 |
| **dfi_cs_n** | 片选 |
| **dfi_ras_n, dfi_cas_n, dfi_we_n** | 命令编码 |
| **dfi_wrdata_en** | 写数据使能 |
| **dfi_wrdata** | 写数据 |
| **dfi_wrdata_mask** | 写数据掩码 |
| **dfi_rddata_en** | 读数据使能 |
| **dfi_rddata** | 读数据 |
| **dfi_rddata_valid** | 读数据有效 |
| **dfi_ctrlupd_req/ack** | PHY 控制更新握手 |
| **dfi_init_complete** | PHY 初始化完成 |
| **dfi_phylvl_req_cs_n/ack** | Write Leveling 握手 |

### 14.4 关键桥接逻辑

```
AXI 突发 → DDR Burst 拆分：
  - AXI burst length (1-256) → DDR burst (BL8/BL16)
  - AXI INCR burst 跨越 Row 边界 → 拆分为多个 DDR 命令（PRE + ACT + RD/WR）
  - AXI burst 跨越 Burst Length 边界 → 拆分为多个 DDR burst

字节选通映射：
  AXI WSTRB[DATA_WIDTH/8-1:0] → DDR DM[DATA_WIDTH/8-1:0]

AXI ID 保序：
  - AXI 要求相同 ID 的事务保序
  - DDR 控制器可乱序调度不同 ID 的事务
  - 需要 AXI Reorder Buffer 保证返回顺序正确
```

### 14.5 带宽计算

```
有效带宽 = 总线速率 × 数据宽度 / 8 × 效率

示例（DDR4-3200, x64, 双 Rank）：
  理论峰值 = 3200 MT/s × 64 bit / 8 = 25.6 GB/s
  实际效率：
    - 命令开销（ACT/PRE/REF）：~10%
    - Row Conflict 开销：~5%（取决于 workload）
    - 总线方向切换（RD↔WR）：~5%
    - 典型效率：70-85%
  有效带宽 = 25.6 × 0.80 = 20.5 GB/s（典型值）

效率优化手段：
  1. Bank Interleaving：减少 tRCD/tRP 等待
  2. Read/Write grouping：减少总线方向切换
  3. Open/Close Page 策略选择：根据访问模式
  4. 优先级调度：Row Hit 优先
```

---

## 附录 A. 缩略语

| 缩写 | 全称 |
|------|------|
| BL | Burst Length |
| BG | Bank Group |
| CA | Command/Address |
| CL | CAS Latency |
| CWL | CAS Write Latency |
| DBI | Data Bus Inversion |
| DFI | DDR PHY Interface |
| DM | Data Mask |
| DQ | Data |
| DQS | Data Strobe |
| DRAM | Dynamic Random-Access Memory |
| ICG | Integrated Clock Gating |
| LPDDR | Low Power DDR |
| MR / MRS | Mode Register / Mode Register Set |
| MRW / MRR | Mode Register Write / Mode Register Read |
| MPR | Multi-Purpose Register |
| MT/s | Mega Transfers per second |
| ODT | On-Die Termination |
| PHY | Physical Layer |
| PRE | Precharge |
| tCCD | Column-to-Column Delay |
| tCK | Clock Cycle Time |
| tFAW | Four Activate Window |
| tRAS | Row Active to Precharge |
| tRC | Row Cycle Time |
| tRCD | Row to Column Delay |
| tRFC | Refresh Cycle Time |
| tRP | Row Precharge Time |
| tRTP | Read to Precharge |
| tRRD | Row to Row Delay |
| tWR | Write Recovery |
| tWTR | Write to Read |
| ZQ | Impedance Calibration |

## 附录 B. 参考文档

| 文档 | 版本 | 说明 |
|------|------|------|
| JESD79-3F | DDR3 SDRAM Specification | JEDEC |
| JESD79-4C | DDR4 SDRAM Specification | JEDEC |
| JESD79-5B | DDR5 SDRAM Specification | JEDEC |
| JESD209-4C | LPDDR4 SDRAM Specification | JEDEC |
| JESD209-5B | LPDDR5 SDRAM Specification | JEDEC |
| DFI 5.0 | DDR PHY Interface Specification | Synopsys/Cadence |
