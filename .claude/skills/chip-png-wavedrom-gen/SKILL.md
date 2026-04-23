---
name: chip-png-wavedrom-gen
description: 使用Wavedrom JSON格式生成芯片时序图PNG。支持信号分组、cycle标注、多通道并行时序展示。
---

# Chip PNG Wavedrom Generator

## 任务
为芯片模块生成 Wavedrom 格式的时序图 JSON 源文件，通过 `wavedrom-cli` + `playwright` 编译为 PNG。

## 依赖
- Node.js
- 依赖包：见 `requirements.txt`（`npm install`）
- D2 CLI（如需处理 `.d2` 文件）：见 `chip-png-d2-gen/requirements.txt`
- 工具路径：chromium 路径通过 `CHROME_PATH` 环境变量或脚本内默认值配置

## 调用方式

### 1. 编写 JSON 源文件
将 `.json` 文件写入项目输出目录，命名规则：`wd_{描述}.json`

### 2. 生成 PNG
```bash
# 单文件：wavedrom-cli 生成 SVG，playwright 截图生成 PNG
npx wavedrom --input <output_dir>/wd_xxx.json > <output_dir>/wd_xxx.svg

# 批量（通过 gen_wavedrom.js，处理所有 wd_*.json + wd_*.d2）
node .claude/skills/chip-png-wavedrom-gen/gen_wavedrom.js <output_dir>
```

`<output_dir>` 为项目中存放图表源文件和输出 PNG 的目录。

### 3. 在文档中引用
```markdown
![描述](wd_xxx.png)
```

## Wavedrom JSON 格式规范

### 基本结构
```json
{signal: [
  {name: 'clk',  wave: 'p.......'},
  {name: 'valid', wave: '01..0...'},
  {name: 'data',  wave: 'x222x...', data: ['D0', 'D1', 'D2']},
]}
```

### 信号分组（推荐）
多组并行信号用二维数组，第一项为组名：
```json
{signal: [
  ['上游请求',
    {name: 'clk',   wave: 'p.......'},
    {name: 'req',   wave: '010.....'},
    {name: 'data',  wave: 'x22x....', data: ['D0']},
  ],
  ['下游响应',
    {name: 'clk',   wave: 'p.......'},
    {name: 'rsp',   wave: '0..10...'},
  ],
  ['cycle',
    {name: '',      wave: '2222222', data: ['0','1','2','3','4','5','6']},
  ]
]}
```

### wave 符号速查

| 符号 | 含义 | 用途 |
|------|------|------|
| `p` | 时钟上升沿 | 时钟信号 |
| `P` | 时钟下降沿 | 低有效时钟 |
| `n` | 低电平 | 低有效信号 |
| `0` | 低电平/无效 | 默认状态 |
| `1` | 高电平/有效 | 有效状态 |
| `2` | 数据值 | 数据传输 |
| `3` | 高阻态 | 三态总线 |
| `x` | 无关 | 未关心值 |
| `.` | 保持前值 | 连续有效 |
| `=` | 数据标签 | 配合 `data` 数组 |
| `-` | 空/未画 | 跳过该区域 |

### wave 常用模式

```json
// Valid-Ready 握手
{name: 'valid', wave: '01...0.'},
{name: 'ready', wave: '0.1..0.'},
{name: 'data',  wave: 'x222x..', data: ['D0','D1','D2']},

// 脉冲请求（单周期）
{name: 'req',   wave: '010.....'},

// 多周期等待
{name: 'req',   wave: '010.....'},
{name: 'rsp',   wave: '0...10..'},

// 流水线（多级重叠）
{name: 's0_vld', wave: '01.01.0.'},
{name: 's1_vld', wave: '0.1.01.0'},
{name: 's2_vld', wave: '0..1.01.'},

// 地址-数据分离（读）
{name: 'arvalid', wave: '010......'},
{name: 'araddr',  wave: 'x22x.....', data: ['A0']},
{name: 'rvalid',  wave: '0...10...'},
{name: 'rdata',   wave: 'x...22x..', data: ['D0','D1']},
```

### cycle 标注行（推荐）
在最后一组添加 cycle 编号行，便于时序分析：
```json
['cycle',
  {name: '', wave: '222222222222', data: ['0','1','2','3','4','5','6','7','8','9','10','11']},
]
```

## 编写技巧

### 分组策略
- 按功能域分组：上游请求、下游响应、内部状态、cycle编号
- 每组独立 `clk`，避免信号跨组混乱
- 3-5 个信号/组最佳，过多拆分

### 命名规范
- 信号名用 Verilog 风格：`req_vld`, `rsp_data`, `sram_rd_en`
- 组名用中文简述功能：`SRAM读请求`, `SRAM返回 & 输出`, `输出(零气泡切换)`

### 数据标注
- `{name: 'signal', wave: 'x222x...', data: ['A0', 'D1', 'D2']}`
- `data` 数组对应 wave 中每个 `2` 的位置
- 地址用 `A0/A1`，数据用 `D0/D1`，状态用 `IDLE/BUSY`

### 常见时序场景模板

#### 3-cycle SRAM 读延迟
```json
{name: 'req',  wave: '010.....'},
{name: 'rsp',  wave: '0...10..'},
{name: 'data', wave: 'x...22x.', data: ['D0','D1']},
```

#### 多通道交织返回
```json
{name: 'ch0_rsp', wave: '01010...'},
{name: 'ch1_rsp', wave: '0.10.10.'},
{name: 'ch2_rsp', wave: '0..10.10'},
```

#### Back-pressure
```json
{name: 'valid',  wave: '01..1.0.'},
{name: 'ready',  wave: '0.10.10.'},
{name: 'bp',     wave: '0.10....'},
```
