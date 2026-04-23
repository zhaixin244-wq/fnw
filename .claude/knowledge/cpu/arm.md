# ARM 架构

> **用途**：ARM Cortex 处理器架构设计参考，供 SoC/CPU 子系统设计时检索
> **架构版本**：ARMv8-A / ARMv9-A
> **典型应用**：手机、服务器、汽车、IoT

---

## 架构概述

ARM 是最广泛使用的商业处理器 ISA，Cortex 系列覆盖从低功耗 MCU 到高性能服务器。ARMv8 引入 AArch64（64-bit），ARMv9 引入 SVE2/RME。

### 关键特性

- **成熟生态**：最广泛的软件支持、工具链、IP 授权
- **多系列覆盖**：Cortex-A（应用）、Cortex-R（实时）、Cortex-M（嵌入式）
- **安全扩展**：TrustZone 安全世界
- **虚拟化**：EL2 硬件虚拟化支持
- **向量扩展**：NEON（128-bit）→ SVE/SVE2（可变长度）

---

## Cortex 系列对比

| 系列 | 架构 | 流水线 | 典型频率 | 应用场景 |
|------|------|--------|----------|----------|
| Cortex-M0/M0+ | ARMv6-M | 2-3 级 | 50-100 MHz | 超低功耗 MCU |
| Cortex-M3 | ARMv7-M | 3 级 | 50-200 MHz | 通用 MCU |
| Cortex-M4 | ARMv7E-M | 3 级 | 50-200 MHz | DSP + FPU |
| Cortex-M7 | ARMv7E-M | 6 级 | 100-600 MHz | 高性能 MCU |
| Cortex-M55 | ARMv8.1-M | 4-6 级 | 100-300 MHz | AI + DSP |
| Cortex-R4 | ARMv7-R | 8 级 | 200-600 MHz | 实时控制 |
| Cortex-R52 | ARMv8-R | 8+ 级 | 200-800 MHz | 汽车/工业 |
| Cortex-A55 | ARMv8.2-A | 8 级 | 1-2 GHz | 效率核 |
| Cortex-A78 | ARMv8.2-A | 11+ 级 | 2-3 GHz | 性能核 |
| Cortex-A710 | ARMv9-A | 10+ 级 | 2-3 GHz | 性能核（ARMv9） |
| Cortex-X3 | ARMv9-A | 10+ 级 | 3+ GHz | 超大核 |
| Neoverse N2 | ARMv9-A | 10+ 级 | 2-3 GHz | 服务器 |

---

## 特权级（ARMv8-A）

| Exception Level | 名称 | 典型用途 |
|-----------------|------|----------|
| EL0 | User | 应用程序 |
| EL1 | Kernel | OS 内核 |
| EL2 | Hypervisor | 虚拟化 |
| EL3 | Secure Monitor | 安全切换 |

### 安全世界

```
┌─────────────────────────────────────────────┐
│              Normal World                    │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐    │
│  │  EL0    │  │  EL1    │  │  EL2    │    │
│  │ (App)   │  │ (Linux) │  │ (KVM)   │    │
│  └─────────┘  └─────────┘  └─────────┘    │
├─────────────────────────────────────────────┤
│              Secure World                    │
│  ┌─────────┐  ┌─────────┐                  │
│  │  EL0    │  │  EL1    │                  │
│  │(Trusted)│  │(OP-TEE) │                  │
│  └─────────┘  └─────────┘                  │
├─────────────────────────────────────────────┤
│              EL3 (Secure Monitor)            │
│         ARM Trusted Firmware (ATF)          │
└─────────────────────────────────────────────┘
```

---

## 寄存器（AArch64）

### 通用寄存器

| 寄存器 | 位宽 | 用途 | 调用约定 |
|--------|------|------|----------|
| X0-X7 | 64-bit | 参数/返回值 | Caller-saved |
| X8 | 64-bit | 间接结果寄存器 | Caller-saved |
| X9-X15 | 64-bit | 临时寄存器 | Caller-saved |
| X16-X17 | 64-bit | IP0/IP1（过程调用） | Caller-saved |
| X18 | 64-bit | 平台寄存器 | - |
| X19-X28 | 64-bit | 保存寄存器 | Callee-saved |
| X29 | 64-bit | 帧指针 (FP) | Callee-saved |
| X30 | 64-bit | 链接寄存器 (LR) | Caller-saved |
| SP | 64-bit | 栈指针 | - |
| XZR | 64-bit | 零寄存器 | - |

### SIMD/浮点寄存器

| 寄存器 | 位宽 | 用途 |
|--------|------|------|
| V0-V31 | 128-bit | NEON/浮点/SVE |
| D0-D31 | 64-bit | 双精度浮点 |
| S0-S31 | 32-bit | 单精度浮点 |
| H0-H31 | 16-bit | 半精度浮点 |

### 系统寄存器

| 寄存器 | EL | 功能 |
|--------|----|------|
| SCTLR_EL1 | EL1 | 系统控制（MMU、Cache） |
| TCR_EL1 | EL1 | 页表控制 |
| TTBR0_EL1 | EL1 | 用户页表基址 |
| TTBR1_EL1 | EL1 | 内核页表基址 |
| VBAR_EL1 | EL1 | 异常向量基址 |
| ESR_EL1 | EL1 | 异常综合寄存器 |
| FAR_EL1 | EL1 | 故障地址 |
| MAIR_EL1 | EL1 | 内存属性 |
| SCTLR_EL2 | EL2 | 虚拟化控制 |
| HCR_EL2 | EL2 | Hypervisor 配置 |
| SCR_EL3 | EL3 | 安全配置 |

