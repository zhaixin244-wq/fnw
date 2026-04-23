# TCP (Transmission Control Protocol) 协议知识文档

> **面向**：数字 IC 设计架构师（TCP 硬件卸载、NIC / TOE 设计参考）
> **核心规范**：RFC 793, RFC 1122, RFC 1323, RFC 2018, RFC 5681, RFC 6298, RFC 7414
> **最后更新**：2026-04-15

---

## 1. 协议概述

TCP（Transmission Control Protocol）是一种面向连接的、可靠的、有序的、全双工字节流传输层协议，定义于 RFC 793。

| 属性 | 说明 |
|------|------|
| **面向连接** | 通信前必须通过三次握手建立连接，通信结束后通过四次挥手释放连接 |
| **可靠传输** | 基于序列号（Sequence Number）、确认号（Acknowledgment Number）、超时重传和校验和保证数据无丢失、无重复 |
| **有序交付** | 接收端按序列号重组，确保字节流顺序与发送端一致 |
| **全双工** | 连接双方可同时发送和接收数据 |
| **字节流** | TCP 不保留消息边界，应用层数据被看作无结构的字节流 |
| **流量控制** | 基于接收窗口（Receive Window）防止发送方淹没接收方 |
| **拥塞控制** | 基于拥塞窗口（Congestion Window）防止发送方淹没网络 |

**硬件卸载关注点**：TCP 的可靠传输、拥塞控制、校验和计算等特性在高吞吐场景下需要硬件（NIC / TOE）加速，否则 CPU 开销过高。

---

## 2. TCP 报文段格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          Source Port          |       Destination Port        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Sequence Number                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Acknowledgment Number                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Offset|  Res  |C|E|U|A|P|R|S|F|            Window             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            Checksum           |         Urgent Pointer        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Options (variable)                 |  Pad   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                             Data                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 位宽 | 说明 |
|------|------|------|
| **Source Port** | 16 bit | 源端口号 |
| **Destination Port** | 16 bit | 目的端口号 |
| **Sequence Number** | 32 bit | 本报文段数据第一个字节的序列号 |
| **Acknowledgment Number** | 32 bit | 期望收到的下一个字节的序列号（ACK 标志置位时有效） |
| **Data Offset** | 4 bit | TCP 头部长度，以 4 字节为单位（最小 5 = 20 字节，最大 15 = 60 字节） |
| **Reserved** | 3 bit | 保留，必须为 0 |
| **Flags** | 9 bit | 控制标志（见下节） |
| **Window** | 16 bit | 接收窗口大小，以字节为单位（配合 Window Scale 可扩展） |
| **Checksum** | 16 bit | 覆盖 TCP 头部 + 数据 + 伪头部的校验和 |
| **Urgent Pointer** | 16 bit | URG 置位时有效，指示紧急数据的末尾偏移 |
| **Options** | 变长 | 可选项（MSS、Window Scale、SACK、Timestamps 等） |

**硬件设计要点**：
- Data Offset 字段决定头部长度，TOE 解析器必须先读取该字段再确定数据起始位置
- Checksum 覆盖伪头部（IP 源/目的地址 + 协议号 + TCP 长度），硬件校验和模块需额外获取 IP 层信息
- Options 字段变长，解析逻辑需支持逐项遍历

---

## 3. Flags 字段详解

Flags 字段在 RFC 793 中定义了 6 个控制位，RFC 3168 追加了 2 个 ECN 位，RFC 3540 追加了 1 个 NS 位：

