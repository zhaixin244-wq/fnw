---
name: chip-microarch-chart-workflow
description: 微架构图表生成工作流。封装 D2/Wavedrom/Interface 图表的生成、编译、验证流程。供 chip-microarch-writer 调用，确保图表强制生成。
tools:
  - Read
  - Write
  - Bash
  - Skill
---

# 微架构图表生成工作流

> 本 skill 封装微架构文档中图表生成的标准化流程，确保每个子模块的图表完整生成。

## 输入参数

```json
{
  "module": "{module_name}",
  "submodule": "{submodule_name}",
  "output_dir": "{module_name}_work/ds/doc/ua/tmp",
  "charts": ["arch", "datapath", "fsm", "timing", "intf"]
}
```

## 工作流程

### 1. 架构图（arch）

```
1. Read 模块功能描述
2. Write wd_{sub}_arch.d2 到 {output_dir}/
3. 调用 Skill: chip-png-d2-gen
   - d2_file: {output_dir}/wd_{sub}_arch.d2
   - output_dir: {output_dir}/
4. Bash: 验证 {output_dir}/wd_{sub}_arch.png 存在
```

### 2. 数据通路图（datapath）

```
1. Read 数据通路描述
2. Write wd_{sub}_datapath.d2 到 {output_dir}/
3. 调用 Skill: chip-png-d2-gen
   - d2_file: {output_dir}/wd_{sub}_datapath.d2
   - output_dir: {output_dir}/
4. Bash: 验证 {output_dir}/wd_{sub}_datapath.png 存在
```

### 3. 状态机图（fsm）

```
1. Read 状态定义和转移条件
2. Write wd_{sub}_fsm.d2 到 {output_dir}/
3. 调用 Skill: chip-png-d2-gen
   - d2_file: {output_dir}/wd_{sub}_fsm.d2
   - output_dir: {output_dir}/
4. Bash: 验证 {output_dir}/wd_{sub}_fsm.png 存在
```

### 4. 时序图（timing）

```
1. Read 接口协议描述
2. Write wd_{desc}.json 到 {output_dir}/
3. 调用 Skill: chip-png-wavedrom-gen
   - json_file: {output_dir}/wd_{desc}.json
   - output_dir: {output_dir}/
4. Bash: 验证 {output_dir}/wd_{desc}.png 存在
```

### 5. 端口图（intf）

```
1. Read 端口列表
2. Write wd_intf_{sub}.json 到 {output_dir}/
3. 调用 Skill: chip-png-interface-gen
   - json_file: {output_dir}/wd_intf_{sub}.json
   - output_dir: {output_dir}/
4. Bash: 验证 {output_dir}/wd_intf_{sub}.png 存在
```

## 批量编译

```bash
node .claude/skills/chip-png-wavedrom-gen/gen_wavedrom.js {output_dir}/
```

## 验证清单

```bash
# 验证所有 .d2 有对应 .png
for f in {output_dir}/wd_*.d2; do
  [ -f "${f%.d2}.png" ] || echo "MISSING: ${f%.d2}.png"
done

# 验证所有 .json 有对应 .png
for f in {output_dir}/wd_*.json; do
  [ -f "${f%.json}.png" ] || echo "MISSING: ${f%.json}.png"
done
```

## 降级处理

| 场景 | 处理方式 |
|------|----------|
| D2 编译失败 | 保留 .d2，标注 [D2-DEGRADED]，降级为文本描述 |
| Wavedrom 解析失败 | 保留 .json，标注错误位置，降级为文本时序表 |
| Interface 生成失败 | 跳过（非关键） |

## 输出

- 所有图表源文件（.d2/.json）在 {output_dir}/
- 所有编译产物（.png）在 {output_dir}/
- 验证报告（pass/fail 列表）
