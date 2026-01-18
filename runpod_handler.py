import runpod, requests, time, os, base64

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
COMFY_URL = "http://127.0.0.1:8188"
VISION_MODEL = "huihui_ai/qwen3-vl-abliterated"

def wait_for_services():
    # 确保双服务在线后再处理请求
    while True:
        try:
            if requests.get(f"{COMFY_URL}/history", timeout=2).status_code == 200:
                break
        except:
            time.sleep(5)

def handler(job):
    job_input = job["input"]
    
    # --- 场景 1: 视觉逆向分析 (如果有图片输入) ---
    if "image" in job_input:
        print("🔍 [Mode: Vision] 触发 GPU 加速分析...")
        payload = {
            "model": VISION_MODEL,
            "prompt": job_input.get("prompt", "请详细描述这张图片。"),
            "stream": False,
            "images": [job_input["image"]],
            "options": {
                "num_gpu": 99,  # 强制要求将所有模型层推入 GPU
                "num_ctx": 8192, 
                "temperature": 0.4
            }
        }
        try:
            start_time = time.time()
            res = requests.post(OLLAMA_URL, json=payload, timeout=300)
            res.raise_for_status()
            print(f"⚡ 分析完成，耗时: {time.time()-start_time:.2f}s")
            return {"status": "success", "type": "vision", "content": res.json().get("response")}
        except Exception as e:
            return {"status": "error", "message": f"Ollama GPU 调用失败: {str(e)}"}

    # --- 场景 2: ComfyUI 画图 (引用参考信息 3) ---
    else:
        print("🎨 [Mode: Generation] 触发 ComfyUI 绘图...")
        prompt_text = job_input.get("prompt", "a beautiful girl")
        output_dir = "/comfyui/output"
        old_files = set(os.listdir(output_dir)) if os.path.exists(output_dir) else set()

        workflow = {
            "39": {"inputs": {"clip_name": "qwen_3_4_b.safetensors", "type": "lumina2", "device": "default"}, "class_type": "CLIPLoader"},
            "40": {"inputs": {"vae_name": "ae.safetensors"}, "class_type": "VAELoader"},
            "41": {"inputs": {"width": 1024, "height": 1024, "batch_size": 1}, "class_type": "EmptySD3LatentImage"},
            "45": {"inputs": {"text": prompt_text, "clip": ["39", 0]}, "class_type": "CLIPTextEncode"},
            "42": {"inputs": {"conditioning": ["45", 0]}, "class_type": "ConditioningZeroOut"},
            "46": {"inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": "default"}, "class_type": "UNETLoader"},
            "47": {"inputs": {"shift": 3.0, "model": ["46", 0]}, "class_type": "ModelSamplingAuraFlow"},
            "44": {"inputs": {"seed": int(time.time()), "steps": 9, "cfg": 1.0, "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0, "model": ["47", 0], "positive": ["45", 0], "negative": ["42", 0], "latent_image": ["41", 0]}, "class_type": "KSampler"},
            "43": {"inputs": {"samples": ["44", 0], "vae": ["40", 0]}, "class_type": "VAEDecode"},
            "9": {"inputs": {"filename_prefix": "z-image", "images": ["43", 0]}, "class_type": "SaveImage"}
        }

        try:
            res = requests.post(f"{COMFY_URL}/prompt", json={"prompt": workflow})
            prompt_id = res.json().get("prompt_id")
            for _ in range(150):
                history_res = requests.get(f"{COMFY_URL}/history/{prompt_id}").json()
                if prompt_id in history_res: break
                time.sleep(1)

            new_files = set(os.listdir(output_dir)) - old_files
            if new_files:
                target = sorted([f for f in new_files if f.startswith("z-image")])[-1]
                with open(os.path.join(output_dir, target), "rb") as f:
                    return {"status": "success", "type": "generation", "image": base64.b64encode(f.read()).decode("utf-8")}
            return {"status": "error", "message": "No output files found."}
        except Exception as e:
            return {"error": str(e)}

if __name__ == "__main__":
    wait_for_services()
    runpod.serverless.start({"handler": handler})
