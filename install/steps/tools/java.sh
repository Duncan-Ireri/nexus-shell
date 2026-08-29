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

# mise has no "temurin-lts" alias — resolve a concrete Temurin LTS spec,
# newest first, falling back to mise's generic "lts" if none match.
java_spec=""
for cand in temurin-25 temurin-21 lts; do
    if mise latest "java@$cand" >/dev/null 2>&1; then
        java_spec="java@$cand"
        break
    fi
done

java_ok=1
if [ -n "$java_spec" ] && mise use --global "$java_spec"; then
    ok "Java ($(mise exec "$java_spec" -- java --version 2>/dev/null | head -1)) installed via mise — pin per-project versions with 'mise use java@21' etc"
else
    warn "java install failed, retry later: mise use --global java@temurin-25"
    java_ok=0
fi

mise use --global maven@latest || warn "maven install failed, retry later: mise use --global maven@latest"
mise use --global gradle@latest || warn "gradle install failed, retry later: mise use --global gradle@latest"

[ "$java_ok" -eq 1 ] || warn "Java did not install successfully"
