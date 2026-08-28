#!/usr/bin/env bash
# Shared prerequisite for node.sh / python.sh / java.sh — not a menu entry
# itself (leading underscore). Ensures mise is installed and activated.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

ensure_mise() {
    if ! is_installed mise; then
        info "Installing mise (polyglot runtime version manager)..."
        pacman_install mise
    fi
    require_installed mise "mise"

    append_once "$HOME/.zshrc" "# nexus-shell: mise activation" \
        '# nexus-shell: mise activation
eval "$(mise activate zsh)"'
    append_once "$HOME/.bashrc" "# nexus-shell: mise activation" \
        '# nexus-shell: mise activation
eval "$(mise activate bash)"'

    eval "$(mise activate bash)"
}
