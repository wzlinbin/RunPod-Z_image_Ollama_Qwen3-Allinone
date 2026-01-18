#!/bin/bash
echo "🚀 [Pre-start] 正在启动整合环境 (Ollama GPU + ComfyUI)..."

# 1. 环境变量强制加载 (完全复刻昨日成功配置)
export OLLAMA_LIBRARY_PATH=/usr/lib/ollama
export LD_LIBRARY_PATH=/usr/lib/ollama:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH
export CUDA_VISIBLE_DEVICES=0

# 2. ComfyUI 深度架构修复 (参考信息 2)
find /usr/local/lib/python3.10/dist-packages/transformers -name "*.pyc" -delete
find /comfyui -name "*.pyc" -delete
cd /comfyui && git fetch --all && git reset --hard origin/master

# 3. 修复权限与目录 (参考信息 2)
mkdir -p "/comfyui/tmp" "/comfyui/output"
chmod -R 777 "/comfyui/tmp" "/comfyui/output"
export TMPDIR="/comfyui/tmp"

# 4. 启动 Ollama 后台服务 (完全复刻昨日成功指令)
ollama serve > /var/log/ollama.log 2>&1 &

# 5. 健康检查：等待 Ollama 就绪 (完全复刻昨日成功指令)
python3 -c "import requests, time; 
for i in range(30):
    try:
        r = requests.get('http://127.0.0.1:11434/api/tags')
        if r.status_code == 200:
            print('✅ Ollama GPU 模型已就绪'); break
    except: pass
    time.sleep(2)
"

# 6. 启动 ComfyUI 后端 (参考信息 1)
python /comfyui/main.py --listen 127.0.0.1 --port 8188 > /var/log/comfyui.log 2>&1 &

# 7. 启动主任务监听 (runpod_handler.py)
python -u /comfyui/runpod_handler.py
