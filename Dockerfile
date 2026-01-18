# 阶段一：提取 Ollama 推理引擎和 Qwen3 模型
FROM ollama/ollama:latest AS ollama-base
RUN ollama serve & sleep 5 && ollama pull huihui_ai/qwen3-vl-abliterated

# 阶段二：主镜像（基于 RunPod ComfyUI）
FROM runpod/worker-comfyui:5.5.1-base

# --- A. 整合 Ollama 与模型 ---
COPY --from=ollama-base /usr/bin/ollama /usr/bin/ollama
COPY --from=ollama-base /usr/lib/ollama /usr/lib/ollama
COPY --from=ollama-base /root/.ollama /root/.ollama

# --- B. 安装 ComfyUI 依赖与模型 ---
RUN pip install --upgrade pip && \
    pip install --no-cache-dir transformers==4.47.0 accelerate==0.34.0 requests runpod

RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors --relative-path models/vae --filename ae.safetensors && \
    comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors --relative-path models/diffusion_models --filename z_image_turbo_bf16.safetensors && \
    comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors --relative-path models/clip --filename qwen_3_4b.safetensors

# --- C. 目录与权限修复 ---
RUN mkdir -p /comfyui/tmp /comfyui/output /app && \
    chmod 1777 /comfyui/tmp /comfyui/output

# --- D. 环境变量 (融合版) ---
ENV OLLAMA_LIBRARY_PATH=/usr/lib/ollama \
    LD_LIBRARY_PATH=/usr/lib/ollama:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    PYTHONUNBUFFERED=1 \
    TMPDIR=/comfyui/tmp

# 建立驱动别名
RUN ln -sf /usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1 /usr/lib/x86_64-linux-gnu/libnvidia-ml.so && \
    ln -sf /usr/lib/x86_64-linux-gnu/libcuda.so.1 /usr/lib/x86_64-linux-gnu/libcuda.so

WORKDIR /comfyui
COPY pre_start.sh runpod_handler.py ./
RUN chmod +x pre_start.sh

CMD ["/bin/bash", "/comfyui/pre_start.sh"]
