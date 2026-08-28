#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"
# shellcheck source=./_mise.sh
source "$SCRIPT_DIR/_mise.sh"

step "Machine Learning tooling"

ensure_mise
mise use --global python@latest
pacman_install uv

info "Installing JupyterLab as a uv tool (isolated, on PATH via 'jupyter lab')..."
uv tool install jupyterlab || warn "jupyterlab install failed, retry later: uv tool install jupyterlab"

if has_nvidia_gpu; then
    info "NVIDIA GPU detected."
    if [ "$NEXUS_NONINTERACTIVE" = "1" ] || ask_confirm "Install CUDA + cuDNN + PyTorch (CUDA build)? This is a multi-GB download." "no"; then
        pacman_install cuda cudnn python-pytorch-cuda
        ok "CUDA toolkit and PyTorch (CUDA) installed"
    else
        info "Skipped CUDA/PyTorch. Install later with: sudo pacman -S cuda cudnn python-pytorch-cuda"
    fi
else
    info "No NVIDIA GPU detected — skipping CUDA/PyTorch-CUDA. For CPU-only PyTorch in a project:"
    info "  uv add torch --index-url https://download.pytorch.org/whl/cpu"
fi

ok "ML tooling ready — start a project with: uv venv && uv add numpy pandas scikit-learn"
