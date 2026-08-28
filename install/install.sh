#!/usr/bin/env bash
# The real nexus-shell installer. Meant to be run directly with a terminal
# attached (the root install.sh bootstrap execs into this after cloning the
# repo) — not piped, since it's interactive by default.
set -euo pipefail

export INSTALL_ROOT
INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$INSTALL_ROOT/lib/common.sh"

usage() {
    cat <<'EOF'
Usage: install/install.sh [options]

  --yes, --non-interactive   Don't prompt; requires --compositor and uses
                              sensible defaults (no optional dev tooling
                              unless --tools is also given; no login manager
                              unless --display-manager is also given).
  --compositor=<hyprland|niri>
  --tools=<comma-separated>  docker,node,python,java,ml,terminal
  --browser=<firefox|chromium|none>   default web browser (default: firefox)
  --wallpaper=<path>         image to install as the default wallpaper
                              (default: assets/wallpapers/trigonometry.png)
  --display-manager          set up greetd + the nexus greeter (prompted for
                              in interactive mode; this forces it on for --yes)
  -h, --help
EOF
}

for arg in "$@"; do
    case "$arg" in
        --yes|--non-interactive) NEXUS_NONINTERACTIVE=1 ;;
        --compositor=*) NEXUS_COMPOSITOR="${arg#--compositor=}" ;;
        --tools=*) NEXUS_TOOLS="${arg#--tools=}" ;;
        --browser=*) NEXUS_BROWSER="${arg#--browser=}" ;;
        --wallpaper=*) NEXUS_WALLPAPER="${arg#--wallpaper=}" ;;
        --display-manager) NEXUS_DISPLAY_MANAGER=1 ;;
        -h|--help) usage; exit 0 ;;
        # A bare path to an image file is taken as the default wallpaper, so
        #   ... | bash -s -- /path/to/wall.png
        # works as a shorthand for --wallpaper=/path/to/wall.png.
        /*|./*|~*) [ -f "$arg" ] && NEXUS_WALLPAPER="$arg" || fail "unknown argument: $arg (see --help)" ;;
        *) fail "unknown option: $arg (see --help)" ;;
    esac
done
export NEXUS_NONINTERACTIVE="${NEXUS_NONINTERACTIVE:-0}"
export NEXUS_COMPOSITOR="${NEXUS_COMPOSITOR:-}"
export NEXUS_TOOLS="${NEXUS_TOOLS:-}"
export NEXUS_BROWSER="${NEXUS_BROWSER:-firefox}"
export NEXUS_WALLPAPER="${NEXUS_WALLPAPER:-}"
export NEXUS_DISPLAY_MANAGER="${NEXUS_DISPLAY_MANAGER:-0}"

if [ -n "$NEXUS_WALLPAPER" ] && [ ! -f "$NEXUS_WALLPAPER" ]; then
    fail "--wallpaper: no such file: $NEXUS_WALLPAPER"
fi

if [ "$NEXUS_NONINTERACTIVE" = "1" ] && [ -z "$NEXUS_COMPOSITOR" ]; then
    fail "--non-interactive requires --compositor=hyprland or --compositor=niri"
fi

echo "nexus-shell installer"
echo "======================"
echo "Log: $NEXUS_INSTALL_LOG"

bash "$INSTALL_ROOT/steps/00-preflight.sh"

# Resolved here (not inside 01-compositor.sh) so the choice is exported in
# this process before any later step forks as a subshell — a child bash
# process can't export a variable back up to us.
if [ -z "$NEXUS_COMPOSITOR" ]; then
    NEXUS_COMPOSITOR="$(ask_choice "nexus-shell needs a Wayland compositor. Which one?" "Hyprland" "Niri")"
fi
export NEXUS_COMPOSITOR
bash "$INSTALL_ROOT/steps/01-compositor.sh"
bash "$INSTALL_ROOT/steps/02-shell.sh"
bash "$INSTALL_ROOT/steps/03-desktop.sh"
bash "$INSTALL_ROOT/steps/04-dev-tools.sh"
bash "$INSTALL_ROOT/steps/05-summary.sh"
