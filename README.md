# gpu-docker-installer

一键在 H200 上部署 DeepSeek-V4.1-Flash。

## 快速开始

### 第一步：安装 GPU Docker 环境

```bash
curl -fsSL https://raw.githubusercontent.com/insoxin/gpu-docker-installer/main/install-gpu-docker.sh | bash
```

### 第二步：部署 DeepSeek-V4.1-Flash

```bash
curl -fsSL https://raw.githubusercontent.com/insoxin/gpu-docker-installer/main/deploy-deepseek-v41-flash.sh | bash
```

## 部署流程

1. 检查 Ubuntu
2. 检查 Docker
3. 检查 NVIDIA
4. 确认 8 张 GPU
5. 确认 H200
6. 测试 Docker GPU
7. 检查磁盘
8. 拉取 vLLM 官方镜像
9. 创建 `/data/deepseek-v41-flash`
10. 下载 DeepSeek-V4.1-Flash
11. 启用 8 GPU Tensor Parallel
12. 启动 OpenAI Compatible API

## 接口测试

```bash
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
```
