# frontend_design

> 芯片前端设计流程，涵盖 RTL 编码、功能验证、逻辑综合和形式验证

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 方法论 |
| 来源 | .claude/knowledge/chip-design/frontend_design.md |

## 核心特性
- RTL 设计语言：Verilog/SystemVerilog/VHDL
- 时钟域划分与 CDC 同步（双触发器/异步 FIFO/格雷码）
- 异步复位同步释放设计
- 逻辑综合流程与 SDC 约束编写
- 形式验证（等价性检查）与门级仿真

## 典型应用场景
- RTL 编码与编码规范制定
- 综合约束（SDC）编写指导
- CDC 设计与验证
- 时序不收敛/功耗超标问题排查

## 与其他实体的关系
- **sta_basics**：前端设计的时序约束需要 STA 验证
- **cdc_sync/cdc_handshake_bus**：CDC 同步的具体实现
- **reset_sync**：异步复位同步释放的 CBB 实现

## 设计注意事项
- 命名规范：模块/信号小写下划线，参数大写下划线
- 时钟命名 `clk` 前缀，复位命名 `rst_xxx_n`
- CDC 必须使用专用同步模块，禁止手动打拍
- 综合约束必须覆盖所有时钟域和接口

## 参考
- 原始文档：`.claude/knowledge/chip-design/frontend_design.md`
