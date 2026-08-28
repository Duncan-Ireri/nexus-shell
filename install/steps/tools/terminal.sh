#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

step "Terminal & shell (kitty, tmux, starship, zsh + oh-my-zsh)"

pacman_install kitty tmux starship zsh

# --- tmux: TPM + a default config, only if the user doesn't already have one
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    info "Installing TPM (tmux plugin manager)..."
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi
if [ ! -f "$HOME/.tmux.conf" ]; then
    info "Writing a default ~/.tmux.conf..."
    cat >"$HOME/.tmux.conf" <<'EOF'
set -g mouse on
set -g default-terminal "tmux-256color"
set -sg escape-time 0
set -g base-index 1
setw -g pane-base-index 1

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'

run '~/.tmux/plugins/tpm/tpm'
EOF
else
    info "~/.tmux.conf already exists — leaving it alone (TPM is installed if you want to add 'run ~/.tmux/plugins/tpm/tpm')"
fi

# --- starship: just activate it, config stays wherever the user wants it
append_once "$HOME/.zshrc" "# nexus-shell: starship prompt" \
    '# nexus-shell: starship prompt
eval "$(starship init zsh)"'
append_once "$HOME/.bashrc" "# nexus-shell: starship prompt" \
    '# nexus-shell: starship prompt
eval "$(starship init bash)"'

# --- oh-my-zsh: unattended, keeps any existing .zshrc
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing oh-my-zsh (unattended)..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc \
        || warn "oh-my-zsh install failed, you can retry manually later"
else
    info "oh-my-zsh already installed"
fi

if [ "$SHELL" != "$(command -v zsh)" ]; then
    if [ "$NEXUS_NONINTERACTIVE" != "1" ] && ask_confirm "Set zsh as your default login shell?" "yes"; then
        chsh -s "$(command -v zsh)" || warn "chsh failed — set it manually later: chsh -s \$(command -v zsh)"
        warn "Takes effect on your next login."
    else
        info "Skipped. Set later with: chsh -s \$(command -v zsh)"
    fi
fi

ok "Terminal tooling installed"
