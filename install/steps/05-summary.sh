#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

step "Done"

greetd_note="Log out and back in, choosing ${NEXUS_COMPOSITOR:-Hyprland/Niri} at
  your login manager, to start using it."
if systemctl is-enabled greetd.service >/dev/null 2>&1; then
    greetd_note="Reboot — greetd will show the nexus greeter; pick
  ${NEXUS_COMPOSITOR:-your compositor} there and log in."
fi

cat <<EOF

nexus-shell is installed with ${NEXUS_COMPOSITOR:-your compositor}, kitty, and
a browser configured, keybinds deployed, and a default wallpaper set.

  $greetd_note

Open a new terminal (or run: export PATH="\$HOME/.local/bin:\$PATH") so the
nexus commands below are found in your current session.

Handy keybinds (once you're in): SUPER+T terminal, SUPER+space launcher,
SUPER+SHIFT+/ the full cheat sheet.

Useful commands:
  nexus-shell theme list / theme set <name>   switch themes
  nexus-shell bar <cmd>                       control the bar
  nexus-shell plugin list                     manage plugins
  nexus setup                                 re-deploy compositor config
  nexus --help                                the full shell CLI

Log file: $NEXUS_INSTALL_LOG

EOF
