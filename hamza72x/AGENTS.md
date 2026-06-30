# AGENTS.md — hamza72x/DankMaterialShell Fork

## Purpose of This Repository

This is a **supply-chain hardened fork** of [AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell). Every external dependency that the project clones or downloads at runtime has been forked under the `hamza72x` GitHub account, audited for safety, and all URLs in the source code rewritten to point to those forks.

The goal is simple: **zero trust in upstream orgs at runtime**. If any upstream repo is compromised, this fork remains unaffected until you explicitly sync.

## Hard Rules — DO NOT VIOLATE

1. **NEVER add, restore, or re-enable any URL pointing to `AvengeMedia`, `quickshell-mirror`, `YaLTeR`, `hyprwm`, `ghostty-org`, `Supreeeme`, or `InioX` GitHub orgs.** All runtime URLs must point to `hamza72x/*` forks only.

2. **NEVER re-enable `dms update`, `dms update check`, or any auto-update mechanism.** These commands are intentionally disabled. They must remain no-ops that print an explanation.

3. **NEVER restore the GitHub API version check** in `core/internal/version/version.go`. The `GetLatestVersion()` function must always return the current local version without making any network call.

4. **NEVER add COPR/PPA/OBS repo references** for DMS dependencies. All DMS-related packages must use `RepoTypeManual` (build from source from our forks). Third-party upstream package repos from AvengeMedia are banned.

5. **NEVER introduce new external URLs** without adding them to this document and ensuring they point to a `hamza72x`-controlled fork.

6. **Official Linux distribution packages are ALLOWED.** Packages from Fedora's official repos, Arch community/extra, Debian main, etc. are trusted. Only DMS-org-specific repos (COPR `avengemedia/*`, PPA `ppa:avengemedia/*`, OBS `home:AvengeMedia:*`) are banned.

7. **The Go module path `github.com/AvengeMedia/DankMaterialShell/core/...` in import statements is the ONLY acceptable reference to `AvengeMedia`.** It is a compile-time identifier, not a runtime URL. Changing it would break the Go module system.

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

### URL String Replacements

All runtime URLs pointing to upstream orgs were replaced with `hamza72x` equivalents. No logic, no control flow, no algorithms were modified.

### Update Mechanism Disabled

- `dms update` — command body replaced with informational message, zero network calls
- `dms update check` — same, no-op
- `GetLatestVersion()` — always returns local version, never contacts any remote
- `git fetch` — never triggered by DMS itself for update purposes

### Package Repo References Removed

All `RepoTypePPA`, `RepoTypeCOPR`, `RepoTypeOBS` mappings for DMS dependencies changed to `RepoTypeManual`. The installer always builds from source using `hamza72x/*` forks. It never adds third-party package repos to your system for DMS packages.

### Files Modified

