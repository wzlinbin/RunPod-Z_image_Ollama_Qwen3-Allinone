#!/bin/bash
echo "🚀 [Pre-start] 正在执行全量 GPU 链路与架构修复..."

# 1. 设置路径（锁定 Ollama 引擎并保留系统原生 CUDA 路径）
export OLLAMA_LIBRARY_PATH="/usr/lib/ollama"
export LD_LIBRARY_PATH="/usr/lib/ollama:/usr/local/nvidia/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
export CUDA_VISIBLE_DEVICES=0

# 2. 依照参考信息 2 执行深度架构修复：清理缓存并重置 ComfyUI 代码
find /usr/local/lib/python3.10/dist-packages/transformers -name "*.pyc" -delete
find /comfyui -name "*.pyc" -delete
cd /comfyui && git fetch --all && git reset --hard origin/master

# 3. 修复目录与权限 (参考信息 2)
mkdir -p "/comfyui/tmp" "/comfyui/output"
chmod -R 777 "/comfyui/tmp" "/comfyui/output"
export TMPDIR="/comfyui/tmp"

# 4. 启动 Ollama (后台并等待初始化)
ollama serve > /var/log/ollama.log 2>&1 &
sleep 5

# 5. 启动 ComfyUI 画图后端 (参考信息 1)
python /comfyui/main.py --listen 127.0.0.1 --port 8188 > /var/log/comfyui.log 2>&1 &

# 6. 健康检查：确保双服务在线且识别硬件
python3 -c "import requests, time;
for i in range(30):
    try:
        o = requests.get('http://127.0.0.1:11434/api/tags').status_code == 200
        c = requests.get('http://127.0.0.1:8188/history').status_code == 200
        if o and c: print('✅ Dual GPU Backends Loaded!'); break
    except: pass
    time.sleep(5)
"

# 7. 启动 RunPod Handler
python -u /comfyui/runpod_handler.py
