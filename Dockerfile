# 阶段一：专门负责拉取 Ollama 模型
FROM ollama/ollama:latest AS ollama-model-puller
# 预拉取 Qwen3-VL (16GB)
RUN ollama serve & sleep 5 && ollama pull huihui_ai/qwen3-vl-abliterated

# 阶段二：构建主运行镜像
FROM runpod/worker-comfyui:5.5.1-base

# 1. 拷贝 Ollama 核心组件 (昨天解决 GPU 的关键)
COPY --from=ollama-model-puller /usr/bin/ollama /usr/bin/ollama
COPY --from=ollama-model-puller /usr/lib/ollama /usr/lib/ollama
COPY --from=ollama-model-puller /root/.ollama /root/.ollama

# 2. 安装 ComfyUI 核心依赖
RUN pip install --upgrade pip && \
    pip install --no-cache-dir transformers==4.47.0 accelerate==0.34.0 requests runpod

# 3. 下载 ComfyUI 相关模型
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors --relative-path models/vae --filename ae.safetensors && \
    comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors --relative-path models/diffusion_models --filename z_image_turbo_bf16.safetensors && \
    comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors --relative-path models/clip --filename qwen_3_4b.safetensors

# 4. 驱动加固 (解决 CPU 回退的核心)
RUN ln -sf /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1 /usr/lib/x86_64-linux-gnu/libnvidia-ml.so && \
    ln -sf /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/lib/x86_64-linux-gnu/libcuda.so

# 5. 目录与权限
RUN mkdir -p /comfyui/tmp /comfyui/output && chmod 1777 /comfyui/tmp /comfyui/output

# 6. 环境参数优化
ENV OLLAMA_LIBRARY_PATH=/usr/lib/ollama \
    LD_LIBRARY_PATH=/usr/lib/ollama:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    PYTHONUNBUFFERED=1 \
    TMPDIR=/comfyui/tmp \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
    OLLAMA_SKIP_CPU_CHECK=1

WORKDIR /comfyui
COPY pre_start.sh runpod_handler.py ./
RUN chmod +x pre_start.sh

CMD ["/bin/bash", "/comfyui/pre_start.sh"]
