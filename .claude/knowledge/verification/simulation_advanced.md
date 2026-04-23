# 仿真高级

> **用途**：仿真性能优化、加速技术、混合仿真参考
> **典型应用**：大规模 SoC 仿真、性能验证、系统级验证

---

## 概述

本节介绍仿真高级技术，包括性能优化、硬件加速、混合仿真等。

---

## 仿真性能优化

### 编译优化

```bash
# VCS 编译优化
vcs -full64 -sverilog \
    -debug_access+all \
    -timescale=1ns/1ps \
    -Mupdate \                    # 增量编译
    -j8 \                         # 并行编译
    -o simv

# Xcelium 编译优化
xrun -64bit -sv \
     -uvm \
     -access +rwc \
     -timescale 1ns/1ps \
     -elaborate \                 # 分离编译和细化
     -xmlibdirname ./xcelium.d

# Questa 编译优化
vlib work
vopt +acc work.tb_top -o tb_top_opt
```

### 运行时优化

```bash
# VCS 运行时优化
./simv +UVM_TESTNAME=my_test \
       +UVM_VERBOSITY=UVM_LOW \          # 降低消息级别
       +notimingcheck \                   # 禁用时序检查
       +nospecify \                       # 禁用 specify 块
       +fsdb+dumpfile=wave.fsdb \         # 限制波形
       +fsdb+dumpoff                      # 延迟波形转储

# Xcelium 运行时优化
xrun -64bit -sv -uvm \
     +UVM_TESTNAME=my_test \
     +UVM_VERBOSITY=UVM_LOW \
     -input probe.tcl

# Questa 运行时优化
vsim -c work.tb_top_opt \
     +UVM_TESTNAME=my_test \
     +UVM_VERBOSITY=UVM_LOW \
     -do "run -all"
```

### 测试优化

```systemverilog
// 优化序列生成
class optimized_sequence extends uvm_sequence #(my_transaction);
    `uvm_object_utils(optimized_sequence)

    virtual task body();
        my_transaction tx;

        // 批量生成事务
        repeat (1000) begin
            tx = my_transaction::type_id::create("tx");

            // 使用约束随机而非完全随机
            assert(tx.randomize() with {
                tx.data inside {[0:255]};
                tx.valid dist {0 := 1, 1 := 9};
            });

            start_item(tx);
            finish_item(tx);
        end
    endtask
endclass

// 优化检查
class optimized_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(optimized_scoreboard)

    // 使用队列而非数组
    my_transaction expected_queue[$];

    virtual function void write(my_transaction tx);
        // 快速比较
        if (expected_queue.size() > 0) begin
            my_transaction expected = expected_queue.pop_front();
            if (tx.data != expected.data)
                `uvm_error("SCOREBOARD", "Data mismatch")
        end
    endfunction
endclass
```

---

## 硬件加速

### 硬件加速器

```
硬件加速器类型：
┌─────────────────────────────────────────────┐
│  FPGA 原型                                  │
│  - 速度快（10-100 MHz）                     │
│  - 可调试性有限                             │
│  - 适合系统验证                             │
├─────────────────────────────────────────────┤
│  硬件仿真器                                │
│  - 速度快（1-10 MHz）                       │
│  - 可调试性好                               │
│  - 适合功能验证                             │
├─────────────────────────────────────────────┤
│  加速器                                    │
│  - 速度中（0.1-1 MHz）                      │
│  - 可调试性最好                             │
│  - 适合复杂验证                             │
└─────────────────────────────────────────────┘
```

### FPGA 原型

```tcl
# Synopsys HAPS
haps_compile -f filelist.f
haps_load design.bin
haps_run

# Cadence Protium
protium_compile -f filelist.f
protium_load design.bin
protium_run

# Siemens Veloce
veloce_compile -f filelist.f
veloce_load design.bin
veloce_run
```

### 硬件仿真

```tcl
# Synopsys ZeBu
zebu_compile -f filelist.f
zebu_load design.bin
zebu_run

# Cadence Palladium
palladium_compile -f filelist.f
palladium_load design.bin
palladium_run

# Siemens Veloce
veloce_compile -f filelist.f
veloce_load design.bin
veloce_run
```

