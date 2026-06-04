# 国密/国际双模加密引擎 需求汇总表

> 版本：v1.0
> 日期：2026-06-04
> 模块名称：crypto_engine
> 文档编号：FNW-REQ-crypto_engine-v1.0

---

## 1. 文档信息

| 字段 | 内容 |
|------|------|
| 模块名称 | 国密/国际双模加密引擎 (crypto_engine) |
| SoC 位置 | 安全子系统 |
| 版本 | v1.0 |
| 日期 | 2026-06-04 |
| 作者 | chip-requirement-arch Agent |

---

## 2. 模块概述

### 2.1 模块定位

国密/国际双模加密引擎是安全子系统的核心密码处理单元，负责：
- 国密算法：SM2（非对称加解密/签名）、SM3（哈希）、SM4（对称加密）
- 国际算法：AES（对称加密）、SHA（哈希）、RSA（非对称）
- 高级抗侧信道攻击防护（DPA/SPA抵抗）
- 商密认证合规（GM/T 0028/0039）

### 2.2 关键特性

| 特性 | 说明 |
|------|------|
| 双模并行 | 国密与国际算法可同时运行，互不阻塞 |
| 高级抗侧信道 | DPA/SPA抵抗，过商密认证 |
| 多通道并行 | 4通道并行加密 |
| AXI 128bit | 大数据块搬运，DMA驱动 |

---

## 3. 需求汇总表

### 3.1 基础需求（REQ-001~REQ-028）

| 编号 | 约束项 | 确认值 | 优先级 | 来源 | 状态 |
|------|--------|--------|--------|------|------|
| REQ-001 | 工艺与频率 | 28nm / 400MHz | Must | 用户输入 | 已确认 |
| REQ-002 | 接口协议 | AXI4 128bit，上游CPU/DMA，下游密钥存储/安全隔离区 | Must | 用户输入 | 已确认 |
| REQ-003 | 数据流特征 | 大数据块搬运，突发传输，DMA驱动 | Should | 用户输入 | 已确认 |
| REQ-004 | 延迟与吞吐 | 安全性优先，性能次之；单次加密延迟待综合评估 | Should | 推断值 | 待确认 |
| REQ-005 | 面积与功耗 | 安全性优先，面积功耗次之；双引擎面积较大可接受 | Should | 推断值 | 待确认 |
| REQ-006 | 时钟与复位 | 单时钟域400MHz，异步复位同步释放，低有效rst_n | Must | 标准方案 | 已确认 |
| REQ-007 | 低功耗 | 使用全局Clock Gating方案，无独立功耗域需求 | Could | 默认值 | 待确认 |
| REQ-008 | DFT | 标准DFT：扫描链、ICG、Boundary Scan | Should | 标准方案 | 已确认 |
| REQ-009 | 可靠性 | 密钥存储ECC保护，寄存器Parity | Should | 安全需求 | 已确认 |
| REQ-010 | 其他约束 | 商密认证（GM/T 0028/0039），高级抗侧信道（DPA/SPA抵抗） | Must | 用户输入 | 已确认 |
| REQ-011 | CDC策略 | 单时钟域，无CDC需求 | N/A | 不适用 | 跳过 |
| REQ-012 | 存储器选型 | 密钥缓存SRAM，中间结果寄存器阵列，S盒ROM | Should | 功能推断 | 已确认 |
| REQ-013 | PVT操作条件 | 28nm TT/0.9V/25°C标准条件 | Should | 默认值 | 待确认 |
| REQ-014 | 接口时序约束 | AXI4标准时序，输入setup≤0.5ns，输出delay≤1ns | Should | 标准方案 | 已确认 |
| REQ-015 | DMA握手接口 | 需要DMA引擎，突发长度16，地址递增模式 | Should | 用户输入 | 已确认 |
| REQ-016 | 中断接口 | 加密完成中断，错误中断，2级优先级，W1C清除 | Should | 默认值 | 待确认 |
| REQ-017 | 调试接口 | 标准JTAG调试接口，性能计数器 | Could | 默认值 | 待确认 |
| REQ-018 | 安全隔离 | TrustZone安全隔离，地址保护，密钥访问控制 | Should | 安全需求 | 已确认 |
| REQ-019 | 软件接口约束 | 寄存器访问模式，中断驱动，APB配置接口 | Should | 标准方案 | 已确认 |
| REQ-020 | 系统级约束 | 安全子系统地址空间，QoS普通级，非Cacheable | Should | 推断值 | 待确认 |
| REQ-021 | 功耗状态机 | Active/Sleep两态，唤醒延迟≤10cycles | Could | 默认值 | 待确认 |
| REQ-022 | PLL/Jitter | 不适用，使用系统时钟 | N/A | 不适用 | 跳过 |
| REQ-023 | SerDes/PHY | 不适用，内部模块 | N/A | 不适用 | 跳过 |
| REQ-024 | 形式验证 | 关键安全路径形式验证 | Should | 默认值 | 待确认 |
| REQ-025 | 验证方法学 | UVM验证，覆盖率目标95%，每日回归 | Should | 默认值 | 待确认 |
| REQ-026 | 封装约束 | 不适用，内部模块 | N/A | 不适用 | 跳过 |
| REQ-027 | EMC/ESD合规 | 不适用，内部模块 | N/A | 不适用 | 跳过 |
| REQ-028 | 时钟树约束 | 标准时钟树，SS覆盖，OCV余量5% | Should | 标准方案 | 已确认 |