| 标志 | 位位置 | 全称 | 含义 |
|------|--------|------|------|
| **CWR** | bit 8 | Congestion Window Reduced | 拥塞窗口已缩减，响应收到的 ECE 标志 |
| **ECE** | bit 7 | ECN-Echo | ECN 回显，通知对端网络发生拥塞 |
| **URG** | bit 6 | Urgent | Urgent Pointer 字段有效，标识紧急数据 |
| **ACK** | bit 5 | Acknowledgment | Acknowledgment Number 字段有效 |
| **PSH** | bit 4 | Push | 提示接收端立即将缓冲区数据递交应用层 |
| **RST** | bit 3 | Reset | 强制复位连接（异常中断） |
| **SYN** | bit 2 | Synchronize | 同步序列号，用于建立连接 |
| **FIN** | bit 1 | Finish | 发送方数据发送完毕，请求关闭连接 |
| **NS** | bit 0 | Nonce Sum | ECN nonce 隐藏保护（RFC 3540，实验性） |

**硬件设计要点**：
- Flags 解析是状态机的核心输入，连接管理状态机根据 SYN/ACK/FIN/RST 决定状态转移
- RST 报文处理需最高优先级，收到 RST 应立即终止连接并释放资源

---

## 4. 连接管理

### 4.1 三次握手（Connection Establishment）

```
    Client                              Server
      |                                   |
      |  -------- SYN, seq=x -------->   |   Client: CLOSED -> SYN_SENT
      |                                   |
      |  <--- SYN+ACK, seq=y, ack=x+1 -- |   Server: LISTEN -> SYN_RCVD
      |                                   |
      |  -------- ACK, ack=y+1 ------->   |   Client: SYN_SENT -> ESTABLISHED
      |                                   |   Server: SYN_RCVD -> ESTABLISHED
```

| 步骤 | 发送方 | Flags | seq | ack | 接收方状态变化 |
|------|--------|-------|-----|-----|----------------|
| 1 | Client | SYN | x | - | Server 进入 SYN_RCVD |
| 2 | Server | SYN+ACK | y | x+1 | - |
| 3 | Client | ACK | x+1 | y+1 | 双方进入 ESTABLISHED |

- 初始序列号 x、y 各自随机选取（防止旧连接的残留报文段干扰）
- 第三次握手可携带数据（TCP Fast Open）

### 4.2 四次挥手（Connection Termination）

```
    Client (主动关闭方)                  Server (被动关闭方)
      |                                   |
      |  -------- FIN, seq=u -------->   |   Client: ESTABLISHED -> FIN_WAIT_1
      |                                   |
      |  <-------- ACK, ack=u+1 -------  |   Server: ESTABLISHED -> CLOSE_WAIT
      |                                   |   Client: FIN_WAIT_1 -> FIN_WAIT_2
      |                                   |
      |  <--- FIN, seq=w ---------------  |   Server 数据发完后
      |                                   |   Server: CLOSE_WAIT -> LAST_ACK
      |  -------- ACK, ack=w+1 ------->   |
      |                                   |   Client: FIN_WAIT_2 -> TIME_WAIT
      |                                   |   Server: LAST_ACK -> CLOSED
      |                                   |
      |    [ 等待 2MSL ]                   |   Client: TIME_WAIT -> CLOSED
```

### 4.3 半关闭状态（Half-Close）

TCP 连接是全双工的，关闭是每个方向独立进行的：
- 主动关闭方发送 FIN 后，不再发送数据，但仍可接收数据（FIN_WAIT_2 状态）
- 被动关闭方可以继续发送数据，直到也发送 FIN
- 这就是中间存在 CLOSE_WAIT / FIN_WAIT_2 状态的原因

### 4.4 TIME_WAIT 状态

- **持续时间**：2MSL（Maximum Segment Lifetime，典型值 60s~120s，Linux 默认 60s）
- **目的**：
  1. 确保最后一个 ACK 能到达对端（若丢失，对端会重传 FIN）
  2. 让网络中该连接的所有报文段消亡，防止旧连接的延迟报文段干扰新连接
- **高并发问题**：大量短连接导致 TIME_WAIT 堆积，消耗端口资源
- **缓解措施**：tcp_tw_reuse、tcp_tw_recycle（Linux 内核参数）

### 4.5 CLOSE_WAIT 状态

