# Proposal

## Why

The optional reminder is a one-shot desktop notification: it fires once at the lead time, offers only "click to join", and is gone. The user wants to snooze it in halving steps, dismiss it, or join from it, and never trigger anything by clicking the body. The Omarchy shell's notification daemon renders no action buttons (it only honours a default click, which always dismisses), so a desktop notification cannot do this. The widget is itself a shell plugin and can draw its own reminder card instead.

## What Changes

- **BREAKING**: The desktop notification (`omarchy-notification-send`) is replaced by a reminder card the plugin draws itself as an overlay window on the focused screen. The `toast` setting keeps its key and now enables this card.
- The card shows the meeting subject and a countdown, and offers three buttons: **Join** (only when the meeting has a join link), **Remind me in N min**, and **Dismiss**. Clicking the card body does nothing.
- **Remind me in N min** hides the card and shows it again after half the remaining time to the start (N = remaining minutes / 2, rounded down, minimum 1). Each reopened card recomputes N from the new remaining time. At one minute remaining or once the meeting has started, the snooze button is no longer offered.
- **Dismiss** hides the card and marks the meeting as dismissed, the same as middle-clicking the widget today.
- **Join** hands the link to Teams for Linux and hides the card.
- The card may show the subject: it is drawn in-process, so no argv leaks it to other local users. The old "no subject in the toast" rule is retired with the transport it protected.
- Settings labels and descriptions for `toast` and `leadMinutes` are reworded from "desktop notification" to "reminder card". No key is renamed.
- The popup list order changes from "latest first" to: meetings still to come first (nearest at the top), then finished meetings (most recently ended first). The hide-finished toggle is unchanged.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `meeting-bar-widget`: the "Optional toast" requirement is replaced by a "Reminder card" requirement with join, snooze and dismiss buttons and an inert body; the "Popup meeting list" requirement gets the new order.
- `plugin-settings`: the `toast` and `leadMinutes` settings now describe the reminder card; defaults and bounds are unchanged.

## Impact

- `Service.qml`: the `onMeetingStateChanged` toast branch becomes card scheduling; a new `PanelWindow` overlay hosts the card; `join` and `dismiss` are reused.
- `Model.js` and `tests/model.test.js`: `toastDue` is extended with a per-meeting "show again at" time and a pure snooze-interval helper.
- `Panel.qml`, `manifest.json`: setting labels reworded.
- `tests/test_plugin_structure.py`: the "toast never mentions subject" check is retired; the new window file is added to the brace-balance check.
- `README.md`, `CHANGELOG.md`, manifest version: release bump.
- No new dependencies. The shell's `PanelWindow`, `BorderSurface` and `Button` are already available to plugins (the bundled OSD and polkit plugins use the same approach).
