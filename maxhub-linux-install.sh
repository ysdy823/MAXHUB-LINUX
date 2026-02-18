#!/usr/bin/env bash
#
# MAXHUB Wireless Dongle — Linux Installer v3.0 (Docker edition)
#
# Runs Wine 11.x+ inside a Docker container — zero conflicts with your system.
# Only touches: Docker (if not installed), one udev rule, and launcher files.
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
TOTAL_STEPS=6
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
IMAGE_NAME="maxhub-dongle"
GHCR_IMAGE="ghcr.io/ysdy823/maxhub-dongle:latest"
INSTALL_DIR="/opt/maxhub-dongle"
UDEV_RULE="/etc/udev/rules.d/99-maxhub-dongle.rules"
DESKTOP_FILE="/usr/share/applications/maxhub-dongle.desktop"
LAUNCHER="$INSTALL_DIR/maxhub-dongle.sh"
EXE_NAME="MAXHUB.exe"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Distro detection ─────────────────────────────────────────────
DISTRO_FAMILY="unknown"
PKG_MANAGER="unknown"

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        case "${ID:-}" in
            ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian)
                DISTRO_FAMILY="debian"; PKG_MANAGER="apt-get" ;;
            fedora)
                DISTRO_FAMILY="fedora"; PKG_MANAGER="dnf" ;;
            centos|rhel|rocky|alma|ol)
                DISTRO_FAMILY="fedora"
                command -v dnf &>/dev/null && PKG_MANAGER="dnf" || PKG_MANAGER="yum" ;;
            arch|manjaro|endeavouros|garuda)
                DISTRO_FAMILY="arch"; PKG_MANAGER="pacman" ;;
            opensuse*|sles)
                DISTRO_FAMILY="suse"; PKG_MANAGER="zypper" ;;
        esac
    fi

    # Fallback: detect by package manager
    if [[ "$DISTRO_FAMILY" == "unknown" ]]; then
        if command -v apt-get &>/dev/null; then
            DISTRO_FAMILY="debian"; PKG_MANAGER="apt-get"
        elif command -v dnf &>/dev/null; then
            DISTRO_FAMILY="fedora"; PKG_MANAGER="dnf"
        elif command -v yum &>/dev/null; then
            DISTRO_FAMILY="fedora"; PKG_MANAGER="yum"
        elif command -v pacman &>/dev/null; then
            DISTRO_FAMILY="arch"; PKG_MANAGER="pacman"
        elif command -v zypper &>/dev/null; then
            DISTRO_FAMILY="suse"; PKG_MANAGER="zypper"
        fi
    fi
}

# ── Docker installation (distro-native first, get.docker.com fallback) ──
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

install_docker() {
    local log="/tmp/maxhub-docker-install.log"
    local installed=false

    # Try distro-native package first (faster — no repo addition needed)
    case "$DISTRO_FAMILY" in
        debian)
            echo -e "  ${DIM}Installing docker.io via apt …${NC}"
            (apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq docker.io >"$log" 2>&1) &
            spinner $! "Installing Docker (apt) …" && installed=true || true
            ;;
        fedora)
            echo -e "  ${DIM}Installing docker via $PKG_MANAGER …${NC}"
            ($PKG_MANAGER install -y docker >"$log" 2>&1) &
            spinner $! "Installing Docker ($PKG_MANAGER) …" && installed=true || true
            ;;
        arch)
            echo -e "  ${DIM}Installing docker via pacman …${NC}"
            (pacman -Sy --noconfirm docker >"$log" 2>&1) &
            spinner $! "Installing Docker (pacman) …" && installed=true || true
            ;;
        suse)
            echo -e "  ${DIM}Installing docker via zypper …${NC}"
            (zypper --non-interactive install docker >"$log" 2>&1) &
            spinner $! "Installing Docker (zypper) …" && installed=true || true
            ;;
    esac

    # Check if native install succeeded
    if [[ "$installed" == true ]] && command -v docker &>/dev/null; then
        return 0
    fi

    # Fallback: get.docker.com (supports nearly everything)
    if ! command -v docker &>/dev/null; then
        warn "Distro package unavailable — using get.docker.com"
        ensure_curl
        (curl -fsSL https://get.docker.com | sh -s -- >"$log" 2>&1) &
        spinner $! "Installing Docker (get.docker.com) …" || true
    fi

    if ! command -v docker &>/dev/null; then
        error "Install log: $log"
        die "Docker installation failed. Install manually: https://docs.docker.com/engine/install/"
    fi
}

