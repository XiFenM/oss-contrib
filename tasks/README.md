# 进行中任务工作目录（`tasks/`）

每个正在推进的开源任务在此建立一个独立子目录，建议命名为 `YYYY-MM-<repo>-<id-or-slug>/`，例如：

```text
tasks/2026-11-aimet-4138/
├── notes.md            # 根因定位、源码锚点（commit SHA + 行号）、替代方案对比
├── repro.py            # 最小复现脚本（不含大权重与敏感数据）
├── test-results.md     # 实际运行命令、环境版本与原始结果摘要
└── pr-draft.md         # 英文认领留言与 PR 描述草稿
```

## 领题前四步检查

1. 在 `upstream/<repo>` 拉取最新目标分支，确认 bug/缺口仍然存在。
2. 按 issue 编号与关键函数名检索 Open PR，确认无重复在研工作。
3. 跑通最小复现脚本并记录 commit SHA 与运行环境。
4. 在 issue 下简短英文留言确认分工，获得认可或无冲突后再提交正式 PR。
