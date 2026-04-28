---
name: chip-png-interface-gen
description: "Use when generating interface port PNG diagrams from Verilog module declarations. Triggers on '接口图', '端口图', 'interface gen', 'port diagram', '接口PNG', 'module snapshot'. Generates module_snapshot style port PNGs with inputs on left, outputs on right, signal names with width and direction arrows."
---

# Chip PNG Interface Generator

## 任务
为芯片模块的每组接口生成 module_snapshot 风格的端口图 PNG。左侧放置 input 信号，右侧放置 output 信号，中间为模块名方框，信号旁标注位宽和方向箭头。

## 依赖
- python 3.8+
- 依赖包：见 `requirements.txt`（`pip install -r requirements.txt`）

## 脚本位置
`.claude/skills/chip-png-interface-gen/gen_module_snapshot.py`

## 执行步骤

1. **准备接口定义**：两种方式：
   - **方式 A**：修改脚本内 `INTERFACES` 字典（适合单项目）
   - **方式 B**：创建外部 `interfaces.json`（适合多项目复用）

2. **定义接口格式**：
   - 使用 `</left>` 和 `</right>` 分隔输入/输出（左侧=input，右侧=output）
   - 每个信号需包含 `input`/`output` 方向、可选位宽 `[H:L]`、信号名
   - 没有 `</left>`/`</right>` 标记时，默认全部在左侧（输入）
   - 信号之间用空行分隔会形成视觉分组

3. **运行生成脚本**：
   ```bash
   # 使用脚本内嵌的 INTERFACES（输出到当前目录）
   python .claude/skills/chip-png-interface-gen/gen_module_snapshot.py

   # 使用外部 JSON 配置，指定输出目录
   python .claude/skills/chip-png-interface-gen/gen_module_snapshot.py <json_file> <output_dir>
   ```

4. **验证输出**：确认 `wd_intf_{接口名}.png` 文件存在且大小 > 0。

5. **在文档中引用**：
   ```markdown
   ![{接口名} 端口图](wd_intf_{接口名}.png)
   ```

## 使用示例

**示例 1：生成模块端口图**
```
用户：帮我生成公共模块的接口端口图
```
预期行为：读取模块端口声明，生成 `wd_intf_{module}.png`（左侧 input、右侧 output、信号名+位宽+方向箭头）

**示例 2：生成子模块端口图**
```
用户：画一个 buf_mgr 子模块的端口图，包含 clk/rst_n/data_in/data_out/valid/ready
```
预期行为：解析信号列表，生成 `wd_intf_buf_mgr.png`，input 信号在左、output 信号在右

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 脚本依赖缺失 | `pip install` 失败 | 提示用户安装依赖：`pip install pillow`，降级为文本端口表 |
| JSON 格式错误 | 解析失败 | 标注错误行号，给出修正建议 |
| 脚本执行失败 | Python 报错 | 检查 Verilog 语法，降级为 Markdown 端口表 |
| 输出目录不存在 | 路径无效 | 自动创建目录（`mkdir -p`） |

## 检查点

- **检查前**：展示接口定义摘要（信号数、输入/输出分组），用户确认后执行
- **检查后**：验证 PNG 文件存在且大小 > 0，否则报错
- 输入信号箭头朝右（→，指向模块），在线段起端
- 输出信号箭头朝右（→，指向外部），在线段末端
- 总线信号（位宽>1）绘制对角斜线标记并标注位宽数字
- 信号名使用等宽字体，位宽标注使用较小字号
