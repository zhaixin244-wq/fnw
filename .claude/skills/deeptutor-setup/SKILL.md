---
name: deeptutor-setup
description: "DeepTutor 部署检测与安装配置。触发词：'部署 DeepTutor'、'安装 DeepTutor'、'检查 DeepTutor'、'配置 DeepTutor'、'deeptutor setup'。检测 CLI 可用性、Python venv、依赖完整性、.env 配置，缺失时自动部署。"
---

# DeepTutor Setup

## 任务

检测 DeepTutor 部署状态，未部署时自动完成安装配置。确保 `deeptutor` CLI 可用且 API key 已配置。

## 前置条件

| 条件 | 检测命令 | 说明 |
|------|----------|------|
| Python 3.11+ | `python --version` | 后端运行时 |
| Git | `git --version` | 克隆仓库（仅首次） |
| 网络连接 | `ping github.com` | 下载依赖 |

## 执行步骤

### Step 1: 检测部署状态

按以下顺序检测，记录每步结果：

```bash
# 1.1 检测 DeepTutor 目录是否存在
ls .claude/tools/DeepTutor/

# 1.2 检测 Python venv 是否存在
ls .claude/tools/DeepTutor/.venv/Scripts/python.exe 2>/dev/null && echo "VENV_OK" || echo "VENV_MISSING"

# 1.3 检测 deeptutor CLI 是否可用
.claude/tools/DeepTutor/deeptutor.bat --help 2>/dev/null && echo "CLI_OK" || echo "CLI_MISSING"

# 1.4 检测 .env 是否存在且已配置 API key
cat .claude/tools/DeepTutor/.env 2>/dev/null | grep -c "YOUR_.*_API_KEY_HERE" && echo "KEY_MISSING" || echo "KEY_CONFIGURED"
```

**状态判定**：

| 状态 | 条件 | 动作 |
|------|------|------|
| ✅ 完全就绪 | 目录 + venv + CLI + API key 均存在 | 跳到 Step 5 输出报告 |
| ⚠️ 部分就绪 | 目录存在但 venv/CLI/key 缺失 | 从缺失步骤开始 |
| ❌ 未部署 | 目录不存在 | 从 Step 2 开始完整部署 |

### Step 2: 克隆仓库（如目录不存在）

```bash
cd .claude/tools/ && git clone https://ghfast.top/https://github.com/HKUDS/DeepTutor.git 2>&1
```

**镜像备选**（ghfast.top 失败时）：
- `https://gitclone.com/github.com/HKUDS/DeepTutor.git`
- `https://hub.gitclone.com/github.com/HKUDS/DeepTutor.git`
- 直连：`https://github.com/HKUDS/DeepTutor.git`

**超时**：120 秒。超时后尝试下一个镜像。

### Step 3: 安装依赖（如 venv/CLI 不存在）

```bash
cd .claude/tools/DeepTutor

# 创建 venv
python -m venv .venv

# 激活 venv 并安装
source .venv/Scripts/activate && pip install -e ".[server]" 2>&1 | tail -10
```

**超时**：300 秒。使用清华 PyPI 镜像加速。

**验证**：
```bash
.claude/tools/DeepTutor/deeptutor.bat --help
```

### Step 4: 配置 .env（如 API key 未配置）

```bash
cd .claude/tools/DeepTutor && cp .env.example .env
```

**默认配置**（LLM + Embedding）：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| LLM_BINDING | `xiaomi_mimo` | 小米 MIMO |
| LLM_MODEL | `mimo-v2.5-pro` | 模型名 |
| LLM_HOST | `https://api.xiaomimimo.com/v1` | API 端点 |
| EMBEDDING_BINDING | `siliconflow` | 硅基流动 |
| EMBEDDING_MODEL | `BAAI/bge-large-zh-v1.5` | 中文向量模型 |
| EMBEDDING_HOST | `https://api.siliconflow.cn/v1/embeddings` | Embedding 端点 |
| EMBEDDING_DIMENSION | `1024` | 向量维度 |

**API key 提示**：输出提示信息，要求用户填写：
```
请编辑 .claude/tools/DeepTutor/.env，填写以下 API key：
- LLM_API_KEY：MIMO 平台 API key
- EMBEDDING_API_KEY：硅基流动 API key
```

### Step 5: 输出部署报告

```markdown
## DeepTutor 部署报告

| 检查项 | 状态 | 详情 |
|--------|------|------|
| 仓库目录 | ✅/❌ | `.claude/tools/DeepTutor/` |
| Python venv | ✅/❌ | `.claude/tools/DeepTutor/.venv/` |
| CLI 可用 | ✅/❌ | `deeptutor --help` |
| .env 配置 | ✅/❌ | API key 已配置/待配置 |
| LLM 连通性 | ✅/❌/⏭️ | `deeptutor config show` |
| Embedding 连通性 | ✅/❌/⏭️ | 需 API key 配置后验证 |

**CLI 路径**：`.claude/tools/DeepTutor/deeptutor.bat`
**知识库目录**：`.claude/tools/DeepTutor/data/knowledge_bases/`
```

## 异常处理

| 场景 | 触发条件 | 处理动作 |
|------|----------|----------|
| Git 克隆失败 | 网络不通/镜像超时 | 尝试备选镜像，全部失败提示用户手动下载 |
| pip 安装失败 | 依赖冲突/网络超时 | 使用 `--no-deps` 降级安装，报告缺失依赖 |
| CLI 启动报错 | 缺少模块 | `pip install {missing_module}` 逐个补装 |
| .env 格式错误 | 编辑导致格式异常 | 重新从 `.env.example` 复制，保留已填 key |
| Python 版本不满足 | < 3.11 | 提示用户升级 Python |

## 检查点

- **Step 1 后**：输出检测结果，确认需要执行的步骤
- **Step 3 后**：验证 CLI 可用，输出 `--help` 结果
- **Step 4 后**：提醒用户填写 API key（如未填写）
- **Step 5 后**：输出完整部署报告

## 使用示例

```
Agent：调用 Skill("deeptutor-setup")

# 输出：
## DeepTutor 部署检测

| 检查项 | 状态 |
|--------|------|
| 仓库目录 | ✅ 存在 |
| Python venv | ✅ 存在 |
| CLI 可用 | ✅ 正常 |
| .env 配置 | ⚠️ API key 待填写 |

CLI 已就绪，API key 需要配置后才能使用 DeepTutor 研究功能。
```
