package distros

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
)

// ManualPackageInstaller provides methods for installing packages from source
type ManualPackageInstaller struct {
	*BaseDistribution
}

// parseLatestTagFromGitOutput parses git ls-remote output and returns the latest tag
func (m *ManualPackageInstaller) parseLatestTagFromGitOutput(output string) string {
	lines := strings.SplitSeq(output, "\n")
	for line := range lines {
		if strings.Contains(line, "refs/tags/") && !strings.Contains(line, "^{}") {
			parts := strings.Split(line, "refs/tags/")
			if len(parts) > 1 {
				latestTag := strings.TrimSpace(parts[1])
				return latestTag
			}
		}
	}
	return ""
}

// getLatestQuickshellTag fetches the latest tag from the quickshell repository
func (m *ManualPackageInstaller) getLatestQuickshellTag(ctx context.Context) string {
	tagCmd := exec.CommandContext(ctx, "git", "ls-remote", "--tags", "--sort=-v:refname",
		"https://github.com/hamza72x/quickshell.git")
	tagOutput, err := tagCmd.Output()
	if err != nil {
		m.log(fmt.Sprintf("Warning: failed to fetch quickshell tags: %v", err))
		return ""
	}

	return m.parseLatestTagFromGitOutput(string(tagOutput))
}

func (m *ManualPackageInstaller) InstallManualPackages(ctx context.Context, packages []string, variantMap map[string]deps.PackageVariant, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	m.log(fmt.Sprintf("Installing manual packages: %s", strings.Join(packages, ", ")))

	for _, pkg := range packages {
		variant := variantMap[pkg]
		switch pkg {
		case "dms (DankMaterialShell)", "dms":
			if err := m.installDankMaterialShell(ctx, variant, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install DankMaterialShell: %w", err)
			}
		case "dgop":
			if err := m.installDgop(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install dgop: %w", err)
			}
		case "niri":
			if err := m.installNiri(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install niri: %w", err)
			}
		case "quickshell":
			if err := m.installQuickshell(ctx, variant, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install quickshell: %w", err)
			}
		case "hyprland":
			if err := m.installHyprland(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install hyprland: %w", err)
			}
		case "ghostty":
			if err := m.installGhostty(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install ghostty: %w", err)
			}
		case "matugen":
			if err := m.installMatugen(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install matugen: %w", err)
			}
		case "xwayland-satellite":
			if err := m.installXwaylandSatellite(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install xwayland-satellite: %w", err)
			}
		default:
			m.log(fmt.Sprintf("Warning: No manual build method for %s", pkg))
		}
	}

	return nil
}

func (m *ManualPackageInstaller) installDgop(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing dgop from source...")

	homeDir := os.Getenv("HOME")
	if homeDir == "" {
		return fmt.Errorf("HOME environment variable not set")
	}

	cacheDir := filepath.Join(homeDir, ".cache", "dankinstall")
	if err := os.MkdirAll(cacheDir, 0o755); err != nil {
		return fmt.Errorf("failed to create cache directory: %w", err)
	}

	tmpDir := filepath.Join(cacheDir, "dgop-build")
	if err := os.MkdirAll(tmpDir, 0o755); err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Cloning dgop repository...",
		IsComplete:  false,
		CommandInfo: "git clone https://github.com/hamza72x/dgop.git",
	}

	cloneCmd := exec.CommandContext(ctx, "git", "clone", "https://github.com/hamza72x/dgop.git", tmpDir)
	if err := cloneCmd.Run(); err != nil {
		m.logError("failed to clone dgop repository", err)
		return fmt.Errorf("failed to clone dgop repository: %w", err)
	}

	buildCmd := exec.CommandContext(ctx, "make")
	buildCmd.Dir = tmpDir
	buildCmd.Env = append(os.Environ(), "TMPDIR="+cacheDir)
	if err := m.runWithProgressStep(buildCmd, progressChan, PhaseSystemPackages, 0.4, 0.7, "Building dgop..."); err != nil {
		return fmt.Errorf("failed to build dgop: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.7,
		Step:        "Installing dgop...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo make install",
	}

	installCmd := privesc.ExecCommand(ctx, sudoPassword, "make install")
	installCmd.Dir = tmpDir
	if err := installCmd.Run(); err != nil {
		m.logError("failed to install dgop", err)
		return fmt.Errorf("failed to install dgop: %w", err)
	}

	m.log("dgop installed successfully from source")
	return nil
}

