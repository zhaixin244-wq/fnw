# MIPI 协议族

> **用途**：移动设备摄像头/显示屏高速串行接口标准
> **规范维护**：MIPI Alliance（Mobile Industry Processor Interface Alliance）
> **典型应用**：手机摄像头、平板/手机显示屏、车载视觉、AR/VR 显示

---

## 1. 协议概述

MIPI（Mobile Industry Processor Interface）是由 MIPI Alliance 制定的一套面向移动设备的高速串行接口标准族，核心目标是用最少的引脚数实现高带宽数据传输，同时保持低功耗。

**核心设计哲学**：

| 目标 | 实现手段 |
|------|----------|
| 低引脚数 | 串行差分传输，替代并行总线（如传统的 8-bit 并行 camera 接口） |
| 低功耗 | 双模物理层：LP（低功耗）模式用于控制，HS（高速）模式用于数据 |
| 高带宽 | 多 Lane 并行 + 高速 SerDes（D-PHY 2.5 Gbps/lane） |
| 协议复用 | 统一的协议层（CSI-2/DSI 共享包格式），物理层可替换（D-PHY/C-PHY） |

---

## 2. MIPI 协议族对比

| 协议 | 全称 | 方向 | 功能定位 | 物理层 |
|------|------|------|----------|--------|
| **CSI-2** | Camera Serial Interface 2 | Camera → SoC | 摄像头图像数据传输 | D-PHY / C-PHY |
| **DSI** | Display Serial Interface | SoC → Display | 显示屏图像/命令传输 | D-PHY / C-PHY |
| **D-PHY** | - | - | 高速差分物理层（1 对时钟 + 1-4 对数据） | - |
| **C-PHY** | - | - | 3 线制物理层（7-Phase 符号编码） | - |
| **I3C** | Improved Inter-Integrated Circuit | 双向 | 控制/配置总线（I2C 升级版） | - |
| **I3C Basic** | - | 双向 | I3C 子集（免授权） | - |

**协议层级关系**：

```
┌─────────────────────────────────────────┐
│          应用层 (Application)            │
│   图像传感器 / 显示控制器 / ISP         │
├─────────────────────────────────────────┤
│          协议层 (Protocol)              │
│   CSI-2（摄像头）  /  DSI（显示屏）      │
│   统一的 Packet 格式、VC、DT 编码       │
├─────────────────────────────────────────┤
│          物理层 (PHY)                   │
│   D-PHY（差分 2-wire）                  │
│   C-PHY（3-wire 7-Phase）              │
└─────────────────────────────────────────┘
```

CSI-2 和 DSI 共享相同的协议层包格式，可灵活搭配 D-PHY 或 C-PHY 物理层。

---

## 3. CSI-2（Camera Serial Interface 2）

### 3.1 协议层级

| 层级 | 功能 | 说明 |
|------|------|------|
| **应用层** | 图像传感器输出 | Sensor 产生 RAW/YUV/RGB/JPEG 数据 |
| **协议层** | 数据打包、VC 分离、DT 编码 | 将像素数据封装为 CSI-2 数据包 |
| **物理层** | 串行传输 | D-PHY（差分）或 C-PHY（3 线） |

### 3.2 D-PHY 信号连接

```
    ┌──────────┐                          ┌──────────┐
    │   SoC    │                          │  Camera  │
    │ (Receiver)│                          │(Transmitter)
    │          │        Dp0  Dn0          │          │
    │   CLK_P ─┼──────── ─── ────────────┼── CLK_P  │   ← 时钟 Lane
    │   CLK_N ─┼──────── ─── ────────────┼── CLK_N  │
    │          │        Dp1  Dn1          │          │
    │   D0_P  ─┼──────── ─── ────────────┼── D0_P   │   ← 数据 Lane 0
    │   D0_N  ─┼──────── ─── ────────────┼── D0_N   │
    │   D1_P  ─┼──────── ─── ────────────┼── D1_P   │   ← 数据 Lane 1（可选）
    │   D1_N  ─┼──────── ─── ────────────┼── D1_N   │
    │   ...    │                          │   ...    │   ← 最多 4 对数据 Lane
    └──────────┘                          └──────────┘
```

**信号说明**：

