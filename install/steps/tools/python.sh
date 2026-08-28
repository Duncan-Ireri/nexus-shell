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
mise use --global python@latest

info "Installing uv (package/venv manager) and ruff (linter/formatter)..."
pacman_install uv ruff

ok "Python ($(mise exec python@latest -- python --version)) installed via mise — pin per-project versions with 'mise use python@3.11' etc"
info "Use 'uv venv' / 'uv add <pkg>' / 'uv run' for project environments instead of raw pip."
