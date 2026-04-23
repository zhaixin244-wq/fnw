# formal_basics

> 形式验证基础，等价性检查与属性检查参考

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/verification/formal_basics.md |

## 核心特性
- 形式验证使用数学方法证明设计正确性
- 等价性检查：比较两个设计（RTL vs 门级）
- 属性检查：验证 SVA 属性（功能验证）
- 模型检查：穷举状态空间（协议验证）

## 关键参数

| 形式验证类型 | 说明 | 应用场景 | 工具 |
|-------------|------|----------|------|
| 等价性检查 | 比较两个设计 | RTL vs 门级 | Formality/Conformal |
| 属性检查 | 验证 SVA 属性 | 功能验证 | JasperGold/VC Formal |
| 模型检查 | 穷举状态空间 | 协议验证 | SPIN/NuSMV |

## 典型应用场景
- 综合前后等价性验证
- 协议状态机正确性验证
- 安全属性验证（无死锁、无活锁）
- 寄存器配置正确性验证

## 与其他实体的关系
- **formal_advanced**：高级形式验证技术
- **simulation_basics**：仿真补充形式验证
- **uvm_basics**：SVA 属性可在 UVM 中使用
- **coverage_analysis**：形式验证覆盖率评估

## 设计注意事项
- 状态空间爆炸问题需要抽象和约束
- 属性编写质量直接影响验证效果
- 等价性检查不需要 Testbench

## 参考
- 原始文档：`.claude/knowledge/verification/formal_basics.md`