| 信号 | 类型 | 数量 | 功能 |
|------|------|------|------|
| CLKp/CLKn | 差分对 | 1 对 | 单向时钟，Sensor → SoC |
| Dp0/Dn0 ~ Dp3/Dn3 | 差分对 | 1~4 对 | 单向数据，Sensor → SoC |

- CSI-2 是单向总线（Sensor → SoC），数据始终从发送端流向接收端
- 典型配置：2-lane（1 CLK + 2 Data）或 4-lane（1 CLK + 4 Data）

### 3.3 数据包格式

CSI-2 协议层定义两种数据包类型：

#### Short Packet（短包）

```
┌────────────┬────────────┬────────────┐
│  Data ID   │   Data     │   ECC      │
│  (1 byte)  │ (2 bytes)  │ (2 bytes)  │
└────────────┴────────────┴────────────┘
```

- 固定 5 字节（不含传输开销）
- 用于帧同步（Frame Start / Frame End）和行同步（Line Start / Line End）
- Data 字段携带帧号或行号

#### Long Packet（长包）

```
┌────────────┬────────────┬────────────┬──────────────┬────────────┐
│  Data ID   │ Word Count │   ECC      │   Payload    │    CRC     │
│  (1 byte)  │ (2 bytes)  │ (2 bytes)  │ (0~65535 B)  │  (2 bytes) │
└────────────┴────────────┴────────────┴──────────────┴────────────┘
```

- Header 6 字节 + Payload（0~65535 字节）+ CRC 2 字节
- 用于传输实际的图像数据行

#### Header 字段解析

**Data ID（1 byte）**：

| Bit [7:6] | Bit [5:0] |
|-----------|-----------|
| Virtual Channel (VC) | Data Type (DT) |

- VC：虚拟通道号（0~3）
- DT：数据类型编码（见下表）

**Word Count（2 bytes）**：Long Packet 的 Payload 字节数（0~65535）

**ECC（2 bytes）**：Header 的纠错码（Hamming 码），可纠 1-bit 错、检 2-bit 错

**CRC（2 bytes）**：Payload 的 CRC-16-CCITT 校验

### 3.4 虚拟通道（Virtual Channel）

| VC 编码 | 标识 | 用途 |
|---------|------|------|
| 2'b00 | VC0 | 默认通道，单摄像头场景 |
| 2'b01 | VC1 | 多摄像头/多流场景 |
| 2'b10 | VC2 | 多摄像头/多流场景 |
| 2'b11 | VC3 | 多摄像头/多流场景 |

**应用场景**：
- 多摄像头复用同一条 MIPI 总线（如前置+后置同时传输）
- 同一 Sensor 输出多种分辨率流（如预览流 + 拍照流）
- 3D 摄像头（左眼 + 右眼图像）

接收端通过解析 Data ID 中的 VC 字段来分离不同来源的数据流。

### 3.5 常用数据类型（Data Type）

| DT 编码 (hex) | 数据类型 | 说明 |
|---------------|----------|------|
| 0x00 | Frame Start Code | 帧起始（Short Packet） |
| 0x01 | Frame End Code | 帧结束（Short Packet） |
| 0x02 | Line Start Code | 行起始（Short Packet） |
| 0x03 | Line End Code | 行结束（Short Packet） |
| **RAW 数据** | | |
| 0x28 | RAW6 | 6-bit RAW 数据 |
| 0x29 | RAW7 | 7-bit RAW 数据 |
| 0x2A | RAW8 | 8-bit RAW 数据 |
| 0x2B | RAW10 | 10-bit RAW 数据（最常用） |
| 0x2C | RAW12 | 12-bit RAW 数据 |
| 0x2D | RAW14 | 14-bit RAW 数据 |
| **YUV 数据** | | |
| 0x18 | YUV420 8-bit | YUV 4:2:0, 8-bit |
| 0x19 | YUV420 10-bit | YUV 4:2:0, 10-bit |
| 0x1E | YUV422 8-bit | YUV 4:2:2, 8-bit |
| 0x1F | YUV422 10-bit | YUV 4:2:2, 10-bit |
| **RGB 数据** | | |
| 0x22 | RGB565 | RGB 5:6:5, 16-bit/pixel |
| 0x24 | RGB888 | RGB 8:8:8, 24-bit/pixel |
| **压缩数据** | | |
| 0x1C | JPEG | JPEG 压缩图像 |
| **User-defined** | | |
| 0x30~0x37 | User Defined 0~7 | 自定义数据类型 |

