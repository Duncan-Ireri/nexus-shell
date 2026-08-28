#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

step "Docker"

pacman_install docker docker-compose docker-buildx lazydocker
sudo systemctl enable --now docker.socket || warn "could not enable docker.socket — start it manually later: sudo systemctl enable --now docker.socket"
require_installed docker "Docker"
require_installed docker-compose "Docker Compose"

# Docker's daemon runs as root and its socket is root-owned, so membership in
# the `docker` group is equivalent to passwordless root: anything in that
# group can `docker run -v /:/host ...` and rewrite the host as root. We warn
# and default to "no" rather than silently granting it, then fall back to
# `sudo docker` — that's a one-word cost for a real security boundary.
if id -nG "$USER" 2>/dev/null | grep -qw docker; then
    info "$USER is already in the docker group."
elif [ "$NEXUS_NONINTERACTIVE" = "1" ]; then
    warn "Non-interactive install: not adding $USER to the docker group (equivalent to passwordless root). Use 'sudo docker' or add yourself manually: sudo usermod -aG docker \$USER"
else
    echo
    warn "Adding yourself to the 'docker' group lets you run 'docker' without sudo,"
    warn "but it is equivalent to passwordless root — anything in that group can"
    warn "mount and rewrite the host filesystem via a container."
    if ask_confirm "Add $USER to the docker group anyway?" "no"; then
        sudo usermod -aG docker "$USER"
        warn "Group membership takes effect after you log out and back in."
    else
        info "Skipped. Use 'sudo docker ...' or add yourself later: sudo usermod -aG docker \$USER"
    fi
fi

ok "Docker installed"
