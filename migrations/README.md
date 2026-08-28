# Migrations

One-time scripts that need to run once per install when nexus-shell's on-disk
conventions change in a way the shell's own settings-schema migration (see
`quickshell/Common/SettingsData.qml`, `configVersion`) can't cover — e.g.
relocating a file, renaming a directory, adjusting a system integration.
Settings.json's own fields already self-migrate on load; this directory is
for everything *outside* that file.

Modeled on Omarchy's `migrations/` directory.

## Convention

- One file per migration: `migrations/<unix-timestamp>-<short-description>.sh`
  e.g. `migrations/1735500000-move-theme-cache.sh`.
- Must be idempotent — `nexus-migrate` tracks completion via a marker file in
  `$XDG_STATE_HOME/NexusShell/migrations/<filename>`, but a migration should
  still be safe to run twice by design (check before you act).
- Non-zero exit means "not done yet" — `nexus-migrate` will retry it on the
  next run and will not mark it complete.
- Keep them small and single-purpose. If a migration needs to explain itself,
  put a one-line comment at the top, not a changelog.

## Running

```
nexus-shell migrate
# or directly:
bin/nexus-migrate
```

Typically invoked automatically after an update (wired up once the installer
exists — see the project README's "Deferred" section).