- 被动关闭方收到 FIN 后进入 CLOSE_WAIT
- 如果大量连接停留在 CLOSE_WAIT，说明应用层未调用 close()
- **硬件/系统层面无法解决**，属于应用层 bug

### 4.6 连接状态机汇总

```
                              +---------+
                              |  CLOSED |
                              +---------+
                       主动打开 /    \ 被动打开
                        SYN /        \ listen
                              v          v
                        +---------+  +---------+
                        |SYN_SENT|  |  LISTEN |
                        +---------+  +---------+
                              |           |
                         收到SYN+ACK   收到SYN
                              v           v
                        +---------+  +---------+
                        |ESTAB-   |  |SYN_RCVD|
                        |LISHED   |<---------+
                        +---------+
                       /            \
                  主动关闭          被动关闭
                    FIN              收到FIN
                      v               v
                +-----------+   +-----------+
                |FIN_WAIT_1 |   |CLOSE_WAIT |
                +-----------+   +-----------+
                   |                |
              收到ACK           应用close()
                   v               v
                +-----------+   +-----------+
                |FIN_WAIT_2 |   | LAST_ACK  |
                +-----------+   +-----------+
                   |                |
              收到FIN          收到ACK
                   v               v
                +-----------+   +---------+
                |TIME_WAIT  |   | CLOSED  |
                +-----------+   +---------+
                   |
              2MSL超时
                   v
                +---------+
                | CLOSED  |
                +---------+
```

---

## 5. 可靠传输机制

### 5.1 序列号和确认号

- **序列号（SEQ）**：每个字节一个序列号，报文段的 SEQ = 该段第一个字节的序列号
- **确认号（ACK）**：期望收到的下一个字节的序列号（累计确认）
- **ISN（Initial Sequence Number）**：连接建立时随机生成，避免旧连接残留数据干扰
- 序列号空间：32 bit，会回绕（wrap-around），需配合 PAWS（Protection Against Wrapped Sequences）和 Timestamps Option 处理

**硬件设计要点**：
- 序列号比较必须处理 32 位回绕，使用 SEQ1 - SEQ2 的有符号差值判断先后
- 硬件中序列号运算使用模 2^32 算术

### 5.2 超时重传（RTO）

RTO（Retransmission Timeout）基于 RTT 测量值动态计算，定义于 RFC 6298：

```
SRTT    = (1 - alpha) * SRTT + alpha * RTT_sample      // 平滑 RTT，alpha = 1/8
RTTVAR  = (1 - beta) * RTTVAR + beta * |SRTT - RTT_sample|  // RTT 方差，beta = 1/4
RTO     = SRTT + max(G, 4 * RTTVAR)                    // G 为时钟粒度

约束：
  RTO 范围：[1s, 60s]（初始），运行时 [200ms, 60s]（各实现不同）
  首次无测量值时 RTO = 1s
  超时后 RTO 指数退避：RTO = RTO * 2
```

| 参数 | 含义 | 默认值 |
|------|------|--------|
| SRTT | 平滑往返时间 | 首次采样值 |
| RTTVAR | RTT 变化量 | 首次采样值 / 2 |
| alpha | SRTT 平滑因子 | 1/8 |
| beta | RTTVAR 平滑因子 | 1/4 |
| G | 时钟粒度 | 100ms（各系统不同） |

**硬件设计要点**：
- 硬件定时器管理每个连接的 RTO，定时器资源是 TOE 的核心瓶颈之一
- 超时重传次数有限制（tcp_retries1=3, tcp_retries2=15），超过则放弃连接

### 5.3 快速重传（Fast Retransmit）

当发送方收到 3 个重复 ACK（即同一 ACK 号连续确认 3 次），不等 RTO 超时，立即重传丢失的报文段：

