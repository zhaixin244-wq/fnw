# LLM Wiki 索引

> **用途**：芯片架构设计知识库的结构化索引
> **维护者**：LLM Agent（每次 ingest 后更新）
> **总计**：52 个 CBB 模块 + 16 个总线协议 + 14 个网络协议 + 8 个 IO 协议

---

## 一、实体页面（Entities）

### 1.1 CBB 模块（52 个）

#### 调度与仲裁（6 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| priority_encoder | [entities/priority_encoder.md](entities/priority_encoder.md) | 优先级编码器，LOW/HIGH 优先级，lock/release | cbb/priority_encoder.md |
| arbiter | [entities/arbiter.md](entities/arbiter.md) | 固定优先级仲裁器，参数化请求者数量 | cbb/arbiter.md |
| wrr | [entities/wrr.md](entities/wrr.md) | 加权轮询调度，静态/动态权重 | cbb/wrr.md |
| dwrr | [entities/dwrr.md](entities/dwrr.md) | 缺损加权轮询，credit-based 变长包调度 | cbb/dwrr.md |
| robin_bucket | [entities/robin_bucket.md](entities/robin_bucket.md) | 轮询桶调度，令牌桶+轮询 | cbb/robin_bucket.md |
| bigrr | [entities/bigrr.md](entities/bigrr.md) | 大位宽轮询仲裁，64-4096 请求者 | cbb/bigrr.md |

#### 流量整形（1 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| shaper | [entities/shaper.md](entities/shaper.md) | 令牌桶整形器，CIR/CBS 配置 | cbb/shaper.md |

#### 总线与互联（5 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| crossbar | [entities/crossbar.md](entities/crossbar.md) | N×M 非阻塞交叉开关 | cbb/crossbar.md |
| address_decoder | [entities/address_decoder.md](entities/address_decoder.md) | 地址译码器，range/base 模式 | cbb/address_decoder.md |
| bridge_axi_to_apb | [entities/bridge_axi_to_apb.md](entities/bridge_axi_to_apb.md) | AXI-to-APB 协议转换桥 | cbb/bridge_axi_to_apb.md |
| axi4_lite_reg_file | [entities/axi4_lite_reg_file.md](entities/axi4_lite_reg_file.md) | AXI4-Lite 寄存器文件 | cbb/axi4_lite_reg_file.md |
| axi4_stream_mux | [entities/axi4_stream_mux.md](entities/axi4_stream_mux.md) | AXI-Stream 多路复用器 | cbb/axi4_stream_mux.md |

#### 存储器（6 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| ram_sp | [entities/ram_sp.md](entities/ram_sp.md) | 单端口 RAM，同步读写 | cbb/ram_sp.md |
| ram_dp | [entities/ram_dp.md](entities/ram_dp.md) | 双端口 RAM，独立读写端口 | cbb/ram_dp.md |
| ram_tp | [entities/ram_tp.md](entities/ram_tp.md) | 真双端口 RAM，两端口均可读写 | cbb/ram_tp.md |
| ram_ro | [entities/ram_ro.md](entities/ram_ro.md) | ROM，文件初始化 | cbb/ram_ro.md |
| sync_fifo | [entities/sync_fifo.md](entities/sync_fifo.md) | 同步 FIFO，单时钟域 | cbb/sync_fifo.md |
| async_fifo | [entities/async_fifo.md](entities/async_fifo.md) | 异步 FIFO，Gray 码指针跨域 | cbb/async_fifo.md |

#### 编码与计算（7 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| bin2onehot | [entities/bin2onehot.md](entities/bin2onehot.md) | 二进制转独热码 | cbb/bin2onehot.md |
| onehot2bin | [entities/onehot2bin.md](entities/onehot2bin.md) | 独热码转二进制 | cbb/onehot2bin.md |
| findfirstone | [entities/findfirstone.md](entities/findfirstone.md) | 查找最低有效位 | cbb/findfirstone.md |
| findlastone | [entities/findlastone.md](entities/findlastone.md) | 查找最高有效位 | cbb/findlastone.md |
| popcount | [entities/popcount.md](entities/popcount.md) | 人口计数器，树形加法 | cbb/popcount.md |
| barrel_shifter | [entities/barrel_shifter.md](entities/barrel_shifter.md) | 桶形移位器，SLL/SRL/SRA/ROR | cbb/barrel_shifter.md |
| bit_reverse | [entities/bit_reverse.md](entities/bit_reverse.md) | 位反转，CRC/SPI/FFT 位反射 | cbb/bit_reverse.md |

