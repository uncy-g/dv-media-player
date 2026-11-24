
#!/bin/bash
#
# i-fi.tv - Kodi Installation and Configuration
# Target: Debian 13 (Trixie), amd64
#
# Responsibilities:
#   - Install Kodi
#   - Install HDMI-CEC utilities
#   - Establish dv-media-player configuration directories
#   - Establish Leonardo Kodi configuration directories
#   - Configure Kodi application launcher
#   - Create Leonardo desktop shortcut (final step)
#
# Configuration layout:
#
#   /opt/dv/
#       etc/dv-media-player/
#           Machine-specific configuration
#
#   /home/leonardo/
#       .kodi/
#           Kodi user configuration
#       .local/share/applications/
#           Kodi application launcher
#       Desktop/
#           Kodi desktop shortcut
#
# Kodi must always run as Leonardo, never root.
#
# Safe to rerun. Existing Kodi configuration is preserved.
#

set -euo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

LEONARDO_USER="leonardo"

DV_ROOT="/opt/dv"
DV_CONFIG="${DV_ROOT}/etc/dv-media-player"

KODI_HOME="${DV_ROOT}/var/kodi"

echo
echo "=========================================="
echo " i-fi.tv - Kodi Installation"
echo "=========================================="
echo

# --------------------------------------------------
# 1. Privilege and platform checks
# --------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

if ! grep -q '^VERSION_CODENAME=trixie' /etc/os-release; then
    echo "ERROR: This script targets Debian 13 Trixie."
    exit 1
fi

if ! id "$LEONARDO_USER" >/dev/null 2>&1; then
    echo "ERROR: User $LEONARDO_USER does not exist."
    exit 1
fi

LEONARDO_UID=$(id -u "$LEONARDO_USER")
LEONARDO_GROUP=$(id -gn "$LEONARDO_USER")
LEONARDO_HOME=$(getent passwd "$LEONARDO_USER" | cut -d: -f6)

if [[ -z "$LEONARDO_HOME" || ! -d "$LEONARDO_HOME" ]]; then
    echo "ERROR: Leonardo home directory not found."
    exit 1
fi

SESSION_RUNTIME="/run/user/${LEONARDO_UID}"
SESSION_BUS="${SESSION_RUNTIME}/bus"

echo "Target user: $LEONARDO_USER"
echo "Home:        $LEONARDO_HOME"
echo "DV config:   $DV_CONFIG"

# --------------------------------------------------
# User session helper
# --------------------------------------------------

run_as_leonardo() {
    runuser -u "$LEONARDO_USER" -- \
        env \
        HOME="$LEONARDO_HOME" \
        USER="$LEONARDO_USER" \
        LOGNAME="$LEONARDO_USER" \
        XDG_RUNTIME_DIR="$SESSION_RUNTIME" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=${SESSION_BUS}" \
        "$@"
}

SESSION_AVAILABLE=false

if [[ -S "$SESSION_BUS" ]]; then
    SESSION_AVAILABLE=true
fi

# --------------------------------------------------
# 2. Install Kodi and dependencies
# --------------------------------------------------

echo
echo "[1/7] Installing Kodi and dependencies..."

apt-get update

apt-get install -y \
    kodi \
    cec-utils

echo
echo "Kodi version:"
kodi --version || true

echo
echo "CEC utilities:"
command -v cec-client || true

# --------------------------------------------------
# 3. Establish machine configuration directories
# --------------------------------------------------

echo
echo "[2/7] Establishing machine configuration..."

install -d -m 755 "$DV_CONFIG"

install -d -m 755 \
    "${DV_CONFIG}/kodi"

# Kodi machine configuration belongs here.
# Do not place Leonardo's personal settings here.

echo "Machine configuration:"
echo "  $DV_CONFIG/kodi"

# --------------------------------------------------
# 4. Establish Kodi user directories
# --------------------------------------------------

echo
echo "[3/7] Establishing Leonardo Kodi directories..."

KODI_USER_DIR="${LEONARDO_HOME}/.kodi"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    -m 755 \
    "$KODI_USER_DIR"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    -m 755 \
    "${KODI_USER_DIR}/userdata"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    -m 755 \
    "${KODI_USER_DIR}/addons"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    -m 755 \
    "${KODI_USER_DIR}/temp"

echo "Kodi user configuration:"
echo "  $KODI_USER_DIR"