### 3.6 传输时序（LP/HS 切换）

一帧图像的典型传输时序：

```
    Lane State:
    LP-11 ──┐     ┌── LP-11 ──┐     ┌── LP-11 ──┐     ┌── LP-11
            │     │           │     │           │     │
    LP-01 ──┘     └── LP-01 ──┘     └── LP-01 ──┘     └── LP-01
            │     │           │     │           │     │
    HS-0  ──┤     ├── HS-0  ──┤     ├── HS-0  ──┤     ├─── EoT
            │     │           │     │           │     │
    Data:   │     │           │     │           │     │
            FS    |--- Line N (Long Packet) ---| LS  |--- Line N+1 ---
            (SP)  |  Header + Pixel Data + CRC | (SP)|  ...
```

**完整帧传输流程**：

```
1. LP-11 (Stop State)        ← 总线空闲
2. LP-01 (Bridge)            ← 准备进入 HS
3. LP-00 (HS-Request)        ← HS 传输请求
4. HS-0  (HS-0 State)        ← Sync 序列起始
5. HS Data                   ← 有效数据传输
   ├── Short Packet: Frame Start (DT=0x00)
   ├── Long Packet:  Line 0 (Header + Pixel + CRC)
   ├── Long Packet:  Line 1
   ├── ...
   ├── Long Packet:  Line N
   └── Short Packet: Frame End (DT=0x01)
6. EoT (End of Transmission) ← HS 数据结束
7. LP-11 (Stop State)        ← 返回空闲
```

**ASCII 波形 - 一帧传输**：

```
        ┌──── HS-Request ────┐
        │                    │
LP:  11─┤00────── Data ──────├─11────── 11
        │                    │
Dp:    ─┤ Sync─┤HDR│Payload│CRC├─EoT──
        │     │    │        │   │
Dn:    ─┤─────┤    │        │   ├──────
```

---

## 4. DSI（Display Serial Interface）

### 4.1 与 CSI-2 的对称关系

| 特性 | CSI-2 | DSI |
|------|-------|-----|
| 方向 | Camera → SoC | SoC → Display |
| 数据包格式 | 相同（Short/Long Packet） | 相同（Short/Long Packet） |
| 物理层 | D-PHY / C-PHY | D-PHY / C-PHY |
| 虚拟通道 | VC0~VC3 | VC0~VC3 |
| 工作模式 | - | Video 模式 / Command 模式 |
| 典型带宽 | 2-4 Lane, ~2.5 Gbps/Lane | 同左 |

DSI 的数据包格式与 CSI-2 完全对称，区别在于方向相反（SoC → Display）和定义了额外的显示控制数据类型。

### 4.2 Video 模式 vs Command 模式

| 特性 | Video 模式 | Command 模式 |
|------|-----------|-------------|
| 数据流 | 持续流式传输（类似 HDMI） | 按需写入帧缓冲 |
| 时序 | SoC 产生 VSYNC/HSYNC/DE 时序 | Display 内部时序控制器产生 |
| 功耗 | 较高（持续传输） | 较低（仅画面变化时传输） |
| 典型应用 | 实时视频播放、游戏 | 静态 UI、低刷新率场景 |
| 帧缓冲 | SoC 端 | Display 端（GRAM） |
| 刷新率 | 固定（60Hz 等） | 可变（0Hz 静态时） |

**Video 模式**：SoC 持续向 Display 推送像素流，Display 被动接收并显示。类似传统 LVDS 接口行为。

**Command 模式**：SoC 将帧数据写入 Display 内部的 GRAM（Graphic RAM），Display 自行刷新屏幕。仅当画面内容变化时才需要传输。

### 4.3 DSI 数据类型

DSI 在 CSI-2 的通用数据类型基础上，增加了显示专用的数据类型：