func (m *ManualPackageInstaller) installNiri(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing niri from source...")

	homeDir, _ := os.UserHomeDir()
	buildDir := filepath.Join(homeDir, ".cache", "dankinstall", "niri-build")
	tmpDir := filepath.Join(homeDir, ".cache", "dankinstall", "tmp")
	if err := os.MkdirAll(buildDir, 0o755); err != nil {
		return fmt.Errorf("failed to create build directory: %w", err)
	}
	if err := os.MkdirAll(tmpDir, 0o755); err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(tmpDir)
	}()

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.2,
		Step:        "Cloning niri repository...",
		IsComplete:  false,
		CommandInfo: "git clone https://github.com/hamza72x/niri.git",
	}

	cloneCmd := exec.CommandContext(ctx, "git", "clone", "https://github.com/hamza72x/niri.git", buildDir)
	if err := cloneCmd.Run(); err != nil {
		return fmt.Errorf("failed to clone niri: %w", err)
	}

	checkoutCmd := exec.CommandContext(ctx, "git", "-C", buildDir, "checkout", "v25.08")
	if err := checkoutCmd.Run(); err != nil {
		m.log(fmt.Sprintf("Warning: failed to checkout v25.08, using main: %v", err))
	}

	if !m.commandExists("cargo-deb") {
		cargoDebInstallCmd := exec.CommandContext(ctx, "cargo", "install", "cargo-deb")
		cargoDebInstallCmd.Env = append(os.Environ(), "TMPDIR="+tmpDir)
		if err := m.runWithProgressStep(cargoDebInstallCmd, progressChan, PhaseSystemPackages, 0.3, 0.35, "Installing cargo-deb..."); err != nil {
			return fmt.Errorf("failed to install cargo-deb: %w", err)
		}
	}

	buildDebCmd := exec.CommandContext(ctx, "cargo", "deb")
	buildDebCmd.Dir = buildDir
	buildDebCmd.Env = append(os.Environ(), "TMPDIR="+tmpDir)
	if err := m.runWithProgressStep(buildDebCmd, progressChan, PhaseSystemPackages, 0.35, 0.95, "Building niri deb package..."); err != nil {
		return fmt.Errorf("failed to build niri deb: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.95,
		Step:        "Installing niri deb package...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "dpkg -i niri.deb",
	}

	installDebCmd := privesc.ExecCommand(ctx, sudoPassword,
		fmt.Sprintf("dpkg -i %s/target/debian/niri_*.deb", buildDir))

	output, err := installDebCmd.CombinedOutput()
	if err != nil {
		m.log(fmt.Sprintf("dpkg install failed. Output:\n%s", string(output)))
		return fmt.Errorf("failed to install niri deb package: %w\nOutput:\n%s", err, string(output))
	}

	m.log(fmt.Sprintf("dpkg install successful. Output:\n%s", string(output)))

	m.log("niri installed successfully from source")
	return nil
}

