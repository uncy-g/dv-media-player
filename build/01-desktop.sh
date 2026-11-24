
#!/bin/bash
#
# i-fi.tv - Desktop and core media applications
#
# Target: Debian 13 (Trixie)
# Desktop: XFCE
# Display manager: LightDM
# User: leonardo
#
# This script must be executable over SSH.
# No active graphical session is required.
#

set -euo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

PLAYER_USER="leonardo"
PLAYER_HOME="/home/${PLAYER_USER}"

XFCE_CONFIG="${PLAYER_HOME}/.config/xfce4"
AUTOSTART="${PLAYER_HOME}/.config/autostart"

echo "======================================"
echo " i-fi.tv Desktop Installation"
echo "======================================"

# --------------------------------------------------
# Validate operating system
# --------------------------------------------------

source /etc/os-release

if [[ "$ID" != "debian" || "$VERSION_CODENAME" != "trixie" ]]; then
    echo "ERROR: Debian 13 Trixie required."
    exit 1
fi

# --------------------------------------------------
# Validate user
# --------------------------------------------------

if ! id "$PLAYER_USER" >/dev/null 2>&1; then
    echo "ERROR: User ${PLAYER_USER} does not exist."
    exit 1
fi

# --------------------------------------------------
# Install desktop and media components
# --------------------------------------------------

echo "Installing desktop components..."

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xorg \
    x11-xserver-utils \
    xfce4 \
    xfce4-screenshooter \
    xfce4-power-manager \
    xfce4-screensaver \
    lightdm \
    firefox-esr \
    kodi \
    openssh-server \
    cec-utils

# --------------------------------------------------
# Configure automatic login
# --------------------------------------------------

echo "Configuring LightDM..."

mkdir -p /etc/lightdm/lightdm.conf.d

cat > /etc/lightdm/lightdm.conf.d/50-dv-media-player.conf <<EOF
[Seat:*]
autologin-user=${PLAYER_USER}
autologin-user-timeout=0
autologin-session=xfce
EOF

# --------------------------------------------------
# Configure XFCE appliance behaviour
# --------------------------------------------------

echo "Configuring XFCE..."

mkdir -p \
    "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml" \
    "${AUTOSTART}"

# Disable screensaver and locking

cat > "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
    <property name="saver" type="empty">
        <property name="enabled" type="bool" value="false"/>
    </property>
    <property name="lock" type="empty">
        <property name="enabled" type="bool" value="false"/>
    </property>
</channel>
EOF

# Disable power-manager blanking and locking

cat > "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
    <property name="lock-screen" type="bool" value="false"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
</channel>
EOF

# Disable X11 screen blanking and DPMS at session startup

cat > "${AUTOSTART}/dv-display-settings.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=DV Display Settings
Comment=Disable display blanking for media player
Exec=xset s off -dpms s noblank
Terminal=false
EOF

# --------------------------------------------------
# Set ownership
# --------------------------------------------------

chown -R "${PLAYER_USER}:${PLAYER_USER}" \
    "${PLAYER_HOME}/.config"

# --------------------------------------------------
# Enable system services
# --------------------------------------------------

echo "Enabling system services..."

systemctl enable ssh
systemctl enable lightdm

systemctl set-default graphical.target

# --------------------------------------------------
# Complete
# --------------------------------------------------

echo
echo "======================================"
echo " Desktop installation complete"
echo "======================================"
echo
echo "Operating system : Debian Trixie"
echo "Desktop          : XFCE"
echo "Display manager  : LightDM"
echo "Automatic login  : ${PLAYER_USER}"
echo "Screensaver      : Disabled"
echo "Screen locking   : Disabled"
echo "Display blanking : Disabled"
echo "SSH              : Enabled"
echo
echo "Reboot required to apply all settings."
echo
