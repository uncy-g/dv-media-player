
#!/bin/bash
#
# i-fi.tv - Streaming Application Support
# Debian 13 Trixie
#
# Netflix kiosk launcher installation.
#
# Core repository:
#   build/06-streaming.sh
#
# Application repository:
#   streaming/icons/GL-netflix.ico
#   streaming/launchers/GL-netflix.desktop
#
# Installed:
#   /opt/dv/bin/dv-netflix
#   /usr/local/bin/dv-netflix -> /opt/dv/bin/dv-netflix
#   /opt/dv/share/icons/GL-netflix.ico
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
CONFIG="$BASE/etc/dv-media-player"

PLAYER_REPO="$BASE/bootstrap/dv-media-players"
STREAMING="$PLAYER_REPO/streaming"

ICON_SOURCE="$STREAMING/icons/GL-netflix.ico"
DESKTOP_SOURCE="$STREAMING/launchers/GL-netflix.desktop"

ICON_DEST="$SHARE/icons/GL-netflix.ico"
DESKTOP_DEST="/usr/share/applications/GL-netflix.desktop"

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
TARGET_GROUP=$(id -gn "$TARGET_USER")
TARGET_UID=$(id -u "$TARGET_USER")

if [[ -z "$TARGET_HOME" ]]; then
    echo "ERROR: Cannot determine user home."
    exit 1
fi

# --------------------------------------------------
# Verify assets
# --------------------------------------------------

echo
echo "Checking application assets..."

for FILE in "$ICON_SOURCE" "$DESKTOP_SOURCE"; do
    if [[ ! -f "$FILE" ]]; then
        echo "ERROR: Required asset missing:"
        echo "$FILE"
        exit 1
    fi
done

# --------------------------------------------------
# Dependencies
# --------------------------------------------------

echo
echo "Installing dependencies..."

apt-get update

apt-get install -y \
    curl \
    firefox-esr \
    libglib2.0-bin \
    desktop-file-utils \
    x11-xserver-utils

# --------------------------------------------------
# Directories
# --------------------------------------------------

echo
echo "Creating directories..."

install -d -m 755 "$BIN"
install -d -m 755 "$SHARE/icons"
install -d -m 755 "$CONFIG"
install -d -m 755 /usr/share/applications

install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/.config/dv-netflix"

install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/Desktop"

# --------------------------------------------------
# Runtime launcher
# --------------------------------------------------

echo
echo "Installing Netflix runtime..."

cat > "$BIN/dv-netflix" <<'RUNTIME'
#!/bin/bash
#
# i-fi.tv - Netflix Kiosk Launcher
#
# Usage:
#   dv-netflix
#   dv-netflix --browser firefox
#   dv-netflix --screen VGA-1
#   dv-netflix --browser firefox --screen LVDS-1
#   dv-netflix --exec kodi
#

set -e

BROWSER="chrome"
SCREEN=""
EXEC_COMMAND=""

# --------------------------------------------------
# Arguments
# --------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in

        --browser)
            [[ -n "${2:-}" ]] || {
                echo "ERROR: --browser requires a value."
                exit 1
            }
            BROWSER="$2"
            shift 2
            ;;

        --screen)
            [[ -n "${2:-}" ]] || {
                echo "ERROR: --screen requires an XRandR output name."
                exit 1
            }
            SCREEN="$2"
            shift 2
            ;;

        --exec)
            [[ -n "${2:-}" ]] || {
                echo "ERROR: --exec requires a command."
                exit 1
            }
            EXEC_COMMAND="$2"
            shift 2
            ;;

        --help|-h)
            echo "Usage:"
            echo "  dv-netflix [--browser chrome|firefox]"
            echo "             [--screen OUTPUT]"
            echo "             [--exec COMMAND]"
            echo
            echo "Available screens:"
            xrandr --query | grep " connected" || true
            exit 0
            ;;

        *)
            echo "ERROR: Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# --------------------------------------------------
# Resolve selected screen geometry
# --------------------------------------------------

WINDOW_POSITION=""
WINDOW_SIZE=""

if [[ -n "$SCREEN" ]]; then

    if ! command -v xrandr >/dev/null 2>&1; then
        echo "ERROR: xrandr is not installed."
        exit 1
    fi

    SCREEN_INFO=$(xrandr --query |
        awk -v screen="$SCREEN" '
            $1 == screen && $2 == "connected" {
                for (i=3; i<=NF; i++) {
                    if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
                        print $i
                        exit
                    }
                }
            }
        ')

    if [[ -z "$SCREEN_INFO" ]]; then
        echo "ERROR: Screen '$SCREEN' not found or inactive."
        exit 1
    fi

    RESOLUTION="${SCREEN_INFO%%+*}"
    POSITION="${SCREEN_INFO#*+}"

    WIDTH="${RESOLUTION%x*}"
    HEIGHT="${RESOLUTION#*x}"

    XPOS="${POSITION%%+*}"
    YPOS="${POSITION#*+}"

    WINDOW_POSITION="$XPOS,$YPOS"
    WINDOW_SIZE="$WIDTH,$HEIGHT"

    echo "Selected screen: $SCREEN"
    echo "Position: $WINDOW_POSITION"
    echo "Size: $WINDOW_SIZE"

