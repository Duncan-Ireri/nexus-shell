#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

step "Compositor: $NEXUS_COMPOSITOR"

COMPOSITOR="$NEXUS_COMPOSITOR"
[ -n "$COMPOSITOR" ] || fail "NEXUS_COMPOSITOR not set (install.sh should resolve this before calling this step)"
COMPOSITOR_LOWER="$(echo "$COMPOSITOR" | tr '[:upper:]' '[:lower:]')"

case "$COMPOSITOR_LOWER" in
    hyprland)
        pacman_install_list "$INSTALL_ROOT/packages/hyprland.packages"
        require_installed Hyprland "Hyprland"

        # nexus-shell deploys a Lua config (~/.config/hypr/hyprland.lua), which
        # Hyprland auto-loads (in place of hyprland.conf) only on 0.55+. Warn
        # early rather than let the user hit it as a black screen after login.
        hypr_ver="$(Hyprland --version 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v)"
        if [ -n "$hypr_ver" ]; then
            hypr_major="${hypr_ver%%.*}"; hypr_rest="${hypr_ver#*.}"; hypr_minor="${hypr_rest%%.*}"
            if [ "$hypr_major" -eq 0 ] && [ "$hypr_minor" -lt 55 ]; then
                warn "Hyprland $hypr_ver is older than 0.55 — it will not load the Lua config nexus-shell deploys. Update Hyprland before logging in."
            else
                info "Hyprland $hypr_ver (Lua config supported)"
            fi
        fi

        HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
        if [ ! -f "$HYPR_CONF" ]; then
            info "No existing Hyprland config found — writing a minimal default"
            mkdir -p "$(dirname "$HYPR_CONF")"
            cat >"$HYPR_CONF" <<'EOF'
# Minimal config written by the nexus-shell installer.
# Full Hyprland reference: https://wiki.hyprland.org/Configuring/

monitor=,preferred,auto,auto

input {
    kb_layout = us
    follow_mouse = 1
}

general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
}

exec-once = /usr/lib/xdg-desktop-portal-hyprland
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
EOF
        fi
        append_once "$HYPR_CONF" "# nexus-shell autostart" \
            "# nexus-shell autostart
exec-once = nexus"
        ;;

    niri)
        pacman_install_list "$INSTALL_ROOT/packages/niri.packages"
        require_installed niri "Niri"

        NIRI_CONF="$HOME/.config/niri/config.kdl"
        if [ ! -f "$NIRI_CONF" ]; then
            info "No existing Niri config found — writing a minimal default"
            mkdir -p "$(dirname "$NIRI_CONF")"
            cat >"$NIRI_CONF" <<'EOF'
// Minimal config written by the nexus-shell installer.
// Full Niri reference: https://github.com/YaLTeR/niri/wiki/Configuration:-Overview

input {
    keyboard {
        xkb {}
    }
}

layout {
    gaps 8
}
EOF
        fi
        append_once "$NIRI_CONF" "// nexus-shell autostart" \
            '// nexus-shell autostart
spawn-at-startup "nexus"
spawn-at-startup "xdg-desktop-portal-gnome"'
        ;;

    *)
        fail "unknown compositor '$COMPOSITOR' (expected Hyprland or Niri)"
        ;;
esac

ok "$COMPOSITOR installed and configured to launch nexus-shell on startup"
