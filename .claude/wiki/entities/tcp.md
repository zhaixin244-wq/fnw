# TCP (Transmission Control Protocol)

> 传输层面向连接的可靠传输协议，提供流量控制、拥塞控制和有序交付，是互联网最重要的传输协议。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络协议（L4 传输层） |
| **标准** | RFC 9293 (TCP) / RFC 5681 (Congestion Control) |
| **传输模式** | 面向连接、可靠、有序、字节流 |

## 核心特性

1. **三次握手/四次挥手**：SYN→SYN-ACK→ACK 建立连接；FIN→ACK→FIN→ACK 释放连接
2. **可靠传输**：序列号 + ACK + 超时重传 + 快速重传 (3 重复 ACK)
3. **流量控制**：滑动窗口 + 接收窗口 (RWND)，防止接收端溢出
4. **拥塞控制**：慢启动 (SS) → 拥塞避免 (CA) → 快速恢复 (FR)，CWND 拥塞窗口
5. **TOE (TCP Offload Engine)**：硬件卸载 TCP 处理，包括 Segmentation、Checksum、Retransmit

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 头部长度 | 20-60 bytes | 固定 20B + 可选字段 |
| 序列号 | 32 bit | 字节级编号 |
| 窗口大小 | 16 bit + Window Scale | 最大 1GB (Scale=14) |
| MSS | 1460 bytes (典型) | 最大报文段长度 |
| 超时 RTO | 动态计算 | 基于 RTT (SRTT + RTTVAR) |
| 拥塞算法 | Cubic / BBR / DCQCN | 数据中心常用 DCTCP/DCQCN |

## 典型应用场景

- TOE (TCP Offload Engine) 网卡硬件加速
- SmartNIC / DPU TCP 处理卸载
- NVMe over TCP 硬件卸载

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| IP | 网络层承载，Protocol=6 |
| UDP | 替代协议，无连接不可靠 |
| RoCE v2 | RDMA 使用 UDP 而非 TCP |
| NVMe-oF | NVMe over TCP (NVMe/TCP) |
| TLS/SSL | TCP 上层加密，硬件 TLS offload |

## RTL 设计要点

- **序列号管理**：32-bit 序列号环形空间，SYN/FIN 占 1 序列号，wrap-around 比较逻辑
- **滑动窗口**：SND.UNA / SND.NXT / SND.WND 三指针，RCV.WND 接收窗口管理
- **重传定时器**：每连接独立 RTO 定时器，指数退避 (×2)，最小 1s / 最大 60s (Linux)
- **Checksum offload**：TCP 伪首部 + 头部 + 数据的 16-bit 校验和，Tx/Rx 分别卸载
- **TSO (TCP Segmentation Offload)**：大包分段引擎，按 MSS 拆分，序列号递增，IP ID 递增
- **RSS (Receive Side Scaling)**：Toeplitz 哈希 (SIP+DIP+SP+DP) 分流到多队列
- **连接表**：TCAM/SRAM 存储 TCB (Transmission Control Block)，五元组索引

## 参考

- RFC 9293 (TCP)
- RFC 5681 (Congestion Control)
- RFC 7323 (TCP Extensions)
- RFC 8257 (DCTCP)
