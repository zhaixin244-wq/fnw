---
name: chip-diagram-generator
description: "Use when generating chip module diagrams (block diagrams, timing diagrams, FSM diagrams). Triggers on '框图', '时序图', '状态机图', 'diagram', '架构图', '画图', '画一个'. Generates module block diagrams, timing diagrams and state machine diagrams. Primary format: D2→PNG for block/FSM diagrams, Wavedrom→PNG for timing diagrams."
---

# Chip Diagram Generator

## 任务
为芯片模块架构生成专业、可渲染的图表。

## 支持的图表类型（按优先级排序）

| 优先级 | 图表类型 | 工具 | 输出格式 | 适用场景 |
|--------|----------|------|----------|----------|
| **1（首选）** | 框图/架构图/FSM | D2 → PNG | `.d2` → `d2 --layout dagre` | 模块框图、数据通路、状态机、NoC 拓扑 |
| **2** | 时序图 | Wavedrom → PNG | `.json` → `wavedrom-cli` | 接口握手、协议事务、关键路径 |
| **3（降级）** | 通用图表 | Mermaid | `.mmd` → `mermaid-cli` | 仅当 D2 无法表达时使用 |

**项目规范**：微架构模板 §5.3 明确要求使用 D2 生成 FSM 图。框图和状态机图**必须优先使用 D2**，Mermaid 仅作为降级方案。

## 执行步骤

1. 确认图表类型与用户所需展示的核心信息。
2. **根据图表类型选择工具**：
   - 框图/FSM → 生成 D2 源码（`.d2` 文件），使用 `d2 --layout dagre {file}.d2 {file}.png` 编译
   - 时序图 → 生成 Wavedrom JSON（`.json` 文件），使用 `wavedrom-cli -i {file}.json -p {file}.png` 编译
   - 降级 → 仅当 D2/Wavedrom 均无法表达时，使用 Mermaid
3. **芯片领域模板**：
   - RR 仲裁器 FSM：S_IDLE → S_CH0/S_CH1/... → S_IDLE，使用独热码编码
   - Valid-Ready 握手：valid 不依赖 ready，ready 优先依赖下游
   - 子模块框图：左侧 input（箭头→指向模块），右侧 output（箭头→指向外部）
4. 编译并验证 PNG 输出成功。为复杂框图添加图例与信号流向说明（箭头旁标注数据宽度）。

## 输出格式

每个图表输出：
1. 源码（D2/Wavedrom JSON）
2. 编译命令
3. PNG 文件路径
4. 简短文字说明图表内容

## 使用示例

**示例 1：生成模块框图（D2）**
```
用户：帮我画公共模块的模块框图，包含 buf、crc、align 三个子模块
```
预期行为：生成 `wd_{module}_arch.d2`，使用 D2 语法定义子模块节点和信号连线，`d2 --layout dagre` 编译为 PNG

**示例 2：生成握手时序图（Wavedrom）**
```
用户：画一个 valid-ready 握手时序图
```
预期行为：生成 `wd_valid_ready.json`，使用 Wavedrom JSON 定义信号时序，`wavedrom-cli` 编译为 PNG

**示例 3：生成 FSM 状态机图（D2）**
```
用户：画一个 4 通道 RR 仲裁器的状态机图
```
预期行为：生成 `wd_rr_arbiter_fsm.d2`，使用 D2 语法定义 S_IDLE/S_CH0~S_CH3 状态和转移条件，独热码编码，编译为 PNG

## 使用示例

**示例 1：生成模块框图**
```
用户：帮我画公共模块的模块框图，包含 buf、crc、align 三个子模块
```
预期行为：生成 Mermaid graph TB 源码，标注信号流向和数据宽度

**示例 2：生成握手时序图**
```
用户：画一个 valid-ready 握手时序图
```
预期行为：生成 Wavedrom JSON 源码，展示 valid/ready/data 信号的时序关系

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 图表语法错误 | Mermaid/Wavedrom 解析失败 | 标注错误位置，给出修正建议 |
| 图表过于复杂 | 节点数 > 20 | 建议拆分为多个子图 |
| 渲染工具不可用 | mermaid-cli 未安装 | 输出源码，建议用户使用在线编辑器验证 |
| 信号名不规范 | 使用了非法字符 | 自动替换为合法标识符，提示用户确认 |

## 检查点

**检查前**：
- 确认图表类型（框图/时序图/FSM）已明确
- 确认核心信息和数据流向已了解

**检查后**：
- 确认源码语法正确
- 确认 PNG 编译成功
- 确认图表包含信号宽度标注和图例

## 降级策略

| 场景 | 行为 |
|------|------|
| D2 工具不可用 | 降级为 Mermaid，标注 `[DIAG-DEGRADED]` |
| wavedrom-cli 不可用 | 输出 JSON 源码，建议用户使用在线编辑器 |
| 图表过于复杂（>20 节点） | 拆分为多个子图，分别生成 |

## 关联 Skills

- **架构图/流程图/状态机**：`chip-png-d2-gen`（D2→PNG，dagre 布局）
- **时序图**：`chip-png-wavedrom-gen`（Wavedrom JSON→PNG）
- **接口端口图**：`chip-png-interface-gen`（Verilog 端口声明→PNG）

需要从 RTL 自动生成图表时，优先调用上述专项 Skill。
