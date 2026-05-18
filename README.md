# zenbook-duo-ux8406ma-screen-fix

Dual-screen and dual-touchscreen helper for the **ASUS Zenbook Duo (UX8406MA)** on **Linux Mint (Cinnamon, X11)**.

- Detach the keyboard → both screens turn on, stacked vertically.
- Attach the keyboard → bottom screen turns off, top screen becomes primary.
- Touch always lands on the screen you actually touched, in either mode.
- **Press the dedicated dual-screen button (right of F12) → toggles the bottom screen on/off.**

## Install

```bash
sudo apt install x11-xserver-utils xinput inotify-tools usbutils python3-evdev
git clone https://github.com/nrebolloso/zenbook-duo-ux8406ma-screen-fix.git
cd zenbook-duo-ux8406ma-screen-fix
./install.sh
```

The installer puts `duo` and `duo-screen-toggle` in `/usr/local/bin`, adds an autostart entry for `duo watch-displays`, and enables `duo-screen-toggle.service` as a systemd user unit. Log out and back in (or run `/usr/local/bin/duo watch-displays &`) to start the keyboard-attach helper. The button handler is already running after install.

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

## Scope

UX8406MA on X11. Wayland is not supported (`xinput`/`xrandr` are X-only). For non-3K variants, edit `RESOLUTION`/`RATE` at the top of `duo`.

## Credits

Concept inspired by the GNOME-targeted [zenbook-duo-2024-ux8406ma-linux](https://github.com/alesya-h/zenbook-duo-2024-ux8406ma-linux) by Alesya Huzik.

## License

MIT.
