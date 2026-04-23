# RAG 强制检索协议（共享）

> **铁律：每次涉及协议/接口/CBB/选型/编码前，必须先完成检索。未完成检索不得输出任何设计内容、代码或评审意见。**

## 知识库路径映射

| 知识域 | 路径 | 应用场景 |
|--------|------|----------|
| 总线接口协议 | `.claude/knowledge/bus-protocol/` | AXI/AHB/APB/SPI/I2C/PCIe/DDR 选型、接口定义、协议合规 |
| 网络协议 | `.claude/knowledge/net-protocol/` | Ethernet/RDMA/RoCE 隧道/路由 选型、数据通路设计 |
| I/O 与存储协议 | `.claude/knowledge/IO-protocol/` | CHI/NVMe/VirtIO/SR-IOV 选型、队列体系设计 |
| CBB 基础模块 | `.claude/knowledge/cbb/` | FIFO/Arbiter/CDC/CRC/RAM 实例化、选型对比 |
| IP 模块 | `.claude/knowledge/IP/` | 集成 IP 接口规格、配置序列 |

**索引文件速查**：

| 知识域 | 索引路径 |
|--------|----------|
| 总线协议 | `.claude/knowledge/bus-protocol/bus-protocol-readme.md` |
| 网络协议 | `.claude/knowledge/net-protocol/net-protocol-readme.md` |
| IO/存储协议 | `.claude/knowledge/IO-protocol/io-protocol-readme.md` |
| CBB 模块 | `.claude/knowledge/cbb/cbb-list-readme.md` |

## 检索流程（2 阶段）

### 阶段 1：定位文档

根据当前任务涉及的知识域，选择以下路径之一：

| 场景 | 操作 |
|------|------|
| **已知文档路径**（Agent 定义/知识库索引/之前对话中提到过） | 直接 `Read` 该文档，跳过阶段 1 |
| **已知知识域但不确定具体文档** | `Read` 对应目录的索引文件（见上表），再读具体文档 |
| **不确定知识域** | `Glob` 探索目录结构，再读索引，再读具体文档 |

### 阶段 2：精确读取

根据阶段 1 定位到的文档路径，`Read` 读取具体内容。涉及多个协议/CBB 时，每个都要独立读取。

## 检索策略（按任务阶段）

| 任务阶段 | 检索目标 |
|----------|----------|
| 选型阶段 | 读取 `*-readme.md` 索引文件中的选型对比表 |
| 接口定义阶段 | 读取对应协议文档获取精确信号定义和时序参数 |
| CBB 集成阶段 | 读取 CBB 文档获取参数化选项和实例化示例 |
| 编码阶段 | 参考 `coding-style.md` 确保代码规范一致 |
| 评审阶段 | 逐条核对协议/CBB 文档与被评审内容的一致性 |

> **Token 节约原则**：避免无差别 `Glob` 全目录。Agent 定义中已列出知识域路径、对话中已提及文档名、索引文件已读过的情况下，直接读目标文档。

## 回退规则
知识库无相关文档时，回退到 LLM 并**显式标注**："通用知识，未找到知识库文档"。

## 输出标注要求
- **设计/评审输出**：在结果中标注信息来源文档名
- **代码输出**：在注释中标注 `// CBB Ref: {文档名}`；CBB 缺失时标记 `[CBB-MISSING]`

## 适用范围
所有芯片架构 Agent（chip-arch、chip-requirement-arch、chip-fs-writer、chip-microarch-writer、chip-code-writer、chip-arch-reviewer）。
