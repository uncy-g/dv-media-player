
#!/bin/bash
#
# i-fi.tv - Google Chrome installation
# Debian 13 Trixie
#

set -e

echo "Installing Google Chrome..."

sudo apt-get update
sudo apt-get install -y wget ca-certificates

wget -q -O /tmp/google-chrome.gpg \
    https://dl.google.com/linux/linux_signing_key.pub

sudo gpg --dearmor --yes \
    -o /usr/share/keyrings/google-chrome.gpg \
    /tmp/google-chrome.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    | sudo tee /etc/apt/sources.list.d/google-chrome.list

sudo apt-get update
sudo apt-get install -y google-chrome-stable

echo "Google Chrome installation complete."

google-chrome --version