### 3.2 扩展需求（REQ-029~REQ-040）

| 编号 | 约束项 | 确认值 | 优先级 | 来源 | 状态 |
|------|--------|--------|--------|------|------|
| REQ-029 | SM2签名验签并行 | 支持签名验签并行处理 | Must | 头脑风暴 | 已确认 |
| REQ-030 | SM3/SHA哈希流水线 | 4级流水线 | Should | 头脑风暴 | 已确认 |
| REQ-031 | AES-GCM模式 | 支持AES-128/192/256-GCM | Must | 头脑风暴 | 已确认 |
| REQ-032 | 密钥派生函数 | 支持KDF（GM/T 0010） | Must | 头脑风暴 | 已确认 |
| REQ-033 | TRNG接口 | 硬件真随机数生成器接口 | Must | 头脑风暴 | 已确认 |
| REQ-034 | 多通道并行 | 4通道并行加密 | Should | 头脑风暴 | 已确认 |
| REQ-035 | 流水线可配置 | 2/4/8级可配置 | Could | 头脑风暴 | 已确认 |
| REQ-036 | DMA背压感知 | AXI流控感知 | Must | 头脑风暴 | 已确认 |
| REQ-037 | SM4/AES动态切换 | 运行时算法切换 | Should | 头脑风暴 | 已确认 |
| REQ-038 | 错误注入接口 | 故障攻击防护验证接口 | Should | 头脑风暴 | 已确认 |
| REQ-039 | 加密性能计数器 | 加密次数/延迟统计 | Could | 头脑风暴 | 已确认 |
| REQ-040 | 密钥使用统计 | 密钥调用次数/错误率 | Should | 头脑风暴 | 已确认 |

---

## 4. 硬约束表

| 约束项 | 约束值 | 来源 | 验证方式 |
|--------|--------|------|----------|
| 工艺节点 | 28nm | 用户输入 | 综合约束 |
| 工作频率 | 400MHz | 用户输入 | STA验证 |
| AXI位宽 | 128bit | 用户输入 | 接口验证 |
| 抗侧信道 | 高级防护（DPA/SPA抵抗） | 用户输入 | 安全认证 |
| 商密认证 | GM/T 0028/0039 | 用户输入 | 认证测试 |
| 处理模式 | 双模并行 | 用户输入 | 功能验证 |

---

## 5. 优先级统计

