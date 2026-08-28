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
and installs nexus-shell. It then sets up a ready-to-use desktop:

- **kitty** as the terminal, **Firefox** as the browser (registered as the
  default http/https handler),
- the full compositor config — keybinds, window rules, layout, colours —
  deployed via `nexus setup` (existing configs are backed up with a
  timestamp, not overwritten in place),
- `~/.local/bin/dms` symlinked to the `nexus` binary, since the shipped
  keybinds and the compositor's shell-launch hook invoke `dms`,
- `assets/wallpapers/trigonometry.png` installed to `~/Pictures/Wallpapers`
  and set as the default wallpaper (override with `--wallpaper=<path>`),
- optionally (prompted; default yes) **greetd + the nexus greeter** as the
  graphical login manager.

Finally it offers a checklist of developer tooling: Docker & Docker Compose,
Node.js/JS, Python, Java, ML extras (JupyterLab, CUDA+PyTorch if an NVIDIA
GPU is detected), and a terminal/shell setup (kitty, tmux + TPM, starship,
zsh + oh-my-zsh). Language runtimes are managed per-project via `mise` rather
than pinned system-wide.

The session is systemd-managed: `nexus setup` writes and enables
`~/.config/systemd/user/nexus.service` (`ExecStart=nexus run --session`,
`WantedBy=graphical-session.target`), so the shell starts with the graphical
session on Hyprland *and* Niri. Start Niri via `niri-session` (what the
greeter does), not bare `niri`, so `graphical-session.target` activates. Pass
`nexus setup --systemd=false` for a standalone session that spawns the shell
from the compositor config instead (Void/Mango default).

Hyprland's native Lua config (`~/.config/hypr/hyprland.lua`, auto-loaded on
Hyprland 0.55+) is used; the installer warns if the installed Hyprland is
older. The deployed keybinds still call `dms ipc call …` (upstream name); a
`~/.local/bin/dms → nexus` alias keeps them working while the keybind
subsystem's rename lands separately.

Non-interactive: `install/install.sh --non-interactive --compositor=hyprland
--tools=docker,node,python --display-manager`. Without `--display-manager`
the login manager is skipped in non-interactive runs. See
`install/install.sh --help`, and `install/lib/common.sh` for the
idempotency/security conventions every step follows (never silently adds you
to the `docker` group, package lists in `install/packages/*.packages`).

**Resilience.** Safe to re-run at any point — every step checks what's
already done rather than redoing it blindly, network operations retry
transient failures, and a stale `pacman` lock from a previous interrupted run
is cleared automatically. Package installs fall back to the AUR via `yay`
(bootstrapped on demand) for anything not in the official repos; a package
found in neither is warned about and skipped rather than aborting the whole
batch. Within the optional dev-tooling checklist, one tool failing (a
network blip mid-`mise install`, say) doesn't take the others down with it —
it's reported at the end so you know what to re-run, everything else still
completes. The one place that still stops the whole install on failure is
the critical path (compositor, the shell build itself) — there's no point
offering to install Docker onto a shell that didn't build.

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
