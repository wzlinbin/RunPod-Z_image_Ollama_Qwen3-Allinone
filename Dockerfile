# 阶段一：预拉取模型，防止构建或运行时因 16GB 大体积下载导致的超时与卡死
FROM ollama/ollama:latest AS ollama-model-puller
RUN ollama serve & sleep 5 && ollama pull huihui_ai/qwen3-vl-abliterated

# 阶段二：主镜像（基于参考信息 1）
FROM runpod/worker-comfyui:5.5.1-base

# 1. 拷贝 Ollama 二进制、推理库及 16GB 模型文件
COPY --from=ollama-model-puller /usr/bin/ollama /usr/bin/ollama
COPY --from=ollama-model-puller /usr/lib/ollama /usr/lib/ollama
COPY --from=ollama-model-puller /root/.ollama /root/.ollama

# 2. 依照参考信息 1 安装 ComfyUI 必要依赖
RUN pip install --upgrade pip && \
    pip install --no-cache-dir transformers==4.47.0 accelerate==0.34.0 requests runpod

# 3. 依照参考信息 1 预载 Z-Image-Turbo 模型
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors --relative-path models/vae --filename ae.safetensors && \
    comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors --relative-path models/diffusion_models --filename z_image_turbo_bf16.safetensors && \
    comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors --relative-path models/clip --filename qwen_3_4b.safetensors

# 4. 关键：建立驱动别名 (解决 A40 驱动穿透与 GPU 识别) [昨日成功核心步骤]
RUN ln -sf /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1 /usr/lib/x86_64-linux-gnu/libnvidia-ml.so && \
    ln -sf /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/lib/x86_64-linux-gnu/libcuda.so

# 5. 环境变量加固：合并系统库与 Ollama 库，确保 PyTorch 不回退到 CPU
ENV OLLAMA_LIBRARY_PATH=/usr/lib/ollama \
    LD_LIBRARY_PATH=/usr/lib/ollama:/usr/local/nvidia/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    PYTHONUNBUFFERED=1 \
    TMPDIR=/comfyui/tmp

RUN mkdir -p /comfyui/tmp /comfyui/output && chmod 1777 /comfyui/tmp /comfyui/output

WORKDIR /comfyui
COPY pre_start.sh runpod_handler.py ./
RUN chmod +x pre_start.sh

CMD ["/bin/bash", "/comfyui/pre_start.sh"]
