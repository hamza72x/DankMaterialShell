# DankMaterialShell — hamza72x Security-Audited Fork

This is a **security-audited fork** of [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) with all upstream dependencies forked under the `hamza72x` GitHub organization.

## Why This Fork Exists

**Supply-chain security.** The original DankMaterialShell pulls binaries and sources from multiple third-party GitHub organizations at install time. A compromise of any single upstream repo could inject malicious code into your system.

This fork mitigates that risk by:

1. Forking every dependency under a single audited org (`hamza72x`)
2. Pinning all download URLs to the forked repos
3. Auditing the source of each dependency before forking
4. Making **zero code logic changes** — only URL replacements

## Installation

One-liner:

```sh
curl -fsSL https://raw.githubusercontent.com/hamza72x/DankMaterialShell/main/hamza72x/install.sh | sh
```

The installer will:
- Verify your system is Linux (amd64 or arm64)
- Download the latest release from the `hamza72x` org
- Verify the SHA256 checksum before executing anything
- Build all dependencies from source using our forks (never from upstream repos)

## Post-Install: No Upstream Updates

After installation, **all DMS self-update mechanisms are disabled**:

- `dms update` — blocked, prints explanation
- `dms update check` — blocked, no network calls made
- Version check — reports local version only, never contacts GitHub
- No COPR/PPA/OBS packages from AvengeMedia are ever used

**Your system package manager (dnf, pacman, apt, etc.) is NOT affected** — official distro packages update normally. Only DMS-specific remote update paths are blocked.

## Forked Repositories

| # | Original | Fork | Purpose |
|---|----------|------|---------|
| 1 | AvengeMedia/DankMaterialShell | hamza72x/DankMaterialShell | Main shell |
| 2 | AvengeMedia/dgop | hamza72x/dgop | System monitoring (CPU/RAM/GPU) |
| 3 | AvengeMedia/dms-plugin-registry | hamza72x/dms-plugin-registry | Plugin & theme registry |
| 4 | AvengeMedia/danksearch | hamza72x/danksearch | File search for launcher (optional) |
| 5 | InioX/matugen | hamza72x/matugen | Material color generation from wallpapers |
| 6 | quickshell-mirror/quickshell | hamza72x/quickshell | QML shell framework |
| 7 | YaLTeR/niri | hamza72x/niri | Scrollable tiling Wayland compositor |
| 8 | hyprwm/Hyprland | hamza72x/Hyprland | Dynamic tiling Wayland compositor |
| 9 | ghostty-org/ghostty | hamza72x/ghostty | GPU-accelerated terminal emulator |
| 10 | Supreeeme/xwayland-satellite | hamza72x/xwayland-satellite | Rootless XWayland bridge |

## Audit Reports

Detailed audit reports for each forked dependency are available at:

[`./audit-reports/index.html`](./audit-reports/index.html)

**Last audit date:** June 30, 2026

## What Was Changed

This fork contains **no code logic changes**. The only modifications are:

- All GitHub download/clone URLs replaced from their original orgs to `hamza72x`
- This `hamza72x/` directory added with the fork-specific installer and documentation
- Audit reports documenting the state of each dependency at fork time

If you diff this fork against upstream (excluding the `hamza72x/` directory), you will find only URL string replacements.

## Syncing With Upstream

To pull in updates from the original AvengeMedia repo:

```sh
# Add upstream remote (one-time)
git remote add upstream https://github.com/AvengeMedia/DankMaterialShell.git

# Fetch and merge
git fetch upstream
git merge upstream/main

# Review changes, re-audit if needed, then push
git push origin main
```

After syncing, re-run the audit process to verify no unexpected changes were introduced.
