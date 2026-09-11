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
    #
    # Models may sit under $VOL/models (this image's layout) OR under
    # $VOL/ComfyUI/models (the older runpod/comfyui template kept them there).
    # Register every "models/" root we can find so nothing is missed.
    emit_model_paths() {   # $1 = yaml key   $2 = base path (with trailing /)
        cat >> /comfyui/extra_model_paths.yaml <<EOF
$1:
    base_path: $2
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
    }

    : > /comfyui/extra_model_paths.yaml
    emit_model_paths runpod_volume "${VOL}/"

    if [ -d "${VOL}/ComfyUI/models" ]; then
        emit_model_paths runpod_volume_legacy "${VOL}/ComfyUI/"
        echo "[start] legacy model root registered: ${VOL}/ComfyUI/models"
    fi
    # catch any other nested layout, e.g. $VOL/<something>/models/checkpoints
    n=0
    while IFS= read -r ckpt; do
        base="$(dirname "$(dirname "$ckpt")")"
        case "$base/" in
            "${VOL}/"|"${VOL}/ComfyUI/") continue ;;
        esac
        n=$((n + 1))
        emit_model_paths "runpod_volume_extra_${n}" "${base}/"
        echo "[start] extra model root registered: ${base}/models"
    done < <(find "$VOL" -mindepth 3 -maxdepth 4 -type d -path '*/models/checkpoints' 2>/dev/null)

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

    # Send generated images to the network volume, not the container's
    # ephemeral disk, so they survive pod termination and show up over
    # the S3 API (same reasoning as the models path fix above).
    OUTPUT_ARGS=""
    if [ -n "$VOL" ]; then
        OUTPUT_ARGS="--output-directory ${VOL}/output"
        echo "[start] output directory: ${VOL}/output"
    else
        echo "[start] WARNING: no network volume mounted, outputs will not persist."
    fi

    # shellcheck disable=SC2086
    exec python -u main.py --listen 0.0.0.0 --port "$PORT" $OUTPUT_ARGS ${EXTRA_ARGS:-}
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
