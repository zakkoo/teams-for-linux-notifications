# Design

## Context

See proposal.md - Why. `BarWidget.qml` computes
`visible: svc !== null && (setupMode || (svc.connected && meetingState.kind !== "none"))`
and `implicitWidth: visible ? … : 0`, so the whole widget collapses whenever
there is nothing to say. The dimmed-icon treatment already exists for
`setupMode` (`!connected && !teamsWired`), and `Service.statusText()` already
produces a one-line reason for every idle or disconnected state. The label
text, suffix and urgent colour all derive from `svc.meetingState`, which is
`kind: "none"` when idle. One widget instance exists per monitor; the service
is a shell-wide singleton that may briefly be `null` while the shell loads.

## Goals / Non-Goals

**Goals:**
- Icon present from the moment the service exists, regardless of connection or meeting state.
- Connection state readable at a glance (normal vs dimmed) and in detail on hover.
- No change to label, scrolling, urgent colour, toast, popup or settings behaviour.

**Non-Goals:**
- A setting to hide the idle icon. Nobody asked; add if someone wants the old behaviour back.
- An explicit "error" glyph or colour for a bridge failure; the dimmed icon plus tooltip text covers it.
- Showing anything while `svc` is still `null` (sub-second at shell start).

## Decisions

1. **Dim the icon whenever `!svc.connected`, not only in `setupMode`.**
   Alternative: keep the icon normal-coloured while idle-disconnected and hide only in setup mode's complement. Rejected: the user's complaint is "did it crash?"; a disconnected widget that looks identical to a connected idle one would answer that question wrongly. Reusing the existing dim colour (`Qt.darker(fg, 1.8)`) keeps the diff to one condition and needs no new theme hook. `setupMode` stays as a separate flag only for the tooltip/popup Connect wording.

2. **Reuse `Service.statusText()` for the idle tooltip.**
   It already distinguishes bridge error, bridge starting, not wired, waiting for Teams, no calendar, connected. Alternative: new strings in the widget. Rejected: duplication, and the popup already shows the same text so wording stays consistent.

3. **Keep `implicitWidth` tied to the row's implicit width and drop the `visible ? … : 0` branch.**
   The row shrinks to the glyph when label and suffix are empty, so the icon-only state needs no special width. `visible` becomes `svc !== null`.

4. **Guard middle-click rather than hide the mouse area.**
   `svc.dismiss()` already returns early when `meetingState.event` is null, so no code change is strictly needed; the spec just makes the no-op explicit.

## Risks / Trade-offs

- [Bar layout shifts when the label appears/disappears] → Already the case today between zero and full width; now the shift is smaller (icon stays put).
- [Users who liked the invisible idle widget] → Changelog entry; a hide setting is cheap to add later if requested.
- [Dimmed colour unreadable on some themes] → Same value already used for setup mode since 0.1.0 with no reports.
