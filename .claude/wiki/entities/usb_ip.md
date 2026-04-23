# usb_ip

> USB 控制器 IP 选型参考，USB 1.1~USB4 2.0 版本对比

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/usb_ip.md |

## 核心特性
- USB 是最广泛使用的外设接口标准
- 版本演进：USB 2.0(480Mbps) → USB 3.0(5Gbps) → USB4(40Gbps) → USB4 2.0(80Gbps)
- 支持 Host/Device/OTG 角色
- 供应商：Synopsys、Cadence、CHIPIDEA

## 关键参数

| 版本 | 速率 | 有效带宽 | 典型应用 |
|------|------|----------|----------|
| USB 2.0 | 480 Mbps | 35 MB/s | 通用外设 |
| USB 3.0 | 5 Gbps | 400 MB/s | 高速存储 |
| USB 3.2 | 20 Gbps | 2.4 GB/s | 高速存储 |
| USB4 | 40 Gbps | 5 GB/s | 高速接口 |
| USB4 2.0 | 80 Gbps | 10 GB/s | 未来高速 |

## 典型应用场景
- 消费电子 USB Host
- 移动设备 USB Device/OTG
- SoC 集成 USB 控制器

## 与其他实体的关系
- **usb**：USB 协议规范
- **pcie_ip**：USB4 基于 PCIe 隧道

## 设计注意事项
- USB 3.0+ 需要单独的 PHY IP
- USB4 支持 PCIe/DP/USB 隧道复用
- USB PD（Power Delivery）需要独立的 PD 控制器

## 参考
- 原始文档：`.claude/knowledge/IP/usb_ip.md`