```
core/install.sh                                  — installer download URLs
core/internal/version/version.go                 — version check disabled (returns local only)
core/internal/distros/base.go                    — binary download URLs
core/internal/distros/manual_packages.go         — all git clone URLs (8 repos)
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

### Files Added

```
hamza72x/AGENTS.md              — this file (fork rules and context)
hamza72x/README.md              — fork documentation
hamza72x/install.sh             — fork-specific installer script
hamza72x/audit-reports/*.html   — HTML security audit reports (10 programs + index)
```

### What Was NOT Changed

- **Go module path** (`github.com/AvengeMedia/DankMaterialShell/core/...`) — compile-time module identity, not a runtime URL. Changing it breaks the Go build.
- **Code comments** referencing upstream — cosmetic, no runtime effect.

## Forked Dependencies (10 Repos)

Every external repo that is cloned or downloaded during installation or runtime:

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

> **Note:** Only the main repo (#1) is private. All dependency forks (#2–#10) are public. The `dankinstall` TUI clones dependencies via HTTPS (no SSH required for those). Only the initial clone of the main repo requires SSH authentication.

## Installation

This is a **private repo**. The curl one-liner does not work (requires auth). Use SSH clone + local build.

### On a barebone Fedora (or any supported distro):

```sh
# 1. Set up SSH key for GitHub (skip if already done)
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
# → Add that key at https://github.com/settings/ssh/new

# 2. Clone and run installer
git clone git@github.com:hamza72x/DankMaterialShell.git ~/.local/src/DankMaterialShell
cd ~/.local/src/DankMaterialShell/hamza72x
bash install.sh
```

The installer handles everything:
1. Verifies SSH access to GitHub
2. Installs build dependencies via system package manager (dnf/pacman/apt)
3. Builds `dms` CLI and `dankinstall` from source
4. Runs `dankinstall` TUI (compositor/terminal selection, builds all deps from `hamza72x/*` forks)
5. Installs the shell system-wide + systemd service

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

### What IS allowed (not blocked):

- **System package manager** (`dnf update`, `pacman -Syu`, `apt upgrade`) — these update official distro packages and are completely unrelated to DMS. They are trusted.
- **User-initiated git operations** — if YOU manually run `git pull` in the DMS config dir, that's your choice. The shell itself will never do this.
- **Plugin installation from registry** — plugins are cloned from repos listed in the `hamza72x/dms-plugin-registry` fork. This is a user-initiated action (Settings > Plugins > Install).

### Why this matters:

If updates were allowed, a compromised upstream could:
1. Push a malicious release to GitHub → auto-update downloads and runs it
2. Modify a COPR/PPA package → your next install gets a backdoored binary
3. Push to the plugin registry → a plugin update injects malicious code
4. Modify any of the 10 dependency repos → your next build includes their code

By disabling all update paths and building from pinned forks, this fork ensures the code running on your machine is exactly what was audited on the fork date.

## Syncing With Upstream (Manual Process)

This is intentionally manual and requires human review:

```sh
# 1. Add upstream remote (one-time)
git remote add upstream https://github.com/AvengeMedia/DankMaterialShell.git

# 2. Fetch (does NOT apply anything)
git fetch upstream

# 3. Review what changed
git log --oneline main..upstream/main

# 4. Merge only after auditing
git merge upstream/main

# 5. Re-apply fork patches
#    Search for any new upstream URLs that need replacing:
grep -rn "github.com/AvengeMedia\|quickshell-mirror\|YaLTeR\|hyprwm\|ghostty-org\|Supreeeme\|InioX" \
  --include="*.go" --include="*.sh" --include="*.qml" \
  | grep -v "go.mod\|go.sum\|import\|//"

# 6. Rebuild and test
cd core && make && make test

# 7. Push
git push origin main
```

Also sync each forked dependency:
```sh
# For each repo (dgop, quickshell, niri, etc.):
cd ~/forks/dgop
git remote add upstream https://github.com/AvengeMedia/dgop.git
git fetch upstream
git log --oneline main..upstream/main  # Review
git merge upstream/main                 # Merge after audit
git push origin main
```

## Security Audit

All 10 repos were audited on **June 30, 2026**. Reports are at `hamza72x/audit-reports/`.

Verdict: **ALL SAFE**. No telemetry, no data exfiltration, no backdoors, no obfuscated code found in any component.

### Audit Scope Per Repo:

| Repo | Files Inspected | Network Calls | exec.Command | Verdict |
|------|----------------|---------------|--------------|---------|
| DankMaterialShell | All Go + QML | Weather API, ip-api.com (local use) | System tools (pacman, systemctl, etc.) | SAFE |
| dgop | All Go | ZERO outbound | 1 (nvidia-smi, hardcoded) | SAFE |
| dms-plugin-registry | All JSON + CI | ZERO (data-only repo) | ZERO | SAFE |
| danksearch | All Go | ZERO outbound | ZERO | SAFE |
| matugen | All Rust | ZERO (default build) | User-configured hooks only | SAFE |
| quickshell | All C++/QML | ZERO external | QML process spawning (by design) | SAFE |
| niri | All Rust + build.rs | ZERO (no networking crates) | systemctl, dbus-update (local) | SAFE |
| Hyprland | All C++ + CMake | ZERO (no networking libs) | hyprpm uses git (user-initiated) | SAFE |
| ghostty | All Zig + Swift | ZERO (Sentry is disk-only) | ZERO | SAFE |
| xwayland-satellite | All Rust | ZERO (no networking crates) | Xwayland spawn only | SAFE |

## Development Notes

- Build the Go CLI: `cd core && make`
- Build the installer: `cd core && make dankinstall`
- Run the shell: `dms run` (requires Quickshell installed)
- Run tests: `cd core && make test`

The Go module path remains `github.com/AvengeMedia/DankMaterialShell/core` in import statements. This is intentional — it's a compilation-time identifier, not a runtime URL. The built binary uses only `hamza72x` URLs at runtime.

## Checklist Before Any Commit

Before pushing any change to this fork, verify:

- [ ] `grep -rn "github.com/AvengeMedia" --include="*.go" | grep -v "go.mod\|go.sum\|import "` returns ZERO results (no runtime URLs to upstream)
- [ ] `grep -rn "quickshell-mirror\|YaLTeR/niri\|hyprwm/Hyprland\|ghostty-org\|Supreeeme\|InioX/matugen" --include="*.go" --include="*.sh" --include="*.qml"` returns ZERO results
- [ ] `dms update` prints disabled message (not actually updating)
- [ ] `core/internal/version/version.go` `GetLatestVersion` never makes network calls
- [ ] No `RepoTypeCOPR`, `RepoTypePPA`, or `RepoTypeOBS` mappings exist for DMS-related packages
- [ ] All git clone URLs in `manual_packages.go` point to `hamza72x/*`
