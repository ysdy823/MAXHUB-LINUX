#!/usr/bin/env bash
#
# MAXHUB Wireless Dongle — Linux Installer
# Installs Wine 11.x+ (WineHQ PPA), udev rules, and a desktop launcher
# for the MAXHUB WT13 dongle (VID:1FF7 PID:0F52).
#
# Usage:  sudo bash maxhub-linux-install.sh
#
set -euo pipefail

# ── Colours / helpers ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
die()   { error "$*"; exit 1; }

# ── Constants ────────────────────────────────────────────────────────
INSTALL_DIR="/opt/maxhub-dongle"
UDEV_RULE="/etc/udev/rules.d/99-maxhub-dongle.rules"
DESKTOP_FILE="/usr/share/applications/maxhub-dongle.desktop"
LAUNCHER="$INSTALL_DIR/maxhub-dongle.sh"
WINEPREFIX_DIR="$INSTALL_DIR/wineprefix"
EXE_NAME="MAXHUB.exe"

# ── Pre-flight checks ───────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root.  Try:  sudo bash $0"

ARCH=$(dpkg --print-architecture 2>/dev/null || true)
[[ "$ARCH" == "amd64" ]] || die "Only amd64 is supported (detected: ${ARCH:-unknown})."

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${VERSION_CODENAME:-}" in
        jammy|noble) info "Detected Ubuntu $VERSION_ID ($VERSION_CODENAME)" ;;
        *) warn "Untested distro/version ($PRETTY_NAME). Proceeding anyway …" ;;
    esac
else
    warn "Cannot detect distribution. Proceeding anyway …"
fi

# ── 1. Add WineHQ repository ────────────────────────────────────────
info "Adding WineHQ repository …"

# Enable 32-bit architecture (required by Wine)
dpkg --add-architecture i386

# Install prerequisites (suppress warnings from unrelated third-party repos)
apt-get update -qq 2>&1 | grep -v "^W:" >&2 || true
apt-get install -y -qq wget gnupg2 software-properties-common >/dev/null

# Add WineHQ GPG key
KEYRING="/etc/apt/keyrings/winehq-archive.key"
mkdir -p /etc/apt/keyrings
if [[ ! -f "$KEYRING" ]]; then
    wget -qO "$KEYRING" https://dl.winehq.org/wine-builds/winehq.key
    info "WineHQ GPG key installed."
else
    info "WineHQ GPG key already present."
fi

# Determine the correct sources file
CODENAME="${VERSION_CODENAME:-noble}"
SOURCES_FILE="/etc/apt/sources.list.d/winehq-${CODENAME}.sources"
if [[ ! -f "$SOURCES_FILE" ]]; then
    wget -qNP /etc/apt/sources.list.d/ \
        "https://dl.winehq.org/wine-builds/ubuntu/dists/${CODENAME}/winehq-${CODENAME}.sources"
    info "WineHQ apt source added for ${CODENAME}."
else
    info "WineHQ apt source already present."
fi

# ── 2. Check existing Wine & install WineHQ ──────────────────────────

# If winehq-devel is already installed at 11+, skip entirely
EXISTING_VER=$(wine --version 2>/dev/null || true)
EXISTING_MAJOR=$(echo "$EXISTING_VER" | grep -oP 'wine-\K[0-9]+' || echo "0")

if [[ "$EXISTING_MAJOR" -ge 11 ]]; then
    info "Wine $EXISTING_VER already installed — skipping."