```
发送方                                  接收方
  |                                       |
  | -- seg1(seq=1, 100 bytes) ---------> |  正常接收，返回 ack=101
  | -- seg2(seq=101, 100 bytes) -------> |  丢失！
  | -- seg3(seq=201, 100 bytes) -------> |  收到，期望101，返回 ack=101 (dup ACK #1)
  | -- seg4(seq=301, 100 bytes) -------> |  收到，期望101，返回 ack=101 (dup ACK #2)
  | -- seg5(seq=401, 100 bytes) -------> |  收到，期望101，返回 ack=101 (dup ACK #3)
  |                                       |
  | [收到3个dup ACK，触发快速重传]         |
  | -- seg2(seq=101, 100 bytes) -------> |  重传成功，返回 ack=501
```

### 5.4 SACK (Selective Acknowledgment)

RFC 2018 定义的选择性确认，接收端通过 SACK Option 告知发送端哪些数据块已收到，避免不必要的重传：

```
SACK Option 格式：
  Kind=5, Length, Left Edge 1, Right Edge 1, Left Edge 2, Right Edge 2, ...

示例：
  ACK=101, SACK={201-501}
  含义：已收到 201~500 字节，但 101~200 字节缺失
  发送方只需重传 seq=101 的报文段
```

- SACK 信息最多包含 4 个数据块（受限于 Option 最大长度 40 字节）
- 发送端需维护 SACK 记录表（SACK scoreboard），硬件中占用额外存储资源
- D-SACK（Duplicate SACK, RFC 2883）扩展：用于通知发送端收到了重复数据

---

## 6. 流量控制

### 6.1 滑动窗口

TCP 使用滑动窗口机制同时实现可靠传输和流量控制：

```
                   发送窗口（Send Window）
        +-----------------------------------------------+
        |  已发送已确认  | 已发送未确认 | 可发送 | 不可发送 |
        |  (已确认)      | (在途数据)   | (窗口内)| (窗口外) |
        +-----------------------------------------------+
                     ^              ^           ^
                   ack           snd_nxt    snd_una + window

  snd_una  = 最早未确认的序列号
  snd_nxt  = 下一个待发送的序列号
  Send Window = min(cwnd, rwnd)  // 取拥塞窗口和接收窗口的较小值
```

- **Send Window（发送窗口）** = min(cwnd, rwnd)，控制发送方可发送的数据量
- **Receive Window（接收窗口 / rwnd）**：接收端通告的窗口大小，反映接收缓冲区剩余空间
- **窗口更新**：接收端在每个 ACK 中携带当前 rwnd 值

### 6.2 窗口缩放（Window Scale Option）

RFC 1323 定义，解决 16 bit Window 字段最大仅 65535 字节的限制：

```
Window Scale Option：
  Kind=3, Length=3, shift_cnt (0~14)

实际窗口 = Window 字段值 * (2 ^ shift_cnt)

示例：Window=32768, shift_cnt=7
  实际窗口 = 32768 * 128 = 4,194,304 字节 (4 MB)
```

- 仅在 SYN 报文段中协商，连接建立后不可更改
- shift_cnt 范围 0~14，最大窗口 = 65535 * 2^14 = ~1 GB
- 硬件解码时必须记住每连接的 shift_cnt 值

**硬件设计要点**：
- 接收窗口计算需左移操作，硬件中用 barrel shifter 实现
- 窗口为 0 时发送方需启动零窗口探测定时器（Zero Window Probe）

---

## 7. 拥塞控制

拥塞控制防止发送方发送速率超过网络承载能力，核心变量：

| 变量 | 含义 |
|------|------|
| **cwnd** | 拥塞窗口（Congestion Window），以 MSS 为单位 |
| **ssthresh** | 慢启动阈值（Slow Start Threshold），决定慢启动和拥塞避免的切换点 |

### 7.1 慢启动（Slow Start）

```
初始：cwnd = 1 MSS（或 IW = 10，RFC 6928）
规则：每收到一个 ACK，cwnd += 1 MSS
效果：cwnd 每个 RTT 翻倍（指数增长）
终止：cwnd >= ssthresh 时切换到拥塞避免
      或检测到丢包时
```

