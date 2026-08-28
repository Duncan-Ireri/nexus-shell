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

# ask_multi "Prompt" opt1 opt2 ... -> echoes chosen options, one per line.
#
# Implemented as a yes/no prompt per option rather than gum's multi-select
# (`gum choose --no-limit`, space to toggle): under the bubble tea v2 rewrite in
# gum 2.0 the space key stopped toggling items in `choose`, so the multi-select
# silently returned nothing. A plain confirm per item works across gum versions
# and degrades cleanly without gum.
ask_multi() {
    local prompt="$1"; shift
    echo "$prompt" >&2
    local opt
    for opt in "$@"; do
        if ask_confirm "  $opt" "no"; then
            echo "$opt"
        fi
    done
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

# --- retry ------------------------------------------------------------

# retry <attempts> <cmd...> — for network-flaky operations (git clone, curl,
# pacman -Sy). Does not swallow the final failure; the caller still sees a
# non-zero exit after the last attempt.
retry() {
    local attempts="$1"; shift
    local n=1
    until "$@"; do
        if [ "$n" -ge "$attempts" ]; then
            return 1
        fi
        warn "command failed (attempt $n/$attempts), retrying in 2s: $*"
        sleep 2
        n=$((n + 1))
    done
}

# --- package installation ----------------------------------------------

NEXUS_NONINTERACTIVE="${NEXUS_NONINTERACTIVE:-0}"

# A stale db.lck from a previous run that got killed (Ctrl-C, crashed VM,
# `kill`) blocks every future pacman call with a cryptic "unable to lock
# database" error until it's removed — a very common real-world reason a
# re-run of an installer fails. Only clear it if no pacman is actually
# running, so we never race a genuinely in-progress transaction.
clear_stale_pacman_lock() {
    local lock="/var/lib/pacman/db.lck"
    [ -f "$lock" ] || return 0
    if pgrep -x pacman >/dev/null 2>&1; then
        return 0
    fi
    warn "Found a stale pacman lock from an interrupted run — removing it."
    sudo rm -f "$lock"
}

have_yay() { command -v yay >/dev/null 2>&1; }

# Bootstrapped lazily (only the first time pacman_install actually needs an
# AUR package), not unconditionally in preflight — most nexus-shell installs
# never need it, since everything in packages/*.packages is in the official
# repos. Failure here is non-fatal: callers fall back to reporting the
# package as unavailable rather than the whole install dying over it.
ensure_yay() {
    have_yay && return 0
    info "Installing yay (AUR helper — fallback for packages outside the official repos)..."
    local tmp
    tmp="$(mktemp -d)"
    # `git clone` refuses a non-empty target, so a failed first attempt would
    # make a retry fail immediately unless the directory is reset between
    # tries — hence the `rm -rf`/`mkdir` inside the retried command.
    if retry 2 bash -c "rm -rf '$tmp' && mkdir -p '$tmp' && git clone --depth 1 https://aur.archlinux.org/yay-bin.git '$tmp'" >>"$NEXUS_INSTALL_LOG" 2>&1 \
        && (cd "$tmp" && makepkg -si --noconfirm --needed >>"$NEXUS_INSTALL_LOG" 2>&1); then
        rm -rf "$tmp"
        have_yay && { ok "yay installed"; return 0; }
    fi
    rm -rf "$tmp"
    warn "could not install yay — AUR fallback unavailable this run (see $NEXUS_INSTALL_LOG)"
    return 1
}

# Installs each package from the official repos where possible, falling back
# to the AUR (via yay, installed on demand) for anything pacman doesn't know
# about. A package resolvable by neither is warned about and skipped, not
# treated as fatal — one bad/renamed/AUR-only name in a list should never
# block every other package in that same call. Callers that need a hard
# guarantee a specific package landed should follow up with
# `require_installed` (which does fail loudly) — that split is deliberate:
# this function's job is "try, and tell me what didn't work," not "succeed
# or die."
pacman_install() {
    local pkgs=("$@")
    [ "${#pkgs[@]}" -eq 0 ] && return 0

    clear_stale_pacman_lock

    local official=() aur_candidates=()
    for pkg in "${pkgs[@]}"; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            official+=("$pkg")
        else
            aur_candidates+=("$pkg")
        fi
    done

    if [ "${#official[@]}" -gt 0 ]; then
        info "Installing (official repos): ${official[*]}"
        retry 2 sudo pacman -S --needed --noconfirm "${official[@]}" \
            || warn "pacman failed on: ${official[*]} — continuing, see $NEXUS_INSTALL_LOG"
    fi

    if [ "${#aur_candidates[@]}" -eq 0 ]; then
        return 0
    fi

    have_yay || ensure_yay || true
    local aur=() missing=()
    for pkg in "${aur_candidates[@]}"; do
        if have_yay && yay -Si "$pkg" >/dev/null 2>&1; then
            aur+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    if [ "${#aur[@]}" -gt 0 ]; then
        info "Installing (AUR via yay): ${aur[*]}"
        retry 2 yay -S --needed --noconfirm "${aur[@]}" \
            || warn "yay failed on: ${aur[*]} — continuing, see $NEXUS_INSTALL_LOG"
    fi
    if [ "${#missing[@]}" -gt 0 ]; then
        warn "not found in the official repos or the AUR, skipped: ${missing[*]}"
    fi
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