#### CRC 与 ECC（2 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| crc_gen | [entities/crc_gen.md](entities/crc_gen.md) | CRC 生成器，CRC-8/16/32 | cbb/crc_gen.md |
| ecc_encoder | [entities/ecc_encoder.md](entities/ecc_encoder.md) | ECC 编码器，SECDED Hamming 码 | cbb/ecc_encoder.md |

#### 外设接口（4 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| spi_master | [entities/spi_master.md](entities/spi_master.md) | SPI 主机，4 种模式 | cbb/spi_master.md |
| i2c_master | [entities/i2c_master.md](entities/i2c_master.md) | I2C 主机，7/10 位寻址 | cbb/i2c_master.md |
| uart_core | [entities/uart_core.md](entities/uart_core.md) | UART 核心，可配置波特率 | cbb/uart_core.md |
| pwm_gen | [entities/pwm_gen.md](entities/pwm_gen.md) | PWM 生成器，多通道 | cbb/pwm_gen.md |

#### 跨时钟域 CDC（4 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| cdc_sync | [entities/cdc_sync.md](entities/cdc_sync.md) | CDC 双触发器同步 | cbb/cdc_sync.md |
| cdc_handshake_bus | [entities/cdc_handshake_bus.md](entities/cdc_handshake_bus.md) | CDC 握手总线，多 bit 跨域 | cbb/cdc_handshake_bus.md |
| cdc_pulse_stretch | [entities/cdc_pulse_stretch.md](entities/cdc_pulse_stretch.md) | CDC 脉冲展宽 | cbb/cdc_pulse_stretch.md |
| gray_converter | [entities/gray_converter.md](entities/gray_converter.md) | Gray 码转换器 | cbb/gray_converter.md |

#### 链表与资源管理（6 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| linked_list_free | [entities/linked_list_free.md](entities/linked_list_free.md) | 空闲链表，O(1) 分配回收 | cbb/linked_list_free.md |
| linked_list_queue | [entities/linked_list_queue.md](entities/linked_list_queue.md) | 链表队列，优先级排序 | cbb/linked_list_queue.md |
| linked_list_circular | [entities/linked_list_circular.md](entities/linked_list_circular.md) | 循环链表，轮询遍历 | cbb/linked_list_circular.md |
| linked_list_hash | [entities/linked_list_hash.md](entities/linked_list_hash.md) | 哈希链表，关联存储 | cbb/linked_list_hash.md |
| ptr_alloc | [entities/ptr_alloc.md](entities/ptr_alloc.md) | 指针分配器，bitmap 方式 | cbb/ptr_alloc.md |
| wide_entry_wr | [entities/wide_entry_wr.md](entities/wide_entry_wr.md) | 宽表项写入器，原子提交 | cbb/wide_entry_wr.md |

#### 基础时序与逻辑（11 个）

| 模块 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| edge_detect | [entities/edge_detect.md](entities/edge_detect.md) | 边沿检测器，RISING/FALLING/BOTH | cbb/edge_detect.md |
| pulse_extend | [entities/pulse_extend.md](entities/pulse_extend.md) | 脉冲展宽器 | cbb/pulse_extend.md |
| reset_sync | [entities/reset_sync.md](entities/reset_sync.md) | 复位同步器，异步复位同步释放 | cbb/reset_sync.md |
| pipeline_reg | [entities/pipeline_reg.md](entities/pipeline_reg.md) | 流水线寄存器，stall/flush | cbb/pipeline_reg.md |
| counter | [entities/counter.md](entities/counter.md) | 可配置计数器 | cbb/counter.md |
| clk_div | [entities/clk_div.md](entities/clk_div.md) | 时钟分频器 | cbb/clk_div.md |
| clk_gating | [entities/clk_gating.md](entities/clk_gating.md) | 时钟门控 ICG | cbb/clk_gating.md |
| lfsr | [entities/lfsr.md](entities/lfsr.md) | 线性反馈移位寄存器 | cbb/lfsr.md |
| mux_onehot | [entities/mux_onehot.md](entities/mux_onehot.md) | 独热码多路选择器 | cbb/mux_onehot.md |
| valid_ready_delay | [entities/valid_ready_delay.md](entities/valid_ready_delay.md) | Valid/Ready 延迟仿真模型 | cbb/valid_ready_delay.md |
| watchdog | [entities/watchdog.md](entities/watchdog.md) | 看门狗定时器 | cbb/watchdog.md |
| intc | [entities/intc.md](entities/intc.md) | 中断控制器 | cbb/intc.md |

