# MIPS 架构

> **用途**：MIPS 处理器架构设计参考，供嵌入式/网络设备 SoC 设计时检索
> **架构版本**：MIPS32r6 / MIPS64r6
> **典型应用**：网络设备、嵌入式、路由器、网关

---

## 架构概述

MIPS 是经典的 RISC ISA，早期广泛用于学术和商业处理器。2018 年 MIPS 架构开源（MIPS Open），但生态已逐渐被 RISC-V 超越。

### 关键特性

- **经典 RISC**：Load/Store 架构，固定长度指令
- **成熟工具链**：GCC/LLVM 支持
- **DSP 扩展**：MIPS DSP ASE 提供 SIMD 运算
- **多线程**：MT ASE 支持硬件多线程
- **虚拟化**：VZ ASE 支持硬件虚拟化

---

## ISA 版本对比

| 版本 | 位宽 | 寄存器 | 典型应用 |
|------|------|--------|----------|
| MIPS32r2 | 32-bit | 32 GPR | 经典嵌入式 |
| MIPS32r6 | 32-bit | 32 GPR | 新一代嵌入式 |
| MIPS64r2 | 64-bit | 32 GPR | 高端网络设备 |
| MIPS64r6 | 64-bit | 32 GPR | 服务器/网络 |

---

## 寄存器

### 通用寄存器（GPR）

| 寄存器 | 名称 | 用途 | 调用约定 |
|--------|------|------|----------|
| $0 | zero | 硬连线 0 | - |
| $1 | at | 汇编器临时 | Caller-saved |
| $2-$3 | v0-v1 | 返回值 | Caller-saved |
| $4-$7 | a0-a3 | 参数寄存器 | Caller-saved |
| $8-$15 | t0-t7 | 临时寄存器 | Caller-saved |
| $16-$23 | s0-s7 | 保存寄存器 | Callee-saved |
| $24-$25 | t8-t9 | 临时寄存器 | Caller-saved |
| $26-$27 | k0-k1 | 内核保留 | - |
| $28 | gp | 全局指针 | - |
| $29 | sp | 栈指针 | Callee-saved |
| $30 | fp/s8 | 帧指针 | Callee-saved |
| $31 | ra | 返回地址 | Caller-saved |

### 特殊寄存器

| 寄存器 | 用途 |
|--------|------|
| PC | 程序计数器 |
| HI | 乘法结果高位 / 除法余数 |
| LO | 乘法结果低位 / 除法商 |

### 浮点寄存器（FPR）

| 寄存器 | 位宽 | 用途 |
|--------|------|------|
| f0-f31 | 32/64-bit | 浮点运算 |
| FCSR | 32-bit | 浮点控制/状态 |

---

## 指令格式

### 三种基本格式

```
R-type: | opcode (6) | rs (5) | rt (5) | rd (5) | shamt (5) | funct (6) |
I-type: | opcode (6) | rs (5) | rt (5) | immediate (16) |
J-type: | opcode (6) | address (26) |
```

### 常用指令

| 类别 | 指令 | 说明 |
|------|------|------|
| 算术 | ADD, SUB, ADDU, SUBU | 加减（有符号/无符号） |
| 乘除 | MULT, MULTU, DIV, DIVU | 乘除法 |
| 逻辑 | AND, OR, XOR, NOR | 逻辑运算 |
| 移位 | SLL, SRL, SRA, SLLV | 移位操作 |
| 比较 | SLT, SLTU, BEQ, BNE | 比较/分支 |
| 加载 | LB, LH, LW, LD | 加载字节/半字/字/双字 |
| 存储 | SB, SH, SW, SD | 存储字节/半字/字/双字 |
| 分支 | BEQ, BNE, BGTZ, BLEZ | 条件分支 |
| 跳转 | J, JAL, JR, JALR | 无条件跳转 |
| 系统 | SYSCALL, BREAK, ERET | 系统调用/异常返回 |

---

## 特权级（MIPS32r6）

| 模式 | 名称 | 典型用途 |
|------|------|----------|
| Kernel | 内核模式 | OS 内核，完全访问 |
| Supervisor | 监督模式 | 部分 OS 功能（可选） |
| User | 用户模式 | 应用程序，受限访问 |