| DT 编码 (hex) | 数据类型 | 方向 | 说明 |
|---------------|----------|------|------|
| **同步类** | | | |
| 0x01 | V Sync Start | SoC→Display | 帧同步起始 |
| 0x11 | V Sync End | SoC→Display | 帧同步结束 |
| 0x21 | H Sync Start | SoC→Display | 行同步起始 |
| 0x31 | H Sync End | SoC→Display | 行同步结束 |
| **数据类** | | | |
| 0x09 | End of Transmission Packet | SoC→Display | 传输结束包 |
| 0x03 | Color Mode (CM) Off | SoC→Display | 关闭色彩模式 |
| 0x02 | Color Mode (CM) On | SoC→Display | 开启色彩模式 |
| **DCS 命令** | | | |
| 0x05 | DCS Short Write (no param) | SoC→Display | DCS 短写（无参数） |
| 0x15 | DCS Short Write (1 param) | SoC→Display | DCS 短写（1 参数） |
| 0x39 | DCS Long Write | SoC→Display | DCS 长写（多参数） |
| 0x06 | DCS Read (no param) | SoC→Display | DCS 读请求 |
| 0x16 | DCS Read (1 param) | SoC→Display | DCS 读请求（1 参数） |
| 0x21 | Generic Short Write (no param) | SoC→Display | 通用短写 |
| 0x23 | Generic Short Write (2 param) | SoC→Display | 通用短写（2 参数） |
| 0x29 | Generic Long Write | SoC→Display | 通用长写 |
| 0x22 | Generic Read (no param) | SoC→Display | 通用读 |

### 4.4 DCS 命令集（常用）

| 命令 (hex) | 名称 | 参数 | 说明 |
|------------|------|------|------|
| 0x01 | Software Reset | 无 | 软复位 |
| 0x11 | Sleep Out | 无 | 退出休眠模式 |
| 0x10 | Sleep In | 无 | 进入休眠模式 |
| 0x28 | Display Off | 无 | 关闭显示 |
| 0x29 | Display On | 无 | 开启显示 |
| 0x2A | Set Column Address | 4 参数 | 设置列地址范围 (x_start, x_end) |
| 0x2B | Set Page Address | 4 参数 | 设置行地址范围 (y_start, y_end) |
| 0x2C | Write Memory Start | 像素数据 | 开始写入帧缓冲 |
| 0x3C | Write Memory Continue | 像素数据 | 继续写入帧缓冲 |
| 0x2E | Read Memory Start | - | 开始读取帧缓冲 |
| 0x3E | Read Memory Continue | - | 继续读取帧缓冲 |
| 0x36 | Set Address Mode | 1 参数 | 设置扫描方向/镜像/RGB 排列 |
| 0x3A | Set Pixel Format | 1 参数 | 设置像素格式 (16/18/24-bit) |
| 0x51 | Write Display Brightness | 1 参数 | 设置背光亮度 |
| 0x53 | Write CTRL Display | 1 参数 | 背光控制 |

### 4.5 帧传输流程

**Command 模式帧写入**：

```
1. DCS Short Write: Sleep Out (0x11)        ← 唤醒 Display
2. DCS Short Write: Display On (0x29)       ← 开启显示
3. DCS Short Write: Set Column Address (0x2A) ← 设置列范围
   参数: [x_start_H, x_start_L, x_end_H, x_end_L]
4. DCS Short Write: Set Page Address (0x2B) ← 设置行范围
   参数: [y_start_H, y_start_L, y_end_H, y_end_L]
5. DCS Long Write: Write Memory Start (0x2C) ← 写入像素数据
   Payload: Line 0 pixel data (RGB888)
6. DCS Long Write: Write Memory Continue (0x3C) ← 继续写入
   Payload: Line 1 pixel data
7. ... (重复直到所有行写完)
```

**Video 模式帧传输**：

```
1. V Sync Start (Short Packet)
2. V Sync End (Short Packet)
3. H Sync Start → 像素数据行 0 (Long Packet) → H Sync End
4. H Sync Start → 像素数据行 1 (Long Packet) → H Sync End
5. ... (重复直到所有行)
6. V Sync Start (下一帧)
```

---

## 5. D-PHY 物理层

### 5.1 LP 模式与 HS 模式

D-PHY 定义了两种电气工作模式，通过切换模式实现低功耗和高带宽的平衡：

