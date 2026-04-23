# UVM 基础

> **用途**：UVM 框架基础概念参考，供验证工程师参考
> **典型应用**：所有 UVM 验证环境

---

## 概述

UVM（Universal Verification Methodology）是业界标准的验证方法学。

### UVM 优势

- **可重用性**：组件可重用
- **可扩展性**：易于扩展
- **标准化**：业界标准
- **自动化**：支持自动化验证

---

## UVM 架构

### UVM 组件层次

```
UVM 组件层次：
┌─────────────────────────────────────────────┐
│  uvm_test                                   │
│  ┌─────────────────────────────────────┐    │
│  │  uvm_env                            │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  uvm_agent                  │    │    │
│  │  │  ┌─────────────────────┐    │    │    │
│  │  │  │  uvm_sequencer      │    │    │    │
│  │  │  ├─────────────────────┤    │    │    │
│  │  │  │  uvm_driver         │    │    │    │
│  │  │  ├─────────────────────┤    │    │    │
│  │  │  │  uvm_monitor        │    │    │    │
│  │  │  └─────────────────────┘    │    │    │
│  │  └─────────────────────────────┘    │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  uvm_scoreboard            │    │    │
│  │  └─────────────────────────────┘    │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │  uvm_coverage              │    │    │
│  │  └─────────────────────────────┘    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## UVM 组件

### uvm_test

```systemverilog
// uvm_test 基类
class my_test extends uvm_test;
    `uvm_component_utils(my_test)

    my_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = my_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // 测试逻辑
    endtask

endclass
```

### uvm_env

```systemverilog
// uvm_env 基类
class my_env extends uvm_env;
    `uvm_component_utils(my_env)

    my_agent agent;
    my_scoreboard scoreboard;
    my_coverage coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = my_agent::type_id::create("agent", this);
        scoreboard = my_scoreboard::type_id::create("scoreboard", this);
        coverage = my_coverage::type_id::create("coverage", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.item_collected_port.connect(scoreboard.item_export);
        agent.monitor.item_collected_port.connect(coverage.item_export);
    endfunction

endclass
```

### uvm_agent

```systemverilog
// uvm_agent 基类
class my_agent extends uvm_agent;
    `uvm_component_utils(my_agent)

    uvm_sequencer #(my_transaction) sequencer;
    my_driver driver;
    my_monitor monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = uvm_sequencer #(my_transaction)::type_id::create("sequencer", this);
            driver = my_driver::type_id::create("driver", this);
        end
        monitor = my_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass
```

### uvm_driver

```systemverilog
// uvm_driver 基类
class my_driver extends uvm_driver #(my_transaction);
    `uvm_component_utils(my_driver)

    virtual my_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual my_interface)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not set")
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_transaction tx;

        forever begin
            seq_item_port.get_next_item(tx);
            drive(tx);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive(my_transaction tx);
        @(posedge vif.clk);
        vif.data <= tx.data;
        vif.valid <= 1'b1;
        @(posedge vif.clk);
        while (!vif.ready)
            @(posedge vif.clk);
        vif.valid <= 1'b0;
    endtask

endclass
```

### uvm_monitor

```systemverilog
// uvm_monitor 基类
class my_monitor extends uvm_monitor;
    `uvm_component_utils(my_monitor)

    virtual my_interface vif;
    uvm_analysis_port #(my_transaction) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual my_interface)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not set")
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_transaction tx;

        forever begin
            @(posedge vif.clk);
            if (vif.valid && vif.ready) begin
                tx = my_transaction::type_id::create("tx");
                tx.data = vif.data;
                item_collected_port.write(tx);
            end
        end
    endtask

endclass
```

### uvm_scoreboard

```systemverilog
// uvm_scoreboard 基类
class my_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_scoreboard)

    uvm_analysis_imp #(my_transaction, my_scoreboard) item_export;
    my_transaction expected_queue[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction

    virtual function void write(my_transaction tx);
        my_transaction expected;

        if (expected_queue.size() == 0)
            `uvm_error("SCOREBOARD", "Unexpected transaction")

        expected = expected_queue.pop_front();

        if (tx.data != expected.data)
            `uvm_error("SCOREBOARD", $sformatf("Data mismatch: expected=%h, got=%h", expected.data, tx.data))
    endfunction

    virtual task run_phase(uvm_phase phase);
        // 生成期望数据
        my_transaction expected;

        forever begin
            expected = my_transaction::type_id::create("expected");
            assert(expected.randomize());
            expected_queue.push_back(expected);
            #10;
        end
    endtask

endclass
```

