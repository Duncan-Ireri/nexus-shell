# Bar control

DankBar was already fully JSON-configured and IPC-controllable in upstream
DMS (`SettingsData.barConfigs`, the `getBarConfig`/`bar` IPC targets in
`DMSShellIPC.qml`) — this is DMS's equivalent of Omarchy's `omarchy-bar`
CLI, just not exposed as a friendly command yet. `bin/nexus-bar` is that
friendly command, wrapping the existing IPC surface:

```
nexus-shell bar toggle                       # preferred/default bar
nexus-shell bar toggle id main               # a specific bar, by id
nexus-shell bar set-position id main left
nexus-shell bar status id main
```

Commands: `reveal`, `hide`, `toggle`, `status`, `autohide`, `manualhide`,
`toggle-autohide`, `toggle-reveal`, `get-position`, `set-position <position>`.
`<selector>` is `id`, `index`, or `position`; `<value>` identifies which bar.

## Sharing a full bar layout

A DankBar layout (position, widgets per section, per-bar settings) is just
JSON in `settings.json`'s `barConfigs` array — so the highest-value "bar
style" for most users is exporting/importing that array directly:

```
nexus-shell ipc call settings get barConfigs > my-bar-layout.json
# ...edit the widget lists in a text editor, or generate it...
nexus-shell ipc call settings set barConfigs "$(cat my-bar-layout.json)"
```

(`settings set` currently only accepts scalar values over IPC — see
`DMSShellIPC.qml`'s `settings.set` handler — so for now this round-trip goes
through Settings UI import/export rather than IPC `set` directly. Worth
revisiting once array/object IPC values are supported upstream.)

## What we deliberately didn't build

Ryoku's "folder styles" (a bar is a directory with `Scene.qml`, swapped via a
registry + `Loader`) is a clean pattern in principle, but DMS's actual bar
surface lifecycle in `ShellCore.qml` has real complexity earned the hard way —
horizontal bars must claim exclusive zones before vertical bars load, and
there's a multi-pass DPMS/monitor-hotplug recovery path. Rewiring that into a
generic swappable-Scene registry is a real project on its own and risks
breaking that recovery logic without a way to test every monitor-hotplug edge
case headlessly. DMS already ships three built-in bar *modes* (classic
DankBar, DankIsland, Frame — see `SettingsData.dankIslandEnabled` /
`frameEnabled`) which covers most of what people actually want to change.
Full third-party bar-chrome swapping is a reasonable follow-up once there's a
real compositor to test hotplug recovery against.
