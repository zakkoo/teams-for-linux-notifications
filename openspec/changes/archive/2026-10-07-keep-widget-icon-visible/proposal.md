# Proposal

## Why

When no meeting falls inside the horizon the widget collapses to zero width and disappears from the bar, which is most of the day. The user cannot tell a healthy idle widget from a crashed one, and loses the only click target for the popup (today's meetings, settings, Connect/Disconnect) until a meeting comes up.

## What Changes

- The calendar icon stays in the bar at all times once the plugin is loaded; only the text label (title + "in 12m" / "now" / "in call") appears and disappears with the meeting state.
- Idle while connected: icon in the normal bar foreground colour, no text. Hover tooltip shows the service status ("Connected", "Connected · no calendar received yet").
- Not connected (Teams for Linux not running, bridge starting, or setup needed): icon dimmed, no text, exactly as setup mode looks today. Hover tooltip shows the matching status text so the user sees *why* it is dimmed.
- Left click always opens the popup. Right click falls back to opening the popup when there is no join link (already the case). Middle click is a no-op when nothing is shown.
- Spec: the "widget occupies no space" scenarios in `meeting-bar-widget` are replaced by "icon only" scenarios. The "Hidden without Teams" requirement is renamed and reworded so the widget is never hidden; connection state is expressed through the dimmed icon instead.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `meeting-bar-widget`: "Upcoming meeting label" scenario *No event inside the horizon* changes from "occupies no space" to "icon only". Requirement "Hidden without Teams" becomes "Always visible; dimmed without Teams": the dimmed-icon treatment now applies whenever Teams is not connected, not only before setup, and the "Teams quits" scenario shows the dimmed icon instead of removing the widget.

## Impact

- `BarWidget.qml`: `visible` and `implicitWidth` expressions, glyph colour, tooltip text, middle-click guard.
- `Service.qml`: `statusText()` already exists and covers every idle/disconnected case; reused for the tooltip, no change expected.
- `openspec/specs/meeting-bar-widget/spec.md`: two requirements updated via the delta.
- `tests/test_plugin_structure.py`: one structural assertion that the widget no longer collapses on the `none` state.
- `README.md` / `CHANGELOG.md`: note that the icon is always present and what the dimmed state means.
- No settings, manifest, bridge, or Teams-side changes.
