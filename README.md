# Vagashell

My standalone [Quickshell](https://quickshell.org/) desktop configuration for Hyprland.

It provides:

- A top bar on every monitor with workspaces, clock, StatusNotifier tray, network, Bluetooth, audio, battery, notifications, and quick settings.
- A compact, always-visible dock on every monitor with pinned and running applications.
- A scrollable 260 px system monitor on the left edge with CPU histories, temperatures, memory, filesystems, disk activity, network throughput, and uptime.
- Native Hyprland window focus/grouping and native Quickshell service integrations.
- Notification popups and bounded in-session history when running under Hyprland.

## Requirements

- Linux with Hyprland
- Quickshell 0.3 or newer
- Python 3 (standard library only)
- NetworkManager and `nmcli` for Wi-Fi controls
- BlueZ and `bluetoothctl` for Bluetooth controls
- PipeWire and UPower for audio and battery integration
- `hyprlauncher` for the launcher button

## Install

Clone this repository and link it to Quickshell's default config directory:

```sh
git clone https://github.com/derekshoneycutt/vagashell-config.git ~/source/vagashell-config
mkdir -p ~/.config
ln -s ~/source/vagashell-config ~/.config/quickshell
```

If `~/.config/quickshell` already exists, move or remove it before creating the symlink. The checkout must be available at that path because the QML services launch the Python helpers from it.

Start the shell:

```sh
qs
```

For foreground testing and logs:

```sh
qs -p ~/.config/quickshell -n
qs list
qs log
```

Quickshell reloads the configuration when its files change. To update the checkout later:

```sh
git -C ~/source/vagashell-config pull --ff-only
```

## Personalization

Application pins, launch commands, and window-class aliases live in `config/Apps.js`. The current list reflects my installed applications, including an Audiobookshelf Chrome PWA, so edit it for a different machine.

System monitor filesystem entries live in `scripts/system_metrics.py`. Paths such as `~/Audiobooks` and `~/Pictures` are personal defaults and are skipped when unavailable.

Colors, dimensions, radii, and icon sizes live in `config/Theme.js`.

## Services

- Audio: PipeWire through `Quickshell.Services.Pipewire`.
- Network: NetworkManager through `Quickshell.Networking`.
- Bluetooth: BlueZ through `Quickshell.Bluetooth`.
- Battery: UPower through `Quickshell.Services.UPower`.
- Tray: StatusNotifier through `Quickshell.Services.SystemTray`.
- Windows/workspaces: native `Quickshell.Hyprland` models.
- Notifications: Quickshell claims `org.freedesktop.Notifications` only when `HYPRLAND_INSTANCE_SIGNATURE` is present, avoiding conflicts while testing outside Hyprland.
- Connectivity: `scripts/connectivity_backend.py` handles scans, Wi-Fi credentials, saved-network removal, and Bluetooth pair/trust/connect flows.
- System metrics: `scripts/system_metrics.py` reads Linux `/proc` and `/sys` data once per second and streams JSON lines to `services/SystemDataService.qml`.

The Python helpers have no third-party package dependencies. Validate them independently with:

```sh
python3 scripts/system_metrics.py --once | python3 -m json.tool
python3 scripts/connectivity_backend.py --once | python3 -m json.tool
python3 -m unittest discover -s scripts/tests
```

## Power controls

Restart and power-off require a second confirmation click within five seconds. Lock requests use `loginctl lock-session`; install and configure `hyprlock`, `swaylock`, or another session locker if no lock screen appears.

## Compatibility

The configuration was load-tested with Quickshell 0.3.0 under GNOME and the Hyprland Lua config was verified with Hyprland 0.56.2. Layer-shell placement, monitor-local window matching, tray menus, and notification ownership still require an actual Hyprland session to exercise.
