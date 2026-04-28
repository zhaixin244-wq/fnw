---
name: chip-png-d2-gen
description: "Use when generating D2 architecture diagrams, data flow diagrams, or FSM state machine diagrams. Triggers on 'd2', '架构图', '框图', '状态机图', 'diagram', '数据通路图', 'generate d2', '模块连接图'. Compiles .d2 source to PNG using dagre layout."
---

# Chip PNG D2 Generator

## 任务
为芯片模块生成 D2 格式的架构框图、流程图、状态机图，通过 `d2` CLI 编译为 PNG。

## 依赖
- D2 CLI：独立二进制，见 `requirements.txt`
- D2 语言规范：https://d2lang.com
- 工具路径查找：优先 `<project_root>/.claude/tools/d2/d2.exe`，其次系统 PATH

## 执行步骤

1. **编写 D2 源文件**：将 `.d2` 文件写入项目输出目录，命名规则：
   - 架构/框图：`{module}_arch.d2` 或 `wd_{name}.d2`
   - 流程图：`wd_{name}_flow.d2`
   - 状态机：`wd_{name}_fsm.d2`

2. **生成 PNG**：
   ```bash
   # 单文件：d2 CLI 直接编译（工具路径查找：.claude/tools/d2/d2.exe → 系统 PATH）
   d2 --layout dagre <output_dir>/input.d2 <output_dir>/output.png

   # 批量（通过 wavedrom skill 的 gen_wavedrom.js，处理所有 wd_*.d2 + wd_*.json）
   node .claude/skills/chip-png-wavedrom-gen/gen_wavedrom.js <output_dir>
   ```
   `<output_dir>` 为项目中存放图表源文件和输出 PNG 的目录。

3. **在文档中引用**：
   ```markdown
   ![描述](filename.png)
   ```

## D2 编写规范

### 架构框图模板
```d2
direction: right

# 外部端口（左=输入，右=输出）
ext_in: "上游输入" {
  style.fill: "#E8F8F5"
  style.stroke: "#27AE60"
  style.stroke-width: 2
}

ext_out: "下游输出" {
  style.fill: "#FDEDEC"
  style.stroke: "#27AE60"
  style.stroke-width: 2
}

# 功能模块
module_a: "模块A" {
  style.fill: "#EBF5FB"
  style.stroke: "#5B9BD5"
  sub_block: "子功能" {shape: cylinder}
}

# 数据通路连线
ext_in -> module_a: "数据流" {style.stroke: "#2E75B6"; style.stroke-width: 2}
module_a -> ext_out {style.stroke: "#2E75B6"; style.stroke-width: 2}

# 配置连线（虚线）
config -> module_a: "配置" {style.stroke: "#8E44AD"; style.stroke-dash: 3}
```

### 流程图模板
```d2
direction: right

step1: "步骤1" {
  style.fill: "#EBF5FB"
  style.stroke: "#5B9BD5"
}

step2: "步骤2" {
  style.fill: "#E8F5E9"
  style.stroke: "#27AE60"
}

decision: "条件?" {
  shape: diamond
  style.fill: "#FFEBEE"
  style.stroke: "#C0392B"
}

step1 -> step2 -> decision
decision -> step3: "yes"
```

### 状态机模板
```d2
direction: right

idle: "IDLE" {
  style.fill: "#E8F5E9"
  style.stroke: "#27AE60"
}

busy: "BUSY" {
  style.fill: "#FFF3E0"
  style.stroke: "#E67E22"
}

error: "ERROR" {
  style.fill: "#FFEBEE"
  style.stroke: "#C0392B"
}

idle -> busy: "start && !err"
busy -> idle: "done"
busy -> error: "err"
error -> idle: "rst"
```

## D2 语法注意事项

### 保留字规避
| 保留字 | 替代方案 |
|--------|----------|
| `link` | `chain_link`, `next`, `ref` |
| `yes`/`no` | 用中文 `yes`/`no` 作为边标签无问题，但不能作为节点 ID |
| 数字开头的 ID | 加前缀，如 `s1_step` 而非 `1_step` |

### 样式约束
- `style.stroke-width`：**必须整数 0-15**，不支持浮点
- `style.stroke-dash`：虚线样式，常用 `3`
- `style.fill`：背景色，使用 HEX 格式
- 推荐配色方案：
  - 输入/绿色系：`#E8F8F5` / `#27AE60`
  - 模块/蓝色系：`#EBF5FB` / `#5B9BD5`
  - 配置/紫色系：`#FAF5FF` / `#8E44AD`
  - 输出/红色系：`#FDEDEC` / `#E74C3C`
  - 警告/橙色系：`#FFF3E0` / `#E67E22`
  - 错误/红色系：`#FFEBEE` / `#C0392B`

### 形状选择
| 用途 | 推荐 shape |
|------|-----------|
| 功能模块 | 默认 rectangle |
| SRAM/存储 | `cylinder` |
| 判断/选择 | `diamond` |
| 外部接口 | `hexagon` |
| 配置模块 | 虚线框 `style.stroke-dash: 3` |

### 布局
- 默认 `direction: right`（从左到右）
- 架构框图用 `direction: right`
- 状态机用 `direction: right`
- 命令行加 `--layout dagre` 确保有向图布局

## 使用示例

**示例 1**：
- 用户：「为公共模块生成架构框图」
- 行为：编写 `{module}_arch.d2`（外部输入/输出 + 功能模块 + 数据通路连线），执行 `d2 --layout dagre` 编译为 PNG，验证输出

**示例 2**：
- 用户：「帮我画 buf_mgr 的 FSM 状态机图」
- 行为：从微架构 §5.3 读取状态定义，编写 `wd_buf_mgr_fsm.d2`（IDLE/WORK/ERROR 状态 + 转移条件），编译为 PNG

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| D2 语法错误 | .d2 文件有语法问题 | 输出 d2 编译错误信息，定位错误行 |
| d2 CLI 不可用 | d2 不在 PATH 且无本地安装 | 暂停，提示安装 d2 CLI |
| 保留字冲突 | 节点 ID 使用了 `link` 等保留字 | 自动替换为 `chain_link` 等替代方案 |
| PNG 未生成 | 编译成功但文件不存在 | 检查输出目录权限，重试 |

## 检查点

**检查前**：
- 确认 d2 CLI 可用
- 确认输出目录存在

**检查后**：
- 确认 .d2 源文件已保存
- 确认 .png 文件已生成且非空
- 确认配色和形状符合规范
