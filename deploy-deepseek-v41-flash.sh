#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================

# DeepSeek-V4.1-Flash Docker Installer

#

# Hardware:

#   8 × NVIDIA H200 141GB

#

# Runtime:

#   vLLM 0.30.0+

#   CUDA Docker

#

# API:

#   OpenAI Compatible API

#   http://0.0.0.0:8000/v1

# ============================================================

APP_NAME="deepseek-v41-flash"

MODEL="deepseek-ai/DeepSeek-V4.1-Flash"

IMAGE="vllm/vllm-openai:deepseekv41-flash-0909"

DATA_DIR="/data/deepseek-v41-flash"

HF_CACHE="${DATA_DIR}/huggingface"

LOG_DIR="${DATA_DIR}/logs"

CONTAINER_NAME="deepseek-v41-flash"

PORT="8000"

TP_SIZE="8"

# ------------------------------------------------------------

# Colors

# ------------------------------------------------------------

RED='\033[0;31m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

BLUE='\033[0;34m'

NC='\033[0m'

info() {

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

trap 'error "部署失败，行号: ${LINENO}"' ERR

# ------------------------------------------------------------

# Root

# ------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then

    error "请使用 root 运行。"

    echo

    echo "例如："

    echo "  sudo bash deploy-deepseek-v41-flash.sh"

    exit 1

fi

# ------------------------------------------------------------

# Banner

# ------------------------------------------------------------

clear || true

echo

echo "============================================================"

echo " DeepSeek-V4.1-Flash"

echo " 8 × NVIDIA H200 141GB"

echo "============================================================"

echo

echo "Model:"

echo "  ${MODEL}"

echo

echo "vLLM:"

echo "  ${IMAGE}"

echo

echo "Tensor Parallel:"

echo "  ${TP_SIZE}"

echo

echo "API:"

echo "  http://0.0.0.0:${PORT}/v1"

echo

echo "============================================================"

echo

# ------------------------------------------------------------

# Check Docker

# ------------------------------------------------------------

info "检查 Docker..."

if ! command -v docker >/dev/null 2>&1; then

    error "未检测到 Docker。"

    error "请先运行 Ubuntu + NVIDIA + Docker 安装脚本。"

    exit 1

fi

docker --version

# ------------------------------------------------------------

# Check Docker GPU

# ------------------------------------------------------------

info "检查 NVIDIA Docker Runtime..."

if ! docker info 2>/dev/null | grep -qi "nvidia"; then

    warn "Docker 信息中没有明显显示 NVIDIA Runtime。"

    warn "继续进行 GPU 测试..."

fi

# ------------------------------------------------------------

# Check nvidia-smi

# ------------------------------------------------------------

if ! command -v nvidia-smi >/dev/null 2>&1; then

    error "没有找到 nvidia-smi。"

    exit 1

fi

echo

info "检测 NVIDIA GPU..."

GPU_COUNT=$(nvidia-smi --query-gpu=index --format=csv,noheader | wc -l)

echo

nvidia-smi --query-gpu=index,name,memory.total,driver_version \

    --format=csv

echo

if [[ "${GPU_COUNT}" -ne 8 ]]; then

    error "检测到 ${GPU_COUNT} 张 GPU。"

    error "本脚本针对 8 × H200 141GB。"

    exit 1

fi

# Check H200

H200_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | grep -ci "H200" || true)

if [[ "${H200_COUNT}" -ne 8 ]]; then

    warn "检测到的 GPU 不完全是 H200。"

    warn "实际 GPU："

    nvidia-smi --query-gpu=name --format=csv,noheader

    echo

    read -r -p "仍然继续部署？[y/N] " answer

    if [[ ! "${answer}" =~ ^[Yy]$ ]]; then

        echo "已取消。"

        exit 0

    fi

fi

success "GPU 检查通过。"

# ------------------------------------------------------------

# Check GPU Docker

# ------------------------------------------------------------

echo

info "测试 Docker GPU..."

docker run --rm \

    --gpus all \

    nvidia/cuda:12.8.1-base-ubuntu24.04 \

    nvidia-smi >/dev/null

success "Docker GPU Runtime 正常。"

# ------------------------------------------------------------

# Create directories

# ------------------------------------------------------------

echo

info "创建模型目录..."

mkdir -p "${HF_CACHE}"

mkdir -p "${LOG_DIR}"

