#!/usr/bin/env bash

set -euo pipefail

# ============================================================
#  Screen share stack — XDPH + modernized hyprland-share-picker
#
#  Lives in hamza72x/screen-share/. Idempotent / upsert: safe to
#  re-run. Overlays our picker + QT scale patch onto an XDPH tree.
#
#  Usage:
#    bash hamza72x/screen-share/build.sh
#
#  Optional env:
#    XDPH_SRC=...       # source tree (default: ~/personal/xdg-desktop-portal-hyprland)
#    XDPH_TAG=v1.4.1    # only used when cloning a missing tree
#    XDPH_CLEAN_BUILD=1 # wipe build/ before configure (default: reuse cache)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICKER_SRC="$SCRIPT_DIR/hyprland-share-picker"
PATCH_QT_SCALE="$SCRIPT_DIR/patches/screencopy-qt-scale.patch"

REPO_URL="https://github.com/hyprwm/xdg-desktop-portal-hyprland.git"
SRC_DIR="${XDPH_SRC:-$HOME/personal/xdg-desktop-portal-hyprland}"
JOBS="$(nproc 2>/dev/null || echo 4)"

DEPS=(
    git cmake gcc-c++ ninja-build
    wayland-devel wayland-protocols-devel
    pipewire-devel libdrm-devel mesa-libgbm-devel
    libuuid-devel
    sdbus-cpp-devel
    # NOTE: do NOT install Fedora hyprland-protocols-devel — it is too old
    # for XDPH 1.4+ (missing toplevel-mapping / input-capture). We use the
    # hyprland-protocols git submodule instead.
    qt6-qtbase-devel
    xdg-desktop-portal xdg-desktop-portal-gtk
)

# Virtual / alias provides that map to differently named RPMs
declare -A DEP_PROVIDES=(
    [pkg-config]=pkgconf-pkg-config
)

info() { printf "%b[*]%b %s\n" "$GREEN" "$NC" "$1"; }
warn() { printf "%b[!]%b %s\n" "$YELLOW" "$NC" "$1"; }
fail() {
    printf "%b[x]%b %s\n" "$RED" "$NC" "$1"
    exit 1
}
step() { printf "\n%b=== %s ===%b\n\n" "$CYAN" "$1" "$NC"; }

pkg_installed() {
    # Accept either the exact RPM name or a known provides alias.
    local name="$1"
    rpm -q "$name" &>/dev/null && return 0
    if [ -n "${DEP_PROVIDES[$name]:-}" ]; then
        rpm -q "${DEP_PROVIDES[$name]}" &>/dev/null && return 0
    fi
    # Also treat "command exists" as satisfied for CLI tools.
    case "$name" in
    git | cmake | ninja-build | pkg-config)
        local cmd="${name%-build}"
        [ "$name" = "ninja-build" ] && cmd="ninja"
        [ "$name" = "pkg-config" ] && cmd="pkg-config"
        command -v "$cmd" &>/dev/null && return 0
        ;;
    esac
    return 1
}

if [ "$(id -u)" == "0" ]; then
    fail "Do not run as root. The script will use sudo when needed."
fi

command -v dnf &>/dev/null || fail "This script expects Fedora (dnf)."

printf "\n"
printf "%b╔══════════════════════════════════════════════════════════╗%b\n" "$CYAN" "$NC"
printf "%b║  screen-share — XDPH + modernized picker (upsert)        ║%b\n" "$CYAN" "$NC"
printf "%b║  Safe to re-run                                          ║%b\n" "$CYAN" "$NC"
printf "%b╚══════════════════════════════════════════════════════════╝%b\n" "$CYAN" "$NC"
printf "\n"

[ -d "$PICKER_SRC" ] || fail "Missing picker sources at $PICKER_SRC"
[ -f "$PICKER_SRC/main.cpp" ] || fail "Missing $PICKER_SRC/main.cpp"

# -----------------------------------------------------------
# Preflight
# -----------------------------------------------------------

step "Checking Hyprland ecosystem libraries"

missing=()
for mod in hyprlang hyprutils hyprwayland-scanner; do
    if pkg-config --exists "$mod" 2>/dev/null; then
        info "$mod $(pkg-config --modversion "$mod")"
    else
        missing+=("$mod")
    fi
