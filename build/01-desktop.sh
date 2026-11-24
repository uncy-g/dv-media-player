
#!/bin/bash
#
# i-fi.tv - Desktop and core media applications
# Debian 13 Trixie
#
# User: leonardo
#

set -e

PLAYER_USER="leonardo"

echo "======================================"
echo " i-fi.tv Desktop Installation"
echo "======================================"

# Install desktop and media components

sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xorg \
    xfce4 \
    xfce4-screenshooter \
    xfce4-power-manager \
    lightdm \
    firefox-esr \
    kodi \
    openssh-server \
    cec-utils

# Configure automatic login

sudo mkdir -p /etc/lightdm/lightdm.conf.d

sudo tee /etc/lightdm/lightdm.conf.d/50-dv-media-player.conf \
    > /dev/null <<EOF
[Seat:*]
autologin-user=${PLAYER_USER}
autologin-user-timeout=0
autologin-session=xfce
EOF

# Configure XFCE appliance behaviour

echo "Configuring screensaver and power management..."

sudo -u "$PLAYER_USER" xfconf-query \
    -c xfce4-screensaver \
    -p /saver/enabled --create -t bool -s false

sudo -u "$PLAYER_USER" xfconf-query \
    -c xfce4-screensaver \
    -p /lock/enabled --create -t bool -s false

sudo -u "$PLAYER_USER" xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/lock-screen \
    --create -t bool -s false

sudo -u "$PLAYER_USER" xfconf-query \
    -c xfce4-power-manager \
    -p /xfce4-power-manager/blank-on-ac \
    --create -t int -s 0

# Disable DPMS and X screen blanking

sudo -u "$PLAYER_USER" mkdir -p \
    "/home/${PLAYER_USER}/.config/autostart"

sudo tee \
    "/home/${PLAYER_USER}/.config/autostart/dv-display-settings.desktop" \
    > /dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=DV Display Settings
Exec=xset s off -dpms s noblank
Terminal=false
EOF

sudo chown -R "${PLAYER_USER}:${PLAYER_USER}" \
    "/home/${PLAYER_USER}/.config"

# Enable services

sudo systemctl enable ssh
sudo systemctl enable lightdm

# Use graphical boot

sudo systemctl set-default graphical.target

echo
echo "======================================"
echo " Desktop installation complete"
echo "======================================"
echo "Automatic login: ${PLAYER_USER}"
echo "Screensaver: disabled"
echo "Screen locking: disabled"
echo "Display blanking: disabled"
echo