# Preserve existing configuration.
# Kodi creates its own settings.xml on first launch.

# --------------------------------------------------
# 5. Prepare application menu launcher
# --------------------------------------------------

echo
echo "[4/7] Preparing Kodi application launcher..."

APP_DIR="${LEONARDO_HOME}/.local/share/applications"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    -m 755 \
    "$APP_DIR"

APP_LAUNCHER="${APP_DIR}/kodi.desktop"

cat > "$APP_LAUNCHER" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Kodi
GenericName=Media Centre
Comment=Launch Kodi Media Centre
Exec=/usr/bin/kodi
TryExec=/usr/bin/kodi
Icon=kodi
Terminal=false
Categories=AudioVideo;Video;Player;
StartupNotify=false
EOF

chown "$LEONARDO_USER:$LEONARDO_GROUP" "$APP_LAUNCHER"
chmod 644 "$APP_LAUNCHER"

# --------------------------------------------------
# 6. Validate installation
# --------------------------------------------------

echo
echo "[5/7] Validating Kodi installation..."

if [[ ! -x /usr/bin/kodi ]]; then
    echo "ERROR: Kodi executable not found."
    exit 1
fi

if [[ ! -x /usr/bin/cec-client ]]; then
    echo "WARNING: HDMI-CEC client not found."
fi

echo "Kodi executable: OK"
echo "Kodi configuration directories: OK"
echo "Application launcher: OK"

# Refresh application menu database.

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || true
fi

# --------------------------------------------------
# 7. Create Leonardo desktop shortcut
# --------------------------------------------------
#
# IMPORTANT:
# This is deliberately the final installation operation.
#
# The desktop file must not be modified after its XFCE
# trusted-launcher checksum has been generated.
#

echo
echo "[6/7] Creating Leonardo desktop shortcut..."

DESKTOP_DIR="${LEONARDO_HOME}/Desktop"

if [[ "$SESSION_AVAILABLE" == true ]]; then

    CONFIGURED_DESKTOP=$(run_as_leonardo \
        xdg-user-dir DESKTOP 2>/dev/null || true)

    if [[ -n "$CONFIGURED_DESKTOP" && \
          "$CONFIGURED_DESKTOP" != "$LEONARDO_HOME" ]]; then
        DESKTOP_DIR="$CONFIGURED_DESKTOP"
    fi

fi

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    -m 755 \
    "$DESKTOP_DIR"

KODI_SHORTCUT="${DESKTOP_DIR}/Kodi.desktop"

cp "$APP_LAUNCHER" "$KODI_SHORTCUT"

chown "$LEONARDO_USER:$LEONARDO_GROUP" "$KODI_SHORTCUT"
chmod 755 "$KODI_SHORTCUT"

# --------------------------------------------------
# 8. Establish XFCE launcher trust
# --------------------------------------------------

echo
echo "[7/7] Establishing XFCE launcher trust..."

if [[ "$SESSION_AVAILABLE" == true ]]; then

    run_as_leonardo gio set -t string \
        "$KODI_SHORTCUT" \
        metadata::trusted true

    KODI_CHECKSUM=$(sha256sum "$KODI_SHORTCUT" | awk '{print $1}')

    run_as_leonardo gio set -t string \
        "$KODI_SHORTCUT" \
        metadata::xfce-exe-checksum "$KODI_CHECKSUM"

    echo "XFCE trust metadata configured."
    echo "Checksum: $KODI_CHECKSUM"

else

    echo "WARNING: Leonardo graphical session unavailable."
    echo "Desktop shortcut created but trust metadata deferred."

fi

# --------------------------------------------------
# Completion
# --------------------------------------------------

echo
echo "=========================================="
echo " Kodi installation complete"
echo "=========================================="
echo
echo "Kodi executable:"
echo "  /usr/bin/kodi"
echo
echo "Kodi user configuration:"
echo "  $KODI_USER_DIR"
echo
echo "Machine configuration:"
echo "  $DV_CONFIG/kodi"
echo
echo "Application launcher:"
echo "  $APP_LAUNCHER"
echo
echo "Desktop shortcut:"
echo "  $KODI_SHORTCUT"
echo
echo "HDMI-CEC:"
echo "  cec-utils installed"
echo
echo "Run Kodi as:"
echo "  $LEONARDO_USER"
echo
echo "=========================================="