| 优先级 | 数量 | 占比 | 说明 |
|--------|------|------|------|
| Must | 9 | 22.5% | 方案必须满足 |
| Should | 20 | 50.0% | 方案应尽量满足 |
| Could | 6 | 15.0% | 方案可选优化 |
| N/A | 5 | 12.5% | 不适用 |
| **合计** | **40** | **100%** | - |

---

## 6. 矛盾检测总结

### 6.1 检测结果

| 类别 | 数量 | 说明 |
|------|------|------|
| 无矛盾 | 15 | 检测通过 |
| 不适用 | 2 | 单时钟域，CDC相关规则跳过 |
| 关注项 | 5 | 需方案阶段细化 |

### 6.2 关注项

| 关注项 | 涉及REQ | 说明 | 建议 |
|--------|---------|------|------|
| 面积 vs 功能复杂度 | REQ-002, REQ-005 | 双引擎+抗侧信道功能复杂 | 方案阶段细化面积预估 |
| 面积 vs 并行度 | REQ-003, REQ-005 | 4通道并行需4套引擎 | 考虑资源共享方案 |
| 多模块共享资源 | REQ-002, REQ-003, REQ-012 | 4通道共享AXI需仲裁 | 设计仲裁策略 |
| 存储容量 vs 面积 | REQ-005, REQ-012 | 密钥缓存+S盒+中间结果 | 优化存储结构 |
| 功能复杂度 vs 验证 | REQ-003, REQ-004, REQ-006 | 40个功能点验证工作量大 | 制定验证计划 |

---

## 7. 需求追溯矩阵（RTM）

