#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

NEXUS_ROOT="$(cd "$INSTALL_ROOT/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
# nexus setup shells out to a privesc helper for the input-group / session bits;
# pin it so it never stops to prompt which tool to use.
export NEXUS_PRIVESC="${NEXUS_PRIVESC:-sudo}"

COMPOSITOR_LOWER="$(echo "${NEXUS_COMPOSITOR:-}" | tr '[:upper:]' '[:lower:]')"
[ -n "$COMPOSITOR_LOWER" ] || fail "NEXUS_COMPOSITOR not set (install.sh resolves this before this step)"

# ---------------------------------------------------------------------------
step "Desktop: terminal + browser"
# ---------------------------------------------------------------------------

pacman_install_list "$INSTALL_ROOT/packages/desktop.packages"

BROWSER_APP="${NEXUS_BROWSER:-firefox}"
case "$BROWSER_APP" in
    none|"") info "No browser requested (--browser=none)." ;;
    *)       pacman_install "$BROWSER_APP" ;;
esac

TERMINAL_CHOICE=kitty
is_installed kitty || { TERMINAL_CHOICE=ghostty; warn "kitty not installed — deploying configs for 'ghostty' instead"; }

# XDG user dirs (~/Pictures etc.) — the wallpaper lands in ~/Pictures/Wallpapers.
is_installed xdg-user-dirs-update && xdg-user-dirs-update || true

# ---------------------------------------------------------------------------
step "Deploying $COMPOSITOR_LOWER + $TERMINAL_CHOICE configuration"
# ---------------------------------------------------------------------------

# `nexus setup` deploys the real compositor config: keybinds, window rules,
# layout, colours, plus the terminal config. --systemd=false because this
# installer does not ship a dms.service user unit — the compositor spawns the
# shell directly (hl.exec_cmd("dms run") / spawn-at-startup "dms" "run").
already_deployed() {
    case "$COMPOSITOR_LOWER" in
        hyprland) [ -f "$HOME/.config/hypr/hyprland.lua" ] ;;
        niri)     [ -f "$HOME/.config/niri/dms/binds.kdl" ] ;;
        mango)    [ -f "$HOME/.config/mango/dms/binds.conf" ] ;;
        *)        return 1 ;;
    esac
}

if ! is_installed nexus; then
    warn "nexus binary missing — skipping config deployment (re-run steps/02-shell.sh)"
elif already_deployed; then
    info "Compositor config already deployed — leaving it (run 'nexus setup' to redeploy)"
else
    if nexus setup --yes --compositor="$COMPOSITOR_LOWER" --terminal="$TERMINAL_CHOICE" --systemd=false; then
        ok "Compositor + terminal configuration deployed"
    else
        warn "nexus setup did not finish cleanly — run it manually later: nexus setup"
    fi
fi

# The shipped keybinds and session-start hooks call "dms"; this fork installs
# the same binary as "nexus". A symlink makes the deployed configs work as-is.
if is_installed nexus && ! is_installed dms; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v nexus)" "$HOME/.local/bin/dms"
    info "Linked ~/.local/bin/dms -> nexus (keybind/session compatibility)"
fi

# ---------------------------------------------------------------------------
step "Default web browser"
# ---------------------------------------------------------------------------

case "$BROWSER_APP" in
    none|"") info "Skipping default-browser setup." ;;
    *)
        BROWSER_DESKTOP="${BROWSER_APP}.desktop"
        if is_installed "$BROWSER_APP" && is_installed xdg-settings; then
            xdg-settings set default-web-browser "$BROWSER_DESKTOP" 2>/dev/null \
                || warn "could not set $BROWSER_APP as the default browser"
            if is_installed xdg-mime; then
                xdg-mime default "$BROWSER_DESKTOP" \
                    x-scheme-handler/http x-scheme-handler/https text/html 2>/dev/null || true
            fi
            append_once "$HOME/.profile" "# nexus-shell: default browser" \
                "# nexus-shell: default browser
