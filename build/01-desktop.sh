
#!/bin/bash
#
# i-fi.tv - Media Player
# 01 - Desktop and core media applications
#
# Target: Debian 13 Trixie
# User: leonardo
#

set -e

echo "======================================"
echo " i-fi.tv Desktop Installation"
echo "======================================"

# Install desktop and media components

sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xorg \
    xfce4 \
    lightdm \
    firefox-esr \
    kodi \
    openssh-server \
    cec-utils

# Configure LightDM automatic login

sudo mkdir -p /etc/lightdm/lightdm.conf.d

sudo tee /etc/lightdm/lightdm.conf.d/50-dv-media-player.conf \
    > /dev/null <<'EOF'
[Seat:*]
autologin-user=leonardo
autologin-user-timeout=0
autologin-session=xfce
EOF

# Enable services

sudo systemctl enable ssh
sudo systemctl enable lightdm

# Use graphical boot

sudo systemctl set-default graphical.target

echo
echo "Desktop installation complete."
echo "Automatic login configured for leonardo."
echo "Reboot to start XFCE."
