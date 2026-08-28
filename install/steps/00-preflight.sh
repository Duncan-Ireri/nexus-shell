#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

step "Preflight checks"

require_arch
require_not_root
clear_stale_pacman_lock

info "Refreshing package databases..."
retry 3 sudo pacman -Sy --noconfirm >/dev/null || fail "pacman -Sy failed after 3 attempts — check your network/mirrors"

if ! is_installed gum; then
    info "Installing gum (used for the rest of this installer's prompts)..."
    pacman_install gum
fi
require_installed gum

step "Installing baseline packages (Wayland session essentials + CLI toolkit)"
pacman_install_list "$INSTALL_ROOT/packages/base.packages"
require_installed qs "quickshell"

ok "Preflight complete"
