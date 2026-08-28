#!/usr/bin/env bash
# nexus-shell bootstrap installer.
#
#   curl -fsSL https://raw.githubusercontent.com/Duncan-Ireri/nexus-shell/main/install.sh | bash
#
# This file is deliberately tiny: when piped through `curl | bash`, stdin is
# the script itself, not a terminal, so nothing here can be interactive. All
# this does is get a full checkout of the repo onto disk, then hand off to
# install/install.sh with stdin explicitly reattached to the terminal — that
# script does the real (interactive) work. Running it directly from an
# existing checkout (./install.sh) skips the clone and just re-execs local
# install/install.sh the same way, so both paths behave identically.
set -euo pipefail

REPO_URL="${NEXUS_SHELL_REPO_URL:-https://github.com/Duncan-Ireri/nexus-shell.git}"
CLONE_DIR="${NEXUS_SHELL_CLONE_DIR:-$HOME/.local/share/nexus-shell-src}"

# BASH_SOURCE[0] is unset when this script is fed to bash via a pipe
# (`curl ... | bash`) rather than run as a file — ${BASH_SOURCE[0]:-} avoids
# tripping `set -u` in that case, falling through to the clone path below.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || true)"

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install/install.sh" ]; then
    # Running from an actual checkout (./install.sh), not piped.
    REAL_INSTALLER="$SCRIPT_DIR/install/install.sh"
else
    command -v git >/dev/null 2>&1 || { echo "git is required — install it and re-run." >&2; exit 1; }

    fresh_clone() {
        echo "Cloning nexus-shell to $CLONE_DIR..."
        rm -rf "$CLONE_DIR"
        local n=1
        until git clone --depth 1 "$REPO_URL" "$CLONE_DIR"; do
            [ "$n" -ge 3 ] && { echo "git clone failed after 3 attempts — check your network." >&2; exit 1; }
            echo "clone failed (attempt $n/3), retrying in 2s..." >&2
            rm -rf "$CLONE_DIR"
            sleep 2
            n=$((n + 1))
        done
    }

    if [ -d "$CLONE_DIR/.git" ]; then
        echo "Updating existing checkout at $CLONE_DIR..."
        # A shallow clone (--depth 1) can't fast-forward past a rewritten
        # remote history, and a previous run could have left this checkout
        # mid-way through something. Rather than get the user stuck on a
        # git error they didn't ask for, fall back to a clean re-clone.
        git -C "$CLONE_DIR" pull --ff-only || fresh_clone
    else
        fresh_clone
    fi
    REAL_INSTALLER="$CLONE_DIR/install/install.sh"
fi

[ -f "$REAL_INSTALLER" ] || { echo "could not find install/install.sh — checkout looks broken" >&2; exit 1; }
chmod +x "$REAL_INSTALLER"

if [ -t 0 ]; then
    exec bash "$REAL_INSTALLER" "$@"
elif ( : </dev/tty ) 2>/dev/null; then
    # stdin is the curl pipe, not a terminal — reattach the real terminal so
    # the interactive prompts in install.sh actually work. Probed in a
    # subshell first: a /dev/tty node can exist but not actually be openable
    # (e.g. no controlling terminal at all), and a subshell test discards
    # that failed redirect cleanly instead of crashing the real exec below.
    exec bash "$REAL_INSTALLER" "$@" </dev/tty
else
    echo "No terminal available for interactive prompts. Re-run with --non-interactive --compositor=<hyprland|niri>, e.g.:" >&2
    echo "  bash $REAL_INSTALLER --non-interactive --compositor=hyprland" >&2
    exit 1
fi