| 需求ID | 优先级 | 需求描述 | FS章节 | 接口/信号 | PPA指标 | 验证策略 | 状态 |
|--------|--------|----------|--------|-----------|---------|----------|------|
| REQ-001 | Must | 28nm / 400MHz | §13 | - | Fmax≥400MHz | STA | Allocated |
| REQ-002 | Must | AXI4 128bit接口 | §4 | axi_*/apb_* | - | 接口验证 | Allocated |
| REQ-003 | Should | 大数据块搬运，突发传输 | §5.1 | - | 吞吐量 | 性能验证 | Allocated |
| REQ-004 | Should | 安全性优先，延迟可接受 | §8.1 | - | 延迟 | 功能验证 | Allocated |
| REQ-005 | Should | 面积功耗次之 | §8.3 | - | 面积 | 综合验证 | Allocated |
| REQ-006 | Must | 单时钟域400MHz | §7 | clk/rst_n | - | 时钟验证 | Allocated |
| REQ-007 | Could | 全局Clock Gating | §10.2 | - | 功耗 | 功耗验证 | Allocated |
| REQ-008 | Should | 标准DFT | §9 | scan_en | - | DFT验证 | Allocated |
| REQ-009 | Should | 密钥存储ECC | §10.1 | - | 面积开销 | 可靠性验证 | Allocated |
| REQ-010 | Must | 商密认证，高级抗侧信道 | §1 | - | - | 安全认证 | Allocated |
| REQ-011 | N/A | 单时钟域，无CDC | - | - | - | - | 跳过 |
| REQ-012 | Should | 密钥缓存SRAM，S盒ROM | §11 | - | 面积 | 存储验证 | Allocated |
| REQ-013 | Should | 28nm TT/0.9V/25°C | §13 | - | - | PVT验证 | Allocated |
| REQ-014 | Should | AXI4标准时序 | §4 | - | 时序 | 接口验证 | Allocated |
| REQ-015 | Should | DMA引擎，突发16 | §4 | dma_* | - | DMA验证 | Allocated |
| REQ-016 | Should | 加密完成/错误中断 | §4 | irq_* | - | 中断验证 | Allocated |
| REQ-017 | Could | JTAG调试接口 | §9 | jtag_* | - | 调试验证 | Allocated |
| REQ-018 | Should | TrustZone安全隔离 | §10.1 | - | - | 安全验证 | Allocated |
| REQ-019 | Should | APB配置接口 | §4 | apb_* | - | 寄存器验证 | Allocated |
| REQ-020 | Should | 安全子系统地址空间 | §4 | - | - | 地址验证 | Allocated |
| REQ-021 | Could | Active/Sleep两态 | §10.2 | - | 唤醒延迟 | 功耗验证 | Allocated |
| REQ-022 | N/A | 使用系统时钟 | - | - | - | - | 跳过 |
| REQ-023 | N/A | 内部模块 | - | - | - | - | 跳过 |
| REQ-024 | Should | 关键安全路径形式验证 | §9 | - | - | 形式验证 | Allocated |
| REQ-025 | Should | UVM验证，95%覆盖率 | §9 | - | - | 覆盖率验证 | Allocated |
| REQ-026 | N/A | 内部模块 | - | - | - | - | 跳过 |
| REQ-027 | N/A | 内部模块 | - | - | - | - | 跳过 |
| REQ-028 | Should | 标准时钟树 | §7 | - | - | 时钟验证 | Allocated |
| REQ-029 | Must | SM2签名验签并行 | §5.1 | - | 并行度 | SM2验证 | Allocated |
| REQ-030 | Should | SM3/SHA 4级流水线 | §5.1 | - | 吞吐量 | 哈希验证 | Allocated |
| REQ-031 | Must | AES-128/192/256-GCM | §5.1 | - | - | AES验证 | Allocated |
| REQ-032 | Must | KDF（GM/T 0010） | §5.1 | - | - | KDF验证 | Allocated |
| REQ-033 | Must | TRNG接口 | §4 | trng_* | - | 随机数验证 | Allocated |
| REQ-034 | Should | 4通道并行加密 | §5.1 | - | 并行度 | 并行验证 | Allocated |
| REQ-035 | Could | 2/4/8级流水线可配置 | §5.4 | - | 灵活性 | 配置验证 | Allocated |
| REQ-036 | Must | AXI流控感知 | §4 | axi_ready | - | 流控验证 | Allocated |
| REQ-037 | Should | SM4/AES运行时切换 | §5.1 | - | - | 切换验证 | Allocated |
| REQ-038 | Should | 错误注入接口 | §9 | err_inject | - | 故障验证 | Allocated |
| REQ-039 | Could | 加密性能计数器 | §9 | perf_cnt | - | 性能验证 | Allocated |
| REQ-040 | Should | 密钥使用统计 | §9 | key_stat | - | 审计验证 | Allocated |

---

## 8. 追溯覆盖率

| 统计项 | 数值 |
|--------|------|
| REQ 总数 | 40 |
| 已覆盖 | 35 (87.5%) |
| 未覆盖 | 5 (12.5%) |
| 未覆盖项 | REQ-011, REQ-022, REQ-023, REQ-026, REQ-027 (N/A) |

---

## 9. 附录

### 9.1 参考文档

| 编号 | 文档名 | 说明 |
|------|--------|------|
| REF-001 | crypto_engine_pr_v1.0.md | PR沟通记录 |
| REF-002 | GM/T 0028-2014 | 密码模块安全技术要求 |
| REF-003 | GM/T 0039-2015 | 密码模块安全检测要求 |

### 9.2 缩略语

| 缩写 | 全称 |
|------|------|
| SM2 | 国密椭圆曲线公钥密码算法 |
| SM3 | 国密杂凑算法 |
| SM4 | 国密分组密码算法 |
| AES | Advanced Encryption Standard |
| SHA | Secure Hash Algorithm |
| RSA | Rivest-Shamir-Adleman |
| KDF | Key Derivation Function |
| TRNG | True Random Number Generator |
| GCM | Galois/Counter Mode |
| DPA | Differential Power Analysis |
| SPA | Simple Power Analysis |
| ECC | Error Correcting Code |
| AXI | Advanced eXtensible Interface |
| APB | Advanced Peripheral Bus |
