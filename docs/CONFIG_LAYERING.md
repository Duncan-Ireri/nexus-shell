# Config layering

nexus-shell resolves settings in three tiers, each overriding the last:

1. **Compiled-in defaults** — property defaults declared directly in
   `quickshell/Common/SettingsData.qml`.
2. **`settings.json`** — `$XDG_CONFIG_HOME/NexusShell/settings.json`. This is
   the GUI-managed layer: everything the Settings window writes lives here.
   It self-migrates across schema versions on load (`configVersion` in
   `SettingsData.qml`).
3. **`user-overrides.json`** — `$XDG_CONFIG_HOME/NexusShell/user-overrides.json`.
   Hand-edited only. Applied last, deep-merged on top of `settings.json` every
   time settings load (`SettingsData.qml: _applyUserOverrides`). The Settings
   UI never reads or writes this file, so a value pinned here survives both
   GUI changes and shell updates.

This is the same shape as Ryoku's three-tier config model (shipped base → GUI
JSON → raw override file that always wins), adapted to DMS's existing
JSON-settings mechanism rather than introducing a parallel config format.

## Example

```json
// ~/.config/NexusShell/user-overrides.json
{
    "dankBarLeftWidgets": [
        {"widgetId": "clock", "enabled": true}
    ],
    "modalElevationEnabled": false
}
```

Editing this file live-reloads the shell (it's watched the same way
`settings.json` is) — no restart needed.

## Why not just edit settings.json directly?

You can — nothing stops you. `user-overrides.json` exists for values you want
to survive the Settings UI touching *other* keys in `settings.json`, or for
sharing a small, reviewable "pin these things" file separately from your full
generated settings (e.g. checking just the override file into a dotfiles
repo, rather than the much larger, frequently-churning `settings.json`).

## What lives outside this file

System-level changes (not shell settings — file relocations, integration
changes) are handled by `migrations/`, not this layering system. See
`migrations/README.md`.
