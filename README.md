# oss-contrib

独立的 AI Infra 开源贡献工程工作区，与知识规划仓库 `../PlanA` 并排存放、职责解耦：

- **`../PlanA/开源贡献/`** 负责定期调研核验、选题决策、阶段计划，以及接收最终成果总结用于复盘、简历与面试取材。
- **`oss-contrib`（本仓）** 负责拉取外部上游仓库、搭建独立编译/测试环境、编写最小复现与补丁、维护 PR 草稿，以及沉淀已完成任务的正式总结并同步回 `PlanA`。

---

## 目录结构

```text
oss-contrib/
├── README.md                  ← 本文件
├── AGENTS.md                  ← 本仓 Agent 协作边界与验证/脱敏纪律
├── .gitignore                 ← 忽略 upstream/ 源码树、虚拟环境、构建产物与缓存
├── plans/                     ← 从 ../PlanA/开源贡献/调研报告/ 单向同步过来的调研与计划（只读镜像）
├── tasks/                     ← 进行中的单个开源任务工作目录（每题一个子目录）
├── summaries/                 ← 已完成/阶段收口任务的总结（权威源，定期同步回 PlanA）
├── upstream/                  ← 外部上游仓库的本地 clone / fork（被 Git 忽略，不入本仓）
├── envs/                      ← 各项目独立环境配置脚本（环境产物本身被 Git 忽略）
└── scripts/
    └── sync_with_plana.py     ← 与 ../PlanA 的双向（分目录单向权威）同步脚本
```

---

## 双仓同步规则与命令

两个方向严格实行**单写者权威源**，避免双向手改冲突：

| 方向 | 权威源 | 目标镜像 | 命令 |
|---|---|---|---|
| **PlanA → oss-contrib** | `../PlanA/开源贡献/调研报告/*.md` | `plans/*.md` | `python3 scripts/sync_with_plana.py pull-plans` |
| **oss-contrib → PlanA** | `summaries/*.md`（不含 `README.md` 与 `_*.md`） | `../PlanA/开源贡献/成果总结/*.md` | `python3 scripts/sync_with_plana.py push-summaries` |

日常先查看差异或演练，再执行同步：

```bash
# 1. 检查双仓当前同步状态
python3 scripts/sync_with_plana.py status

# 2. 从 PlanA 同步最新调研与工作计划（先 dry-run 预览）
python3 scripts/sync_with_plana.py pull-plans --dry-run
python3 scripts/sync_with_plana.py pull-plans

# 3. 将已完成任务总结回传到 PlanA（先 dry-run 预览）
python3 scripts/sync_with_plana.py push-summaries --dry-run
python3 scripts/sync_with_plana.py push-summaries
```

---

## 标准单题工作流

1. **读计划**：在 `plans/` 中选定 1 个任务（不要同时铺开多个大题）。
2. **建任务目录**：在 `tasks/` 下新建 `YYYY-MM-<repo>-<id>/`，记录目标 commit、最小复现脚本、源码分析与测试结果。
3. **拉上游与搭环境**：将目标仓库浅克隆或 fork 拉入 `upstream/<repo>`，在 `envs/` 或独立 venv/conda/docker 中隔离依赖。
4. **验证与提交前核对**：先在本地跑通复现与单测；需要短窗口租卡（AMD 单卡 / NV 单机多卡）时，先把代码和测试脚本准备完毕再开机测试。
5. **收口与回传**：PR 提交、进入评审或合并后，按 `summaries/_template.md` 写入 `summaries/YYYY-MM-DD-<repo>-<topic>.md`，再用 `sync_with_plana.py push-summaries` 同步回 `PlanA`。
