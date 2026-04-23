# PCIe IP

> **用途**：PCIe 控制器 IP 选型参考，供 SoC/DPU/网卡架构设计时检索
> **典型应用**：服务器、DPU、网卡、存储控制器

---

## 概述

PCIe（Peripheral Component Interconnect Express）是高速串行互联标准，广泛用于服务器、PC 和嵌入式系统。

### PCIe 版本对比

| 版本 | 速率 | 带宽/lane | 编码 | 典型应用 |
|------|------|----------|------|----------|
| Gen1 | 2.5 GT/s | 250 MB/s | 8b/10b | 旧设备 |
| Gen2 | 5.0 GT/s | 500 MB/s | 8b/10b | 旧设备 |
| Gen3 | 8.0 GT/s | 1 GB/s | 128b/130b | 服务器 |
| Gen4 | 16.0 GT/s | 2 GB/s | 128b/130b | 服务器 |
| Gen5 | 32.0 GT/s | 4 GB/s | 128b/130b | 高端服务器 |
| Gen6 | 64.0 GT/s | 8 GB/s | 1b/1b | 未来服务器 |

### 带宽对比

| 版本 | x1 | x4 | x8 | x16 |
|------|----|----|----|----|
| Gen3 | 1 GB/s | 4 GB/s | 8 GB/s | 16 GB/s |
| Gen4 | 2 GB/s | 8 GB/s | 16 GB/s | 32 GB/s |
| Gen5 | 4 GB/s | 16 GB/s | 32 GB/s | 64 GB/s |
| Gen6 | 8 GB/s | 32 GB/s | 64 GB/s | 128 GB/s |

---

## PCIe IP 供应商

### Synopsys

| IP | 版本 | 配置 | 典型应用 |
|------|------|------|----------|
| DesignWare PCIe | Gen3/4/5 | RC/EP/NTB | 服务器、DPU |
| DesignWare PCIe Gen6 | Gen6 | RC/EP | 未来服务器 |

**关键特性**：
- 支持 Gen3/4/5/6
- 支持 RC（Root Complex）、EP（Endpoint）、NTB（Non-Transparent Bridge）
- 支持 SR-IOV
- 支持 MSI/MSI-X
- 支持 DMA

### Cadence

| IP | 版本 | 配置 | 典型应用 |
|------|------|------|----------|
| Cadence PCIe | Gen3/4/5 | RC/EP/NTB | 服务器、DPU |
| Cadence PCIe Gen6 | Gen6 | RC/EP | 未来服务器 |

**关键特性**：
- 支持 Gen3/4/5/6
- 支持 RC、EP、NTB
- 支持 SR-IOV
- 支持 MSI/MSI-X

### ARM

| IP | 版本 | 配置 | 典型应用 |
|------|------|------|----------|
| ARM PCIe | Gen3/4 | EP | 嵌入式、SoC |

**关键特性**：
- 支持 Gen3/4
- 主要用于 EP
- 与 ARM 核心集成良好

---

## PCIe 配置选项

### 基础配置

| 配置 | 选项 | 权衡 |
|------|------|------|
| 版本 | Gen3/4/5/6 | 性能 vs 功耗/面积 |
| 宽度 | x1/x2/x4/x8/x16 | 带宽 vs 引脚数 |
| 角色 | RC/EP/NTB | 功能 vs 复杂度 |
| 功能 | 基本/完整 | 功能 vs 面积 |

### 高级配置

| 配置 | 选项 | 说明 |
|------|------|------|
| SR-IOV | 支持/不支持 | 虚拟化支持 |
| MSI-X | 支持/不支持 | 中断支持 |
| DMA | 内置/外部 | 数据传输 |
| ATS | 支持/不支持 | 地址转换 |
| TLP 包大小 | 128B-4KB | 最大包大小 |
| Outstanding | 数量 | 未完成事务数 |

---

## PCIe 接口

### 用户侧接口

| 接口 | 说明 | 典型实现 |
|------|------|----------|
| AXI4 | 数据传输 | AXI4 Master/Slave |
| AXI4-Lite | 寄存器访问 | AXI4-Lite |
| AXI4-Stream | 流式数据 | TLP 包接口 |