---

## UVM 事务

### uvm_sequence_item

```systemverilog
// uvm_sequence_item 基类
class my_transaction extends uvm_sequence_item;
    `uvm_object_utils(my_transaction)

    rand bit [7:0] data;
    rand bit valid;
    rand bit ready;

    constraint c_valid {
        valid dist {0 := 1, 1 := 9};
    }

    function new(string name = "my_transaction");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("data=%h, valid=%b, ready=%b", data, valid, ready);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        my_transaction rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        data = rhs_.data;
        valid = rhs_.valid;
        ready = rhs_.ready;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        my_transaction rhs_;
        if (!$cast(rhs_, rhs))
            return 0;
        return (data == rhs_.data) && (valid == rhs_.valid) && (ready == rhs_.ready);
    endfunction

endclass
```

---

## UVM 序列

### uvm_sequence

```systemverilog
// uvm_sequence 基类
class my_sequence extends uvm_sequence #(my_transaction);
    `uvm_object_utils(my_sequence)

    function new(string name = "my_sequence");
        super.new(name);
    endfunction

    virtual task body();
        my_transaction tx;

        repeat (100) begin
            tx = my_transaction::type_id::create("tx");
            start_item(tx);
            assert(tx.randomize());
            finish_item(tx);
        end
    endtask

endclass
```

### uvm_sequencer

```systemverilog
// uvm_sequencer 基类
class my_sequencer extends uvm_sequencer #(my_transaction);
    `uvm_component_utils(my_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
```

---

## UVM 配置

### uvm_config_db

```systemverilog
// 设置配置
uvm_config_db #(virtual my_interface)::set(null, "uvm_test_top.env.agent.driver", "vif", vif);
uvm_config_db #(virtual my_interface)::set(null, "uvm_test_top.env.agent.monitor", "vif", vif);

// 获取配置
if (!uvm_config_db #(virtual my_interface)::get(this, "", "vif", vif))
    `uvm_fatal("NOVIF", "Virtual interface not set")
```

---

## UVM 工厂

### 工厂注册

```systemverilog
// 类注册
class my_transaction extends uvm_sequence_item;
    `uvm_object_utils(my_transaction)
    ...
endclass

class my_driver extends uvm_driver #(my_transaction);
    `uvm_component_utils(my_driver)
    ...
endclass
```

### 工厂覆盖

```systemverilog
// 类型覆盖
set_type_override_by_type(my_transaction::get_type(), my_transaction_ext::get_type());

// 实例覆盖
set_inst_override_by_type("env.agent.driver", my_driver::get_type(), my_driver_ext::get_type());
```

---

## UVM 阶段

### 阶段列表

| 阶段 | 说明 | 用途 |
|------|------|------|
| build_phase | 构建组件 | 创建组件 |
| connect_phase | 连接组件 | 连接端口 |
| end_of_elaboration_phase | 精细调整 | 调试设置 |
| start_of_simulation_phase | 仿真开始 | 初始化 |
| run_phase | 运行仿真 | 测试逻辑 |
| extract_phase | 提取数据 | 收集数据 |
| check_phase | 检查结果 | 验证正确性 |
| report_phase | 报告结果 | 生成报告 |

### 阶段执行顺序

```
build_phase → connect_phase → end_of_elaboration_phase →
start_of_simulation_phase → run_phase → extract_phase →
check_phase → report_phase
```

---

## UVM 最佳实践

### 设计原则

1. **可重用性**：组件设计为可重用
2. **可扩展性**：易于扩展新功能
3. **可配置性**：支持配置参数
4. **可调试性**：易于调试

### 编码规范

1. **命名规范**：使用有意义的名称
2. **注释规范**：添加必要的注释
3. **代码组织**：合理组织代码结构
4. **错误处理**：添加错误处理机制

### 验证策略

1. **覆盖率驱动**：基于覆盖率验证
2. **约束随机**：使用约束随机测试
3. **自动化**：提高自动化程度
4. **回归测试**：建立回归测试套件

---

## 参考文档

| 编号 | 文档 | 说明 |
|------|------|------|
| REF-001 | UVM User Guide | UVM 官方文档 |
| REF-002 | UVM Cookbook | UVM 最佳实践 |
| REF-003 | Synopsys VCS UVM Guide | VCS UVM 支持 |
| REF-004 | Cadence Xcelium UVM Guide | Xcelium UVM 支持 |
