#!/usr/bin/env bash
set -euo pipefail

# Common base tooling installer shared across CPU / NVIDIA / ROCm / Other images.
# Designed for Ubuntu 22.04/24.04 and Debian-based vendor images (amd64 & arm64).

APT_MIRROR="${APT_MIRROR:-}"
INSTALL_GH_CLI="${INSTALL_GH_CLI:-true}"
INSTALL_CPP_EXTRA="${INSTALL_CPP_EXTRA:-true}"
USERNAME="${USERNAME:-dev}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"

export DEBIAN_FRONTEND=noninteractive

if ! command -v apt-get >/dev/null 2>&1; then
  echo "[ERROR] install-common.sh currently supports Debian/Ubuntu (apt-get) base images." >&2
  exit 1
fi

# Optional APT mirror override (supports Ubuntu 24.04 DEB822 and legacy sources.list, amd64 & arm64).
# Defaults to http:// when no scheme is provided, because minimal base images lack ca-certificates
# before the first apt-get install.
if [[ -n "${APT_MIRROR}" ]]; then
  MIRROR_URL="${APT_MIRROR%/}"
  if [[ "${MIRROR_URL}" != http://* && "${MIRROR_URL}" != https://* ]]; then
    MIRROR_URL="http://${MIRROR_URL}"
  fi
  echo "[INFO] Switching APT mirror to ${MIRROR_URL}"
  for src in /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources; do
    if [[ -f "${src}" ]]; then
      sed -i -E "s#https?://([a-z0-9-]+\.)?(archive|security|ports)\.ubuntu\.com#${MIRROR_URL}#g" "${src}"
    fi
  done
fi

apt-get update
apt-get install -y --no-install-recommends \
  bash-completion \
  build-essential \
  ca-certificates \
  ccache \
  cmake \
  curl \
  gdb \
  git \
  git-lfs \
  gnupg \
  htop \
  jq \
  less \
  libffi-dev \
  libssl-dev \
  locales \
  lsb-release \
  ninja-build \
  openssh-client \
  patchelf \
  pkg-config \
  procps \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv \
  ripgrep \
  rsync \
  sudo \
  tmux \
  unzip \
  vim \
  wget \
  xz-utils \
  zlib1g-dev

if [[ "${INSTALL_CPP_EXTRA}" == "true" ]]; then
  # System headers/libs commonly needed by ROCm/mori (UMBP io_uring, RDMA verbs, NUMA, MPI),
  # LMCache C++ extensions, and general AI Infra C++ unit tests.
  apt-get install -y --no-install-recommends \
    ibverbs-utils \
    libgtest-dev \
    libibverbs-dev \
    libnuma-dev \
    libopenmpi-dev \
    libprotobuf-dev \
    liburing-dev \
    openmpi-bin \
    protobuf-compiler \
    strace
fi

# Configure UTF-8 locale
locale-gen en_US.UTF-8 || true

# Optional GitHub CLI installation (soft-fail if network blocks cli.github.com)
if [[ "${INSTALL_GH_CLI}" == "true" ]] && ! command -v gh >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  if curl -fsSL --connect-timeout 10 --max-time 30 \
      https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; then
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list
    apt-get update && apt-get install -y --no-install-recommends gh || \
      echo "[WARN] Failed to install gh CLI; continuing without it."
  else
    echo "[WARN] Could not reach cli.github.com; continuing without gh CLI."
  fi
fi

# Clean apt caches
rm -rf /var/lib/apt/lists/*

# Create or adapt non-root developer user when USER_UID != 0.
# Handles Ubuntu 24.04's pre-existing 'ubuntu' (1000:1000) user gracefully.
if [[ "${USER_UID}" != "0" ]]; then
  EXISTING_GROUP="$(getent group "${USER_GID}" | cut -d: -f1 || true)"
  if [[ -z "${EXISTING_GROUP}" ]]; then
    groupadd --gid "${USER_GID}" "${USERNAME}"
    TARGET_GROUP="${USERNAME}"
  else
    TARGET_GROUP="${EXISTING_GROUP}"
  fi

  EXISTING_USER="$(getent passwd "${USER_UID}" | cut -d: -f1 || true)"
  if [[ -z "${EXISTING_USER}" ]]; then
    useradd --uid "${USER_UID}" --gid "${TARGET_GROUP}" -m -s /bin/bash "${USERNAME}"
  elif [[ "${EXISTING_USER}" != "${USERNAME}" ]]; then
    usermod -l "${USERNAME}" "${EXISTING_USER}"
    if [[ ! -d "/home/${USERNAME}" ]]; then
      usermod -d "/home/${USERNAME}" -m "${USERNAME}"
    fi
    usermod -s /bin/bash "${USERNAME}"
  else
    usermod -s /bin/bash "${USERNAME}"
  fi

  # Add to common device/admin groups if present
  for grp in sudo video render; do
    if getent group "${grp}" >/dev/null 2>&1; then
      usermod -aG "${grp}" "${USERNAME}" || true
    fi
  done

  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${USERNAME}"
  chmod 0440 "/etc/sudoers.d/90-${USERNAME}"

  TARGET_OWNER="${USER_UID}:${USER_GID}"
else
  TARGET_OWNER="0:0"
fi

# Prepare persistent cache & workspace directories
mkdir -p \
  /workspace/oss-contrib \
  /opt/uv-python \
  /cache/uv \
  /cache/pip \
  /cache/huggingface \
  /cache/torch \
  /cache/ccache \
  /cache/triton \
  /cache/venvs

chown -R "${TARGET_OWNER}" /workspace /opt/uv-python /cache
