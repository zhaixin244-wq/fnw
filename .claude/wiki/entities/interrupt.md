# interrupt

> 处理器中断控制器架构设计，管理和分发中断请求

## 基本信息

| 字段 | 值 |
|------|----|
| 类型 | 概念 |
| 来源 | .claude/knowledge/cpu/interrupt.md |

## 核心特性
- 中断类型：外部中断、内部中断、软件中断、异常
- 简单中断控制器：基本优先级编码
- 高级中断控制器：GIC（ARM）、APIC（x86）、PLIC/CLIC（RISC-V）
- 中断优先级、屏蔽、嵌套支持

## 典型应用场景
- 所有 CPU/SoC 中断子系统设计
- 多核中断路由和负载均衡
- 实时系统中断响应优化

## 与其他实体的关系
- **intc**：中断控制器 CBB 实现
- **arm**：ARM GIC 中断控制器
- **riscv**：RISC-V PLIC/CLIC 中断控制器

## 设计注意事项
- 中断延迟 = 识别延迟 + 上下文保存 + 跳转延迟
- 嵌套中断需要保存/恢复上下文
- 多核中断亲和性（Affinity）影响负载均衡

## 参考
- 原始文档：`.claude/knowledge/cpu/interrupt.md`
