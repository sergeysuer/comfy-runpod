#!/usr/bin/env bash
# Dual-mode launcher.
#   MODE=pod         -> ComfyUI web UI on port 8188
#   MODE=serverless  -> RunPod job handler (default)
set -uo pipefail

echo "==========================================="
echo "  ComfyUI container starting"
echo "==========================================="

# ---------------------------------------------------------
# 1. Find the network volume.
#    RunPod mounts it at /runpod-volume on Serverless
#    and at /workspace on Pods.
# ---------------------------------------------------------
VOL=""
if [ -d /runpod-volume ]; then
    VOL="/runpod-volume"
elif [ -d /workspace ]; then
    VOL="/workspace"
fi

if [ -n "$VOL" ]; then
    echo "[start] network volume found at: $VOL"
    mkdir -p "$VOL/models" "$VOL/output" "$VOL/input" "$VOL/user" 2>/dev/null || true

    # Point ComfyUI at the volume for models. Folder names match
    # your existing local EZI layout so workflows transfer 1:1.
    cat > /comfyui/extra_model_paths.yaml <<EOF
runpod_volume:
    base_path: ${VOL}/
    checkpoints: models/checkpoints
    clip: models/clip
    clip_vision: models/clip_vision
    configs: models/configs
    controlnet: models/controlnet
    diffusion_models: models/diffusion_models
    embeddings: models/embeddings
    gligen: models/gligen
    hypernetworks: models/hypernetworks
    loras: models/loras
    model_patches: models/model_patches
    photomaker: models/photomaker
    sams: models/sams
    style_models: models/style_models
    text_encoders: models/text_encoders
    ultralytics: models/ultralytics
    ultralytics_bbox: models/ultralytics/bbox
    ultralytics_segm: models/ultralytics/segm
    unet: models/unet
    upscale_models: models/upscale_models
    vae: models/vae
    vae_approx: models/vae_approx
EOF
    echo "[start] wrote /comfyui/extra_model_paths.yaml"
else
    echo "[start] WARNING: no network volume mounted."
    echo "[start] ComfyUI will only see models baked into the image (none)."
fi

# ---------------------------------------------------------
# 2. Branch on MODE
# ---------------------------------------------------------
MODE="${MODE:-serverless}"
echo "[start] MODE=$MODE"
echo "==========================================="

if [ "$MODE" = "pod" ]; then
    # ---- interactive web UI ----
    PORT="${COMFY_PORT:-8188}"
    echo "[start] launching ComfyUI web UI on port $PORT"
    cd /comfyui
    # shellcheck disable=SC2086
    exec python -u main.py --listen 0.0.0.0 --port "$PORT" ${EXTRA_ARGS:-}
else
    # ---- serverless handler ----
    echo "[start] launching RunPod serverless handler"
    if [ -x /start.sh ]; then
        exec /start.sh                 # base image's own entrypoint
    elif [ -f /handler.py ]; then
        exec python -u /handler.py
    else
        echo "[start] FATAL: no handler found in this image."
        exit 1
    fi
fi
