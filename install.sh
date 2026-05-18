#!/usr/bin/env bash
# Installer for zenbook-duo-ux8406ma-screen-fix.
# Copies `duo` to /usr/local/bin and sets up an autostart entry for the current user.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOSTART_DIR="$HOME/.config/autostart"
USER_UNIT_DIR="$HOME/.config/systemd/user"

echo "Installing /usr/local/bin/duo, duo-screen-toggle, duo-brightness-sync, duo-swap-monitor (sudo required)..."
sudo install -m 755 -o root -g root "$SCRIPT_DIR/duo" /usr/local/bin/duo
sudo install -m 755 -o root -g root "$SCRIPT_DIR/duo-screen-toggle" /usr/local/bin/duo-screen-toggle
sudo install -m 755 -o root -g root "$SCRIPT_DIR/duo-brightness-sync" /usr/local/bin/duo-brightness-sync
sudo install -m 755 -o root -g root "$SCRIPT_DIR/duo-swap-monitor" /usr/local/bin/duo-swap-monitor

echo "Adding autostart entry at $AUTOSTART_DIR/zenbook-duo-helper.desktop..."
mkdir -p "$AUTOSTART_DIR"
cp "$SCRIPT_DIR/zenbook-duo-helper.desktop" "$AUTOSTART_DIR/zenbook-duo-helper.desktop"

echo "Installing screen-toggle button user service at $USER_UNIT_DIR/duo-screen-toggle.service..."
mkdir -p "$USER_UNIT_DIR"
install -m 644 "$SCRIPT_DIR/duo-screen-toggle.service" "$USER_UNIT_DIR/duo-screen-toggle.service"
systemctl --user daemon-reload
systemctl --user enable --now duo-screen-toggle.service

echo "Installing brightness-sync system service..."
sudo install -m 644 -o root -g root "$SCRIPT_DIR/duo-brightness-sync.service" /etc/systemd/system/duo-brightness-sync.service
sudo systemctl daemon-reload
sudo systemctl enable --now duo-brightness-sync.service

echo "Installing udev keyboard remap (F5/F6 -> brightness, F8 -> XF86Launch1 on the magnetic keyboard)..."
sudo install -m 644 -o root -g root "$SCRIPT_DIR/61-zenbook-duo-keyboard.hwdb" /etc/udev/hwdb.d/61-zenbook-duo-keyboard.hwdb
sudo systemd-hwdb update
sudo udevadm trigger --subsystem-match=input --action=change

echo "Configuring Cinnamon keybinding: F8 (XF86Launch1) -> duo-swap-monitor..."
SWAP_CMD="/usr/local/bin/duo-swap-monitor"
SWAP_BIND="XF86Launch1"
SWAP_NAME="Swap All Windows Between Screens (Zenbook Duo)"
LIST_RAW=$(gsettings get org.cinnamon.desktop.keybindings custom-list 2>/dev/null || echo "@as []")
SLOTS=()
if [[ "$LIST_RAW" =~ \[(.*)\] ]]; then
  while IFS= read -r item; do
    item=$(echo "$item" | tr -d " '")
    [ -n "$item" ] && SLOTS+=("$item")
  done < <(echo "${BASH_REMATCH[1]}" | tr ',' '\n')
fi
EXISTING_SLOT=""
for slot in "${SLOTS[@]}"; do
  schema_path="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$slot/"
  cur_cmd=$(gsettings get "$schema_path" command 2>/dev/null | sed "s/^'//;s/'$//")
  if [ "$cur_cmd" = "$SWAP_CMD" ]; then
    EXISTING_SLOT="$slot"
    break
  fi
done
if [ -z "$EXISTING_SLOT" ]; then
  n=0
  while printf '%s\n' "${SLOTS[@]}" | grep -qx "custom$n"; do n=$((n+1)); done
  EXISTING_SLOT="custom$n"
  if [ ${#SLOTS[@]} -eq 0 ]; then
    NEW_LIST="['$EXISTING_SLOT']"
  else
    JOINED=""
    for s in "${SLOTS[@]}"; do JOINED+="'$s', "; done
    JOINED+="'$EXISTING_SLOT'"
    NEW_LIST="[$JOINED]"
  fi
  gsettings set org.cinnamon.desktop.keybindings custom-list "$NEW_LIST"
fi
SCHEMA_PATH="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$EXISTING_SLOT/"
gsettings set "$SCHEMA_PATH" name "$SWAP_NAME"
gsettings set "$SCHEMA_PATH" binding "['$SWAP_BIND']"
gsettings set "$SCHEMA_PATH" command "$SWAP_CMD"
echo "  -> using $EXISTING_SLOT"

echo
echo "Installed. Either log out and back in, or run:"
echo "  /usr/local/bin/duo watch-displays &"
echo "to start the keyboard-attach helper now without restarting your session."
echo "The screen-toggle button handler and brightness-sync are already running via systemd."
