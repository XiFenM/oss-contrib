#!/usr/bin/env bash
set -euo pipefail

# Ensure persistent cache directories exist and are writable by the current user
# (handles freshly created Docker named volumes owned by root).
if [[ -d /cache ]]; then
  if [[ ! -w /cache ]] && command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$(id -u):$(id -g)" /cache 2>/dev/null || true
  fi
  mkdir -p \
    /cache/uv \
    /cache/pip \
    /cache/huggingface \
    /cache/torch \
    /cache/ccache \
    /cache/triton \
    /cache/venvs 2>/dev/null || true
fi

# Prevent git "dubious ownership" errors on host-mounted repositories
if command -v git >/dev/null 2>&1; then
  git config --global --add safe.directory '*' 2>/dev/null || true
fi

# Print concise environment summary only for interactive shells
if [[ -t 1 ]]; then
  profile="${OSS_CONTRIB_PROFILE:-unknown}"
  arch="$(uname -m)"
  cpus="$(nproc 2>/dev/null || echo '?')"
  mem_total="$(awk '/MemTotal/ {printf "%.1f GiB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo '?')"

  accel="CPU-only"
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    gpu_count="$(nvidia-smi -L | wc -l | tr -d ' ')"
    first_gpu="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || echo 'NVIDIA GPU')"
    accel="NVIDIA (${gpu_count}x ${first_gpu})"
  elif command -v rocm-smi >/dev/null 2>&1 && [[ -e /dev/kfd ]]; then
    accel="AMD ROCm (/dev/kfd detected)"
  elif [[ -d /dev/dri ]] || [[ -d /dev/accel ]]; then
    accel="Accelerator device detected (/dev/dri or /dev/accel)"
  fi

  echo "============================================================"
  echo " oss-contrib container | profile: ${profile} | arch: ${arch}"
  echo " Resources: ${cpus} vCPU, ${mem_total} RAM | Accel: ${accel}"
  echo " Workspace: /workspace/oss-contrib | Cache: /cache"
  echo " Tip: run 'mkvenv <aimet|mori|lmcache|sglang-omni|custom>' to create a project venv"
  echo "============================================================"
fi

exec "$@"
