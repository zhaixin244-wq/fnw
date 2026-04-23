# LLM Wiki 日志

> **格式**：`## [YYYY-MM-DD] action | 描述`
> **维护者**：LLM Agent（append-only）

---

## [2026-04-23] init | Wiki 系统初始化

- 创建 wiki 目录结构：entities/ concepts/ comparisons/ guides/
- 创建 schema.md：定义三层架构和工作流
- 创建 index.md：从现有 knowledge/ 生成初始索引（52 CBB + 16 总线协议 + 14 网络协议 + 8 IO 协议）
- 创建 log.md：本文件
- 原始文档保留在 `.claude/knowledge/` 不变

---

## [2026-04-23] ingest | 补全 41 个缺失的 entity 页面

- 检查发现 knowledge/ 中有 41 个源文件未生成对应 wiki entity 页面
- 分 3 批次完成全部 entity 页面创建：
  - 批次 1：chip-design（10 个）+ IO-protocol（1 个）= 11 个
  - 批次 2：cpu（8 个）+ IP（8 个）= 16 个
  - 批次 3：mmu（6 个）+ verification（8 个）= 14 个
- 更新 index.md：实体总数从 90 → 131，新增 5 个域分类（1.5 芯片设计/1.6 CPU/1.7 IP/1.8 MMU/1.9 验证）
- 新增 entity 列表：
  - chip-design: design_flow, frontend_design, physical_design, signoff, dft_basics, dft_advanced, low_power_basics, low_power_advanced, sta_basics, sta_advanced
  - cpu: arm, riscv, mips, pipeline, cache, branch_predictor, interrupt, multicore
  - IP: arm_core, riscv_core, pcie_ip, ddr_ip, ethernet_ip, usb_ip, spi_i2c_uart_ip, pll_dll
  - mmu: address_space, page_table, tlb, memory_attributes, memory_protection, virtualization
  - verification: simulation_basics, simulation_advanced, formal_basics, formal_advanced, uvm_basics, uvm_advanced, coverage_analysis, verification_overview
