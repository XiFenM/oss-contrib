# 多硬件容器开发环境（`envs/docker/`）

本目录提供一套按硬件分层的 Docker 容器配置，便于在不同机器（大内存 Linux CPU、Apple M4 Mac、短窗口租用的 NVIDIA 单卡/单机多卡、AMD ROCm 单卡及其他厂商加速卡）上快速复现一致的开源贡献工作环境。

## 设计原则

1. **硬件底座与项目依赖解耦**：镜像本身只打包稳定的 OS + 系统编译库（C/C++/CMake/Ninja/ccache/io_uring/ibverbs/NUMA/MPI）+ GPU 工具链 + `uv`，**不把冲突的 Python 包写死在全局环境里**。
2. **每项目独立 venv + 跨容器共享缓存**：容器内通过 `mkvenv` 在 `/cache/venvs/<profile>/<project>` 创建独立虚拟环境（`uv` 可按项目自动拉取 Python 3.10 / 3.11 / 3.12），`uv` / `pip` / `huggingface` / `ccache` 全部落在持久卷 `oss-contrib-cache` 中，重建容器不丢缓存。
3. **构建上下文轻量**：Docker 构建上下文固定在 `envs/docker/`，不会把 `upstream/` 里数 GB 的上游源码打包传给 Docker daemon。

---

## 四个硬件 Profile 选型

| Profile | Dockerfile | 默认基础镜像 | 适用硬件 | 对应计划中的典型任务 |
|---|---|---|---|---|
| `cpu` | [Dockerfile.cpu](docker/Dockerfile.cpu) | `ubuntu:24.04`（原生支持 `amd64` / `arm64`） | 大内存 Linux CPU、Apple M4 Mac | `qualcomm/aimet#4138/#4128/#4126`、`ROCm/mori` UMBP CPU/SSD（`#1095/#770/#920`）、`LMCache#6748` CPU 单测、`sglang-omni#4629`、`pytorch/executorch` |
| `nvidia` | [Dockerfile.nvidia](docker/Dockerfile.nvidia) | `nvidia/cuda:12.8.0-devel-ubuntu24.04` | NVIDIA 单卡 / 单机多卡 | `LMCache#6748` GPU↔CPU E2E、`sglang-omni#4615/#4629`、vLLM / SGLang CUDA 扩展编译与调试 |
| `rocm` | [Dockerfile.rocm](docker/Dockerfile.rocm) | `rocm/dev-ubuntu-24.04:7.1.1-complete` | AMD ROCm 单卡（MI250/MI300/RX 7900 等） | `ROCm/mori`、`ROCm/rocm-aic#221`、`sglang-omni#2416`、`LMCache#5075`（`rocprofv3`/ROCTX）与 `#6345` |
| `other` | [Dockerfile.other](docker/Dockerfile.other) | `ARG BASE_IMAGE`（传入厂商镜像） | Intel XPU / Qualcomm QAIC / Ascend NPU 等 | 在任意厂商 Debian/Ubuntu 官方镜像上无侵入叠加 `uv`、编译工具和工作区约定 |

---

## 快速开始（新机器 3 步开工）

### 第 1 步：准备 `.env`

```bash
cd envs/docker
cp .env.example .env
```

按目标机器实际情况调整 `.env`（该文件已加入 `.gitignore`，不会误提交）：

- **UID / GID**：
  - 普通 Linux 工作站或 macOS：设为宿主机 `id -u` / `id -g`（通常为 `1000`）。
  - 云租卡机器（宿主机直接为 `root`，如 AutoDL / Vast.ai）：改为 `DEV_UID=0`、`DEV_GID=0`。
- **网络加速**（国内机器可选）：配置 `APT_MIRROR`、`UV_INDEX_URL`、`HF_ENDPOINT` 或代理。
- **GPU 版本对齐**：
  - NVIDIA 宿主机驱动若不支持 CUDA 12.8，改 `NVIDIA_BASE_IMAGE=nvidia/cuda:12.6.3-devel-ubuntu24.04`、`PYTORCH_CUDA_TAG=cu126`。
  - AMD ROCm 建议与宿主机 KFD 驱动版本对齐（如 `rocm/dev-ubuntu-24.04:6.4.4-complete`、`7.1.1-complete` 或 `rocm/pytorch:latest`），并在宿主机执行 `getent group render | cut -d: -f3` 填入 `RENDER_GID`。