### 7.2 拥塞避免（Congestion Avoidance）

```
规则：每收到一个 ACK，cwnd += MSS * MSS / cwnd
效果：cwnd 每个 RTT 增加约 1 MSS（线性增长）
终止：检测到丢包时
  - 超时丢包：ssthresh = cwnd/2, cwnd = 1 MSS, 回到慢启动
  - 3 dup ACK（快速重传）：进入快速恢复
```

### 7.3 快速恢复（Fast Recovery, RFC 5681）

```
触发：收到 3 个重复 ACK
处理：
  1. ssthresh = max(cwnd/2, 2*MSS)
  2. cwnd = ssthresh + 3 MSS
  3. 重传丢失的报文段
  4. 每收到一个重复 ACK，cwnd += 1 MSS
  5. 收到新 ACK 时：
     cwnd = ssthresh
     进入拥塞避免
```

### 7.4 状态转换图

```
          慢启动                    拥塞避免
        +-----------+             +-----------+
        |           |  cwnd >=    |           |
  ----->| cwnd 指数  |------------>| cwnd 线性  |
        | 增长      |  ssthresh   | 增长      |
        +-----------+             +-----------+
             |                         |
             | 超时                    | 3 dup ACK
             v                         v
        +-----------+  新ACK    +-----------+
        | 丢包处理   |<---------| 快速恢复    |
        | ssthresh=cwnd/2       | ssthresh=cwnd/2
        | cwnd=1 MSS |          | cwnd=ssthresh+3
        | -> 慢启动  |          | -> 拥塞避免 |
        +-----------+           +-----------+
```

### 7.5 现代拥塞控制算法

| 算法 | 特点 | 适用场景 |
|------|------|----------|
| **Reno** | 经典算法，上述标准实现 | 通用 |
| **CUBIC** | 以三次函数增长 cwnd，Linux 默认，对高 BDP 链路友好 | 高带宽长延迟链路 |
| **DCTCP** | 利用 ECN 标记精细调整 cwnd，减少缓冲区占用 | 数据中心内部 |
| **BBR** | 基于带宽和 RTT 建模，不依赖丢包信号，追求最优吞吐 | Google/B 站等互联网服务 |

**硬件设计要点**：
- CUBIC 涉及浮点/定点乘方运算，硬件实现需定点化处理
- BBR 需要带宽测量（最大交付速率）和 RTT 测量的硬件支持
- DCTCP 需要解析 ECN 标记并维护每连接的 ECN 比例统计
- 拥塞控制算法可配置化（per-connection），TOE 应支持算法切换

---

## 8. Nagle 算法与延迟 ACK

### 8.1 Nagle 算法（RFC 896）

- **目的**：减少网络中小报文段（tiny segments）的数量
- **规则**：当存在未被确认的已发送数据时，暂缓发送小报文段，直到：
  1. 收到所有已发数据的 ACK，或
  2. 积累到足够数据（>= MSS）
- **禁用方式**：设置 TCP_NODELAY socket 选项
- **问题**：与延迟 ACK 配合可能导致最多 40ms 的额外延迟

### 8.2 延迟 ACK（Delayed ACK, RFC 1122）

- **目的**：减少纯 ACK 报文段数量
- **规则**：收到数据后不立即发送 ACK，延迟最多 200ms（典型实现 40ms）
- **例外**：收到第 2 个报文段时立即发送 ACK；PSH 标志置位时立即 ACK
- **与 Nagle 冲突**：发送方等 ACK 才能继续发，接收方延迟发 ACK，导致延迟累积

**硬件设计要点**：
- TOE 的 ACK 生成逻辑需实现延迟 ACK 定时器（per-connection）
- TCP_NODELAY 选项影响发送策略，TOE 需维护 per-connection 配置

---

## 9. Keep-Alive 机制