---

## 混合仿真

### RTL/门级混合

```systemverilog
// 混合仿真配置
module tb_top;
    // RTL 模块
    rtl_module u_rtl (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out_rtl)
    );

    // 门级模块
    gate_module u_gate (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out_gate)
    );

    // 比较输出
    always @(posedge clk) begin
        if (data_out_rtl !== data_out_gate)
            $error("Output mismatch: RTL=%h, Gate=%h", data_out_rtl, data_out_gate);
    end
endmodule
```

### 软硬件协同仿真

```systemverilog
// 软硬件协同仿真
module tb_top;
    // 硬件模型
    dut u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out)
    );

    // 软件模型
    sw_model u_sw (
        .data_in(data_out),
        .data_out(data_in)
    );

    // 接口
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        #100 rst_n = 1;

        // 运行测试
        run_test();
    end
endmodule
```

---

## 性能分析

### 性能指标

```
仿真性能指标：
1. 仿真速度
   - 事务/秒
   - 周期/秒
   - 指令/秒

2. 资源使用
   - CPU 使用率
   - 内存使用量
   - 磁盘 I/O

3. 覆盖率
   - 代码覆盖率
   - 功能覆盖率
   - 断言覆盖率
```

### 性能监控

```systemverilog
// 性能监控器
class perf_monitor extends uvm_monitor;
    `uvm_component_utils(perf_monitor)

    int tx_count;
    real start_time;
    real end_time;
    real throughput;

    virtual task run_phase(uvm_phase phase);
        start_time = $realtime;

        forever begin
            @(posedge vif.clk);
            if (vif.valid && vif.ready) begin
                tx_count++;
            end
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        end_time = $realtime;
        throughput = tx_count / (end_time - start_time) * 1e9;

        `uvm_info("PERF", $sformatf("Transactions: %0d", tx_count), UVM_LOW)
        `uvm_info("PERF", $sformatf("Time: %0f ns", end_time - start_time), UVM_LOW)
        `uvm_info("PERF", $sformatf("Throughput: %0f tx/sec", throughput), UVM_LOW)
    endfunction
endclass
```

### 性能瓶颈分析

```
性能瓶颈分析：
1. CPU 瓶颈
   - 减少复杂计算
   - 优化算法
   - 使用硬件加速

2. 内存瓶颈
   - 减少数据复制
   - 使用引用
   - 优化数据结构

3. I/O 瓶颈
   - 减少波形转储
   - 使用压缩格式
   - 优化文件 I/O
```

---

## 高级调试

### 断言调试

```systemverilog
// 高级断言
module advanced_sva;
    logic clk, rst_n, valid, ready, data;

    // 复杂断言
    property p_handshake;
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |-> (##[1:10] ready);
    endproperty

    property p_data_integrity;
        @(posedge clk) disable iff (!rst_n)
        (valid && ready) |-> (data inside {[0:255]});
    endproperty

    // 覆盖
    cover property (p_handshake);
    cover property (p_data_integrity);

endmodule
```

### 形式验证辅助

```systemverilog
// 形式验证属性
module formal_properties;
    logic clk, rst_n, req, gnt, data;

    // 请求-授权属性
    property p_req_gnt;
        @(posedge clk) disable iff (!rst_n)
        req |-> ##[1:5] gnt;
    endproperty

    // 数据稳定性
    property p_data_stable;
        @(posedge clk) disable iff (!rst_n)
        (req && !gnt) |=> $stable(data);
    endproperty

    // 假设
    assume property (p_req_gnt);
    assume property (p_data_stable);

    // 断言
    assert property (p_req_gnt);
    assert property (p_data_stable);

endmodule
```

### 调试自动化

```tcl
# 调试脚本
#!/bin/bash

# 自动化调试流程
run_debug() {
    TEST=$1
    SEED=$2

    # 运行测试
    ./simv +UVM_TESTNAME=$TEST \
           +ntb_random_seed=$SEED \
           +fsdb+dumpfile=wave.fsdb

    # 检查错误
    if grep -q "UVM_ERROR" test.log; then
        echo "Errors found, launching Verdi..."
        verdi -ssf wave.fsdb &
    fi
}

# 运行调试
run_debug my_test 12345
```