### CP0 寄存器（系统控制）

| 寄存器 | 编号 | 功能 |
|--------|------|------|
| Status | 12 | 处理器状态 |
| Cause | 13 | 异常原因 |
| EPC | 14 | 异常返回地址 |
| BadVAddr | 8 | 故障地址 |
| EntryHi | 10 | TLB 条目高位 |
| EntryLo0 | 2 | TLB 条目低位（偶页） |
| EntryLo1 | 3 | TLB 条目低位（奇页） |
| PageMask | 5 | TLB 页掩码 |
| Index | 0 | TLB 索引 |
| Random | 1 | TLB 随机索引 |
| Wired | 6 | TLB 固定条目数 |
| PRId | 15 | 处理器 ID |
| Config | 16 | 配置寄存器 |

---

## 异常处理

### 异常类型

| ExcCode | 名称 | 说明 |
|---------|------|------|
| 0 | Int | 中断 |
| 1 | Mod | TLB 修改异常 |
| 2 | TLBL | TLB 加载异常 |
| 3 | TLBS | TLB 存储异常 |
| 4 | AdEL | 地址错误（加载） |
| 5 | AdES | 地址错误（存储） |
| 6 | IBE | 总线错误（取指） |
| 7 | DBE | 总线错误（数据） |
| 8 | Sys | 系统调用 |
| 9 | Bp | 断点 |
| 10 | RI | 保留指令 |
| 11 | CpU | 协处理器不可用 |
| 12 | Ov | 算术溢出 |
| 13 | Tr | Trap |

### 异常处理流程

1. 设置 EPC = 异常指令地址
2. 设置 Cause.ExcCode = 异常类型
3. 设置 Status.EXL = 1（进入异常级）
4. PC = 异常向量地址（0x80000180 或 BEV=1 时 0xBFC00380）
5. 处理异常
6. ERET 返回（PC = EPC，Status.EXL = 0）

---

## TLB（后备转换缓冲）

### TLB 结构

| 字段 | 说明 |
|------|------|
| VPN2 | 虚拟页号（高位） |
| ASID | 地址空间 ID |
| PageMask | 页大小掩码 |
| PFN0/PFN1 | 物理帧号（偶/奇页） |
| V0/V1 | 有效位（偶/奇页） |
| D0/D1 | 脏位（偶/奇页） |
| C0/C1 | Cache 属性（偶/奇页） |

### TLB 查找流程

1. 比较 VPN2 和 ASID
2. 匹配后检查 V（有效位）
3. 检查 D（脏位）用于写保护
4. 输出 PFN + Offset = 物理地址

---

## 设计注意事项

### RTL 实现要点

1. **延迟槽**：分支/跳转后的指令总是执行（MIPS32r6 已取消）
2. **乘法器**：MULT/MULTU 需 32×32→64 位乘法器
3. **除法器**：DIV/DIVU 需多周期除法器
4. **TLB**：软件管理 TLB，需 TLB Refill 异常处理
5. **CP0**：系统控制寄存器需特权级保护

### 面积/功耗权衡

| 配置 | 面积 (kGates) | 功耗 | 性能 |
|------|---------------|------|------|
| MIPS32 单发射 | ~20 | 低 | 1.0 DMIPS/MHz |
| MIPS32 双发射 | ~50 | 中 | 1.5 DMIPS/MHz |
| MIPS32 74K | ~80 | 中高 | 2.0 DMIPS/MHz |
| MIPS64 | ~100+ | 高 | 2.5+ DMIPS/MHz |

### 常见陷阱

1. **延迟槽**：MIPS32r2 有延迟槽，r6 已取消
2. **对齐**：非对齐访问触发 AdEL/AdES 异常
3. **大小端**：MIPS 支持大小端，需明确配置
4. **TLB 管理**：软件管理 TLB，Refill 异常复杂
5. **分支条件**：比较结果在分支指令中使用，需前递

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | MIPS32 Architecture | 官方 ISA 规范 |
| REF-002 | MIPS64 Architecture | 64-bit ISA 规范 |
| REF-003 | MIPS MT ASE | 多线程扩展 |
| REF-004 | MIPS DSP ASE | DSP 扩展 |