- **目的**：检测对端是否存活，避免空闲连接长期占用资源
- **触发条件**：连接空闲超过指定时间（tcp_keepalive_time，默认 7200s = 2 小时）
- **探测方式**：
  1. 发送空数据段或 Keep-Alive 探测报文
  2. 每隔 tcp_keepalive_intvl（默认 75s）发送一次
  3. 连续 tcp_keepalive_probes（默认 9 次）无响应则关闭连接
- **非标准**：Keep-Alive 在 RFC 1122 中描述为可选实现，不保证所有中间设备（NAT/Firewall）支持

**硬件设计要点**：
- TOE 需为每个连接维护 Keep-Alive 定时器
- Keep-Alive 探测报文的序列号 = snd_una - 1（不消耗序列号空间）
- 硬件定时器资源规划需考虑 Keep-Alive 的并发需求

---

## 10. TCP 分段/校验和卸载

### 10.1 TCP Segmentation Offload (TSO)

- **原理**：NIC 硬件将超大 TCP 报文（通常 64KB）分段为多个 MSS 大小的报文段
- **收益**：
  - 减少 CPU 处理的报文数量（64KB / 1460B ≈ 45 个段合并为 1 次处理）
  - 减少 PCIe 带宽消耗（大块 DMA 优于多次小 DMA）
  - 降低协议栈处理开销

```
软件准备：一个大的 TCP 报文（64KB）
    +--------------------------------------------+
    | IP Header | TCP Header (20B) | Data (64KB) |
    +--------------------------------------------+

NIC 硬件自动完成：
    +------------------------+
    | IP Hdr | TCP Hdr | MSS |  -> seg 1 (seq=N)
    +------------------------+
    +------------------------+
    | IP Hdr | TCP Hdr | MSS |  -> seg 2 (seq=N+MSS)
    +------------------------+
    ... (共 ~45 个段)
    +------------------------+
    | IP Hdr | TCP Hdr | last | -> seg N (PUSH=1)
    +------------------------+

硬件需自动生成：
  - 各段的 IP Header（更新 Total Length, Identification, Checksum）
  - 各段的 TCP Header（更新 Sequence Number, FIN/PSH flags, Checksum）
```

- **GSO（Generic Segmentation Offload）**：软件版本的 TSO，在驱动层分段

### 10.2 TCP Checksum Offload (CSO)

- **TX 校验和卸载**：NIC 硬件计算 TCP 校验和，插入报文头部
  - 软件在报文中填入伪头部信息，NIC 完成校验和计算
  - 硬件需支持跨 DMA 缓冲区边界的增量校验和计算
- **RX 校验和卸载**：NIC 硬件验证 TCP 校验和，标记校验结果
  - 通过描述符状态位或 packet metadata 通知软件

### 10.3 其他硬件卸载特性

| 特性 | 说明 |
|------|------|
| **LRO（Large Receive Offload）** | 接收方向合并多个 TCP 报文段为一个大报文 |
| **GRO（Generic Receive Offload）** | 软件版本的 LRO |
| **RSC（Receive Side Coalescing）** | Windows 术语，等同于 LRO |
| **RSS（Receive Side Scaling）** | 根据 IP/端口哈希将不同连接分配到不同 CPU 核 |
| **VXLAN/Geneve Offload** | 隧道协议封装/解封装卸载 |
| **TLS/SSL Offload** | 加密/解密卸载（kTLS 硬件支持） |

---

## 11. TCP Offload Engine (TOE) 硬件设计要点

### 11.1 总体架构

```
+--------------------------------------------------+
|                    Host System                    |
|  +--------+    PCIe/AXI    +--------------------+ |
|  |  CPU   | <===========> |    NIC / TOE       | |
|  +--------+                |  +---------------+ | |
|                            |  | TX Data Path  | | |
|                            |  +---------------+ | |
|                            |  | RX Data Path  | | |
|                            |  +---------------+ | |
|                            |  | Connection DB | | |
|                            |  +---------------+ | |
|                            |  | Timer Engine  | | |
|                            |  +---------------+ | |
|                            |  | Checksum Eng  | | |
|                            |  +---------------+ | |
|                            |  | Congestion    | | |
|                            |  | Control       | | |
|                            |  +---------------+ | |
|                            |  | MAC/PHY       | | |
|                            |  +---------------+ | |
|                            +--------------------+ |
+--------------------------------------------------+
```

