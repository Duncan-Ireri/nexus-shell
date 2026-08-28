# Theming

nexus-shell has two theming layers that work independently:

1. **The shell's own look** (bar, launcher, control center, modals) — this is
   DankMaterialShell's existing matugen-driven pipeline: pick a wallpaper or a
   stock theme in Settings → Appearance, and `Common/Theme.qml` regenerates
   the shell's Material color tokens. Nothing changed here; see
   `quickshell/docs/CUSTOM_THEMES.md` (ported from upstream) for the JSON
   custom-theme format.

2. **External apps** (terminal, system monitor, ...) — new in nexus-shell,
   modeled on Omarchy's `colors.toml` + template pipeline, since propagating
   one palette to every app on the system is Omarchy's actual differentiator
   and DMS's matugen integration only covers GTK/the shell itself.

This document covers layer 2.

## Applying a theme

```
nexus-shell theme list
nexus-shell theme set nord
```

Built-in themes live in `theming/themes/<name>/colors.toml`
(nord, gruvbox, catppuccin-mocha, tokyo-night ship by default). Drop your own
theme at `~/.config/NexusShell/themes/<name>/colors.toml` — same-named user
themes always win over built-ins.

## How it works

`bin/nexus-theme-set`:

1. Resolves the theme directory and reads `colors.toml`.
2. Renders every `.tpl` file in `theming/templates/` (built-in) and
   `~/.config/NexusShell/themed/` (your own extra templates), substituting
   `{{ key }}` (raw value, e.g. `#89b4fa`) and `{{ key_strip }}` (no leading
   `#`, for formats that want bare hex) from `colors.toml`.
3. Writes the result to a **staging directory**, then atomically swaps the
   `current-theme` symlink (`$XDG_STATE_HOME/NexusShell/current-theme`) to
   point at it. Apps never see a half-rendered theme mid-swap.
4. Runs any executable hooks in `~/.config/NexusShell/hooks/theme-set.d/`,
   passing `(theme-name, theme-dir)`.

## Wiring up an app (one-time, per app, per machine)

nexus-shell deliberately does **not** edit your app configs for you — only
your own dotfiles should own that. Instead, `current-theme` is a stable path
apps can `include`/`source` once:

```conf
# ~/.config/kitty/kitty.conf
include ~/.local/state/NexusShell/current-theme/kitty.conf
```

```ini
# ~/.config/foot/foot.ini
include=~/.local/state/NexusShell/current-theme/foot.ini
```

```bash
# btop: copy once, or symlink — btop doesn't support include
ln -sf ~/.local/state/NexusShell/current-theme/btop.theme \
       ~/.config/btop/themes/nexus.theme
# then set `color_theme = "nexus"` in ~/.config/btop/btop.conf
```

This "stable path + one-time include" approach is deliberate: Ryoku's own
theming docs flag the *lack* of this indirection as a real gap in their
system (they overwrite app configs directly per-app, so four different places
have to agree). One stable, always-current directory avoids that class of
drift entirely.

## Adding a template for a new app

Drop `theming/templates/<app>.tpl` (or `~/.config/NexusShell/themed/<app>.tpl`
for a personal one) using `{{ key }}` / `{{ key_strip }}` placeholders. Keys
available: see any file in `theming/themes/*/colors.toml` — `background`,
`foreground`, `accent`, `selection`, `muted`, `red`/`orange`/`yellow`/`green`/
`cyan`/`blue`/`magenta`/`brown` and their `bright_*` counterparts, plus
`dark_background`/`darker_background`/`lighter_background`/`dim_foreground`.

## Adding a hook

Drop an executable at `~/.config/NexusShell/hooks/theme-set.d/50-my-hook` — it
runs after every `theme set`, receiving `$1=theme-name $2=theme-dir`. Use this
for anything that needs an explicit restart to pick up new config (e.g.
`pkill -SIGUSR2 btop` or restarting a status-bar module), mirroring Omarchy's
`hooks/<event>.d/` convention.
