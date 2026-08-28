package deps

import (
	"context"
)

type DependencyStatus int

const (
	StatusMissing DependencyStatus = iota
	StatusInstalled
	StatusNeedsUpdate
	StatusNeedsReinstall
)

// ShellPackageName is the display Name of the Dependency representing the
// nexus-shell package itself (produced by distros.BaseDistribution.detectDMS).
// It is a required package and cannot be excluded from a headless install.
const ShellPackageName = "dms (NexusShell)"

type PackageVariant int

const (
	VariantStable PackageVariant = iota
	VariantGit
)

type Dependency struct {
	Name        string
	Status      DependencyStatus
	Version     string
	Description string
	Required    bool
	Variant     PackageVariant
	CanToggle   bool
}

type WindowManager int

const (
	WindowManagerHyprland WindowManager = iota
	WindowManagerNiri
	WindowManagerMango
)

type Terminal int

const (
	TerminalGhostty Terminal = iota
	TerminalKitty
	TerminalAlacritty
)

type DependencyDetector interface {
	DetectDependencies(ctx context.Context, wm WindowManager) ([]Dependency, error)
	DetectDependenciesWithTerminal(ctx context.Context, wm WindowManager, terminal Terminal) ([]Dependency, error)
}
