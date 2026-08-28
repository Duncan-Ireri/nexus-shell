# Credits

nexus-shell is a fork combining code from one project with customization
patterns studied from two others.

## DankMaterialShell (code, MIT)

<https://github.com/AvengeMedia/DankMaterialShell> — nexus-shell's
`quickshell/` and `core/` are a direct fork of DMS: the QML shell (bar,
launcher, control center, notifications, plugin system, IPC) and its Go
companion daemon. This is the performance/architecture base — async Loaders
everywhere, singleton services, a Go IPC fast-path that bypasses subprocess
spawn for hot paths, precompiled shaders. See `README.md` for what was
renamed/rebranded vs. kept as-is.

## Default wallpaper

`assets/wallpapers/trigonometry.png` — a dark chalkboard-style illustration of
trigonometry/calculus formulae, shipped as the installer's default wallpaper.
Provided by the project maintainer; replace it with `--wallpaper=<path>` at
install time or from the shell afterwards.

## dank-qml-common (code, MIT)

<https://github.com/AvengeMedia/dank-qml-common> — shared QML widget library
DMS depends on (was a git submodule upstream; vendored directly here).

## Omarchy (patterns studied, MIT — no code copied)

<https://github.com/basecamphq/omarchy> (DHH) — nexus-shell's theming layer
(`theming/`, `bin/nexus-theme-set`) is modeled directly on Omarchy's
`colors.toml` + `.tpl` template pipeline for propagating one palette to many
apps, and on its `bin/omarchy-*` self-documenting-CLI + single-dispatcher
convention (`bin/nexus-shell`). The three-tier config layering in
`docs/CONFIG_LAYERING.md` also draws on Omarchy's default/config/user-layer
split. Omarchy additionally ships its own Quickshell-based shell
(`omarchy/shell/`) with a plugin/theming/IPC architecture very close to what
this project needed — worth a closer look if nexus-shell's plugin system
ever needs to grow beyond what DMS already provides.

## Ryoku (patterns studied, GPL-3 outer repo — no code copied)

<https://github.com/neur0map/ryoku-arch> — a fork of Omarchy. No code was
copied (Ryoku's outer repo is GPL-3; only its documented architecture was
read). Patterns nexus-shell's docs reference:

- The three-tier config-override model (shipped base → GUI-managed →
  hand-edited override that always wins) — see `docs/CONFIG_LAYERING.md`.
- "Install ≠ activate" as a separate step for anything installable.
- A stable, atomically-swapped current-theme directory that apps `include`
  once, instead of overwriting app configs directly per-theme-switch — see
  `docs/THEMING.md`. Ryoku's own docs call out the *lack* of this as a gap
  in their system; nexus-shell built it in from the start.
- Ryoku's plugin contract (host owns chrome/position, plugin content only
  renders, injected geometry/density props) turned out to already describe
  DMS's existing `PluginComponent` design closely enough that no changes
  were needed there — see `quickshell/PLUGINS/README.md`.
- Small, cheap CI dev-tooling gates (`bin/ryoku-dev-scan-slop`,
  `bin/ryoku-dev-audit-shell-binds`) — reimplemented from scratch as
  `bin/nexus-dev-scan-slop` and `bin/nexus-dev-audit-ipc-calls`.

Ryoku's bar "folder styles" (a full bar swapped via a Scene.qml registry) and
its plugin store/launcher-provider-registry were studied but not ported —
see `docs/BAR_CONTROL.md` for why, and the main README's "Deferred" section.
