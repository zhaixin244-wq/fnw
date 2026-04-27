---
name: chip-impl-sdc-sva
description: SDC/SVA/TB 编写 — 生成时钟约束、SVA 断言、testbench
---

# SDC/SVA/TB 编写 Skill

## 职责
基于微架构时钟策略和验证要点生成 SDC 约束、SVA 断言、TB testbench。

## 输入
- `rtl_files`: RTL 文件列表
- `microarch_doc`: 微架构文档
- `port_list`: 端口列表

## 执行步骤

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