| 特性 | LP（Low Power）模式 | HS（High Speed）模式 |
|------|---------------------|---------------------|
| 信号类型 | 单端（Single-Ended） | 差分（Differential） |
| 电平范围 | 0~1.2V | 100~300mV（差分摆幅） |
| 共模电压 | - | 200mV |
| 传输速率 | ~10 Mbps | 80 Mbps ~ 2.5 Gbps（D-PHY v1.2） |
| 典型用途 | 控制命令、短包同步 | 图像数据传输 |
| 功耗 | 低 | 高 |
| 端接 | 无（高阻） | 100 ohm 差分端接 |

**LP 状态机**：

| 状态 | Dp | Dn | 说明 |
|------|----|----|------|
| LP-11 | 1 | 1 | Stop State（总线空闲） |
| LP-10 | 1 | 0 | Bridge / HS-Request 起始 |
| LP-01 | 0 | 1 | Bridge / HS-Prepare |
| LP-00 | 0 | 0 | HS-Request / HS-Trail |

### 5.2 LP/HS 状态切换时序

**LP → HS（进入高速传输）**：

```
           TLPX   THS-PREPARE  THS-ZERO  THS-TRAIL
            │        │            │          │
Dp:    ─11──┤10──────┤00──────────┤───HS Data──┤──EoT──┤──11──
            │        │            │           │       │
Dn:    ─11──┤────────┤────────────┤───HS Data──┤───────┤──11──
            │        │            │           │       │
State:  Stop  Bridge  HS-Prepare  HS-0  Sync  Data  Trail  Stop

时序参数（典型值）：
├─ TLPX         = 50 ns     (LP-10 持续时间)
├─ THS-PREPARE  = 40 ns + 4UI  (HS 准备时间)
├─ THS-ZERO     = 105 ns + 6UI (HS-0 稳定时间)
├─ THS-SYNC     = 8UI        (Sync 序列: 0001_1101)
├─ THS-TRAIL    = 60 ns + 4UI (HS 尾部)
└─ TCLK-PREPARE = 38 ns      (时钟的 HS-Prepare)
```

**HS 传输序列**：

```
HS State Transition:
LP-11 → LP-10 → LP-00 → [THS-PREPARE] → HS-0 → [THS-ZERO] → Sync Byte → Data → EoT → LP-11
                                               │
                                               └── Sync Byte = 8'b1011_1000 (0xB8)
                                                   这是 HS 模式的同步码，接收端据此建立字节边界
```

**EoT（End of Transmission）时序**：

```
Dp:    ────HS Data────┤─Trail─┤──11──
Dn:    ────HS Data────┤───────┤──11──

├─ THS-TRAIL = 60 ns + 4UI   (HS 尾部驱动)
├─ THS-EXIT  = 1 ns           (返回 LP-11 前的安静期)
└── 返回 LP-11 Stop State
```

### 5.3 时钟通路与数据通路

**时钟通路**：
- 单向传输：Sensor/Master → SoC/Slave
- LP 模式下时钟线保持 LP-11 状态
- HS 模式下传输连续差分时钟
- 接收端用此时钟同步采样数据 Lane

**数据通路**：
- CSI-2：单向（Sensor → SoC）
- DSI：通常单向（SoC → Display），也可配置为双向（Burst 模式下的读操作）
- 数据 Lane 上，HS 传输前发送 8-bit Sync Byte（0xB8）用于字节边界对齐
- 多 Lane 时数据按字节交织分配到各 Lane

**多 Lane 数据分配**（以 4-Lane 为例）：

```
Byte Stream: B0 B1 B2 B3 B4 B5 B6 B7 ...
             │  │  │  │  │  │  │  │
Lane 0:      B0     B4     B8  ...
Lane 1:         B1     B5     B9  ...
Lane 2:            B2     B6     B10 ...
Lane 3:               B3     B7     B11 ...
```

### 5.4 D-PHY 版本演进

| 版本 | 最大速率/Lane | 关键特性 |
|------|--------------|----------|
| v1.0 | 1.0 Gbps | 初版 |
| v1.1 | 1.5 Gbps | |
| v1.2 | 2.5 Gbps | 广泛使用 |
| v2.0 | 2.5 Gbps | 适配 C-PHY 共存 |
| v2.1 | 4.5 Gbps | 高速模式 |
| v2.5 | 4.5 Gbps | 最新主流 |

---

## 6. C-PHY 物理层

### 6.1 基本概念

