---
name: UVM Verification Coding Style (Advanced)
description: UVM-1.2 验证环境编码规范高级版。覆盖 Scoreboard/Coverage/Interface/RAL 等特殊场景。
---

# 验证环境编码规范（UVM 1.2）— 高级版

> 本文件为  的补充，覆盖特殊场景。
> **仅在需要时加载**（如编写 Scoreboard、Coverage、RAL 模型等）。

---

## 9. Scoreboard 编码

### 9.1 标准 Scoreboard 模板

```systemverilog
class data_adpt_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(data_adpt_scoreboard)

    // TLM 端口
    uvm_analysis_imp_decl(_exp)    // 期望数据（来自上游 monitor）
    uvm_analysis_imp_decl(_act)    // 实际数据（来自下游 monitor）

    uvm_analysis_imp_exp #(axi4_seq_item, data_adpt_scoreboard) exp_imp;
    uvm_analysis_imp_act #(axi4_seq_item, data_adpt_scoreboard) act_imp;

    // 期望队列
    axi4_seq_item exp_queue[$];

    // 统计
    int match_cnt, mismatch_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_imp = new("exp_imp", this);
        act_imp = new("act_imp", this);
    endfunction

    // 期望数据入队
    virtual function void write_exp(axi4_seq_item item);
        exp_queue.push_back(item);
    endfunction

    // 实际数据比对
    virtual function void write_act(axi4_seq_item item);
        axi4_seq_item exp_item;
        if (exp_queue.size() == 0) begin
            `uvm_error("SCB", $sformatf("Unexpected actual item: %s", item.convert2string()))
            mismatch_cnt++;
            return;
        end
        exp_item = exp_queue.pop_front();
        if (item.compare(exp_item)) begin
            match_cnt++;
        end else begin
            `uvm_error("SCB", $sformatf("Data mismatch!\nEXP: %s\nACT: %s",
                exp_item.convert2string(), item.convert2string()))
            mismatch_cnt++;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("Scoreboard: MATCH=%0d MISMATCH=%0d Q_SIZE=%0d",
            match_cnt, mismatch_cnt, exp_queue.size()), UVM_LOW)
        if (mismatch_cnt > 0)
            `uvm_error("SCB", "Scoreboard has mismatches!")
        if (exp_queue.size() > 0)
            `uvm_warning("SCB", $sformatf("Expected queue not empty: %0d remaining", exp_queue.size()))
    endfunction
endclass
```

### 9.2 Scoreboard 规则

| # | 规则 | 说明 |
|---|------|------|
| S-01 | 使用 `analysis_imp_decl` 宏 | 多端口必须加后缀区分 |
| S-02 | 期望数据入队，实际数据出队比对 | FIFO 语义 |
| S-03 | 比对失败用 `uvm_error` | 不用 `uvm_fatal`（不终止仿真） |
| S-04 | `report_phase` 输出统计 | match/mismatch/queue size |
| S-05 | 队列非空在 `report_phase` 告警 | 说明有期望数据未被比对 |
| S-06 | 使用 `compare()` 方法比对 | 不要手动逐字段比对 |
| S-07 | 支持乱序比对（如需） | 用 `find_first_match` 替代 `pop_front` |

---

## 10. 覆盖率收集

### 10.1 Covergroup 定义

