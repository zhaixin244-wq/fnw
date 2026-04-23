---
name: 工具链与skill参考
description: 项目中使用的图表生成工具、skill位置和调用方式
type: reference
---
## 工具安装目录

```
.claude/tools/
├── requirements.txt          # 全局工具依赖总表
└── d2/
    └── d2.exe                # D2 CLI v0.7.1（已安装）
```

工具查找顺序：`.claude/tools/<name>` → 系统 PATH

## 图表生成 Skill

| Skill | 脚本 | 依赖 | 安装命令 |
|-------|------|------|----------|
| `chip-png-interface-gen` | `gen_module_snapshot.py` | Pillow | `pip install -r requirements.txt` |
| `chip-png-wavedrom-gen` | `gen_wavedrom.js` | playwright-core, @wavedrom/cli | `npm install` |
| `chip-png-d2-gen` | (d2 CLI) | d2.exe | 已在 `.claude/tools/d2/` |

### 调用方式
```bash
# 接口端口图
python .claude/skills/chip-png-interface-gen/gen_module_snapshot.py <json> <out_dir>

# D2 架构图（单文件）
.claude/tools/d2/d2.exe --layout dagre <input.d2> <output.png>

# Wavedrom + D2 批量
node .claude/skills/chip-png-wavedrom-gen/gen_wavedrom.js <out_dir>
```

### 环境变量
- `CHROME_PATH`：playwright chromium 路径（默认 ms-playwright 安装路径）

## 已创建的 Chip Skills

| Skill | 用途 |
|-------|------|
| `chip-png-interface-gen` | Verilog 模块声明→接口端口 PNG |
| `chip-png-d2-gen` | D2 架构图/流程图/状态机→PNG |
| `chip-png-wavedrom-gen` | Wavedrom JSON 时序图→PNG |
| `chip-diagram-generator` | Mermaid/Wavedrom 图表生成 |
| `chip-interface-contractor` | 接口契约文档 |
| `chip-doc-structurer` | 文档结构化 |
| `chip-rtl-guideline-generator` | RTL 编码规范 |