C-PHY 是 MIPI Alliance 为追求更高带宽效率而定义的替代物理层。

| 特性 | D-PHY | C-PHY |
|------|-------|-------|
| 线数 | 2 线/对（Dp, Dn） | 3 线/Trio（A, B, C） |
| 信号类型 | 差分 | 3-wire 7-Phase |
| 编码 | 8b → 8b（Sync Byte） | 16-bit → 7-Phase 符号 |
| 效率 | ~1 bit/UI | ~2.28 bit/UI（3-wire） |
| 最大速率 | 2.5 Gbps/Lane（D-PHY v1.2） | ~5.7 Gbps/Trio（C-PHY v1.1） |
| 典型 Lane 配置 | 1 CLK + 4 Data = 10 线 | 3×4 = 12 线（4 Trio） |

### 6.2 7-Phase 符号编码

C-PHY 每个 Trio（3 线）使用 7-Phase 信令，每个 Unit Interval 传输一个 3-bit 符号（Wire State）：

```
Wire States（3 线中 1 线为高，1 线为低，1 线为高阻）：

  State 1:  A=H, B=L, C=Z
  State 2:  A=Z, B=H, C=L
  State 3:  A=L, B=Z, C=H
  State 4:  A=H, B=Z, C=L
  State 5:  A=Z, B=L, C=H
  State 6:  A=L, B=H, C=Z
  State 7:  A=Z, B=Z, C=Z   （停止状态）

相邻 UI 之间禁止重复相同状态（必须切换），利用状态跳变进行时钟恢复。
```

**编码效率**：16-bit payload → 7 个连续 Phase 符号，每个符号 3-bit，等效约 2.28 bit/UI，相比 D-PHY 提升约 30% 效率。

### 6.3 与 D-PHY 的选择

| 场景 | 推荐 |
|------|------|
| 引脚兼容性要求高 | D-PHY（更成熟的生态系统） |
| 最大带宽 | C-PHY（更高效率） |
| 低成本 Sensor | D-PHY（实现更简单） |
| 高端 ISP SoC | C-PHY 或 D-PHY + C-PHY 双模 |

---

## 7. 设计注意事项（CSI-2 Receiver RTL 设计要点）

### 7.1 字节对齐

- HS 传输以 Sync Byte（0xB8）开始，接收端需检测此序列建立字节边界
- 多 Lane 场景需要各 Lane 独立做字节对齐，然后做 Lane 间 Deskew
- RTL 实现：每条 Data Lane 上用移位寄存器检测 0xB8 模式

### 7.2 ECC/CRC 校验

| 校验 | 保护对象 | 算法 | RTL 设计要点 |
|------|----------|------|-------------|
| **ECC** | Packet Header（DI + WC + ECC） | Hamming 纠错码 | 可纠 1-bit 错，检 2-bit 错；Header 解析后立即校验 |
| **CRC** | Long Packet Payload | CRC-16-CCITT | 对完整 Payload 计算 CRC，与包尾 CRC 比较；需支持流式计算 |

**ECC 矩阵**：标准定义了 8×24 的 Parity Check Matrix，对 Header 24-bit（含 ECC 自身）做校验。RTL 中通常用组合逻辑实现 XOR 树。

### 7.3 帧同步

- 帧起始：Short Packet，DT = 0x00（Frame Start），WC 字段为帧号
- 帧结束：Short Packet，DT = 0x01（Frame End），WC 字段为帧号
- RTL 设计要点：
  - 收到 Frame Start 后开始接收行数据
  - 收到 Frame End 后关闭当前帧，产生帧完成信号
  - 异常恢复：长时间未收到 Frame End（超时），强制关闭帧

### 7.4 虚拟通道分离

```verilog
// 组合逻辑：按 VC 分发数据包
always @(*) begin
    case (vc_id)
        2'b00: begin vc0_valid = pkt_valid; vc0_data = pkt_data; end
        2'b01: begin vc1_valid = pkt_valid; vc1_data = pkt_data; end
        2'b10: begin vc2_valid = pkt_valid; vc2_data = pkt_data; end
        2'b11: begin vc3_valid = pkt_valid; vc3_data = pkt_data; end
        default: begin /* all zeros */ end
    endcase
end
```

