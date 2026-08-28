#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"
# shellcheck source=./_mise.sh
source "$SCRIPT_DIR/_mise.sh"

step "Node.js / JavaScript"

ensure_mise
info "Installing Node.js LTS via mise..."
if mise use --global node@lts; then
    info "Enabling corepack (pnpm + yarn, pinned per-project via package.json)..."
    mise exec node@lts -- corepack enable || warn "corepack enable failed, you can retry: mise exec node@lts -- corepack enable"
    ok "Node.js ($(mise exec node@lts -- node --version 2>/dev/null)) installed via mise — pin per-project versions with 'mise use node@20' etc"
else
    warn "node install failed, retry later: mise use --global node@lts"
fi
