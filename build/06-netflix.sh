
#!/bin/bash
#
# i-fi.tv - Netflix Kiosk
# Debian 13 Trixie
#

set -e

echo "======================================"
echo " Installing Netflix Kiosk"
echo "======================================"

# Identify target desktop user
TARGET_USER="${SUDO_USER:-leonardo}"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: User $TARGET_USER does not exist."
    exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_GROUP=$(id -gn "$TARGET_USER")

if [[ -z "$TARGET_HOME" ]]; then
    echo "ERROR: Could not determine user home."
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this build script using sudo."
    exit 1
fi

# Install Firefox ESR
echo "Installing Firefox ESR..."

apt-get update
apt-get install -y firefox-esr

# Create directories
echo "Creating directories..."

install -d -m 755 /usr/local/bin
install -d -m 755 /usr/share/applications
install -d -m 755 /usr/share/icons/hicolor/scalable/apps

install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/.config/dv-netflix"

install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/Desktop"

# Install runtime launcher
echo "Installing dv-netflix..."

cat > /usr/local/bin/dv-netflix <<'RUNTIME'
#!/bin/bash
#
# i-fi.tv - Netflix Kiosk Launcher
#

set -e

BROWSER="chrome"
EXEC_COMMAND=""

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
        --exec)
            [[ -n "${2:-}" ]] || {
                echo "ERROR: --exec requires a command."
                exit 1
            }
            EXEC_COMMAND="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: dv-netflix [--browser chrome|firefox] [--exec COMMAND]"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown parameter: $1"
            exit 1
            ;;
    esac
done

URL="https://www.netflix.com/"

case "$BROWSER" in
    chrome)
        BROWSER_BIN=$(command -v google-chrome || \
                      command -v google-chrome-stable || true)

        if [[ -z "$BROWSER_BIN" ]]; then
            echo "ERROR: Google Chrome is not installed."
            exit 1
        fi

        PROFILE="$HOME/.config/dv-netflix/chrome-profile"
        mkdir -p "$PROFILE"

        "$BROWSER_BIN" \
            --kiosk \
            --no-first-run \
            --disable-session-crashed-bubble \
            --user-data-dir="$PROFILE" \
            "$URL"
        ;;

    firefox)
        BROWSER_BIN=$(command -v firefox-esr || true)

        if [[ -z "$BROWSER_BIN" ]]; then
            echo "ERROR: Firefox ESR is not installed."
            exit 1
        fi

        PROFILE="$HOME/.config/dv-netflix/firefox-profile"
        mkdir -p "$PROFILE"

        "$BROWSER_BIN" \
            --no-remote \
            --profile "$PROFILE" \
            --kiosk \
            "$URL"
        ;;

    *)
        echo "ERROR: Unsupported browser: $BROWSER"
        exit 1
        ;;
esac

echo "Netflix browser closed."

if [[ -n "$EXEC_COMMAND" ]]; then
    echo "Executing: $EXEC_COMMAND"
    bash -lc "$EXEC_COMMAND"
fi
RUNTIME

chmod 755 /usr/local/bin/dv-netflix

# Create Netflix icon
echo "Installing Netflix icon..."

cat > /usr/share/icons/hicolor/scalable/apps/dv-netflix.svg <<'ICON'
<svg xmlns="http://www.w3.org/2000/svg"
     width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="40" fill="#151515"/>
  <path d="M65 45 L104 45 L153 180 L153 45 L191 45
           L191 211 L151 211 L103 91 L103 211 L65 211 Z"
        fill="#E50914"/>
  <path d="M65 45 L104 45 L153 211 L114 211 Z"
        fill="#B20710" opacity="0.7"/>
</svg>
ICON

# Create desktop application entry
echo "Creating desktop launcher..."

cat > /usr/share/applications/dv-netflix.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Netflix
Comment=Watch Netflix in kiosk mode
Exec=/usr/local/bin/dv-netflix
Icon=dv-netflix
Terminal=false
Categories=AudioVideo;Video;
StartupNotify=false
DESKTOP

# Create desktop shortcut
cp /usr/share/applications/dv-netflix.desktop \
   "$TARGET_HOME/Desktop/Netflix.desktop"

chown "$TARGET_USER:$TARGET_GROUP" \
    "$TARGET_HOME/Desktop/Netflix.desktop"

chmod 755 "$TARGET_HOME/Desktop/Netflix.desktop"

# Update desktop database if available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications
fi

echo
echo "======================================"
echo " Netflix Kiosk installed successfully"
echo "======================================"
echo
echo "Runtime:   /usr/local/bin/dv-netflix"
echo "Desktop:   $TARGET_HOME/Desktop/Netflix.desktop"
echo "Icon:      dv-netflix"
echo
echo "Default browser: Chrome"
echo "Alternative:     Firefox ESR"
echo
