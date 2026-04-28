---
name: chip-impl-parallel-dev
description: "Use when running parallel RTL development across multiple submodules. Triggers on '并行开发', 'parallel', '多模块并行', '并行subagent', 'parallel dev', '并行调度'. Coordinates Plan Mode analysis, parallel subagent dispatch, top-level integration and PR confirmation."
---

# 并行开发 Skill

## 任务
多模块并行开发流程：分析→调度→集成→确认。

## 流程

### Phase 1: Plan Mode 分析
1. 用 `Glob` 搜索 `{module}_work/ds/rtl/*.v` 获取子模块 RTL 文件列表。若文件不存在，暂停并提示用户
2. 确认输入：PR/FS/UA 文档
3. RAG 检索 CBB 依赖
4. 划分模块，评估依赖关系
5. 确定并行组（无依赖模块可并行）

**输出格式**：
```markdown
### 模块开发清单
| 模块名 | 依赖 | 复杂度 | 预估工时 | 并行组 |
|--------|------|--------|----------|--------|
| buf_mgr | sync_fifo | 中 | 2h | Group-A |
| ctrl_fsm | 无 | 高 | 3h | Group-A |
| top_int | buf_mgr, ctrl_fsm | 低 | 1h | Group-B |
```

### Phase 2: 并行 Subagent 开发
为每个可并行模块启动独立 subagent：
```
Agent({
  description: "RTL 开发 - {模块名}",
  subagent_type: "chip-code-writer",
  prompt: "开发 {module_name} 模块 RTL..."
})
```

**调度规则**：
| 规则 | 说明 |
|------|------|
| 依赖优先 | 有依赖的模块必须等待依赖完成 |
| 无依赖并行 | 无依赖模块可同时启动 |
| 独立工作目录 | 每个模块使用独立 `{module}_work/` |
| 独立检查 | 每个模块独立执行 Lint + 综合 |

### Phase 3: 顶层集成
所有子模块完成后：
1. 顶层 Lint 检查（ALL PASS）
2. 顶层综合检查（ALL PASS + 面积达标）
3. 检查模块间接口一致性

### Phase 4: PR/FS/UA 确认
| 确认维度 | 检查方法 |
|----------|----------|
| 功能覆盖 | 对照 FS §4 功能列表 |
| 接口一致 | 对照 FS §6 接口定义 |
| PPA 达标 | 对照 FS §8 PPA 规格 |
| 需求追溯 | 对照 RTM（FS §14） |

## 冲突检测

### 监控路径
| 文件类型 | 路径模式 | 冲突级别 |
|----------|----------|----------|
| 顶层 RTL | `{module}_work/rtl/{top_module}.v` | Critical |
| CBB 清单 | `{module}_work/ds/doc/*_cbb_list.md` | Major |
| SDC 约束 | `{module}_work/syn/{top_module}.sdc` | Major |
| 子模块 RTL | `{module}_work/rtl/{submodule}.v` | Info（独立目录不冲突） |

### 文件锁机制（跨平台）

**Linux/macOS — flock 原子锁**：
```bash
lock_file="{module}_work/.lock.{file_type}"
exec 200>"$lock_file"
if ! flock -n 200; then
  echo "[CONFLICT] $lock_file held by $(cat $lock_file)"
  exit 1
fi
echo "{agent_id}:$(date +%s)" >&200
# ... 执行 ...
exec 200>&-  # 释放
```

**Windows — PowerShell Mutex**：
```powershell
$mutex = New-Object System.Threading.Mutex($false, "Global\{module}_{file_type}")
if (-not $mutex.WaitOne(0)) {
  Write-Error "[CONFLICT] Mutex held by another process"
  exit 1
}
# ... 执行 ...
$mutex.ReleaseMutex()
$mutex.Dispose()
```

**平台检测逻辑**：
```bash
if command -v flock >/dev/null 2>&1; then
  # Linux/macOS: 使用 flock
  ...
elif command -v powershell >/dev/null 2>&1; then
  # Windows: 调用 PowerShell mutex
  powershell -File lock.ps1 ...
else
  # fallback: 文件存在性检查（有竞态风险，仅用于开发环境）
  ...
fi
```

**flock 优势**：原子操作，不存在"检查-写入"竞态窗口；进程崩溃时 fd 自动关闭释放锁。

### 冲突行为
| 冲突级别 | 行为 |
|----------|------|
| Critical | 暂停，等待用户协调，不自动合并 |
| Major | 暂停，提示冲突文件，等待确认 |
| Info | 记录日志，继续执行 |

## 输出
- 各模块 RTL + 质量报告
- 顶层集成 RTL + 质量报告
- PR/FS/UA 确认报告

## 使用示例

**示例 1**：
- 用户：「公共模块有 3 个子模块，帮我并行开发」
- 行为：分析依赖关系，无依赖模块（如 buf_mgr、ctrl_fsm）编入 Group-A 并行启动 subagent，有依赖模块（如 top_int）编入 Group-B 等待，完成后顶层集成

**示例 2**：
- 用户：「检查多模块并行开发是否有文件冲突」
- 行为：扫描各模块工作目录，检查顶层 RTL、CBB 清单、SDC 约束等共享文件是否有并发写入冲突，输出冲突报告

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| 子模块依赖环 | 模块间存在循环依赖 | 暂停，输出依赖环图，等待用户重新划分 |
| 文件锁冲突 | 多 subagent 同时写入同一文件 | Critical 级别暂停，等待用户协调 |
| Subagent 超时 | 单个模块开发超时无响应 | 记录超时模块，继续其他模块，汇总后重试 |
| 顶层集成失败 | 子模块接口不一致 | 输出接口差异表，定位不一致模块 |

## 检查点

**检查前**：
- 确认 PR/FS/UA 文档齐全
- 确认模块划分和依赖关系已明确
- 确认各模块工作目录独立

**检查后**：
- 确认所有子模块 RTL 已生成且 Lint 通过
- 确认顶层集成 Lint ALL PASS + 面积达标
- 确认 PR/FS/UA 确认报告已输出
