
#!/bin/bash
#
# i-fi.tv - Google Chrome Installation
# Target: Debian 13 (Trixie), amd64
#
# Responsibilities:
#   - Install Google Chrome Stable
#   - Configure Google's APT repository
#   - Create Leonardo-specific Chrome launcher
#   - Create Leonardo desktop shortcut
#   - Configure Chrome password store
#   - Establish XFCE trusted launcher metadata
#
# Does NOT:
#   - Modify system-wide desktop launchers
#   - Configure screensaver or screen locking
#   - Configure desktop power management
#

set -euo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

LEONARDO_USER="leonardo"

CHROME_REPO_KEY="/usr/share/keyrings/google-chrome.gpg"
CHROME_REPO_FILE="/etc/apt/sources.list.d/google-chrome.list"

echo
echo "=========================================="
echo " i-fi.tv - Chrome Installation"
echo "=========================================="
echo

# --------------------------------------------------
# 1. Privilege and architecture checks
# --------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

ARCH=$(dpkg --print-architecture)

if [[ "$ARCH" != "amd64" ]]; then
    echo "ERROR: Google Chrome requires amd64."
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

# --------------------------------------------------
# 2. Leonardo session helper
# --------------------------------------------------

SESSION_AVAILABLE=false

if [[ -S "$SESSION_BUS" ]]; then
    SESSION_AVAILABLE=true
fi

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

# --------------------------------------------------
# 3. Install prerequisites
# --------------------------------------------------

echo
echo "[1/6] Installing prerequisites..."

apt-get update

apt-get install -y \
    wget \
    ca-certificates \
    gnupg \
    xdg-utils \
    libglib2.0-bin

# --------------------------------------------------
# 4. Configure Google Chrome repository
# --------------------------------------------------

echo
echo "[2/6] Configuring Google Chrome repository..."

wget -q -O /tmp/google-chrome.gpg \
    https://dl.google.com/linux/linux_signing_key.pub

gpg --dearmor \
    --yes \
    -o "$CHROME_REPO_KEY" \
    /tmp/google-chrome.gpg

rm -f /tmp/google-chrome.gpg

cat > "$CHROME_REPO_FILE" <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
EOF

# --------------------------------------------------
# 5. Install Google Chrome
# --------------------------------------------------

echo
echo "[3/6] Installing Google Chrome..."

apt-get update

apt-get install -y google-chrome-stable

echo
google-chrome-stable --version

# --------------------------------------------------
# 6. Create Leonardo application launcher
# --------------------------------------------------

echo
echo "[4/6] Creating Leonardo application launcher..."

APP_DIR="${LEONARDO_HOME}/.local/share/applications"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    "$APP_DIR"

APP_LAUNCHER="${APP_DIR}/google-chrome.desktop"

cat > "$APP_LAUNCHER" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
GenericName=Web Browser
Comment=Browse the Internet
Exec=/usr/bin/google-chrome-stable --password-store=basic %U
TryExec=/usr/bin/google-chrome-stable
Icon=google-chrome
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

chown "$LEONARDO_USER:$LEONARDO_GROUP" "$APP_LAUNCHER"
chmod 644 "$APP_LAUNCHER"

# --------------------------------------------------
# 7. Create Leonardo desktop shortcut
# --------------------------------------------------

echo
echo "[5/6] Creating Leonardo desktop shortcut..."

DESKTOP_DIR="${LEONARDO_HOME}/Desktop"

# Honour the configured XDG desktop directory.
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
    "$DESKTOP_DIR"

CHROME_SHORTCUT="${DESKTOP_DIR}/Google Chrome.desktop"

cp "$APP_LAUNCHER" "$CHROME_SHORTCUT"

chown "$LEONARDO_USER:$LEONARDO_GROUP" "$CHROME_SHORTCUT"
chmod 755 "$CHROME_SHORTCUT"

# --------------------------------------------------
# 8. Establish XFCE launcher trust
# --------------------------------------------------

echo
echo "[6/6] Configuring XFCE launcher trust..."

if [[ "$SESSION_AVAILABLE" == true ]]; then

    # Mark the desktop launcher as trusted.
    run_as_leonardo gio set -t string \
        "$CHROME_SHORTCUT" \
        metadata::trusted true

    # XFCE requires the checksum of the final launcher.
    CHECKSUM=$(sha256sum "$CHROME_SHORTCUT" | awk '{print $1}')

    run_as_leonardo gio set -t string \
        "$CHROME_SHORTCUT" \
        metadata::xfce-exe-checksum "$CHECKSUM"

    echo "XFCE trust metadata configured."
    echo "Checksum: $CHECKSUM"

else
    echo "WARNING: Leonardo desktop session unavailable."
    echo "Launcher trust metadata not configured."
fi

# --------------------------------------------------
# 9. Refresh application menu database
# --------------------------------------------------

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || true
fi

# --------------------------------------------------
# 10. Completion
# --------------------------------------------------

echo
echo "=========================================="
echo " Chrome installation complete"
echo "=========================================="
echo
echo "Chrome version:"
google-chrome-stable --version
echo
echo "Application launcher:"
echo "  $APP_LAUNCHER"
echo
echo "Desktop shortcut:"
echo "  $CHROME_SHORTCUT"
echo
echo "Chrome password store:"
echo "  basic"
echo
echo "XFCE trust configured:"
echo "  $SESSION_AVAILABLE"
echo
echo "System-wide launchers:"
echo "  UNMODIFIED"
echo
echo "=========================================="
