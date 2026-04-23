# ethernet_ip

> 以太网 MAC/PHY IP 选型参考，10M~800G 速率覆盖

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/ethernet_ip.md |

## 核心特性
- 以太网是最广泛使用的局域网技术
- MAC（媒体访问控制）+ PHY（物理层）两层
- 速率覆盖：10M → 1G → 10G → 25G → 100G → 400G → 800G
- 供应商：Synopsys、Cadence、Marvell、Broadcom

## 关键参数

| 速率 | 标准 | 典型应用 |
|------|------|----------|
| 1G | IEEE 802.3ab | 通用 |
| 10G | IEEE 802.3ae | 服务器 |
| 25G | IEEE 802.3by | 数据中心 |
| 100G | IEEE 802.3ba | 数据中心 |
| 400G | IEEE 802.3bs | 数据中心 |
| 800G | IEEE 802.3df | 未来数据中心 |

## 典型应用场景
- 网卡/DPU MAC 设计
- 交换芯片端口
- SoC 集成以太网

## 与其他实体的关系
- **ethernet**：以太网协议规范
- **vlan_qos**：VLAN 和 QoS 支持
- **pcie_ip**：网卡 PCIe 接口

## 设计注意事项
- MAC 需要支持流量控制（Pause Frame）
- 高速以太网需要 FEC（前向纠错）
- PHY 通常需要单独的模拟 IP

## 参考
- 原始文档：`.claude/knowledge/IP/ethernet_ip.md`
