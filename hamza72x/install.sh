#!/usr/bin/env bash

set -euo pipefail

# ============================================================
#  DankMaterialShell Installer — hamza72x fork
#  https://github.com/hamza72x/DankMaterialShell
#
#  Security-audited fork with all dependencies pinned under
#  the hamza72x GitHub org for supply-chain safety.
# ============================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TEMP_DIR=""

# Cleanup on exit
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Banner
printf "\n"
printf "%b╔══════════════════════════════════════════════════════════╗%b\n" "$CYAN" "$NC"
printf "%b║  DankMaterialShell — hamza72x fork                      ║%b\n" "$CYAN" "$NC"
printf "%b║  Security-audited • Supply-chain verified                ║%b\n" "$CYAN" "$NC"
printf "%b║  https://github.com/hamza72x/DankMaterialShell          ║%b\n" "$CYAN" "$NC"
printf "%b╚══════════════════════════════════════════════════════════╝%b\n" "$CYAN" "$NC"
printf "\n"

# Check for root privileges
if [ "$(id -u)" == "0" ]; then
    printf "%bError: This script must not be run as root%b\n" "$RED" "$NC"
    exit 1
fi

# Check if running on Linux
if [ "$(uname)" != "Linux" ]; then
    printf "%bError: This installer only supports Linux systems%b\n" "$RED" "$NC"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
x86_64)
    ARCH="amd64"
    ;;
aarch64)
    ARCH="arm64"
    ;;
*)
    printf "%bError: Unsupported architecture: %s%b\n" "$RED" "$ARCH" "$NC"
    printf "This installer only supports x86_64 (amd64) and aarch64 (arm64) architectures\n"
    exit 1
    ;;
esac

printf "%b[1/5]%b Fetching latest release info...\n" "$GREEN" "$NC"

# Get the latest release version
LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/hamza72x/DankMaterialShell/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    printf "%bError: Could not fetch latest version%b\n" "$RED" "$NC"
    exit 1
fi

printf "       Found version: %b%s%b (arch: %s)\n" "$BOLD" "$LATEST_VERSION" "$NC" "$ARCH"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Download the gzipped binary and its checksum
printf "%b[2/5]%b Downloading installer...\n" "$GREEN" "$NC"
curl -fSL "https://github.com/hamza72x/DankMaterialShell/releases/download/$LATEST_VERSION/dankinstall-$ARCH.gz" -o "installer.gz"

printf "%b[3/5]%b Downloading checksum...\n" "$GREEN" "$NC"
curl -fSL "https://github.com/hamza72x/DankMaterialShell/releases/download/$LATEST_VERSION/dankinstall-$ARCH.gz.sha256" -o "expected.sha256"

# Get the expected checksum
EXPECTED_CHECKSUM=$(awk '{print $1}' expected.sha256)

# Calculate actual checksum
printf "%b[4/5]%b Verifying SHA256 checksum...\n" "$GREEN" "$NC"
ACTUAL_CHECKSUM=$(sha256sum installer.gz | awk '{print $1}')

# Compare checksums
if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    printf "%bError: Checksum verification failed!%b\n" "$RED" "$NC"
    printf "  Expected: %s\n" "$EXPECTED_CHECKSUM"
    printf "  Got:      %s\n" "$ACTUAL_CHECKSUM"
    printf "%bThe downloaded file may be corrupted or tampered with.%b\n" "$YELLOW" "$NC"
    exit 1
fi

printf "       Checksum OK: %s\n" "$ACTUAL_CHECKSUM"

# Decompress the binary
printf "%b[5/5]%b Decompressing and launching installer...\n" "$GREEN" "$NC"
gunzip installer.gz
chmod +x installer

# Execute the installer
./installer
