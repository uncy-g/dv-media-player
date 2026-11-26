
#!/bin/bash
#
# i-fi.tv - Streaming Application Support
# Debian 13 Trixie
#
# Installs the Netflix kiosk launcher.
#
# Core repository:
#   build/06-streaming.sh
#
# Application repository:
#   streaming/icons/GL-netflix.png
#   streaming/launchers/GL-netflix.desktop
#
# Installed:
#   /opt/dv/bin/dv-netflix
#   /usr/local/bin/dv-netflix -> /opt/dv/bin/dv-netflix
#   /opt/dv/share/icons/GL-netflix.png
#   /usr/share/applications/GL-netflix.desktop
#

set -e

echo "======================================"
echo " i-fi.tv - Streaming Applications"
echo "======================================"

# --------------------------------------------------
# Configuration
# --------------------------------------------------

BASE="/opt/dv"
BIN="$BASE/bin"
SHARE="$BASE/share"

PLAYER_REPO="$BASE/bootstrap/dv-media-players"

STREAMING="$PLAYER_REPO/streaming"

ICON_SOURCE="$STREAMING/icons/GL-netflix.png"
DESKTOP_SOURCE="$STREAMING/launchers/GL-netflix.desktop"

ICON_DEST="$SHARE/icons/GL-netflix.png"
DESKTOP_DEST="/usr/share/applications/GL-netflix.desktop"

# Identify desktop user
TARGET_USER="${SUDO_USER:-leonardo}"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script using sudo."
    exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: User $TARGET_USER does not exist."
    exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$TARGET_USER")
TARGET_GROUP=$(id -gn "$TARGET_USER")

if [[ -z "$TARGET_HOME" ]]; then
    echo "ERROR: Cannot determine user home."
    exit 1
fi

# --------------------------------------------------
# Verify application assets
# --------------------------------------------------

echo
echo "Checking application assets..."

for FILE in "$ICON_SOURCE" "$DESKTOP_SOURCE"; do
    if [[ ! -f "$FILE" ]]; then
        echo "ERROR: Required application asset missing:"
        echo "$FILE"
        exit 1
    fi
done

# --------------------------------------------------
# Install dependencies
# --------------------------------------------------

echo
echo "Installing dependencies..."

apt-get update

apt-get install -y \
    firefox-esr \
    libglib2.0-bin \
    desktop-file-utils

# Chrome is installed by 02-chrome.sh.
if ! command -v google-chrome >/dev/null 2>&1 &&
   ! command -v google-chrome-stable >/dev/null 2>&1; then
    echo "WARNING: Google Chrome not detected."
    echo "Chrome will not be available until installed."
fi

# --------------------------------------------------
# Create directories
# --------------------------------------------------

echo
echo "Creating directories..."

install -d -m 755 "$BIN"
install -d -m 755 "$SHARE/icons"
install -d -m 755 /usr/share/applications

install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/.config/dv-netflix"

install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/Desktop"

# --------------------------------------------------
# Install runtime launcher
# --------------------------------------------------

echo
echo "Installing Netflix runtime launcher..."

cat > "$BIN/dv-netflix" <<'RUNTIME'
#!/bin/bash
#
# i-fi.tv - Netflix Kiosk Launcher
#

set -u

BROWSER="chrome"
EXEC_COMMAND=""

# --------------------------------------------------
# Arguments
# --------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in

        --browser)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --browser requires a value."
                exit 1
            fi

            BROWSER="$2"
            shift 2
            ;;

        --exec)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --exec requires a command."
                exit 1
            fi

            EXEC_COMMAND="$2"
            shift 2
            ;;

        --help|-h)
            echo "Usage:"
            echo "  dv-netflix [--browser chrome|firefox] [--exec COMMAND]"
            exit 0
            ;;

        *)
            echo "ERROR: Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# --------------------------------------------------
# Netflix
# --------------------------------------------------

URL="https://www.netflix.com/"

PROFILE="$HOME/.config/dv-netflix"

mkdir -p "$PROFILE"

echo "Starting Netflix..."
echo "Browser: $BROWSER"

# --------------------------------------------------
# Launch browser
# --------------------------------------------------

