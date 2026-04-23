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
4. 保存到 `{module}_work/syn/{submodule}.sdc`

### SVA 断言
1. 从微架构 §10 提取验证场景
2. 实现握手稳定性：`valid && !ready |=> valid`
3. 实现数据稳定性：`valid && !ready |=> $stable(data)`
4. 实现非法状态检测
5. 所有 SVA 放在 `` `ifdef ASSERT_ON `` 内
6. 保存到 `{module}_work/rtl/{submodule}_sva.sv`

### TB testbench
1. 生成基本 testbench 框架
2. 时钟/复位生成
3. 实例化 DUT
4. 保存到 `{module}_work/rtl/{submodule}_tb.v`

### Makefile
1. 生成 Lint 调用脚本 `run_lint.sh`
2. 生成综合调用脚本 `run_synth.sh`
3. 生成 Makefile

## 输出
- `sdc_file`: SDC 约束文件路径
- `sva_file`: SVA 断言文件路径
- `tb_file`: TB testbench 文件路径
- `makefile`: Makefile 路径

## Gate
无强制门禁，但 SDC 时钟周期必须与微架构 §6 一致。

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/sdc_sva.json`：
```json
{"stage_id": "sdc_sva", "duration_ms": 0, "iteration_count": 1}
```
