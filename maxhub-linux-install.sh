#!/usr/bin/env bash
#
# MAXHUB Wireless Dongle — Linux Installer v4.1.1 (Wine Portable)
#
# Downloads a portable Wine 11.2 build (~70MB) — no Docker, no system packages.
# Only touches: one udev rule, Wine in /opt, and launcher files.
#
# Usage:  sudo bash maxhub-linux-install.sh
#
set -euo pipefail

# ── Cleanup trap ──────────────────────────────────────────────────
cleanup() { tput cnorm 2>/dev/null || true; }
trap cleanup EXIT

# ── Colours / UI helpers ─────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
error() { echo -e "  ${RED}✗${NC} $*"; }
die()   { error "$*"; exit 1; }

# ── Timing ────────────────────────────────────────────────────────
SCRIPT_START_TIME=$(date +%s)
TOTAL_STEPS=5
current_step=0
step_start=0

step() {
    local label="$1" estimate="${2:-}"
    current_step=$((current_step + 1))
    step_start=$(date +%s)
    echo ""
    local est=""
    [[ -n "$estimate" ]] && est="  ${DIM}($estimate)${NC}"
    echo -e "${BOLD}${BLUE}[$current_step/$TOTAL_STEPS]${NC} ${BOLD}$label${NC}$est"
    echo -e "${DIM}$(printf '%.0s─' {1..50})${NC}"
}

step_done() {
    local elapsed=$(( $(date +%s) - step_start ))
    if [[ $elapsed -ge 60 ]]; then
        info "Done ($((elapsed/60))m $((elapsed%60))s)"
    else
        info "Done (${elapsed}s)"
    fi
}

spinner() {
    local pid=$1 msg=$2
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 spin_start
    spin_start=$(date +%s)

    tput civis 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        local elapsed=$(( $(date +%s) - spin_start ))
        echo -ne "\r  ${CYAN}${frames[$i]}${NC} ${DIM}$msg${NC} ${DIM}[${elapsed}s]${NC} "
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?

    echo -ne "\r\033[K"
    tput cnorm 2>/dev/null || true

    return $exit_code
}

# ── Constants ────────────────────────────────────────────────────
WINE_VERSION="11.2"
WINE_TARBALL="wine-${WINE_VERSION}-amd64-wow64.tar.xz"
WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/${WINE_TARBALL}"
INSTALL_DIR="/opt/maxhub-dongle"
WINE_DIR="$INSTALL_DIR/wine"
UDEV_RULE="/etc/udev/rules.d/99-maxhub-dongle.rules"
DESKTOP_FILE="/usr/share/applications/maxhub-dongle.desktop"
LAUNCHER="$INSTALL_DIR/maxhub-dongle.sh"
EXE_NAME="MAXHUB.exe"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Distro detection ─────────────────────────────────────────────
PKG_MANAGER="unknown"

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        case "${ID:-}" in
            ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian)
                PKG_MANAGER="apt-get" ;;
            fedora)
                PKG_MANAGER="dnf" ;;
            centos|rhel|rocky|alma|ol)
                command -v dnf &>/dev/null && PKG_MANAGER="dnf" || PKG_MANAGER="yum" ;;
            arch|manjaro|endeavouros|garuda)
                PKG_MANAGER="pacman" ;;
            opensuse*|sles)
                PKG_MANAGER="zypper" ;;
        esac
    fi

    # Fallback: detect by package manager
    if [[ "$PKG_MANAGER" == "unknown" ]]; then
        if command -v apt-get &>/dev/null; then
            PKG_MANAGER="apt-get"
        elif command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
        elif command -v yum &>/dev/null; then
            PKG_MANAGER="yum"
        elif command -v pacman &>/dev/null; then
            PKG_MANAGER="pacman"
        elif command -v zypper &>/dev/null; then
            PKG_MANAGER="zypper"
        fi
    fi
}

ensure_curl() {
    command -v curl &>/dev/null && return 0
    case "$PKG_MANAGER" in
        apt-get) apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq curl >/dev/null 2>&1 ;;
        dnf|yum) $PKG_MANAGER install -y -q curl >/dev/null 2>&1 ;;
        pacman)  pacman -Sy --noconfirm curl >/dev/null 2>&1 ;;
        zypper)  zypper --non-interactive install curl >/dev/null 2>&1 ;;
        *)       die "curl not found and cannot install it automatically" ;;
    esac
}

# ── Banner ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║   MAXHUB Wireless Dongle — Installer      ║"
echo "  ║   Wine Portable  v4.1.1                    ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${DIM}Portable Wine — no Docker, no system packages modified.${NC}"
echo -e "  ${DIM}Estimated time: ~30 seconds${NC}"
echo ""

