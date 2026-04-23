# 图表生成规范（共享）

> 供 chip-microarch-writer / chip-fs-writer 等 Agent 引用，不得内联复制。
> 所有图表源文件和输出 PNG 统一写入 `<module>_work/ds/doc/ua/tmp/`（微架构）或 `<module>_work/ds/doc/fs/tmp/`（FS）。

---

## chip-png-d2-gen（架构图/状态机/数据通路图）

**调用流程**：编写 `.d2` 源文件 → `d2 --layout dagre` 编译为 PNG。

**命名规则与适用场景**：

| 场景 | 文件命名 | 微架构对应章节 |
|------|----------|---------------|
| 子模块内部框图 | `wd_{sub}_arch.d2` | §3.3 内部框图 |
| 数据通路图 | `wd_{sub}_datapath.d2` | §5.1 数据通路 |
| 状态机图 | `wd_{sub}_fsm.d2` | §5.3 状态机 |
| 流程图 | `wd_{sub}_flow.d2` | §5.x 控制流 |

**编译命令**：
```bash
# 单文件（工具路径：.claude/tools/d2/d2.exe → 系统 PATH）
d2 --layout dagre <output_dir>/wd_xxx.d2 <output_dir>/wd_xxx.png

# 批量（同时处理所有 wd_*.d2 + wd_*.json）
node .claude/skills/chip-png-wavedrom-gen/gen_wavedrom.js <output_dir>
```

**D2 编写约束**：
- `style.stroke-width` 必须整数 0-15，不支持浮点
- 配色：输入/绿色系 `#E8F8F5`，模块/蓝色系 `#EBF5FB`，输出/红色系 `#FDEDEC`，状态/橙色系 `#FFF3E0`
- 形状：SRAM → `cylinder`，判断 → `diamond`，外部接口 → `hexagon`
- 避免保留字：`link` → `chain_link`，数字开头加前缀

**在文档中引用**：
```markdown
![{子模块名} 内部框图](wd_{sub}_arch.png)
![{子模块名} 数据通路](wd_{sub}_datapath.png)
![{子模块名} 状态机](wd_{sub}_fsm.png)
```

---

## chip-png-wavedrom-gen（时序图）

**调用流程**：编写 Wavedrom `.json` 源文件 → `npx wavedrom` 生成 SVG → playwright 截图生成 PNG。

**命名规则**：`wd_{描述}.json`（如 `wd_apb_write.json`、`wd_axi_read_resp.json`）

**适用场景**：

| 场景 | 微架构对应章节 |
|------|---------------|
| 接口事务时序 | §4.2 接口协议与事务时序 |
| 握手时序 | §5.2 控制逻辑 / §4.2 |
| 流水线时序 | §5.4 流水线设计 |
| 仲裁/背压时序 | §5.2 流控机制 |

**编译命令**：
```bash
# 单文件
npx wavedrom --input <output_dir>/wd_xxx.json > <output_dir>/wd_xxx.svg

# 批量（推荐，同时处理 .json 和 .d2）
node .claude/skills/chip-png-wavedrom-gen/gen_wavedrom.js <output_dir>
```

**Wavedrom JSON 要点**：
- 多组并行信号用二维数组，第一项为组名（如 `['上游请求', ...]`）
- 必须添加 cycle 标注行：`['cycle', {name: '', wave: '2222...', data: ['0','1','2',...]}]`
- 每组独立 `clk`，3-5 个信号/组最佳
- 信号名用 Verilog 风格：`req_vld`, `rsp_data`
- 数据标注：地址用 `A0/A1`，数据用 `D0/D1`

**在文档中引用**：
```markdown
![{事务名称} 时序](wd_{描述}.png)
```

---

## chip-png-interface-gen（接口端口图）

**调用流程**：准备接口 JSON 配置 → `python gen_module_snapshot.py` 生成 PNG。

**命名规则**：输出文件 `wd_intf_{接口名}.png`

**适用场景**：

| 场景 | 微架构对应章节 |
|------|---------------|
| 子模块端口图 | §4.1 端口列表（配合端口表） |
| 顶层接口图 | FS §6 接口定义 |

**调用方式**：
```bash
# 外部 JSON 配置（推荐）
python .claude/skills/chip-png-interface-gen/gen_module_snapshot.py <json_file> <output_dir>
```

**接口 JSON 文件路径**：`<module>_work/ds/doc/ua/tmp/wd_intf_{sub}.json`（与 D2/Wavedrom 源文件同目录）。

**接口 JSON 格式**：使用 `</left>`（输入）和 `</right>`（输出）分隔，信号含方向、位宽 `[H:L]`、信号名。

**在文档中引用**：
```markdown
![{子模块名} 端口图](wd_intf_{sub}.png)
```

---

## 批量生成

单个子模块微架构编写完成后，推荐使用批量命令一次性编译所有图表：
```bash
node .claude/skills/chip-png-wavedrom-gen/gen_wavedrom.js <module>_work/ds/doc/ua/tmp/
```
该命令自动处理目录下所有 `wd_*.d2` 和 `wd_*.json` 文件，生成对应 PNG。

---

## 图表编译验证（质量门禁）

在 `quality_check` 阶段，必须对所有图表源文件执行编译验证：

```bash
# 验证所有 D2 文件
for f in <output_dir>/wd_*.d2; do
  d2 --layout dagre "$f" "${f%.d2}.png" || echo "D2-COMPILE-FAIL: $f"
done

# 验证所有 Wavedrom JSON
for f in <output_dir>/wd_*.json; do
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" || echo "JSON-PARSE-FAIL: $f"
done
```

编译失败项必须在 §11 风险章节中标注，并保留源文件供修复。