else
    info "Installing Wine (winehq-devel) — this may take a while …"
    apt-get update -qq 2>&1 | grep -v "^W:" >&2 || true

    # Try to install — if it works, great. If not, diagnose and guide the user.
    if apt-get install -y --install-recommends winehq-devel 2>&1 | grep -v "^W:"; then
        info "Wine installed successfully."
    else
        # ── Diagnose the failure and tell the user what to do ────────
        echo ""
        error "Wine installation failed. Diagnosing the problem …"
        echo ""

        # Check for held packages
        HELD=$(apt-mark showhold 2>/dev/null | grep -iE "wine|libwine" || true)
        if [[ -n "$HELD" ]]; then
            error "Found held packages that block installation:"
            error "  $HELD"
            echo ""
            error "To fix, run:"
            error "  sudo apt-mark unhold $HELD"
            error "Then re-run this installer."
            exit 1
        fi

        # Check for conflicting Wine packages from Ubuntu/other repos
        CONFLICTS=$(dpkg -l 2>/dev/null | grep -E "^ii" | awk '{print $2}' | \
            grep -iE "^(wine|wine32|wine64|wine-stable|wine[0-9])" | \
            grep -iv "winehq\|wine-devel\|wine-staging" || true)
        if [[ -n "$CONFLICTS" ]]; then
            error "Found Wine packages from other sources that conflict with WineHQ:"
            for pkg in $CONFLICTS; do
                error "  - $pkg"
            done
            echo ""
            error "To fix, you can remove them (this will NOT delete your Wine settings/data):"
            error "  sudo apt remove $CONFLICTS"
            error "Then re-run this installer."
            echo ""
            error "If you use these packages for other programs, you may need to"
            error "choose between the existing Wine and WineHQ 11+."
            exit 1
        fi

        # Check for broken dpkg state
        if ! dpkg --configure -a 2>/dev/null; then
            error "dpkg is in a broken state."
            error "To fix, run:"
            error "  sudo dpkg --configure -a"
            error "  sudo apt --fix-broken install"
            error "Then re-run this installer."
            exit 1
        fi

        # Generic fallback
        error "Could not determine the cause. Please run this command manually"
        error "to see the full error:"
        error "  sudo apt install --install-recommends winehq-devel"
        exit 1
    fi
fi

WINE_VER=$(wine --version 2>/dev/null || true)
info "Wine installed: ${WINE_VER:-unknown version}"

# Verify Wine version is 11+
WINE_MAJOR=$(echo "$WINE_VER" | grep -oP 'wine-\K[0-9]+' || echo "0")
if [[ "$WINE_MAJOR" -lt 11 ]]; then
    warn "Wine version $WINE_VER detected — version 11+ is required for HID support."
    warn "The dongle may not work with this version."
fi

# ── 3. Install udev rule ────────────────────────────────────────────
info "Installing udev rule for MAXHUB dongle …"
cat > "$UDEV_RULE" << 'UDEV'
# MAXHUB WT13 Wireless Dongle (VID:1FF7 PID:0F52)
# Allow all users access to the hidraw and usb device
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1ff7", ATTRS{idProduct}=="0f52", MODE="0666", ENV{ID_INPUT}="1", ENV{ID_INPUT_TOUCHSCREEN}="1"
SUBSYSTEM=="usb", ATTR{idVendor}=="1ff7", ATTR{idProduct}=="0f52", MODE="0666"
UDEV

if udevadm control --reload-rules 2>/dev/null && udevadm trigger 2>/dev/null; then
    info "Udev rules installed and reloaded."
else
    warn "Could not reload udev rules (no udev daemon?). Rules will apply on next boot."
fi

# ── 4. Prepare install directory ─────────────────────────────────────
mkdir -p "$INSTALL_DIR"

# ── 5. Copy MAXHUB.exe from USB (if found) ──────────────────────────
EXE_FOUND=""
# Search common mount points for the exe
for mount_dir in /media /mnt /run/media; do
    if [[ -d "$mount_dir" ]]; then
        FOUND=$(find "$mount_dir" -maxdepth 4 -iname "$EXE_NAME" -type f 2>/dev/null | head -1)
        if [[ -n "$FOUND" ]]; then
            EXE_FOUND="$FOUND"
            break
        fi
    fi
done

