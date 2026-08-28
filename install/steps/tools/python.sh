#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"
# shellcheck source=./_mise.sh
source "$SCRIPT_DIR/_mise.sh"

step "Python"

ensure_mise
info "Installing latest Python via mise..."
python_ok=1
mise use --global python@latest || { warn "python install failed, retry later: mise use --global python@latest"; python_ok=0; }

info "Installing uv (package/venv manager) and ruff (linter/formatter)..."
pacman_install uv ruff

if [ "$python_ok" -eq 1 ]; then
    ok "Python ($(mise exec python@latest -- python --version 2>/dev/null)) installed via mise — pin per-project versions with 'mise use python@3.11' etc"
fi
if is_installed uv; then
    info "Use 'uv venv' / 'uv add <pkg>' / 'uv run' for project environments instead of raw pip."
else
    warn "uv did not install — Python package management will need pip manually"
fi