# ── Banner ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║   MAXHUB Wireless Dongle — Installer      ║"
echo "  ║   Docker Edition  v3.0                     ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${DIM}Wine runs in Docker — your system stays clean.${NC}"
echo -e "  ${DIM}Estimated time: ~2-4 min (faster if Docker is installed)${NC}"
echo ""

# ── Pre-flight checks ───────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root.  Try:  sudo bash $0"

REAL_USER="${SUDO_USER:-$USER}"
DOCKER_GROUP_ADDED=false

detect_distro
info "Detected: ${DISTRO_FAMILY} (${PKG_MANAGER})"

# ── Step 1: Docker ──────────────────────────────────────────────
step "Docker" "~1 min if not installed"

if command -v docker &>/dev/null; then
    info "Already installed: $(docker --version | head -1)"
else
    install_docker
    info "Docker installed: $(docker --version | head -1)"
fi

# Start Docker if not running
if ! docker info &>/dev/null 2>&1; then
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true

    # Verify it actually started (retry up to 10 seconds)
    retries=0
    while ! docker info &>/dev/null 2>&1; do
        retries=$((retries + 1))
        if [[ $retries -ge 10 ]]; then
            die "Docker failed to start. Check: journalctl -u docker"
        fi
        sleep 1
    done
    info "Docker daemon started"
fi

# Enable Docker on boot
systemctl enable docker 2>/dev/null || true

# Add user to docker group
if ! id -nG "$REAL_USER" 2>/dev/null | grep -qw docker; then
    usermod -aG docker "$REAL_USER"
    DOCKER_GROUP_ADDED=true
    info "Added $REAL_USER to docker group"
else
    info "$REAL_USER already in docker group"
fi

step_done

# ── Step 2: Wine container image ────────────────────────────────
step "Wine 11+ container image" "~1-2 min if not cached"

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

# Verify Wine works in the image
WINE_VER=$(docker run --rm "$IMAGE_NAME" --version 2>/dev/null) || WINE_VER=""
if [[ "$WINE_VER" == *"wine-"* ]]; then
    info "Wine version in container: $WINE_VER"
else
    warn "Wine verification: ${WINE_VER:-no response} (may still work at runtime)"
fi

step_done

# ── Step 3: Udev rule ──────────────────────────────────────────
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

# ── Step 4: Copy MAXHUB.exe ────────────────────────────────────
step "Locating MAXHUB.exe" "~1 sec"

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

step_done

# ── Step 5: Launcher + desktop entry ───────────────────────────
step "Creating launcher" "~1 sec"

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
    # Docker group may not be active yet (need logout/login) — try sg workaround
    if sg docker -c "docker info" &>/dev/null 2>&1; then
        exec sg docker -c "$0"
    fi
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
    --security-opt label=disable \
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
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
info "Desktop entry: MAXHUB Dongle (in app menu)"

step_done

# ── Step 6: Finalize ───────────────────────────────────────────
step "Finishing up" "~1 sec"

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

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║        Installation complete!              ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Total time: ${CYAN}${TIME_STR}${NC}"
echo ""
echo -e "  ${BOLD}Installed:${NC}"
echo -e "  ${DIM}├─${NC} Docker image  : ${CYAN}$IMAGE_NAME${NC} (Wine ${WINE_VER:-unknown})"
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
if [[ "$DOCKER_GROUP_ADDED" == true ]]; then
    echo -e "  ${YELLOW}⚠${NC} ${BOLD}Log out and back in${NC} for Docker permissions to take effect."
    echo -e "  ${DIM}  (or the launcher will use a workaround automatically)${NC}"
fi
echo -e "  ${DIM}If the dongle is plugged in, unplug and replug it.${NC}"
echo ""
