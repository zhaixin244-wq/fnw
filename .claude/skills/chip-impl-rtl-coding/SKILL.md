---
name: chip-impl-rtl-coding
description: "Use when implementing RTL code for chip submodules. Triggers on 'RTL实现', 'rtl coding', '写rtl', '代码实现', '数据通路', '控制逻辑', 'rtl code'. Implements data path, control logic, CBB integration and interface per submodule, strictly following architecture freeze."
---

# RTL 代码实现 Skill

## 任务
逐子模块实现 RTL 代码：数据通路 → 控制逻辑/FSM → CBB 集成 → 接口逻辑。

## 输入
- `microarch_doc`: 微架构文档
- `port_list`: 端口列表（来自 module_structure）
- `submodule_list`: 子模块列表
- `cbb_docs`: CBB 文档
- `coding_style`: 编码规范

## 执行步骤（每个子模块）
1. **数据通路**：从微架构 §5.1 逐阶段编码
2. **控制逻辑 + FSM**：从微架构 §5.3 两段式状态机
3. **CBB 集成**：从 RAG 检索结果实例化，标注 `// CBB Ref`
4. **接口逻辑**：valid/ready 握手、背压、异常处理
5. 保存到 `{module}_work/ds/rtl/{submodule}.v`

## 模板化 always 块骨架

> 编码时直接复用以下模板，减少 LLM 推理开销，提升代码一致性。`{...}` 为占位符。

### 复位模板（异步复位同步释放）
```verilog
// Ref: Arch-Sec-{X.Y} — {信号功能描述}
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        {signal}_r <= {reset_value};
    end else begin
        {signal}_r <= {signal}_nxt;
    end
end
```

### FSM 两段式模板
```verilog
// FSM 段1：时序逻辑存状态
// Ref: Arch-Sec-{X.Y} — {状态机功能描述}
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_cur <= S_IDLE;
    else state_cur <= state_nxt;
end

// FSM 段2：组合逻辑算次态
always @(*) begin
    state_nxt = S_IDLE;  // 默认值（防 latch）
    case (state_cur)
        S_IDLE: if ({condition}) state_nxt = S_WORK;
        S_WORK: state_nxt = {done} ? S_IDLE : S_WORK;
        default: state_nxt = S_IDLE;  // 非法状态回收
    endcase
end
```

### 握手模板（Valid-Ready）
```verilog
// Valid-Ready 握手模板
// Ref: Arch-Sec-{X.Y} — {接口功能描述}
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) valid_r <= 1'b0;
    else if (valid_r && ready) valid_r <= next_valid;  // 握手后更新
    else if (!valid_r) valid_r <= next_valid;           // 无数据时可更新
end

assign ready = !downstream_backpressure;  // ready 仅依赖下游
```

### 组合逻辑模板（防 latch）
```verilog
always @(*) begin
    // 默认值（必须）
    {output1} = {default1};
    {output2} = {default2};
    case ({selector})
        {VAL_A}: begin
            {output1} = {value_a1};
            {output2} = {value_a2};
        end
        {VAL_B}: begin
            {output1} = {value_b1};
        end
        default: ;  // case default（必须）
    endcase
end
```

## 架构冻结铁律
```
ABSOLUTELY NO ARCHITECTURE MODIFICATION IN RTL
```
- 严格按微架构文档实现
- 疑问暂停标记 `[ARCH-QUESTION]`
- 仅文档明显笔误时允许偏差，标注 `[ARCH-DEVIATION]`
- 代码标注架构章节号：`// Ref: Arch-Sec-4.2.1`

## 编码铁律（L0 核心 6 条）
1. 时序逻辑：`always @(posedge clk or negedge rst_n)` + `<=`
2. 组合逻辑：`always @(*)` 必须赋默认值，case 有 default，if 有 else
3. FSM：用 `localparam` 定义状态，禁止 `define`，两段式
4. 握手：`valid` 不能依赖 `ready` 的组合逻辑
5. always 块：≤ 100 行，生成信号 < 5 个，语义不相近拆分
6. 禁止：casex/casez、task、门控时钟、位置关联实例化、单字母名

## CBB 集成规则
- 功能属于 CBB 范畴必须使用标准 CBB，禁止自研
- 实例化注释标注 `// CBB Ref: {文档名}`
- 无文档标记 `[CBB-MISSING]`

## 输出
- `rtl_files`: 所有子模块 RTL 文件路径列表

## Gate
每个子模块 RTL 编译无语法错误。

## Metrics
执行完成后记录到 `{work_dir}/ds/report/metrics/rtl_impl.json`：
```json
{"stage_id": "rtl_impl", "duration_ms": 0, "iteration_count": 1}
```

## 使用示例

**示例 1**：
- 用户：「根据公共模块微架构实现 input_if_mod 子模块 RTL」
- 行为：读取微架构 §5.1 数据通路逐阶段编码，§5.3 实现两段式 FSM，集成 CBB 并标注 `// CBB Ref`，实现 valid/ready 握手逻辑，保存到 `{module}_work/ds/rtl/input_if_mod.v`

**示例 2**：
- 用户：「帮我补全 buf_mgr 的 FIFO 子模块代码」
- 行为：从微架构 §5.5 读取 FIFO 配置，按编码规范实现多 1 位指针法满/空判断，异步复位同步释放，组合逻辑赋默认值，保存到对应 `.v` 文件

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 微架构章节缺失 | §5.1/§5.3 无详细设计 | 暂停，标注 `[ARCH-QUESTION]`，等待用户补充 |
| CBB 文档缺失 | RAG 检索无结果 | 标注 `[CBB-MISSING]`，提示用户确认是否自研 |
| 架构疑问 | 微架构描述模糊或矛盾 | 暂停标记 `[ARCH-QUESTION]`，不擅自修改架构 |
| 编码规范冲突 | 微架构要求与编码规范矛盾 | 标注 `[ARCH-DEVIATION]`，以微架构为准 |

## 检查点

**检查前**：
- 确认微架构文档已读取且 §5 各子章节完整
- 确认端口列表（来自 module_structure）已就绪
- 确认 CBB 文档已检索

**检查后**：
- 确认每个子模块 RTL 文件已保存到 `{module}_work/ds/rtl/`
- 确认代码遵循编码铁律（时序 `<=`、组合默认值、FSM 两段式等）
- 确认所有 CBB 实例化有 `// CBB Ref` 注释
- 确认 metrics 已写入 `{work_dir}/ds/report/metrics/rtl_impl.json`
