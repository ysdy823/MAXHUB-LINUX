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

# ── Colours / UI helpers ─────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'
NC='\033[0m'

TOTAL_STEPS=6
current_step=0

step() {
    current_step=$((current_step + 1))
    echo ""
    echo -e "${BOLD}${BLUE}[$current_step/$TOTAL_STEPS]${NC} ${BOLD}$*${NC}"
    echo -e "${DIM}$(printf '%.0s─' {1..50})${NC}"
}

info()  { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
error() { echo -e "  ${RED}✗${NC} $*"; }
die()   { error "$*"; exit 1; }

spinner() {
    local pid=$1 msg=$2
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    # Hide cursor
    tput civis 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r  ${CYAN}${frames[$i]}${NC} ${DIM}$msg${NC} "
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done

    # Wait for exit code
    wait "$pid"
    local exit_code=$?

    # Clear spinner line and show cursor
    echo -ne "\r\033[K"
    tput cnorm 2>/dev/null || true

    return $exit_code
}

# ── Constants ────────────────────────────────────────────────────────
IMAGE_NAME="maxhub-dongle"
GHCR_IMAGE="ghcr.io/ysdy823/maxhub-dongle:latest"
INSTALL_DIR="/opt/maxhub-dongle"
UDEV_RULE="/etc/udev/rules.d/99-maxhub-dongle.rules"
DESKTOP_FILE="/usr/share/applications/maxhub-dongle.desktop"
LAUNCHER="$INSTALL_DIR/maxhub-dongle.sh"
EXE_NAME="MAXHUB.exe"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Banner ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║   MAXHUB Wireless Dongle — Installer      ║"
echo "  ║   Docker Edition                           ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${DIM}Wine runs in Docker — your system stays clean.${NC}"
echo ""

# ── Pre-flight checks ───────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root.  Try:  sudo bash $0"

REAL_USER="${SUDO_USER:-$USER}"

# ── Step 1: Docker ───────────────────────────────────────────────────
step "Docker"

if command -v docker &>/dev/null; then
    info "Already installed: $(docker --version | head -1)"
else
    echo -e "  ${DIM}Docker not found — installing via official script …${NC}"
    echo -e "  ${DIM}(supports Ubuntu, Debian, Fedora, CentOS, Arch, SUSE, and more)${NC}"

    if ! command -v curl &>/dev/null; then
        # Install curl using whatever package manager is available
        if command -v apt-get &>/dev/null; then
            apt-get update -qq 2>&1 | grep -v "^W:" || true
            apt-get install -y -qq curl >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf install -y -q curl >/dev/null 2>&1
        elif command -v pacman &>/dev/null; then
            pacman -Sy --noconfirm curl >/dev/null 2>&1
        elif command -v zypper &>/dev/null; then
            zypper install -y curl >/dev/null 2>&1
        else
            die "curl not found and no known package manager to install it"
        fi
    fi

    DOCKER_LOG="/tmp/maxhub-docker-install.log"
    if command -v pacman &>/dev/null; then
        # Arch Linux — get.docker.com doesn't support it
        (pacman -Sy --noconfirm docker >"$DOCKER_LOG" 2>&1) &
        spinner $! "Installing Docker (pacman) …"
    else
        # All other distros — official Docker script
        (curl -fsSL https://get.docker.com | sh -s -- >"$DOCKER_LOG" 2>&1) &
        spinner $! "Installing Docker …"
    fi

    if ! command -v docker &>/dev/null; then
        error "Install log: $DOCKER_LOG"
        die "Docker installation failed. Install manually: https://docs.docker.com/engine/install/"
    fi

    info "Docker installed: $(docker --version | head -1)"
fi

# Start Docker if not running
if ! docker info &>/dev/null 2>&1; then
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
fi

# Add user to docker group
if ! groups "$REAL_USER" | grep -q docker; then
    usermod -aG docker "$REAL_USER"
    info "Added $REAL_USER to docker group"
else
    info "$REAL_USER already in docker group"
fi

# ── Step 2: Wine container image ─────────────────────────────────────
step "Wine 11+ container image"

IMAGE_READY=false

# Check if image already exists locally
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
    info "Image '$IMAGE_NAME' already cached locally"
    IMAGE_READY=true
fi

# Try to pull pre-built image (fast — ~1 min instead of ~10 min)
if [[ "$IMAGE_READY" == false ]]; then
    echo -e "  ${DIM}Downloading pre-built image (~200MB compressed) …${NC}"
    (
        docker pull "$GHCR_IMAGE" 2>&1
    ) &
    if spinner $! "Pulling pre-built image …"; then
        docker tag "$GHCR_IMAGE" "$IMAGE_NAME"
        info "Pre-built image downloaded and ready"
        IMAGE_READY=true
    else
        warn "Could not download pre-built image — building locally"
    fi
fi

# Fallback: build locally from Dockerfile
if [[ "$IMAGE_READY" == false ]]; then
    if [[ ! -f "$SCRIPT_DIR/Dockerfile" ]]; then
        die "Dockerfile not found in $SCRIPT_DIR and pre-built image unavailable"
    fi

    echo -e "  ${DIM}Building locally (~400MB download, may take 5-10 min) …${NC}"

    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" 2>&1 | while IFS= read -r line; do
        case "$line" in
            *"#"*" DONE"*)
                echo -e "\r  ${GREEN}✓${NC} ${DIM}$line${NC}"
                ;;
            *"Downloading"* | *"Extracting"* | *"Pulling"*)
                echo -ne "\r  ${CYAN}⠋${NC} ${DIM}${line:0:70}${NC}\033[K"
                ;;
            *"Successfully tagged"* | *"naming to"*)
                echo ""
                ;;
        esac
    done
    IMAGE_READY=true
