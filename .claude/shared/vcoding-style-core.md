---
name: UVM Verification Coding Style (Core)
description: UVM-1.2 验证环境编码规范核心版。覆盖 Agent/Driver/Monitor 编码的日常必需规则。
---

# 验证环境编码规范（UVM 1.2）— 核心版

> 适用范围：所有 UVM 验证环境代码。语言：SystemVerilog（IEEE 1800-2012）+ UVM 1.2。
> 本规范与 （RTL 编码规范）互补。
>
> **高级内容**（Scoreboard、Coverage、Interface/BFM、参数化、复位、Objection、Phase、TLM、宏、报告、RAL）见 ，按需加载。

---

---
name: UVM Verification Coding Style
description: 基于 UVM-1.2 的验证环境编码规范。适用于所有 UVM 验证环境组件（agent/driver/monitor/scoreboard/sequence/coverage）。
---

# 验证环境编码规范（UVM 1.2）

> 适用范围：所有 UVM 验证环境代码。语言：SystemVerilog（IEEE 1800-2012）+ UVM 1.2。本规范与 `rules/coding-style.md`（RTL 编码规范）互补——RTL 管可综合代码，本规范管验证环境。

---

## 1. 文件组织

**文件命名**：

| 文件类型 | 命名规则 | 示例 |
|----------|----------|------|
| Package | `{module}_pkg.sv` | `data_adpt_pkg.sv` |
| Interface | `{module}_intf.sv` | `axi4_intf.sv` |
| Transaction | `{module}_seq_item.sv` | `axi4_rd_seq_item.sv` |
| Sequence | `{module}_seq.sv` | `axi4_rd_seq.sv` |
| Driver | `{module}_driver.sv` | `axi4_driver.sv` |
| Monitor | `{module}_monitor.sv` | `axi4_monitor.sv` |
| Agent | `{module}_agent.sv` | `axi4_agent.sv` |
| Scoreboard | `{module}_scoreboard.sv` | `data_adpt_scoreboard.sv` |
| Coverage | `{module}_cov.sv` | `data_adpt_cov.sv` |
| Env | `{module}_env.sv` | `data_adpt_env.sv` |
| Test | `{module}_base_test.sv` | `data_adpt_base_test.sv` |
| TB Top | `{module}_tb_top.sv` | `data_adpt_tb_top.sv` |

**一个文件一个类**。例外：极小的 helper class（<30 行）可与关联类同文件。

**文件内部顺序**（UVM 组件类）：

```
文件头注释 → import → class 声明 → 成员变量（rand/非 rand）
  → UVM 组件宏 → new() → build_phase → connect_phase
  → run_phase / main_phase → 其他 phase → task/function
  → endclass
```

**文件头**：

```systemverilog
// Class    : {class_name}
// Function : {功能描述}
// Author   : {author}
// Date     : {YYYY-MM-DD}
// Revision : v{X.Y}
```

---

## 2. 命名规范

### 2.1 类命名

| UVM 组件 | 命名规则 | 示例 |
|----------|----------|------|
| Transaction | `{if}_{type}_seq_item` | `axi4_rd_seq_item` |
| Sequence | `{if}_{scenario}_seq` | `axi4_backpressure_seq` |
| Sequencer | `{if}_sequencer` | `axi4_sequencer` |
| Driver | `{if}_driver` | `axi4_driver` |
| Monitor | `{if}_monitor` | `axi4_monitor` |
| Agent | `{if}_agent` | `axi4_agent` |
| Scoreboard | `{module}_scoreboard` | `data_adpt_scoreboard` |
| Coverage | `{module}_cov` | `data_adpt_cov` |
| Env | `{module}_env` | `data_adpt_env` |
| Config | `{if}_cfg` / `{module}_env_cfg` | `axi4_cfg` / `data_adpt_env_cfg` |
| Test | `{module}_{scenario}_test` | `data_adpt_basic_test` |
| Interface | `{if}_intf` | `axi4_intf` |

