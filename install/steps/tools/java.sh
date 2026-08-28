#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"
# shellcheck source=./_mise.sh
source "$SCRIPT_DIR/_mise.sh"

step "Java"

ensure_mise
info "Installing Java (Temurin LTS), Maven, and Gradle via mise..."
mise use --global java@temurin-lts
mise use --global maven@latest
mise use --global gradle@latest

ok "Java ($(mise exec java@temurin-lts -- java --version | head -1)) installed via mise — pin per-project versions with 'mise use java@21' etc"
