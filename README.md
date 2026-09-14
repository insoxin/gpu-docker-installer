# gpu-docker-installer
一键在H200部署 DeepSeek-V4.1-Flash

# 第一步
curl -fsSL https://raw.githubusercontent.com/insoxin/gpu-docker-installer/main/install-gpu-docker.sh | bash

# 第二步
curl -fsSL https://raw.githubusercontent.com/insoxin/gpu-docker-installer/main/deploy-deepseek-v41-flash.sh | bash



检查 Ubuntu
    ↓
检查 Docker
    ↓
检查 NVIDIA
    ↓
确认 8 张 GPU
    ↓
确认 H200
    ↓
测试 Docker GPU
    ↓
检查磁盘
    ↓
拉取 vLLM 官方镜像
    ↓
创建 /data/deepseek-v41-flash
    ↓
下载 DeepSeek-V4.1-Flash
    ↓
8 GPU Tensor Parallel
    ↓
启动 OpenAI Compatible API



````
curl http://127.0.0.1:8000/v1/models

curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-ai/DeepSeek-V4.1-Flash",
    "messages": [
      {
        "role": "user",
        "content": "你好，请用一句话介绍自己。"
      }
    ],
    "max_tokens": 512
  }'
````