func (m *ManualPackageInstaller) installQuickshell(ctx context.Context, variant deps.PackageVariant, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing quickshell from source...")

	homeDir := os.Getenv("HOME")
	if homeDir == "" {
		return fmt.Errorf("HOME environment variable not set")
	}

	cacheDir := filepath.Join(homeDir, ".cache", "dankinstall")
	if err := os.MkdirAll(cacheDir, 0o755); err != nil {
		return fmt.Errorf("failed to create cache directory: %w", err)
	}

	tmpDir := filepath.Join(cacheDir, "quickshell-build")
	if err := os.MkdirAll(tmpDir, 0o755); err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Cloning quickshell repository...",
		IsComplete:  false,
		CommandInfo: "git clone https://github.com/hamza72x/quickshell.git",
	}

	var cloneCmd *exec.Cmd
	if forceQuickshellGit || variant == deps.VariantGit {
		cloneCmd = exec.CommandContext(ctx, "git", "clone", "https://github.com/hamza72x/quickshell.git", tmpDir)
	} else {
		latestTag := m.getLatestQuickshellTag(ctx)
		if latestTag != "" {
			m.log(fmt.Sprintf("Using latest quickshell tag: %s", latestTag))
			cloneCmd = exec.CommandContext(ctx, "git", "clone", "--branch", latestTag, "https://github.com/hamza72x/quickshell.git", tmpDir)
		} else {
			m.log("Warning: failed to fetch latest tag, using default branch")
			cloneCmd = exec.CommandContext(ctx, "git", "clone", "https://github.com/hamza72x/quickshell.git", tmpDir)
		}
	}
	if err := cloneCmd.Run(); err != nil {
		return fmt.Errorf("failed to clone quickshell: %w", err)
	}

	buildDir := tmpDir + "/build"
	if err := os.MkdirAll(buildDir, 0o755); err != nil {
		return fmt.Errorf("failed to create build directory: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.3,
		Step:        "Configuring quickshell build...",
		IsComplete:  false,
		CommandInfo: "cmake -B build -S . -G Ninja",
	}

	configureCmd := exec.CommandContext(ctx, "cmake", "-GNinja", "-B", "build",
		"-DCMAKE_BUILD_TYPE=RelWithDebInfo",
		"-DCMAKE_INSTALL_PREFIX=/usr",
		"-DINSTALL_QML_PREFIX=/usr/lib64/qt6/qml",
		"-DCRASH_HANDLER=OFF",
		"-DCMAKE_CXX_STANDARD=20")
	configureCmd.Dir = tmpDir
	configureCmd.Env = append(os.Environ(), "TMPDIR="+cacheDir)

	output, err := configureCmd.CombinedOutput()
	if err != nil {
		m.log(fmt.Sprintf("cmake configure failed. Output:\n%s", string(output)))
		return fmt.Errorf("failed to configure quickshell: %w\nCMake output:\n%s", err, string(output))
	}

	m.log(fmt.Sprintf("cmake configure successful. Output:\n%s", string(output)))

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.4,
		Step:        "Building quickshell (this may take a while)...",
		IsComplete:  false,
		CommandInfo: "cmake --build build",
	}

	buildCmd := exec.CommandContext(ctx, "cmake", "--build", "build")
	buildCmd.Dir = tmpDir
	buildCmd.Env = append(os.Environ(), "TMPDIR="+cacheDir)
	if err := m.runWithProgressStep(buildCmd, progressChan, PhaseSystemPackages, 0.4, 0.8, "Building quickshell..."); err != nil {
		return fmt.Errorf("failed to build quickshell: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.8,
		Step:        "Installing quickshell...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo cmake --install build",
	}

	installCmd := privesc.ExecCommand(ctx, sudoPassword, "cmake --install build")
	installCmd.Dir = tmpDir
	if err := installCmd.Run(); err != nil {
		return fmt.Errorf("failed to install quickshell: %w", err)
	}

	m.log("quickshell installed successfully from source")
	return nil
}

