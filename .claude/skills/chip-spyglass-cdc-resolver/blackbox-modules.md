# Blackbox Modules — CDC 自动 Waive 模块列表

> 本文件由 `chip-spyglass-cdc-resolver` 使用。列表中的模块在 CDC 检查中自动 waive 所有违例。
> 用户可按需编辑本文件，添加或移除模块。

---

## 使用说明

- 每行一个模块名，格式：`- <module_name> — <reason>`
- 模块名必须与 RTL 中的模块名完全匹配
- 支持路径匹配：如果违例文件路径包含模块名，也算匹配
- 空行和 `#` 开头的行会被忽略

---

## 模块列表

### PLL / 时钟生成

- `pll_top` — 第三方 PLL IP，CDC 由 IP 内部处理
- `clk_gen` — 时钟生成模块，已验证

### 第三方 IP

<!-- 按需添加项目中使用的第三方 IP -->

### 已验证模块

<!-- 添加已 tape-out 或已通过 CDC 验证的模块 -->

### 模拟封装

<!-- 添加模拟模块的数字封装 -->

---

## 添加新模块

在对应分类下添加一行：

```
- <module_name> — <waive reason>
```

示例：
```
- ddr_ctrl — Synopsys DDR 控制器 IP，CDC 由 IP 内部处理
- pcie_phy — PCIe PHY 硬宏，模拟域隔离
```

---

## 注意事项

1. **Blackbox 模块的 CDC 安全由 IP 提供方保证**，团队不负责其内部 CDC
2. 如果 IP 的端口存在 CDC 问题（如端口信号未同步），仍需在顶层处理
3. 建议定期审查 blackbox 列表，确保 IP 版本更新后仍然有效
4. **P0 违例（Ac_unsync01/02）即使在 blackbox 模块中也应重点关注**——如果 IP 端口到用户逻辑的路径无同步器，问题在集成层面
