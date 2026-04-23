# UDP (User Datagram Protocol)

> 传输层无连接传输协议，提供简单的多路复用和校验和，延迟低、开销小，适合实时和 RDMA 场景。

## 基本信息

| 字段 | 内容 |
|------|------|
| **类型** | 网络协议（L4 传输层） |
| **标准** | RFC 768 (UDP) / RFC 2460 (UDP-IPv6) |
| **传输模式** | 无连接、不可靠、无序、数据报 |

## 核心特性

1. **极简头部**：仅 8 字节 (Src Port + Dst Port + Length + Checksum)，无状态、无握手
2. **校验和**：IPv4 可选（但推荐），IPv6 强制。伪首部 (IP Src/Dst + Proto + UDP Length) + UDP 头 + Data
3. **UDP-Lite (RFC 3828)**：部分校验和，仅覆盖头部和部分载荷，适合语音/视频容错
4. **GRO/LRO 卸载**：UDP GRO 将多个小包合并为大包减少 CPU 开销

## 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 头部长度 | 8 bytes (固定) | SrcPort(2B) + DstPort(2B) + Len(2B) + CS(2B) |
| 端口范围 | 0-65535 | 0-1023 知名端口，4791=RoCE v2 |
| 最大载荷 | 65527 bytes | 65535 - 8 (UDP 头) |
| 校验和 | 16-bit one's complement | IPv4 可选 / IPv6 强制 |

## 典型应用场景

- **RoCE v2**：UDP DstPort=4791 承载 RDMA，ECN 拥塞通知
- **NVMe over TCP vs NVMe/RDMA**：RDMA 路径使用 UDP (RoCE v2)
- **VXLAN**：UDP DstPort=4789 承载 L2 帧
- **DNS / DHCP / NTP**：请求-响应式协议
- **实时音视频**：RTP over UDP

## 与其他协议的关系

| 协议 | 关系 |
|------|------|
| IP | 网络层承载，Protocol=17 |
| TCP | 替代协议，TCP 可靠但延迟高 |
| RoCE v2 | RDMA BTH 头部封装在 UDP 载荷内 |
| VXLAN/GENEVE | 隧道封装使用 UDP 端口 |
| ECN | RoCE v2 依赖 IP ECN + UDP |

## RTL 设计要点

- **校验和计算**：16-bit one's complement 累加，伪首部包含 IP Src/Dst/Proto/UDP Len
- **端口解析**：仅需提取 16-bit DstPort，与 TCP 端口区分 (Protocol 字段)
- **RoCE v2 识别**：UDP DstPort=4791 + BTH Magic → RDMA 路径
- **VXLAN 识别**：UDP DstPort=4789 → 隧道解封装路径
- **GRO 聚合**：相同五元组 + 连续序列号 → 合并为大包，需跟踪包边界
- **长度字段校验**：UDP Length 必须 ≥ 8 且与 IP Total Length 一致

## 参考

- RFC 768 (UDP)
- RFC 3828 (UDP-Lite)
- RFC 7348 (VXLAN - UDP Port 4789)
- IB Spec Vol.1 Appendix A (RoCE v2 - UDP Port 4791)
