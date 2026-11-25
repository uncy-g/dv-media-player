
#!/bin/bash
#
# i-fi.tv - Unified Remote Server
# Debian 13 Trixie / AMD64
#

set -e

echo "======================================"
echo " Installing Unified Remote Server"
echo "======================================"

# Verify architecture
ARCH=$(dpkg --print-architecture)

if [[ "$ARCH" != "amd64" ]]; then
    echo "ERROR: This installer currently targets AMD64."
    exit 1
fi

# Install prerequisites
echo "Installing prerequisites..."

sudo apt-get update
sudo apt-get install -y curl ca-certificates

# Download Unified Remote
echo "Downloading Unified Remote..."

curl -fL \
    https://www.unifiedremote.com/d/linux-x64-deb \
    -o /tmp/urserver.deb

# Install package
echo "Installing Unified Remote package..."

sudo apt-get install -y /tmp/urserver.deb

# Remove downloaded package
rm -f /tmp/urserver.deb

# Configure desktop autostart
echo "Configuring Unified Remote autostart..."

mkdir -p "$HOME/.config/autostart"

cp /opt/urserver/urserver-autostart.desktop \
   "$HOME/.config/autostart/urserver.desktop"

# Complete
echo
echo "======================================"
echo " Unified Remote installation complete"
echo "======================================"
echo
echo "Installation directory: /opt/urserver"
echo "Autostart:              $HOME/.config/autostart/urserver.desktop"
echo "Web manager:            http://localhost:9510/web"
echo
echo "Unified Remote will start automatically"
echo "when the Leonardo desktop session starts."
