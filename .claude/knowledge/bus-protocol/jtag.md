# JTAG (IEEE 1149.1) 接口协议

> **用途**：芯片测试与调试标准接口，支持边界扫描和内部调试访问
> **规范版本**：IEEE Std 1149.1-2013（最新修订），首次发布 1990 年
> **典型应用**：PCB 边界扫描测试、芯片内部调试、FPGA 编程、SoC 调试（ARM CoreSight）

---

## 1. 协议概述

IEEE 1149.1 标准（俗称 JTAG，源自 Joint Test Action Group）定义了一套标准化的测试访问机制，核心包括 **Test Access Port（TAP）** 和 **TAP 控制器**。

**核心目标**：

| 目标 | 说明 |
|------|------|
| 边界扫描测试 | 通过 BSR（Boundary Scan Register）测试 PCB 连线，无需物理探针 |
| 内部调试 | 通过扫描链访问芯片内部寄存器、断点、单步执行等 |
| 编程下载 | FPGA bitstream 加载、Flash 编程 |
| JTAG Chain | 多芯片菊花链级联，共享 4/5 根信号线 |

**系统架构**：

```
┌──────────────────────────────────────────────────┐
│                   Test System (Host)              │
│  ┌─────────────────────────────────────────────┐ │
│  │   JTAG Adapter (USB-Blaster / J-Link / DAP) │ │
│  └──────────────────┬──────────────────────────┘ │
│                     │ TCK / TMS / TDI / TDO / TRST# │
└─────────────────────┼────────────────────────────┘
                      │
          ┌───────────▼───────────┐
          │     TAP Controller    │
          │  ┌─────────────────┐  │
          │  │ Instruction Reg │  │
          │  └────────┬────────┘  │
          │           │           │
          │  ┌────────▼────────┐  │
          │  │  Data Register  │  │
          │  │ (BSR/ID/Bypass) │  │
          │  └────────┬────────┘  │
          │           │           │
          │  ┌────────▼────────┐  │
          │  │   Core Logic    │  │
          │  └─────────────────┘  │
          └───────────────────────┘
```

---

## 2. 信号定义

### 2.1 TAP 信号表

| 信号 | 全称 | 方向（外部视角） | 说明 |
|------|------|------------------|------|
| **TCK** | Test Clock | Host → Device | 测试时钟，独立于系统时钟，由外部 JTAG 适配器提供 |
| **TMS** | Test Mode Select | Host → Device | 模式选择，TCK 上升沿采样，控制 TAP 状态机跳转 |
| **TDI** | Test Data In | Host → Device | 数据输入（进入芯片），TCK 上升沿采样 |
| **TDO** | Test Data Out | Device → Host | 数据输出（离开芯片），TCK 下降沿驱动 |
| **TRST#** | Test Reset | Host → Device | 测试复位，低有效异步复位 TAP 控制器（可选） |

> **注意**：TRST# 为可选信号。无 TRST# 时，TMS 持续高电平 5 个 TCK 周期可将 TAP 控制器复位到 Test-Logic-Reset 状态。

### 2.2 信号电气特性

| 参数 | 最小值 | 典型值 | 最大值 | 单位 | 说明 |
|------|--------|--------|--------|------|------|
| TCK 频率 | DC | 10 | 50+ | MHz | 取决于目标芯片 |
| TDI/TMS setup | 5 | - | - | ns | 相对 TCK 上升沿 |
| TDI/TMS hold | 5 | - | - | ns | 相对 TCK 上升沿 |
| TDO 输出延迟 | - | - | 15 | ns | 相对 TCK 下降沿 |

---

## 3. TAP 控制器状态机

TAP 控制器是一个 **16 状态** 的有限状态机，由 TMS 信号在 TCK 上升沿驱动状态转移。

### 3.1 状态定义

| 状态 | 编码 | 说明 |
|------|------|------|
| Test-Logic-Reset | S0 | 所有测试逻辑被复位，正常系统功能不受影响 |
| Run-Test/Idle | S1 | 空闲状态，或执行内建自测试（BIST） |
| Select-DR-Scan | S2 | 选择 DR 扫描或 IR 扫描的分支点 |
| Capture-DR | S3 | 将数据并行加载到选定的 DR |
| Shift-DR | S4 | 数据在 TDI→TDO 之间串行移位 |
| Exit1-DR | S5 | 退出 DR 扫描或转入 Pause |
| Pause-DR | S6 | 暂停 DR 数据移位 |
| Exit2-DR | S7 | 从 Pause 恢复或退出 DR 扫描 |
| Update-DR | S8 | 将移位寄存器内容锁存到更新寄存器 |
| Select-IR-Scan | S9 | 进入 IR 扫描分支 |
| Capture-IR | S10 | 将固定值加载到 IR 移位寄存器 |
| Shift-IR | S11 | IR 数据串行移位 |
| Exit1-IR | S12 | 退出 IR 扫描或转入 Pause |
| Pause-IR | S13 | 暂停 IR 数据移位 |
| Exit2-IR | S14 | 从 Pause 恢复或退出 IR 扫描 |
| Update-IR | S15 | 将移位寄存器内容锁存到 IR 更新寄存器 |

