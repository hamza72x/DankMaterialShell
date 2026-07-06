#!/usr/bin/env bash

set -euo pipefail

# ============================================================
#  DankMaterialShell Installer — hamza72x fork (private repo)
#  SSH clone + local build method
#
#  Usage on a barebone Fedora:
#    1. Set up SSH key: ssh-keygen -t ed25519 && cat ~/.ssh/id_ed25519.pub
#    2. Add the key to your GitHub account (Settings > SSH Keys)
#    3. Run this script: bash install.sh
#
#  Prerequisites (auto-installed by this script):
#    - git, make, go (1.22+), gcc, cargo, cmake, ninja-build
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

REPO="git@github.com:hamza72x/DankMaterialShell.git"
CLONE_DIR="$HOME/.local/src/DankMaterialShell"

# -----------------------------------------------------------
# Helpers
# -----------------------------------------------------------

info()  { printf "%b[*]%b %s\n" "$GREEN" "$NC" "$1"; }
warn()  { printf "%b[!]%b %s\n" "$YELLOW" "$NC" "$1"; }
fail()  { printf "%b[x]%b %s\n" "$RED" "$NC" "$1"; exit 1; }
step()  { printf "\n%b=== %s ===%b\n\n" "$CYAN" "$1" "$NC"; }

# -----------------------------------------------------------
# Preflight checks
# -----------------------------------------------------------

if [ "$(id -u)" == "0" ]; then
    fail "Do not run as root. The script will use sudo when needed."
fi

if [ "$(uname)" != "Linux" ]; then
    fail "This installer only supports Linux."
fi

# -----------------------------------------------------------
# Banner
# -----------------------------------------------------------

printf "\n"
printf "%b╔══════════════════════════════════════════════════════════╗%b\n" "$CYAN" "$NC"
printf "%b║  DankMaterialShell — hamza72x fork (private)            ║%b\n" "$CYAN" "$NC"
printf "%b║  Supply-chain hardened • All deps built from source     ║%b\n" "$CYAN" "$NC"
printf "%b║  SSH clone + local build                                ║%b\n" "$CYAN" "$NC"
printf "%b╚══════════════════════════════════════════════════════════╝%b\n" "$CYAN" "$NC"
printf "\n"

# -----------------------------------------------------------
# Step 1: Detect if repo is already present (scp/rsync deploy)
# -----------------------------------------------------------

step "Checking repository"

# Determine where the repo is — either we're inside it already, or we need to clone
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$REPO_DIR/core/Makefile" ] && [ -f "$REPO_DIR/quickshell/shell.qml" ]; then
    # We're running from inside an already-deployed repo (scp/rsync)
    CLONE_DIR="$REPO_DIR"
    info "Repo already present at $CLONE_DIR (deployed via scp/rsync)."
    info "Skipping GitHub SSH check and clone."
else
    # Need to clone from GitHub
    step "Verifying GitHub SSH access"

    if ! ssh -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -qi "successfully authenticated"; then
        warn "SSH authentication to GitHub failed."
        printf "\n"
        printf "  To fix this on a new Fedora install:\n"
        printf "    1. %bssh-keygen -t ed25519%b (press Enter for defaults)\n" "$BOLD" "$NC"
        printf "    2. %bcat ~/.ssh/id_ed25519.pub%b\n" "$BOLD" "$NC"
        printf "    3. Add that key at: https://github.com/settings/ssh/new\n"
        printf "    4. Re-run this script\n"
        printf "\n"
        fail "Cannot continue without SSH access to github.com"
    fi

    info "GitHub SSH access confirmed."

    CLONE_DIR="$HOME/.local/src/DankMaterialShell"

    if [ -d "$CLONE_DIR/.git" ]; then
        info "Repo already cloned at $CLONE_DIR — skipping clone."
    else
        info "Cloning $REPO → $CLONE_DIR"
        mkdir -p "$(dirname "$CLONE_DIR")"
        git clone "$REPO" "$CLONE_DIR"
    fi
fi

cd "$CLONE_DIR"
info "Repo: $CLONE_DIR"

# -----------------------------------------------------------
# Step 2: Install build dependencies (Fedora)
# -----------------------------------------------------------

step "Installing build dependencies"

# Detect package manager
if command -v dnf &>/dev/null; then
    PM="dnf"
elif command -v pacman &>/dev/null; then
    PM="pacman"
