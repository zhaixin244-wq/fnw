# 仿真基础

> **用途**：仿真流程、调试技术、波形分析基础参考
> **典型应用**：所有芯片功能仿真

---

## 概述

仿真是芯片验证的核心方法，通过运行测试用例验证设计功能正确性。

### 仿真类型

| 类型 | 说明 | 速度 | 精度 |
|------|------|------|------|
| RTL 仿真 | 行为级仿真 | 慢 | 高 |
| 门级仿真 | 带时序仿真 | 中 | 高 |
| 混合仿真 | RTL+门级 | 中 | 高 |

---

## 仿真流程

### 基本流程

```
仿真流程：
┌─────────────────────────────────────────────┐
│  编译阶段                                    │
│  ┌─────────────────────────────────────┐    │
│  │  RTL 源码                           │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  编译器 (VCS/Xcelium/Questa)        │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  仿真可执行文件                      │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  仿真阶段                                    │
│  ┌─────────────────────────────────────┐    │
│  │  测试用例                            │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  仿真器运行                          │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  波形/日志/覆盖率                    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### VCS 仿真

```bash
# VCS 编译
vcs -full64 -sverilog -debug_access+all \
    -timescale=1ns/1ps \
    -f filelist.f \
    -o simv

# VCS 仿真
./simv +UVM_TESTNAME=my_test \
       +UVM_VERBOSITY=UVM_HIGH \
       +ntb_random_seed=12345

# 带波形仿真
./simv +UVM_TESTNAME=my_test \
       +fsdb+dumpfile=wave.fsdb
```

### Xcelium 仿真

```bash
# Xcelium 编译
xrun -64bit -sv -uvm \
     -access +rwc \
     -timescale 1ns/1ps \
     -f filelist.f

# Xcelium 仿真
xrun -64bit -sv -uvm \
     +UVM_TESTNAME=my_test \
     +UVM_VERBOSITY=UVM_HIGH \
     -input probe.tcl
```

### Questa 仿真

```bash
# Questa 编译
vlib work
vlog -sv -f filelist.f

# Questa 仿真
vsim -c work.tb_top \
     +UVM_TESTNAME=my_test \
     +UVM_VERBOSITY=UVM_HIGH \
     -do "run -all"
```

---

## 测试用例

### 测试用例结构

```systemverilog
// 基本测试用例
class my_test extends uvm_test;
    `uvm_component_utils(my_test)

    my_env env;
    my_config cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 创建配置
        cfg = my_config::type_id::create("cfg");
        cfg.num_transactions = 1000;
        uvm_config_db #(my_config)::set(this, "*", "cfg", cfg);

        // 创建环境
        env = my_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_sequence seq;

        phase.raise_objection(this);

        // 启动序列
        seq = my_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask

endclass
```

### 测试用例类型

```systemverilog
// 定向测试
class directed_test extends my_test;
    `uvm_component_utils(directed_test)

    virtual task run_phase(uvm_phase phase);
        directed_sequence seq;

        phase.raise_objection(this);

        seq = directed_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass

// 随机测试
class random_test extends my_test;
    `uvm_component_utils(random_test)

    virtual task run_phase(uvm_phase phase);
        random_sequence seq;

        phase.raise_objection(this);

        seq = random_sequence::type_id::create("seq");
        seq.num_items = 10000;
        seq.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass

// 回归测试
class regression_test extends my_test;
    `uvm_component_utils(regression_test)

    virtual task run_phase(uvm_phase phase);
        my_sequence seq;

        phase.raise_objection(this);

        // 运行多个测试
        repeat (100) begin
            seq = my_sequence::type_id::create("seq");
            seq.start(env.agent.sequencer);
        end

        phase.drop_objection(this);
    endtask
endclass
```

---

## 波形分析

### 波形生成

```systemverilog
// FSDB 波形（Synopsys）
initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, tb_top);
end

// VCD 波形
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_top);
end

// SHM 波形（Cadence）
initial begin
    $shm_open("wave.shm");
    $shm_probe(tb_top, "AC");
end

// WLF 波形（Siemens）
initial begin
    $wlfdumpvars(0, tb_top);
end
```

### 波形查看

```tcl
# Verdi 打开波形
verdi -ssf wave.fsdb -ssf2st

# SimVision 打开波形
simvision wave.shm

# Visualizer 打开波形
visualizer wave.wlf
```

### 波形调试

```
波形调试流程：
1. 定位问题时间点
   - 查看错误消息时间戳
   - 搜索特定信号跳变

2. 分析信号行为
   - 检查时钟和复位
   - 验证数据通路
   - 确认控制信号

3. 追踪问题根源
   - 向前追踪：从错误点向前找原因
   - 向后追踪：从激励向后找影响

4. 验证修复
   - 确认信号行为正确
   - 检查时序关系
```

---

## 调试技术

### 消息调试

```systemverilog
// 消息级别
`uvm_info("TAG", "Information message", UVM_LOW)
`uvm_warning("TAG", "Warning message")
`uvm_error("TAG", "Error message")
`uvm_fatal("TAG", "Fatal message")

