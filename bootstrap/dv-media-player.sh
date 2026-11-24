
#!/bin/bash
#
# i-fi.tv - dv-media-player
# Initial deployment bootstrap
#
# Target: Debian 13 (Trixie)
# User:   leonardo
#

set -e

GITHUB="uncy-g"
BRANCH="main"
BASE="/opt/dv"

echo "======================================"
echo " i-fi.tv Media Player Bootstrap"
echo "======================================"

# Check Debian
source /etc/os-release

if [[ "$ID" != "debian" || "$VERSION_CODENAME" != "trixie" ]]; then
    echo "ERROR: Debian 13 Trixie required."
    exit 1
fi

# Check user
if [[ "$(whoami)" != "leonardo" ]]; then
    echo "ERROR: Run this script as leonardo."
    exit 1
fi

echo "Installing prerequisites..."

sudo apt-get update
sudo apt-get install -y git ca-certificates

# Create filesystem structure
echo "Creating filesystem structure..."

sudo mkdir -p \
    "$BASE/bootstrap" \
    "$BASE/share/applications" \
    "$BASE/share/icons/hicolor" \
    "$BASE/etc/dv-media-player"

sudo mkdir -p \
    /usr/local/sbin \
    /home/leonardo/sbin \
    /home/leonardo/bin

# Allow Leonardo to maintain Git checkouts
sudo chown leonardo:leonardo "$BASE/bootstrap"

# Clone repositories
echo "Retrieving GitHub repositories..."

for REPO in dv-media-player dv-media-players
do
    DEST="$BASE/bootstrap/$REPO"

    if [ -d "$DEST/.git" ]; then
        echo "$REPO already exists - skipping"
    elif [ -e "$DEST" ]; then
        echo "ERROR: $DEST exists but is not a Git repository."
        exit 1
    else
        echo "Cloning $REPO..."

        git clone \
            --branch "$BRANCH" \
            "https://github.com/$GITHUB/$REPO.git" \
            "$DEST"
    fi
done

echo
echo "======================================"
echo " Bootstrap completed successfully"
echo "======================================"
echo
echo "Repositories: $BASE/bootstrap"