elif command -v apt-get &>/dev/null; then
    PM="apt"
else
    fail "Unsupported package manager. This script supports dnf, pacman, and apt."
fi

info "Detected package manager: $PM"

case "$PM" in
dnf)
    # Core build tools (split into smaller groups for better error handling)
    info "Installing core build tools via dnf..."
    sudo dnf install -y git make gcc gcc-c++ tar rsync curl gzip coreutils meson rpm-build

    info "Installing Go..."
    sudo dnf install -y golang

    info "Installing Rust/Cargo..."
    sudo dnf install -y cargo rust

    info "Installing CMake/Ninja..."
    sudo dnf install -y cmake ninja-build pkg-config

    info "Installing runtime services and drivers..."
    sudo dnf install -y \
        pipewire pipewire-pulseaudio wireplumber \
        upower power-profiles-daemon \
        fontconfig mesa-dri-drivers

    info "Installing Hyprland build dependencies..."
    sudo dnf install -y --skip-unavailable \
        wayland-devel wayland-protocols-devel libxkbcommon-devel \
        cairo-devel pango-devel pixman-devel libdrm-devel \
        mesa-libgbm-devel mesa-libEGL-devel mesa-libGLES-devel \
        libinput-devel glib2-devel re2-devel muParser-devel lcms2-devel \
        libXcursor-devel libuuid-devel xcb-util-errors-devel libxcb-devel \
        xcb-util-renderutil-devel xcb-util-wm-devel xcb-util-devel \
        xcb-util-keysyms-devel glslang-devel spirv-tools-devel \
        vulkan-headers OpenEXR-devel libwebp-devel libjpeg-turbo-devel \
        libpng-devel file-devel hwdata-devel libseat-devel \
        libdisplay-info-devel librsvg2-devel tomlplusplus-devel \
        pugixml-devel libzip-devel readline-devel python3 libffi-devel \
        iniparser-devel abseil-cpp-devel

    info "Installing Hyprland runtime dependencies..."
    sudo dnf install -y --skip-unavailable \
        libwayland-client libwayland-server libwayland-cursor \
        libxkbcommon mesa-libEGL mesa-libGLES mesa-libgbm libdrm libseat \
        libdisplay-info cairo pango pixman glslang vulkan-loader libXcursor \
        libinput xorg-x11-server-Xwayland \
        glib2 re2 muParser lcms2 libuuid libffi hwdata file-libs polkit \
        libxcb xcb-util-errors xcb-util-renderutil xcb-util-wm \
        librsvg2 tomlplusplus pugixml libzip libwebp libjpeg-turbo libpng

    info "Installing Qt6 and Quickshell dev packages..."
    sudo dnf install -y \
        qt6-qtbase-devel qt6-qtbase-private-devel \
        qt6-qtdeclarative-devel \
        qt6-qtshadertools-devel \
        qt6-qtwayland-devel \
        qt6-qtmultimedia-devel \
        qt6-qtsvg-devel \
        pipewire-devel pam-devel polkit-devel \
        jemalloc-devel cli11-devel

    info "Enabling runtime services..."
    sudo systemctl enable upower power-profiles-daemon
    ;;
pacman)
    BUILD_PKGS=(
        git make gcc cmake ninja pkg-config
        go
        rust cargo
        qt6-base qt6-declarative qt6-shadertools qt6-wayland qt6-multimedia
        wayland wayland-protocols libdrm
        pipewire pam polkit
        libinput libxkbcommon
        jemalloc cli11
        curl gzip coreutils
    )
    info "Installing packages via pacman (may prompt for sudo)..."
    sudo pacman -S --needed --noconfirm "${BUILD_PKGS[@]}" 2>/dev/null || {
        warn "Some packages may not be available. Continuing..."
    }
    ;;
apt)
    BUILD_PKGS=(
        git make gcc g++ cmake ninja-build pkg-config
        golang
        cargo rustc
        qt6-base-dev qt6-declarative-dev qt6-shader-baker
        libwayland-dev wayland-protocols libdrm-dev
        libpipewire-0.3-dev libpam0g-dev libpolkit-agent-1-dev
        libinput-dev libxkbcommon-dev
        libegl-dev libgles-dev
        libjemalloc-dev
        curl gzip coreutils
    )
    info "Installing packages via apt (may prompt for sudo)..."
    sudo apt-get update -qq
    sudo apt-get install -y "${BUILD_PKGS[@]}" 2>/dev/null || {
        warn "Some packages may not be available. Continuing..."
    }
    ;;
