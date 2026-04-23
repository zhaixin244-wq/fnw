---
name: chip-impl-rtl-coding
description: RTL 代码实现 — 逐子模块实现数据通路+控制逻辑+CBB+接口，严格遵循架构冻结铁律
---

# RTL 代码实现 Skill

## 职责
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
5. 保存到 `{module}_work/rtl/{submodule}.v`

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