### 物理侧接口

| 接口 | 说明 | 典型实现 |
|------|------|----------|
| SerDes | 高速串行 | 内置/外部 |
| PIPE | PHY 接口 | PIPE 4.0/5.0 |

### 配置接口

| 接口 | 说明 | 典型实现 |
|------|------|----------|
| APB | 寄存器配置 | APB Slave |
| JTAG | 调试 | JTAG Master |

---

## PCIe 功能

### 事务层包（TLP）

| TLP 类型 | 说明 | 用途 |
|----------|------|------|
| Memory Read | 内存读请求 | DMA 读 |
| Memory Write | 内存写请求 | DMA 写 |
| Completion | 完成包 | 响应请求 |
| Message | 消息包 | 中断、电源管理 |

### 流控（Flow Control）

- **Credit-based**：基于信用的流控
- **Posted/Non-posted**：区分已发送/未发送
- **Header/Data**：分离头部和数据信用

### 错误处理

| 错误类型 | 说明 | 处理 |
|----------|------|------|
| ECRC 错误 | 端到端 CRC | 重传 |
| LCRC 错误 | 链路 CRC | 重传 |
| 超时 | 响应超时 | 重试 |
| 毒性包 | 数据错误 | 丢弃 |

---

## SR-IOV

### SR-IOV 功能

- **PF（Physical Function）**：完整 PCIe 功能
- **VF（Virtual Function）**：轻量级虚拟功能
- **设备直通**：VF 直接分配给虚拟机

### SR-IOV 配置

| 配置 | 选项 | 说明 |
|------|------|------|
| PF 数量 | 1-8 | 物理功能数量 |
| VF 数量 | 0-256 | 虚拟功能数量 |
| MSI-X 数量 | 1-2048 | 每功能中断数 |

---

## 性能指标

### 延迟

| 版本 | 链路延迟 | TLP 延迟 | 总延迟 |
|------|----------|----------|--------|
| Gen3 | ~100 ns | ~200 ns | ~300 ns |
| Gen4 | ~100 ns | ~150 ns | ~250 ns |
| Gen5 | ~100 ns | ~100 ns | ~200 ns |

### 带宽效率

| 版本 | 理论带宽 | 有效带宽 | 效率 |
|------|----------|----------|------|
| Gen3 x16 | 16 GB/s | 14 GB/s | 87% |
| Gen4 x16 | 32 GB/s | 28 GB/s | 87% |
| Gen5 x16 | 64 GB/s | 56 GB/s | 87% |

---

## 选型建议

### 嵌入式 EP

- **推荐**：ARM PCIe Gen3
- **配置**：x1/x2，AXI4 接口
- **理由**：面积小，与 ARM 核心集成好

### 服务器 EP

- **推荐**：Synopsys/Cadence PCIe Gen4/5
- **配置**：x8/x16，AXI4-Stream 接口
- **理由**：高性能，功能完整

### DPU/SmartNIC

- **推荐**：Synopsys PCIe Gen4/5
- **配置**：x8/x16，SR-IOV，DMA
- **理由**：虚拟化支持，高带宽

### 服务器 RC

- **推荐**：Synopsys/Cadence PCIe Gen4/5
- **配置**：x16，完整功能
- **理由**：高性能，功能完整

---

## 集成注意事项

### 接口匹配

- **AXI 接口**：确保与 SoC 互联匹配
- **时钟域**：PCIe 时钟与系统时钟同步
- **中断**：MSI/MSI-X 中断路由

### 验证策略

- **协议验证**：PCIe 协议一致性
- **性能验证**：带宽和延迟测试
- **互操作性**：与其他 PCIe 设备兼容

### 物理集成

- **SerDes**：高速 SerDes 布局
- **电源**：独立电源域
- **DFT**：扫描链、BIST 集成

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | PCIe Spec | PCIe 官方规范 |
| REF-002 | Synopsys PCIe IP | Synopsys IP 文档 |
| REF-003 | Cadence PCIe IP | Cadence IP 文档 |
| REF-004 | ARM PCIe IP | ARM IP 文档 |
