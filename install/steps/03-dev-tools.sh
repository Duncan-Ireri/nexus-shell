#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

step "Developer tooling"

# label -> script, in menu order
declare -A TOOL_SCRIPT=(
    ["Docker & Docker Compose"]="docker.sh"
    ["Node.js / JavaScript (via mise)"]="node.sh"
    ["Python (via mise + uv)"]="python.sh"
    ["Java (via mise: Temurin + Maven + Gradle)"]="java.sh"
    ["Machine Learning extras (JupyterLab, CUDA if NVIDIA)"]="ml.sh"
    ["Terminal & shell (kitty, tmux, starship, zsh + oh-my-zsh)"]="terminal.sh"
)
TOOL_ORDER=(
    "Docker & Docker Compose"
    "Node.js / JavaScript (via mise)"
    "Python (via mise + uv)"
    "Java (via mise: Temurin + Maven + Gradle)"
    "Machine Learning extras (JupyterLab, CUDA if NVIDIA)"
    "Terminal & shell (kitty, tmux, starship, zsh + oh-my-zsh)"
)

selected=()
if [ -n "${NEXUS_TOOLS:-}" ]; then
    # Non-interactive: NEXUS_TOOLS=docker,node,python,java,ml,terminal
    IFS=',' read -ra requested <<<"$NEXUS_TOOLS"
    for r in "${requested[@]}"; do
        case "$r" in
            docker) selected+=("Docker & Docker Compose") ;;
            node) selected+=("Node.js / JavaScript (via mise)") ;;
            python) selected+=("Python (via mise + uv)") ;;
            java) selected+=("Java (via mise: Temurin + Maven + Gradle)") ;;
            ml) selected+=("Machine Learning extras (JupyterLab, CUDA if NVIDIA)") ;;
            terminal) selected+=("Terminal & shell (kitty, tmux, starship, zsh + oh-my-zsh)") ;;
            *) warn "unknown NEXUS_TOOLS entry '$r', skipping" ;;
        esac
    done
else
    mapfile -t selected < <(ask_multi "Pick the developer tooling to install (space to toggle, enter to confirm)" "${TOOL_ORDER[@]}")
fi

if [ "${#selected[@]}" -eq 0 ]; then
    info "No optional tooling selected."
else
    # Each tool script runs in its own process with its own `set -e`, so a
    # real bug or a network hiccup inside e.g. java.sh aborts *that script*
    # — but must not take down node.sh/python.sh/the rest of the installer
    # with it. Failures are collected and reported, not swallowed: this is
    # "don't let one thing ruin everything else," not "hide problems."
    failed=()
    for label in "${selected[@]}"; do
        script="${TOOL_SCRIPT[$label]:-}"
        [ -z "$script" ] && { warn "no script mapped for '$label', skipping"; continue; }
        if ! bash "$SCRIPT_DIR/tools/$script"; then
            warn "$label had a problem and may be incomplete — see $NEXUS_INSTALL_LOG. Continuing with the rest."
            failed+=("$label")
        fi
    done

    if [ "${#failed[@]}" -gt 0 ]; then
        warn "These tooling steps didn't finish cleanly, re-run them individually once fixed:"
        for label in "${failed[@]}"; do
            warn "  - $label -> bash $SCRIPT_DIR/tools/${TOOL_SCRIPT[$label]}"
        done
    fi
fi

ok "Developer tooling step complete"
