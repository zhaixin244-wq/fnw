---
name: chip-create-dir
description: 初始化芯片模块工作目录结构，创建 ds（设计）和 dv（验证）两级目录树，包含文档、RTL、仿真、报告等标准子目录。
---

# Chip Create Directory

## 任务
为芯片模块创建标准化工作目录结构，初始化 `<module_name>_work/` 根目录及 ds/dv 两级目录树。

## 依赖
- 无外部依赖，纯目录创建

## 调用方式

```bash
bash .claude/skills/chip-create-dir/init_workdir.sh <module_name> [parent_dir]
```

- `<module_name>`：模块名（必填），如 `axi_bridge`、`pcie_ctrl`
- `[parent_dir]`：父目录（可选），默认当前目录 `.`

## 目录结构

```
<module_name>_work/
├── ds/                          # Design（设计）
│   ├── doc/                     # 设计文档
│   │   ├── pr/                  # PR 原始资料
│   │   ├── fs/                  # 功能规格书（FS）
│   │   ├── ua/                  # 微架构规格书（UA）
│   │   └── report/              # 设计报告
│   ├── rtl/                     # RTL 源码
│   ├── lib/                     # IP/CBB 库
│   ├── common/                  # 公共头文件（.vh）、Interface（.sv）
│   └── run/                     # 综合/实现运行目录
│
└── dv/                          # Verification（验证）
    ├── doc/                     # 验证文档
    │   ├── chk_point/           # 验证检查点
    │   ├── plan/                # 验证计划
    │   └── report/              # 验证报告
    ├── env/                     # 验证环境（UVM/自定义）
    ├── tb/                      # Testbench
    ├── case/                    # 测试用例
    ├── ral/                     # 寄存器抽象层
    └── run/                     # 仿真运行目录
```

## 使用示例

```bash
# 在当前目录创建
bash .claude/skills/chip-create-dir/init_workdir.sh axi_bridge

# 指定父目录
bash .claude/skills/chip-create-dir/init_workdir.sh axi_bridge /d/work/project
```

创建完成后输出目录树摘要。
