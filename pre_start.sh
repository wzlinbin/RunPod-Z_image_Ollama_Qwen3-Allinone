#!/bin/bash
echo "🚀 [Pre-start] 正在初始化双 GPU 后端..."

# 1. 强制声明路径优先级 (解决 Ollama 找不到 GPU)
export OLLAMA_LIBRARY_PATH="/usr/lib/ollama"
export LD_LIBRARY_PATH="/usr/lib/ollama:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH"
export CUDA_VISIBLE_DEVICES=0

# 2. ComfyUI 架构修复补丁
find /usr/local/lib/python3.10/dist-packages/transformers -name "*.pyc" -delete
find /comfyui -name "*.pyc" -delete
cd /comfyui && git fetch --all && git reset --hard origin/master

# 3. 优先启动 Ollama 并占住 GPU 句柄
echo "🧪 正在启动视觉分析引擎..."
ollama serve > /var/log/ollama.log 2>&1 &
sleep 10

# 4. 启动 ComfyUI 画图引擎
echo "🎨 正在启动 ComfyUI..."
python /comfyui/main.py --listen 127.0.0.1 --port 8188 > /var/log/comfyui.log 2>&1 &

# 5. 服务健康检查
python3 -c "import requests, time;
for i in range(30):
    try:
        if requests.get('http://127.0.0.1:11434/api/tags').status_code == 200 and \
           requests.get('http://127.0.0.1:8188/history').status_code == 200:
            print('✅ 所有服务已就绪！'); break
    except: pass
    time.sleep(5)
"

# 6. 启动主 Handler
python -u /comfyui/runpod_handler.py