func (m *ManualPackageInstaller) installHyprland(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing Hyprland from source...")

	homeDir := os.Getenv("HOME")
	if homeDir == "" {
		return fmt.Errorf("HOME environment variable not set")
	}

	cacheDir := filepath.Join(homeDir, ".cache", "dankinstall")
	if err := os.MkdirAll(cacheDir, 0o755); err != nil {
		return fmt.Errorf("failed to create cache directory: %w", err)
	}

	tmpDir := filepath.Join(cacheDir, "hyprland-build")
	if err := os.MkdirAll(tmpDir, 0o755); err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Cloning Hyprland repository...",
		IsComplete:  false,
		CommandInfo: "git clone --recursive https://github.com/hamza72x/Hyprland.git",
	}

	cloneCmd := exec.CommandContext(ctx, "git", "clone", "--recursive", "https://github.com/hamza72x/Hyprland.git", tmpDir)
	if err := cloneCmd.Run(); err != nil {
		return fmt.Errorf("failed to clone Hyprland: %w", err)
	}

	// Use the fork's build script which handles building all Hypr ecosystem
	// libraries from source (hyprutils, hyprlang, hyprgraphics, hyprcursor,
	// aquamarine, hyprwire, hyprtoolkit, hyprwayland-scanner, Lua 5.5) and
	// then builds Hyprland itself and packages it as an RPM.
	buildScript := filepath.Join(tmpDir, "hamza72x", "build-hyprland.sh")

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.2,
		Step:        "Building Hyprland + ecosystem libraries (this will take a while)...",
		IsComplete:  false,
		CommandInfo: "bash hamza72x/build-hyprland.sh",
	}

	buildCmd := exec.CommandContext(ctx, "bash", buildScript)
	buildCmd.Dir = tmpDir
	buildCmd.Env = append(os.Environ(), "TMPDIR="+cacheDir)
	if err := m.runWithProgressStep(buildCmd, progressChan, PhaseSystemPackages, 0.2, 0.9, "Building Hyprland..."); err != nil {
		return fmt.Errorf("failed to build Hyprland: %w", err)
	}

	// Install the resulting RPM
	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.9,
		Step:        "Installing Hyprland RPM...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo dnf install -y hyprland-*.rpm",
	}

	// Find the built RPM
	rpmPattern := filepath.Join(tmpDir, "hamza72x", "hyprland-*.rpm")
	matches, _ := filepath.Glob(rpmPattern)
	if len(matches) == 0 {
		// Also check ~/rpmbuild/RPMS
		rpmPattern = filepath.Join(homeDir, "rpmbuild", "RPMS", "x86_64", "hyprland-*.rpm")
		matches, _ = filepath.Glob(rpmPattern)
	}
	if len(matches) == 0 {
		return fmt.Errorf("failed to find built Hyprland RPM")
	}

	installCmd := privesc.ExecCommand(ctx, sudoPassword, fmt.Sprintf("dnf install -y %s", matches[0]))
	if err := installCmd.Run(); err != nil {
		return fmt.Errorf("failed to install Hyprland RPM: %w", err)
	}

	m.log("Hyprland installed successfully from source")
	return nil
}

