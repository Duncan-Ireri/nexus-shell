## What is this?

nexus-shell is an open-source, MIT-licensed desktop shell for Wayland
compositors on Linux — a fork of DankMaterialShell (DMS), re-themed and
extended with customization mechanisms adapted from Omarchy and Ryoku. See
the root `README.md` for provenance and what changed from upstream.

## Repo Structure

- `quickshell/` — the Quickshell/QML application, the entirety of the shell
  UI. See `quickshell/AGENTS.md`'s original content below for the internal
  layout; it hasn't changed shape from upstream DMS.
  - `Common/` — app-wide singletons and helpers (Theme, SettingsData,
    SessionData, I18n, PopoutManager). `SettingsData.qml` additionally
    implements the three-tier config layering described in
    `docs/CONFIG_LAYERING.md`.
  - `Services/` — headless singletons that talk to the system and to `core`.
  - `Modules/` — the visible shell: DankBar, ControlCenter, Dock, Lock,
    Notifications, OSD, and so on.
  - `Modals/` — large standalone surfaces: Settings, DankLauncherV2,
    Clipboard, Greeter.
  - `Widgets/` — reusable Dank* components.
  - `PLUGINS/` — the plugin system; unchanged from upstream, it already
    matches the "host owns chrome, content only renders" contract we'd
    otherwise have ported from Ryoku.
  - `DankCommon/` — symlink to `../dank-qml-common/DankCommon` (see below).
- `dank-qml-common/` — shared QML widget library (was a submodule upstream;
  vendored directly here since this isn't a git checkout of DMS).
- `core/` — Go companion. `cmd/nexus` is the shell supervisor + unix-socket
  server for functionality QML can't do natively (network, bluez,
  brightness, cups, clipboard, screenshot, wlr-layer-shell, polkit, ...).
  `cmd/nexus-install` is upstream's TUI installer, kept but **not wired up**
  — we're deferring the installer redesign (curl-based, pick-your-tools) to
  a later pass.
- `bin/` — bash tooling: `nexus-shell` is the self-documenting dispatcher
  (Omarchy's `bin/omarchy-*` + single-dispatcher pattern), routing to
  `nexus-theme-set`, `nexus-theme-list`, `nexus-bar`, `nexus-plugin`,
  `nexus-migrate`, and `nexus-dev-*` tooling. Every script also runs
  standalone. **Not** to be confused with the `nexus` binary in `core/` —
  that's the compiled shell supervisor; this is bash tooling that shells out
  to it over IPC.
- `theming/` — `colors.toml` themes + `.tpl` templates for propagating a
  palette to external apps (terminal, btop, ...). See `docs/THEMING.md`.
- `migrations/` — one-time system-level migration scripts. See
  `migrations/README.md`.
- `docs/` — architecture references: `CONFIG_LAYERING.md`, `THEMING.md`,
  `BAR_CONTROL.md`, plus whatever shipped with upstream DMS's `docs/`.
- `install/` — the curl-installable installer (Arch/pacman). `install.sh` at
  the repo root is a tiny bootstrap (clones the repo if piped via curl,
  reattaches `/dev/tty` so prompts still work, then hands off);
  `install/install.sh` is the real orchestrator, running `install/steps/*.sh`
  in order (preflight → compositor choice → build+install the shell →
  desktop layer [terminal, browser, `nexus setup` config deployment,
  wallpaper, optional greetd + nexus greeter] → an opt-in dev-tooling
  checklist in `install/steps/tools/*.sh` → summary). `03-desktop.sh` runs
  `nexus setup --yes` (systemd session: `nexus setup` writes + enables
  `~/.config/systemd/user/nexus.service`) and symlinks `~/.local/bin/dms ->
  nexus` because the shipped keybinds still call `dms ipc call` (the QML
  keybind subsystem's rename is deferred — see the deps note in memory).
  `install/lib/common.sh` has the shared logging/prompt/package-install/
  idempotent-file-edit helpers every step uses — read that before adding a
  new step, it already solves "don't clobber an existing dotfile," "don't
  silently grant a security-sensitive group membership," "retry a flaky
  network op," "fall back to the AUR via yay when pacman doesn't know a
  package," and "don't let one thing failing take everything else down with
  it" (`pacman_install` is best-effort by design — it warns and moves on;
  callers that need a hard guarantee a package landed follow up with
  `require_installed`, which does fail loudly). New steps should follow the
  same split: fail loud on your own genuinely-required precondition, but if
  you're one of several optional things offered together (see
  `steps/04-dev-tools.sh`'s per-tool try/warn loop, or `steps/tools/terminal.sh`'s
  independent kitty/tmux/starship/zsh blocks), don't let your failure block
  the others.

## General Rules

- Keep it simple. Do not overcomplicate things.
- Follow each app's own conventions. QML widgets use `Theme` tokens instead
  of hardcoding colors, spacing, or other constants.
- Resource usage is extremely important — this shell runs 24/7. Audit any
  change for idle CPU cost, extra processes, timers, and retained memory.
- `core` and `quickshell` are tightly coupled through the unix socket
  protocol *and* through shared identity strings (the `nexus` app ID, the
  `NEXUS_*` env var prefix, the runtime socket name). If you rename or move
  one side's half of that contract, grep the other side before you consider
  it done — this project already shipped two real bugs from exactly that
  gap during the initial fork (see `README.md`'s "Known rough edges").
- Use the `Dank*` wrappers in `Widgets/` instead of raw ListView/Flickable/
  ScrollView.
- All user-facing text goes through `I18n.tr()`. Translation catalogs in
  `translations/` are synced externally — don't hand-edit them; the QML
  source strings themselves are the thing to edit.
- Do not leave paragraphs of comments on top of code. Prefer clear naming;
  keep necessary comments concise, and remove stale ones you come across.
- Use guard-clause patterns.
- Do not write tests that don't validate real input/output behavior.
- Do not edit generated code by hand (mocks are `mockery`-generated).
- If a request is missing something important, say so rather than silently
  filling the gap.
- Never commit, push, or open a PR unless explicitly asked.

## Commit Messages

`<area touched>: short lowercase description of the work`, e.g.:

```
theming: add tokyo-night colors.toml
bar: fix set-position arg order in nexus-bar
```
