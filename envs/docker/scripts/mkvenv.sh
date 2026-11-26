#!/usr/bin/env bash
set -euo pipefail

# Helper to create per-project isolated uv virtual environments under /cache/venvs/<profile>/<name>.
# Keeps dependencies cleanly separated across aimet, mori, lmcache, sglang-omni, executorch, etc.

PROFILE="${OSS_CONTRIB_PROFILE:-cpu}"
VENV_ROOT="${OSS_CONTRIB_VENV_ROOT:-/cache/venvs/${PROFILE}}"

usage() {
  cat <<EOF
Usage:
  mkvenv <preset-or-name> [python-version]

Presets:
  aimet         Python 3.10 (default) + PyTorch + pytest + onnx + transformers (for qualcomm/aimet)
  mori          Python 3.12 (default) + pytest + numpy + pybind11 + build tools (for ROCm/mori)
  lmcache       Python 3.12 (default) + PyTorch + pytest + ruff (for LMCache/LMCache)
  sglang-omni   Python 3.12 (default) + PyTorch + pytest + httpx + websockets (for sglang-omni)
  executorch    Python 3.11 (default) + PyTorch + pytest + numpy (for pytorch/executorch)
  <custom>      Any custom venv name with clean Python + pytest

Environment overrides:
  TORCH_INDEX_URL   Override PyTorch wheel index (auto-selected by OSS_CONTRIB_PROFILE otherwise)
  PYTORCH_ROCM_TAG  ROCm wheel channel when profile=rocm (default: rocm6.4, e.g. rocm6.3 / rocm7.1)
  PYTORCH_CUDA_TAG  CUDA wheel channel when profile=nvidia (default: cu128, e.g. cu126 / cu124)
  SKIP_TORCH=1      Skip installing torch (useful when reusing vendor base image PyTorch)
EOF
}

if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
  exit 0
fi

NAME="$1"
PY_OVERRIDE="${2:-}"

case "${NAME}" in
  aimet)
    PY_VER="${PY_OVERRIDE:-3.10}"
    INSTALL_TORCH="true"
    EXTRA_PKGS=(pytest numpy onnx onnxruntime transformers accelerate safetensors)
    ;;
  mori)
    PY_VER="${PY_OVERRIDE:-3.12}"
    INSTALL_TORCH="false"
    EXTRA_PKGS=(pytest numpy pybind11 scikit-build-core ninja)
    ;;
  lmcache)
    PY_VER="${PY_OVERRIDE:-3.12}"
    INSTALL_TORCH="true"
    EXTRA_PKGS=(pytest pytest-asyncio numpy ruff pyyaml msgspec)
    ;;
  sglang-omni)
    PY_VER="${PY_OVERRIDE:-3.12}"
    INSTALL_TORCH="true"
    EXTRA_PKGS=(pytest pytest-asyncio httpx websockets fastapi uvicorn transformers safetensors)
    ;;
  executorch)
    PY_VER="${PY_OVERRIDE:-3.11}"
    INSTALL_TORCH="true"
    EXTRA_PKGS=(pytest numpy pyyaml packaging)
    ;;
  *)
    PY_VER="${PY_OVERRIDE:-3.12}"
    INSTALL_TORCH="false"
    EXTRA_PKGS=(pytest)
    ;;
esac

if [[ "${SKIP_TORCH:-0}" == "1" ]]; then
  INSTALL_TORCH="false"
fi

if [[ -z "${TORCH_INDEX_URL:-}" ]]; then
  case "${PROFILE}" in
    cpu)
      TORCH_INDEX_URL="https://download.pytorch.org/whl/cpu"
      ;;
    nvidia)
      TORCH_INDEX_URL="https://download.pytorch.org/whl/${PYTORCH_CUDA_TAG:-cu128}"
      ;;
    rocm)
      TORCH_INDEX_URL="https://download.pytorch.org/whl/${PYTORCH_ROCM_TAG:-rocm6.4}"
      ;;
    *)
      TORCH_INDEX_URL=""
      ;;
  esac
fi

VENV_DIR="${VENV_ROOT}/${NAME}"
mkdir -p "${VENV_ROOT}"

echo "[INFO] Creating venv: ${VENV_DIR} (profile=${PROFILE}, python=${PY_VER})"
uv venv --python "${PY_VER}" "${VENV_DIR}"

if [[ "${INSTALL_TORCH}" == "true" ]]; then
  if [[ -n "${TORCH_INDEX_URL}" ]]; then
    echo "[INFO] Installing PyTorch from ${TORCH_INDEX_URL}"
    uv pip install --python "${VENV_DIR}/bin/python" --index-url "${TORCH_INDEX_URL}" torch
  else
    echo "[INFO] Installing PyTorch from default index (set TORCH_INDEX_URL or SKIP_TORCH=1 for vendor builds)"
    uv pip install --python "${VENV_DIR}/bin/python" torch
  fi
fi

if [[ ${#EXTRA_PKGS[@]} -gt 0 ]]; then
  echo "[INFO] Installing base packages: ${EXTRA_PKGS[*]}"
  uv pip install --python "${VENV_DIR}/bin/python" "${EXTRA_PKGS[@]}"
fi

cat <<EOF

[DONE] Virtual environment ready: ${VENV_DIR}
Activate with:
  source ${VENV_DIR}/bin/activate
EOF