# ── Pre-flight checks ───────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root.  Try:  sudo bash $0"
[[ "$(uname -m)" == "x86_64" ]] || die "This installer requires a 64-bit (x86_64) system."

REAL_USER="${SUDO_USER:-$USER}"

detect_distro
info "Detected package manager: ${PKG_MANAGER}"

# Check available disk space (need ~200MB for Wine + prefix)
AVAIL_MB=$(df -m "$INSTALL_DIR" 2>/dev/null | awk 'NR==2{print $4}' || echo 0)
# If install dir doesn't exist yet, check /opt
[[ "$AVAIL_MB" -eq 0 ]] && AVAIL_MB=$(df -m /opt 2>/dev/null | awk 'NR==2{print $4}' || echo 0)
if [[ "$AVAIL_MB" -lt 200 ]]; then
    die "Not enough disk space. Need ~200MB, have ${AVAIL_MB}MB free on $(df -h "$INSTALL_DIR" 2>/dev/null | awk 'NR==2{print $6}' || echo '/opt')"
fi
info "Disk space: ${AVAIL_MB}MB available"

# ── Step 1: Download Wine portable ──────────────────────────────
step "Downloading Wine ${WINE_VERSION}" "~10 sec"

mkdir -p "$INSTALL_DIR"

# Clean up junk from previous broken installs (e.g. git repos cloned inside /opt)
for junk in "$INSTALL_DIR"/{MAXHUB-LINUX,.git}; do
    if [[ -d "$junk" ]]; then
        warn "Removing junk directory: $junk"
        rm -rf "$junk"
    fi
done

if [[ -x "$WINE_DIR/bin/wine" ]]; then
    EXISTING_VER=$("$WINE_DIR/bin/wine" --version 2>/dev/null || echo "unknown")
    info "Wine already installed: $EXISTING_VER"
else
    ensure_curl
    TMPFILE=$(mktemp /tmp/wine-portable-XXXXXX.tar.xz)
    trap 'rm -f "$TMPFILE"; cleanup' EXIT

    echo -e "  ${DIM}Downloading ${WINE_TARBALL} (~70MB) …${NC}"
    (
        curl -fSL --progress-bar -o "$TMPFILE" "$WINE_URL" 2>&1
    ) &
    spinner $! "Downloading wine-${WINE_VERSION}-wow64 (70MB) …" || die "Download failed. Check your internet connection."

    echo -e "  ${DIM}Extracting …${NC}"
    rm -rf "$WINE_DIR"
    mkdir -p "$WINE_DIR"
    (
        tar -xf "$TMPFILE" -C "$WINE_DIR" --strip-components=1
    ) &
    spinner $! "Extracting Wine …" || die "Extraction failed."

    rm -f "$TMPFILE"
    trap cleanup EXIT

    if [[ ! -x "$WINE_DIR/bin/wine" ]]; then
        die "Wine binary not found after extraction. Something went wrong."
    fi

    WINE_VER=$("$WINE_DIR/bin/wine" --version 2>/dev/null || echo "unknown")
    info "Wine installed: $WINE_VER"
fi

# Disable crash dialog — remove winedbg everywhere it may exist
WINEDBG_FOUND=0
while IFS= read -r -d '' f; do
    rm -f "$f" && info "Removed: $f"
    WINEDBG_FOUND=$((WINEDBG_FOUND + 1))
done < <(find "$WINE_DIR" /usr/bin /usr/lib /usr/local -name "winedbg*" -print0 2>/dev/null)

if [[ $WINEDBG_FOUND -gt 0 ]]; then
    info "Removed $WINEDBG_FOUND winedbg file(s) — crash dialogs disabled"
else
    info "No winedbg found — crash dialogs already disabled"
fi

step_done

# ── Step 2: Udev rule ────────────────────────────────────────────
step "USB device permissions" "~1 sec"

cat > "$UDEV_RULE" << 'UDEV'
# MAXHUB WT13 Wireless Dongle (VID:1FF7 PID:0F52)
# Allow all users access to the hidraw and usb device
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1ff7", ATTRS{idProduct}=="0f52", MODE="0666", ENV{ID_INPUT}="1", ENV{ID_INPUT_TOUCHSCREEN}="1"
SUBSYSTEM=="usb", ATTR{idVendor}=="1ff7", ATTR{idProduct}=="0f52", MODE="0666"
UDEV
info "Rule file: $UDEV_RULE"

if command -v udevadm &>/dev/null; then
    if udevadm control --reload-rules 2>/dev/null && udevadm trigger 2>/dev/null; then
        info "Udev rules reloaded"
    else
        warn "Could not reload udev rules — will apply on next boot"
    fi
else
    warn "udevadm not found — rules will apply on next boot"
fi

step_done

# ── Step 3: Copy MAXHUB.exe ──────────────────────────────────────
step "Locating MAXHUB.exe" "~1 sec"

