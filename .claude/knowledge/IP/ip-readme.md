# IP 核知识库总览

> **用途**：芯片设计常用 IP 核参考文档，供 chip-arch agent 在 SoC 架构设计时快速检索
> **总计**：8 个文档，覆盖 4 大类别

---

## IP 分类索引

### 1. 处理器 IP（2 个）

| IP | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| RISC-V 处理器 | [riscv_core.md](riscv_core.md) | RISC-V 处理器 IP 选型 | 嵌入式、IoT、SoC |
| ARM 处理器 | [arm_core.md](arm_core.md) | ARM Cortex 处理器 IP 选型 | 手机、服务器、汽车 |

### 2. 接口 IP（3 个）

| IP | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| PCIe IP | [pcie_ip.md](pcie_ip.md) | PCIe 控制器 IP 选型 | 服务器、DPU、网卡 |
| DDR IP | [ddr_ip.md](ddr_ip.md) | DDR 控制器 IP 选型 | 所有需要内存的 SoC |
| 以太网 IP | [ethernet_ip.md](ethernet_ip.md) | 以太网 MAC/PHY IP 选型 | 网卡、交换芯片、SoC |

### 3. 外设 IP（2 个）

| IP | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| USB IP | [usb_ip.md](usb_ip.md) | USB 控制器 IP 选型 | 消费电子、IoC |
| SPI/I2C/UART IP | [spi_i2c_uart_ip.md](spi_i2c_uart_ip.md) | 低速外设 IP 选型 | 嵌入式、IoT |

### 4. 模拟 IP（1 个）

| IP | 文件 | 定位 | 典型应用 |
|------|------|------|----------|
| PLL/DLL | [pll_dll.md](pll_dll.md) | 时钟生成 IP 选型 | 所有时钟系统 |

---

## IP 选型考虑因素

| 因素 | 说明 | 权衡 |
|------|------|------|
| 性能 | 带宽、延迟、频率 | 性能 vs 功耗/面积 |
| 面积 | 逻辑面积、SRAM 面积 | 面积 vs 功能 |
| 功耗 | 动态功耗、静态功耗 | 功耗 vs 性能 |
| 工艺 | 支持的工艺节点 | 工艺 vs 成本 |
| 验证 | 验证状态、硅验证 | 风险 vs 成本 |
| 支持 | 技术支持、文档 | 支持 vs 成本 |
| 授权 | 授权模式、费用 | 成本 vs 灵活性 |

---

## IP 供应商

| 供应商 | 优势 | 典型 IP |
|--------|------|---------|
| ARM | 处理器 IP 领导者 | Cortex-A/R/M, Mali, Ethos |
| Synopsys | 接口 IP 领导者 | PCIe, DDR, USB, Ethernet |
| Cadence | 接口 IP + 验证 | PCIe, DDR, USB, Ethernet |
| Imagination | GPU + 接口 | PowerVR, Ethernet |
| SiFive | RISC-V 处理器 | U/S/E 系列 |
| Andes | RISC-V 处理器 | A/N 系列 |

---

## IP 集成注意事项

### 1. 接口匹配

- 确保 IP 接口与 SoC 互联匹配
- 考虑接口转换（如 AXI ↔ AHB）
- 注意时钟域 crossing

### 2. 验证策略

- IP 供应商提供验证环境
- 集成后需系统级验证
- 考虑形式验证和仿真

### 3. 物理集成

- IP 布局布线约束
- 电源域划分
- DFT 集成

### 4. 软件支持

- 驱动程序支持
- 固件支持
- 工具链支持

---

## 典型 SoC IP 需求

| SoC 类型 | 需要的 IP |
|----------|----------|
| **嵌入式 MCU** | RISC-V/ARM Cortex-M + SRAM + SPI/I2C/UART + PLL |
| **IoT SoC** | ARM Cortex-M + BLE/WiFi + SRAM + SPI/I2C + PLL |
| **应用处理器** | ARM Cortex-A + Mali GPU + DDR + PCIe + USB + PLL |
| **服务器 CPU** | 高性能核心 + DDR5 + PCIe 5.0 + 以太网 + PLL |
| **DPU/SmartNIC** | RISC-V/ARM + DDR + PCIe + 以太网 + PLL |
| **AI 加速器** | RISC-V/ARM + DDR + PCIe + 专用加速器 + PLL |

---

## 文档格式说明

每个 IP 文档包含以下标准章节：

| 章节 | 内容 |
|------|------|
| IP 概述 | 功能、版本、供应商 |
| 关键特性 | 性能、面积、功耗 |
| 接口 | 接口类型、信号 |
| 配置选项 | 可配置参数 |
| 集成注意事项 | 集成要点、常见问题 |
| 选型建议 | 不同场景推荐 |

**配合 chip-arch agent 使用**：在生成 SoC FS/微架构文档时，agent 会检索本目录下的文档作为 IP 选型参考。