---

### 1.2 总线协议（16 个）

#### AMBA 总线族（5 个）

| 协议 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| AXI4 | [entities/axi4.md](entities/axi4.md) | 高性能系统总线，128-bit@250MHz | bus-protocol/axi4.md |
| AXI4-Lite | [entities/axi4_lite.md](entities/axi4_lite.md) | 低速寄存器访问总线 | bus-protocol/axi4_lite.md |
| AXI4-Stream | [entities/axi4_stream.md](entities/axi4_stream.md) | 流式数据传输 | bus-protocol/axi4_stream.md |
| AHB | [entities/ahb.md](entities/ahb.md) | 高性能系统总线（AXI 前代） | bus-protocol/ahb.md |
| APB | [entities/apb.md](entities/apb.md) | 外设低功耗总线 | bus-protocol/apb.md |

#### 串行外设接口（4 个）

| 协议 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| SPI | [entities/spi.md](entities/spi.md) | 同步全双工主从，1-100+ MHz | bus-protocol/spi.md |
| I2C | [entities/i2c.md](entities/i2c.md) | 同步半双工多主多从 | bus-protocol/i2c.md |
| UART | [entities/uart.md](entities/uart.md) | 异步全双工点对点 | bus-protocol/uart.md |
| CAN | [entities/can.md](entities/can.md) | 多主仲裁，汽车/工业 | bus-protocol/can.md |

#### 高速串行接口（3 个）

| 协议 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| PCIe | [entities/pcie.md](entities/pcie.md) | Gen5: 32GT/s, Gen6: 64GT/s | bus-protocol/pcie.md |
| USB | [entities/usb.md](entities/usb.md) | HS: 480Mbps, SS: 20Gbps | bus-protocol/usb.md |
| MIPI | [entities/mipi.md](entities/mipi.md) | D-PHY: 2.5Gbps/lane | bus-protocol/mipi.md |

#### 其他（4 个）

| 协议 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| JTAG | [entities/jtag.md](entities/jtag.md) | 调试/边界扫描，5 线 | bus-protocol/jtag.md |
| DDR | [entities/ddr.md](entities/ddr.md) | DDR4: 3200MT/s, DDR5: 5600MT/s | bus-protocol/ddr.md |
| Wishbone | [entities/wishbone.md](entities/wishbone.md) | 开源免版税总线 | bus-protocol/wishbone.md |
| TileLink | [entities/tilelink.md](entities/tilelink.md) | RISC-V 生态缓存一致性 | bus-protocol/tilelink.md |

---

### 1.3 网络协议（14 个）

| 协议 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| Ethernet | [entities/ethernet.md](entities/ethernet.md) | 以太网 L2 帧/MAC/PHY | net-protocol/ethernet.md |
| VLAN/QoS | [entities/vlan_qos.md](entities/vlan_qos.md) | VLAN 标签、QoS 优先级 | net-protocol/vlan_qos.md |
| IP | [entities/ip.md](entities/ip.md) | IPv4/IPv6 路由 | net-protocol/ip.md |
| TCP | [entities/tcp.md](entities/tcp.md) | 可靠传输、拥塞控制 | net-protocol/tcp.md |
| UDP | [entities/udp.md](entities/udp.md) | 无连接传输 | net-protocol/udp.md |
| ARP/ICMP | [entities/arp_icmp.md](entities/arp_icmp.md) | 地址解析/差错报告 | net-protocol/arp_icmp.md |
| RDMA | [entities/rdma.md](entities/rdma.md) | 远程直接内存访问 | net-protocol/rdma.md |
| RoCE v2 | [entities/roce_v2.md](entities/roce_v2.md) | RDMA over Converged Ethernet | net-protocol/roce_v2.md |
| InfiniBand | [entities/infiniband.md](entities/infiniband.md) | 高性能计算互联 | net-protocol/infiniband.md |
| UEC | [entities/uec.md](entities/uec.md) | Ultra Ethernet Consortium | net-protocol/uec.md |
| VXLAN/Geneve | [entities/vxlan_geneve.md](entities/vxlan_geneve.md) | 网络虚拟化隧道 | net-protocol/vxlan_geneve.md |
| MPLS | [entities/mpls.md](entities/mpls.md) | 多协议标签交换 | net-protocol/mpls.md |
| ECMP/LAG | [entities/ecmp_lag.md](entities/ecmp_lag.md) | 等价多路径/链路聚合 | net-protocol/ecmp_lag.md |
| NAT/DHCP/DNS | [entities/nat_dhcp_dns.md](entities/nat_dhcp_dns.md) | 网络地址转换/动态主机配置 | net-protocol/nat_dhcp_dns.md |