func (m *ManualPackageInstaller) installGhostty(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing Ghostty from source...")

	homeDir := os.Getenv("HOME")
	if homeDir == "" {
		return fmt.Errorf("HOME environment variable not set")
	}

	cacheDir := filepath.Join(homeDir, ".cache", "dankinstall")
	if err := os.MkdirAll(cacheDir, 0o755); err != nil {
		return fmt.Errorf("failed to create cache directory: %w", err)
	}

	tmpDir := filepath.Join(cacheDir, "ghostty-build")
	if err := os.MkdirAll(tmpDir, 0o755); err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Cloning Ghostty repository...",
		IsComplete:  false,
		CommandInfo: "git clone https://github.com/hamza72x/ghostty.git",
	}

	cloneCmd := exec.CommandContext(ctx, "git", "clone", "https://github.com/hamza72x/ghostty.git", tmpDir)
	if err := cloneCmd.Run(); err != nil {
		return fmt.Errorf("failed to clone Ghostty: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.2,
		Step:        "Building Ghostty (this may take a while)...",
		IsComplete:  false,
		CommandInfo: "zig build -Doptimize=ReleaseFast",
	}

	buildCmd := exec.CommandContext(ctx, "zig", "build", "-Doptimize=ReleaseFast")
	buildCmd.Dir = tmpDir
	buildCmd.Env = append(os.Environ(), "TMPDIR="+cacheDir)
	if err := buildCmd.Run(); err != nil {
		return fmt.Errorf("failed to build Ghostty: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.8,
		Step:        "Installing Ghostty...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo cp zig-out/bin/ghostty /usr/local/bin/",
	}

	installCmd := privesc.ExecCommand(ctx, sudoPassword,
		fmt.Sprintf("cp %s/zig-out/bin/ghostty /usr/local/bin/", tmpDir))
	if err := installCmd.Run(); err != nil {
		return fmt.Errorf("failed to install Ghostty: %w", err)
	}

	m.log("Ghostty installed successfully from source")
	return nil
}

func (m *ManualPackageInstaller) installMatugen(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing matugen from source...")

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Cloning matugen repo...",
		IsComplete:  false,
		CommandInfo: "git clone https://github.com/hamza72x/matugen (no submodules)",
	}

	// Clone without --recurse-submodules to avoid broken gitlink with no URL
	tmpDir, err := os.MkdirTemp("", "matugen-build-*")
	if err != nil {
		return fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	cloneCmd := exec.CommandContext(ctx, "git", "clone", "--depth=1",
		"https://github.com/hamza72x/matugen.git", tmpDir)
	if err := cloneCmd.Run(); err != nil {
		return fmt.Errorf("failed to clone matugen: %w", err)
	}

	// Remove stale submodule gitlink entry (material-colors is a crates.io dep, not a path dep)
	rmSubmoduleCmd := exec.CommandContext(ctx, "git", "-C", tmpDir, "rm", "--cached", "-f", "material-colors")
	_ = rmSubmoduleCmd.Run() // ignore error if entry doesn't exist

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.2,
		Step:        "Building matugen with cargo...",
		IsComplete:  false,
		CommandInfo: "cargo install --path .",
	}

	buildCmd := exec.CommandContext(ctx, "cargo", "install", "--path", tmpDir)
	if err := m.runWithProgressStep(buildCmd, progressChan, PhaseSystemPackages, 0.2, 0.7, "Building matugen..."); err != nil {
		return fmt.Errorf("failed to build matugen: %w", err)
	}

	homeDir := os.Getenv("HOME")
	sourcePath := filepath.Join(homeDir, ".cargo", "bin", "matugen")
	targetPath := "/usr/local/bin/matugen"

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.7,
		Step:        "Installing matugen binary to system...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: fmt.Sprintf("sudo cp %s %s", sourcePath, targetPath),
	}

	if err := privesc.Run(ctx, sudoPassword, "cp", sourcePath, targetPath); err != nil {
		return fmt.Errorf("failed to copy matugen to /usr/local/bin: %w", err)
	}

	if err := privesc.Run(ctx, sudoPassword, "chmod", "+x", targetPath); err != nil {
		return fmt.Errorf("failed to make matugen executable: %w", err)
	}

	m.log("matugen installed successfully from source")
	return nil
}