// 条件消息
if (debug_en)
    `uvm_info("DEBUG", $sformatf("Value: %0d", data), UVM_HIGH)

// 消息过滤
initial begin
    uvm_top.set_report_verbosity_level(UVM_HIGH);
    uvm_top.set_report_id_action("DEBUG", UVM_NO_ACTION);
end
```

### 断点调试

```systemverilog
// SystemVerilog 断点
always @(posedge clk) begin
    if (data == 8'hFF)
        $stop;  // 触发断点
end

// UVM 断点
class my_test extends uvm_test;
    virtual task run_phase(uvm_phase phase);
        // 在特定条件下停止
        wait (env.agent.driver.tx_count == 100);
        `uvm_info("TEST", "Reached 100 transactions, stopping", UVM_LOW)
        $stop;
    endtask
endclass
```

### 日志分析

```systemverilog
// 日志文件
initial begin
    // 重定向日志
    $fopen("test.log", "w");
    $fwrite("Test started at %0t\n", $time);
end

// 日志解析
// 搜索错误消息
// grep "UVM_ERROR" test.log
// grep "UVM_FATAL" test.log
```

---

## 仿真控制

### 命令行参数

```bash
# UVM 参数
+UVM_TESTNAME=my_test      # 测试名称
+UVM_VERBOSITY=UVM_HIGH    # 消息级别
+UVM_TIMEOUT=1000000       # 超时时间

# 随机种子
+ntb_random_seed=12345     # 指定种子
+ntb_random_seed=0         # 随机种子

# 波形控制
+fsdb+dumpfile=wave.fsdb   # FSDB 文件
+vcd+dumpfile=wave.vcd     # VCD 文件
```

### 仿真脚本

```bash
#!/bin/bash
# run_test.sh

TEST_NAME=$1
SEED=$2
VERBOSITY=${3:-UVM_MEDIUM}

# 编译
vcs -full64 -sverilog -debug_access+all \
    -timescale=1ns/1ps \
    -f filelist.f \
    -o simv

# 运行仿真
./simv +UVM_TESTNAME=$TEST_NAME \
       +UVM_VERBOSITY=$VERBOSITY \
       +ntb_random_seed=$SEED \
       +fsdb+dumpfile=wave.fsdb \
       | tee test.log

# 检查结果
if grep -q "UVM_FATAL" test.log; then
    echo "TEST FAILED"
    exit 1
elif grep -q "UVM_ERROR" test.log; then
    echo "TEST PASSED WITH ERRORS"
    exit 0
else
    echo "TEST PASSED"
    exit 0
fi
```

---

## 门级仿真

### 门级仿真流程

```
门级仿真流程：
┌─────────────────────────────────────────────┐
│  RTL 综合                                    │
│  ┌─────────────────────────────────────┐    │
│  │  RTL → 门级网表                      │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  时序分析 (STA)                      │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  生成 SDF 文件                       │    │
│  └─────────────────────────────────────┘    │
│                     │                       │
│                     ▼                       │
│  ┌─────────────────────────────────────┐    │
│  │  门级仿真                            │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### 门级仿真脚本

```bash
# VCS 门级仿真
vcs -full64 -sverilog -debug_access+all \
    -timescale=1ns/1ps \
    +neg_tchk \
    +sdfverbose \
    -f gate_filelist.f \
    -o simv_gate

./simv_gate +UVM_TESTNAME=my_test \
            +sdf_max=typical.sdf \
            +fsdb+dumpfile=wave_gate.fsdb
```

### 门级调试

```systemverilog
// 门级仿真检查
class gate_test extends my_test;
    `uvm_component_utils(gate_test)

    virtual task run_phase(uvm_phase phase);
        // 运行基本测试
        super.run_phase(phase);

        // 检查时序
        check_timing();
    endtask

    virtual function void check_timing();
        // 检查建立时间
        // 检查保持时间
        // 检查时钟偏斜
    endfunction
endclass
```

---

## 仿真性能

### 性能优化

```
仿真性能优化：
1. 编译优化
   - 使用增量编译
   - 优化编译选项
   - 并行编译

2. 运行时优化
   - 减少波形转储
   - 优化消息输出
   - 使用快速仿真模式

3. 测试优化
   - 减少不必要的事务
   - 使用约束随机
   - 优化序列生成
```

### 性能监控

```systemverilog
// 性能计数器
class my_env extends uvm_env;
    int tx_count;
    real start_time;
    real end_time;

    virtual task run_phase(uvm_phase phase);
        start_time = $realtime;

        // 监控事务
        forever begin
            @(posedge agent.monitor.item_collected_port);
            tx_count++;
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        end_time = $realtime;
        `uvm_info("PERF", $sformatf("Transactions: %0d, Time: %0f ns", tx_count, end_time - start_time), UVM_LOW)
    endfunction
endclass
```

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | Synopsys VCS User Guide | VCS 仿真工具 |
| REF-002 | Cadence Xcelium User Guide | Xcelium 仿真工具 |
| REF-003 | Siemens Questa User Guide | Questa 仿真工具 |
| REF-004 | UVM User Guide | UVM 框架 |
