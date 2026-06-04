# 混合控制器 需求汇总表

> 版本：v1.0
> 日期：2026-06-03
> 状态：已冻结
> 来源：stageB phase1（28 项）+ stageB phase2（3 项追加）

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| 模块名称 | hybrid_controller（混合控制器） |
| 文档编号 | FNW-REQ-hybrid_controller-v1.0 |
| 作者 | 苏启辰/Sean |
| 日期 | 2026-06-03 |
| 状态 | **已冻结** |

---

## 2. 修订历史

| 版本 | 日期 | 作者 | 变更描述 |
|------|------|------|----------|
| v1.0 | 2026-06-03 | Sean | 初始版本，31 项 REQ 冻结 |

---

## 3. 需求汇总表

### 3.1 核心约束（REQ-001 ~ REQ-028）

| REQ | 约束项 | 确认值 | 优先级 | 状态 | 来源 |
|-----|--------|--------|--------|------|------|
| REQ-001 | 工艺与频率 | 28nm / 200MHz | Must | 冻结 | stageB phase1 |
| REQ-002 | 接口协议 | 上游：APB32 + AXI4(64bit) + SPI；下游：AXI4(64bit) + 自定义流式 DMA | Must | 冻结 | stageB phase1 |
| REQ-003 | 数据流特征 | AXI 突发 16beat/32B；SPI 单拍 1~4B；APB 单拍 4B | Should | 冻结 | stageB phase1 |
| REQ-004 | 延迟与吞吐 | AXI→AXI4：≤4cycles；SPI→DMA：≤6cycles；APB→AXI4：≤3cycles | Must | 冻结 | stageB phase1 |
| REQ-005 | 面积与功耗 | 面积 ≤50kGates；SRAM ≤2KB（硬约束）；功耗 ≤15mW | Must | 冻结 | stageB phase1 |
| REQ-006 | 时钟与复位 | 单时钟域 200MHz；异步复位同步释放 rst_n | Must | 冻结 | stageB phase1 |
| REQ-007 | 低功耗 | 无独立功耗域，使用全局 Clock Gating | Could | 冻结 | stageB phase1 |
| REQ-008 | DFT | 标准扫描链 + ICG，无特殊要求 | Should | 冻结 | stageB phase1 |
| REQ-009 | 可靠性 | 无 ECC/TMR，SRAM 使用 Parity | Should | 冻结 | stageB phase1 |
| REQ-010 | 其他约束 | 无安全/合规/特殊工艺限制 | N/A | 冻结 | stageB phase1 |
| REQ-011 | CDC 策略 | 单时钟域，无 CDC | N/A | 冻结 | stageB phase1 |
| REQ-012 | 存储器选型 | SRAM 1920B（详见 breakdown）+ 寄存器阵列 ~128B | Must | 冻结 | stageB phase1 |
| REQ-013 | PVT 操作条件 | TT / 0.9V / 25°C（商业级） | Should | 冻结 | stageB phase1 |
| REQ-014 | 接口时序约束 | AXI：setup ≤0.5ns, delay ≤1ns；APB：setup ≤1ns, delay ≤2ns | Should | 冻结 | stageB phase1 |
| REQ-015 | DMA 握手接口 | 自定义流式 DMA，Valid-Ready 握手，burst 长度可配 | Should | 冻结 | stageB phase1 |
| REQ-016 | 中断接口 | 1 路中断输出，W1C 清除，支持错误/完成事件 | Should | 冻结 | stageB phase1 |
| REQ-017 | 调试接口 | 无特殊调试接口 | Could | 冻结 | stageB phase1 |
| REQ-018 | 安全隔离 | 无 TrustZone/防火墙需求 | N/A | 冻结 | stageB phase1 |
| REQ-019 | 软件接口约束 | APB 寄存器访问，中断+轮询混合模式 | Should | 冻结 | stageB phase1 |
| REQ-020 | 系统级约束 | 固定地址映射，无 QoS，无 Cache | Must | 冻结 | stageB phase1 |
| REQ-021 | 功耗状态机 | 无独立功耗域，不适用 | N/A | 冻结 | stageB phase1 |
| REQ-022 | PLL/Jitter | 不适用，外部时钟输入 | N/A | 冻结 | stageB phase1 |
| REQ-023 | SerDes/PHY | 不适用 | N/A | 冻结 | stageB phase1 |
| REQ-024 | 形式验证 | 不适用 | N/A | 冻结 | stageB phase1 |
| REQ-025 | 验证方法学 | 功能仿真为主 | Could | 冻结 | stageB phase1 |
| REQ-026 | 封装约束 | 不适用（IP 级模块） | N/A | 冻结 | stageB phase1 |
| REQ-027 | EMC/ESD 合规 | 不适用 | N/A | 冻结 | stageB phase1 |
| REQ-028 | 时钟树约束 | 不适用（单时钟域） | N/A | 冻结 | stageB phase1 |

