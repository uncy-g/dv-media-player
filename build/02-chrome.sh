
#!/bin/bash
#
# i-fi.tv - Google Chrome Installation
# Target: Debian 13 (Trixie)
#
# Installs Google Chrome Stable and creates a
# Leonardo-specific desktop launcher.
#
# The Leonardo launcher uses --password-store=basic
# to avoid GNOME Keyring prompts with automatic login.
#
# Does not modify system-wide Chrome launchers.
#

set -euo pipefail

echo
echo "=========================================="
echo " i-fi.tv - Google Chrome Installation"
echo "=========================================="
echo

# --------------------------------------------------
# 1. Check privileges
# --------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

# --------------------------------------------------
# 2. Install prerequisites
# --------------------------------------------------

echo "[1/5] Installing prerequisites..."

apt-get update

apt-get install -y \
    wget \
    ca-certificates \
    gnupg

# --------------------------------------------------
# 3. Configure Google Chrome repository
# --------------------------------------------------

echo "[2/5] Configuring Google Chrome repository..."

wget -q -O /tmp/google-chrome.gpg \
    https://dl.google.com/linux/linux_signing_key.pub

gpg --dearmor \
    --yes \
    -o /usr/share/keyrings/google-chrome.gpg \
    /tmp/google-chrome.gpg

rm -f /tmp/google-chrome.gpg

cat > /etc/apt/sources.list.d/google-chrome.list <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
EOF

# --------------------------------------------------
# 4. Install Google Chrome
# --------------------------------------------------

echo "[3/5] Installing Google Chrome..."

apt-get update

apt-get install -y google-chrome-stable

echo
echo "Installed Chrome version:"
google-chrome-stable --version

# --------------------------------------------------
# 5. Create Leonardo-specific desktop launcher
# --------------------------------------------------

echo
echo "[4/5] Creating Leonardo Chrome launcher..."

LEONARDO_USER="leonardo"

LEONARDO_HOME=$(getent passwd "$LEONARDO_USER" | cut -d: -f6)

if [[ -z "$LEONARDO_HOME" || ! -d "$LEONARDO_HOME" ]]; then
    echo "ERROR: Leonardo user or home directory not found."
    exit 1
fi

APP_DIR="${LEONARDO_HOME}/.local/share/applications"

mkdir -p "$APP_DIR"

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

# Set ownership to Leonardo
chown -R "${LEONARDO_USER}:$(id -gn "$LEONARDO_USER")" \
    "$APP_DIR"

chmod 755 "${APP_DIR}/google-chrome.desktop"

# --------------------------------------------------
# 6. Refresh desktop application database
# --------------------------------------------------

echo "[5/5] Refreshing Leonardo desktop applications..."

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || true
fi

# --------------------------------------------------
# Complete
# --------------------------------------------------

echo
echo "=========================================="
echo " Google Chrome installation complete"
echo "=========================================="
echo
echo "Chrome version:"
google-chrome-stable --version
echo
echo "Leonardo launcher:"
echo "${APP_DIR}/google-chrome.desktop"
echo
echo "Chrome launch options:"
echo "--password-store=basic"
echo
echo "System-wide Chrome launcher: UNMODIFIED"
echo
