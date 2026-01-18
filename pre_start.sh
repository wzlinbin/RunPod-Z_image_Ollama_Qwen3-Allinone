#!/bin/bash
echo "🚀 [Pre-start] 正在初始化双 GPU 加速环境..."

# 1. 核心修复：强制声明驱动与引擎路径 (复刻昨日成功经验)
export OLLAMA_LIBRARY_PATH="/usr/lib/ollama"
export LD_LIBRARY_PATH="/usr/lib/ollama:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH"
export CUDA_VISIBLE_DEVICES=0

# 2. ComfyUI 架构修复 (引用参考逻辑)
pip install --upgrade pip --quiet
pip install --no-cache-dir transformers==4.47.0 accelerate==0.34.0 requests runpod --quiet
find /usr/local/lib/python3.10/dist-packages/transformers -name "*.pyc" -delete
find /comfyui -name "*.pyc" -delete
cd /comfyui && git fetch --all && git reset --hard origin/master

# 3. 关键：先启动 Ollama 并给它 5 秒时间锁定显存句柄
echo "🧪 正在抢占 GPU 句柄给 Ollama..."
ollama serve > /var/log/ollama.log 2>&1 &
sleep 5

# 4. 启动 ComfyUI
echo "🎨 正在启动 ComfyUI..."
python /comfyui/main.py --listen 127.0.0.1 --port 8188 > /var/log/comfyui.log 2>&1 &

# 5. 启动任务处理器
python -u /comfyui/runpod_handler.py
