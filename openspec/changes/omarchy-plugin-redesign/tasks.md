# Tasks

## 1. Repackage as a plugin

- [x] 1.1 Delete `sources/`, `alert/`, `install.sh`, `config.env.example`; verify `git status` shows only the new layout
- [x] 1.2 Write `manifest.json` (id `io.github.zakkoo.teams-for-linux-notifications`, kinds bar-widget, defaultSection center, defaults and schema from the plugin-settings spec) and verify `omarchy plugin validate .` passes
- [x] 1.3 Add `LICENSE` (MIT) and rewrite `README.md` with install, Connect, move, remove and PoC-migration steps; verify every command in it is spelled as the shell prints it

## 2. Bridge

- [x] 2.1 Move the PoC broker and due-logic into `scripts/bridge.py` taking `--port --prefix --poll-minutes`; emit one JSON state line on stdout per change (`connected`, `inCall`, `meetingStarted`, `events`); verify with a socket test that connect → subscribe → publish calendar yields the expected line
- [x] 2.2 Handle `connected` (incl. LWT), `in-call`, `meeting-started` topics and client disconnect; verify the state line flips `connected` false on disconnect
- [x] 2.3 Adapt `tests/selfcheck.py` to the new module and output contract; verify `python3 tests/selfcheck.py` prints ok

## 3. Teams configuration helper

- [x] 3.1 Write `scripts/teams-config.py connect|disconnect|status` merging/removing only the required keys with a timestamped backup; verify with a temp config containing unrelated keys that connect and disconnect round-trip to the original
- [x] 3.2 Add the helper's cases to `tests/selfcheck.py`; verify it passes

## 4. Bar widget

- [x] 4.1 `BarWidget.qml`: host the bridge as a `Process`, restart on exit, parse stdout lines into properties; verify the process appears under the shell and reconnects after `kill`
- [x] 4.2 `Model.js`: pure function computing the label state from events, now, inCall, meetingStarted, horizon; verify with a small JS self-check run via `qml` or node covering the scenarios in meeting-bar-widget
- [x] 4.3 Render label with urgent colour for "now", capped width with scrolling text, hidden when state is none; verify visually on the bar with a fake calendar
- [ ] 4.4 Left click opens join URL via `xdg-open`, right click opens the popup; verify both
- [ ] 4.5 Optional toast via `omarchy-notification-send` on the "now" transition when `settings.toast`; verify one notification per meeting
- [ ] 4.6 Restart the bridge when `pollMinutes`, `mqttPort` or `mqttPrefix` change; verify the process args update after a settings change

## 5. Popup

- [x] 5.1 `Panel.qml`: today's events with Join buttons, connection status line, last bridge error; verify it opens anchored to the widget
- [ ] 5.2 Connect/Disconnect button driven by `teams-config.py status`, with the "restart Teams" hint; verify both actions edit the config and the button flips

## 6. Integration

- [ ] 6.1 Install from the GitHub URL with `omarchy plugin add ... --enable --yes`, Connect, restart Teams; verify the widget shows a real upcoming event and goes sticky at start time
- [ ] 6.2 Remove with `omarchy plugin remove ... --yes`; verify bridge gone and Disconnect restores the config
