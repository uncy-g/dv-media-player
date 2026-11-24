# --------------------------------------------------
# Configure Chrome for automatic-login environments
# --------------------------------------------------

echo "Configuring Chrome password store..."

CHROME_DESKTOP="/usr/share/applications/google-chrome.desktop"

if [[ -f "$CHROME_DESKTOP" ]]; then
    # Add basic password store to every Chrome launcher entry.
    # This prevents Chrome requesting GNOME Keyring unlock.

    sed -i \
        '/^Exec=/ {
            /--password-store=basic/! s|^\(Exec=[^ ]*\)|\1 --password-store=basic|
        }' "$CHROME_DESKTOP"

    echo "Chrome configured to use basic password storage."
else
    echo "WARNING: Chrome desktop launcher not found."
fi

# Refresh desktop application database if available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications
fi