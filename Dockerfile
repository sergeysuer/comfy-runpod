# =============================================================
#  Serge's ComfyUI image - Pod UI + Serverless in ONE image
#  Base: RunPod's official ComfyUI worker (CUDA 12.8 = Blackwell OK)
# =============================================================
# To move to a newer base later, change this ONE line:
ARG BASE_TAG=5.8.5-base-cuda12.8.1
FROM runpod/worker-comfyui:${BASE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1
ENV PYTHONUNBUFFERED=1

# ---- system libraries several custom nodes need ----
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        wget \
        curl \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---- custom nodes (driven by nodes.txt) ----
COPY nodes.txt /build/nodes.txt
COPY scripts/install_nodes.sh /build/install_nodes.sh
RUN chmod +x /build/install_nodes.sh && /build/install_nodes.sh

# ---- our dual-mode launcher ----
# NOTE: named serge_start.sh so we do NOT clobber the base image's /start.sh
COPY scripts/start.sh /serge_start.sh
RUN chmod +x /serge_start.sh

# ---- defaults ----
# MODE=serverless  -> RunPod job handler (Photoshop plugin, API)
# MODE=pod         -> ComfyUI web UI on port 8188
ENV MODE=serverless
ENV COMFY_PORT=8188

EXPOSE 8188

CMD ["/serge_start.sh"]
