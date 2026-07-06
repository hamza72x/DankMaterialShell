# AGENTS.md — hamza72x/DankMaterialShell Fork

## Goal

Deploy DankMaterialShell on a **barebone Fedora 44** machine (192.168.0.185) by syncing this repo via rsync and running `hamza72x/install.sh`. Everything builds from source using `hamza72x/*` forks. No package repos from AvengeMedia, no auto-updates, no trust in upstream orgs at runtime.

## Purpose of This Repository

This is a **supply-chain hardened fork** of [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell). Every external dependency that the project clones or downloads at runtime has been forked under the `hamza72x` GitHub account, audited for safety, and all URLs in the source code rewritten to point to those forks.

The goal is simple: **zero trust in upstream orgs at runtime**. If any upstream repo is compromised, this fork remains unaffected until you explicitly sync.

## Deployment Model (rsync + local build)

This is a **private repo**. It is NOT installed via `dnf`, COPR, or any package manager. The workflow is:

1. Develop/edit on the dev machine (this working copy)
2. `rsync` the repo to the target Fedora machine
3. Run `bash ~/DankMaterialShell/hamza72x/install.sh` on the target

The target machine at `hamza@192.168.0.185` is a barebone Fedora 44 (no GUI, no compositor, no audio stack, no Qt — just base system + SSH + NetworkManager + bluez).

### Rsync Command

```sh
rsync -avz --delete --exclude='.git' --exclude='core/bin' --exclude='core/vendor' \
  /home/hamza/personal/DankMaterialShell/ hamza@192.168.0.185:~/DankMaterialShell/
```

### Run Installer on Target

```sh
ssh -t hamza@192.168.0.185 'bash ~/DankMaterialShell/hamza72x/install.sh'
```

The `-t` flag is required so `sudo` can prompt for a password.

## What `hamza72x/install.sh` Does (Step by Step)

1. **Detects the repo is already on disk** (synced via rsync) — skips GitHub SSH clone
2. **Installs build dependencies via dnf:**
   - Core build tools: git, make, gcc, gcc-c++, meson, rpm-build
   - Go compiler: golang
   - Rust/Cargo: cargo, rust
   - CMake/Ninja: cmake, ninja-build, pkg-config
   - Runtime services: pipewire, pipewire-pulseaudio, wireplumber, upower, power-profiles-daemon, fontconfig, mesa-dri-drivers
   - Hyprland build deps: glslang-devel, vulkan-headers, cairo-devel, pango-devel, pixman-devel, mesa-libgbm-devel, libseat-devel, libdisplay-info-devel, xcb-util-*, spirv-tools-devel, etc. (full list from `hamza72x/Hyprland` fork's `build-hyprland.sh`)
   - Hyprland runtime deps: libwayland-*, mesa-libEGL, vulkan-loader, xorg-x11-server-Xwayland, etc.
   - Qt6/Quickshell dev packages: qt6-qtbase-devel, qt6-qtdeclarative-devel, qt6-qtshadertools-devel, qt6-qtwayland-devel, qt6-qtmultimedia-devel, pipewire-devel, pam-devel, polkit-devel, jemalloc-devel
3. **Enables system services:** upower, power-profiles-daemon
4. **Builds `dms` CLI** from `core/` (Go)
5. **Builds `dankinstall` TUI** from `core/cmd/dankinstall/` (Go)
6. **Pre-deploys DMS QML files:** Symlinks `~/.config/quickshell/dms` → the repo's `quickshell/` dir (so `dankinstall` doesn't try to clone the private repo)
7. **Runs `dankinstall` TUI** — interactive compositor/terminal selection, builds from source:
   - quickshell (C++/CMake from `hamza72x/quickshell`)
   - hyprland (via `hamza72x/build-hyprland.sh` which builds all Hypr ecosystem libs + Lua 5.5 + Hyprland itself → RPM)
   - ghostty (Zig from `hamza72x/ghostty`) — or kitty/alacritty from DNF
   - matugen (Rust via `cargo install --git hamza72x/matugen`)
   - dgop (Go from `hamza72x/dgop`)
   - niri (if chosen instead of Hyprland)
8. **Installs `dms` binary system-wide:** `sudo make install` in `core/`
9. **Installs shell files + systemd service:** `sudo make install` at repo root

