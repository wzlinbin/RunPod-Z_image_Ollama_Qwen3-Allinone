#!/bin/bash
echo "🚀 [Pre-start] 正在初始化双后端加速环境 (Ollama + ComfyUI)..."

# 1. 执行 ComfyUI 架构修复 (引用自参考信息)
pip install --upgrade pip --quiet
pip install --no-cache-dir transformers==4.47.0 accelerate==0.34.0 requests runpod --quiet
find /usr/local/lib/python3.10/dist-packages/transformers -name "*.pyc" -delete
find /comfyui -name "*.pyc" -delete
cd /comfyui && git fetch --all && git reset --hard origin/master

# 2. 环境变量设置
export OLLAMA_LIBRARY_PATH=/usr/lib/ollama
export LD_LIBRARY_PATH=/usr/lib/ollama:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
export CUDA_VISIBLE_DEVICES=0
export TMPDIR="/comfyui/tmp"

# 3. 启动 Ollama (后台)
ollama serve > /var/log/ollama.log 2>&1 &

# 4. 启动 ComfyUI (后台)
python /comfyui/main.py --listen 127.0.0.1 --port 8188 > /var/log/comfyui.log 2>&1 &

# 5. 健康检查
echo "⏳ 等待所有服务就绪..."
python3 -c "import requests, time;
def check():
    try:
        ollama_ok = requests.get('http://127.0.0.1:11434/api/tags').status_code == 200
        comfy_ok = requests.get('http://127.0.0.1:8188/history').status_code == 200
        return ollama_ok and comfy_ok
    except: return False
for i in range(60):
    if check(): print('✅ 双后端全部 Ready!'); break
    time.sleep(5)
"

# 6. 启动主 Handler
python -u /comfyui/runpod_handler.py