### 2.2 成员变量命名

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| UVM 组件句柄 | `{name}` | `driver`, `monitor` |
| TLM 端口 | `{name}_{port_type}` | `req_analysis_port`, `rsp_imp` |
| Config 对象 | `cfg` / `{name}_cfg` | `cfg`, `axi_cfg` |
| Virtual interface | `vif` / `{if}_vif` | `vif`, `axi_vif` |
| Sequence item | `req` / `rsp` | `req`, `rsp` |
| 事件/同步 | `{name}_evt` | `done_evt`, `reset_evt` |
| 计数器 | `{name}_cnt` | `item_cnt`, `err_cnt` |
| 标志位 | `is_{state}` / `has_{attr}` | `is_active`, `has_response` |
| 配置字段 | 小写下划线 | `data_width`, `ch_num` |

### 2.3 方法命名

| 方法类型 | 命名规则 | 示例 |
|----------|----------|------|
| Phase 方法 | `{phase}_phase` | `build_phase`, `run_phase` |
| 回调方法 | `on_{event}` | `on_reset`, `on_item_done` |
| 校验方法 | `check_{what}` | `check_data`, `check_order` |
| 转换方法 | `{from}_to_{to}` | `addr_to_region` |
| 配置方法 | `set_{what}` / `get_{what}` | `set_timeout`, `get_item` |

### 2.4 禁止

- 单字母变量（`i`/`j` 仅用于循环 genvar）
- 与 UVM 基类同名（如 `driver`、`monitor` 作为类名）
- 匈牙利命名（`m_data`、`p_port`）——UVM 内部用，用户代码不用
- `tmp`/`temp`/`aux` 等无意义名

---

## 3. UVM 组件层次

### 3.1 标准层次结构

```
{module}_tb_top                          // 顶层 TB（module）
  └── {module}_test                      // 测试（uvm_test）
        └── {module}_env                 // 环境（uvm_env）
              ├── {if}_agent             // 上游接口 Agent
              │     ├── {if}_driver
              │     ├── {if}_monitor
              │     └── {if}_sequencer
              ├── {if}_agent             // 下游接口 Agent
              │     ├── {if}_driver
              │     ├── {if}_monitor
              │     └── {if}_sequencer
              ├── {if}_agent             // 配置接口 Agent（APB 等）
              ├── {module}_scoreboard    // 记分板
              ├── {module}_cov           // 覆盖率收集器
              └── {module}_env_cfg       // 环境配置对象
```

### 3.2 Agent 模式

| 模式 | 宏值 | 用途 | Driver/Sequencer |
|------|------|------|-------------------|
| Active | `UVM_ACTIVE` | 激励驱动接口 | 创建 |
| Passive | `UVM_PASSIVE` | 仅监控接口 | 不创建 |

**规则**：
- DUT 输入接口 → Active Agent（驱动激励）
- DUT 输出接口 → Passive Agent（仅监控）
- 双向接口 → Active Agent（driver + monitor 均需）

```systemverilog
class axi4_agent extends uvm_agent;
    `uvm_component_utils_begin(axi4_agent)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
    `uvm_component_utils_end

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = axi4_monitor::type_id::create("monitor", this);
        if (is_active == UVM_ACTIVE) begin
            driver    = axi4_driver::type_id::create("driver", this);
            sequencer = axi4_sequencer::type_id::create("sequencer", this);
        end
    endfunction
endclass
```

---

## 4. 工厂（Factory）使用

### 4.1 注册规则

**所有 UVM 组件和事务必须注册工厂**：

```systemverilog
// 组件注册
class axi4_driver extends uvm_driver #(axi4_seq_item);
    `uvm_component_utils(axi4_driver)
    // ...
endclass

// 事务注册
class axi4_seq_item extends uvm_sequence_item;
    `uvm_object_utils(axi4_seq_item)
    // ...
endclass
```

### 4.2 创建规则

**禁止直接 new()，必须通过工厂创建**：

```systemverilog
// ✅ 正确
driver = axi4_driver::type_id::create("driver", this);

// ❌ 错误
driver = new("driver", this);
```

