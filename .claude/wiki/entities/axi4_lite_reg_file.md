# axi4_lite_reg_file

> AXI4-Lite 从接口寄存器文件，CPU 通过总线读写配置和状态寄存器

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | CBB |
| 来源 | .claude/knowledge/cbb/axi4_lite_reg_file.md |

## 核心特性
- 标准 AXI4-Lite 从接口，支持完整 AW/W/B/AR/R 握手
- 支持 RW（读写）、RO（只读）、W1C（写1清零）三种寄存器类型
- 写地址/写数据并行握手，2 周期完成读/写事务
- wstrb 字节使能支持 8/16/32 位粒度写入
- 地址越界返回 DECERR 响应

## 关键参数

| 参数 | 默认值 | 范围 | 说明 |
|------|--------|------|------|
| `REG_COUNT` | 16 | ≥1 | 寄存器数量 |
| `ADDR_WIDTH` | 6 | ≥$clog2(REG_COUNT×4) | 地址位宽 |
| `BASE_ADDR` | 0 | - | 基地址偏移 |
| `REG_TYPE` | "RW" | RW/RO/W1C | 寄存器类型数组 |

## 接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `s_axi_*` | I/O | AXI4-Lite 标准 | AXI 从接口 |
| `reg_out` | O | REG_COUNT×32 | 寄存器输出（连接功能逻辑） |
| `reg_in` | I | REG_COUNT×32 | 寄存器输入（RO/W1C 状态反馈） |
| `reg_wr_strobe` | O | REG_COUNT | 寄存器写入脉冲 |

## 典型应用场景
- SoC 配置空间：模块使能、模式选择、中断控制
- 外设控制寄存器：UART 波特率、SPI 时钟分频
- 状态查询：中断状态（W1C）、错误计数器（RO）

## 与其他实体的关系
- 通常作为 bridge_axi_to_apb 的下游或直接挂在 AXI 互联上
- 与 address_decoder 配合实现寄存器地址映射

## 设计注意事项
- RO 寄存器写操作被忽略，读返回 reg_in 值
- W1C 寄存器：写 1 对应位清零，写 0 保持不变
- 地址按 4 字节对齐：`reg_idx = (addr - BASE_ADDR) >> 2`
- 面积：REG_COUNT × 32 触发器 + AXI 握手逻辑

## 参考
- 原始文档：`.claude/knowledge/cbb/axi4_lite_reg_file.md`
