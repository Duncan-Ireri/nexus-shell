#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

step "Done"

cat <<EOF

nexus-shell is installed, with ${NEXUS_COMPOSITOR:-your compositor} configured
to launch it on startup.

  Log out and back in, selecting ${NEXUS_COMPOSITOR:-Hyprland/Niri} at your
  display/login manager, to start using it.

Useful commands:
  nexus-shell theme list / theme set <name>   switch themes
  nexus-shell bar <cmd>                       control the bar
  nexus-shell plugin list                     manage plugins
  nexus --help                                the full shell CLI

Log file: $NEXUS_INSTALL_LOG

EOF
