#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

step "Building and installing nexus-shell"

NEXUS_ROOT="$(cd "$INSTALL_ROOT/.." && pwd)"

if ! is_installed go; then
    info "Go toolchain not found — installing via pacman..."
    pacman_install go
fi
require_installed go "Go toolchain"

info "Building core/cmd/nexus (embeds the QML shell)..."
(cd "$NEXUS_ROOT/core" && make build) || fail "build failed — see output above"

info "Installing the nexus binary to ~/.local/bin..."
(cd "$NEXUS_ROOT/core" && PREFIX="$HOME/.local" make install) || fail "install failed"

# Put ~/.local/bin on PATH for this session *before* verifying, so the check
# below sees the freshly installed binary even when the user's shell has never
# had ~/.local/bin on PATH. Write it to .profile (login shells) plus .bashrc and
# .zshrc (interactive non-login shells — Arch's default .bash_profile does not
# source .profile), matching how the other steps register shell hooks.
path_line='# nexus-shell: ~/.local/bin on PATH
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
append_once "$HOME/.profile" "# nexus-shell: ~/.local/bin on PATH" "$path_line"
append_once "$HOME/.bashrc" "# nexus-shell: ~/.local/bin on PATH" "$path_line"
append_once "$HOME/.zshrc" "# nexus-shell: ~/.local/bin on PATH" "$path_line"
export PATH="$HOME/.local/bin:$PATH"

require_installed nexus "nexus"

info "Linking nexus-shell CLI tooling (theme, bar, plugin, migrate, dev)..."
mkdir -p "$HOME/.local/bin"
shopt -s nullglob
for script in "$NEXUS_ROOT"/bin/nexus-*; do
    chmod +x "$script"
    ln -sf "$script" "$HOME/.local/bin/$(basename "$script")"
done
shopt -u nullglob

info "Applying the default theme..."
"$HOME/.local/bin/nexus-theme-set" tokyo-night || warn "theme apply failed, you can retry later: nexus-theme-set tokyo-night"

ok "nexus-shell is built and installed"
