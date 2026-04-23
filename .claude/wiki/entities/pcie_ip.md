# pcie_ip

> PCIe 控制器 IP 选型参考，Gen1~Gen6 版本对比

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/pcie_ip.md |

## 核心特性
- 高速串行互联标准，广泛用于服务器/PC/嵌入式
- 版本演进：Gen1(2.5GT/s) → Gen3(8GT/s) → Gen5(32GT/s) → Gen6(64GT/s)
- 支持 Endpoint/Root Complex/Switch 角色
- 供应商：Synopsys（DesignWare）、Cadence（Denali）、PLDA、Altera

## 关键参数

| 版本 | 速率 | 带宽/lane | 编码 | 典型应用 |
|------|------|----------|------|----------|
| Gen3 | 8.0 GT/s | 1 GB/s | 128b/130b | 服务器 |
| Gen4 | 16.0 GT/s | 2 GB/s | 128b/130b | 服务器 |
| Gen5 | 32.0 GT/s | 4 GB/s | 128b/130b | 高端服务器 |
| Gen6 | 64.0 GT/s | 8 GB/s | 1b/1b | 未来服务器 |

## 典型应用场景
- 服务器 PCIe Root Complex
- 网卡/DPU PCIe Endpoint
- NVMe 存储控制器

## 与其他实体的关系
- **pcie**：PCIe 协议规范
- **pcie_tlp**：PCIe 事务层包格式
- **sr_iov**：PCIe 虚拟化

## 设计注意事项
- Gen6 引入 FLIT 模式和 IDE 加密
- PCIe IP 通常需要 PHY IP 配合
- 链路训练和协商需要 LTSSM 状态机

## 参考
- 原始文档：`.claude/knowledge/IP/pcie_ip.md`
