#!/usr/bin/env bash
# Installer for zenbook-duo-ux8406ma-screen-fix.
# Copies `duo` to /usr/local/bin and sets up an autostart entry for the current user.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOSTART_DIR="$HOME/.config/autostart"
USER_UNIT_DIR="$HOME/.config/systemd/user"

echo "Installing /usr/local/bin/duo and /usr/local/bin/duo-screen-toggle (sudo required)..."
sudo install -m 755 -o root -g root "$SCRIPT_DIR/duo" /usr/local/bin/duo
sudo install -m 755 -o root -g root "$SCRIPT_DIR/duo-screen-toggle" /usr/local/bin/duo-screen-toggle

echo "Adding autostart entry at $AUTOSTART_DIR/zenbook-duo-helper.desktop..."
mkdir -p "$AUTOSTART_DIR"
cp "$SCRIPT_DIR/zenbook-duo-helper.desktop" "$AUTOSTART_DIR/zenbook-duo-helper.desktop"

echo "Installing screen-toggle button user service at $USER_UNIT_DIR/duo-screen-toggle.service..."
mkdir -p "$USER_UNIT_DIR"
install -m 644 "$SCRIPT_DIR/duo-screen-toggle.service" "$USER_UNIT_DIR/duo-screen-toggle.service"
systemctl --user daemon-reload
systemctl --user enable --now duo-screen-toggle.service

echo
echo "Installed. Either log out and back in, or run:"
echo "  /usr/local/bin/duo watch-displays &"
echo "to start the keyboard-attach helper now without restarting your session."
echo "The screen-toggle button handler is already running via systemd."
