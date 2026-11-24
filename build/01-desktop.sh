
#!/bin/bash
#
# i-fi.tv - Desktop Environment Installation
# Target: Debian 13 (Trixie)
#
# Responsibilities:
#   - Install Xorg and XFCE desktop
#   - Configure LightDM
#   - Configure Leonardo automatic login
#   - Configure XFCE screensaver
#   - Disable screen locking and password challenges
#   - Retain screen blanking and display power management
#   - Install Firefox ESR
#   - Install Kodi
#   - Install SSH server
#   - Install HDMI-CEC utilities
#
# Does NOT:
#   - Install Google Chrome
#   - Configure Chrome launchers
#   - Configure Unified Remote
#

set -euo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

LEONARDO_USER="leonardo"

echo
echo "=========================================="
echo " i-fi.tv - Desktop Installation"
echo "=========================================="
echo

# --------------------------------------------------
# 1. Privilege and platform checks
# --------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

if [[ ! -f /etc/debian_version ]]; then
    echo "ERROR: Debian installation required."
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

LEONARDO_HOME=$(getent passwd "$LEONARDO_USER" | cut -d: -f6)
LEONARDO_GROUP=$(id -gn "$LEONARDO_USER")

if [[ -z "$LEONARDO_HOME" || ! -d "$LEONARDO_HOME" ]]; then
    echo "ERROR: Leonardo home directory not found."
    exit 1
fi

echo "Target user: $LEONARDO_USER"
echo "Home:        $LEONARDO_HOME"

# --------------------------------------------------
# 2. Install desktop packages
# --------------------------------------------------

echo
echo "[1/6] Installing desktop packages..."

apt-get update

apt-get install -y \
    xorg \
    x11-xserver-utils \
    xfce4 \
    xfce4-goodies \
    xfce4-screenshooter \
    xfce4-power-manager \
    xfce4-screensaver \
    lightdm \
    firefox-esr \
    kodi \
    openssh-server \
    cec-utils

# --------------------------------------------------
# 3. Remove competing screen locker
# --------------------------------------------------

echo
echo "[2/6] Removing light-locker..."

if dpkg -s light-locker >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive \
        apt-get purge -y light-locker
else
    echo "light-locker not installed."
fi

# --------------------------------------------------
# 4. Configure LightDM automatic login
# --------------------------------------------------

echo
echo "[3/6] Configuring LightDM..."

install -d /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/50-leonardo.conf <<EOF
[Seat:*]
autologin-user=${LEONARDO_USER}
autologin-user-timeout=0
user-session=xfce
EOF

# --------------------------------------------------
# 5. Configure Leonardo XFCE settings
# --------------------------------------------------

echo
echo "[4/6] Configuring XFCE..."

XFCE_CONFIG="${LEONARDO_HOME}/.config/xfce4"

SCREENSAVER_CONFIG="${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml"

POWER_CONFIG="${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    "$(dirname "$SCREENSAVER_CONFIG")"

# --------------------------------------------------
# XFCE Screensaver
# --------------------------------------------------
#
# Keep screensaver functionality.
# Disable screen locking and password challenges.
#
# /lock/enabled = false
#

cat > "$SCREENSAVER_CONFIG" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
EOF

# --------------------------------------------------
# XFCE Power Manager
# --------------------------------------------------
#
# Retain display power management.
# Do not lock the screen when the display wakes.
#
# /xfce4-power-manager/lock-screen = false
#

cat > "$POWER_CONFIG" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="lock-screen" type="bool" value="false"/>
  </property>
</channel>
EOF

chown -R \
    "$LEONARDO_USER:$LEONARDO_GROUP" \
    "$XFCE_CONFIG"

# --------------------------------------------------
# 6. Configure display startup and services
# --------------------------------------------------

echo
echo "[5/6] Configuring desktop startup..."

AUTOSTART_DIR="${LEONARDO_HOME}/.config/autostart"

install -d \
    -o "$LEONARDO_USER" \
    -g "$LEONARDO_GROUP" \
    "$AUTOSTART_DIR"

# Display configuration.
# Leave screen blanking and DPMS under XFCE power manager control.

cat > "${AUTOSTART_DIR}/dv-display-settings.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=DV Display Settings
Comment=Display configuration
Exec=xset s on
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

chown "$LEONARDO_USER:$LEONARDO_GROUP" \
    "${AUTOSTART_DIR}/dv-display-settings.desktop"

chmod 644 \
    "${AUTOSTART_DIR}/dv-display-settings.desktop"

# --------------------------------------------------
# Enable required services
# --------------------------------------------------

echo
echo "[6/6] Enabling services..."

systemctl enable ssh
systemctl enable lightdm

systemctl set-default graphical.target



# --------------------------------------------------
# Completion
# --------------------------------------------------

echo
echo "=========================================="
echo " Desktop installation complete"
echo "=========================================="
echo
echo "Desktop:"
echo "  XFCE4"
echo
echo "Display manager:"
echo "  LightDM"
echo
echo "Automatic login:"
echo "  $LEONARDO_USER"
echo
echo "Screensaver:"
echo "  Installed"
echo
echo "Screen locking:"
echo "  Disabled"
echo
echo "light-locker:"
echo "  Removed"
echo
echo "Display power management:"
echo "  Retained"
echo
echo "Applications:"
echo "  Firefox ESR"
echo
echo "Services:"
echo "  SSH enabled"
echo "  LightDM enabled"
echo
echo "HDMI-CEC:"
echo "  cec-utils installed"
echo
echo "=========================================="
echo " Reboot recommended"
echo "=========================================="
