# zenbook-duo-ux8406ma-screen-fix

Dual-screen and dual-touchscreen helper for the **ASUS Zenbook Duo (UX8406MA)** on **Linux Mint (Cinnamon, X11)**.

- Detach the keyboard → both screens turn on, stacked vertically.
- Attach the keyboard → bottom screen turns off, top screen becomes primary.
- Touch always lands on the screen you actually touched, in either mode.
- **Press the dedicated dual-screen button (right of F12) → toggles the bottom screen on/off.**
- F5 / F6 on the magnetic keyboard dim/brighten both screens (and external keyboards keep F5/F6 as F5/F6).
- The Cinnamon brightness slider also dims both screens together.
- F8 on the magnetic keyboard moves every application window to the opposite physical screen.

## Install

```bash
sudo apt install x11-xserver-utils xinput inotify-tools usbutils python3-evdev
git clone https://github.com/nrebolloso/zenbook-duo-ux8406ma-screen-fix.git
cd zenbook-duo-ux8406ma-screen-fix
./install.sh
```

The installer puts `duo`, `duo-screen-toggle`, `duo-brightness-sync`, and `duo-swap-monitor` in `/usr/local/bin`, adds an autostart entry for `duo watch-displays`, enables `duo-screen-toggle.service` as a systemd user unit, enables `duo-brightness-sync.service` as a systemd system unit, installs the udev keyboard remap, and adds a Cinnamon custom keybinding so F8 (remapped to `XF86Launch1` on the magnetic keyboard) runs `duo-swap-monitor`. Log out and back in (or run `/usr/local/bin/duo watch-displays &`) to start the keyboard-attach helper. The button handler and brightness sync are already running after install.

## Manual commands

```bash
duo top      # top screen only
duo both     # both screens stacked
duo normal   # auto-detect from keyboard state
```

```bash
systemctl --user status duo-screen-toggle.service
journalctl --user -u duo-screen-toggle.service -f
```

## How the screen-toggle button works

The button right of F12 on the detachable keyboard is the dual-screen toggle (same physical button Windows' MyASUS uses for "ScreenXpert"). It does **not** emit a normal key event — it shows up as `EV_ABS code=ABS_MISC (40) value=106` on one of the BT keyboard's `/dev/input/event*` nodes. Because no keysym is ever produced, Cinnamon's keyboard-shortcut UI can't see it and `xev` won't catch it either.

`duo-screen-toggle` is a small Python/evdev daemon that opens every input device named `ASUS Zenbook Duo Keyboard` with `ABS_MISC` capability, watches for value `106`, and calls `duo top` or `duo both` based on the current `xrandr` state. It rescans when the BT keyboard reconnects.

## How brightness sync works

The Fn brightness keys and Cinnamon's brightness slider only write to `/sys/class/backlight/intel_backlight/brightness` (the top panel). The bottom panel exposes a separate sysfs entry — `/sys/class/backlight/card1-eDP-2-backlight/brightness` — which nothing writes to by default, so the bottom screen stays pinned at 100%.

`duo-brightness-sync` is a tiny bash daemon that watches `intel_backlight/brightness` with `inotifywait` and copies each new value (scaled by `max_brightness`) to `card1-eDP-2-backlight`. It is enabled as a system unit so it starts at boot and survives screen-toggle events; when `duo top` removes the eDP-2 backlight node, the daemon blocks until it reappears.

```bash
systemctl status duo-brightness-sync.service
journalctl -u duo-brightness-sync.service -f
```

There is also an `asus_screenpad` backlight node exposed by `asus-nb-wmi` on this hardware, but it doesn't actually control the UX8406MA's bottom OLED — `card1-eDP-2-backlight` is the one that works.

## How F8 swaps windows between the two screens

The magnetic keyboard's F8 is remapped via udev hwdb to `KEY_PROG1` (X11 keysym `XF86Launch1`), and a Cinnamon custom keybinding runs `/usr/local/bin/duo-swap-monitor` whenever that keysym fires. The script enumerates every normal window with `wmctrl -lG`, decides which physical panel each one is on by comparing its vertical midpoint to `eDP-2`'s Y offset from `xrandr`, and shifts it across the boundary with `wmctrl -e`. Maximized windows are temporarily unmaximized, moved, then re-maximized so they re-snap to the new screen.

`wmctrl -e` accepts frame coordinates while `wmctrl -lG` reports the client position, so the script offsets the sent coordinates by `_NET_FRAME_EXTENTS` + the client's relative offset within its frame to land windows exactly where they should. Desktop, dock, splash, and other non-normal windows (including the Cinnamon panel) are skipped — only application windows move. In `duo top` mode the swap is a no-op because only one panel is active.

The script intentionally does not change `xrandr --primary` or any monitor positions. In testing, doing so triggered Cinnamon's auto-window-relocation in a way that raced against the `wmctrl` moves and ended up reverting them. Keeping monitor topology constant makes the swap reliable on every press.

The remap is scoped to the magnetic keyboard's USB/Bluetooth IDs, so F8 on external keyboards still produces a normal F8.

## How F5 / F6 become brightness keys

The detachable magnetic keyboard's firmware doesn't translate Fn+F5 / Fn+F6 to brightness keysyms — Fn is local and emits nothing on the F-row, so the keys always come through as plain `KEY_F5` / `KEY_F6`. Cinnamon's brightness bindings listen for `XF86MonBrightnessUp/Down`, so by default the brightness keys appear dead.

`61-zenbook-duo-keyboard.hwdb` is a udev keyboard remap that rewrites the scancodes `0x7003e` (F5) and `0x7003f` (F6) to `brightnessdown` / `brightnessup` — but only on the keyboard with USB ID `0B05:1B2C` (docked) or Bluetooth ID `0B05:1B2D` (detached). External keyboards keep F5/F6 as F5/F6.

The installer runs `systemd-hwdb update` and `udevadm trigger` to apply the map without a reboot. If brightness keys still don't respond after install, unplug/replug the keyboard (or toggle Bluetooth) so it gets re-evaluated against the new hwdb.

## Scope

UX8406MA on X11. Wayland is not supported (`xinput`/`xrandr` are X-only). For non-3K variants, edit `RESOLUTION`/`RATE` at the top of `duo`.

## Credits

Concept inspired by the GNOME-targeted [zenbook-duo-2024-ux8406ma-linux](https://github.com/alesya-h/zenbook-duo-2024-ux8406ma-linux) by Alesya Huzik.

## License

MIT.