---

## 仿真环境管理

### 配置管理

```systemverilog
// 配置类
class my_config extends uvm_object;
    `uvm_object_utils(my_config)

    // 仿真配置
    int num_transactions = 1000;
    bit enable_coverage = 1;
    bit enable_checks = 1;
    bit enable_logging = 1;

    // 接口配置
    virtual my_interface vif;

    function new(string name = "my_config");
        super.new(name);
    endfunction

    // 配置验证
    virtual function void check_config();
        if (num_transactions <= 0)
            `uvm_error("CONFIG", "num_transactions must be positive")
        if (!vif)
            `uvm_error("CONFIG", "Virtual interface not set")
    endfunction

endclass

// 配置使用
class my_test extends uvm_test;
    my_config cfg;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        cfg = my_config::type_id::create("cfg");
        cfg.num_transactions = 10000;
        cfg.enable_coverage = 1;

        uvm_config_db #(my_config)::set(this, "*", "cfg", cfg);
        cfg.check_config();
    endfunction
endclass
```

### 环境复用

```systemverilog
// 可复用环境
class base_env extends uvm_env;
    `uvm_component_utils(base_env)

    my_agent agent;
    my_scoreboard scoreboard;
    my_coverage coverage;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = my_agent::type_id::create("agent", this);
        scoreboard = my_scoreboard::type_id::create("scoreboard", this);
        coverage = my_coverage::type_id::create("coverage", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        agent.monitor.item_collected_port.connect(scoreboard.item_export);
        agent.monitor.item_collected_port.connect(coverage.analysis_export);
    endfunction

endclass

// 扩展环境
class extended_env extends base_env;
    `uvm_component_utils(extended_env)

    my_sub_agent sub_agent;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sub_agent = my_sub_agent::type_id::create("sub_agent", this);
    endfunction

endclass
```

---

## 回归测试

### 回归测试管理

```bash
#!/bin/bash
# regression.sh

# 测试列表
TESTS=(
    "directed_test"
    "random_test"
    "boundary_test"
    "error_test"
)

# 种子列表
SEEDS=(12345 23456 34567 45678 56789)

# 运行回归
run_regression() {
    for test in "${TESTS[@]}"; do
        for seed in "${SEEDS[@]}"; do
            echo "Running $test with seed $seed..."
            ./simv +UVM_TESTNAME=$test \
                   +ntb_random_seed=$seed \
                   | tee logs/${test}_${seed}.log
        done
    done
}

# 检查结果
check_results() {
    FAIL=0
    for log in logs/*.log; do
        if grep -q "UVM_FATAL" $log; then
            echo "FATAL: $log"
            FAIL=$((FAIL+1))
        fi
    done
    return $FAIL
}

# 主流程
mkdir -p logs
run_regression
check_results
if [ $? -eq 0 ]; then
    echo "Regression PASSED"
else
    echo "Regression FAILED"
fi
```

### 覆盖率驱动回归

```systemverilog
// 覆盖率驱动回归
class coverage_driven_test extends uvm_test;
    `uvm_component_utils(coverage_driven_test)

    my_env env;

    virtual task run_phase(uvm_phase phase);
        my_sequence seq;
        real coverage;

        phase.raise_objection(this);

        // 运行直到覆盖率满足
        forever begin
            seq = my_sequence::type_id::create("seq");
            seq.start(env.agent.sequencer);

            // 检查覆盖率
            coverage = env.coverage.cg_transaction.get_coverage();
            if (coverage >= 95.0) begin
                `uvm_info("TEST", $sformatf("Coverage reached: %0f%%", coverage), UVM_LOW)
                break;
            end
        end

        phase.drop_objection(this);
    endtask

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
| REF-005 | Synopsys ZeBu User Guide | 硬件仿真器 |
| REF-006 | Cadence Palladium User Guide | 硬件仿真器 |