fi

# --------------------------------------------------
# Netflix profile
# --------------------------------------------------

URL="https://www.netflix.com/"

PROFILE="$HOME/.config/dv-netflix"

mkdir -p "$PROFILE"

# --------------------------------------------------
# Launch browser
# --------------------------------------------------

echo
echo "Starting Netflix..."
echo "Browser: $BROWSER"

case "$BROWSER" in

    chrome)

        BROWSER_BIN=$(command -v google-chrome || \
                      command -v google-chrome-stable || true)

        if [[ -z "$BROWSER_BIN" ]]; then
            echo "ERROR: Google Chrome is not installed."
            exit 1
        fi

        CHROME_ARGS=(
            --kiosk
            --no-first-run
            --disable-session-crashed-bubble
            --user-data-dir="$PROFILE/chrome"
        )

        if [[ -n "$WINDOW_POSITION" ]]; then
            CHROME_ARGS+=("--window-position=$WINDOW_POSITION")
            CHROME_ARGS+=("--window-size=$WINDOW_SIZE")
        fi

        "$BROWSER_BIN" "${CHROME_ARGS[@]}" "$URL"

        ;;

    firefox)

        BROWSER_BIN=$(command -v firefox-esr || true)

        if [[ -z "$BROWSER_BIN" ]]; then
            echo "ERROR: Firefox ESR is not installed."
            exit 1
        fi

        FIREFOX_ARGS=(
            --no-remote
            --profile "$PROFILE/firefox"
            --kiosk
        )

        if [[ -n "$WINDOW_POSITION" ]]; then
            FIREFOX_ARGS+=("--width=$WIDTH")
            FIREFOX_ARGS+=("--height=$HEIGHT")
        fi

        "$BROWSER_BIN" "${FIREFOX_ARGS[@]}" "$URL"

        ;;

    *)

        echo "ERROR: Unsupported browser: $BROWSER"
        echo "Supported: chrome, firefox"
        exit 1

        ;;

esac

# --------------------------------------------------
# Browser closed
# --------------------------------------------------

echo
echo "Netflix browser closed."

# --------------------------------------------------
# Optional return command
# --------------------------------------------------

if [[ -n "$EXEC_COMMAND" ]]; then
    echo "Executing: $EXEC_COMMAND"
    bash -lc "$EXEC_COMMAND"
fi

echo "Netflix launcher finished."
RUNTIME

chmod 755 "$BIN/dv-netflix"

# System-wide command
ln -sfn "$BIN/dv-netflix" /usr/local/bin/dv-netflix

# --------------------------------------------------
# Install icon
# --------------------------------------------------

echo
echo "Installing Netflix icon..."

install -m 644 "$ICON_SOURCE" "$ICON_DEST"

# --------------------------------------------------
# Install desktop application
# --------------------------------------------------

echo
echo "Installing desktop application..."

install -m 644 "$DESKTOP_SOURCE" "$DESKTOP_DEST"

desktop-file-validate "$DESKTOP_DEST"

# --------------------------------------------------
# Desktop shortcut
# --------------------------------------------------

echo
echo "Installing desktop shortcut..."

DESKTOP_SHORTCUT="$TARGET_HOME/Desktop/GL-netflix.desktop"

install -m 755 "$DESKTOP_SOURCE" "$DESKTOP_SHORTCUT"

chown "$TARGET_USER:$TARGET_GROUP" "$DESKTOP_SHORTCUT"

# --------------------------------------------------
# XFCE trust metadata
# --------------------------------------------------

echo
echo "Configuring XFCE desktop trust..."

runuser -u "$TARGET_USER" -- \
    gio set "$DESKTOP_SHORTCUT" metadata::trusted true

CHECKSUM=$(sha256sum "$DESKTOP_SHORTCUT" | awk '{print $1}')

runuser -u "$TARGET_USER" -- \
    gio set -t string "$DESKTOP_SHORTCUT" \
    metadata::xfce-exe-checksum "$CHECKSUM"

# --------------------------------------------------
# Desktop database
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
echo "Configuration: $CONFIG"
echo "Icon:          $ICON_DEST"
echo "Application:   $DESKTOP_DEST"
echo "Shortcut:      $DESKTOP_SHORTCUT"
echo
echo "Examples:"
echo "  dv-netflix"
echo "  dv-netflix --screen VGA-1"
echo "  dv-netflix --browser firefox --screen LVDS-1"
echo "  dv-netflix --exec kodi"
echo
