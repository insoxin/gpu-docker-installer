#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================

# GPU Docker Installer

# Ubuntu + NVIDIA Driver + Docker + NVIDIA Container Toolkit

#

# GitHub:

#   gpu-docker-installer

#

# Supported:

#   Ubuntu 22.04 / 24.04

#   amd64 / arm64

# ============================================================

SCRIPT_NAME="GPU Docker Installer"

SCRIPT_VERSION="1.0.0"

RED='\033[0;31m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

BLUE='\033[0;34m'

NC='\033[0m'

log() {

    echo -e "${BLUE}[INFO]${NC} $*"

}

success() {

    echo -e "${GREEN}[ OK ]${NC} $*"

}

warn() {

    echo -e "${YELLOW}[WARN]${NC} $*"

}

error() {

    echo -e "${RED}[ERROR]${NC} $*" >&2

}

trap 'error "安装失败，行号: ${LINENO}"' ERR

# ------------------------------------------------------------

# Root

# ------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then

    error "请使用 root 用户运行此脚本。"

    echo

    echo "例如："

    echo "  sudo bash install-gpu-docker.sh"

    exit 1

fi

# ------------------------------------------------------------

# OS check

# ------------------------------------------------------------

if [[ ! -f /etc/os-release ]]; then

    error "无法检测操作系统。"

    exit 1

fi

source /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then

    error "当前系统不是 Ubuntu。"

    error "检测到: ${PRETTY_NAME}"

    exit 1

fi

case "${VERSION_ID}" in

    22.04|24.04)

        ;;

    *)

        error "不支持的 Ubuntu 版本: ${VERSION_ID}"

        error "支持: Ubuntu 22.04 / 24.04"

        exit 1

        ;;

esac

ARCH="$(dpkg --print-architecture)"

echo

echo "============================================================"

echo " ${SCRIPT_NAME} v${SCRIPT_VERSION}"

echo "============================================================"

echo

echo "系统     : ${PRETTY_NAME}"

echo "架构     : ${ARCH}"

echo "内核     : $(uname -r)"

echo

# ------------------------------------------------------------

# Basic packages

# ------------------------------------------------------------

log "安装基础依赖..."

apt-get update

apt-get install -y \

    ca-certificates \

    curl \

    gnupg \

    lsb-release \

    ubuntu-drivers-common

success "基础依赖安装完成。"

# ------------------------------------------------------------

# NVIDIA Driver

# ------------------------------------------------------------

echo

echo "============================================================"

echo " NVIDIA Driver"

echo "============================================================"

if command -v nvidia-smi >/dev/null 2>&1; then

    success "检测到 NVIDIA Driver。"

    nvidia-smi --query-gpu=name,driver_version,memory.total \

        --format=csv,noheader || true

else

    warn "未检测到 NVIDIA Driver。"

    log "检测系统推荐 NVIDIA Driver..."

    ubuntu-drivers devices || true

    echo

    log "安装系统推荐 NVIDIA Driver..."

    ubuntu-drivers install

    echo

    success "NVIDIA Driver 安装完成。"

    if ! command -v nvidia-smi >/dev/null 2>&1; then

        warn "nvidia-smi 当前不可用。"

        echo

        echo "通常需要重启服务器才能加载 NVIDIA Driver。"

        echo

        echo "请执行："

        echo

        echo "  reboot"

        echo

        echo "重启后重新运行本脚本即可继续。"

        exit 0

    fi

fi

# ------------------------------------------------------------

# Docker

# ------------------------------------------------------------

echo

echo "============================================================"

echo " Docker"

echo "============================================================"

if command -v docker >/dev/null 2>&1; then

    success "检测到 Docker：$(docker --version)"

else

    log "安装 Docker CE..."

    # Remove conflicting packages

    apt-get remove -y \

        docker.io \

        docker-compose \

        docker-compose-v2 \

        docker-doc \

        podman-docker \

        containerd \

        runc \

        2>/dev/null || true

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL \

        https://download.docker.com/linux/ubuntu/gpg \

        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    cat > /etc/apt/sources.list.d/docker.sources <<EOF

Types: deb

URIs: https://download.docker.com/linux/ubuntu

Suites: ${UBUNTU_CODENAME:-${VERSION_CODENAME}}

Components: stable

Architectures: ${ARCH}

Signed-By: /etc/apt/keyrings/docker.asc

EOF

    apt-get update

    apt-get install -y \

        docker-ce \

        docker-ce-cli \

        containerd.io \

        docker-buildx-plugin \

        docker-compose-plugin

    systemctl enable docker

    systemctl restart docker

    success "Docker 安装完成。"

fi

systemctl enable docker >/dev/null 2>&1 || true

systemctl start docker >/dev/null 2>&1 || true

echo

docker --version

docker compose version

# ------------------------------------------------------------

# NVIDIA Container Toolkit

# ------------------------------------------------------------

echo

echo "============================================================"

echo " NVIDIA Container Toolkit"

echo "============================================================"

if dpkg -s nvidia-container-toolkit >/dev/null 2>&1; then

    success "检测到 NVIDIA Container Toolkit。"

else

    log "添加 NVIDIA Container Toolkit 软件源..."

    install -m 0755 -d /usr/share/keyrings

    curl -fsSL \

        https://nvidia.github.io/libnvidia-container/gpgkey \

        | gpg --dearmor \

        -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    curl -s -L \

        https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \

        | sed \

        's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \

        > /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get update

    apt-get install -y nvidia-container-toolkit

    success "NVIDIA Container Toolkit 安装完成。"

fi

# ------------------------------------------------------------

# Configure Docker

# ------------------------------------------------------------

echo

echo "============================================================"

echo " 配置 Docker NVIDIA Runtime"

echo "============================================================"

nvidia-ctk runtime configure --runtime=docker

systemctl restart docker

success "Docker NVIDIA Runtime 配置完成。"

# ------------------------------------------------------------

# Host GPU test

# ------------------------------------------------------------

echo

echo "============================================================"

echo " NVIDIA GPU Test"

echo "============================================================"

if ! command -v nvidia-smi >/dev/null 2>&1; then

    error "nvidia-smi 不存在。"

    exit 1

fi

nvidia-smi

# ------------------------------------------------------------

# Docker GPU test

# ------------------------------------------------------------

echo

echo "============================================================"

echo " Docker GPU Test"

echo "============================================================"

log "启动 CUDA 测试容器..."

docker run --rm \

    --gpus all \

    nvidia/cuda:12.8.1-base-ubuntu24.04 \

    nvidia-smi

# ------------------------------------------------------------

# Final

# ------------------------------------------------------------

echo

echo "============================================================"

echo " 安装完成"

echo "============================================================"

echo

success "Ubuntu"

success "NVIDIA Driver"

success "Docker"

success "NVIDIA Container Toolkit"

success "Docker GPU Runtime"

echo

echo "GPU："

nvidia-smi --query-gpu=index,name,memory.total,driver_version \

    --format=csv

echo

echo "Docker："

docker --version

echo

echo "Docker Compose："

docker compose version

echo

echo "============================================================"

echo " GPU Docker 环境已经可以使用。"

echo "============================================================"

echo

echo "下一步可以部署："

echo

echo "  vLLM"

echo "  DeepSeek-V4.1-Flash"

echo "  Open WebUI"

echo "  OpenAI Compatible API"

echo