### 第 2 步：构建并启动对应 Profile

```bash
# 纯 CPU（Linux x86_64 或 Apple M4 Arm64 均可）
docker compose --profile cpu up -d --build
docker compose --profile cpu exec cpu bash

# NVIDIA CUDA（需宿主机已装 NVIDIA Container Toolkit）
docker compose --profile nvidia up -d --build
docker compose --profile nvidia exec nvidia bash

# AMD ROCm（需宿主机已装 amdgpu/ROCm 驱动且存在 /dev/kfd 与 /dev/dri）
docker compose --profile rocm up -d --build
docker compose --profile rocm exec rocm bash
```

### 第 3 步：在容器内按项目创建独立虚拟环境

进入容器后直接使用预装的 `mkvenv` 命令：

```bash
# Phase 1: qualcomm/aimet#4138 (Python 3.10 + CPU PyTorch + pytest/onnx/transformers)
mkvenv aimet
source /cache/venvs/cpu/aimet/bin/activate

# ROCm/mori C++ + Python 辅助单测
mkvenv mori
source /cache/venvs/cpu/mori/bin/activate   # 在 rocm 容器内路径为 /cache/venvs/rocm/mori

# LMCache / sglang-omni / 自定义环境
mkvenv lmcache
mkvenv sglang-omni
mkvenv my-experiment 3.11
```

> 若使用 `rocm/pytorch:latest` 或厂商自带 PyTorch 的镜像，可在调用 `mkvenv` 前设置 `SKIP_TORCH=1` 避免重复下载 PyTorch。

---

## 其他加速卡（`other` Profile）用法

对于 Intel XPU、Qualcomm Cloud AI（QAIC）、Ascend CANN 等依赖厂商特定基础镜像与设备节点的硬件：

1. 在 `envs/docker/.env` 中指定厂商官方镜像：
   ```dotenv
   OTHER_BASE_IMAGE=intel/deep-learning-essentials:latest   # 示例，替换为实际厂商镜像
   OTHER_INSTALL_CPP_EXTRA=false
   OTHER_SKIP_TORCH=1
   ```
2. 按需在 `envs/docker/compose.override.yml`（本地文件，按需创建）中追加设备透传，例如：
   ```yaml
   services:
     other:
       devices:
         - /dev/dri:/dev/dri            # Intel XPU 示例
       group_add:
         - video
         - "${RENDER_GID:-render}"
   ```
   - Qualcomm QAIC 可挂 `/dev/accel:/dev/accel`；
   - Ascend NPU 可挂 `/dev/davinci0`、`/dev/davinci_manager`、`/dev/devmm_svm`、`/dev/hisi_hdc` 及宿主机驱动目录。
3. 启动并进入：
   ```bash
   docker compose --profile other up -d --build
   docker compose --profile other exec other bash
   ```

---

## 短窗口租卡工作流建议（省时省钱）

1. **先在 CPU 机器（或 `cpu` 容器）上准备完毕**：拉取 `upstream/<repo>`、定位源码、写出补丁与最小复现脚本（放在 `tasks/<task>/`），确保纯逻辑单测已通过。
2. **租卡开机后直接挂载运行**：同步本仓（及对应补丁）到云卡机，用 `nvidia` 或 `rocm` profile 拉起容器，直接跑 E2E 复现与回归测试、留存日志与环境信息（OS/驱动/ROCm 或 CUDA/PyTorch 版本）。
3. **避免编译爆内存**：默认 `MAX_JOBS=4`，若目标机器内存紧张可在 `.env` 中调低为 `MAX_JOBS=2`，大内存卡机可调高至 `8` 或 `16`。

---

## 常用维护命令

```bash
# 查看各 profile 渲染后的完整配置
docker compose --env-file .env.example --profile cpu --profile nvidia --profile rocm --profile other config

# 停止容器（保留 /cache 命名卷中的包缓存、HF 模型缓存与 venv）
docker compose --profile cpu down

# 仅彻底清理缓存卷（慎用：会删除所有已下载缓存与 /cache/venvs）
docker volume rm oss-contrib-cache
```