if [[ -n "$EXE_FOUND" ]]; then
    info "Found $EXE_NAME at: $EXE_FOUND"
    cp -v "$EXE_FOUND" "$INSTALL_DIR/$EXE_NAME"

    # Also copy any DLLs that sit alongside the exe
    EXE_DIR=$(dirname "$EXE_FOUND")
    shopt -s nullglob
    for dll in "$EXE_DIR"/*.dll "$EXE_DIR"/*.DLL; do
        cp -v "$dll" "$INSTALL_DIR/"
    done
    shopt -u nullglob
    info "Executable and supporting files copied to $INSTALL_DIR/"
elif [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    info "$EXE_NAME already present in $INSTALL_DIR — skipping copy."
else
    warn "$EXE_NAME not found on any mounted USB drive."
    warn "Please copy it manually:  sudo cp /path/to/$EXE_NAME $INSTALL_DIR/"
fi

# ── 6. Initialize Wine prefix ───────────────────────────────────────
info "Initializing Wine prefix at $WINEPREFIX_DIR …"
# Run wineboot as the real (non-root) user
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

mkdir -p "$WINEPREFIX_DIR"
chown "$REAL_USER":"$REAL_USER" "$WINEPREFIX_DIR"
if sudo -u "$REAL_USER" env WINEPREFIX="$WINEPREFIX_DIR" DISPLAY="${DISPLAY:-}" wineboot --init 2>/dev/null; then
    info "Wine prefix initialized."
else
    warn "wineboot could not fully initialize (no display?). Prefix will be set up on first launch."
fi
chown -R "$REAL_USER":"$REAL_USER" "$INSTALL_DIR"
info "Wine prefix ready."

# ── 7. Create launcher script ───────────────────────────────────────
info "Creating launcher script …"
cat > "$LAUNCHER" << 'LAUNCHER_SCRIPT'
#!/usr/bin/env bash
# MAXHUB Wireless Dongle Launcher
set -euo pipefail

INSTALL_DIR="/opt/maxhub-dongle"
WINEPREFIX="$INSTALL_DIR/wineprefix"
EXE="$INSTALL_DIR/MAXHUB.exe"

if [[ ! -f "$EXE" ]]; then
    echo "Error: $EXE not found."
    echo "Please copy MAXHUB.exe to $INSTALL_DIR/ first."
    exit 1
fi

export WINEPREFIX
cd "$INSTALL_DIR"
exec wine "$EXE" "$@"
LAUNCHER_SCRIPT
chmod +x "$LAUNCHER"

# ── 8. Create desktop entry ─────────────────────────────────────────
info "Creating desktop launcher …"
cat > "$DESKTOP_FILE" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=MAXHUB Dongle
Comment=MAXHUB Wireless Screen Sharing Dongle
Exec=/opt/maxhub-dongle/maxhub-dongle.sh
Icon=video-display
Terminal=false
Categories=Utility;Network;
Keywords=maxhub;dongle;screen;sharing;wireless;
DESKTOP
chmod 644 "$DESKTOP_FILE"

# Update desktop database (best-effort)
update-desktop-database /usr/share/applications 2>/dev/null || true

# ── 9. Set ownership ────────────────────────────────────────────────
chown -R "$REAL_USER":"$REAL_USER" "$INSTALL_DIR"

# ── Done ─────────────────────────────────────────────────────────────
echo ""
info "========================================="
info "  MAXHUB Dongle installation complete!"
info "========================================="
echo ""
info "Install directory : $INSTALL_DIR"
info "Wine prefix       : $WINEPREFIX_DIR"
info "Udev rule         : $UDEV_RULE"
info "Launcher          : $LAUNCHER"
info "Desktop entry     : $DESKTOP_FILE"
echo ""
if [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    info "To launch: click 'MAXHUB Dongle' in your application menu,"
    info "           or run:  $LAUNCHER"
else
    warn "Remember to copy $EXE_NAME to $INSTALL_DIR/ before launching."
fi
echo ""
info "If the dongle is already plugged in, unplug and replug it"
info "so the new udev rules take effect."