**唯一例外**：`uvm_sequence_item` 的 `new()` 在事务内部允许直接调用。

### 4.3 覆盖规则

覆盖仅在 test 层进行，禁止在 env/agent 内部覆盖：

```systemverilog
class data_adpt_stress_test extends data_adpt_base_test;
    `uvm_component_utils(data_adpt_stress_test)

    virtual function void build_phase(uvm_phase phase);
        // 覆盖 sequence 类型
        axi4_rd_seq::type_id::set_type_override(axi4_rd_stress_seq::get_type());
        super.build_phase(phase);
    endfunction
endclass
```

---

## 5. Config Database 使用

### 5.1 传递路径约定

| 数据类型 | set 路径 | get 路径 | 说明 |
|----------|----------|----------|------|
| Virtual interface | `uvm_test_top.env.{agent}` | `build_phase` 中 get | 必须在 test 层 set |
| Agent config | `uvm_test_top.env.{agent}` | `build_phase` 中 get | is_active 等 |
| Env config | `uvm_test_top.env` | `build_phase` 中 get | 全局配置 |
| Test config | `uvm_test_top` | `build_phase` 中 get | 测试级参数 |

### 5.2 Virtual Interface 传递

**TB Top → Test → Agent → Driver/Monitor**：

```systemverilog
// TB Top（module 中）
initial begin
    uvm_config_db#(virtual axi4_intf)::set(null, "uvm_test_top.env.axi_agt*", "vif", axi4_vif);
end