### 3.2 状态转移图（ASCII）

```
                          TMS=1 at every TCK↑
                    ┌──────────────────────────────────┐
                    │                                  ▼
               ┌────┴────┐   TMS=0   ┌────────────┐   │
          ┌───►│Test-Logic│◄─────────►│Run-Test/   │   │
          │    │  Reset   │           │  Idle      ├───┘
          │    └────┬─────┘           └─────┬──────┘   ▲
          │         │ TMS=1                 │ TMS=1    │
          │         ▼                       ▼          │
          │    ┌──────────┐          ┌─────────────┐   │
          │    │Select-DR─│          │Select-IR─   │   │
          │    │  Scan    │          │  Scan       │   │
          │    └─┬──────┬─┘          └─┬────────┬──┘   │
          │      │      │              │        │      │
          │  TMS=0  TMS=1          TMS=0   TMS=1      │
          │      │      │              │        │      │
          │      ▼      └──────────────┘        │      │
          │  ┌─────────┐         ┌──────────┐   │      │
          │  │Capture─ │         │Capture─  │   │      │
          │  │  DR     │         │  IR      │   │      │
          │  └────┬────┘         └────┬─────┘   │      │
          │       │                   │         │      │
          │   TMS=0               TMS=0        │      │
          │       ▼                   ▼         │      │
          │  ┌─────────┐         ┌──────────┐   │      │
          │  │Shift─   │         │Shift─    │   │      │
          │  │  DR     │         │  IR      │   │      │
          │  └───┬──┬──┘         └──┬───┬───┘   │      │
          │     │  │                 │   │       │      │
          │ TMS=0  TMS=1          TMS=0  TMS=1  │      │
          │     │  │                 │   │       │      │
          │     │  ▼                 │   ▼       │      │
          │     │ ┌──────────┐      │ ┌─────────┐│      │
          │     │ │Exit1─DR  │      │ │Exit1─IR ││      │
          │     │ └─┬─────┬──┘      │ └─┬────┬──┘│      │
          │     │   │     │         │   │    │   │      │
          │  TMS=0  TMS=1        TMS=0  TMS=1   │      │
          │     │   │     │         │   │    │   │      │
          │     ▼   │     │         ▼   │    │   │      │
          │ ┌───────┴┐    │     ┌───────┴┐   │   │      │
          │ │Pause─DR │    │     │Pause─IR│   │   │      │
          │ └───┬──┬──┘    │     └──┬──┬─┘   │   │      │
          │     │  │       │        │  │     │   │      │
          │  TMS=0  TMS=1        TMS=0  TMS=1│   │      │
          │     │  │       │        │  │     │   │      │
          │     │  ▼       │        │  ▼     │   │      │
          │     │ ┌───────┴──┐     │ ┌──────┴┐  │      │
          │     │ │Exit2─DR  │     │ │Exit2─IR│  │      │
          │     │ └────┬─────┘     │ └───┬────┘  │      │
          │     │      │           │     │       │      │
          │     │   TMS=1→Select─DR  TMS=1→Select─IR    │
          │     ▼      │           ▼     │       │      │
          │ ┌──────────┴─┐    ┌──────────┴─┐     │      │
          │ │Update─DR   │    │Update─IR   │     │      │
          │ └──────┬─────┘    └──────┬─────┘     │      │
          │        │                 │            │      │
          │   TMS=1→Select─DR   TMS=1→Select─DR  │      │
          │        └─────────────────┴────────────┘      │
          │                                              │
          └────────────── TMS=1 (5 cycles) ──────────────┘
```

**转移规则总结**：

- TMS = 0：在各分支中向深处走（Capture → Shift → ...）
- TMS = 1：向上/退出方向走（返回 Select-DR 或 Test-Logic-Reset）
- **复位**：TMS 连续为 1 达 5 个 TCK 周期，自动回到 Test-Logic-Reset

### 3.3 状态转移表

| 当前状态 | TMS=0 | TMS=1 |
|----------|-------|-------|
| Test-Logic-Reset | Run-Test/Idle | Test-Logic-Reset |
| Run-Test/Idle | Run-Test/Idle | Select-DR-Scan |
| Select-DR-Scan | Capture-DR | Select-IR-Scan |
| Capture-DR | Shift-DR | Exit1-DR |
| Shift-DR | Shift-DR | Exit1-DR |
| Exit1-DR | Pause-DR | Update-DR |
| Pause-DR | Pause-DR | Exit2-DR |
| Exit2-DR | Shift-DR | Update-DR |
| Update-DR | Run-Test/Idle | Select-DR-Scan |
| Select-IR-Scan | Capture-IR | Test-Logic-Reset |
| Capture-IR | Shift-IR | Exit1-IR |
| Shift-IR | Shift-IR | Exit1-IR |
| Exit1-IR | Pause-IR | Update-IR |
| Pause-IR | Pause-IR | Exit2-IR |
| Exit2-IR | Shift-IR | Update-IR |
| Update-IR | Run-Test/Idle | Select-DR-Scan |