## Key Design Decisions & Fixes Applied

### 1. Private Repo Clone Bypass (Step 6)

**Problem:** `dankinstall`'s `installDankMaterialShell()` function tries to `git clone https://github.com/hamza72x/DankMaterialShell.git` into `~/.config/quickshell/dms`. Since the repo is private, this prompts for credentials and fails.

**Fix:** Before running `dankinstall`, `install.sh` creates a symlink:
```sh
ln -sfn "$CLONE_DIR/quickshell" ~/.config/quickshell/dms
```
`dankinstall` sees the path already exists, skips the clone, and continues.

### 2. Hyprland Build Process (modified `installHyprland()`)

**Problem:** The original `installHyprland()` in `manual_packages.go` ran `make all` directly. This fails on Fedora 44 because:
- Fedora ships outdated Hypr ecosystem libs (hyprutils 0.7.1 vs needed 0.13.1)
- Missing: aquamarine, hyprwire, Lua 5.5
- `glslang-devel` and other build deps were never installed

**Fix:** Replaced `installHyprland()` to:
1. Clone `hamza72x/Hyprland` (stays on `main` = v0.55)
2. Run `bash hamza72x/build-hyprland.sh` which:
   - Installs all build deps via dnf (idempotent, skips if already present)
   - Builds from source: hyprwayland-scanner, hyprutils, hyprlang, hyprgraphics, hyprcursor, hyprwire, aquamarine, hyprtoolkit, hyprland-guiutils, Lua 5.5
   - Builds Hyprland itself
   - Packages as RPM
3. Installs the resulting RPM via `sudo dnf install -y`

### 3. Missing Runtime Packages

**Problem:** Barebone Fedora has no audio stack, no display drivers, no font tools, no power management.

**Fix:** Added to `install.sh` dnf section:
- `pipewire pipewire-pulseaudio wireplumber` (audio)
- `upower power-profiles-daemon` (power management)
- `fontconfig` (font discovery)
- `mesa-dri-drivers` (GPU acceleration)

## Hard Rules — DO NOT VIOLATE

1. **NEVER add, restore, or re-enable any URL pointing to `AvengeMedia`, `quickshell-mirror`, `YaLTeR`, `hyprwm`, `ghostty-org`, `Supreeeme`, or `InioX` GitHub orgs.** All runtime URLs must point to `hamza72x/*` forks only.

2. **NEVER re-enable `dms update`, `dms update check`, or any auto-update mechanism.** These commands are intentionally disabled. They must remain no-ops that print an explanation.

3. **NEVER restore the GitHub API version check** in `core/internal/version/version.go`. The `GetLatestVersion()` function must always return the current local version without making any network call.

4. **NEVER add COPR/PPA/OBS repo references** for DMS dependencies. All DMS-related packages must use `RepoTypeManual` (build from source from our forks). Third-party upstream package repos from AvengeMedia are banned.

5. **NEVER introduce new external URLs** without adding them to this document and ensuring they point to a `hamza72x`-controlled fork.

6. **Official Linux distribution packages are ALLOWED.** Packages from Fedora's official repos, Arch community/extra, Debian main, etc. are trusted. Only DMS-org-specific repos (COPR `avengemedia/*`, PPA `ppa:avengemedia/*`, OBS `home:AvengeMedia:*`) are banned.

7. **The Go module path `github.com/AvengeMedia/DankMaterialShell/core/...` in import statements is the ONLY acceptable reference to `AvengeMedia`.** It is a compile-time identifier, not a runtime URL. Changing it would break the Go module system.

8. **NEVER install DMS from DNF/package manager.** This repo is deployed via rsync and built locally. The `DankMaterialShell` RPM in Fedora repos is the upstream version — we don't use it.

## Architecture (Inherited from Upstream)

DankMaterialShell is a monorepo with two components:

1. **Go Backend** (`core/`) — system integration, IPC server, CLI tools, installer
2. **QML Frontend** (`quickshell/`) — UI layer built on Quickshell framework

The backend provides all system integration (D-Bus, Wayland, hardware) via a Unix socket IPC server. The QML frontend is a thin reactive layer consuming that API.

## Files Modified in This Fork

