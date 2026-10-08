# Design

## Context

See proposal.md for motivation. Facts that shape the approach, all verified against the installed Omarchy shell (`/usr/share/omarchy/shell/plugins/notifications`):

- The shell is the `org.freedesktop.Notifications` server. Its card renders summary, body and icon only. Left click runs the default action and dismisses; right click closes. Non-default actions are never drawn. So buttons on a desktop notification are impossible here.
- The widget's `Service.qml` is mounted once per shell with the bridge state, `meetingState`, `join()` and `dismiss()`. It already ticks `nowMs` every 15 seconds.
- Bundled plugins (OSD, polkit agent, lock) open their own layer-shell window with `PanelWindow` from inside an `Item`, styled with `BorderSurface` and the shell's `Style`/`Color` singletons. The popup in `Panel.qml` already uses the shell's `Button`.
- `Model.js` is pure JS, tested by `node --test`. `toastDue(state, nowMs, leadMin)` is the existing due check.

## Goals / Non-Goals

**Goals:**
- One reminder card, drawn by the plugin, with Join / Remind me / Dismiss and an inert body.
- Snooze and due logic stays in `Model.js` so it is unit-tested without Qt.
- Smallest diff: reuse `join()`, `dismiss()`, `dismissed`, the 15-second tick, and the shell's UI components.

**Non-Goals:**
- Keeping the desktop notification as an alternative. One reminder path only.
- Per-meeting reminder history across shell restarts. A restart mid-reminder simply re-evaluates and may show the card again, which is the desired behaviour.
- Keyboard navigation, sounds, or showing the card on every monitor.

## Decisions

**Own overlay window instead of a desktop notification.** The daemon cannot render buttons and always dismisses on click. Alternatives: (a) three separate notifications, one per action, ugly and still dismiss-on-click; (b) a custom D-Bus action listener, pointless because the buttons are never drawn. Rejected.

**Window lives with the service, not in the bar widget.** The service exists once per shell, the widget once per monitor. One card total is a requirement. Placement follows the OSD: `WlrLayer.Overlay`, `ExclusionMode.Ignore`, no keyboard focus, `screen` bound to the Hyprland focused monitor at show time. The card is a `BorderSurface` anchored top-centre, under the bar, with `Style.space` margins. The window's input region is limited to the card so it does not block the desktop. The window goes in a sibling `ReminderCard.qml` loaded by `Service.qml`; that keeps `Service.qml` readable and the structure tests already resolve referenced QML files.

**Inert body is the absence of a `MouseArea`.** No handler on the card, only on the three `Button`s. Nothing to implement for "click does nothing".

**Snooze state is a timestamp per meeting, not a timer.** `Service.qml` gains `property var remindAt: ({})` keyed by event id, replacing `toasted`. The due rule in `Model.js` becomes: due when `toastDue(...)` holds and `nowMs >= (remindAt[id] || 0)`. Pressing Remind-me sets `remindAt[id] = nowMs + snoozeMs`. Pressing Dismiss uses the existing `dismiss()`, which removes the event from `meetingState` and therefore closes the card. The existing 15-second tick re-evaluates, so the card reappears within 15 seconds of its due time with no extra `Timer`. The "shown once" bookkeeping disappears: the card is visible exactly when it is due and not snoozed, a derived boolean rather than a flag to maintain.

**Snooze maths is one pure function.** `snoozeMinutes(state, nowMs)` in `Model.js` returns `Math.max(1, Math.floor(remainingMinutes / 2))` for an upcoming event with more than one minute left, else 0 meaning "do not offer". The 15 → 7 → (8 left) → 4 → (4 left) → 2 → 1 chain in the request falls out of floor division. The card hides the button when the result is 0.

**"Now" transition during snooze.** A snooze is half the shown countdown, so by construction it always ends before the start. `remindAt` therefore applies uniformly in every state with no "now" special case, and a snoozed meeting still re-shows the card at its start. The same field doubles as "never again": Join from the card sets it to Infinity, which keeps the card off while the bar continues to show the meeting until Teams reports the call. The "now" card has no Remind-me button, so there is no loop.

**Card visibility is a binding.** `visible: toast && due && !inCall && meetingState.event`. Because `meetingState` already handles in-call, ended and dismissed events by returning a different state, "closes when the user joins elsewhere / meeting ends / dismissed from the bar" costs nothing.

**Settings keys stay.** Renaming `toast` or `leadMinutes` would orphan existing shell.json entries. Only labels change, in `manifest.json` and `Panel.qml`. The default lead time stays at 2 minutes; the user's 15-minute example is a setting they can raise.

## Risks / Trade-offs

- [Card reappears up to 15 seconds late] → Acceptable for minute-granularity snoozes; the countdown text is computed from real remaining time, not from the snooze.
- [Overlay window on a screen that disappears] → Bind `screen` at show time from the focused monitor and fall back to the first screen, as the OSD does.
- [The card overlaps the shell's own notification stack] → Place it top-centre; shell notifications sit top-right. Verify visually after implementation.
- [Structure test `test_toast_never_mentions_subject` would fail by design] → Retire it in the same task that adds the card; the privacy reason it guarded is gone with the transport.
- [Subject shown on the lock screen or screen share] → Same exposure as the bar label today; no new leak.