---

## 4. 指令寄存器（IR）

### 4.1 IR 结构

IR 用于选择当前操作的数据寄存器。每次 IR 扫描将新的指令串行移入，Update-IR 锁存后生效。

```
TDI → [IR_shift_reg] → Bypass/DR → TDO
              │
              ▼ (Update-IR)
         IR_update_reg → DR 选择信号
```

### 4.2 标准指令集

| 指令 | IR 编码（默认） | 选择的 DR | 说明 |
|------|-----------------|-----------|------|
| **BYPASS** | 全 1 | BYPASS Register | 1-bit 旁路寄存器，数据 1 cycle 延迟通过 |
| **EXTEST** | 全 0 | BSR | 外部引脚测试：输出引脚驱动测试向量，输入引脚捕获响应 |
| **SAMPLE/PRELOAD** | `...0010` | BSR | 采样内部信号（不影响系统功能）或预加载 BSR |
| **INTEST** | `...0110` | BSR | 内部逻辑测试：BSR 驱动内部节点，捕获内部响应 |
| **IDCODE** | `...0010` | IDCODE Register | 读取芯片 32-bit ID（厂家、版本、Part Number） |
| **CLAMP** | `...0011` | BYPASS | 输出引脚保持 BSR 预加载值 |
| **HIGHZ** | `...0101` | BYPASS | 所有输出引脚置高阻 |
| **USERCODE** | `...1000` | USERCODE Register | 读取用户可编程编码（FPGA 常用） |

> **注意**：EXTEST 选择 BSR 作为 DR，但 TDO 输出的是 BSR 链的数据。BYPASS 在 IR 编码全 1 时自动选中。

### 4.3 IR 位宽

- 最小宽度：2 bit（必须支持 EXTEST、BYPASS、SAMPLE/PRELOAD）
- 实际宽度：取决于芯片实现，通常 4~32 bit
- 未实现的指令编码默认选中 BYPASS 寄存器

---

## 5. 数据寄存器（DR）

### 5.1 必需的数据寄存器

| 寄存器 | 说明 | 位宽 |
|--------|------|------|
| **BYPASS** | 1-bit 移位寄存器，指令无关时选中，数据延迟 1 TCK | 1 bit |
| **BSR**（Boundary Scan Register） | 边界扫描寄存器，每个 I/O pad 一个 cell | I/O 数量 × 1 bit |
| **IDCODE** | 32-bit 芯片标识寄存器 | 32 bit |

### 5.2 IDCODE 格式（32-bit）

```
Bit[31:28]    Bit[27:12]    Bit[11:1]      Bit[0]
┌──────────┐ ┌───────────┐ ┌─────────────┐ ┌───┐
│ Version  │ │ Part Num  │ │ Manufacturer│ │ 1 │
│  (4 bit) │ │  (16 bit) │ │   (11 bit)  │ │   │
└──────────┘ └───────────┘ └─────────────┘ └───┘
```

| 字段 | 位域 | 说明 |
|------|------|------|
| Version | [31:28] | 芯片版本号，0x0 = Rev A |
| Part Number | [27:12] | 芯片型号编码（厂家自定义） |
| Manufacturer | [11:1] | JEDEC Manufacturer ID（如 ARM = 0x23B） |
| LSB | [0] | 固定为 1（标识为 IDCODE 寄存器） |

### 5.3 BSR（Boundary Scan Register）结构

```
        Core Logic
    ┌───────────────┐
    │               │
    │  ┌────────┐   │
    │  │        │   │
───►│BSR│→──►│BSR│───► Output Pin
Pin │In │   │Out│
───►│   │   │   │
    └────────┘   │
        ▲        │
        └────────┘
```

每个 I/O pad 包含至少一个 BS Cell：
- **Input Cell**：捕获输入引脚信号
- **Output Cell**：控制输出引脚驱动值
- **Bidirectional Cell**：兼具输入/输出功能
- **Control Cell**：控制输出使能（OE）

---

## 6. 扫描操作流程

### 6.1 IR 扫描（Instruction Register Scan）

用于加载新指令到 IR。

```
状态转移路径：
Test-Logic-Reset → Run-Test/Idle
    → Select-DR-Scan → Select-IR-Scan
    → Capture-IR → Shift-IR (N cycles) → Exit1-IR → Update-IR
    → Run-Test/Idle

时序：
         Capture-IR    Shift-IR (N bits)     Update-IR
              │              │                  │
              ▼              ▼                  ▼
TCK:  ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
        └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
TMS:  ──0──0──0──0──0──0──0──0──0──0──0──0──1──1──1──
TDI:  ──[bit0]──[bit1]──[bit2]──...──[bitN-1]────────
TDO:  ──────[lsb0]──[lsb1]──[lsb2]──...──[lsbN-1]────
              ◄────── N TCK cycles ──────►
```