### Upstream URL Replacements (supply-chain hardening)

```
core/install.sh                                  — installer download URLs
core/internal/version/version.go                 — version check disabled (returns local only)
core/internal/distros/base.go                    — binary download URLs
core/internal/distros/manual_packages.go         — all git clone URLs + Hyprland build logic
core/internal/distros/opensuse.go                — quickshell clone URLs, RepoTypeManual
core/internal/distros/fedora.go                  — RepoTypeManual (no COPR)
core/internal/distros/ubuntu.go                  — RepoTypeManual (no PPA)
core/internal/distros/debian.go                  — RepoTypeManual (no OBS)
core/internal/plugins/registry.go                — plugin registry repo URL
core/internal/themes/registry.go                 — theme registry repo URL
core/internal/plugins/search.go                  — first-party repo detection prefix
core/internal/server/plugins/utils.go            — first-party repo detection prefix
core/internal/tui/views_welcome.go               — error message URL
core/cmd/dms/commands_features.go                — update commands disabled, self-update removed
core/internal/distros/base_test.go               — test fixture URL
core/internal/server/plugins/handlers_test.go    — test fixture URLs
distro/scripts/copr-upload.sh                    — package build download URL
distro/scripts/ppa-build.sh                      — package build download URLs
distro/scripts/ppa-sync-plan.sh                  — git remote URL
quickshell/Modals/DankLauncherV2/ResultsList.qml — dsearch install hint
quickshell/Modals/Changelog/ChangelogContent.qml — plugin link
quickshell/Modules/Settings/AboutTab.qml         — repo link, tooltip, LICENSE
quickshell/Modules/Settings/ThemeColorsTab.qml   — theme plugin links
```

### Fedora Deployment Fixes (this session)

```
hamza72x/install.sh                              — added all runtime + Hyprland build deps,
                                                    pre-deploy symlink step, service enablement
core/internal/distros/manual_packages.go         — installHyprland() rewritten to use
                                                    hamza72x/build-hyprland.sh (builds ecosystem
                                                    libs + Lua 5.5 + packages as RPM)
```

### Files Added

```
hamza72x/AGENTS.md              — this file (fork rules, deployment, and context)
hamza72x/README.md              — fork documentation
hamza72x/install.sh             — fork-specific installer script (rsync + local build)
hamza72x/audit-reports/*.html   — HTML security audit reports (10 programs + index)
```

## Forked Dependencies (10 Repos)

Every external repo that is cloned or downloaded during installation:

| # | Original | Fork | Visibility | Type |
|---|----------|------|-----------|------|
| 1 | AvengeMedia/DankMaterialShell | hamza72x/DankMaterialShell | **PRIVATE** | Main project |
| 2 | AvengeMedia/dgop | hamza72x/dgop | Public | System monitor (Go) |
| 3 | AvengeMedia/dms-plugin-registry | hamza72x/dms-plugin-registry | Public | Plugin/theme registry (JSON data) |
| 4 | AvengeMedia/danksearch | hamza72x/danksearch | Public | File search daemon (Go) |
| 5 | InioX/matugen | hamza72x/matugen | Public | Color scheme generator (Rust) |
| 6 | quickshell-mirror/quickshell | hamza72x/quickshell | Public | QML shell framework (C++) |
| 7 | YaLTeR/niri | hamza72x/niri | Public | Wayland compositor (Rust) |
| 8 | hyprwm/Hyprland | hamza72x/Hyprland | Public | Wayland compositor (C++) |
| 9 | ghostty-org/ghostty | hamza72x/ghostty | Public | Terminal emulator (Zig) |
| 10 | Supreeeme/xwayland-satellite | hamza72x/xwayland-satellite | Public | XWayland bridge (Rust) |

