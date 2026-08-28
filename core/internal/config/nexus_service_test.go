package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func nexusUnitPath(home string) string {
	return filepath.Join(home, ".config", "systemd", "user", NexusUserServiceName)
}

func TestEnsureNexusUserServiceWritesUnitAndWants(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	path, err := EnsureNexusUserService("/opt/nexus/bin/nexus")
	if err != nil {
		t.Fatal(err)
	}
	if path != nexusUnitPath(home) {
		t.Fatalf("unexpected path %s", path)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "ExecStart=/opt/nexus/bin/nexus run --session") {
		t.Fatalf("ExecStart not templated:\n%s", data)
	}
	if !strings.Contains(string(data), "WantedBy=graphical-session.target") {
		t.Fatalf("missing [Install]:\n%s", data)
	}

	link := filepath.Join(home, ".config", "systemd", "user", "graphical-session.target.wants", NexusUserServiceName)
	target, err := os.Readlink(link)
	if err != nil {
		t.Fatalf("wants symlink missing: %v", err)
	}
	if target != filepath.Join("..", NexusUserServiceName) {
		t.Fatalf("wants symlink points at %q", target)
	}
}

func TestEnsureNexusUserServiceKeepsExisting(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	path := nexusUnitPath(home)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	custom := "[Unit]\nDescription=mine\n"
	if err := os.WriteFile(path, []byte(custom), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := EnsureNexusUserService("/usr/bin/nexus"); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != custom {
		t.Fatalf("existing unit was overwritten:\n%s", data)
	}
}

func TestEnsureNexusUserServiceDefaultExec(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	if _, err := EnsureNexusUserService(""); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(nexusUnitPath(home))
	if !strings.Contains(string(data), "ExecStart=%h/.local/bin/nexus run --session") {
		t.Fatalf("default ExecStart not used:\n%s", data)
	}
}
