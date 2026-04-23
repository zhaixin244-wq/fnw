# UVM 高级特性

> **用途**：UVM 高级特性和最佳实践参考，供复杂验证环境开发时检索
> **典型应用**：复杂 SoC 验证、多协议验证、性能验证

---

## 概述

本节介绍 UVM 的高级特性，包括寄存器模型、高级序列、回调机制、工厂高级用法等。

---

## UVM 寄存器模型

### 寄存器模型架构

```
UVM 寄存器模型：
┌─────────────────────────────────────────────┐
│  uvm_reg_block                              │
│  ┌─────────────────────────────────────┐    │
│  │  uvm_reg_map                        │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  uvm_reg (寄存器)           │    │    │
│  │  │  ┌─────────────────────┐    │    │    │
│  │  │  │  uvm_reg_field      │    │    │    │
│  │  │  └─────────────────────┘    │    │    │
│  │  └─────────────────────────────┘    │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  uvm_adapter (适配器)               │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  uvm_predictor (预测器)             │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### 寄存器定义

```systemverilog
// 寄存器字段定义
class ctrl_reg extends uvm_reg;
    `uvm_object_utils(ctrl_reg)

    rand uvm_reg_field enable;
    rand uvm_reg_field mode;
    rand uvm_reg_field priority;

    virtual function void build();
        enable = uvm_reg_field::type_id::create("enable");
        mode = uvm_reg_field::type_id::create("mode");
        priority = uvm_reg_field::type_id::create("priority");

        enable.configure(this, 1, 0, "RW", 0, 1'h0, 1, 1, 1);
        mode.configure(this, 2, 1, "RW", 0, 2'h0, 1, 1, 1);
        priority.configure(this, 3, 3, "RW", 0, 3'h0, 1, 1, 1);
    endfunction

    function new(string name = "ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

endclass

// 状态寄存器（只读）
class status_reg extends uvm_reg;
    `uvm_object_utils(status_reg)

    uvm_reg_field busy;
    uvm_reg_field error;
    uvm_reg_field count;

    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        error = uvm_reg_field::type_id::create("error");
        count = uvm_reg_field::type_id::create("count");

        busy.configure(this, 1, 0, "RO", 0, 1'h0, 1, 0, 1);
        error.configure(this, 1, 1, "RO", 0, 1'h0, 1, 0, 1);
        count.configure(this, 8, 8, "RO", 0, 8'h0, 1, 0, 1);
    endfunction

    function new(string name = "status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

endclass
```

### 寄存器块

```systemverilog
// 寄存器块定义
class my_reg_block extends uvm_reg_block;
    `uvm_object_utils(my_reg_block)

    rand ctrl_reg ctrl;
    rand status_reg status;

    function new(string name = "my_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        ctrl = ctrl_reg::type_id::create("ctrl");
        ctrl.build();
        ctrl.configure(this, null, "ctrl");

        status = status_reg::type_id::create("status");
        status.build();
        status.configure(this, null, "status");

        // 创建地址映射
        default_map = create_map("default_map", 0, 4, UVM_BIG_ENDIAN);
        default_map.add_reg(ctrl, 32'h0000_0000, "RW");
        default_map.add_reg(status, 32'h0000_0004, "RO");

        lock_model();
    endfunction

endclass
```

### 寄存器适配器

```systemverilog
// 总线适配器
class my_adapter extends uvm_reg_adapter;
    `uvm_object_utils(my_adapter)

    function new(string name = "my_adapter");
        super.new(name);
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        my_transaction tx;

        tx = my_transaction::type_id::create("tx");
        tx.addr = rw.addr;
        tx.data = rw.data;
        tx.write = (rw.kind == UVM_WRITE);

        return tx;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        my_transaction tx;

        if (!$cast(tx, bus_item))
            `uvm_fatal("ADAPTER", "Failed to cast bus item")

        rw.addr = tx.addr;
        rw.data = tx.data;
        rw.kind = tx.write ? UVM_WRITE : UVM_READ;
        rw.status = (tx.error) ? UVM_NOT_OK : UVM_IS_OK;
    endfunction

endclass
```

### 寄存器预测

```systemverilog
// 显式预测
class my_env extends uvm_env;
    my_reg_block reg_model;
    my_adapter adapter;
    uvm_reg_predictor #(my_transaction) predictor;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        reg_model = my_reg_block::type_id::create("reg_model");
        reg_model.build();

        adapter = my_adapter::type_id::create("adapter");

        predictor = uvm_reg_predictor #(my_transaction)::type_id::create("predictor", this);
        predictor.map = reg_model.default_map;
        predictor.adapter = adapter;
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // 连接预测器
        agent.monitor.item_collected_port.connect(predictor.bus_in);

        // 设置寄存器模型的默认映射
        reg_model.default_map.set_sequencer(agent.sequencer, adapter);
    endfunction

endclass
```

---

## UVM 高级序列

### 序列库

```systemverilog
// 序列库
class my_sequence_library extends uvm_sequence_library #(my_transaction);
    `uvm_object_utils(my_sequence_library)

    function new(string name = "my_sequence_library");
        super.new(name);
        init_sequence_library();
    endfunction

    virtual function void init_sequence_library();
        add_sequence(simple_sequence::get_type());
        add_sequence(random_sequence::get_type());
        add_sequence(directed_sequence::get_type());
    endfunction

endclass

// 序列配置
class my_test extends uvm_test;
    virtual task run_phase(uvm_phase phase);
        my_sequence_library seq_lib;

        phase.raise_objection(this);

        seq_lib = my_sequence_library::type_id::create("seq_lib");
        seq_lib.selection_mode = UVM_SEQ_LIB_RANDC;
        seq_lib.min_random_count = 10;
        seq_lib.max_random_count = 20;
        seq_lib.start(env.agent.sequencer);

        phase.drop_objection(this);
    endtask
endclass
```

### 虚拟序列

```systemverilog
// 虚拟序列
class my_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(my_virtual_sequence)

    my_sequencer seqr_a;
    my_sequencer seqr_b;

    task body();
        simple_sequence seq_a, seq_b;

        // 并行启动序列
        fork
            begin
                seq_a = simple_sequence::type_id::create("seq_a");
                seq_a.start(seqr_a);
            end
            begin
                seq_b = simple_sequence::type_id::create("seq_b");
                seq_b.start(seqr_b);
            end
        join
    endtask

endclass

// 虚拟序列器
class my_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(my_virtual_sequencer)

    my_sequencer seqr_a;
    my_sequencer seqr_b;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
```

### 序列仲裁

```systemverilog
// 序列仲裁配置
class my_sequencer extends uvm_sequencer #(my_transaction);
    `uvm_component_utils(my_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // 设置仲裁模式
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        set_arbitration(SEQ_ARB_STRICT_FIFO);
    endfunction

endclass

// 优先级序列
class high_priority_sequence extends uvm_sequence #(my_transaction);
    `uvm_object_utils(high_priority_sequence)

    virtual task body();
        my_transaction tx;

        // 设置高优先级
        set_priority(100);

        repeat (10) begin
            tx = my_transaction::type_id::create("tx");
            start_item(tx);
            assert(tx.randomize());
            finish_item(tx);
        end
    endtask

endclass
```

---

## UVM 回调

### 回调基类

```systemverilog
// 回调基类
class my_driver_callback extends uvm_callback;
    `uvm_object_utils(my_driver_callback)

    function new(string name = "my_driver_callback");
        super.new(name);
    endfunction

    // 预驱动回调
    virtual task pre_drive(my_transaction tx);
        // 默认无操作
    endtask

    // 后驱动回调
    virtual task post_drive(my_transaction tx);
        // 默认无操作
    endtask

endclass

// 回调实现
class my_error_callback extends my_driver_callback;
    `uvm_object_utils(my_error_callback)

    function new(string name = "my_error_callback");
        super.new(name);
    endfunction

    virtual task pre_drive(my_transaction tx);
        // 注入错误
        if ($urandom_range(0, 99) < 10) begin
            tx.data = ~tx.data;
            `uvm_info("CALLBACK", "Error injected", UVM_MEDIUM)
        end
    endtask

endclass

// 驱动器中使用回调
class my_driver extends uvm_driver #(my_transaction);
    `uvm_component_utils(my_driver)
    `uvm_register_cb(my_driver, my_driver_callback)

    virtual task drive(my_transaction tx);
        `uvm_do_callbacks(my_driver, my_driver_callback, pre_drive(tx))

        // 正常驱动逻辑
        @(posedge vif.clk);
        vif.data <= tx.data;
        vif.valid <= 1'b1;

        `uvm_do_callbacks(my_driver, my_driver_callback, post_drive(tx))
    endtask

endclass

// 测试中注册回调
class my_test extends uvm_test;
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 注册错误注入回调
        uvm_callbacks #(my_driver, my_driver_callback)::add(
            env.agent.driver,
            my_error_callback::type_id::create("error_cb")
        );
    endfunction
endclass
```

---

## UVM 工厂高级用法

### 类型覆盖

```systemverilog
// 类型覆盖
class my_test extends uvm_test;
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 全局类型覆盖
        set_type_override_by_type(
            my_transaction::get_type(),
            my_transaction_ext::get_type()
        );

        // 实例覆盖
        set_inst_override_by_type(
            "env.agent.driver",
            my_driver::get_type(),
            my_driver_ext::get_type()
        );
    endfunction
endclass
```

### 参数化覆盖

```systemverilog
// 参数化类
class my_driver #(parameter DATA_WIDTH = 8) extends uvm_driver #(my_transaction);
    `uvm_component_utils(my_driver #(DATA_WIDTH))

    // 参数化实现
    virtual task drive(my_transaction tx);
        @(posedge vif.clk);
        vif.data[DATA_WIDTH-1:0] <= tx.data[DATA_WIDTH-1:0];
        vif.valid <= 1'b1;
    endtask

endclass

// 工厂创建参数化类
class my_env extends uvm_env;
    my_driver #(16) driver_16;
    my_driver #(32) driver_32;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        driver_16 = my_driver #(16)::type_id::create("driver_16", this);
        driver_32 = my_driver #(32)::type_id::create("driver_32", this);
    endfunction
endclass
```

---

## UVM TLM 高级

### TLM 2.0

```systemverilog
// TLM 2.0 接口
class my_target extends uvm_component;
    `uvm_component_utils(my_target)

    uvm_tlm_b_target_socket #(my_target, my_transaction) target_socket;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        target_socket = new("target_socket", this);
    endfunction

    virtual task b_transport(my_transaction tx, uvm_tlm_time delay);
        // 处理事务
        `uvm_info("TARGET", $sformatf("Received: %s", tx.convert2string()), UVM_MEDIUM)
        delay.increase(10ns);
    endtask

endclass

// TLM 2.0 发起端
class my_initiator extends uvm_component;
    `uvm_component_utils(my_initiator)

    uvm_tlm_b_initiator_socket #(my_transaction) initiator_socket;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        initiator_socket = new("initiator_socket", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_transaction tx;
        uvm_tlm_time delay;

        tx = my_transaction::type_id::create("tx");
        delay = new("delay", 1e-9, 0);

        initiator_socket.b_transport(tx, delay);
    endtask

endclass
```

### Analysis Port 高级

```systemverilog
// 多端口分析
class my_monitor extends uvm_monitor;
    `uvm_component_utils(my_monitor)

    uvm_analysis_port #(my_transaction) item_port;
    uvm_analysis_port #(my_transaction) error_port;
    uvm_analysis_port #(my_transaction) coverage_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_port = new("item_port", this);
        error_port = new("error_port", this);
        coverage_port = new("coverage_port", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_transaction tx;

        forever begin
            @(posedge vif.clk);
            if (vif.valid && vif.ready) begin
                tx = my_transaction::type_id::create("tx");
                tx.data = vif.data;

                // 发送到不同端口
                item_port.write(tx);
                coverage_port.write(tx);

                if (tx.error)
                    error_port.write(tx);
            end
        end
    endtask

endclass
```

---

## UVM 覆盖率

### 功能覆盖率

```systemverilog
// 功能覆盖率
class my_coverage extends uvm_subscriber #(my_transaction);
    `uvm_component_utils(my_coverage)

    my_transaction tx;

    // 覆盖组
    covergroup cg_transaction;
        data: coverpoint tx.data {
            bins zero = {0};
            bins max = {8'hFF};
            bins others = {[1:8'hFE]};
        }
        valid: coverpoint tx.valid;
        ready: coverpoint tx.ready;

        cross_data_valid: cross data, valid;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_transaction = new();
    endfunction

    virtual function void write(my_transaction t);
        tx = t;
        cg_transaction.sample();
    endfunction

endclass
```

### 断言覆盖率

```systemverilog
// SVA 断言覆盖率
module my_sva;
    logic clk, rst_n, valid, ready, data;

    // 断言
    property p_valid_stable;
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> valid;
    endproperty

    property p_data_stable;
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> $stable(data);
    endproperty

    // 覆盖
    cover property (p_valid_stable);
    cover property (p_data_stable);

endmodule
```

---

## UVM 最佳实践

### 验证环境架构

```
推荐验证环境架构：
┌─────────────────────────────────────────────┐
│  uvm_test                                   │
│  ┌─────────────────────────────────────┐    │
│  │  uvm_env                            │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  Virtual Sequencer          │    │    │
│  │  └─────────────────────────────┘    │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  Agent (Active)             │    │    │
│  │  │  - Sequencer                │    │    │
│  │  │  - Driver                   │    │    │
│  │  │  - Monitor                  │    │    │
│  │  └─────────────────────────────┘    │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  Agent (Passive)            │    │    │
│  │  │  - Monitor                  │    │    │
│  │  └─────────────────────────────┘    │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  Scoreboard                 │    │    │
│  │  └─────────────────────────────┘    │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  Coverage                   │    │    │
│  │  └─────────────────────────────┘    │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  Reg Model                  │    │    │
│  │  └─────────────────────────────┘    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### 编码最佳实践

```systemverilog
// 1. 使用宏简化代码
`uvm_info("TAG", "Message", UVM_MEDIUM)
`uvm_error("TAG", "Error message")
`uvm_fatal("TAG", "Fatal message")

// 2. 使用 config_db 管理配置
class my_config extends uvm_object;
    `uvm_object_utils(my_config)

    bit enable_coverage = 1;
    bit enable_checks = 1;
    int num_transactions = 1000;

    function new(string name = "my_config");
        super.new(name);
    endfunction
endclass

// 3. 使用 factory 创建对象
my_transaction tx = my_transaction::type_id::create("tx");

// 4. 使用 objection 控制仿真结束
phase.raise_objection(this);
// ... 测试逻辑 ...
phase.drop_objection(this);

// 5. 使用 sequence 管理激励
class my_sequence extends uvm_sequence #(my_transaction);
    `uvm_object_utils(my_sequence)

    virtual task body();
        my_transaction tx;

        repeat (100) begin
            tx = my_transaction::type_id::create("tx");
            start_item(tx);
            assert(tx.randomize() with {
                tx.data inside {[0:255]};
                tx.valid dist {0 := 1, 1 := 9};
            });
            finish_item(tx);
        end
    endtask
endclass
```

### 性能优化

```systemverilog
// 1. 使用 uvm_config_db 避免重复创建
class my_env extends uvm_env;
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 一次性配置
        uvm_config_db #(virtual my_interface)::set(this, "agent.driver", "vif", vif);
        uvm_config_db #(virtual my_interface)::set(this, "agent.monitor", "vif", vif);
    endfunction
endclass

// 2. 使用 analysis_imp 替代 analysis_port
class my_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_scoreboard)

    uvm_analysis_imp #(my_transaction, my_scoreboard) item_export;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction

    // 直接实现 write 方法
    virtual function void write(my_transaction tx);
        // 处理事务
    endfunction
endclass

// 3. 使用 do_not_copy 避免不必要的复制
class my_transaction extends uvm_sequence_item;
    `uvm_object_utils(my_transaction)

    // 大数据使用引用
    byte data[];

    virtual function void do_copy(uvm_object rhs);
        my_transaction rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        data = rhs_.data;  // 浅复制
    endfunction
endclass
```

---

## 调试技巧

### 消息控制

```systemverilog
// 消息严重级别
`uvm_info("TAG", "Information", UVM_LOW)
`uvm_warning("TAG", "Warning")
`uvm_error("TAG", "Error")
`uvm_fatal("TAG", "Fatal")

// 消息过滤
initial begin
    // 设置消息级别
    uvm_top.set_report_verbosity_level(UVM_HIGH);

    // 过滤特定消息
    uvm_top.set_report_id_action("MY_ID", UVM_NO_ACTION);

    // 设置消息计数限制
    uvm_top.set_report_max_quit_count(10);
end
```

### 波形调试

```systemverilog
// 添加调试信号
class my_driver extends uvm_driver #(my_transaction);
    // 调试信号
    int tx_count;
    my_transaction last_tx;

    virtual task drive(my_transaction tx);
        tx_count++;
        last_tx = tx;

        // 记录事务
        `uvm_info("DRV", $sformatf("Transaction #%0d: %s", tx_count, tx.convert2string()), UVM_HIGH)

        // 驱动逻辑
        ...
    endtask
endclass
```

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | UVM User Guide | UVM 官方文档 |
| REF-002 | UVM Cookbook | UVM 最佳实践 |
| REF-003 | UVM Reference Guide | UVM 参考手册 |
| REF-004 | Verification Academy | 验证学院资源 |