> **Note:** Only the main repo (#1) is private. All dependency forks (#2–#10) are public. The `dankinstall` TUI clones dependencies via HTTPS (no SSH required for those). The main repo is deployed via rsync (never cloned on the target).

## Target Machine State (Fedora 44 @ 192.168.0.185)

### Already Present (base system)
- systemd, dbus-broker, polkit
- NetworkManager, bluez
- openssh-server
- Fedora 44, kernel 7.0.14

### Installed by `install.sh` (via dnf)
- Build tools: git, make, gcc, gcc-c++, golang, cargo, rust, cmake, ninja-build, meson, rpm-build
- Audio: pipewire, pipewire-pulseaudio, wireplumber
- Power: upower, power-profiles-daemon
- Display: mesa-dri-drivers, fontconfig
- Qt6: qt6-qtbase-devel, qt6-qtdeclarative-devel, qt6-qtshadertools-devel, qt6-qtwayland-devel, qt6-qtmultimedia-devel
- Hyprland deps: glslang-devel, vulkan-headers, cairo-devel, pango-devel, pixman-devel, 30+ more (see install.sh)
- Wayland: wayland-devel, wayland-protocols-devel, libdrm-devel, xorg-x11-server-Xwayland

### Built from Source by `dankinstall`
- quickshell (from hamza72x/quickshell)
- Hyprland v0.55 + ecosystem (from hamza72x/Hyprland via build-hyprland.sh)
- ghostty (from hamza72x/ghostty) — or kitty/alacritty from DNF
- matugen (from hamza72x/matugen)
- dgop (from hamza72x/dgop)
- dms CLI (from this repo's core/)

## Post-Install: Updates Are Permanently Disabled

After installation, **no automatic or manual updates from any remote will ever occur**:

| Mechanism | Status | Details |
|-----------|--------|---------|
| `dms update` | DISABLED | Prints explanation, makes zero network calls |
| `dms update check` | DISABLED | Prints explanation, makes zero network calls |
| Version check (dms doctor) | NEUTERED | Returns local version only, never contacts GitHub API |
| `git fetch` in DMS config | NEVER TRIGGERED | Shell never auto-fetches from any remote |
| COPR/PPA/OBS repo install | REMOVED | All DMS deps use `RepoTypeManual` (build from source) |
| Plugin registry update | LOCAL ONLY | Uses `hamza72x/dms-plugin-registry` fork, no auto-sync |

## Development Notes

- Build the Go CLI: `cd core && make`
- Build the installer: `cd core && make dankinstall`
- Run the shell: `dms run` (requires Quickshell installed)
- Run tests: `cd core && make test`
- Deploy to target: rsync + `ssh -t hamza@192.168.0.185 'bash ~/DankMaterialShell/hamza72x/install.sh'`

The Go module path remains `github.com/AvengeMedia/DankMaterialShell/core` in import statements. This is intentional — it's a compilation-time identifier, not a runtime URL. The built binary uses only `hamza72x` URLs at runtime.

## Troubleshooting

### "Username for 'https://github.com'" prompt during dankinstall
The `installDankMaterialShell()` function is trying to clone the private repo. Fix: ensure `~/.config/quickshell/dms` symlink exists before running dankinstall (Step 6 in install.sh handles this).

### Hyprland build fails with missing `glslang` / `vulkan-headers` / etc.
The Hyprland build deps weren't installed. Fix: ensure the "Installing Hyprland build dependencies" step in install.sh runs successfully (all packages in the `--skip-unavailable` dnf call).

### `sudo: a terminal is required`
Use `ssh -t` (not plain `ssh`) when running install.sh remotely.

## Checklist Before Any Commit

Before pushing any change to this fork, verify:

- [ ] `grep -rn "github.com/AvengeMedia" --include="*.go" | grep -v "go.mod\|go.sum\|import "` returns ZERO results (no runtime URLs to upstream)
- [ ] `grep -rn "quickshell-mirror\|YaLTeR/niri\|hyprwm/Hyprland\|ghostty-org\|Supreeeme\|InioX/matugen" --include="*.go" --include="*.sh" --include="*.qml"` returns ZERO results
- [ ] `dms update` prints disabled message (not actually updating)
- [ ] `core/internal/version/version.go` `GetLatestVersion` never makes network calls
- [ ] No `RepoTypeCOPR`, `RepoTypePPA`, or `RepoTypeOBS` mappings exist for DMS-related packages
- [ ] All git clone URLs in `manual_packages.go` point to `hamza72x/*`
- [ ] `hamza72x/install.sh` pre-deploys the QML symlink before running dankinstall
- [ ] Hyprland builds via `build-hyprland.sh` (not bare `make all`)
