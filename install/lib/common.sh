#!/usr/bin/env bash
# Shared helpers for the nexus-shell installer. Sourced, not executed.
# Every function here assumes `set -euo pipefail` is active in the caller.

NEXUS_INSTALL_LOG="${NEXUS_INSTALL_LOG:-$HOME/.local/state/NexusShell/install.log}"

nexus_log_line() {
    mkdir -p "$(dirname "$NEXUS_INSTALL_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$NEXUS_INSTALL_LOG"
}

# --- output -----------------------------------------------------------

info()  { echo -e "\033[1;34m::\033[0m $*"; nexus_log_line "INFO  $*"; }
ok()    { echo -e "\033[1;32m✓\033[0m $*"; nexus_log_line "OK    $*"; }
warn()  { echo -e "\033[1;33m!\033[0m $*" >&2; nexus_log_line "WARN  $*"; }
fail()  { echo -e "\033[1;31m✗\033[0m $*" >&2; nexus_log_line "FAIL  $*"; exit 1; }

step() {
    echo
    echo -e "\033[1;36m==>\033[0m \033[1m$*\033[0m"
    nexus_log_line "==== $* ===="
}

# --- gum-backed prompts, with a plain-bash fallback --------------------
# gum is installed as the very first thing install.sh does, so in practice
# these always hit the gum path — the fallback exists so a step script
# stays testable/runnable even if invoked before that (e.g. `--dry-run`).

have_gum() { command -v gum >/dev/null 2>&1; }

# ask_choice "Prompt" opt1 opt2 ... -> echoes the chosen option
ask_choice() {
    local prompt="$1"; shift
    if have_gum; then
        gum choose --header "$prompt" "$@"
    else
        echo "$prompt" >&2
        select opt in "$@"; do
            [ -n "${opt:-}" ] && { echo "$opt"; return 0; }
        done
    fi
}

# ask_multi "Prompt" opt1 opt2 ... -> echoes chosen options, one per line
ask_multi() {
    local prompt="$1"; shift
    if have_gum; then
        gum choose --no-limit --header "$prompt" "$@"
    else
        echo "$prompt (space-separated numbers, e.g. 1 3 4)" >&2
        local i=1
        for opt in "$@"; do echo "  $i) $opt" >&2; i=$((i + 1)); done
        read -r -p "> " picks
        for n in $picks; do
            echo "${@:$n:1}"
        done
    fi
}

# ask_confirm "Prompt" [default: yes|no] -> returns 0/1
ask_confirm() {
    local prompt="$1" default="${2:-no}"
    if have_gum; then
        if [ "$default" = "yes" ]; then
            gum confirm --default=true "$prompt"
        else
            gum confirm --default=false "$prompt"
        fi
    else
        local suffix="[y/N]"
        [ "$default" = "yes" ] && suffix="[Y/n]"
        read -r -p "$prompt $suffix " reply
        reply="${reply:-$default}"
        [[ "$reply" =~ ^([yY]|[yY][eE][sS])$ ]]
    fi
}

# --- package installation ----------------------------------------------

NEXUS_NONINTERACTIVE="${NEXUS_NONINTERACTIVE:-0}"

pacman_install() {
    local pkgs=("$@")
    [ "${#pkgs[@]}" -eq 0 ] && return 0
    info "Installing: ${pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${pkgs[@]}" || fail "pacman failed to install: ${pkgs[*]}"
}

# Install a package list file (one package per line, '#' comments, blanks ok).
pacman_install_list() {
    local file="$1"
    [ -f "$file" ] || fail "package list not found: $file"
    local pkgs=()
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [ -n "$line" ] && pkgs+=("$line")
    done <"$file"
    pacman_install "${pkgs[@]}"
}

require_installed() {
    local bin="$1" what="${2:-$1}"
    command -v "$bin" >/dev/null 2>&1 || fail "$what did not install correctly (no '$bin' on PATH)"
    ok "$what is installed"
}

is_installed() { command -v "$1" >/dev/null 2>&1; }

# --- idempotent file edits ----------------------------------------------

# append_once <file> <marker> <content>
# Appends <content> to <file> unless a line containing <marker> is already
# present, so re-running the installer never duplicates entries. Creates the
# file (and parent dir) if missing. Never overwrites existing unrelated
# content — this is an append-only operation.
append_once() {
    local file="$1" marker="$2" content="$3"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -qF "$marker" "$file" 2>/dev/null; then
        return 0
    fi
    printf '\n%s\n' "$content" >>"$file"
}

# --- misc -----------------------------------------------------------

has_nvidia_gpu() {
    command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -qi nvidia
}

require_arch() {
    [ -f /etc/os-release ] || fail "cannot detect OS (no /etc/os-release)"
    # shellcheck disable=SC1091
    source /etc/os-release
    if [ "${ID:-}" != "arch" ] && [[ "${ID_LIKE:-}" != *arch* ]]; then
        fail "nexus-shell's installer currently targets Arch Linux and derivatives (found ID=${ID:-unknown}). See README.md for the manual install path."
    fi
    command -v pacman >/dev/null 2>&1 || fail "pacman not found — is this really Arch-based?"
}

require_not_root() {
    [ "$EUID" -ne 0 ] || fail "run this as your normal user, not root — it uses sudo where it needs privilege"
}