### 11.2 连接表管理（Connection Table）

- **存储内容**：每连接的 4 元组（src_ip, dst_ip, src_port, dst_port）、序列号（SND.UNA, SND.NXT, RCV.NXT）、窗口信息、状态机状态、定时器、拥塞控制变量
- **存储位置**：片上 SRAM（快速访问） + 片外 DRAM（大容量，配合缓存）
- **查找**：基于 4 元组哈希 + CAM/TCAM 精确匹配
- **容量**：典型 TOE 支持 4K~64K 并发连接（片上），百万级连接需配合片外存储
- **生命周期**：连接建立时分配，连接关闭后释放，需处理半关闭和 TIME_WAIT

**硬件设计要点**：
- 连接表是 TOE 最关键的资源，需平衡容量、功耗和访问延迟
- 多端口并行访问需仲裁逻辑或 bank 分割
- 连接表条目大小取决于存储的信息量，典型 64~256 字节/连接

### 11.3 序列号计算

- 所有序列号运算使用模 2^32 算术
- 关键比较操作：SEQ1 < SEQ2（处理回绕）使用 `SEQ1 - SEQ2 < 0`（有符号 32 位比较）
- TSO 模式下硬件需自动递增每段的 Sequence Number
- SACK Scoreboard 维护：记录已确认的数据块范围，判断是否需要重传

```verilog
// 序列号比较（处理 32 位回绕）
function seq_lt;
    input [31:0] a, b;
    begin
        seq_lt = ($signed(a - b) < 0);
    end
endfunction
```

### 11.4 校验和生成

- TCP 校验和 = 对 TCP 头部 + 数据 + 伪头部的 16 位反码求和
- 伪头部 = 源 IP + 目的 IP + 协议号(6) + TCP 长度
- TSO 场景：每段的伪头部相同（除 TCP 长度），可预计算伪头部校验和，增量更新每段
- 硬件实现：流水线化的 16 位加法器 + 反码进位回加

### 11.5 重传定时器

- **资源挑战**：per-connection 定时器在大连接数场景下是核心瓶颈
- **实现方案**：
  1. **有序链表**：按到期时间排序，每次检查最早到期的定时器
  2. **时间轮（Timing Wheel）**：分层时间轮，O(1) 插入删除
  3. **硬件定时器阵列**：专用 SRAM + 计数器，适合连接数有限的场景
- **定时器类型**：RTO 定时器、延迟 ACK 定时器、Keep-Alive 定时器、TIME_WAIT 定时器、零窗口探测定时器

### 11.6 窗口管理

- **发送窗口** = min(cwnd, rwnd)
- **拥塞窗口更新**：每个 ACK 到达时更新 cwnd（慢启动：cwnd += MSS；拥塞避免：cwnd += MSS*MSS/cwnd）
- **接收窗口更新**：应用层读取数据后更新 rwnd，通过 ACK 通告
- **零窗口处理**：发送方发送 Zero Window Probe，间隔指数退避（1s, 2s, 4s...）
- **窗口缩放**：32 位内部窗口 vs 16 位报文字段，需左移/右移操作

### 11.7 PCIe / AXI 接口

| 接口 | 用途 | 关键参数 |
|------|------|----------|
| **PCIe Gen4 x16** | Host 数据搬运（DMA） | 256 Gbps 带宽，描述符队列 |
| **AXI4-Stream** | 内部数据通路 | 报文级流控，TKEEP 支持变长数据 |
| **AXI4-Lite** | 寄存器配置 | 连接建立/拆除命令，状态查询 |
| **AXI4** | 连接表等大数据量存储访问 | 突发传输，DDR/HBM 接口 |