---

## 指令集（AArch64）

### 指令格式

```
| 31    21 | 20  16 | 15  10 | 9   5 | 4    0 |
|----------|--------|--------|-------|--------|
| opcode   |  Rn    |  Rm    | shift |  Rd    |  R-type

| 31    22 | 21  10 | 9   5 | 4    0 |
|----------|--------|-------|--------|
| opcode   | imm12  |  Rn   |  Rd    |  I-type

| 31    25 | 24  21 | 20  16 | 15   5 | 4    0 |
|----------|--------|--------|--------|--------|
| opcode   | opc    |  Rm    | imm6   | Rn/Rd  |  R-type (shifted)
```

### 常用指令类别

| 类别 | 指令示例 | 说明 |
|------|----------|------|
| 算术 | ADD, SUB, MUL, SDIV | 加减乘除 |
| 逻辑 | AND, ORR, EOR, BIC | 逻辑运算 |
| 移位 | LSL, LSR, ASR, ROR | 移位操作 |
| 比较 | CMP, CMN, TST | 比较并设置标志 |
| 分支 | B, BL, BR, BLR, RET | 无条件/条件分支 |
| 加载/存储 | LDR, STR, LDP, STP | 内存访问 |
| 系统 | MSR, MRS, SVC, HVC, SMC | 系统调用 |
| SIMD | ADD.4S, MUL.4S, FMLA.4S | NEON 向量运算 |
| SVE | LD1W, ST1W, ADD.Z | SVE 向量运算 |

---

## 异常处理

### 异常类型

| 类型 | 来源 | 处理 |
|------|------|------|
| 同步异常 | 指令执行 | 跳转到 VBAR_ELx |
| IRQ | 外部中断 | 跳转到 VBAR_ELx + 0x80 |
| FIQ | 快速中断 | 跳转到 VBAR_ELx + 0x100 |
| SError | 系统错误 | 跳转到 VBAR_ELx + 0x180 |

### 异常向量表

```
VBAR_ELx + 0x000: 同步异常（当前 EL，SP_EL0）
VBAR_ELx + 0x080: IRQ（当前 EL，SP_EL0）
VBAR_ELx + 0x100: FIQ（当前 EL，SP_EL0）
VBAR_ELx + 0x180: SError（当前 EL，SP_EL0）
VBAR_ELx + 0x200: 同步异常（当前 EL，SP_ELx）
VBAR_ELx + 0x280: IRQ（当前 EL，SP_ELx）
VBAR_ELx + 0x300: FIQ（当前 EL，SP_ELx）
VBAR_ELx + 0x380: SError（当前 EL，SP_ELx）
VBAR_ELx + 0x400: 同步异常（低 EL，AArch64）
VBAR_ELx + 0x480: IRQ（低 EL，AArch64）
VBAR_ELx + 0x500: FIQ（低 EL，AArch64）
VBAR_ELx + 0x580: SError（低 EL，AArch64）
VBAR_ELx + 0x600: 同步异常（低 EL，AArch32）
VBAR_ELx + 0x680: IRQ（低 EL，AArch32）
VBAR_ELx + 0x700: FIQ（低 EL，AArch32）
VBAR_ELx + 0x780: SError（低 EL，AArch32）
```

---

## GIC（通用中断控制器）

### GICv3/v4 架构

| 组件 | 功能 | 接口 |
|------|------|------|
| Distributor | 全局中断分发 | MMIO |
| Redistributor | 每 CPU 中断路由 | MMIO |
| CPU Interface | CPU 中断应答 | 系统寄存器 |

### 中断类型

| 类型 | ID 范围 | 说明 |
|------|---------|------|
| SGI | 0-15 | 软件触发中断（核间通信） |
| PPI | 16-31 | 私有外设中断（每 CPU） |
| SPI | 32-1019 | 共享外设中断 |
| LPI | 8192+ | 局部外设中断（GICv3） |

---

## 设计注意事项

### RTL 实现要点

1. **译码器**：ARM 指令编码复杂，需多级译码
2. **条件执行**：ARMv7 有条件执行，ARMv8 仅条件分支
3. **TrustZone**：需安全状态切换逻辑
4. **GIC**：中断控制器通常作为独立 IP
5. **NEON/SVE**：向量单元面积大，需独立电源域

### 面积/功耗权衡

| 核心 | 面积 (mm²) | 功耗 | 性能 |
|------|-----------|------|------|
| Cortex-M0 | ~0.01 | ~10 μW/MHz | 0.9 DMIPS/MHz |
| Cortex-M4 | ~0.03 | ~30 μW/MHz | 1.25 DMIPS/MHz |
| Cortex-A55 | ~0.3 | ~100 mW | 4 DMIPS/MHz |
| Cortex-A78 | ~1.0 | ~500 mW | 8 DMIPS/MHz |
| Cortex-X3 | ~2.0 | ~1 W | 10+ DMIPS/MHz |

### 常见陷阱

1. **大小端**：ARM 支持大小端，需明确配置
2. **对齐**：非对齐访问可能触发异常或性能惩罚
3. **Cache 一致性**：多核需 GIC + SCU 或 CHI
4. **安全切换**：EL3 ↔ EL1 需 SMC 调用
5. **向量长度**：SVE 长度可变（128-2048-bit），需适配

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | ARM ARM (DDI 0487) | 架构参考手册 |
| REF-002 | ARM GIC Spec (IHI 0069) | GICv3/v4 规范 |
| REF-003 | ARM TRM (核心 TRM) | 各核心技术参考 |
| REF-004 | ARM SVE Spec | SVE 规范 |