esac

# Verify critical tools
for tool in git make go cargo cmake; do
    if ! command -v "$tool" &>/dev/null; then
        fail "'$tool' is not available after package install. Install it manually and retry."
    fi
done

info "Build dependencies ready."
info "Go version: $(go version)"
info "Cargo version: $(cargo --version)"

# -----------------------------------------------------------
# Step 3: Build dms CLI
# -----------------------------------------------------------

step "Building dms CLI"

cd "$CLONE_DIR/core"
make clean 2>/dev/null || true
make build

info "Built: core/bin/dms"

# -----------------------------------------------------------
# Step 4: Build dankinstall (the TUI installer)
# -----------------------------------------------------------

step "Building dankinstall"

make dankinstall

info "Built: core/bin/dankinstall"

# -----------------------------------------------------------
# Step 5: Pre-deploy DMS QML files (skip clone in dankinstall)
# -----------------------------------------------------------

step "Pre-deploying DMS shell files"

# dankinstall tries to git clone the (private) DMS repo into ~/.config/quickshell/dms.
# Since the repo is already on disk (synced via rsync/scp), symlink it instead.
DMS_QML_DIR="$HOME/.config/quickshell/dms"
mkdir -p "$(dirname "$DMS_QML_DIR")"
if [ -L "$DMS_QML_DIR" ] || [ -d "$DMS_QML_DIR" ]; then
    rm -rf "$DMS_QML_DIR"
fi
ln -sfn "$CLONE_DIR/quickshell" "$DMS_QML_DIR"
info "Symlinked $DMS_QML_DIR → $CLONE_DIR/quickshell"

# -----------------------------------------------------------
# Step 5b: Pre-extract Lua 5.5 source (www.lua.org unreachable)
# -----------------------------------------------------------

# build-hyprland.sh downloads Lua from www.lua.org which may be unreachable.
# We bundle the source tarball and pre-extract it to skip the download.
LUA_BUILD_DIR="$HOME/hypr-deps"
if [ ! -d "$LUA_BUILD_DIR/lua-5.5.0" ]; then
    info "Pre-extracting bundled Lua 5.5.0 source..."
    mkdir -p "$LUA_BUILD_DIR"
    tar xzf "$CLONE_DIR/hamza72x/vendor/lua-5.5.0.tar.gz" -C "$LUA_BUILD_DIR"
    info "Lua 5.5.0 source ready at $LUA_BUILD_DIR/lua-5.5.0"
else
    info "Lua 5.5.0 source already present at $LUA_BUILD_DIR/lua-5.5.0"
fi

# -----------------------------------------------------------
# Step 6: Run dankinstall
# -----------------------------------------------------------

step "Running dankinstall (interactive TUI)"

printf "\n"
info "dankinstall will now guide you through compositor/terminal selection"
info "and install all remaining dependencies from hamza72x forks.\n"
printf "\n"

./bin/dankinstall

# -----------------------------------------------------------
# Step 7: Install dms binary system-wide
# -----------------------------------------------------------

step "Installing dms binary"

sudo make install
info "Installed dms to /usr/local/bin/dms"

# -----------------------------------------------------------
# Step 8: Install shell files + systemd service
# -----------------------------------------------------------

step "Installing shell files"

cd "$CLONE_DIR"
sudo make install

# -----------------------------------------------------------
# Done
# -----------------------------------------------------------

printf "\n"
printf "%b╔══════════════════════════════════════════════════════════╗%b\n" "$GREEN" "$NC"
printf "%b║  Installation complete!                                  ║%b\n" "$GREEN" "$NC"
printf "%b║                                                          ║%b\n" "$GREEN" "$NC"
printf "%b║  Start DMS:   systemctl --user enable --now dms          ║%b\n" "$GREEN" "$NC"
printf "%b║  Or manually:  dms run                                   ║%b\n" "$GREEN" "$NC"
printf "%b║                                                          ║%b\n" "$GREEN" "$NC"
printf "%b║  Source:  %s%b\n" "$GREEN" "$CLONE_DIR" "$NC"
printf "%b║  Updates: disabled (supply-chain hardened fork)          ║%b\n" "$GREEN" "$NC"
printf "%b╚══════════════════════════════════════════════════════════╝%b\n" "$GREEN" "$NC"
printf "\n"