**操作步骤**：
1. 从 Run-Test/Idle 出发，TMS=1 进入 Select-DR-Scan
2. TMS=1 进入 Select-IR-Scan
3. TMS=0 进入 Capture-IR（固定值加载到 IR 移位寄存器）
4. TMS=0 进入 Shift-IR，串行移入 N bit 指令（最低位先入）
5. 最后 1 bit 时 TMS=1 进入 Exit1-IR
6. TMS=1 进入 Update-IR（指令锁存，DR 选择切换）
7. TMS=0 回到 Run-Test/Idle

### 6.2 DR 扫描（Data Register Scan）

用于对当前 IR 选中的 DR 进行移位操作。

```
状态转移路径：
Run-Test/Idle → Select-DR-Scan
    → Capture-DR → Shift-DR (M cycles) → Exit1-DR → Update-DR
    → Run-Test/Idle

时序：
         Capture-DR    Shift-DR (M bits)     Update-DR
              │              │                  │
              ▼              ▼                  ▼
TCK:  ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
        └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
TMS:  ──0──0──0──0──0──0──0──0──0──0──0──0──1──1──1──
TDI:  ──[bit0]──[bit1]──[bit2]──...──[bitM-1]────────
TDO:  ──────[lsb0]──[lsb1]──[lsb2]──...──[lsbM-1]────
              ◄────── M TCK cycles ──────►
```

### 6.3 典型调试操作序列

```
1. IR 扫描：写入 IDCODE 指令
   Run-Test/Idle → ... → Shift-IR → 移入 IDCODE → Update-IR

2. DR 扫描：读取 IDCODE（TDI 送任意值，TDO 读回 ID）
   Run-Test/Idle → ... → Shift-DR → 移入 32 bit → Update-DR

3. IR 扫描：写入 EXTEST 指令
   Run-Test/Idle → ... → Shift-IR → 移入 EXTEST → Update-IR

4. DR 扫描：移入测试向量
   Run-Test/Idle → ... → Shift-DR → 移入 BSR 数据 → Update-DR

5. DR 扫描：捕获测试响应
   Run-Test/Idle → ... → Capture-DR → Shift-DR → 读出 BSR 数据
```

---

## 7. 时序波形

### 7.1 TCK 采样与驱动

```
TCK 周期:    │◄── T ──►│

TCK:         ┌────────┐          ┌────────┐
             │        │          │        │
        ─────┘        └──────────┘        └─────
                     ▲                    ▲
                  上升沿                下降沿
                  (Rise)               (Fall)

TDI/TMS:     ═══════════╤═══════════════════════
  (输入)                │ tSU
                   ┌────┤
                   │    │ tHOLD
                   │    ├──────
                   │    │
                   ▼    ▼
TCK:        ──────┘    └─────────────────────
                       ▲
                    采样沿（TCK Rise）

TDO:        ────────────────╤═══════════════
  (输出)                    │ tDO
                        ┌───┤
                        │   │
                        │   │
                        ▼   ▼
TCK:        ────────────────┘    └──────────
                             ▲
                          驱动沿（TCK Fall）
```

### 7.2 关键时序参数

| 参数 | 符号 | 最小值 | 最大值 | 单位 | 说明 |
|------|------|--------|--------|------|------|
| TCK 周期 | T | 20 | - | ns | @ 50 MHz 最大频率 |
| TCK 高电平宽度 | tHIGH | 10 | - | ns | |
| TCK 低电平宽度 | tLOW | 10 | - | ns | |
| TDI/TMS setup | tSU | 5 | - | ns | 相对 TCK 上升沿 |
| TDI/TMS hold | tHOLD | 5 | - | ns | 相对 TCK 上升沿 |
| TDO 输出延迟 | tDO | - | 15 | ns | 相对 TCK 下降沿 |
| TRST# 脉宽 | tRST | 100 | - | ns | 异步复位最小脉宽 |

---

## 8. JTAG 链（菊花链）

### 8.1 拓扑结构

多芯片通过 TDO→TDI 级联形成菊花链，共享 TCK、TMS。

```
  Host (JTAG Adapter)
    │
    ├── TCK ────────────────────────────────────────┐
    │                                               │
    ├── TMS ────────────────────────────────────────┤
    │                                               │
    │   ┌──────────┐   ┌──────────┐   ┌──────────┐ │
    ├──►│ TDI      │   │ TDI      │   │ TDI      │ │
    │   │ Chip 0   │   │ Chip 1   │   │ Chip 2   │ │
    │   │      TDO ├──►│      TDO ├──►│      TDO ├──┘
    │   └──────────┘   └──────────┘   └──────────┘  │
    │                                                │
    └── TCK ◄───────────────────────────────────────┘
                                                    │
                                               返回 TDO
```

### 8.2 链操作原理

