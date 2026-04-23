# ddr_ip

> DDR 控制器 IP 选型参考，DDR3/DDR4/DDR5/LPDDR 版本对比

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | IP |
| 来源 | .claude/knowledge/IP/ddr_ip.md |

## 核心特性
- DDR（Double Data Rate）是主流内存标准
- 版本演进：DDR3(2133MT/s) → DDR4(3200MT/s) → DDR5(6400MT/s)
- LPDDR 系列针对移动设备低功耗优化
- 供应商：Synopsys（DesignWare）、Cadence、Rambus

## 关键参数

| 版本 | 速率 | 带宽 | 电压 | 典型应用 |
|------|------|------|------|----------|
| DDR4 | 1600-3200 MT/s | 12.8-25.6 GB/s | 1.2V | 服务器、PC |
| DDR5 | 3200-6400 MT/s | 25.6-51.2 GB/s | 1.1V | 新服务器 |
| LPDDR5 | 6400 MT/s | 51.2 GB/s | 1.05V | 移动设备 |
| LPDDR5X | 8533 MT/s | 68.2 GB/s | 1.05V | 旗舰手机 |

## 典型应用场景
- 服务器内存子系统
- 移动设备内存
- 高性能计算

## 与其他实体的关系
- **ddr**：DDR 协议规范
- **crossbar**：DDR 控制器前端互联

## 设计注意事项
- DDR 控制器需配合 PHY IP
- DDR5 引入 ECC on-die 和双通道
- LPDDR5X 支持 Bank 架构优化

## 参考
- 原始文档：`.claude/knowledge/IP/ddr_ip.md`