done
[ "${#missing[@]}" -eq 0 ] || fail "Missing: ${missing[*]}. Install Hyprland first."
command -v hyprwayland-scanner &>/dev/null || fail "hyprwayland-scanner not in PATH."

# -----------------------------------------------------------
# Build dependencies (install only what's missing)
# -----------------------------------------------------------

step "Ensuring build dependencies"

need_pkgs=()
for pkg in "${DEPS[@]}"; do
    # gcc-c++ RPM name is gcc-c++; rpm -q accepts it
    if pkg_installed "$pkg"; then
        :
    else
        need_pkgs+=("$pkg")
    fi
done

if [ "${#need_pkgs[@]}" -eq 0 ]; then
    info "All dependency packages already installed."
else
    info "Installing missing packages: ${need_pkgs[*]}"
    # Disable cursor repo — its GPG prompt can hang noninteractive runs.
    sudo dnf install -y --disablerepo='cursor*' "${need_pkgs[@]}"
fi

# Fedora's hyprland-protocols package lacks protocols required by XDPH 1.4+.
# If it is present, CMake prefers it over the submodule and the build fails
# with "Couldn't load proto". Remove it so the submodule is used instead.
FORCE_CMAKE_RECONFIG=0
if pkg-config --exists hyprland-protocols 2>/dev/null; then
    proto_datadir="$(pkg-config --variable=pkgdatadir hyprland-protocols 2>/dev/null | sed 's|^//|/|')"
    if [ ! -f "${proto_datadir}/protocols/hyprland-toplevel-mapping-v1.xml" ]; then
        warn "System hyprland-protocols at ${proto_datadir} is too old — removing RPM so submodule is used"
        sudo dnf remove -y --disablerepo='cursor*' hyprland-protocols-devel hyprland-protocols 2>/dev/null || true
        FORCE_CMAKE_RECONFIG=1
    fi
fi

# -----------------------------------------------------------
# Source tree (never reset / never delete)
# -----------------------------------------------------------

step "Preparing source at $SRC_DIR"

mkdir -p "$(dirname "$SRC_DIR")"

if [ -d "$SRC_DIR/.git" ]; then
    info "Existing clone found — leaving checkout as-is (no reset/pull)."
    if [ -f "$SRC_DIR/.gitmodules" ]; then
        git -C "$SRC_DIR" submodule update --init --recursive
    fi
elif [ -e "$SRC_DIR" ]; then
    fail "$SRC_DIR exists but is not a git repo. Move/rename it, or set XDPH_SRC."
else
    if [ -z "${XDPH_TAG:-}" ]; then
        XDPH_TAG="$(git ls-remote --tags --refs "$REPO_URL" 'v*' \
            | awk -F/ '{print $NF}' \
            | sort -V \
            | tail -1)"
        [ -n "$XDPH_TAG" ] || fail "Could not resolve latest tag from $REPO_URL"
    fi
    info "Cloning $REPO_URL @ $XDPH_TAG (first run only)"
    git clone --recursive --branch "$XDPH_TAG" "$REPO_URL" "$SRC_DIR"
fi

cd "$SRC_DIR"
info "Source: $SRC_DIR ($(git describe --tags --always 2>/dev/null || echo unknown))"

# Submodule must provide protocols Fedora's RPM lacks.
SUB_PROTO="$SRC_DIR/subprojects/hyprland-protocols/protocols"
for need in hyprland-toplevel-mapping-v1.xml hyprland-input-capture-v1.xml; do
    [ -f "$SUB_PROTO/$need" ] || fail "Missing $SUB_PROTO/$need — run: git -C $SRC_DIR submodule update --init --recursive"
done
info "Bundled hyprland-protocols OK ($(ls "$SUB_PROTO"/*.xml | wc -l) xml files)"

# -----------------------------------------------------------
# Overlay hamza72x/screen-share picker + portal patches
# -----------------------------------------------------------

step "Applying screen-share overlays"

