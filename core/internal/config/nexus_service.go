package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// nexusUserServiceTemplate is the systemd --user unit that runs the shell as
// part of the graphical session. {{EXEC}} is replaced with the absolute path to
// the nexus binary so the unit works regardless of where it was installed and
// without depending on the systemd --user PATH.
const nexusUserServiceTemplate = `[Unit]
Description=Nexus Shell
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=exec
ExecStart={{EXEC}} run --session
Restart=on-failure
RestartSec=2
Slice=session.slice

[Install]
WantedBy=graphical-session.target
`

// NexusUserServiceName is the unit name enabled/queried elsewhere.
const NexusUserServiceName = "nexus.service"

func nexusUserServiceUnit(execPath string) string {
	if execPath == "" {
		execPath = "%h/.local/bin/nexus"
	}
	return strings.ReplaceAll(nexusUserServiceTemplate, "{{EXEC}}", execPath)
}

// EnsureNexusUserService writes ~/.config/systemd/user/nexus.service (ExecStart
// pointed at execPath, typically os.Executable()) and the
// graphical-session.target.wants symlink that enables it. An existing unit is
// left alone — matching this installer's "never clobber a config the user may
// have edited" rule. Returns the unit path.
func EnsureNexusUserService(execPath string) (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	unitPath := filepath.Join(homeDir, ".config", "systemd", "user", NexusUserServiceName)

	if _, err := os.Stat(unitPath); err == nil {
		return unitPath, nil
	} else if !os.IsNotExist(err) {
		return "", fmt.Errorf("reading %s: %w", unitPath, err)
	}

	if err := os.MkdirAll(filepath.Dir(unitPath), 0o755); err != nil {
		return "", err
	}
	if err := os.WriteFile(unitPath, []byte(nexusUserServiceUnit(execPath)), 0o644); err != nil {
		return "", err
	}

	// Enable it by hand too: `systemctl --user enable` needs a running user
	// manager, which an SSH/CI install may not have. This is exactly what
	// `enable` would create from the unit's [Install] WantedBy=.
	wantsDir := filepath.Join(filepath.Dir(unitPath), "graphical-session.target.wants")
	if err := os.MkdirAll(wantsDir, 0o755); err == nil {
		link := filepath.Join(wantsDir, NexusUserServiceName)
		if _, err := os.Lstat(link); os.IsNotExist(err) {
			_ = os.Symlink(filepath.Join("..", NexusUserServiceName), link)
		}
	}

	return unitPath, nil
}
