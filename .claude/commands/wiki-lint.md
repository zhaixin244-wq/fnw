# Wiki Lint — 知识库健康检查

运行知识库健康检查，检测以下问题：

1. **索引一致性** — index.md 条目与实际文件是否匹配
2. **死链接** — markdown 链接目标是否存在
3. **空页面** — 内容过少的占位页面
4. **过期声明** — TODO/待补充/TBD 标记
5. **格式一致性** — 实体页面是否缺少标准章节
6. **来源追溯** — 知识来源标注是否完整
7. **孤立页面** — 无任何引用的页面
8. **交叉引用** — 相关实体间双向链接完整性

## 执行

运行 lint 脚本：

```bash
bash .claude/shared/wiki-lint.sh
```

如需自动修复可修复项：
```bash
bash .claude/shared/wiki-lint.sh --fix
```

读取生成的报告 `.claude/wiki/lint-report.md`，总结发现的问题和修复建议。

## 参数

- `$ARGUMENTS` — 可选参数，如 `--fix` 启用自动修复

执行命令：`bash .claude/shared/wiki-lint.sh $ARGUMENTS`
