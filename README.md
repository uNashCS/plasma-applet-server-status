# Server Status Plasmoid

An applet for KDE Plasma 6 that shows the status of user-defined servers.

This fork builds on the original Server Status Plasmoid and the Plasma 6 port,
adding native KDE notifications, network path diagnostics, per-server latency
and HTTP details, and latency history sparklines.

Current version: **2.4**

## Credits

- Original project: Maciej Gierej ([makg.eu](http://makg.eu))
- Plasma 6 port: renyuneyun (Rui Zhao) ([me.ryey.icu](https://me.ryey.icu))
- Fork and current maintenance: **Cristopher Salas (@uNashCS)**
  ([github.com/uNashCS/plasma-applet-server-status](https://github.com/uNashCS/plasma-applet-server-status))

## Requirements

- KDE Plasma 6 (Qt 6)
- `kpackagetool6` for installation
- For the default check methods: `ping`/`ping6` (iputils) and `curl`
- Optional for diagnostics: `mtr` (preferred) or `tracepath`

## Installation

```bash
git clone https://github.com/uNashCS/plasma-applet-server-status.git
cd plasma-applet-server-status
./install.sh
```

The installer upgrades the applet with `kpackagetool6` and installs the
notification configuration used by native KDE notifications. Use
`./install.sh --no-restart` to avoid restarting plasmashell automatically.

### Manual installation

```bash
kpackagetool6 --type Plasma/Applet --install package
install -Dm644 package/contents/notifications/org.kde.plasma.serverstatus.notifyrc \
  ~/.local/share/knotifications6/org.kde.plasma.serverstatus.notifyrc
install -Dm644 package/contents/notifications/org.kde.plasma.serverstatus.desktop \
  ~/.local/share/applications/org.kde.plasma.serverstatus.desktop
```

## Features

- Monitor any number of servers with automatic refresh.
- Four check methods: IPv4 ping, IPv6 ping, HTTP 200 OK, and a custom command.
- Per-server result: ping latency, HTTP status code, or OK/fail.
- Manual refresh by clicking a server.
- Hover tooltip shown beside the widget with:
  - status and result,
  - check method and last check time,
  - latency min/avg/max and packet loss,
  - a latency sparkline for the configured history window.
- Latency history kept in memory only (no disk writes).
- Native KDE notifications with per-event sounds and actions (Refresh, Diagnose).
- Network path diagnostics with `mtr` and a `tracepath` fallback.
- Configurable diagnostic cycle count and automatic diagnosis when a server
  goes offline.

## Configuration

### Servers

Each server has a name, host name, refresh rate, check method and an active
flag. Servers can be added, edited, reordered and removed from the applet
settings.

### Check methods

| Method | Command | Online when |
| --- | --- | --- |
| Ping | `ping -c 3 -W 2 -w 8 <host>` | exit code 0 |
| Ping (IPv6) | `ping6 -c 1 -W 2 -w 4 <host>` | exit code 0 |
| HTTP 200 OK | `curl` with `--connect-timeout`/`--max-time` | HTTP status 200 |
| Command | user-defined | exit code 0 |

Checks use timeouts so unreachable servers are detected quickly.

### Appearance

- Font size and online/offline icons.
- Latency history window (1–360 minutes, default 60).

## Notifications

Notifications use KNotification, so they follow Plasma's Do Not Disturb mode,
notification history, and per-application settings. Configure popups and sounds
in **System Settings → Notifications → Server Status**.

The notification for a server going offline uses critical urgency and the
`dialog-error` sound. The notification for a server coming back online uses the
`dialog-information` sound. Notifications include **Refresh** and **Diagnose**
actions. The first status check after starting the applet does not send a
notification.

## Network diagnostics

Servers can be diagnosed from the add/edit dialog, from the server's context
menu, or from the Diagnose action in a notification. The diagnostic uses `mtr`
in report mode when available and falls back to `tracepath` if `mtr` is missing
or cannot run. Both tools are optional; the status checks do not depend on them.

The report shows the route, packet loss and latency per hop. It opens in a
non-modal window and can be copied or run again. The number of `mtr` cycles can
be configured (1–30) in **Configure → Notifications → Diagnostics** or directly
in the report window.

When a server transitions from online to offline, a diagnostic can run
automatically in the background. Its last report remains available from the
context menu. Automatic diagnostics can be disabled in the configuration.

## Latency history and tooltips

Latency samples are stored in memory while the applet is running and are lost
when plasmashell restarts. The tooltip shows a sparkline with the min/avg/max
latency, packet loss and the most recent value. The history window is
configurable up to 6 hours.

## Custom command

You can define a custom command that is executed on each server update. The
plasmoid interprets exit code 0 as the server being online; any other exit code
results in offline status. Use `%hostname%` in the command to pass the server's
host name as an argument or option.

## Screenshots

New screenshots will be added soon. The previous screenshots from the original
project are intentionally not shown here to avoid confusion with the current
version.

## License

Released under the GPLv3 license (GPL-3.0-or-later). See [LICENSE](LICENSE).

## Changelog

### 2.4

- Tooltip now opens in Plasma's tooltip window beside the widget instead of on
  top of the server list.
- Redesigned tooltip with status indicator, result badge, method icon,
  min/avg/max latency, packet loss and an improved sparkline.
- Fixed the diagnostic button in the server settings dialog.
- Added fork maintainer information and corrected project metadata.
- README overhaul.

### 2.3

- Latency history kept in memory (configurable window, up to 6 hours) with a
  sparkline in the tooltip.
- HTTP checks now report response time.

### 2.2

- Configurable number of `mtr` cycles for diagnostics, both in the configuration
  and in the report window.

### 2.1

- Native KDE notifications (KNotification) with Refresh and Diagnose actions.
- Network diagnostics with `mtr` and a `tracepath` fallback, automatic diagnosis
  when a server goes offline, and a report window.
- Per-server latency, HTTP code and OK/fail details.
- Hover tooltips and check timeouts.

### 2.0

- Initial working version for Plasma 6.

### 1.0

- Initial release.