info "Overlaying picker from $PICKER_SRC"
rm -rf "$SRC_DIR/hyprland-share-picker"
mkdir -p "$SRC_DIR/hyprland-share-picker"
# Copy contents (not the directory node) so CMakeLists stays at the right path.
cp -a "$PICKER_SRC"/. "$SRC_DIR/hyprland-share-picker/"

if [ -f "$PATCH_QT_SCALE" ]; then
    if grep -q 'QT_SCALE_FACTOR' "$SRC_DIR/src/shared/ScreencopyShared.cpp" 2>/dev/null; then
        info "ScreencopyShared already has QT scale overrides"
    else
        info "Applying $(basename "$PATCH_QT_SCALE")"
        if ! git -C "$SRC_DIR" apply --whitespace=nowarn "$PATCH_QT_SCALE" 2>/tmp/xdph-patch.err; then
            # Fallback: patch(1) if git apply fails on dirty trees
            if ! patch -d "$SRC_DIR" -p1 --forward --reject-file=- <"$PATCH_QT_SCALE" >/tmp/xdph-patch.out 2>/tmp/xdph-patch.err; then
                warn "Could not apply QT scale patch (may already be present):"
                cat /tmp/xdph-patch.err 2>/dev/null || true
            else
                info "QT scale patch applied via patch(1)"
            fi
        else
            info "QT scale patch applied"
        fi
    fi
fi

# -----------------------------------------------------------
# Build (reuse CMake cache unless XDPH_CLEAN_BUILD=1)
# -----------------------------------------------------------

step "Configuring (CMake)"

# Fedora portal backends live in /usr/libexec (not Arch's /usr/lib).
CMAKE_FLAGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/usr
    -DCMAKE_INSTALL_LIBEXECDIR=libexec
    -DSYSTEMD_SERVICES=ON
)

if [ "${XDPH_CLEAN_BUILD:-0}" = "1" ] || [ "${FORCE_CMAKE_RECONFIG:-0}" = "1" ]; then
    if [ "${FORCE_CMAKE_RECONFIG:-0}" = "1" ]; then
        warn "Clearing CMake cache so it picks bundled hyprland-protocols"
    else
        warn "XDPH_CLEAN_BUILD=1 — removing build/"
    fi
    # Keep object files when only switching proto source; wipe cache dirs.
    if [ "${XDPH_CLEAN_BUILD:-0}" = "1" ]; then
        rm -rf build
    else
        rm -rf build/CMakeCache.txt build/CMakeFiles
    fi
fi

configure_build() {
    # Reuse whatever generator already configured this build dir (Makefiles
    # vs Ninja). Only pick Ninja on a fresh build/ to avoid generator mismatch.
    if [ -f build/CMakeCache.txt ]; then
        cmake -S . -B build "${CMAKE_FLAGS[@]}"
    else
        cmake -S . -B build -G Ninja "${CMAKE_FLAGS[@]}"
    fi
}

if ! configure_build 2>&1 | tee /tmp/xdph-cmake.log; then
    if grep -q 'Does not match the generator used previously' /tmp/xdph-cmake.log; then
        warn "CMake generator mismatch in build/ — clearing cache and retrying"
        rm -rf build/CMakeCache.txt build/CMakeFiles
        if command -v ninja &>/dev/null; then
            cmake -S . -B build -G Ninja "${CMAKE_FLAGS[@]}"
        else
            cmake -S . -B build "${CMAKE_FLAGS[@]}"
        fi
    else
        fail "CMake configure failed"
    fi
fi
rm -f /tmp/xdph-cmake.log

step "Building"
cmake --build build -j"$JOBS"

# -----------------------------------------------------------
# Install (overwrite binaries only — upsert)
# -----------------------------------------------------------

step "Installing"

before_bin=""
after_bin=""
if [ -x /usr/libexec/xdg-desktop-portal-hyprland ]; then
    before_bin="$(stat -c '%Y %s' /usr/libexec/xdg-desktop-portal-hyprland 2>/dev/null || true)"
fi

if sudo -n true 2>/dev/null; then
    if sudo -n cmake --install build; then
        info "Installed system-wide via cmake --install"
    else
        warn "cmake --install failed; continuing with user-local picker"
    fi
else
    warn "sudo not available non-interactively — skipping system install; using user-local picker"