chmod 755 "${DATA_DIR}"

success "目录创建完成：${DATA_DIR}"

# ------------------------------------------------------------

# Check disk

# ------------------------------------------------------------

echo

info "检查磁盘空间..."

df -h "${DATA_DIR}"

AVAILABLE_GB=$(df -BG "${DATA_DIR}" | awk 'NR==2 {gsub("G","",$4); print $4}')

echo

echo "模型 checkpoint 大约需要 511GB。"

echo "建议至少预留 700GB，推荐 1TB+。"

echo

echo "当前可用空间：${AVAILABLE_GB} GB"

echo

if [[ "${AVAILABLE_GB}" -lt 700 ]]; then

    warn "当前可用磁盘空间低于 700GB。"

    warn "模型下载/缓存可能失败。"

    read -r -p "仍然继续？[y/N] " answer

    if [[ ! "${answer}" =~ ^[Yy]$ ]]; then

        echo "已取消。"

        exit 0

    fi

fi

# ------------------------------------------------------------

# Pull image

# ------------------------------------------------------------

echo

info "拉取官方 vLLM DeepSeek V4.1 Flash 镜像..."

docker pull "${IMAGE}"

success "vLLM 镜像准备完成。"

# ------------------------------------------------------------

# Stop old container

# ------------------------------------------------------------

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then

    warn "检测到旧容器：${CONTAINER_NAME}"

    info "停止旧容器..."

    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

    success "旧容器已删除。"

fi

# ------------------------------------------------------------

# Start container

# ------------------------------------------------------------

echo

echo "============================================================"

echo " 启动 DeepSeek-V4.1-Flash"

echo "============================================================"

echo

docker run -d \

    --name "${CONTAINER_NAME}" \

    --restart unless-stopped \

    --gpus all \

    --privileged \

    --ipc=host \

    -p "${PORT}:8000" \

    -v "${HF_CACHE}:/root/.cache/huggingface" \

    -e VLLM_ENGINE_READY_TIMEOUT_S=3600 \

    -e VLLM_USE_RUST_FRONTEND=1 \

    "${IMAGE}" \

    "${MODEL}" \

    --tokenizer-mode deepseek_v41 \

    --tensor-parallel-size "${TP_SIZE}" \

    --tool-call-parser deepseek_v41 \

    --enable-auto-tool-choice \

    --reasoning-parser deepseek_v41 \

    --mm-encoder-tp-mode data \

    --gpu-memory-utilization 0.95 \

    --max-num-batched-tokens 8192 \

    --max-num-seqs 256 \

    --max-model-len auto

success "DeepSeek-V4.1-Flash 容器已经启动。"

# ------------------------------------------------------------

# Status

# ------------------------------------------------------------

echo

echo "============================================================"

echo " 容器状态"

echo "============================================================"

docker ps \

    --filter "name=${CONTAINER_NAME}" \

    --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# ------------------------------------------------------------

# Logs

# ------------------------------------------------------------

echo

echo "============================================================"

echo " 启动日志"

echo "============================================================"

echo

sleep 3

docker logs --tail 50 "${CONTAINER_NAME}" || true

# ------------------------------------------------------------

# Final

# ------------------------------------------------------------

echo

echo "============================================================"

echo " 部署完成"

echo "============================================================"

echo

echo "模型："

echo "  ${MODEL}"

echo

echo "容器："

echo "  ${CONTAINER_NAME}"

echo

echo "API："

echo "  http://服务器IP:${PORT}/v1"

echo

echo "模型首次启动需要加载约 511GB checkpoint。"

echo "第一次启动可能需要较长时间。"

echo

echo "查看实时日志："

echo

echo "  docker logs -f ${CONTAINER_NAME}"

echo

echo "查看 GPU："

echo

echo "  watch -n 1 nvidia-smi"

echo

echo "检查 API："

echo

echo "  curl http://127.0.0.1:${PORT}/v1/models"

echo

echo "测试对话："

echo

echo "  curl http://127.0.0.1:${PORT}/v1/chat/completions \\"

echo "    -H 'Content-Type: application/json' \\"

echo "    -d '{"

echo '      "model": "deepseek-ai/DeepSeek-V4.1-Flash",'

echo '      "messages": [{"role": "user", "content": "你好，请介绍一下自己"}],'

echo '      "max_tokens": 512'

echo "    }'"

echo

echo "============================================================"