---

### 1.4 IO/存储协议（8 个）

| 协议 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| PCIe TLP | [entities/pcie_tlp.md](entities/pcie_tlp.md) | PCIe 事务层包格式 | IO-protocol/pcie_tlp.md |
| NVMe | [entities/nvme.md](entities/nvme.md) | NVMe 命令/队列体系 | IO-protocol/nvme.md |
| NVMe-oF | [entities/nvme_of.md](entities/nvme_of.md) | NVMe over Fabrics | IO-protocol/nvme_of.md |
| CHI | [entities/chi.md](entities/chi.md) | AMBA CHI 缓存一致性 | IO-protocol/chi.md |
| VirtIO | [entities/virtio.md](entities/virtio.md) | 虚拟化 IO 标准 | IO-protocol/virtio.md |
| SR-IOV | [entities/sr_iov.md](entities/sr_iov.md) | 单根 IO 虚拟化 | IO-protocol/sr_iov.md |
| MIPS-IO | [entities/mips_io.md](entities/mips_io.md) | MIPS IO 系统 | IO-protocol/mips-io.md |

---

## 二、概念页面（Concepts）

| 概念 | 页面 | 摘要 |
|------|------|------|
| 握手协议 | [concepts/handshake-protocol.md](concepts/handshake-protocol.md) | Valid-Ready 握手机制设计模式 |
| CDC 策略 | [concepts/cdc-strategy.md](concepts/cdc-strategy.md) | 跨时钟域设计策略总结 |
| 流控机制 | [concepts/flow-control.md](concepts/flow-control.md) | Credit/背压/令牌桶流控对比 |
| 仲裁策略 | [concepts/arbitration-strategy.md](concepts/arbitration-strategy.md) | Fixed/RR/WRR/DWRR 仲裁对比 |
| 存储器选型 | [concepts/memory-selection.md](concepts/memory-selection.md) | SRAM/RegFile/FIFO 选型指南 |
| 流水线设计 | [concepts/pipeline-design.md](concepts/pipeline-design.md) | 流水线 stall/flush/冒险处理 |

---

## 三、对比页面（Comparisons）

| 对比 | 页面 | 摘要 |
|------|------|------|
| 总线协议选型 | [comparisons/bus-protocol-selection.md](comparisons/bus-protocol-selection.md) | AXI/AHB/APB/Stream 选型对比 |
| 串行接口选型 | [comparisons/serial-interface-selection.md](comparisons/serial-interface-selection.md) | SPI/I2C/UART/CAN 选型对比 |
| 高速接口选型 | [comparisons/high-speed-interface-selection.md](comparisons/high-speed-interface-selection.md) | PCIe/USB/MIPI 选型对比 |
| 仲裁器选型 | [comparisons/arbiter-selection.md](comparisons/arbiter-selection.md) | 6 种仲裁 CBB 选型对比 |
| FIFO 选型 | [comparisons/fifo-selection.md](comparisons/fifo-selection.md) | sync_fifo/async_fifo 选型 |
| 资源管理选型 | [comparisons/resource-mgmt-selection.md](comparisons/resource-mgmt-selection.md) | ptr_alloc vs linked_list 选型 |
| CDC 方案选型 | [comparisons/cdc-selection.md](comparisons/cdc-selection.md) | 4 种 CDC CBB 选型对比 |

---

## 四、指南页面（Guides）

| 指南 | 页面 | 摘要 |
|------|------|------|
| AXI4 集成指南 | [guides/axi4-integration-guide.md](guides/axi4-integration-guide.md) | AXI4 主从集成最佳实践 |
| CDC 设计指南 | [guides/cdc-design-guide.md](guides/cdc-design-guide.md) | 跨时钟域设计完整流程 |
| FIFO 深度计算 | [guides/fifo-depth-calculation.md](guides/fifo-depth-calculation.md) | FIFO 深度计算方法与公式 |
| 仲裁器集成指南 | [guides/arbiter-integration-guide.md](guides/arbiter-integration-guide.md) | 仲裁器选型与集成流程 |
