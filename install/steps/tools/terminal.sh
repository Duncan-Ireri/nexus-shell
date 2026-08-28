#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

step "Terminal & shell (kitty, tmux, starship, zsh + oh-my-zsh)"

pacman_install kitty tmux starship zsh

# Each block below is independent on purpose: a failed TPM clone shouldn't
# stop starship from activating, and vice versa. `pacman_install` above is
# already best-effort (see common.sh), so a package silently missing here
# just skips its own block via `is_installed` rather than crashing the rest
# of this script.

# --- tmux: TPM + a default config, only if the user doesn't already have one
if is_installed tmux; then
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    # Check for the actual executable, not just the directory — a previous
    # run interrupted mid-clone leaves a directory that looks "installed" but
    # isn't, and `git clone` refuses to clone into a non-empty one.
    if [ ! -x "$TPM_DIR/tpm" ]; then
        info "Installing TPM (tmux plugin manager)..."
        # `git clone` refuses a non-empty target, so a failed first attempt
        # would make attempt 2 fail immediately unless we clean up between
        # tries — hence the `rm -rf` inside the retried command, not before it.
        retry 2 bash -c "rm -rf '$TPM_DIR' && git clone --depth 1 https://github.com/tmux-plugins/tpm '$TPM_DIR'" \
            || warn "TPM clone failed, retry later: git clone https://github.com/tmux-plugins/tpm $TPM_DIR"
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
else
    warn "tmux not installed, skipping tmux setup"
fi

# --- starship: just activate it, config stays wherever the user wants it
if is_installed starship; then
    append_once "$HOME/.zshrc" "# nexus-shell: starship prompt" \
        '# nexus-shell: starship prompt
eval "$(starship init zsh)"'
    append_once "$HOME/.bashrc" "# nexus-shell: starship prompt" \
        '# nexus-shell: starship prompt
eval "$(starship init bash)"'
else
    warn "starship not installed, skipping prompt activation"
fi

# --- zsh + oh-my-zsh: unattended, keeps any existing .zshrc
if is_installed zsh; then
    if [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        rm -rf "$HOME/.oh-my-zsh"
        info "Installing oh-my-zsh (unattended)..."
        # Downloaded to a file rather than run as `sh -c "$(retry ... curl ...)"`:
        # a failed attempt inside that command substitution could leak partial
        # output ahead of a successful retry's output into the same capture,
        # corrupting the script `sh` then executes. A file download either
        # succeeds cleanly or doesn't; retry just re-tries the whole file.
        omz_installer="$(mktemp)"
        if retry 2 curl -fsSL -o "$omz_installer" https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh; then
            RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$omz_installer" "" --unattended --keep-zshrc \
                || warn "oh-my-zsh install failed, you can retry manually later"
        else
            warn "could not download the oh-my-zsh installer, retry later"
        fi
        rm -f "$omz_installer"
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
else
    warn "zsh not installed, skipping oh-my-zsh and shell change"
fi

ok "Terminal tooling installed"
