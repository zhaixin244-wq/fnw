# VLAN & QoS

> IEEE 802.1Q VLAN 标签与 QoS 机制，提供二层网络隔离、流量分类与优先级调度。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络协议（L2 数据链路层） |
| **标准** | IEEE 802.1Q / 802.1Qbb / 802.1Qaz / 802.1Qbv |
| **核心功能** | VLAN 隔离、优先级调度、流量整形、拥塞控制 |

## 核心特性

1. **VLAN Tag (802.1Q)**：4 字节插入 EtherType 后，TPID=0x8100，12-bit VLAN ID (0-4095)，3-bit PCP 优先级
2. **QinQ (802.1ad)**：双层 VLAN Tag (S-VLAN + C-VLAN)，TPID=0x88A8，运营商级隔离
3. **PFC (802.1Qbb)**：基于 CoS (Class of Service) 的逐优先级流控，8 个独立 Pause 通道，零丢包
4. **ETS (802.1Qaz)**：增强传输调度，支持 Strict Priority / WRR / ETS 三种模式，带宽分配
5. **DiffServ**：DSCP (6-bit) 映射到 CoS/队列，EF/AF/BE 服务等级

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| VLAN ID | 12 bit (0-4095) | 0 和 4095 保留 |
| PCP | 3 bit (0-7) | 优先级，7=最高 |
| CoS 队列数 | 8 | PFC/ETS 管理的流量等级 |
| DSCP | 6 bit (0-63) | DiffServ 代码点 |
| PFC Pause | 按 CoS | Quanta 字段指定暂停时间 |
| ETS Bandwidth | % per TC | 每个 Traffic Class 的带宽比例 |

## 典型应用场景

- 数据中心无损网络（RoCE v2 需 PFC + ECN）
- 多租户网络隔离（VLAN/VXLAN）
- HPC / AI 集群 QoS 保障

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| Ethernet | VLAN Tag 嵌入以太帧 |
| IP (DSCP) | L3 DiffServ 映射到 L2 CoS |
| RoCE v2 | 依赖 PFC 实现无损传输 |
| ECMP | 基于 VLAN/CoS 的流量分类后做 ECMP |
| VXLAN | L2-over-L3 隧道，内层保留 VLAN 信息 |

## RTL 设计要点

- **VLAN 解析**：解析 TPID=0x8100/0x88A8，提取 VID/PCP/DEI，支持 QinQ 双层剥离
- **PFC 帧生成/解析**：MAC Control Opcode=0x0101，8-bit Priority Enable Bitmap + 8 个 Quanta 值
- **队列调度器**：8 队列 WRR + Strict Priority 混合调度，带宽加权参数可配
- **ETS 带宽分配**：Token Bucket per TC，支持 CBS (Committed Burst Size) + EBS
- **PCP→队列映射**：查找表 (LUT) 实现 PCP→TC→Queue 三级映射
- **QinQ 标签处理**：双层 TPID 识别，内/外层 VLAN 分别处理

## 参考

- IEEE 802.1Q-2022
- IEEE 802.1Qbb (PFC)
- IEEE 802.1Qaz (ETS / DCBX)
- IEEE 802.1Qbv (Time-Aware Shaper)
- RFC 2474 (DiffServ)
