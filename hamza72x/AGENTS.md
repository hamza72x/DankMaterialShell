# AGENTS.md — hamza72x/DankMaterialShell Fork

## Purpose of This Repository

This is a **supply-chain hardened fork** of [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell). Every external dependency that the project clones or downloads at runtime has been forked under the `hamza72x` GitHub account, audited for safety, and all URLs in the source code rewritten to point to those forks.

The goal is simple: **zero trust in upstream orgs at runtime**. If any upstream repo is compromised, this fork remains unaffected until you explicitly sync.

## What This Fork Is NOT

- NOT a feature fork — no features added or removed
- NOT a code refactor — logic is identical to upstream
- NOT a permanent divergence — designed to be rebased/merged from upstream periodically

## Architecture (Inherited from Upstream)

DankMaterialShell is a monorepo with two components:

1. **Go Backend** (`core/`) — system integration, IPC server, CLI tools, installer
2. **QML Frontend** (`quickshell/`) — UI layer built on Quickshell framework

The backend provides all system integration (D-Bus, Wayland, hardware) via a Unix socket IPC server. The QML frontend is a thin reactive layer consuming that API.

## What Was Changed (Relative to Upstream)

Only **URL string constants** were replaced. No logic, no control flow, no algorithms were modified.

### Files Modified (runtime URL replacements)

```
core/install.sh                                  — installer download URLs
core/internal/version/version.go                 — release version check API
core/internal/distros/base.go                    — binary download URLs
core/internal/distros/manual_packages.go         — all git clone URLs (8 repos)
core/internal/distros/opensuse.go                — quickshell clone URLs
core/internal/plugins/registry.go                — plugin registry repo URL
core/internal/themes/registry.go                 — theme registry repo URL
core/internal/plugins/search.go                  — first-party repo detection prefix
core/internal/server/plugins/utils.go            — first-party repo detection prefix
core/internal/tui/views_welcome.go               — error message URL
core/cmd/dms/commands_features.go                — self-update clone/download URLs
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

### Files Added

```
hamza72x/README.md              — fork documentation
hamza72x/install.sh             — fork-specific installer script
hamza72x/audit-reports/*.html   — HTML security audit reports (10 programs + index)
```

### What Was NOT Changed

- **Go module path** (`github.com/AvengeMedia/DankMaterialShell/core/...`) — this is the Go module identity used in import statements; changing it would break compilation. It does not affect runtime behavior.
- **OBS/COPR/PPA repository identifiers** (`home:AvengeMedia:danklinux`, `ppa:avengemedia/dms`) — these are Linux package repo names on external build services. They are only used when pre-built distro packages exist and are a fallback path.
- **Code comments** referencing upstream — cosmetic, no runtime effect.

## Forked Dependencies (10 Repos)

Every external repo that is cloned or downloaded during installation or runtime:

| # | Original | Fork | Type |
|---|----------|------|------|
| 1 | AvengeMedia/DankMaterialShell | hamza72x/DankMaterialShell | Main project |
| 2 | AvengeMedia/dgop | hamza72x/dgop | System monitor (Go) |
| 3 | AvengeMedia/dms-plugin-registry | hamza72x/dms-plugin-registry | Plugin/theme registry (JSON data) |
| 4 | AvengeMedia/danksearch | hamza72x/danksearch | File search daemon (Go) |
| 5 | InioX/matugen | hamza72x/matugen | Color scheme generator (Rust) |
| 6 | quickshell-mirror/quickshell | hamza72x/quickshell | QML shell framework (C++) |
| 7 | YaLTeR/niri | hamza72x/niri | Wayland compositor (Rust) |
| 8 | hyprwm/Hyprland | hamza72x/Hyprland | Wayland compositor (C++) |
| 9 | ghostty-org/ghostty | hamza72x/ghostty | Terminal emulator (Zig) |
| 10 | Supreeeme/xwayland-satellite | hamza72x/xwayland-satellite | XWayland bridge (Rust) |

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/hamza72x/DankMaterialShell/main/hamza72x/install.sh | sh
```

The installer:
1. Checks Linux + architecture (amd64/arm64)
2. Fetches latest release from `hamza72x/DankMaterialShell`
3. Verifies SHA256 checksum
4. Runs the `dankinstall` TUI which clones all deps from `hamza72x/*`

## Syncing With Upstream

```sh
git remote add upstream https://github.com/AvengeMedia/DankMaterialShell.git
git fetch upstream
git merge upstream/main
```

After merging:
1. Re-apply URL replacements if upstream added new external URLs (search for `AvengeMedia`, `quickshell-mirror`, `YaLTeR`, `hyprwm`, `ghostty-org`, `Supreeeme`, `InioX`)
2. Sync each forked dependency repo with its upstream
3. Re-audit any new code before pushing

## Security Audit

All 10 repos were audited on **June 30, 2026**. Reports are at `hamza72x/audit-reports/`.

Verdict: **ALL SAFE**. No telemetry, no data exfiltration, no backdoors, no obfuscated code found in any component.

## Development Notes

- Build the Go CLI: `cd core && make`
- Build the installer: `cd core && make dankinstall`
- Run the shell: `dms run` (requires Quickshell installed)
- Run tests: `cd core && make test`

The Go module path remains `github.com/AvengeMedia/DankMaterialShell/core` in import statements. This is intentional — it's a compilation-time identifier, not a runtime URL. The built binary uses only `hamza72x` URLs at runtime.
