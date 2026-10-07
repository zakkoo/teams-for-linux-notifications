# 01 D-Bus sniff
Catches the desktop notifications Teams for Linux / Firefox already send, before Omarchy shows them.

Prereqs:
- Teams: Settings → Notifications and activity → Meetings → "Meeting start notification" ON.
- `~/.config/teams-for-linux/config.json`: `"notificationMethod": "electron"`.
- Firefox: allow notifications for outlook.office.com (Outlook → Settings → General → Notifications).

Run `./start`; every notification seen is logged to stderr so you can tune `DBUS_APPS` / `DBUS_PATTERN` in config.env.
