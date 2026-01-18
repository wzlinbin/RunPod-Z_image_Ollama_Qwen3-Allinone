#!/bin/bash
echo "🚀 [Pre-start] 正在初始化双 GPU 加速环境 (Ollama + ComfyUI)..."

# 1. 强制声明驱动与引擎路径 (复刻昨日成功经验)
export OLLAMA_LIBRARY_PATH="/usr/lib/ollama"
export LD_LIBRARY_PATH="/usr/lib/ollama:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH"
export CUDA_VISIBLE_DEVICES=0

# 2. 执行 ComfyUI 架构修复 (引用参考信息 2)
pip install --upgrade pip --quiet
pip install --no-cache-dir transformers==4.47.0 accelerate==0.34.0 requests runpod --quiet
find /usr/local/lib/python3.10/dist-packages/transformers -name "*.pyc" -delete
find /comfyui -name "*.pyc" -delete
cd /comfyui && git fetch --all && git reset --hard origin/master

# 3. 关键：先启动 Ollama 并给它时间锁定 GPU 句柄
echo "🧪 正在唤醒 Ollama GPU 引擎..."
ollama serve > /var/log/ollama.log 2>&1 &
sleep 10  # 给予充足时间让 Ollama 完成显存探测

# 4. 启动 ComfyUI (引用参考信息 1)
echo "🎨 正在启动 ComfyUI 后端..."
python /comfyui/main.py --listen 127.0.0.1 --port 8188 > /var/log/comfyui.log 2>&1 &

# 5. 健康检查
echo "⏳ 等待双服务就绪..."
python3 -c "import requests, time;
def check():
    try:
        ollama_ok = requests.get('http://127.0.0.1:11434/api/tags').status_code == 200
        comfy_ok = requests.get('http://127.0.0.1:8188/history').status_code == 200
        return ollama_ok and comfy_ok
    except: return False
for i in range(60):
    if check(): print('✅ 双后端 GPU 环境全部 Ready!'); break
    time.sleep(5)
"

# 6. 启动主 Handler
python -u /comfyui/runpod_handler.py