case "$BROWSER" in

    chrome)

        BROWSER_BIN=$(command -v google-chrome || \
                      command -v google-chrome-stable || true)

        if [[ -z "$BROWSER_BIN" ]]; then
            echo "ERROR: Google Chrome is not installed."
            exit 1
        fi

        "$BROWSER_BIN" \
            --kiosk \
            --no-first-run \
            --disable-session-crashed-bubble \
            --user-data-dir="$PROFILE/chrome" \
            "$URL" || BROWSER_STATUS=$?

        ;;

    firefox)

        BROWSER_BIN=$(command -v firefox-esr || true)

        if [[ -z "$BROWSER_BIN" ]]; then
            echo "ERROR: Firefox ESR is not installed."
            exit 1
        fi

        "$BROWSER_BIN" \
            --no-remote \
            --profile "$PROFILE/firefox" \
            --kiosk \
            "$URL" || BROWSER_STATUS=$?

        ;;

    *)

        echo "ERROR: Unsupported browser: $BROWSER"
        exit 1

        ;;

esac

# --------------------------------------------------
# Browser has exited
# --------------------------------------------------

BROWSER_STATUS=${BROWSER_STATUS:-0}

echo "Netflix browser closed."

# --------------------------------------------------
# Optional return command
# --------------------------------------------------

if [[ -n "$EXEC_COMMAND" ]]; then

    echo "Executing: $EXEC_COMMAND"

    bash -lc "$EXEC_COMMAND"

fi

exit "$BROWSER_STATUS"
RUNTIME

chmod 755 "$BIN/dv-netflix"

# Create system-wide command symlink
ln -sfn "$BIN/dv-netflix" /usr/local/bin/dv-netflix

# --------------------------------------------------
# Install application icon
# --------------------------------------------------

echo
echo "Installing Netflix icon..."

install -m 644 "$ICON_SOURCE" "$ICON_DEST"

# --------------------------------------------------
# Install application launcher
# --------------------------------------------------

echo
echo "Installing desktop application..."

install -m 644 "$DESKTOP_SOURCE" "$DESKTOP_DEST"

# Validate desktop entry
desktop-file-validate "$DESKTOP_DEST"

# Create user's desktop shortcut
DESKTOP_SHORTCUT="$TARGET_HOME/Desktop/GL-netflix.desktop"

install -m 755 "$DESKTOP_SOURCE" "$DESKTOP_SHORTCUT"

chown "$TARGET_USER:$TARGET_GROUP" "$DESKTOP_SHORTCUT"

# --------------------------------------------------
# Trust XFCE desktop launcher
# --------------------------------------------------

echo
echo "Configuring desktop launcher trust..."

gio_cmd=$(command -v gio)

if [[ -n "$gio_cmd" ]]; then

    runuser -u "$TARGET_USER" -- env \
        HOME="$TARGET_HOME" \
        XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$TARGET_UID/bus}" \
        "$gio_cmd" set -t string \
        "$DESKTOP_SHORTCUT" metadata::trusted true

    CHECKSUM=$(sha256sum "$DESKTOP_SHORTCUT" | awk '{print $1}')

    runuser -u "$TARGET_USER" -- env \
        HOME="$TARGET_HOME" \
        XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$TARGET_UID/bus}" \
        "$gio_cmd" set -t string \
        "$DESKTOP_SHORTCUT" metadata::xfce-exe-checksum "$CHECKSUM"

    touch "$DESKTOP_SHORTCUT"

else
    echo "WARNING: gio unavailable; desktop trust not configured."
fi

# --------------------------------------------------
# Update desktop database
# --------------------------------------------------

update-desktop-database /usr/share/applications

# --------------------------------------------------
# Complete
# --------------------------------------------------

echo
echo "======================================"
echo " Streaming installation complete"
echo "======================================"
echo
echo "Runtime:       $BIN/dv-netflix"
echo "Command:       /usr/local/bin/dv-netflix"
echo "Icon:          $ICON_DEST"
echo "Application:   $DESKTOP_DEST"
echo "Shortcut:      $DESKTOP_SHORTCUT"
echo
echo "Default browser: Chrome"
echo "Alternative:     Firefox ESR"
echo
echo "Usage:"
echo "  dv-netflix"
echo "  dv-netflix --browser firefox"
echo "  dv-netflix --exec kodi"
echo
