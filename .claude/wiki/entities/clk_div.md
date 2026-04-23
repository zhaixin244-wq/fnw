# clk_div — 时钟分频器

> 将输入时钟按可配置分频比产生低频时钟，支持整数/奇偶分频和 50% 占空比

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/clk_div.md |

## 核心特性
- 支持 FIXED 固定分频和 DYNAMIC 动态分频
- 偶数分频：计数到 DIV/2-1 翻转
- 奇数分频：上升沿+下降沿计数器交错实现 50% 占空比
- CLOCK 输出类型（时钟）和 ENABLE 输出类型（使能脉冲）
- 支持相位偏移（PHASE）

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| DIV_WIDTH | 8 | - | 分频比位宽 |
| DIV_VALUE | 2 | - | 固定分频比 |
| MODE | "FIXED" | FIXED/DYNAMIC | 分频模式 |
| DUTY_50 | 1 | 0/1 | 占空比 50% 使能 |
| OUT_TYPE | "CLOCK" | CLOCK/ENABLE | 输出类型 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| en | I | 1 | 分频使能 |
| div_value | I | DIV_WIDTH | 动态分频比 |
| clk_out | O | 1 | 分频时钟输出（CLOCK） |
| clk_out_en | O | 1 | 使能脉冲输出（ENABLE） |
| locked | O | 1 | 输出稳定标志 |

## 典型应用场景
- 外设时钟分频（100MHz → 25MHz，DIV=4）
- 动态分频自适应频率
- SPI 时钟生成（ENABLE 模式）

## 与其他实体的关系
- `clk_gating` 用于门控分频后的时钟
- `counter` 为通用计数器，本模块专注时钟分频

## 设计注意事项
- CLOCK 输出不能直接 assign 给组合逻辑（毛刺），需通过 ICG 门控
- 动态切换时 div_value 更新立即生效
- 面积：DIV_WIDTH 个触发器 + 比较器，极小开销

## 参考
- 原始文档：`.claude/knowledge/cbb/clk_div.md`
