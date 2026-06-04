# 复杂模块测试池（40k+ RTL）

> 面向 4 万行以上 RTL 的复杂芯片模块，测试 chip-requirement-arch Agent 在极端复杂场景下的执行质量。

---

## 概述

本测试池包含 **50 个复杂芯片模块**，覆盖 10 个技术领域，用于全面测试需求探索 Agent 的执行质量。每个模块预估 RTL 行数 ≥ 40,000 行，确保触发 E 阶段递归分解流程。

---

## 快速开始

### 随机选择 1 个模块

```bash
/test-chip-requirement-arch complex_random
```

或使用选择器脚本：

```bash
bash .claude/debug/chip-requirement-arch/scenarios/complex_modules/select_module.sh single
```

### 批量测试（5 个模块，维度覆盖优化）

```bash
bash .claude/debug/chip-requirement-arch/scenarios/complex_modules/select_module.sh batch 5
```

### 角色均衡测试

```bash
bash .claude/debug/chip-requirement-arch/scenarios/complex_modules/select_module.sh balanced
```

### 全量测试（50 个模块）

```bash
bash .claude/debug/chip-requirement-arch/scenarios/complex_modules/select_module.sh full
```

---

## 模块总览

| # | ID | 模块 | 领域 | RTL 行数 | 角色 | 复杂度标签 |
|---|-----|------|------|----------|------|-----------|
| 1 | CM-01 | PCIe Gen5 Root Complex | interconnect | 65,000 | E | multi_channel, high_speed |
| 2 | CM-02 | CXL 3.0 内存控制器 | interconnect | 55,000 | C | cache_coherency, memory_pooling |
| 3 | CM-03 | UCIe Die-to-Die PHY | interconnect | 42,000 | E | high_speed_serdes |
| 4 | CM-04 | CHI 一致性互联 | interconnect | 70,000 | C | cache_coherency, mesh_topology |
| 5 | CM-05 | HBM3 内存控制器 | interconnect | 48,000 | E | multi_channel, ECC |
| 6 | CM-06 | NoC 路由器 | interconnect | 40,000 | E | virtual_channel, adaptive_routing |
| 7 | CM-07 | NVMe 2.0 SSD 控制器 | storage | 58,000 | E | multi_queue, NAND_management |
| 8 | CM-08 | DDR5 内存控制器 | storage | 45,000 | E | multi_channel, ECC |
| 9 | CM-09 | RAID 加速引擎 | storage | 42,000 | C | XOR_engine, PQ_codec |
| 10 | CM-10 | ZNS 存储引擎 | storage | 40,000 | E | zone_management, GC |
| 11 | CM-11 | 100G 以太网 MAC | network | 45,000 | E | RS-FEC, PFC |
| 12 | CM-12 | 交换矩阵芯片 | network | 72,000 | C | non_blocking_switch, ACL |
| 13 | CM-13 | DPU SmartNIC 控制器 | network | 60,000 | C | OVS_offload, RDMA |
| 14 | CM-14 | P4 可编程报文解析器 | network | 40,000 | E | programmable_parser |
| 15 | CM-15 | NPU 卷积加速引擎 | compute | 55,000 | E | systolic_array, Winograd |
| 16 | CM-16 | GPU Shader Core | compute | 75,000 | C | SIMD, texture, tensor_core |
| 17 | CM-17 | RISC-V 向量处理器 | compute | 48,000 | E | RVV_extension, chaining |
| 18 | CM-18 | RISC-V 乱序执行核心 | compute | 80,000 | C | out_of_order, ROB, LSQ |
| 19 | CM-19 | DSP 信号处理核心 | compute | 42,000 | E | VLIW, MAC |
| 20 | CM-20 | 国密/国际双模加密引擎 | security | 45,000 | E | dual_crypto, side_channel |
| 21 | CM-21 | 安全飞地处理器 | security | 50,000 | C | TEE, secure_boot |
| 22 | CM-22 | 8K 视频编解码器 | multimedia | 65,000 | E | H265_H266, 8K |
| 23 | CM-23 | 图像信号处理流水线 | multimedia | 50,000 | E | ISP, HDR, 3A |
| 24 | CM-24 | 显示控制器 | multimedia | 42,000 | E | multi_layer, HDR, VRR |
| 25 | CM-25 | ADAS 传感器融合处理器 | automotive | 55,000 | C | sensor_fusion, ASIL_D |
| 26 | CM-26 | CAN-FD 网关控制器 | automotive | 40,000 | E | multi_channel, autosar |
| 27 | CM-27 | 末级缓存控制器 | memory | 50,000 | C | MOESI, partitioning |
| 28 | CM-28 | CXL 内存交换芯片 | memory | 52,000 | C | multi_host, QoS |
| 29 | CM-29 | 可重构数据流加速器 | reconfig | 48,000 | C | CGRA, runtime_reconfig |
| 30 | CM-30 | FPGA 部分重配置控制器 | reconfig | 40,000 | E | partial_reconfig |
| 31 | CM-31 | USB4 Hub 控制器 | io | 42,000 | E | USB4, TBT3, tunneling |
| 32 | CM-32 | MIPI CSI-2 接收控制器 | io | 40,000 | E | MIPI_CSI2, D_PHY |
| 33 | CM-33 | PCIe 交换芯片 | interconnect | 68,000 | C | multi_root, SR_IOV |
| 34 | CM-34 | AI 推理 SoC 互联 | compute | 60,000 | C | AllReduce, model_parallel |
| 35 | CM-35 | 张量计算核心 | compute | 45,000 | E | matrix_multiply, mixed_precision |
| 36 | CM-36 | 数据压缩/解压引擎 | storage | 40,000 | E | multi_algorithm, line_rate |
| 37 | CM-37 | NVMe-oF 控制器 | storage | 48,000 | E | NVMe_oF, RDMA_transport |
| 38 | CM-38 | 多声道音频 DSP | multimedia | 40,000 | E | multi_channel, low_latency |
| 39 | CM-39 | 10G 以太网 PHY | network | 42,000 | E | PCS_PMA, EEE |
| 40 | CM-40 | NAND Flash 控制器 | storage | 40,000 | E | ONFI, LDPC_ECC |
| 41 | CM-41 | USB 3.2 Device 控制器 | io | 40,000 | E | USB32, multi_endpoint |
| 42 | CM-42 | HDMI 2.1 收发器 | io | 42,000 | E | HDMI21, FRL, VRR |
| 43 | CM-43 | TSN 以太网交换 | automotive | 45,000 | E | TSN, deterministic_latency |
| 44 | CM-44 | DDR5 PHY | memory | 42,000 | E | DDR5_PHY, DFI, training |
| 45 | CM-45 | PCIe Gen5 PHY | interconnect | 45,000 | E | SerDes, PIPE_60 |
| 46 | CM-46 | 稀疏计算加速器 | compute | 42,000 | C | sparse_matrix, CSR_CSC |
| 47 | CM-47 | GICv4 高级中断控制器 | soc_infra | 40,000 | E | GICv4, LPI_ITS |
| 48 | CM-48 | PCIe/CXL 混合交换芯片 | interconnect | 72,000 | C | dual_protocol, CXL_cache_mem |
| 49 | CM-49 | RDMA 网卡控制器 | network | 55,000 | C | RDMA, RoCE_v2, zero_copy |
| 50 | CM-50 | Transformer 推理加速器 | compute | 62,000 | C | attention, KV_cache, MoE |

