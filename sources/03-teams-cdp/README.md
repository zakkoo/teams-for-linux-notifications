# 03 Teams for Linux → DevTools → Graph
Asks the running Teams renderer for its own Graph token (`window.teamsForLinuxReactHandler.acquireToken`)
and polls `/me/calendarView` directly. No MQTT, no app registration.

Setup:
1. Add `"graphApi": { "enabled": true }` to `~/.config/teams-for-linux/config.json`.
2. Launch Teams with remote debugging: `teams-for-linux --remote-debugging-port=9222`
   (or copy `/usr/share/applications/teams-for-linux.desktop` to `~/.local/share/applications/` and add the flag to `Exec=`).
3. `./start`.

Caveat: port 9222 lets any local process drive your Teams session. Local-only, but know it.