- IR 扫描：指令长度 = 所有芯片 IR 宽度之和，各芯片同时加载指令
- DR 扫描：数据长度 = 各芯片选中 DR 宽度之和
- 数据像移位寄存器一样穿过整条链
- 不参与操作的芯片可加载 BYPASS 指令（1-bit 延迟）

### 8.3 链长度计算

```
DR 扫描总位数 = Σ (各芯片 IR 选中的 DR 位宽)
若 Chip0: EXTEST (BSR=64 bit)
   Chip1: BYPASS (1 bit)
   Chip2: IDCODE (32 bit)
总位数 = 64 + 1 + 32 = 97 bit
```

### 8.4 链设计注意事项

| 项目 | 建议 |
|------|------|
| TCK 布线 | 等长走线，避免 skew 过大 |
| TDO→TDI | 最短路径，减少延迟 |
| TRST# | 所有芯片共享，统一复位 |
| 上拉电阻 | TMS/TDI/TDO 加 4.7K~10K 上拉 |
| 信号完整性 | 高速 JTAG（>20 MHz）注意反射 |

---

## 9. 边界扫描测试

### 9.1 EXTEST（External Test）

测试 PCB 板级连线，BS Cell 驱动/捕获引脚信号。

```
测试流程：
1. 加载 EXTEST 指令到 IR
2. 将测试向量移入 BSR（Shift-DR）
3. Update-DR：BSR 输出 cell 驱动引脚
4. 等待信号稳定
5. Capture-DR：BSR 输入 cell 捕获引脚值
6. Shift-DR：读出捕获值，与期望值比较
7. 重复步骤 2-6 覆盖所有引脚

┌──────────────────────────────────────┐
│              PCB Trace               │
│                                      │
│  ┌────────┐   ┌──────────────────┐   │
│  │Chip A  │   │    Chip B        │   │
│  │        │   │                  │   │
│  │ BS Out ├──►├──── Pin ►───────┤   │
│  │        │   │                  │   │
│  │        │   │    BS In ◄──────┤   │
│  └────────┘   └──────────────────┘   │
│                                      │
│  EXTEST: Chip A 驱动，Chip B 捕获    │
└──────────────────────────────────────┘
```

### 9.2 SAMPLE（Signal Sampling）

在系统正常运行时采样引脚信号，不影响系统功能。

```
1. 加载 SAMPLE/PRELOAD 指令到 IR
2. Capture-DR：BS Cell 同时捕获当前引脚值
3. Shift-DR：读出采样值
4. 系统逻辑正常运行不受影响

关键区别：
- EXTEST：BSR 驱动引脚，系统逻辑断开
- SAMPLE：BSR 只采样，系统逻辑保持连接
```

### 9.3 INTEST（Internal Test）

测试芯片内部逻辑，BS Cell 从引脚侧驱动/捕获。

```
┌────────────────────────────┐
│        Chip                │
│                            │
│  Pin ──►BS In──►┌───────┐  │
│                 │ Core  │  │
│  Pin ◄──BS Out◄─│ Logic │  │
│                 └───────┘  │
│                            │
│  INTEST: BS Out 驱动 Core  │
│          BS In 捕获 Core 输出
└────────────────────────────┘
```

---

## 10. 调试扩展

### 10.1 ARM CoreSight JTAG-DP（JTAG Debug Port）

ARM 调试架构使用 JTAG-DP 作为物理接口选项之一，连接 DAP（Debug Access Port）。

```
┌──────────────────────────────────────────┐
│  Host (Debugger)                          │
│  ┌──────────────────────────────────┐    │
│  │   JTAG Adapter                   │    │
│  └─────┬────────────────────────────┘    │
│        │ TCK/TMS/TDI/TDO                 │
└────────┼─────────────────────────────────┘
         │
    ┌────▼────┐
    │ JTAG-DP │  ◄── Debug Port (JTAG 物理接口)
    └────┬────┘
         │ DAP Interface
    ┌────▼────┐
    │   DAP   │  ◄── Debug Access Port
    │ (AHB/AP)│
    └────┬────┘
         │
    ┌────▼──────────────────────┐
    │  Debug Components         │
    │  ┌───────┐  ┌──────────┐  │
    │  │ CTI   │  │  DCC     │  │
    │  └───────┘  └──────────┘  │
    │  ┌───────┐  ┌──────────┐  │
    │  │ ETM   │  │  DWT     │  │
    │  └───────┘  └──────────┘  │
    └───────────────────────────┘
```

### 10.2 JTAG-DP 指令与 DR

| IR 编码 | 指令 | DR 位宽 | 说明 |
|---------|------|---------|------|
| `4'b1110` | DPACC | 35 bit | DP 寄存器访问（[34:3]=data, [2:0]=addr） |
| `4'b1111` | ABORT | 35 bit | 中止当前操作 |
| `4'b0010` | IDCODE | 32 bit | 芯片 ID（ARM = 0x4BA00477） |
| `4'b1111` | BYPASS | 1 bit | 默认旁路 |