---

## 覆盖矩阵

### 评估维度覆盖

| 维度 | 覆盖模块数 | 覆盖率 |
|------|-----------|--------|
| D1 需求采集完整性 | 50/50 | 100% |
| D2 需求一致性 | 20/50 | 40% |
| D3 需求文档质量 | 50/50 | 100% |
| D4 方案细化质量 | 50/50 | 100% |
| D5 子模块分解质量 | 48/50 | 96% |
| D6 顶层集成质量 | 14/50 | 28% |
| D7 ADR 文档质量 | 18/50 | 36% |
| D8 方案验证与评审 | 15/50 | 30% |
| D9 追溯完整性 | 50/50 | 100% |
| D10 过程规范性 | 50/50 | 100% |

> **说明**：D2/D6/D7/D8 仅在特定复杂场景下触发，覆盖率反映的是"需要测试该维度的模块占比"，非缺陷。

### 用户角色覆盖

| 角色 | 模块数 | 占比 |
|------|--------|------|
| E (clear_expert) | 32 | 64% |
| C (challenging_reviewer) | 18 | 36% |
| V (vague_beginner) | 0 | 通过随机替换补充 |

### 技术领域覆盖

| 领域 | 模块数 |
|------|--------|
| interconnect | 9 |
| compute | 9 |
| storage | 7 |
| network | 7 |
| multimedia | 4 |
| io | 4 |
| automotive | 3 |
| memory | 3 |
| security | 2 |
| reconfig | 2 |
| soc_infra | 1 |

---

## 文件结构

```
complex_modules/
├── README.md              # 本文件
├── module_pool.json       # 50 个模块定义（主配置）
├── coverage_matrix.json   # 覆盖矩阵
└── select_module.sh       # 随机选择脚本
```

---

## 自定义模块

在 `module_pool.json` 的 `modules` 数组中添加新条目：

```json
{
  "id": "CM-51",
  "name": "my_module",
  "display_name": "我的模块",
  "domain": "custom",
  "rtl_estimate": 45000,
  "user_persona": "E",
  "context": {
    "soc_position": "...",
    "upstream": "...",
    "downstream": "...",
    "protocol": "...",
    "priority": "..."
  },
  "initial_input": "帮我做 XXX 的需求采集",
  "test_focus": ["D1", "D4", "D5"],
  "complexity_tags": ["tag1", "tag2"],
  "expected_req_count": 35,
  "timeout_minutes": 50,
  "max_dialog_rounds": 80
}
```

---

## 与现有场景的关系

| 场景类型 | 模块复杂度 | RTL 行数 | 用途 |
|----------|-----------|----------|------|
| basic_dma | 低 | ~5,000 | 基础流程验证 |
| complex_pcie | 中 | ~15,000 | 高级场景验证 |
| vague_input | 低 | ~5,000 | 边界/模糊输入 |
| edge_cases | 中 | ~15,000 | 异常处理 |
| **complex_modules** | **高** | **≥40,000** | **极端复杂度验证** |

---

## 评估标准

复用 `.claude/evaluation_criteria/chip-requirement-arch-eva.md`，额外关注：

| 检查项 | 说明 |
|--------|------|
| E 阶段递归分解 | 40k+ 行模块必须触发，叶子节点 <3000 行 |
| 子模块数量 | 预期 10~30 个子模块 |
| stageD Q&A 数量 | ≥64 个（20 个子阶段 min_qa_pairs 总和） |
| 门控 G-08 | 每个叶子目录 ≥5 文件 |
| 目录结构 | 孙模块在子模块目录下 |
