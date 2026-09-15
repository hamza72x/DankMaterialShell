#!/usr/bin/env bash
#
# Rebuild & reinstall quickshell (hamza72x/quickshell fork) from source
# against whatever Qt is currently installed on the system.
#
# Why this exists: a routine `dnf update` bumps qt6-qtbase/qt6-qtdeclarative
# without rebuilding quickshell, and the prebuilt quickshell binary is then
# ABI-mismatched against the new Qt — it crashes (dms auto-restarts it,
# which hides the crash). You'll see this in the logs when it happens:
#
#   journalctl --user -u dms | grep "built against Qt"
#
# Re-run this script whenever that warning shows up. It mirrors the exact
# clone/configure/build/install steps dankinstall uses for quickshell
# (see core/internal/distros/manual_packages.go), but keeps the source tree
# around at ~/.local/src/quickshell so repeat runs are incremental instead
# of a full re-clone + full rebuild every time.
#
# Requires sudo (the install step writes to /usr) — run this interactively.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { printf '%b[*]%b %s\n' "$GREEN" "$NC" "$1"; }
warn() { printf '%b[!]%b %s\n' "$YELLOW" "$NC" "$1"; }
step() { printf '\n%b=== %s ===%b\n\n' "$CYAN" "$1" "$NC"; }

REPO="https://github.com/hamza72x/quickshell.git"
SRC_DIR="$HOME/.local/src/quickshell"

step "Fetching quickshell source"

if [ -d "$SRC_DIR/.git" ]; then
    info "Updating existing clone at $SRC_DIR"
    git -C "$SRC_DIR" fetch origin
else
    info "Cloning $REPO -> $SRC_DIR"
    mkdir -p "$(dirname "$SRC_DIR")"
    git clone "$REPO" "$SRC_DIR"
fi

info "Pulling latest master"
git -C "$SRC_DIR" checkout master
git -C "$SRC_DIR" pull --ff-only origin master

step "Configuring build"

cmake -GNinja -B "$SRC_DIR/build" -S "$SRC_DIR" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DINSTALL_QML_PREFIX=/usr/lib64/qt6/qml \
    -DCRASH_HANDLER=OFF \
    -DCMAKE_CXX_STANDARD=20

step "Building quickshell (this can take a while)"

cmake --build "$SRC_DIR/build"

step "Installing quickshell"

sudo cmake --install "$SRC_DIR/build"

step "Restarting DMS"

dms restart 2>/dev/null && info "DMS restarted" || warn "DMS restart failed — restart manually: dms restart"

info "Done. quickshell rebuilt against $(pkg-config --modversion Qt6Core 2>/dev/null || echo 'current Qt')."