// Driver（build_phase 中）
if (!uvm_config_db#(virtual axi4_intf)::get(this, "", "vif", vif))
    `uvm_fatal("NOVIF", "Virtual interface not set for driver")
```

**规则**：
- `set` 仅在 TB Top 的 `initial` 块中执行
- `get` 在 `build_phase` 中执行，失败必须 `uvm_fatal`
- 路径使用通配符 `*` 时必须注释说明匹配范围

### 5.3 Config Object 传递

```systemverilog
// Test 中 set
data_adpt_env_cfg env_cfg = data_adpt_env_cfg::type_id::create("env_cfg");
env_cfg.data_width = 32;
env_cfg.ch_num     = 4;
uvm_config_db#(data_adpt_env_cfg)::set(this, "env", "env_cfg", env_cfg);

// Env 中 get
if (!uvm_config_db#(data_adpt_env_cfg)::get(this, "", "env_cfg", cfg))
    `uvm_fatal("NOCFG", "Environment config not set")
```

---

## 6. Sequence 与 Sequencer

### 6.1 Sequence 定义

```systemverilog
class axi4_rd_seq extends uvm_sequence #(axi4_seq_item);
    `uvm_object_utils(axi4_rd_seq)

    rand int unsigned num_items;
    constraint c_num { num_items inside {[1:100]}; }

    virtual task body();
        repeat (num_items) begin
            `uvm_do_with(req, {
                req.xact_type == AXI_READ;
                req.addr[31:28] == 4'h1;
            })
        end
    endtask
endclass
```

### 6.2 `uvm_do 宏族使用规则

| 宏 | 用途 | 适用场景 |
|----|------|----------|
| `uvm_do(req)` | 创建+随机化+发送 | 无约束默认随机 |
| `uvm_do_with(req, {c})` | 创建+带约束随机化+发送 | 需要特定约束 |
| `uvm_send(req)` | 直接发送已有 item | item 已手动创建 |
| `uvm_rand_send(req)` | 随机化已有 item 后发送 | item 已创建需随机 |
| `uvm_create(req)` | 仅创建不发送 | 需要多步配置后发送 |

**规则**：
- 简单场景用 `uvm_do` / `uvm_do_with`
- 复杂场景用 `uvm_create` + 手动配置 + `uvm_send`
- 禁止在 `body()` 中直接 `new` item 后绕过 sequencer 发送

### 6.3 嵌套 Sequence

```systemverilog
class axi4_full_test_seq extends uvm_sequence;
    `uvm_object_utils(axi4_full_test_seq)

    axi4_rd_seq rd_seq;
    axi4_wr_seq wr_seq;

    virtual task body();
        // 并发执行读写 sequence
        fork
            rd_seq.start(m_sequencer);
            wr_seq.start(m_sequencer);
        join
    endtask
endclass
```

### 6.4 Sequence 生命周期

**规则**：
- Sequence 通过 `start()` 启动，自动 `create` + `start` + `finish`
- 禁止手动调用 `pre_body()` / `post_body()` 以外的 phase 回调
- `kill()` 仅用于紧急停止，正常结束靠 `body()` 自然返回
- `uvm_do` 内部会自动调用 `start_item()` + `finish_item()`

---

## 7. Driver 编码

### 7.1 标准 Driver 模板

```systemverilog
class axi4_driver extends uvm_driver #(axi4_seq_item);
    `uvm_component_utils(axi4_driver)

    virtual axi4_intf vif;
    axi4_cfg cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_intf)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not set")
        if (!uvm_config_db#(axi4_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "Config not set")
    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            drive_items();
            monitor_reset();
        join
    endtask

    virtual task drive_items();
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_item(axi4_seq_item item);
        // 驱动信号到接口
        @(posedge vif.clk);
        vif.valid <= 1'b1;
        vif.data  <= item.data;
        // 等待握手
        while (!vif.ready) @(posedge vif.clk);
        vif.valid <= 1'b0;
    endtask

    virtual task monitor_reset();
        forever begin
            @(negedge vif.rst_n);
            `uvm_info("RST", "Reset asserted, clearing driver state", UVM_MEDIUM)
            reset_signals();
            @(posedge vif.rst_n);
        end
    endtask

    virtual function void reset_signals();
        vif.valid <= 1'b0;
        vif.data  <= '0;
    endfunction
endclass
```

### 7.2 Driver 规则

| # | 规则 | 说明 |
|---|------|------|
| D-01 | `get_next_item` + `item_done` 成对 | 每次 `get_next_item` 后必须有 `item_done` |
| D-02 | `item_done()` 可带 response | 读操作返回数据时通过 `item_done(rsp)` 传递 |
| D-03 | 接口信号赋值用 `<=` | 时序赋值，非阻塞 |
| D-04 | 等待用 `@(posedge clk)` | 不用 `#delay`，与时钟同步 |
| D-05 | 复位时清零所有输出信号 | `monitor_reset` 独立线程 |
| D-06 | 禁止在 driver 中做校验 | 校验在 monitor/scoreboard |
| D-07 | 禁止在 driver 中收集覆盖率 | 覆盖率在 monitor/coverage collector |

---

## 8. Monitor 编码

### 8.1 标准 Monitor 模板

```systemverilog
class axi4_monitor extends uvm_monitor;
    `uvm_component_utils(axi4_monitor)

    virtual axi4_intf vif;
    axi4_cfg cfg;

    uvm_analysis_port #(axi4_seq_item) item_ap;    // 事务级输出
    uvm_analysis_port #(axi4_seq_item) err_ap;      // 错误事务输出

    int unsigned item_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_ap = new("item_ap", this);
        err_ap  = new("err_ap", this);
        if (!uvm_config_db#(virtual axi4_intf)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not set")
    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            collect_items();
            monitor_reset();
        join
    endtask

    virtual task collect_items();
        axi4_seq_item item;
        forever begin
            @(posedge vif.clk);
            if (vif.valid && vif.ready) begin
                item = axi4_seq_item::type_id::create("item");
                item.data = vif.data;
                item.addr = vif.addr;
                item_cnt++;
                item_ap.write(item);
            end
        end
    endtask

    virtual task monitor_reset();
        forever begin
            @(negedge vif.rst_n);
            `uvm_info("RST", "Reset detected", UVM_MEDIUM)
            item_cnt = 0;
            @(posedge vif.rst_n);
        end
    endtask
endclass
```

### 8.2 Monitor 规则

| # | 规则 | 说明 |
|---|------|------|
| M-01 | 纯被动监控 | 禁止驱动任何接口信号 |
| M-02 | 通过 `analysis_port` 广播 | 不直接引用 scoreboard/coverage |
| M-03 | 复位时清零状态 | `monitor_reset` 独立线程 |
| M-04 | 采样在时钟上升沿 | `@(posedge vif.clk)` |
| M-05 | 检测用 `valid && ready` | 握手成功才采样 |
| M-06 | 错误事务单独端口 | `err_ap` 输出异常事务 |
| M-07 | 禁止在 monitor 中做校验 | 校验在 scoreboard |

---

## 19. 禁止行为清单

| # | 禁止行为 | 原因 | 替代方案 |
|---|----------|------|----------|
| X-01 | Driver 中 `#delay` | 不可控，不与时钟同步 | `@(posedge clk)` |
| X-02 | Monitor 中驱动信号 | 违反被动监控原则 | 信号驱动仅在 Driver |
| X-03 | `$display` / `$write` | 绕过 UVM 报告机制 | `uvm_info` |
| X-04 | Sequence 中 `raise_objection` | Objection 仅在 test 层 | Test 中控制 |
| X-05 | `build_phase` 中耗时操作 | 阻塞组件创建 | 移到 `run_phase` |
| X-06 | 工厂外直接 `new` 组件 | 无法覆盖 | `::type_id::create()` |
| X-07 | 硬编码路径字符串 | 路径变化时失效 | 参数化 / config_db |
| X-08 | `while(1) @(posedge clk)` | 无法被 objection 终止 | `forever @(posedge clk)` |
| X-09 | `initial` 块在 class 内 | 不可综合的 SV 特性，UVM 不支持 | Phase 任务 |
| X-10 | 全局变量 | 命名冲突、不可控 | Config object / 成员变量 |
| X-11 | `force` / `release` | 破坏信号驱动主权 | 通过接口正常驱动 |
| X-12 | `casex` / `casez` | X 传播风险 | `case` + `inside` |
| X-13 | 跨组件直接引用句柄 | 紧耦合 | TLM 端口连接 |

---

## 20. 文件结构总结

### 20.1 目录约定

```
dv/
├── env/
│   ├── {module}_pkg.sv          // Package（include 所有 class 文件）
│   ├── {if}_intf.sv             // Interface
│   ├── {if}_cfg.sv              // 接口配置
│   ├── {if}_seq_item.sv         // 事务
│   ├── {if}_seq.sv              // Sequence
│   ├── {if}_driver.sv           // Driver
│   ├── {if}_monitor.sv          // Monitor
│   ├── {if}_agent.sv            // Agent
│   ├── {module}_env_cfg.sv      // 环境配置
│   ├── {module}_scoreboard.sv   // Scoreboard
│   ├── {module}_cov.sv          // Coverage
│   ├── {module}_env.sv          // Env
│   └── plan/                    // 组件详细方案
│       └── {comp}_env_plan_v{X}.md
├── test/
│   ├── {module}_base_test.sv    // Base test
│   └── {module}_{scenario}_test.sv  // 场景 test
├── seq/
│   ├── {module}_base_seq.sv     // Base sequence
│   └── {module}_{scenario}_seq.sv  // 场景 sequence
├── tb/
│   └── {module}_tb_top.sv       // TB 顶层
├── doc/
│   ├── plan/                    // 总验证方案
│   │   └── {module}_verify_plan_v{X}.md
│   └── check_point/             // 测试点+用例+覆盖率
│       ├── {module}_testcase_v{X}.md
│       └── {module}_coverage_v{X}.md
└── run/
    ├── filelist.f               // 文件列表
    ├── run_test.sh              // 运行脚本
    └── cov_report.sh            // 覆盖率报告脚本
```

---


---

> **核心版覆盖 §1-§8（文件组织/命名/层次/Factory/ConfigDB/Sequence/Driver/Monitor）+ §19-§20（禁止行为/文件结构）。**
> **高级版**覆盖 §9-§18 + §21-§23（Scoreboard/Coverage/Interface/参数化/复位/Objection/Phase/TLM/宏/报告/反合理化/RTL对应/RAL）。
