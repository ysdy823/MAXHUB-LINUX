#!/usr/bin/env bash
#
# MAXHUB Wireless Dongle — Linux Installer (Docker edition)
#
# Runs Wine 11.x+ inside a Docker container — zero conflicts with your system.
# Only touches: Docker (if not installed), one udev rule, and launcher files.
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
IMAGE_NAME="maxhub-dongle"
INSTALL_DIR="/opt/maxhub-dongle"
UDEV_RULE="/etc/udev/rules.d/99-maxhub-dongle.rules"
DESKTOP_FILE="/usr/share/applications/maxhub-dongle.desktop"
LAUNCHER="$INSTALL_DIR/maxhub-dongle.sh"
EXE_NAME="MAXHUB.exe"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Pre-flight checks ───────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root.  Try:  sudo bash $0"

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ── 1. Install Docker if needed ─────────────────────────────────────
if command -v docker &>/dev/null; then
    info "Docker already installed: $(docker --version)"
else
    info "Installing Docker …"

    apt-get update -qq 2>&1 | grep -v "^W:" >&2 || true
    apt-get install -y -qq ca-certificates curl gnupg >/dev/null

    install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    fi

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
    fi

    if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${VERSION_CODENAME:-noble} stable" > /etc/apt/sources.list.d/docker.list
    fi

    apt-get update -qq 2>&1 | grep -v "^W:" >&2 || true
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io >/dev/null

    info "Docker installed."
fi

# Add user to docker group (so they can run without sudo)
if ! groups "$REAL_USER" | grep -q docker; then
    usermod -aG docker "$REAL_USER"
    info "Added $REAL_USER to docker group (takes effect on next login)."
fi

# ── 2. Build Docker image with Wine 11+ ─────────────────────────────
info "Building Docker image '$IMAGE_NAME' — this may take a few minutes on first run …"

# Use Dockerfile from same directory as this script
if [[ -f "$SCRIPT_DIR/Dockerfile" ]]; then
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" 2>&1 | while IFS= read -r line; do
        # Show only key progress lines
        case "$line" in
            *"Step "* | *"Successfully"* | *"DONE"*) echo "  $line" ;;
        esac
    done
else
    die "Dockerfile not found in $SCRIPT_DIR"
fi

info "Docker image '$IMAGE_NAME' ready."

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
    warn "Could not reload udev rules. Rules will apply on next boot."
fi

# ── 4. Prepare install directory & copy MAXHUB.exe ───────────────────
mkdir -p "$INSTALL_DIR"

EXE_FOUND=""
# Check if exe is next to the install script
if [[ -f "$SCRIPT_DIR/$EXE_NAME" ]]; then
    EXE_FOUND="$SCRIPT_DIR/$EXE_NAME"
fi

# Search USB mount points
if [[ -z "$EXE_FOUND" ]]; then
    for mount_dir in /media /mnt /run/media; do
        if [[ -d "$mount_dir" ]]; then
            FOUND=$(find "$mount_dir" -maxdepth 4 -iname "$EXE_NAME" -type f 2>/dev/null | head -1)
            if [[ -n "$FOUND" ]]; then
                EXE_FOUND="$FOUND"
                break
            fi
        fi
    done
fi

if [[ -n "$EXE_FOUND" ]]; then
    info "Found $EXE_NAME at: $EXE_FOUND"
    cp -v "$EXE_FOUND" "$INSTALL_DIR/$EXE_NAME"

    # Also copy DLLs alongside the exe
    EXE_DIR=$(dirname "$EXE_FOUND")
    shopt -s nullglob
    for dll in "$EXE_DIR"/*.dll "$EXE_DIR"/*.DLL; do
        cp -v "$dll" "$INSTALL_DIR/"
    done
    shopt -u nullglob
    info "Files copied to $INSTALL_DIR/"
elif [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    info "$EXE_NAME already present in $INSTALL_DIR — skipping."
else
    warn "$EXE_NAME not found."
    warn "Copy it manually:  sudo cp /path/to/$EXE_NAME $INSTALL_DIR/"
fi

# ── 5. Create launcher script ───────────────────────────────────────
info "Creating launcher script …"
cat > "$LAUNCHER" << 'LAUNCHER_SCRIPT'
#!/usr/bin/env bash
# MAXHUB Wireless Dongle Launcher (Docker edition)
set -euo pipefail

INSTALL_DIR="/opt/maxhub-dongle"
IMAGE_NAME="maxhub-dongle"
EXE="$INSTALL_DIR/MAXHUB.exe"

if [[ ! -f "$EXE" ]]; then
    echo "Error: $EXE not found."
    echo "Copy MAXHUB.exe to $INSTALL_DIR/ first."
    exit 1
fi

# Collect all hidraw devices for the dongle
HIDRAW_ARGS=""
for dev in /dev/hidraw*; do
    [[ -e "$dev" ]] && HIDRAW_ARGS="$HIDRAW_ARGS --device=$dev"
done

# Collect all USB bus devices
USB_ARGS=""
for dev in /dev/bus/usb/*/*; do
    [[ -e "$dev" ]] && USB_ARGS="$USB_ARGS --device=$dev"
done

exec docker run --rm \
    -e DISPLAY="$DISPLAY" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$INSTALL_DIR:/app:ro" \
    $HIDRAW_ARGS \
    $USB_ARGS \
    --network=host \
    "$IMAGE_NAME" \
    /app/MAXHUB.exe
LAUNCHER_SCRIPT
chmod +x "$LAUNCHER"

# ── 6. Create desktop entry ─────────────────────────────────────────
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
update-desktop-database /usr/share/applications 2>/dev/null || true

# ── 7. Set ownership ────────────────────────────────────────────────
chown -R "$REAL_USER":"$REAL_USER" "$INSTALL_DIR"

# ── Done ─────────────────────────────────────────────────────────────
echo ""
info "========================================="
info "  MAXHUB Dongle installation complete!"
info "========================================="
echo ""
info "What was installed:"
info "  - Docker image '$IMAGE_NAME' (Wine runs inside, not on your system)"
info "  - Udev rule    : $UDEV_RULE"
info "  - Launcher     : $LAUNCHER"
info "  - Desktop entry: $DESKTOP_FILE"
echo ""
info "Your system packages were NOT modified (Wine runs in Docker)."
echo ""
if [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    info "To launch: click 'MAXHUB Dongle' in your application menu,"
    info "           or run:  $LAUNCHER"
else
    warn "Copy $EXE_NAME to $INSTALL_DIR/ before launching."
fi
echo ""
if ! groups "$REAL_USER" | grep -q docker; then
    warn "Log out and log back in for Docker permissions to take effect."
fi
info "If the dongle is plugged in, unplug and replug it."