fi

info "Docker image '$IMAGE_NAME' ready"
WINE_VER=$(docker run --rm "$IMAGE_NAME" --version 2>/dev/null || echo "unknown")
info "Wine version in container: $WINE_VER"

# ── Step 3: Udev rule ───────────────────────────────────────────────
step "USB device permissions"

cat > "$UDEV_RULE" << 'UDEV'
# MAXHUB WT13 Wireless Dongle (VID:1FF7 PID:0F52)
# Allow all users access to the hidraw and usb device
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1ff7", ATTRS{idProduct}=="0f52", MODE="0666", ENV{ID_INPUT}="1", ENV{ID_INPUT_TOUCHSCREEN}="1"
SUBSYSTEM=="usb", ATTR{idVendor}=="1ff7", ATTR{idProduct}=="0f52", MODE="0666"
UDEV

if udevadm control --reload-rules 2>/dev/null && udevadm trigger 2>/dev/null; then
    info "Udev rules installed and reloaded"
else
    warn "Could not reload udev rules — will apply on next boot"
fi
info "Rule file: $UDEV_RULE"

# ── Step 4: Copy MAXHUB.exe ─────────────────────────────────────────
step "Locating MAXHUB.exe"

mkdir -p "$INSTALL_DIR"

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
    cp "$EXE_FOUND" "$INSTALL_DIR/$EXE_NAME"
    # Copy DLLs alongside the exe
    EXE_DIR=$(dirname "$EXE_FOUND")
    shopt -s nullglob
    for dll in "$EXE_DIR"/*.dll "$EXE_DIR"/*.DLL; do
        cp "$dll" "$INSTALL_DIR/"
        info "Copied: $(basename "$dll")"
    done
    shopt -u nullglob
    info "MAXHUB.exe copied to $INSTALL_DIR/"
elif [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    info "$EXE_NAME already in $INSTALL_DIR"
else
    warn "$EXE_NAME not found on USB drives"
    warn "Copy manually later:  sudo cp /path/to/$EXE_NAME $INSTALL_DIR/"
fi

# ── Step 5: Launcher + desktop entry ─────────────────────────────────
step "Creating launcher"

cat > "$LAUNCHER" << 'LAUNCHER_SCRIPT'
#!/usr/bin/env bash
# MAXHUB Wireless Dongle Launcher (Docker edition)
set -euo pipefail

INSTALL_DIR="/opt/maxhub-dongle"
IMAGE_NAME="maxhub-dongle"
EXE="$INSTALL_DIR/MAXHUB.exe"

# ── Pre-launch checks ──────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "Error: Docker is not installed."
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    echo "Error: Docker is not running. Start it with: sudo systemctl start docker"
    exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
    echo "Error: No display found (\$DISPLAY is empty)."
    echo "This tool requires X11. Wayland without XWayland is not supported."
    echo "If you use Wayland, make sure XWayland is enabled."
    exit 1
fi

if [[ ! -f "$EXE" ]]; then
    echo "Error: $EXE not found."
    echo "Copy MAXHUB.exe to $INSTALL_DIR/ first."
    exit 1
fi

# Allow Docker container to access X11 display
xhost +local:docker >/dev/null 2>&1 || true

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
info "Launcher: $LAUNCHER"

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
info "Desktop entry: MAXHUB Dongle (in app menu)"

# ── Step 6: Finalize ─────────────────────────────────────────────────
step "Finishing up"

chown -R "$REAL_USER":"$REAL_USER" "$INSTALL_DIR"
info "Ownership set to $REAL_USER"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║        Installation complete!              ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Installed:${NC}"
echo -e "  ${DIM}├─${NC} Docker image  : ${CYAN}$IMAGE_NAME${NC} (Wine $WINE_VER)"
echo -e "  ${DIM}├─${NC} Udev rule     : ${CYAN}$UDEV_RULE${NC}"
echo -e "  ${DIM}├─${NC} Launcher      : ${CYAN}$LAUNCHER${NC}"
echo -e "  ${DIM}└─${NC} Desktop entry : ${CYAN}MAXHUB Dongle${NC}"
echo ""
echo -e "  ${BOLD}${GREEN}Your system packages were NOT modified.${NC}"
echo -e "  ${DIM}Wine runs inside Docker — nothing was installed on your system.${NC}"
echo ""

if [[ -f "$INSTALL_DIR/$EXE_NAME" ]]; then
    echo -e "  ${BOLD}To launch:${NC}"
    echo -e "    Click ${CYAN}MAXHUB Dongle${NC} in app menu, or run:"
    echo -e "    ${CYAN}$LAUNCHER${NC}"
else
    echo -e "  ${YELLOW}⚠${NC} Copy ${BOLD}$EXE_NAME${NC} to $INSTALL_DIR/ before launching."
fi

echo ""
NEEDS_RELOGIN=false
if ! groups "$REAL_USER" | grep -q docker; then
    echo -e "  ${YELLOW}⚠${NC} ${BOLD}Log out and back in${NC} for Docker permissions to take effect."
    NEEDS_RELOGIN=true
fi
echo -e "  ${DIM}If the dongle is plugged in, unplug and replug it.${NC}"
echo ""