export BROWSER=\"\${BROWSER:-$BROWSER_APP}\""
            ok "$BROWSER_APP set as the default web browser"
        else
            warn "$BROWSER_APP not installed — default-browser handler left unchanged"
        fi
        ;;
esac

# ---------------------------------------------------------------------------
step "Default wallpaper"
# ---------------------------------------------------------------------------

WALLPAPER_SRC="${NEXUS_WALLPAPER:-$NEXUS_ROOT/assets/wallpapers/trigonometry.png}"
SESSION_JSON="$HOME/.local/state/NexusShell/session.json"

if [ ! -f "$WALLPAPER_SRC" ]; then
    warn "wallpaper not found at $WALLPAPER_SRC — skipping"
else
    WALL_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"
    mkdir -p "$WALL_DIR"
    WALL_DEST="$WALL_DIR/$(basename "$WALLPAPER_SRC")"
    [ -f "$WALL_DEST" ] || cp "$WALLPAPER_SRC" "$WALL_DEST"

    mkdir -p "$(dirname "$SESSION_JSON")"

    if ! is_installed jq; then
        warn "jq not available — set the wallpaper from the shell (SUPER+Y) later"
    else
        current_wp=""
        if [ -f "$SESSION_JSON" ]; then
            current_wp="$(jq -r '.wallpaperPath // ""' "$SESSION_JSON" 2>/dev/null || true)"
        fi

        tmp="$(mktemp)"
        wrote=0
        if [ -n "$current_wp" ]; then
            info "session.json already has a wallpaper set — leaving it"
        elif [ -f "$SESSION_JSON" ]; then
            jq --arg p "$WALL_DEST" \
                '. + {wallpaperPath: $p, wallpaperPathLight: $p, wallpaperPathDark: $p}' \
                "$SESSION_JSON" >"$tmp" 2>/dev/null && wrote=1
        else
            jq -n --arg p "$WALL_DEST" \
                '{configVersion: 4, wallpaperPath: $p, wallpaperPathLight: $p, wallpaperPathDark: $p}' \
                >"$tmp" 2>/dev/null && wrote=1
        fi

        if [ "$wrote" = "1" ]; then
            mv "$tmp" "$SESSION_JSON"
            ok "Default wallpaper set: $WALL_DEST"
        else
            rm -f "$tmp"
            [ -n "$current_wp" ] || warn "could not update $SESSION_JSON — set the wallpaper from the shell later"
        fi
    fi
fi

# ---------------------------------------------------------------------------
step "Login manager (greetd + nexus greeter)"
# ---------------------------------------------------------------------------

want_dm=0
if [ "${NEXUS_NONINTERACTIVE:-0}" = "1" ]; then
    if [ "${NEXUS_DISPLAY_MANAGER:-0}" = "1" ]; then
        want_dm=1
    else
        info "Skipping login manager (pass --display-manager to set up greetd)."
    fi
elif ask_confirm "Set up greetd + the nexus greeter as your graphical login manager?" "yes"; then
    want_dm=1
fi

if [ "$want_dm" = "1" ]; then
    if systemctl list-unit-files 2>/dev/null | grep -qE '^(gdm|sddm|lightdm|lxdm|ly)\.service'; then
        warn "another display manager is already installed — skipping greetd to avoid a conflict"
    else
        pacman_install greetd greetd-dms-greeter-git
        if ! is_installed dms-greeter; then
            warn "greetd-dms-greeter-git did not install (AUR build may have failed) — set up a login manager manually"
        elif dms-greeter install --yes; then
            if [ -f /etc/greetd/config.toml ]; then
                if sudo systemctl enable greetd.service; then
                    ok "greetd enabled — graphical login on next boot"
                else
                    warn "could not enable greetd.service — enable it manually: sudo systemctl enable greetd"
                fi
            else
                warn "dms-greeter install produced no /etc/greetd/config.toml — greetd left disabled"
            fi
        else
            warn "dms-greeter install failed — greetd left disabled (see $NEXUS_INSTALL_LOG)"
        fi
    fi
fi

ok "Desktop step complete"