func (m *ManualPackageInstaller) installDankMaterialShell(ctx context.Context, variant deps.PackageVariant, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing DankMaterialShell (DMS)...")

	if err := m.installDMSBinary(ctx, sudoPassword, progressChan); err != nil {
		m.logError("Failed to install DMS binary", err)
	}

	dmsPath := filepath.Join(os.Getenv("HOME"), ".config/quickshell/dms")

	if _, err := os.Stat(dmsPath); os.IsNotExist(err) {
		progressChan <- InstallProgressMsg{
			Phase:       PhaseSystemPackages,
			Progress:    0.90,
			Step:        "Cloning DankMaterialShell...",
			IsComplete:  false,
			CommandInfo: "git clone https://github.com/hamza72x/DankMaterialShell.git",
		}

		configDir := filepath.Dir(dmsPath)
		if err := os.MkdirAll(configDir, 0o755); err != nil {
			return fmt.Errorf("failed to create quickshell config directory: %w", err)
		}

		cloneCmd := exec.CommandContext(ctx, "git", "clone",
			"https://github.com/hamza72x/DankMaterialShell.git", dmsPath)
		if err := cloneCmd.Run(); err != nil {
			return fmt.Errorf("failed to clone DankMaterialShell: %w", err)
		}

		if forceDMSGit || variant == deps.VariantGit {
			m.log("Using git variant (master branch)")
			return nil
		}

		tagCmd := exec.CommandContext(ctx, "git", "-C", dmsPath, "describe", "--tags", "--abbrev=0", "origin/master")
		tagOutput, err := tagCmd.Output()
		if err != nil {
			m.log("Using default branch (no tags found)")
			return nil
		}

		latestTag := strings.TrimSpace(string(tagOutput))
		checkoutCmd := exec.CommandContext(ctx, "git", "-C", dmsPath, "checkout", latestTag)
		if err := checkoutCmd.Run(); err != nil {
			m.logError(fmt.Sprintf("Failed to checkout tag %s", latestTag), err)
			return nil
		}

		m.log(fmt.Sprintf("Checked out latest tag: %s", latestTag))
		m.log("DankMaterialShell cloned successfully")
		return nil
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.90,
		Step:        "Updating DankMaterialShell...",
		IsComplete:  false,
		CommandInfo: "Updating ~/.config/quickshell/dms",
	}

	fetchCmd := exec.CommandContext(ctx, "git", "-C", dmsPath, "fetch", "origin", "--tags", "--force")
	if err := fetchCmd.Run(); err != nil {
		m.logError("Failed to fetch updates", err)
		return nil
	}

	if forceDMSGit || variant == deps.VariantGit {
		branchCmd := exec.CommandContext(ctx, "git", "-C", dmsPath, "rev-parse", "--abbrev-ref", "HEAD")
		branchOutput, err := branchCmd.Output()
		if err != nil {
			m.logError("Failed to get current branch", err)
			return nil
		}

		branch := strings.TrimSpace(string(branchOutput))
		if branch == "" {
			branch = "master"
		}

		pullCmd := exec.CommandContext(ctx, "git", "-C", dmsPath, "pull", "origin", branch)
		if err := pullCmd.Run(); err != nil {
			m.logError("Failed to pull updates", err)
			return nil
		}

		m.log("DankMaterialShell updated successfully (git variant)")
		return nil
	}

	latestTagCmd := exec.CommandContext(ctx, "git", "-C", dmsPath, "describe", "--tags", "--abbrev=0", "origin/master")
	tagOutput, err := latestTagCmd.Output()
	if err != nil {
		m.logError("Failed to get latest tag", err)
		return nil
	}

	latestTag := strings.TrimSpace(string(tagOutput))
	checkoutCmd := exec.CommandContext(ctx, "git", "-C", dmsPath, "checkout", latestTag)
	if err := checkoutCmd.Run(); err != nil {
		m.logError(fmt.Sprintf("Failed to checkout tag %s", latestTag), err)
		return nil
	}

	m.log(fmt.Sprintf("Updated to tag: %s", latestTag))
	return nil
}

func (m *ManualPackageInstaller) installXwaylandSatellite(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	m.log("Installing xwayland-satellite from source...")

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Installing xwayland-satellite via cargo...",
		IsComplete:  false,
		CommandInfo: "cargo install --git https://github.com/hamza72x/xwayland-satellite --tag v0.7",
	}

	installCmd := exec.CommandContext(ctx, "cargo", "install", "--git", "https://github.com/hamza72x/xwayland-satellite", "--tag", "v0.7")
	if err := m.runWithProgressStep(installCmd, progressChan, PhaseSystemPackages, 0.1, 0.7, "Building xwayland-satellite..."); err != nil {
		return fmt.Errorf("failed to install xwayland-satellite: %w", err)
	}

	homeDir := os.Getenv("HOME")
	sourcePath := filepath.Join(homeDir, ".cargo", "bin", "xwayland-satellite")
	targetPath := "/usr/local/bin/xwayland-satellite"

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.7,
		Step:        "Installing xwayland-satellite binary to system...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: fmt.Sprintf("sudo cp %s %s", sourcePath, targetPath),
	}

	if err := privesc.Run(ctx, sudoPassword, "cp", sourcePath, targetPath); err != nil {
		return fmt.Errorf("failed to copy xwayland-satellite to /usr/local/bin: %w", err)
	}

	if err := privesc.Run(ctx, sudoPassword, "chmod", "+x", targetPath); err != nil {
		return fmt.Errorf("failed to make xwayland-satellite executable: %w", err)
	}

	m.log("xwayland-satellite installed successfully from source")
	return nil
}