### 3.2 头脑风暴追加 REQ（REQ-029 ~ REQ-031）

| REQ | 约束项 | 确认值 | 优先级 | 状态 | 来源 |
|-----|--------|--------|--------|------|------|
| REQ-029 | AXI 写突发合并 | 支持将多个小 burst 合并为单个大 burst 写入下游 AXI4 | Should | 冻结 | stageB phase2 |
| REQ-030 | 错误注入接口 | APB 可配置的地址解码错误注入寄存器 | Could | 冻结 | stageB phase2 |
| REQ-031 | 事务计数器 | APB 可读的各接口事务计数 + 错误计数寄存器 | Should | 冻结 | stageB phase2 |

---

## 4. SRAM 容量 Breakdown（≤2KB 硬约束）

> **用户铁律：SRAM 必须 ≤ 2KB（2048 Bytes）**

| Buffer 名称 | 容量 | 用途 | 压缩策略 |
|-------------|------|------|----------|
| AXI 写缓冲 | 512B | AXI 写数据暂存，支持 16beat × 32B burst | 原 1KB，压缩 50% |
| SPI 接收缓冲 | 128B | SPI 接收数据暂存 | 原 256B，压缩 50% |
| 共享读缓冲 | 1024B | AXI4/DMA 读返回数据暂存，三路共享 | 共享 buffer 替代独立 buffer |
| 地址映射表 | 256B | 地址解码查找表（可选，也可用组合逻辑） | 若面积紧张可改为组合逻辑 |
| **合计** | **1920B** | | **< 2048B（满足）** |

### SRAM 压缩方案

| 方案 | 描述 | 面积节省 | 性能影响 |
|------|------|----------|----------|
| FIFO 深度压缩 | AXI 写 buffer 从 32beat 降到 16beat | -512B | 背压频率略增 |
| SPI buffer 缩小 | SPI 接收 buffer 从 256B 降到 128B | -128B | SPI 速率低，无影响 |
| 共享读 buffer | 三路读返回共享 1024B，用 tag 区分来源 | -768B（vs 独立） | 需仲裁，增加 1cycle |
| 地址表可选 | 地址映射表可用组合逻辑替代 | -256B（可选） | 组合逻辑面积换 SRAM |

---

## 5. 优先级分布

| 优先级 | 数量 | REQ 列表 |
|--------|------|----------|
| Must | 7 | REQ-001, REQ-002, REQ-004, REQ-005, REQ-006, REQ-012, REQ-020 |
| Should | 9 | REQ-003, REQ-008, REQ-009, REQ-013, REQ-014, REQ-015, REQ-016, REQ-019, REQ-029, REQ-031 |
| Could | 4 | REQ-007, REQ-017, REQ-025, REQ-030 |
| N/A | 10 | REQ-010, REQ-011, REQ-018, REQ-021~024, REQ-026~028 |
| **总计** | **31** | |

---

## 6. 冻结声明

本需求汇总表已于 2026-06-03 冻结。所有 REQ 项不可单方面变更，变更需走 change_handling 流程（受 change_cooldown 约束：同一 REQ 变更 ≥3 次强制暂停）。
