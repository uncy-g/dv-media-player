
#!/bin/bash
#
# i-fi.tv - Unified Remote Server
# Debian 13 Trixie / AMD64
#

set -e

echo "Installing Unified Remote Server..."

ARCH=$(dpkg --print-architecture)

if [[ "$ARCH" != "amd64" ]]; then
    echo "ERROR: This installer currently targets AMD64."
    exit 1
fi

sudo apt-get update
sudo apt-get install -y curl ca-certificates

curl -fL \
    https://www.unifiedremote.com/d/linux-x64-deb \
    -o /tmp/urserver.deb

sudo apt-get install -y /tmp/urserver.deb

rm -f /tmp/urserver.deb

echo
echo "Unified Remote installation complete."
echo "Installation directory: /opt/urserver"
echo "Web manager: http://localhost:9510/web"
