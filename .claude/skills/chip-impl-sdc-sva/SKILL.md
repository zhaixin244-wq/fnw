---
name: chip-impl-sdc-sva
description: "Use when generating SDC constraints, SVA assertions or testbench for RTL. Triggers on 'SDC', 'SVA', 'testbench', '时钟约束', '断言', 'TB', '约束文件', 'assertion'. Generates clock constraints, SVA assertions and testbench based on microarch timing strategy."
---

# SDC/SVA/TB 编写 Skill

## 任务
基于微架构时钟策略和验证要点生成 SDC 约束、SVA 断言、TB testbench。

## 输入
- `rtl_files`: RTL 文件列表
- `microarch_doc`: 微架构文档
- `port_list`: 端口列表

## 执行步骤

0. 用 `Glob` 搜索 `{module}_work/ds/doc/ua/*.md` 获取微架构文档列表。若文件不存在，暂停并提示用户

### SDC 约束
1. 从微架构 §6 提取时钟定义（频率/来源）
2. 生成 `create_clock` / `set_input_delay` / `set_output_delay`
3. 设置 `set_false_path`（复位信号）
4. 保存到 `{module}_work/run/{module}.sdc`

### SVA 断言
1. 从微架构 §10 提取验证场景
2. 实现握手稳定性：`valid && !ready |=> valid`
3. 实现数据稳定性：`valid && !ready |=> $stable(data)`
4. 实现非法状态检测
5. 所有 SVA 放在 `` `ifdef ASSERT_ON `` 内
6. 保存到 `{module}_work/ds/rtl/{submodule}_sva.sv`

### TB testbench
1. 生成基本 testbench 框架
2. 时钟/复位生成
3. 实例化 DUT
4. 保存到 `{module}_work/ds/rtl/{submodule}_tb.v`

### Run 脚本
1. 生成文件列表 `{module}_work/run/{module}.f`
2. 生成 Lint 脚本 `{module}_work/run/lint.sh`
3. 生成综合脚本 `{module}_work/run/synth_yosys.tcl`

## 输出
- `sdc_file`: `{module}_work/run/{module}.sdc`
- `sva_file`: `{module}_work/ds/rtl/{submodule}_sva.sv`
- `tb_file`: `{module}_work/ds/rtl/{submodule}_tb.v`
- `filelist`: `{module}_work/run/{module}.f`
- `lint_script`: `{module}_work/run/lint.sh`
- `synth_script`: `{module}_work/run/synth_yosys.tcl`

## Gate
无强制门禁，但 SDC 时钟周期必须与微架构 §6 一致。

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/sdc_sva.json`：
```json
{"stage_id": "sdc_sva", "duration_ms": 0, "iteration_count": 1}
```

## 使用示例

**示例 1**：
- 用户：「为公共模块生成 SDC 约束和 SVA 断言」
- 行为：从微架构 §6 提取时钟定义生成 `create_clock`/`set_input_delay`/`set_output_delay`，从 §10 提取验证场景生成握手/数据稳定性断言，保存到对应目录

**示例 2**：
- 用户：「帮我写 buf_mgr 的 testbench 框架」
- 行为：生成基本 TB 框架（时钟/复位生成 + DUT 实例化 + 文件列表），保存到 `buf_mgr_work/ds/rtl/buf_mgr_tb.v`，同步生成 `run/lint.sh` 和 `run/synth_yosys.tcl`

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 微架构时钟定义缺失 | §6 无时钟频率/来源 | 暂停，提示用户补充时钟策略 |
| 验证场景缺失 | §10 无验证要点 | 仅生成基础握手断言，标注 `[SVA-PARTIAL]` |
| SDC 时钟周期不一致 | 生成的 SDC 与微架构 §6 矛盾 | 以微架构为准，修正 SDC |
| RTL 文件未就绪 | `rtl_files` 列表为空 | 暂停，提示先完成 RTL 实现 |

## 检查点

**检查前**：
- 确认 RTL 文件列表非空
- 确认微架构文档包含 §6（时钟复位）和 §10（验证要点）

**检查后**：
- 确认 SDC 时钟周期与微架构 §6 一致
- 确认 SVA 断言在 `` `ifdef ASSERT_ON `` 内
- 确认文件列表 `.f` 和脚本已生成
- 确认 metrics 已写入 `{work_dir}/ds/report/metrics/sdc_sva.json`
