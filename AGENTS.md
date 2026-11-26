# oss-contrib Agent 协作指南

本仓库是独立的开源贡献工程环境，配合同级知识仓库 `../PlanA` 使用。在此仓库内工作时遵守以下规则：

## 1. 仓库分工与单写者边界

- `plans/` 内的计划报告来自 `../PlanA/开源贡献/调研报告/`，**只读不手改**；需要重新调研或调整计划时回到 `PlanA` 更新后，用 `python3 scripts/sync_with_plana.py pull-plans` 同步。
- `summaries/` 是已完成或阶段收口任务总结的**唯一权威源**；写好或更新后通过 `python3 scripts/sync_with_plana.py push-summaries` 同步回 `../PlanA/开源贡献/成果总结/`。
- `upstream/` 仅存放外部上游源码 clone/fork（已由 `.gitignore` 忽略），不要把上游代码、wheel、模型权重或构建产物拷进 `../PlanA`。

## 2. 外部交互与 Git 授权边界

- 未经用户明确确认，不对外发布 GitHub issue、评论或 PR，也不执行 `git push`。
- 不在未获授权时替用户自动修改 `../PlanA` 中除 `push-summaries` 目标目录之外的任何文件（不触碰 `PlanA/计划/学习断点.md`、模块 `进度.md` 或未提交草稿）。
- 使用 AI 辅助编写上游补丁时，严格遵守目标项目的 AI 披露、DCO sign-off、代码格式和人工审阅要求。

## 3. 验证与证据纪律

- 硬件边界保持诚实：明确区分本地 Linux CPU、M4 Arm64 CPU、AMD 单卡、NV 单机多卡与维护者 CI；**无多机多卡环境**，不把 CPU mock、单卡结果或模拟器通过写成多机/RDMA/生产实测。
- 动手改代码前必查最新 `main`/`develop` 和所有相关 Open PR，防止重复实现已有作者的工作。
- 严禁带入任何公司内部代码、未公开 API、内部日志或敏感硬件参数。