fi

# Always publish the modernized picker to ~/.local/bin and point XDPH at it.
# This is the UI users actually see; upsert-safe and does not need sudo.
PICKER_BIN="$SRC_DIR/build/hyprland-share-picker/hyprland-share-picker"
PICKER_DST="$HOME/.local/bin/hyprland-share-picker"
if [ -x "$PICKER_BIN" ]; then
    mkdir -p "$(dirname "$PICKER_DST")"
    cp -f "$PICKER_BIN" "$PICKER_DST"
    chmod +x "$PICKER_DST"
    info "Picker → $PICKER_DST"
else
    fail "Built picker not found at $PICKER_BIN"
fi

if [ -x /usr/libexec/xdg-desktop-portal-hyprland ]; then
    after_bin="$(stat -c '%Y %s' /usr/libexec/xdg-desktop-portal-hyprland 2>/dev/null || true)"
fi

info "Installed/updated xdg-desktop-portal-hyprland + hyprland-share-picker"

# -----------------------------------------------------------
# xdph.conf — create or ensure key; never overwrite whole file
# -----------------------------------------------------------

step "Ensuring ~/.config/hypr/xdph.conf"

XDPH_CONF="$HOME/.config/hypr/xdph.conf"
mkdir -p "$(dirname "$XDPH_CONF")"

ensure_xdph_conf() {
    local need_token=1 need_picker=1
    if [ -f "$XDPH_CONF" ]; then
        grep -Eq '^\s*allow_token_by_default\s*=' "$XDPH_CONF" && need_token=0
        grep -Eq '^\s*custom_picker_binary\s*=' "$XDPH_CONF" && need_picker=0
    fi

    if [ ! -f "$XDPH_CONF" ]; then
        cat >"$XDPH_CONF" <<EOF
# xdg-desktop-portal-hyprland config
# https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/

screencopy {
    # Slack/Electron open several ScreenCast sessions per share (preview +
    # stream). Pre-check "Allow restore token" so later sessions reuse the
    # first pick instead of spawning the picker again.
    allow_token_by_default = true
    custom_picker_binary = $HOME/.local/bin/hyprland-share-picker
}
EOF
        info "Created $XDPH_CONF"
        return
    fi

    if [ "$need_token" -eq 0 ] && [ "$need_picker" -eq 0 ]; then
        # Keep custom_picker_binary pointed at our upserted binary.
        sed -i "s|^[[:space:]]*custom_picker_binary[[:space:]]*=.*|    custom_picker_binary = $HOME/.local/bin/hyprland-share-picker|" "$XDPH_CONF"
        info "$XDPH_CONF already configured — picker path refreshed"
        return
    fi

    {
        echo ""
        echo "# Added by hamza72x/screen-share/build.sh (upsert)"
        echo "screencopy {"
        [ "$need_token" -eq 1 ] && echo "    allow_token_by_default = true"
        [ "$need_picker" -eq 1 ] && echo "    custom_picker_binary = $HOME/.local/bin/hyprland-share-picker"
        echo "}"
    } >>"$XDPH_CONF"
    info "Updated $XDPH_CONF (appended missing screencopy settings)"
}

ensure_xdph_conf

# -----------------------------------------------------------
# Restart portals only when the binary changed (or first install)
# -----------------------------------------------------------

step "Portal services"

if [ "$before_bin" != "$after_bin" ] || [ -z "$before_bin" ]; then
    info "Binary changed — restarting portal services"
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal-gtk.service 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal-hyprland.service 2>/dev/null || true
    sleep 1
else
    info "Binary unchanged — skipping portal restart"
fi

if gdbus introspect --session \
    --dest org.freedesktop.portal.Desktop \
    --object-path /org/freedesktop/portal/desktop 2>/dev/null \
    | grep -q 'org.freedesktop.portal.ScreenCast'; then
    info "ScreenCast portal is available."
else
    warn "ScreenCast not visible yet — log out/in if sharing still fails."
fi

printf "\n"
printf "%bDone (upsert).%b Re-run anytime; source tree and xdph.conf are preserved.\n" "$GREEN" "$NC"
printf "\n"
