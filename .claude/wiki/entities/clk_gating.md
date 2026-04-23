# clk_gating — 集成时钟门控单元

> 标准 ICG（Integrated Clock Gating）单元包装，Latch-based 实现无毛刺门控时钟

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/clk_gating.md |

## 核心特性
- 低电平锁存器锁存使能信号，消除毛刺
- scan_en 强制开时钟，保证 DFT 扫描链正常
- 替代 `assign gated = clk & en` 的不安全写法
- 支持多级门控和片选式门控

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| ICG_CELL | "CKLNQD1" | - | 标准单元库 ICG cell 名称 |
| TECH_NODE | "GENERIC" | GENERIC/TSMC7/SAMSUNG5 | 工艺节点 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk_in | I | 1 | 输入时钟 |
| en | I | 1 | 时钟使能（高有效） |
| scan_en | I | 1 | DFT 扫描使能 |
| clk_out | O | 1 | 门控后时钟输出 |

## 典型应用场景
- 模块级时钟门控（UART、SPI 等）
- 多级时钟门控（系统→子系统→模块）
- 片选式时钟门控（8 通道独立门控）
- 低功耗状态机配合

## 与其他实体的关系
- `reset_sync` 管理复位同步，本模块管理时钟门控
- `clk_div` 分频后的时钟可通过本模块门控

## 设计注意事项
- 禁止 `assign gated = clk & en`，必须通过标准 ICG cell
- 门控粒度建议至少模块级，过细增加时钟树复杂度
- 面积：1 个 ICG cell ≈ 6-8 GE
- 综合约束：`set_clock_gating_style`

## 参考
- 原始文档：`.claude/knowledge/cbb/clk_gating.md`
