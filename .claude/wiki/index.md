# LLM Wiki 索引

> **用途**：芯片架构设计知识库的结构化索引
> **维护者**：LLM Agent（每次 ingest 后更新）
> **总计**：130 个实体页面（53 CBB + 16 总线协议 + 14 网络协议 + 7 IO 协议 + 10 芯片设计 + 8 CPU + 8 IP + 6 MMU + 8 验证）

---

## 一、实体页面（Entities）

### 1.1 CBB 模块（53 个）

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

#### 基础时序与逻辑（12 个）

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

### 1.4 IO/存储协议（7 个）

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

### 1.5 芯片设计（10 个）

#### 设计流程与方法（4 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 设计流程 | [entities/design_flow.md](entities/design_flow.md) | 芯片设计全流程概述 | chip-design/design_flow.md |
| 前端设计 | [entities/frontend_design.md](entities/frontend_design.md) | RTL 设计与验证流程 | chip-design/frontend_design.md |
| 物理设计 | [entities/physical_design.md](entities/physical_design.md) | 后端布局布线流程 | chip-design/physical_design.md |
| 签核验证 | [entities/signoff.md](entities/signoff.md) | 签核检查与交付标准 | chip-design/signoff.md |

#### DFT 可测试性（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| DFT 基础 | [entities/dft_basics.md](entities/dft_basics.md) | 扫描链、BIST、ATPG 基础 | chip-design/dft_basics.md |
| DFT 高级 | [entities/dft_advanced.md](entities/dft_advanced.md) | 高级 DFT 技术与策略 | chip-design/dft_advanced.md |

#### 低功耗设计（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 低功耗基础 | [entities/low_power_basics.md](entities/low_power_basics.md) | 时钟门控、电源门控基础 | chip-design/low_power_basics.md |
| 低功耗高级 | [entities/low_power_advanced.md](entities/low_power_advanced.md) | DVFS、多电压域高级技术 | chip-design/low_power_advanced.md |

#### 时序分析（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| STA 基础 | [entities/sta_basics.md](entities/sta_basics.md) | 静态时序分析基础概念 | chip-design/sta_basics.md |
| STA 高级 | [entities/sta_advanced.md](entities/sta_advanced.md) | 高级时序约束与优化 | chip-design/sta_advanced.md |

---

### 1.6 CPU 与处理器（8 个）

#### 指令集架构（3 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| ARM | [entities/arm.md](entities/arm.md) | ARMv8/v9 架构与生态系统 | cpu/arm.md |
| RISC-V | [entities/riscv.md](entities/riscv.md) | RISC-V 指令集与扩展 | cpu/riscv.md |
| MIPS | [entities/mips.md](entities/mips.md) | MIPS 架构与历史 | cpu/mips.md |

#### 微架构组件（3 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 流水线 | [entities/pipeline.md](entities/pipeline.md) | 处理器流水线设计 | cpu/pipeline.md |
| 缓存 | [entities/cache.md](entities/cache.md) | 缓存层次结构与策略 | cpu/cache.md |
| 分支预测 | [entities/branch_predictor.md](entities/branch_predictor.md) | 分支预测器设计 | cpu/branch_predictor.md |

#### 系统特性（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 中断 | [entities/interrupt.md](entities/interrupt.md) | 中断机制与控制器 | cpu/interrupt.md |
| 多核 | [entities/multicore.md](entities/multicore.md) | 多核架构与一致性 | cpu/multicore.md |

---

### 1.7 IP 核（8 个）

#### 处理器 IP（2 个）

| IP | 页面 | 摘要 | 来源 |
|------|------|------|------|
| ARM Core | [entities/arm_core.md](entities/arm_core.md) | ARM Cortex-A/R/M 核心选型 | IP/arm_core.md |
| RISC-V Core | [entities/riscv_core.md](entities/riscv_core.md) | RISC-V 开源/商业核心选型 | IP/riscv_core.md |

#### 高速接口 IP（4 个）

| IP | 页面 | 摘要 | 来源 |
|------|------|------|------|
| PCIe IP | [entities/pcie_ip.md](entities/pcie_ip.md) | PCIe 控制器 IP 选型 | IP/pcie_ip.md |
| DDR IP | [entities/ddr_ip.md](entities/ddr_ip.md) | DDR 控制器 IP 选型 | IP/ddr_ip.md |
| Ethernet IP | [entities/ethernet_ip.md](entities/ethernet_ip.md) | 以太网 MAC/PHY IP 选型 | IP/ethernet_ip.md |
| USB IP | [entities/usb_ip.md](entities/usb_ip.md) | USB 控制器 IP 选型 | IP/usb_ip.md |

#### 低速外设 IP（1 个）

| IP | 页面 | 摘要 | 来源 |
|------|------|------|------|
| SPI/I2C/UART IP | [entities/spi_i2c_uart_ip.md](entities/spi_i2c_uart_ip.md) | 低速外设接口 IP 选型 | IP/spi_i2c_uart_ip.md |

#### 时钟 IP（1 个）

| IP | 页面 | 摘要 | 来源 |
|------|------|------|------|
| PLL/DLL | [entities/pll_dll.md](entities/pll_dll.md) | PLL/DLL 时钟生成 IP 选型 | IP/pll_dll.md |

---

### 1.8 MMU 内存管理（6 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 地址空间 | [entities/address_space.md](entities/address_space.md) | 虚拟/物理地址空间管理 | mmu/address_space.md |
| 页表 | [entities/page_table.md](entities/page_table.md) | 多级页表结构设计 | mmu/page_table.md |
| TLB | [entities/tlb.md](entities/tlb.md) | TLB 架构与地址转换加速 | mmu/tlb.md |
| 内存属性 | [entities/memory_attributes.md](entities/memory_attributes.md) | 缓存策略与共享性控制 | mmu/memory_attributes.md |
| 内存保护 | [entities/memory_protection.md](entities/memory_protection.md) | PMP/MPU/IOMMU 保护机制 | mmu/memory_protection.md |
| 虚拟化 | [entities/virtualization.md](entities/virtualization.md) | 两阶段地址转换与虚拟机 | mmu/virtualization.md |

---

### 1.9 验证方法（8 个）

#### 仿真（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 仿真基础 | [entities/simulation_basics.md](entities/simulation_basics.md) | 仿真流程与调试技术 | verification/simulation_basics.md |
| 仿真高级 | [entities/simulation_advanced.md](entities/simulation_advanced.md) | 性能优化与硬件加速 | verification/simulation_advanced.md |

#### 形式验证（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 形式验证基础 | [entities/formal_basics.md](entities/formal_basics.md) | 等价性检查与属性检查 | verification/formal_basics.md |
| 形式验证高级 | [entities/formal_advanced.md](entities/formal_advanced.md) | 模型检查与收敛策略 | verification/formal_advanced.md |

#### UVM 验证方法学（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| UVM 基础 | [entities/uvm_basics.md](entities/uvm_basics.md) | UVM 框架与组件 | verification/uvm_basics.md |
| UVM 高级 | [entities/uvm_advanced.md](entities/uvm_advanced.md) | 寄存器模型与高级序列 | verification/uvm_advanced.md |

#### 覆盖率与验证管理（2 个）

| 概念 | 页面 | 摘要 | 来源 |
|------|------|------|------|
| 覆盖率分析 | [entities/coverage_analysis.md](entities/coverage_analysis.md) | 代码/功能/断言覆盖率 | verification/coverage_analysis.md |
| 验证概述 | [entities/verification_overview.md](entities/verification_overview.md) | 验证流程与方法概述 | verification/verification_overview.md |

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