### 10.3 DCC（Debug Communication Channel）

DCC 提供调试器与处理器核心之间的通信通道：

| 功能 | 说明 |
|------|------|
| DTRTX | Debug Transmit：处理器写入 → 调试器读取 |
| DTRRX | Debug Receive：调试器写入 → 处理器读取 |
| DCSR | Debug Control and Status Register |

### 10.4 扫描链选择

ARM JTAG-DP 通过 IR 和 DR 的组合选择目标扫描链：

```
1. IR = SCAN_N (0x02)
2. DR = 扫描链编号（8 bit）
3. IR = INTEST/EXTEST
4. DR = 目标数据

扫描链分配：
  Chain 0：Debug - ARM 核心
  Chain 1：ETM（Embedded Trace Macrocell）
  Chain 2：ICE Breaker
```

---

## 11. 与 SWD 的对比

SWD（Serial Wire Debug）是 ARM 定义的 2 线调试接口，作为 JTAG 的替代方案。

| 对比项 | JTAG (IEEE 1149.1) | SWD (Serial Wire Debug) |
|--------|---------------------|-------------------------|
| 信号线数 | 4~5 线（TCK/TMS/TDI/TDO/TRST#） | 2 线（SWCLK/SWDIO） |
| 标准 | IEEE 1149.1（通用标准） | ARM 专有（CoreSight） |
| 适用范围 | 通用（所有支持 JTAG 的芯片） | 仅 ARM 核心 |
| 双工模式 | 半双工（TDI 和 TDO 分离） | 半双工（SWDIO 双向） |
| 协议开销 | 中等（状态机 16 状态） | 低（ACK/NACK 简化协议） |
| 速率 | 最高 ~50 MHz（典型 10 MHz） | 最高 ~50 MHz（典型 4 MHz） |
| 调试能力 | 相同（通过 DAP） | 相同（通过 DAP） |
| 引脚复用 | 需要 4~5 个专用引脚 | 仅需 2 个引脚 |
| 边界扫描 | 支持 | 不支持 |
| 多核调试 | 支持（菊花链 + DAP 选择） | 支持（多 DAP 拓扑） |
| 引脚数节约 | - | 比 JTAG 少 2~3 个引脚 |

**SWD 协议简述**：
```
Host → Target: START | APnDP | RnW | A[2:3] | PARITY | STOP
Target → Host:  ACK[2:0] | DATA[31:0] | PARITY

SWCLK:  ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
           └──┘  └──┘  └──┘  └──┘  └──┘
SWDIO:   ──[S][AP][RW][A][P][0]──[ACK]──[DATA]──[P]──
```

**选择建议**：
- 需要边界扫描测试 → 必须用 JTAG
- 仅 ARM 核心调试 → 优先 SWD（省引脚）
- 多厂商混合链 → JTAG（通用兼容）
- 引脚紧张 → SWD

---

## 12. 设计注意事项

### 12.1 TAP 控制器 RTL 实现要点

| 要点 | 说明 |
|------|------|
| TCK 异步域 | TAP 控制器工作在 TCK 域，与系统时钟 clk 不同域，需 CDC 处理 |
| TMS 采样 | TCK 上升沿采样 TMS，需做好 setup/hold |
| TDO 驱动 | TCK 下降沿驱动 TDO，需满足输出延迟要求 |
| TRST# 同步 | TRST# 为异步信号，需同步释放 |
| 16 状态 FSM | 严格按 IEEE 1149.1 状态转移表实现 |
| 默认状态 | 复位后进入 Test-Logic-Reset，所有输出为安全值 |

### 12.2 扫描链设计

| 项目 | 建议 |
|------|------|
| 扫描链分段 | 长链拆分为多段，减少 shift 周期 |
| 扫描链选择 | 通过 IR 指令选择目标扫描链 |
| 旁路寄存器 | 每条链必须支持 BYPASS |
| 扫描链顺序 | 按信号拓扑排列，便于调试 |
| 扫描链长度 | 记录到文档，调试工具需要此信息 |

### 12.3 多 TAP 控制器仲裁

复杂 SoC 可能包含多个 TAP 控制器（如 CPU TAP、GPU TAP、安全 TAP）。

```
JTAG Adapter
    │
    ├── TCK/TMS/TDI
    │       │
    │  ┌────▼──────┐
    │  │  JTAG     │
    │  │  Router   │◄── IR 选择目标 TAP
    │  └─┬───┬───┬─┘
    │    │   │   │
    │  ┌─▼┐ ┌▼─┐ ┌▼─┐
    │  │TAP│ │TAP│ │TAP│
    │  │ 0 │ │ 1 │ │ 2 │
    │  └─┬┘ └─┬┘ └─┬┘
    │    │    │    │
    │  ┌─▼────▼────▼──┐
    │  │  TDO MUX     │
    │  └──────────────┘
    │       │
    └── TDO
```