```systemverilog
class data_adpt_cov extends uvm_component;
    `uvm_component_utils(data_adpt_cov)

    uvm_analysis_imp #(axi4_seq_item, data_adpt_cov) item_imp;

    // 功能覆盖率
    covergroup cg_data_adpt;
        cp_xact_type: coverpoint item.xact_type {
            bins read  = {AXI_READ};
            bins write = {AXI_WRITE};
        }
        cp_addr_region: coverpoint item.addr[31:28] {
            bins region0 = {4'h0};
            bins region1 = {4'h1};
            bins regionf = {4'hF};
        }
        cp_data_size: coverpoint item.size {
            bins byte1  = {0};
            bins byte2  = {1};
            bins byte4  = {2};
            bins byte8  = {3};
        }
        cx_type_addr: cross cp_xact_type, cp_addr_region;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_data_adpt = new();
    endfunction

    virtual function void write(axi4_seq_item item);
        cg_data_adpt.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("Functional coverage: %.1f%%",
            cg_data_adpt.get_inst_coverage()), UVM_LOW)
    endfunction
endclass
```

### 10.2 覆盖率规则

| # | 规则 | 说明 |
|---|------|------|
| C-01 | 每个 covergroup 有明确的覆盖目标 | 对应测试点 |
| C-02 | 使用 `bins` 显式定义覆盖桶 | 不依赖自动推断 |
| C-03 | `illegal_bins` 标记非法组合 | 配置互斥时用 |
| C-04 | `ignore_bins` 标记不关心的组合 | 减少噪声 |
| C-05 | Cross coverage 按需创建 | 避免组合爆炸 |
| C-06 | `report_phase` 输出覆盖率 | 与收敛计划对比 |
| C-07 | 覆盖率收集器独立组件 | 不嵌入 monitor |

---

## 11. Interface 与 BFM

### 11.1 Interface 定义

```systemverilog
interface axi4_intf #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64
)(
    input logic clk,
    input logic rst_n
);
    // 信号声明
    logic [ADDR_WIDTH-1:0] aw_addr;
    logic                    aw_valid;
    logic                    aw_ready;
    logic [DATA_WIDTH-1:0] w_data;
    logic                    w_valid;
    logic                    w_ready;
    // ...

    // Modport 定义
    modport master (
        output aw_addr, aw_valid,
        input  aw_ready,
        output w_data, w_valid,
        input  w_ready,
        input  clk, rst_n
    );

    modport slave (
        input  aw_addr, aw_valid,
        output aw_ready,
        input  w_data, w_valid,
        output w_ready,
        input  clk, rst_n
    );

    modport monitor (
        input aw_addr, aw_valid, aw_ready,
        input w_data, w_valid, w_ready,
        input clk, rst_n
    );

    // SVA 断言（可选）
    `ifdef ASSERT_ON
    property p_valid_stable;
        @(posedge clk) disable iff (!rst_n)
        (aw_valid && !aw_ready) |=> aw_valid;
    endproperty
    assert_valid_stable: assert property (p_valid_stable);
    `endif
endinterface
```

### 11.2 Interface 规则

| # | 规则 | 说明 |
|---|------|------|
| I-01 | 必须定义 modport | master / slave / monitor 至少三个 |
| I-02 | 时钟复位在端口传入 | `input logic clk, rst_n` |
| I-03 | 参数化位宽 | 用 `parameter` 不硬编码 |
| I-04 | Monitor modport 只读 | 所有信号 `input` |
| I-05 | BFM 逻辑在 driver 中 | Interface 内禁止 `always`/`initial` |
| I-06 | SVA 可放 Interface 内 | `` `ifdef ASSERT_ON `` 保护 |

---

## 12. 参数化与配置

### 12.1 Config Object 模板

```systemverilog
class data_adpt_env_cfg extends uvm_object;
    `uvm_object_utils(data_adpt_env_cfg)

    // 编译时参数（来自 DUT parameter）
    int data_width = 32;
    int ch_num     = 4;

    // Agent 配置
    uvm_active_passive_enum axi_agt_mode = UVM_ACTIVE;
    uvm_active_passive_enum apb_agt_mode = UVM_ACTIVE;

    // 运行时配置
    bit       module_en = 1'b1;
    bit [3:0] int_mask  = 4'h0;

    // 接口配置对象
    axi4_cfg axi_cfg;
    apb_cfg  apb_cfg;

    // 约束
    constraint c_valid {
        data_width inside {8, 16, 32, 64};
        ch_num inside {[1:8]};
    }

    function new(string name = "data_adpt_env_cfg");
        super.new(name);
        axi_cfg = axi4_cfg::type_id::create("axi_cfg");
        apb_cfg = apb_cfg::type_id::create("apb_cfg");
    endfunction
endclass
```

### 12.2 参数化规则

| # | 规则 | 说明 |
|---|------|------|
| P-01 | 编译时参数用 `parameter` | DUT 参数化对应 |
| P-02 | 运行时配置用 config object | 通过 `uvm_config_db` 传递 |
| P-03 | 配置对象必须有默认值 | 未 set 时有合理行为 |
| P-04 | 配置互斥用 `constraint` | 不要在 `build_phase` 中 `if-else` |
| P-05 | 配置验证在 `check_config` | test 的 `build_phase` 末尾调用 |

---

## 13. 复位处理

### 13.1 复位规则

| # | 规则 | 说明 |
|---|------|------|
| R-01 | Driver/Monitor 必须有 `monitor_reset` | 独立 `fork` 线程 |
| R-02 | 复位时清零所有输出 | Driver `reset_signals()` |
| R-03 | 复位时清零内部状态 | Monitor/Scoreboard 计数器/队列 |
| R-04 | 复位释放后等待 N 拍再工作 | 可配置的复位后延迟 |
| R-05 | 异步复位用 `@(negedge rst_n)` | 不用 `@(posedge clk)` 检测 |
| R-06 | Sequence 在复位时可被 kill | test 中通过 objection 控制 |

### 13.2 复位检测模板

```systemverilog
// 每个有 vif 的组件都必须有此任务
virtual task monitor_reset();
    forever begin
        @(negedge vif.rst_n);
        `uvm_info("RST", $sformatf("[%s] Reset asserted", get_name()), UVM_MEDIUM)
        reset_state();
        @(posedge vif.rst_n);
        `uvm_info("RST", $sformatf("[%s] Reset released", get_name()), UVM_MEDIUM)
        repeat (cfg.post_reset_delay) @(posedge vif.clk);
    end
endtask
```

---

## 14. Objection 机制

### 14.1 Objection 规则

| # | 规则 | 说明 |
|---|------|------|
| O-01 | `raise_objection` 仅在 test 层 | sequence/driver 中禁止 |
| O-02 | `drop_objection` 仅在 test 层 | 与 `raise` 成对 |
| O-03 | `raise` 在 `run_phase` 第一行 | `phase.raise_objection(this)` |
| O-04 | `drop` 在 `run_phase` 最后一行 | `phase.drop_objection(this)` |
| O-05 | 设置 `drain_time` 防止提前结束 | `phase.phase_done.set_drain_time(this, 100)` |
| O-06 | 超时保护 | `uvm_top.set_timeout(10ms)` |

```systemverilog
class data_adpt_base_test extends uvm_test;
    `uvm_component_utils(data_adpt_base_test)

    virtual task run_phase(uvm_phase phase);
        data_adpt_base_seq seq;
        phase.raise_objection(this, "Starting sequence");
        phase.phase_done.set_drain_time(this, 100ns);

        seq = data_adpt_base_seq::type_id::create("seq");
        seq.start(env.axi_agt.sequencer);

        phase.drop_objection(this, "Sequence completed");
    endtask
endclass
```

---

## 15. Phase 使用

### 15.1 Phase 使用规则

| Phase | 用途 | 禁止 |
|-------|------|------|
| `build_phase` | 创建组件、get config/vif | 不做耗时操作 |
| `connect_phase` | TLM 端口连接 | 不创建组件 |
| `end_of_elaboration` | 打印拓扑、配置校验 | 不修改连接 |
| `run_phase` | 主要仿真逻辑 | 不修改组件结构 |
| `check_phase` | 最终校验（空队列等） | 不做耗时操作 |
| `report_phase` | 输出统计报告 | 不做校验 |
| `final_phase` | 文件关闭等清理 | 不访问 DUT |

### 15.2 Phase 注意事项

- `build_phase` 中 `create` 顺序：子组件先于父组件连接
- `connect_phase` 中 `connect` 顺序：无强制，但建议从底向上
- `run_phase` 中多个 task 用 `fork...join` 并行
- `reset_phase` / `main_phase` / `shutdown_phase` 可按需细分 `run_phase`

---

## 16. TLM 端口使用

### 16.1 端口类型选择

| 场景 | 端口类型 | 说明 |
|------|----------|------|
| Monitor → Scoreboard | `analysis_port` / `analysis_imp` | 广播，一对多 |
| Sequence → Driver | `seq_item_port` / `seq_item_export` | 请求-响应 |
| Monitor → Coverage | `analysis_port` / `analysis_imp` | 广播 |
| 阻塞传输 | `put_port` / `put_imp` | 生产者→消费者 |
| 非阻塞传输 | `get_port` / `get_imp` | 消费者→生产者 |

### 16.2 TLM 规则

| # | 规则 | 说明 |
|---|------|------|
| T-01 | 一个 `analysis_imp` 只能连接一个 `analysis_port` | 多端口用 `imp_decl` 宏 |
| T-02 | `write()` 实现中禁止阻塞 | `analysis_imp` 的 `write` 必须非阻塞 |
| T-03 | 使用 `#(T)` 参数化端口 | 类型安全 |
| T-04 | Scoreboard 用 `analysis_imp_decl` | 多源比对必须 |

---

## 17. 宏使用

### 17.1 UVM 标准宏

| 宏 | 用途 | 必需 |
|----|------|------|
| `` `uvm_component_utils `` | 组件工厂注册 | Must |
| `` `uvm_object_utils `` | 对象工厂注册 | Must |
| `` `uvm_field_int `` | 自动字段操作（pack/compare/print） | 按需 |
| `` `uvm_field_object `` | 自动对象字段操作 | 按需 |
| `` `uvm_field_enum `` | 自动枚举字段操作 | 按需 |
| `` `uvm_info `` | 信息输出 | Must |
| `` `uvm_warning `` | 警告输出 | 按需 |
| `` `uvm_error `` | 错误输出 | 按需 |
| `` `uvm_fatal `` | 致命错误（终止仿真） | 仅不可恢复错误 |
| `` `uvm_do `` | Sequence 事务宏 | 按需 |
| `` `uvm_do_with `` | 带约束事务宏 | 按需 |
| `` `uvm_analysis_imp_decl `` | 多端口 analysis_imp | 多端口时 Must |

### 17.2 宏规则

| # | 觌则 | 说明 |
|---|------|------|
| M-01 | `uvm_info` 必须带 verbosity | `UVM_LOW` / `UVM_MEDIUM` / `UVM_HIGH` |
| M-02 | `uvm_fatal` 仅用于不可恢复错误 | 虚拟接口未设置、配置致命错误 |
| M-03 | 禁止用 `$display` | 统一用 UVM 报告机制 |
| M-04 | `uvm_field_*` 宏按需使用 | 大事务避免全字段注册（性能） |
| M-05 | 自定义 `convert2string` 优先于 field 宏 | 复杂事务推荐手动实现 |

---

## 18. 报告机制

### 18.1 Verbosity 约定

| 级别 | 用途 | 默认显示 |
|------|------|----------|
| `UVM_NONE` | 必须显示的信息 | 是 |
| `UVM_LOW` | 测试开始/结束、覆盖率 | 是 |
| `UVM_MEDIUM` | 事务收发、状态变化 | 是 |
| `UVM_HIGH` | 详细调试信息 | 否 |
| `UVM_DEBUG` | 极详细调试 | 否 |
| `UVM_FULL` | 全部输出 | 否 |

### 18.2 报告规则

| # | 规则 | 说明 |
|---|------|------|
| R-01 | 事务发送/接收用 `UVM_HIGH` | 仿真大量事务时不刷屏 |
| R-02 | 状态变化用 `UVM_MEDIUM` | FSM 转移、配置变化 |
| R-03 | 错误用 `uvm_error` | 不用 `uvm_warning` 替代 |
| R-04 | 致命错误用 `uvm_fatal` | 仅仿真无法继续时 |
| R-05 | 报告 ID 唯一且有意义 | `"[AXI_DRV]"`, `"[SCB]"` |

---

## 21. 反合理化清单

| 借口 | 回应 |
|------|------|
| "Driver 里加个 check 没事" | Driver 只驱动，校验在 Scoreboard |
| "Monitor 里直接写 scoreboard" | 用 analysis_port，解耦 |
| "用 $display 方便调试" | 统一 uvm_info，可控制 verbosity |
| "new 一下就行了不用 factory" | Factory 支持覆盖，new 不行 |
| "objection 放 sequence 里方便" | Test 层统一控制，sequence 不管生命周期 |
| "config_db 路径写死省事" | 路径变了全崩，用通配符+注释 |
| "force/release 能快速验证" | 破坏信号主权，掩盖真实 bug |
| "field 宏全注册最保险" | 大事务性能差，手动 convert2string 更灵活 |
| "#delay 比 @(posedge clk) 简单" | 不与时钟同步，仿真行为不可复现 |
| "一个大 sequence 写完省事" | 可复用性为零，拆成小 sequence 组合 |

---

## 22. 与 RTL 编码规范的对应关系

| RTL 规范 | 验证规范对应 | 说明 |
|----------|-------------|------|
| `coding-style.md` §2 命名 | 本规范 §2 命名 | 信号名风格一致 |
| `coding-style.md` §5 时钟复位 | 本规范 §13 复位处理 | 复位检测与 RTL 复位策略对应 |
| `coding-style.md` §6 组合逻辑 | 本规范 §7 Driver | Driver 接口赋值规则 |
| `coding-style.md` §8 握手协议 | 本规范 §8 Monitor | valid/ready 采样规则 |
| `coding-style.md` §10 Interface | 本规范 §11 Interface | modport 定义规则 |
| `coding-style.md` §11 SVA | 本规范 §11 Interface | SVA 放 Interface 内 |

---

## 23. RAL 寄存器模型与后门访问

> 基于 UVM 1.2 RAL（Register Abstraction Layer）的寄存器模型编码规范。所有寄存器访问必须通过 RAL 模型，禁止直接 `uvm_config_db` 传递寄存器值。

### 23.1 RAL 寄存器类

```systemverilog
class ral_reg_{module}_{REG_NAME} extends uvm_reg;
    rand uvm_reg_field field_name;

    function new(string name = "{module}_{REG_NAME}");
        super.new(name, 32, UVM_NO_COVERAGE);  // 位宽与 FS §7 一致
    endfunction

    virtual function void build();
        field_name = uvm_reg_field::type_id::create("field_name");
        // configure(reg, width, lsb, access, volatile, reset, has_reset, is_rand, individually_accessible)
        field_name.configure(this, 1, 0, "RW", 0, 1'h0, 1, 1, 1);
    endfunction
endclass
```

**RAL 寄存器规则**：

| # | 规则 | 说明 |
|---|------|------|
| RAL-01 | 每个寄存器一个类 | 类名 `ral_reg_{module}_{REG_NAME}` |
| RAL-02 | `configure()` 的 access 参数与 FS §7 一致 | RW/RO/W1C/WO/RC/W1S |
| RAL-03 | reset 值与 FS §7.2 复位值一致 | 包括保留位 |
| RAL-04 | `has_reset=1` | 所有寄存器必须有复位值 |
| RAL-05 | `individually_accessible` 按需设置 | 位域可独立访问时设为 1 |
| RAL-06 | W1C 字段 access 设为 `"W1C"` | 不要用 `"RW"` + 手动清零 |

### 23.2 RAL Block 与 Map

```systemverilog
class ral_block_{module}_reg_block extends uvm_reg_block;
    rand ral_reg_{module}_CTRL   CTRL;
    rand ral_reg_{module}_STATUS STATUS;

    function new(string name = "{module}_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        // 创建地址映射（基地址由 cfg_agent 配置）
        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN);

        // 逐个寄存器注册
        CTRL = ral_reg_{module}_CTRL::type_id::create("CTRL");
        CTRL.configure(this, null, "CTRL");  // 第三参数：hdl_path
        CTRL.build();
        default_map.add_reg(CTRL, 32'h00, "RW");  // 偏移地址与 FS §7.1 一致

        // lock_model() 必须在所有寄存器添加后调用
        lock_model();
    endfunction
endclass
```

**RAL Block 规则**：

| # | 规则 | 说明 |
|---|------|------|
| RB-01 | Block 类名 `ral_block_{module}_reg_block` | 一个 DUT 一个 Block |
| RB-02 | `create_map` 的 endian 与 RTL 一致 | 通常 `UVM_LITTLE_ENDIAN` |
| RB-03 | `add_reg` 的 offset 与 FS §7.1 地址映射一致 | 逐项比对 |
| RB-04 | `configure` 的 hdl_path 参数用于后门 | 设为寄存器 RTL 信号名 |
| RB-05 | `lock_model()` 在 `build()` 末尾调用 | 防止后续修改 |
| RB-06 | Block 内禁止放功能逻辑 | 仅寄存器定义和映射 |

### 23.3 RAL Adapter（前门）

```systemverilog
class {module}_reg_adapter extends uvm_reg_adapter;
    function new(string name = "{module}_reg_adapter");
        super.new(name);
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        apb_seq_item bus = apb_seq_item::type_id::create("bus");
        bus.addr  = rw.addr;
        bus.data  = rw.data;
        bus.write = (rw.kind == UVM_WRITE) ? 1 : 0;
        return bus;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        apb_seq_item bus;
        if (!$cast(bus, bus_item)) begin
            `uvm_fatal("ADAPT", "bus_item is not apb_seq_item")
            return;
        end
        rw.kind  = bus.write ? UVM_WRITE : UVM_READ;
        rw.addr  = bus.addr;
        rw.data  = bus.data;
        rw.status = UVM_IS_OK;
    endfunction
endclass
```

**Adapter 规则**：

| # | 规则 | 说明 |
|---|------|------|
| RA-01 | 每个总线接口一个 Adapter | APB / AXI-Lite 各一个 |
| RA-02 | `reg2bus` 返回正确的总线事务类型 | 与 Driver 的 seq_item 一致 |
| RA-03 | `bus2reg` 正确设置 `rw.status` | 错误响应设为 `UVM_NOT_OK` |
| RA-04 | Adapter 注册工厂 | `uvm_object_utils` |

### 23.4 后门访问

**后门路径注册**（在 RAL Block `build()` 中）：

```systemverilog
// 为每个寄存器添加后门 HDL 路径
CTRL.add_hdl_path_slice("ctrl_r", 0, 32);      // 信号名, lsb, width
STATUS.add_hdl_path_slice("status_r", 0, 32);
INT_STATUS.add_hdl_path_slice("int_status_r", 0, 32);

// 注册到 Block 的 HDL 路径
add_hdl_path("tb_top.dut.u_reg_mod", "RTL");   // 模块层级路径
```

**后门访问使用**：

```systemverilog
// 后门写（快速初始化）
ral_block.CTRL.write(status, 32'h0000_0001, UVM_BACKDOOR);

// 后门读（状态查询，无副作用）
ral_block.STATUS.read(status, value, UVM_BACKDOOR);

// 后门读 + 比对（复位值验证）
ral_block.CTRL.peek(status, value);  // peek = 后门读，不影响状态
assert(value == 32'h0000_0000) else `uvm_error("RST", "CTRL reset value mismatch")

// 前门读写（正常功能测试）
ral_block.CTRL.write(status, 32'h0000_0001, UVM_FRONTDOOR);
ral_block.CTRL.read(status, value, UVM_FRONTDOOR);
```

**后门规则**：

| # | 规则 | 说明 |
|---|------|------|
| BD-01 | 后门路径必须与 RTL 层级一致 | 用 Grep RTL 确认信号名和模块层级 |
| BD-02 | W1C 寄存器后门写需特殊处理 | 写 1 清零，不能直接赋新值 |
| BD-03 | RO 寄存器禁止后门写 | 后门写 RO 寄存器是验证环境 bug |
| BD-04 | 后门路径变化时同步更新 `add_hdl_path_slice` | RTL 重命名信号时 |
| BD-05 | 后门访问不触发总线时序 | 用于快速初始化和状态查询 |
| BD-06 | 前门访问用于功能测试 | 正常读写路径必须走前门 |

### 23.5 RAL 与 Scoreboard 集成

```systemverilog
// Scoreboard 中使用 RAL 预测值比对
class {module}_scoreboard extends uvm_scoreboard;
    ral_block_{module}_reg_block ral_model;

    // 前门写后，RAL 模型自动预测
    // 后门读 DUT 实际值，与 RAL 预测值比对
    virtual function void check_reg(string reg_name);
        uvm_reg       rg  = ral_model.get_reg_by_name(reg_name);
        uvm_status_e  status;
        uvm_reg_data_t act_val, exp_val;

        rg.peek(status, act_val);                    // 后门读实际值
        exp_val = rg.get();                          // RAL 预测值
        if (act_val !== exp_val) begin
            `uvm_error("SCB", $sformatf("REG %s mismatch: EXP=0x%h ACT=0x%h",
                reg_name, exp_val, act_val))
        end
    endfunction
endclass
```

**RAL Scoreboard 规则**：

| # | 规则 | 说明 |
|---|------|------|
| RS-01 | 复位后检查所有寄存器复位值 | 后门读 + 比对 FS §7.2 |
| RS-02 | 每次前门写后 N 拍检查目标寄存器 | N 由 UA §6 时序决定 |
| RS-03 | W1C 寄存器读回后检查清零 | 后门读 + 比对 expected_mask |
| RS-04 | 测试结束前全寄存器扫描 | 后门读所有寄存器，比对最终状态 |

### 23.6 RAL 命名汇总

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| 寄存器类 | `ral_reg_{module}_{REG}` | `ral_reg_data_adpt_CTRL` |
| Block 类 | `ral_block_{module}_reg_block` | `ral_block_data_adpt_reg_block` |
| Adapter 类 | `{module}_reg_adapter` | `data_adpt_reg_adapter` |
| Block 实例 | `ral_model` 或 `{module}_reg_block` | `ral_model` |
| Adapter 实例 | `reg_adapter` | `reg_adapter` |
| Map 名 | `default_map` | `default_map` |
