# nexus-shell

A Wayland desktop shell built on [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)'s
Quickshell/QML engine, with customization mechanisms adapted from
[Omarchy](https://github.com/basecamphq/omarchy) and
[Ryoku](https://github.com/neur0map/ryoku-arch). See `CREDITS.md` for exactly
what came from where.

Performance and customizability were the two things this fork optimized for:
DMS was chosen as the base specifically because it already gets performance
right (async `Loader`s everywhere, singleton services instead of duplicated
state, a Go IPC fast-path that skips subprocess spawn for hot paths,
precompiled shaders) — see `quickshell/AGENTS.md` → `AGENTS.md` for the
resource-usage discipline that's still the rule here. The additions on top
are aimed entirely at customizability: a config-override layer that survives
updates, a theme pipeline that reaches beyond the shell into your terminal
and other apps, a friendly CLI over the bar's existing IPC surface, and
dev-tooling gates that keep it that way.

## What's actually new here vs. upstream DMS

| Area | What | Docs |
|---|---|---|
| Config | Three-tier layering: defaults → `settings.json` (GUI) → `user-overrides.json` (hand-edited, always wins, update-proof) | `docs/CONFIG_LAYERING.md` |
| Theming | `colors.toml` + template pipeline propagating one palette to terminal/btop/etc, via a stable atomically-swapped `current-theme` directory | `docs/THEMING.md` |
| Bar | `nexus-shell bar <cmd>` — friendly CLI over DankBar's existing (but previously unexposed) IPC control surface | `docs/BAR_CONTROL.md` |
| CLI | `bin/nexus-shell` — self-documenting dispatcher over `bin/nexus-*` scripts, Omarchy-style | `bin/nexus-shell --help` |
| Migrations | Timestamped, idempotent, marker-tracked one-time system migrations | `migrations/README.md` |
| Dev tooling | `nexus-dev-scan-slop` (AI-filler comment lint), `nexus-dev-audit-ipc-calls` (catches typo'd `ipc call` targets before they ship) | `.githooks/pre-commit` |

Everything else — the plugin system, the bar/launcher/notification/settings
UI, the Go daemon's system integrations — is upstream DMS, largely untouched
in shape. It didn't need reinventing: DMS's `PluginComponent` contract
(host owns chrome/position, plugin content only renders, geometry injected)
already matches what Ryoku's plugin docs describe as the right design, so
that's one whole "port this from Ryoku" item that turned out to already be
done. See `quickshell/PLUGINS/README.md`.

## Repo layout

See `AGENTS.md` for the full breakdown. Short version: `quickshell/` is the
QML shell, `core/` is the Go supervisor/daemon, `dank-qml-common/` is a
vendored shared widget library, `bin/` + `theming/` + `migrations/` are the
customization layer described above, and `install/` is the installer (see
"Installing" below).

## Building

```bash
cd core
make build          # embeds quickshell/ into the nexus binary, builds cmd/nexus
./bin/nexus --help
```

`make build` requires `dank-qml-common/DankCommon` to actually have content
(it's vendored directly in this repo, not a submodule you need to init).

Run it: `core/bin/nexus` is a self-contained supervisor — it spawns the
embedded QML shell and starts the unix-socket server other components talk
to. Point `--config`/`NEXUS_SHELL_DIR` at `quickshell/` instead if you're
iterating on QML and don't want to rebuild the Go binary each time.

## Installing

```bash
curl -fsSL https://raw.githubusercontent.com/Duncan-Ireri/nexus-shell/main/install.sh | bash
# or, from a checkout:
./install.sh
```

Targets Arch Linux and derivatives (pacman). Asks you to pick Hyprland or
Niri, installs and verifies it *before* touching anything else, then builds
and installs nexus-shell, then offers a checklist of developer tooling:
Docker & Docker Compose, Node.js/JS, Python, Java, ML extras (JupyterLab,
CUDA+PyTorch if an NVIDIA GPU is detected), and a terminal/shell setup
(kitty, tmux + TPM, starship, zsh + oh-my-zsh). Language runtimes are
managed per-project via `mise` rather than pinned system-wide, so different
projects can pin different Node/Python/Java versions.

Non-interactive: `install/install.sh --non-interactive --compositor=hyprland --tools=docker,node,python`.
See `install/install.sh --help`, and `install/lib/common.sh` for the
idempotency/security conventions every step follows (never silently adds you
to the `docker` group, never overwrites an existing dotfile, package lists
in `install/packages/*.packages`).

`core/cmd/nexus-install` (upstream's bubbletea TUI installer) is still
present but unused by this flow — kept renamed and buildable in case it's
worth reviving for a GUI-driven install path later.

## Deferred

**A generic swappable bar-chrome plugin type** (Ryoku's "folder styles").
Studied, not built — see `docs/BAR_CONTROL.md` for why (DMS's bar-surface
lifecycle has real, hard-won complexity around monitor hotplug/DPMS recovery
that a generic Scene-swap registry would need to respect, and it can't be
verified headlessly). DMS already ships three built-in bar modes
(classic/Island/Frame), which covers most of the actual use case.

**Ryoku's store / launcher-provider-registry / config-import wizard.**
Real, well-designed patterns, but each is a project-sized piece of work on
its own rather than something to bolt on inside this pass. Worth revisiting
once there's a package/plugin registry for nexus-shell to point a store at.

## Known rough edges

This fork's rename pass focused on everything that's *functionally coupled*
(the shell↔daemon IPC socket identity, the `NEXUS_*` env var prefix, config/
state/cache paths, the Wayland app-id, exec'd binary names, all user-facing
CLI help text) over cosmetic completeness. Two real bugs were caught and
fixed this way during the fork — see `AGENTS.md`'s note on this — which is
exactly why the functional half got priority. What's *not* chased down:
internal Go/QML identifiers that are invisible to a user (`dmsPath`,
`DankBar` as a QML type name, etc.) — same category, same reasoning DMS
itself uses for its own `Dank*` naming, left alone deliberately rather than
overlooked.

## License

MIT. See `LICENSE` and `CREDITS.md`.