| 仲裁方案 | 说明 |
|----------|------|
| 静态选择 | 通过固定 IR 编码选择 TAP，简单但不灵活 |
| 动态路由 | 通过专门的 Router TAP 指令选择目标 TAP |
| 层次化 | 主 TAP 下挂子 TAP，通过 APB/AHB 访问子 TAP |

### 12.4 CDC 处理

| 跨域路径 | 同步方案 | 说明 |
|----------|----------|------|
| TCK → clk | 双触发器同步 + 握手 | 读写寄存器跨域 |
| clk → TCK | 双触发器同步 | 系统状态更新到 TAP |
| TRST# → TCK | 异步复位同步释放 | 2 级同步器 |

### 12.5 DFT 友好性

| 项目 | 建议 |
|------|------|
| TAP 控制器本身 | 使用系统 clk 做扫描链，TCK 域单独处理 |
| BSR cell | 使用标准 BS Cell（IEEE 1149.1 BSDL 描述） |
| ICG cell | TCK 门控使用标准 ICG，避免毛刺 |
| 扫描链复用 | BSR 也可用于内部扫描链（Scan Chain） |

---

## 13. TAP 控制器 Verilog 代码骨架

```verilog
// ============================================================================
// Module   : tap_controller
// Function : IEEE 1149.1 TAP Controller — 16-state FSM + IR/DR shift registers
// Author   : arch
// Date     : 2026-04-15
// Revision : v1.0
// ============================================================================

module tap_controller #(
    parameter IR_WIDTH    = 4,
    parameter DR_WIDTH    = 32,
    parameter IDCODE_VAL  = 32'h4BA00477   // ARM default IDCODE
)(
    // TAP 信号
    input  wire                  tck,
    input  wire                  tms,
    input  wire                  tdi,
    input  wire                  trst_n,
    output reg                   tdo,

    // 系统接口
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [DR_WIDTH-1:0]   bs_data_in,    // BSR 采样数据
    output wire [DR_WIDTH-1:0]   bs_data_out,   // BSR 驱动数据
    output wire                  bs_capture_en,  // BSR 采样使能
    output wire                  bs_update_en,   // BSR 更新使能
    output wire                  extest_active   // EXTEST 活动指示
);

    // === TAP 状态定义（独热码）===
    localparam [15:0] S_TEST_LOGIC_RESET = 16'h0001,
                      S_RUN_TEST_IDLE    = 16'h0002,
                      S_SELECT_DR_SCAN   = 16'h0004,
                      S_CAPTURE_DR       = 16'h0008,
                      S_SHIFT_DR         = 16'h0010,
                      S_EXIT1_DR         = 16'h0020,
                      S_PAUSE_DR         = 16'h0040,
                      S_EXIT2_DR         = 16'h0080,
                      S_UPDATE_DR        = 16'h0100,
                      S_SELECT_IR_SCAN   = 16'h0200,
                      S_CAPTURE_IR       = 16'h0400,
                      S_SHIFT_IR         = 16'h0800,
                      S_EXIT1_IR         = 16'h1000,
                      S_PAUSE_IR         = 16'h2000,
                      S_EXIT2_IR         = 16'h4000,
                      S_UPDATE_IR        = 16'h8000;

    // === TAP 状态寄存器（TCK 域）===
    reg [15:0] state_cur, state_nxt;

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            state_cur <= S_TEST_LOGIC_RESET;
        else
            state_cur <= state_nxt;
    end

    // === 状态转移组合逻辑 ===
    always @(*) begin
        state_nxt = state_cur;
        case (state_cur)
            S_TEST_LOGIC_RESET: state_nxt = tms ? S_TEST_LOGIC_RESET : S_RUN_TEST_IDLE;
            S_RUN_TEST_IDLE:    state_nxt = tms ? S_SELECT_DR_SCAN    : S_RUN_TEST_IDLE;
            S_SELECT_DR_SCAN:   state_nxt = tms ? S_SELECT_IR_SCAN    : S_CAPTURE_DR;
            S_CAPTURE_DR:       state_nxt = tms ? S_EXIT1_DR          : S_SHIFT_DR;
            S_SHIFT_DR:         state_nxt = tms ? S_EXIT1_DR          : S_SHIFT_DR;
            S_EXIT1_DR:         state_nxt = tms ? S_UPDATE_DR         : S_PAUSE_DR;
            S_PAUSE_DR:         state_nxt = tms ? S_EXIT2_DR          : S_PAUSE_DR;
            S_EXIT2_DR:         state_nxt = tms ? S_UPDATE_DR         : S_SHIFT_DR;
            S_UPDATE_DR:        state_nxt = tms ? S_SELECT_DR_SCAN    : S_RUN_TEST_IDLE;
            S_SELECT_IR_SCAN:   state_nxt = tms ? S_TEST_LOGIC_RESET  : S_CAPTURE_IR;
            S_CAPTURE_IR:       state_nxt = tms ? S_EXIT1_IR          : S_SHIFT_IR;
            S_SHIFT_IR:         state_nxt = tms ? S_EXIT1_IR          : S_SHIFT_IR;
            S_EXIT1_IR:         state_nxt = tms ? S_UPDATE_IR         : S_PAUSE_IR;
            S_PAUSE_IR:         state_nxt = tms ? S_EXIT2_IR          : S_PAUSE_IR;
            S_EXIT2_IR:         state_nxt = tms ? S_UPDATE_IR         : S_SHIFT_IR;
            S_UPDATE_IR:        state_nxt = tms ? S_SELECT_DR_SCAN    : S_RUN_TEST_IDLE;
            default:            state_nxt = S_TEST_LOGIC_RESET;
        endcase
    end

    // === 状态输出 ===
    wire shift_ir  = (state_cur == S_SHIFT_IR);
    wire shift_dr  = (state_cur == S_SHIFT_DR);
    wire capture_ir = (state_cur == S_CAPTURE_IR);
    wire capture_dr = (state_cur == S_CAPTURE_DR);
    wire update_ir  = (state_cur == S_UPDATE_IR);
    wire update_dr  = (state_cur == S_UPDATE_DR);

    assign bs_capture_en = capture_dr;
    assign bs_update_en  = update_dr;

    // === IR 移位寄存器 ===
    reg [IR_WIDTH-1:0] ir_shift;
    reg [IR_WIDTH-1:0] ir_update;

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            ir_shift <= {IR_WIDTH{1'b0}};
        end else if (capture_ir) begin
            ir_shift <= {{(IR_WIDTH-1){1'b1}}, 1'b0};  // IEEE 规定的 Capture 值
        end else if (shift_ir) begin
            ir_shift <= {tdi, ir_shift[IR_WIDTH-1:1]};
        end
    end

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ir_update <= {IR_WIDTH{1'b1}};  // 复位后默认 BYPASS（全 1）
        else if (update_ir)
            ir_update <= ir_shift;
    end

    // === 指令解码 ===
    localparam [IR_WIDTH-1:0] IR_EXTEST    = {IR_WIDTH{1'b0}},
                              IR_IDCODE    = {{(IR_WIDTH-2){1'b0}}, 2'b10},
                              IR_SAMPLE    = {{(IR_WIDTH-3){1'b0}}, 3'b010},
                              IR_BYPASS    = {IR_WIDTH{1'b1}};

    wire sel_idcode  = (ir_update == IR_IDCODE);
    wire sel_bsr     = (ir_update == IR_EXTEST) || (ir_update == IR_SAMPLE);
    wire sel_bypass  = sel_idcode ? 1'b0 : (sel_bsr ? 1'b0 : 1'b1);

    assign extest_active = (ir_update == IR_EXTEST);

    // === DR 移位寄存器（复用）===
    reg [DR_WIDTH-1:0] dr_shift;
    reg [DR_WIDTH-1:0] dr_update;

    wire [DR_WIDTH-1:0] dr_capture_val =
        sel_idcode ? IDCODE_VAL :
        sel_bsr    ? bs_data_in :
                     {DR_WIDTH{1'b0}};  // BYPASS 不关心

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dr_shift <= {DR_WIDTH{1'b0}};
        end else if (capture_dr) begin
            dr_shift <= dr_capture_val;
        end else if (shift_dr) begin
            dr_shift <= {tdi, dr_shift[DR_WIDTH-1:1]};
        end
    end

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            dr_update <= {DR_WIDTH{1'b0}};
        else if (update_dr)
            dr_update <= dr_shift;
    end

    assign bs_data_out = dr_update;

    // === TDO 输出（TCK 下降沿驱动）===
    wire tdo_ir = ir_shift[0];
    wire tdo_dr = sel_bypass ? dr_shift[0] : dr_shift[0];

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n)
            tdo <= 1'b0;
        else if (shift_ir)
            tdo <= tdo_ir;
        else if (shift_dr)
            tdo <= tdo_dr;
        else
            tdo <= 1'b0;
    end

endmodule
```

---

## 附录

### A. 缩略语

| 缩写 | 全称 |
|------|------|
| TAP | Test Access Port |
| TCK | Test Clock |
| TDI | Test Data In |
| TDO | Test Data Out |
| TMS | Test Mode Select |
| TRST | Test Reset |
| BSR | Boundary Scan Register |
| DAP | Debug Access Port |
| DCC | Debug Communication Channel |
| DWT | Data Watchpoint and Trace |
| ETM | Embedded Trace Macrocell |
| SWD | Serial Wire Debug |

### B. 参考文档

| 编号 | 文档名 | 版本 | 说明 |
|------|--------|------|------|
| REF-001 | IEEE Std 1149.1 | 2013 | JTAG 标准规范 |
| REF-002 | ARM CoreSight DAP | v5.2 | ARM 调试架构 |
| REF-003 | IEEE 1149.7 | 2009 | 增强版 JTAG（CJTAG，2 线） |
| REF-004 | ARM Debug Interface | ADIv5 | SWD/JTAG-DP 统一规范 |
