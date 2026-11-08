# Server Status Plasmoid

## About
Applet for KDE Plasma 6 showing a status of the servers defined by user.

Ported by renyuneyun (Rui Zhao) - https://me.ryey.icu
- Largely with the help from Copilot

Originally written by Maciej Gierej - http://makg.eu

## Installation
```
./install.sh
```

The installer updates the applet with `kpackagetool6` and also installs the
notification configuration needed for native KDE notifications. Use
`./install.sh --no-restart` to avoid restarting plasmashell automatically.

If you install manually, copy the notification files too:

```
kpackagetool6 --type Plasma/Applet --install package
install -Dm644 package/contents/notifications/org.kde.plasma.serverstatus.notifyrc \
  ~/.local/share/knotifications6/org.kde.plasma.serverstatus.notifyrc
install -Dm644 package/contents/notifications/org.kde.plasma.serverstatus.desktop \
  ~/.local/share/applications/org.kde.plasma.serverstatus.desktop
```

## Features
- Add as many servers as you want
- Customize font size and icons
- 4 server checking methods: ping, ping for IPv6 addresses, HTTP 200 OK response, custom command
- Automatic update of server status
- Manual refresh by clicking on the server name
- Per-server detail: ping latency, HTTP status code, or OK/fail for commands
- Hover tooltip with host, method, last check, result, and a latency sparkline
- Latency history kept in memory (configurable window, up to 6 hours)
- Check timeouts so unreachable servers are detected quickly
- Native KDE notifications with per-event sounds and a refresh action
- Network path diagnostics with `mtr` and a `tracepath` fallback

## Notifications

Notifications use KNotification, so they follow Plasma's Do Not Disturb mode,
notification history, and per-application settings. Configure popups and sounds
in **System Settings → Notifications → Server Status**.

The notification for a server going offline uses a critical urgency and the
`dialog-error` sound. The notification for a server coming back online uses the
`dialog-information` sound. The first status check after starting the applet
does not send a notification.

## Network diagnostics

Servers can be diagnosed from the add/edit dialog or from the server's context
menu in the applet. The diagnostic uses `mtr` in report mode when available and
falls back to `tracepath` if `mtr` is missing or cannot run. Both are optional
tools; the status checks do not depend on them.

The report shows the route, packet loss, and latency per hop. It can be copied
from the diagnostic window or run again. When a server transitions from online
to offline, a diagnostic can also run automatically in the background and its
last report remains available from the context menu. This behavior can be
disabled in **Configure → Notifications → Diagnostics**.

## Custom command
You can define your custom command which will be executed on each server update. The plasmoid interprets exit code 0 as the server being online. Any other exit code will result in offline status. You can use `%hostname%` string in the command definition to pass particular server's hostname as an argument or option.

## Screenshots (not updated)
![Server Status Plasmoid](https://raw.githubusercontent.com/MakG10/plasma-applet-server-status/master/server-status-plasmoid.png)

![Server Status Plasmoid (Panel)](https://raw.githubusercontent.com/MakG10/plasma-applet-server-status/master/server-status-panel.png)

![Server Status Plasmoid (Configuration)](https://raw.githubusercontent.com/MakG10/plasma-applet-server-status/master/server-status-config.png)

![Server Status Plasmoid (Configuration)](https://raw.githubusercontent.com/MakG10/plasma-applet-server-status/master/server-status-config-item.png)

![Server Status Plasmoid (Configuration)](https://raw.githubusercontent.com/MakG10/plasma-applet-server-status/master/server-status-config-appearance.png)

## License

Released under the GPLv3 license.

## Changelog

### 2.0
Initial working version for Plasma 6

### 1.0
Initial release