- 每个 VC 独立维护帧状态机（Frame Start/End 计数）
- 支持最多 4 个 VC 同时活跃

### 7.5 LP/HS 检测

- 接收端需持续监测 Lane 状态（LP-11/10/01/00）
- LP→HS 转换时检测 THS-PREPARE → THS-ZERO → Sync Byte
- RTL 实现：用采样时钟（≥ 2× 数据速率）对 Dp/Dn 做状态采样，状态机跟踪 LP→HS 转换序列

### 7.6 典型 CSI-2 Receiver 架构

```
Dp0/Dn0 ─→ [LP Detect] ─→ [HS Sampler] ─→ [Byte Align] ─┐
Dp1/Dn1 ─→ [LP Detect] ─→ [HS Sampler] ─→ [Byte Align] ─┤
Dp2/Dn2 ─→ [LP Detect] ─→ [HS Sampler] ─→ [Byte Align] ─┼─→ [Lane Deskew] ─→ [Packet Parser] ─→ [VC Split] ─→ Output
Dp3/Dn3 ─→ [LP Detect] ─→ [HS Sampler] ─→ [Byte Align] ─┤                                              │
CLKp/CLKn → [Clock Rx]  ─→ [Byte Clock Gen] ─────────────┘                                     [ECC Check]
                                                                                                  [CRC Check]
```

### 7.7 关键设计参数

| 参数 | 典型值 | 说明 |
|------|--------|------|
| 参考时钟频率 | 由 PHY IP 提供 | 通常为数据速率的 1/8 或 1/16 |
| 字节时钟 | Data Rate / 8 | 接收端字节处理时钟 |
| FIFO 深度 | ≥ 4 lines | 跨时钟域 + 背压缓冲 |
| CRC 计算延迟 | 1~2 cycles | 流式 CRC 需与数据对齐 |
| ECC 解码延迟 | 1 cycle | 组合逻辑，无状态 |

---

## 8. 与 LVDS/SubLVDS 对比

| 特性 | MIPI D-PHY | MIPI C-PHY | LVDS | SubLVDS |
|------|-----------|-----------|------|---------|
| 差分对数 | 1 CLK + 1~4 Data | 3 线/Trio × 4 | 1 CLK + 4~10 Data | 1 CLK + 4~10 Data |
| 信号类型 | 差分（HS）/ 单端（LP） | 3-wire 7-Phase | 差分 | 差分 |
| 最大速率 | 2.5~4.5 Gbps/Lane | ~5.7 Gbps/Trio | ~950 Mbps/Pair | ~1 Gbps/Pair |
| 低功耗模式 | 有（LP 模式） | 有（LP 模式） | 无 | 无 |
| 数据编码 | Sync Byte (0xB8) | 7-Phase 编码 | 无（7-bit 并行→串行） | 无 |
| 协议层 | CSI-2 / DSI | CSI-2 / DSI | 无（点对点） | 无（点对点） |
| 多路复用 | Virtual Channel | Virtual Channel | 无 | 无 |
| 功耗（典型） | 中等 | 中等（效率更高） | 较高 | 较高 |
| 生态系统 | 手机、平板、车载 | 手机、平板 | 工业、医疗 | Sony Sensor 专用 |
| 典型应用 | 手机摄像头/显示 | 高端摄像头 | 医疗成像、工业 | Sony IMX 系列 |

**关键差异总结**：
- LVDS/SubLVDS 是**纯物理层**标准，不定义协议层；MIPI 定义了完整的从协议到物理层的栈
- MIPI 的 LP 模式使其在空闲时功耗远低于 LVDS
- SubLVDS 是 Sony 私有的 LVDS 变体，主要用于其 CMOS Sensor 产品线
- 现代手机 SoC 普遍支持 MIPI CSI-2/DSI，LVDS 在移动领域已基本被取代

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | MIPI CSI-2 Specification v3.0 | 摄像头接口协议规范 |
| REF-002 | MIPI DSI Specification v1.3 | 显示接口协议规范 |
| REF-003 | MIPI D-PHY Specification v2.5 | D-PHY 物理层规范 |
| REF-004 | MIPI C-PHY Specification v2.0 | C-PHY 物理层规范 |
| REF-005 | MIPI I3C Specification v1.1 | I3C 控制总线规范 |
