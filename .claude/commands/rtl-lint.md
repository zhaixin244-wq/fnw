# RTL Lint — Verilator + Verible 双重检查

对 Verilog/SystemVerilog 文件执行综合 lint 检查。

## 检查内容

1. **Verible 语法检查** — 解析器级别的语法正确性
2. **Verible 风格检查** — 50+ 可配置规则（命名、格式、结构）
3. **Verilator 功能检查** — 功能级 lint（latch、位宽、未连接端口等）

## 使用方式

```bash
# 完整检查
bash .claude/shared/rtl-lint.sh {file}.v

# 检查 + 自动格式化
bash .claude/shared/rtl-lint.sh {file}.v --fix
```

## 参数

- `$ARGUMENTS` — 要检查的 Verilog 文件路径

## 检查规则

| 工具 | 检查维度 | 规则文件 |
|------|----------|----------|
| Verible | 语法、命名、格式、结构 | `.claude/tools/verible/verible-lint.rules` |
| Verilator | 功能、位宽、latch、未连接端口 | 内置 -Wall |

## 规则定制

编辑 `.claude/tools/verible/verible-lint.rules` 可启用/禁用规则：
- `+rule-name` 启用
- `-rule-name` 禁用
