# Design

## Context

See proposal.md for motivation. Constraints discovered while exploring:

- The Omarchy plugin installer only clones files, validates the manifest and flips the enabled bit. It never runs plugin code or install hooks, so nothing can touch Teams' `config.json` at install time.
- Plugins run unsandboxed inside the single `omarchy-shell` Quickshell process. A plugin must not start a second Quickshell, may not contain symlinks, and gets `bar`, `moduleName` and `settings` injected.
- The manifest `barWidget.schema` (types `integer` with min/max/step, `enum`, `boolean`, `string`) is rendered by the shell as a settings form; values are stored inline on the widget's shell.json entry and arrive as `settings.<key>`.
- Bar placement is a shell feature (drag, `omarchy bar move`), so the plugin only sets `defaultSection`.
- Quickshell cannot listen on TCP, so an MQTT broker must be a helper process. Quickshell `Process` with `stdout` parsing is the shell's standard pattern (weather, agents).
- Teams for Linux publishes `{prefix}/connected` (LWT), `{prefix}/calendar` (Graph JSON on `get-calendar` command), `{prefix}/meeting-started` (pulse, no title), `{prefix}/in-call`. Meeting-start detection matches English UI strings only.
- Teams for Linux minimised to the tray has no Wayland toplevel, so window presence is not a reliable "Teams is running" signal.

## Goals / Non-Goals

**Goals:**
- One repo = one marketplace plugin; install and remove through `omarchy plugin`.
- No file the user has to edit; settings via the shell form, Teams config via a button.
- The bar is the only UI surface by default.

**Non-Goals:**
- Multi-account or non-Teams calendars.
- Notification history, snooze, or a full agenda view beyond today.
- Running without Teams for Linux (no direct Graph auth).
- Non-English meeting-start detection (that is Teams' `patterns` setting; README points at it).

## Decisions

1. **Bridge is a child `Process` of the bar widget, always running while the shell runs; the widget hides itself until Teams connects.**
   Alternatives: (a) systemd user unit, as in the PoC: survives shell restarts but requires an installer step the plugin system forbids. (b) Start/stop the bridge on Teams' Wayland toplevel: breaks when Teams sits in the tray. An idle broker blocked on `accept()` costs nothing measurable, and `{prefix}/connected` with LWT is the authoritative "Teams is here" signal.

2. **Keep the PoC's stdlib MQTT broker and due-logic in Python (`scripts/bridge.py`); it emits one JSON line per state change on stdout.**
   Alternative: port the MQTT framing to QML/JS. The Python is tested (`tests/selfcheck.py`) and ~150 lines; QML has no TCP server anyway. The JSON line is the whole contract: `{"connected": bool, "inCall": bool, "meetingStarted": bool, "events": [{"id","subject","start","end","joinUrl"}]}`. QML owns rendering and timing; Python owns protocol and calendar fetching.

3. **Settings reach the bridge as command-line arguments; changing a setting restarts the Process.**
   Only `pollMinutes`, `mqttPort`, `mqttPrefix` matter to the bridge. `leadMinutes`, `horizonMinutes`, `toast` are evaluated in QML from the event list, so they apply instantly without a restart. Alternative: a stdin control channel — more code for no visible gain.

4. **Bar label state machine lives in QML, derived every 15 s from `events`, `now`, `inCall`, `meetingStarted`.**
   ```
   !connected                                -> hidden
   inCall                                    -> hidden
   event with start <= now < end, not joined -> "<icon> <title> · now"  (urgent colour, sticky)
   next event with 0 < start-now <= horizon  -> "<icon> <title> in Nm"
   otherwise                                 -> hidden
   ```
   `meetingStarted` pulse promotes the nearest event (start within ±5 min) to the "now" state even if the clock has not reached its start, and triggers the optional toast. Long titles scroll like `omarchy.media`.

5. **Teams configuration edits are done by `scripts/teams-config.py connect|disconnect|status`, invoked from the popup.**
   `connect` merges `mqtt.{enabled,brokerUrl,topicPrefix,commandTopic}`, `graphApi.enabled`, `meetingStartDetection.enabled` into `~/.config/teams-for-linux/config.json`, writing `config.json.bak-<timestamp>` first and preserving all other keys. `disconnect` removes exactly those keys. `status` reports whether the keys are present so the popup can show the right button. Teams reads its config at startup, so the popup tells the user to restart Teams. Alternative: ask the user to paste JSON (the PoC approach) — rejected by the requirement.

6. **Toast uses `omarchy-notification-send`, off by default, only on the meeting-started transition.**
   Red borders dropped: they are a global side effect and the bar now carries the signal.

7. **Repository layout**
   ```
   manifest.json  BarWidget.qml  Panel.qml  Model.js
   scripts/bridge.py  scripts/teams-config.py
   tests/selfcheck.py  README.md  LICENSE  preview.png
   ```
   Everything else from the PoC is deleted. Flat layout, no symlinks.

## Risks / Trade-offs

- [Teams restarted while bridge holds the port] → broker accepts the next connection; Teams' MQTT client auto-reconnects. Bridge must handle sequential clients, which the PoC already does.
- [Port 1883 in use by a real broker] → `mqttPort` setting; popup shows the bridge's last error line.
- [Shell restart kills the bridge mid-meeting] → state is recomputed from the next calendar fetch on start; a meeting in progress reappears as "now" because `start <= now < end`.
- [`meeting-started` pulse arrives with no matching calendar event] → show a generic "Meeting started" label with no join link, clear on `in-call` or after 10 min.
- [User removes the plugin without pressing Disconnect] → Teams keeps trying to reach a broker that is gone; harmless, and README documents `scripts/teams-config.py disconnect`.
- [Graph token missing in Teams] → `calendar` never arrives; widget stays hidden. Popup shows "connected, no calendar yet" so it is diagnosable.

## Migration Plan

1. Users of the PoC: `./install.sh --remove` on the old checkout (documented in README).
2. `omarchy plugin add https://github.com/zakkoo/teams-for-linux-notifications.git --enable`.
3. Click the widget → Connect Teams for Linux → restart Teams.
Rollback: `omarchy plugin remove io.github.zakkoo.teams-for-linux-notifications --yes` plus Disconnect (or restore the `.bak` file).

## Open Questions

- Exact icon glyph and whether the widget keeps a dim icon (instead of hiding) when connected with nothing upcoming. Cosmetic; decide while implementing against the real bar.
