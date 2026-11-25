
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

# Default hostname
PLAYER_HOSTNAME="dv-media-player"

# Process command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hostname)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --hostname requires a value."
                exit 1
            fi
            PLAYER_HOSTNAME="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--hostname HOSTNAME]"
            echo "Default hostname: dv-media-player"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown parameter: $1"
            echo "Usage: $0 [--hostname HOSTNAME]"
            exit 1
            ;;
    esac
done

# Validate hostname (RFC-compatible static hostname)
if [[ ${#PLAYER_HOSTNAME} -gt 63 ]] ||
   [[ ! "$PLAYER_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
    echo "ERROR: Invalid hostname: $PLAYER_HOSTNAME"
    echo "Use letters, numbers and hyphens."
    exit 1
fi

echo "======================================"
echo " i-fi.tv Media Player Bootstrap"
echo "======================================"
echo
echo "Hostname: $PLAYER_HOSTNAME"
echo

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

# Configure system hostname
echo "Configuring hostname..."

sudo hostnamectl set-hostname "$PLAYER_HOSTNAME"

# Update /etc/hosts
if grep -qE '^127\.0\.1\.1[[:space:]]' /etc/hosts; then
    sudo sed -i -E \
        "/^127\\.0\\.1\\.1[[:space:]]/c\\127.0.1.1\\t$PLAYER_HOSTNAME" \
        /etc/hosts
else
    echo -e "127.0.1.1\t$PLAYER_HOSTNAME" |
        sudo tee -a /etc/hosts > /dev/null
fi

echo "Hostname configured: $(hostnamectl --static)"

# Install prerequisites
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
echo "Hostname:    $(hostnamectl --static)"
echo "Repositories: $BASE/bootstrap"
