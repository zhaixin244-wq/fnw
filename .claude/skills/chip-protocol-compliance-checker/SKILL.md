---
name: chip-protocol-compliance-checker
description: "Use when checking module interface protocol compliance. Triggers on '协议检查', 'protocol check', 'AXI合规', 'APB合规', '协议合规', '接口规范', 'compliance'. Checks module interfaces against AXI/CHI/TileLink/APB protocol specifications."
---

# Chip Protocol Compliance Checker

## 任务
检查模块接口架构是否符合选定总线协议的规范要求。

## 支持协议
- AXI4 / AXI4-Lite
- ACE / ACE-Lite
- CHI（AMBA 5）
- TileLink
- APB / AHB

## 执行步骤
1. **获取 RTL 源码**：
   - 用 `Glob` 搜索 `{module}_work/ds/rtl/*.v` 获取模块文件列表
   - 用 `Read` 读取目标模块 RTL，用 `Grep` 提取端口声明
   - 若文件不存在，暂停并提示用户先完成 RTL 实现
2. **Wiki/RAG 知识检索**：按 `rag-mandatory-search.md` 协议，检索 `.claude/wiki/` 中对应协议规范页（如 `axi4_*`），获取检查项清单
3. 确认用户使用的协议版本与接口角色（Master/Slave/Interconnect）。若未指定，从端口名推断（`arvalid`→Master, `awready`→Slave）
4. 逐条核对关键协议要求：
   - **握手规则**：VALID/READY 依赖关系、无组合路径、数据稳定性
   - **事务排序**：ID 扩展、out-of-order 支持、原子操作
   - **缓存一致性**（ACE/CHI/TileLink）：Snoop 响应、脏数据回写、Shareability Domain
   - **突发传输**：Burst Type/Length、Wrap/Increment 规则、不对齐访问
   - **地址映射**：Region/Cache/Prot/ QoS 信号定义
   - **低功耗接口**（AXI4）：CACTIVE/CSYSREQ/CSYSACK 时序
3. 识别常见违规点：
   - READY 依赖 VALID 的组合路径
   - WLAST 与 AWLEN 不匹配
   - 非法的 Burst Type 组合
   - ID 位宽不足导致排序冲突
4. 生成合规检查报告与整改建议。

## 输出格式
```markdown
### 协议合规检查报告（协议：AXI4 | 角色：Slave）

| 检查项 | 规范来源 | 状态 | 发现 | 建议 |
|--------|----------|------|------|------|
| READY 不依赖 VALID | AXI4 §A3.2.1 | Pass | - | - |
| WLAST 与 AWLEN 匹配 | AXI4 §A3.4.1 | Fail | 最后一拍未正确置起 WLAST | 在 W 通道计数器中检查 |

**合规评分：X/Y (Z%)**
```

## 使用示例

**示例 1**：
- 用户：「检查公共模块的 AXI4 Slave 接口是否合规」
- 行为：确认 AXI4 协议和 Slave 角色，逐条核对握手规则（READY 不依赖 VALID）、突发传输（Burst Type/Length）、WLAST 匹配等，输出合规检查报告

**示例 2**：
- 用户：「帮我验证 buf_mgr 的 APB 接口是否符合规范」
- 行为：核对 APB 时序（PSEL→PENABLE→PREADY 握手）、地址对齐、读写信号极性，输出合规评分

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 协议版本未指定 | 用户未明确 AXI4/ACE/CHI 版本 | 默认使用最新版本，标注 `[PROTO-ASSUMED]` |
| 接口信号缺失 | 端口列表不完整 | 列出缺失信号，标注 `[PROTO-INCOMPLETE]` |
| 协议规范文档缺失 | 无 Wiki/RAG 参考 | 基于通用知识检查，标注 `[PROTO-GENERAL]` |
| RTL 文件不存在 | 模块未实现 | 暂停，提示先完成 RTL 实现，标注 `[RTL-MISSING]` |
| 角色未指定 | 用户未说明 Master/Slave | 从端口名推断（`ar*`→Master, `aw*`→Slave），标注 `[ROLE-INFERRED]` |

## 与 chip-arch-reviewer 的关系

协议合规检查是架构评审的子集。若用户要求完整架构评审，应调用 `chip-arch-reviewer` Agent，本 skill 作为其协议检查步骤的详细展开。

## 检查点

**检查前**：
- 确认协议版本和接口角色已明确
- 确认模块端口列表已获取

**检查后**：
- 确认所有关键检查项已逐条核对
- 确认合规评分已输出
- 确认 Fail 项已标注整改建议