**DMA 设计要点**：
- TX 方向：Host 通过描述符队列提交发送请求，TOE DMA 读取数据
- RX 方向：TOE 将重组后的数据通过 DMA 写入 Host 内存
- 描述符格式需包含：地址、长度、连接 ID、操作类型、完成标志
- MSI-X 中断通知 Host 完成事件

---

## 12. TCP 与 UDP 对比

| 特性 | TCP | UDP |
|------|-----|-----|
| 连接 | 面向连接（三次握手） | 无连接 |
| 可靠性 | 可靠（确认、重传、排序） | 不可靠（尽力而为） |
| 有序性 | 保证有序 | 不保证 |
| 数据边界 | 字节流（无边界） | 数据报（保留边界） |
| 流量控制 | 滑动窗口 | 无 |
| 拥塞控制 | 有（慢启动、拥塞避免等） | 无 |
| 头部开销 | 最小 20 字节 | 8 字节 |
| 速度 | 较慢（握手、确认、流控） | 较快（无额外开销） |
| 典型应用 | HTTP/HTTPS、FTP、SSH、数据库 | DNS、视频流、VoIP、游戏 |
| 硬件卸载复杂度 | 高（连接管理、重传、流控） | 低（仅校验和） |
| 校验和 | 强制（覆盖伪头部+数据+头部） | 可选（仅覆盖 UDP 头+数据） |

---

## 13. 与 QUIC 的关系

QUIC（Quick UDP Internet Connections）是由 Google 提出、IETF 标准化（RFC 9000）的传输层协议，运行于 UDP 之上：

| 维度 | TCP | QUIC |
|------|-----|------|
| **传输层** | TCP（IP 层协议号 6） | UDP（IP 层协议号 17） |
| **连接建立** | TCP 握手 + TLS 握手 = 1~3 RTT | 0-RTT 或 1-RTT（合并加密握手） |
| **队头阻塞** | TCP 层队头阻塞（单字节流） | 无（多独立 stream） |
| **连接迁移** | 基于 4 元组，IP 变化断连 | 基于 Connection ID，IP 变化不断连 |
| **加密** | 可选（TLS 在应用层） | 强制（TLS 1.3 集成在传输层） |
| **头部** | 明文，中间设备可解析 | 加密，中间设备不可解析 |
| **拥塞控制** | 内核实现（CUBIC 等） | 用户空间实现，可灵活切换 |
| **硬件卸载** | 成熟（TSO/CSO/TOE） | 尚不成熟，卸载难度更大 |

**对 IC 设计的影响**：
- QUIC 将传输层逻辑从内核移到用户空间，传统 TCP 硬件卸载的价值可能被重新评估
- QUIC 的 Connection ID 机制对 NIC 的 RSS（Receive Side Scaling）分发策略提出新要求
- 未来 NIC 可能需要同时支持 TCP 和 QUIC 的硬件加速
- QUIC 的加密集成意味着 TLS 卸载将变得更加重要

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| RFC 793 | Transmission Control Protocol | TCP 核心规范 |
| RFC 1122 | Requirements for Internet Hosts | 主机实现要求 |
| RFC 1323 | TCP Extensions for High Performance | Window Scale, Timestamps, PAWS |
| RFC 2018 | TCP Selective Acknowledgment Options | SACK |
| RFC 2883 | An Extension to SACK: D-SACK | 重复 SACK |
| RFC 3168 | The Addition of ECN to IP | ECN 拥塞通知 |
| RFC 5681 | TCP Congestion Control | 标准拥塞控制算法 |
| RFC 6298 | Computing TCP's Retransmission Timer | RTO 计算 |
| RFC 6928 | Increasing TCP's Initial Window | IW=10 |
| RFC 7414 | A Roadmap for TCP Specification Documents | TCP 规范文档索引 |
| RFC 9000 | QUIC: A UDP-Based Multiplexed and Secure Transport | QUIC 核心规范 |