EXE_FOUND=""
# Check next to the install script first
if [[ -f "$SCRIPT_DIR/$EXE_NAME" ]]; then
    EXE_FOUND="$SCRIPT_DIR/$EXE_NAME"
    info "Found next to installer: $EXE_FOUND"
fi

# Search USB mount points
if [[ -z "$EXE_FOUND" ]]; then
    echo -e "  ${DIM}Searching USB drives …${NC}"
    for mount_dir in /media /mnt /run/media; do
        if [[ -d "$mount_dir" ]]; then
            FOUND=$(find "$mount_dir" -maxdepth 4 -iname "$EXE_NAME" -type f 2>/dev/null | head -1)
            if [[ -n "$FOUND" ]]; then
                EXE_FOUND="$FOUND"
                info "Found on USB: $EXE_FOUND"
                break
            fi
        fi
    done
fi

if [[ -n "$EXE_FOUND" ]]; then
    # Copy ALL files from the USB directory (exe, dlls, data files, configs)
    EXE_DIR=$(dirname "$EXE_FOUND")
    FILE_COUNT=0
    for f in "$EXE_DIR"/*; do
        [[ -f "$f" ]] || continue
        BASENAME=$(basename "$f")
        # Skip Windows autorun
        [[ "${BASENAME,,}" == "autorun.inf" ]] && continue
        cp "$f" "$INSTALL_DIR/"
        info "Copied: $BASENAME"
        FILE_COUNT=$((FILE_COUNT + 1))
    done
    info "$FILE_COUNT files copied to $INSTALL_DIR/"
elif [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    info "$EXE_NAME already in $INSTALL_DIR"
else
    warn "$EXE_NAME not found on USB drives"
    warn "Copy manually later:  sudo cp /path/to/$EXE_NAME $INSTALL_DIR/"
fi

step_done

# ── Step 4: Launcher + desktop entry ─────────────────────────────
step "Creating launcher" "~1 sec"

cat > "$LAUNCHER" << 'LAUNCHER_SCRIPT'
#!/usr/bin/env bash
# MAXHUB Wireless Dongle Launcher (Wine Portable)
set -euo pipefail

INSTALL_DIR="/opt/maxhub-dongle"
WINE="$INSTALL_DIR/wine/bin/wine"
EXE="$INSTALL_DIR/MAXHUB.exe"

export WINEPREFIX="$INSTALL_DIR/.wineprefix"
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"
export WINEDEBUG=-all

# ── Logging ────────────────────────────────────────────────────
LOG_DIR="$INSTALL_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/maxhub.log"

# Rotate: keep one previous log
[[ -f "$LOG_FILE" ]] && mv -f "$LOG_FILE" "${LOG_FILE}.old"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== MAXHUB Dongle Launcher ==="
log "Wine: $("$WINE" --version 2>/dev/null || echo 'not found')"
log "WINEPREFIX: $WINEPREFIX"
log "DISPLAY: ${DISPLAY:-unset}"
log "GPU: $(lspci 2>/dev/null | grep -i 'vga\|3d\|display' | head -2 || echo 'unknown')"

if [[ ! -f "$EXE" ]]; then
    log "ERROR: $EXE not found."
    log "Copy MAXHUB.exe to $INSTALL_DIR/ first."
    exit 1
fi

if [[ ! -x "$WINE" ]]; then
    log "ERROR: Wine not found at $WINE"
    log "Re-run the installer: sudo bash maxhub-linux-install.sh"
    exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
    log "ERROR: No display found (\$DISPLAY is empty)."
    log "This tool requires X11. Wayland without XWayland is not supported."
    log "If you use Wayland, make sure XWayland is enabled."
    exit 1
fi

# First launch: create prefix + pre-create directories the app expects
if [[ ! -d "$WINEPREFIX/drive_c" ]]; then
    log "First launch — setting up Wine (~10 seconds) …"
    mkdir -p "$WINEPREFIX"
    # Initialize Wine prefix (creates drive_c, system32, etc.)
    "$WINE" wineboot --init 2>&1 | grep -v '^libEGL warning' | tee -a "$LOG_FILE"
fi

# Ensure ScreenShare bundle dir exists with schannel.dll (needed for TLS)
WIN_USER="$WINEPREFIX/drive_c/users/$(whoami)"
BUNDLE_DIR="$WIN_USER/Application Data/ScreenShare/bundle"
if [[ ! -f "$BUNDLE_DIR/schannel.dll" ]]; then
    log "Setting up ScreenShare bundle (schannel.dll for TLS) …"
    mkdir -p "$BUNDLE_DIR"
    # Copy Wine's schannel.dll to where the app expects it
    for src in "$WINEPREFIX/drive_c/windows/system32/schannel.dll" \
               "$WINEPREFIX/drive_c/windows/syswow64/schannel.dll"; do
        if [[ -f "$src" ]]; then
            cp "$src" "$BUNDLE_DIR/schannel.dll"
            log "Copied schannel.dll from $(basename "$(dirname "$src")")"
            break
        fi
    done
fi

log "Starting: $WINE $EXE $*"
log "Log file: $LOG_FILE"

cd "$INSTALL_DIR"
"$WINE" "$EXE" "$@" 2>&1 | grep -v '^libEGL warning' | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
log "Wine exited with code: $EXIT_CODE"
exit "$EXIT_CODE"
LAUNCHER_SCRIPT
chmod +x "$LAUNCHER"
info "Launcher: $LAUNCHER"

cat > "$DESKTOP_FILE" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=MAXHUB Dongle
Comment=MAXHUB Wireless Screen Sharing Dongle
Exec=/opt/maxhub-dongle/maxhub-dongle.sh
Icon=video-display
Terminal=true
Categories=Utility;Network;
Keywords=maxhub;dongle;screen;sharing;wireless;
DESKTOP
chmod 644 "$DESKTOP_FILE"
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
info "Desktop entry: MAXHUB Dongle (in app menu)"

step_done

# ── Step 5: Finalize ─────────────────────────────────────────────
step "Finishing up" "~1 sec"

# Remove old Wine prefix so launcher rebuilds it with schannel.dll fix
WINEPREFIX_DIR="$INSTALL_DIR/.wineprefix"
if [[ -d "$WINEPREFIX_DIR/drive_c" ]]; then
    warn "Removing old Wine prefix (will rebuild on first launch) …"
    rm -rf "$WINEPREFIX_DIR"
    info "Old prefix removed — fresh setup on next launch"
fi

chown -R "$REAL_USER":"$REAL_USER" "$INSTALL_DIR"
info "Ownership set to $REAL_USER"

step_done

# ── Summary ──────────────────────────────────────────────────────
TOTAL_ELAPSED=$(( $(date +%s) - SCRIPT_START_TIME ))
if [[ $TOTAL_ELAPSED -ge 60 ]]; then
    TIME_STR="$((TOTAL_ELAPSED/60))m $((TOTAL_ELAPSED%60))s"
else
    TIME_STR="${TOTAL_ELAPSED}s"
fi

WINE_VER=$("$WINE_DIR/bin/wine" --version 2>/dev/null || echo "unknown")

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║        Installation complete!              ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Total time: ${CYAN}${TIME_STR}${NC}"
echo ""
echo -e "  ${BOLD}Installed:${NC}"
echo -e "  ${DIM}├─${NC} Wine          : ${CYAN}${WINE_VER}${NC} (portable, in $WINE_DIR)"
echo -e "  ${DIM}├─${NC} Udev rule     : ${CYAN}$UDEV_RULE${NC}"
echo -e "  ${DIM}├─${NC} Launcher      : ${CYAN}$LAUNCHER${NC}"
echo -e "  ${DIM}├─${NC} Desktop entry : ${CYAN}MAXHUB Dongle${NC}"
echo -e "  ${DIM}└─${NC} Logs          : ${CYAN}$INSTALL_DIR/logs/maxhub.log${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}Your system packages were NOT modified.${NC}"
echo -e "  ${DIM}Wine is self-contained in $WINE_DIR — no system packages installed.${NC}"
echo ""

if [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    echo -e "  ${BOLD}To launch:${NC}"
    echo -e "    Click ${CYAN}MAXHUB Dongle${NC} in app menu, or run:"
    echo -e "    ${CYAN}$LAUNCHER${NC}"
else
    echo -e "  ${YELLOW}⚠${NC} Copy ${BOLD}$EXE_NAME${NC} to $INSTALL_DIR/ before launching."
fi

echo ""
echo -e "  ${DIM}If the dongle is plugged in, unplug and replug it.${NC}"
echo ""

# ── Auto-launch ──────────────────────────────────────────────────
if [[ -f "$INSTALL_DIR/$EXE_NAME" ]] && [[ -n "${DISPLAY:-}" ]]; then
    echo -e "  ${BOLD}Launching MAXHUB …${NC}"
    echo ""
    REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    LOG_FILE="$INSTALL_DIR/logs/maxhub.log"
    mkdir -p "$INSTALL_DIR/logs"
    chown "$REAL_USER":"$REAL_USER" "$INSTALL_DIR/logs"
    nohup sudo -u "$REAL_USER" env \
        DISPLAY="$DISPLAY" \
        XAUTHORITY="${XAUTHORITY:-$REAL_HOME/.Xauthority}" \
        "$LAUNCHER" >>"$LOG_FILE" 2>&1 &
    disown
    echo -e "  ${DIM}Logs: tail -f $LOG_FILE${NC}"
fi
