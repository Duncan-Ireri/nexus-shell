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
java_ok=1
mise use --global java@temurin-lts || { warn "java install failed, retry later: mise use --global java@temurin-lts"; java_ok=0; }
mise use --global maven@latest || warn "maven install failed, retry later: mise use --global maven@latest"
mise use --global gradle@latest || warn "gradle install failed, retry later: mise use --global gradle@latest"

if [ "$java_ok" -eq 1 ]; then
    ok "Java ($(mise exec java@temurin-lts -- java --version 2>/dev/null | head -1)) installed via mise — pin per-project versions with 'mise use java@21' etc"
else
    warn "Java did not install successfully"
fi
