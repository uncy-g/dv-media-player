
#!/bin/bash
#
# i-fi.tv - Google Chrome Installation
# Target: Debian 13 (Trixie)
#
# Installs Google Chrome Stable.
# Creates Leonardo-specific launchers.
#
# Chrome uses --password-store=basic to avoid
# GNOME Keyring prompts with automatic login.
#
# System-wide Chrome desktop launchers are NOT modified.
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

LEONARDO_HOME=$(getent passwd "$LEONARDO_USER" | cut -d: -f6)

if [[ -z "$LEONARDO_HOME" || ! -d "$LEONARDO_HOME" ]]; then
    echo "ERROR: Leonardo user or home directory not found."
    exit 1
fi

LEONARDO_GROUP=$(id -gn "$LEONARDO_USER")

echo "Target user: $LEONARDO_USER"
echo "Home:        $LEONARDO_HOME"
echo "Group:       $LEONARDO_GROUP"

# --------------------------------------------------
# 2. Install prerequisites
# --------------------------------------------------

echo
echo "[1/5] Installing prerequisites..."

apt-get update

apt-get install -y \
    wget \
    ca-certificates \
    gnupg \
    xdg-utils

# --------------------------------------------------
# 3. Configure Google Chrome repository
# --------------------------------------------------

echo
echo "[2/5] Configuring Google Chrome repository..."

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
# 4. Install Google Chrome
# --------------------------------------------------

echo
echo "[3/5] Installing Google Chrome..."

apt-get update

apt-get install -y google-chrome-stable

echo
echo "Installed version:"
google-chrome-stable --version

# --------------------------------------------------
# 5. Create Leonardo application launcher
# --------------------------------------------------

echo
echo "[4/5] Creating Leonardo application launcher..."

APP_DIR="${LEONARDO_HOME}/.local/share/applications"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    "$APP_DIR"

cat > "${APP_DIR}/google-chrome.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
GenericName=Web Browser
Comment=Browse the Internet
Exec=/usr/bin/google-chrome-stable --password-store=basic %U
Icon=google-chrome
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF

chown "$LEONARDO_USER:$LEONARDO_GROUP" \
    "${APP_DIR}/google-chrome.desktop"

chmod 755 "${APP_DIR}/google-chrome.desktop"

# --------------------------------------------------
# 6. Create Leonardo desktop shortcut
# --------------------------------------------------

echo
echo "[5/5] Creating Leonardo desktop shortcut..."

# Obtain the configured desktop directory.
DESKTOP_DIR=$(runuser -u "$LEONARDO_USER" -- \
    env HOME="$LEONARDO_HOME" xdg-user-dir DESKTOP 2>/dev/null || true)

# Fall back to the conventional Desktop directory.
if [[ -z "$DESKTOP_DIR" ]]; then
    DESKTOP_DIR="${LEONARDO_HOME}/Desktop"
fi

# Create desktop directory if necessary.
install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    "$DESKTOP_DIR"

# Install the desktop shortcut.
cp "${APP_DIR}/google-chrome.desktop" \
   "${DESKTOP_DIR}/Google Chrome.desktop"

chown "$LEONARDO_USER:$LEONARDO_GROUP" \
    "${DESKTOP_DIR}/Google Chrome.desktop"

chmod 755 "${DESKTOP_DIR}/Google Chrome.desktop"

# Mark shortcut as trusted (XFCE/GIO).
if command -v gio >/dev/null 2>&1; then
    runuser -u "$LEONARDO_USER" -- \
        env HOME="$LEONARDO_HOME" \
        gio set "${DESKTOP_DIR}/Google Chrome.desktop" \
        metadata::trusted true 2>/dev/null || true
fi

# Refresh Leonardo's application menu database.
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || true
fi

# --------------------------------------------------
# 7. Completion
# --------------------------------------------------

echo
echo "=========================================="
echo " Chrome installation complete"
echo "=========================================="
echo
echo "Chrome version:"
google-chrome-stable --version
echo
echo "Leonardo application launcher:"
echo "${APP_DIR}/google-chrome.desktop"
echo
echo "Leonardo desktop shortcut:"
echo "${DESKTOP_DIR}/Google Chrome.desktop"
echo
echo "Chrome launch parameter:"
echo "--password-store=basic"
echo
echo "System-wide desktop launchers: UNMODIFIED"
echo
echo "=========================================="
