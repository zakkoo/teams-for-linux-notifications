# Tasks

## 1. Snooze and due logic in the model

- [x] 1.1 Add `snoozeMinutes(state, nowMs)` to `Model.js` returning floor(remaining/2) with a floor of 1, and 0 when the state is not "upcoming" or at most one minute remains; verify with new cases in `tests/model.test.js` covering 15→7, 8→4, 4→2, 2→1, 1→0 and "now"→0 (`node --test tests/model.test.js`)
- [x] 1.2 Extend `toastDue` to take `remindAt` (ms, may be undefined) and return false while `nowMs < remindAt` for an upcoming event, but ignore `remindAt` in the "now" state; verify with test cases for snoozed-upcoming, snooze-elapsed and snoozed-then-started (`node --test tests/model.test.js`)

## 2. Reminder card window

- [x] 2.1 Create `ReminderCard.qml` as a `PanelWindow` overlay (focused screen, overlay layer, no exclusive zone, no keyboard focus, input region limited to the card) holding a `BorderSurface` with subject, countdown or "now", optional location, and the buttons Join (when `joinUrl`), "Remind me in N min" (when `snoozeMinutes` > 0) and Dismiss, with no MouseArea on the body; verify `qmllint --import disable --unqualified disable ReminderCard.qml` reports no error and `python3 -m unittest discover -s tests` passes after adding the file to the brace-balance list in `tests/test_plugin_structure.py`
- [ ] 2.2 In `Service.qml` replace `toasted` with `remindAt` keyed by event id, drop the `omarchy-notification-send` branch, load `ReminderCard.qml`, and bind its visibility to `toast && Model.toastDue(meetingState, nowMs, leadMinutes, remindAt[id]) && !inCall`; wire Join to `join()`, Dismiss to `dismiss()`, Remind-me to set `remindAt[id] = nowMs + snoozeMinutes * 60000`; verify by running the shell with the reminder on and a test meeting that the card appears at the lead time, the body ignores clicks, Remind-me closes it and it returns with the halved interval, Dismiss clears the bar label, Join opens Teams for Linux
- [x] 2.3 Retire `test_toast_never_mentions_subject` in `tests/test_plugin_structure.py` and add a check that `Service.qml` no longer references `omarchy-notification-send`; verify `python3 -m unittest discover -s tests` passes

## 3. Settings wording and docs

- [x] 3.1 Reword the `toast` and `leadMinutes` labels and descriptions in `manifest.json` and `Panel.qml` to describe the reminder card and its lead time; verify `tests/test_plugin_structure.py` still passes (every schema key still used, every read key still declared)
- [x] 3.2 Update `README.md` (feature list, settings paragraph) to describe the reminder card with Join, Remind me and Dismiss; verify the text matches the implemented button labels

## 4. Popup order

- [x] 4.1 Add `popupOrder(events, nowMs, hidePast)` to `Model.js` (upcoming by start ascending, then finished by start descending, finished dropped when hidden) and make `Panel.qml` rows use it; verify with a `tests/model.test.js` case covering both halves and the hide flag (`node --test tests/model.test.js`) and `qmllint` on `Panel.qml`

## 5. Instant settings and stacked cards

- [x] 5.1 Refresh the service clock when settings are pushed, reset the hold-back map on lead-time or reminder changes, and cap the effective lead at the horizon (also in the popup field's maximum); verify the structure tests pass and `qmllint` is clean on `Service.qml`, `BarWidget.qml`, `Panel.qml`
- [x] 5.2 Add `Model.dueReminders` (per-meeting judgement, soonest first, capped at three) with a `tests/model.test.js` case for cap, lead, dismissed, snoozed and in-call; make the service expose the list and the window render one card per entry with per-meeting Join, Remind me and Dismiss; verify `node --test`, the structure tests and `qmllint` on `ReminderCard.qml`

## 6. Dismiss semantics and handled meetings

- [x] 6.1 Add `Model.dismissUntil` (hold until start before the start, skip after) and drop the five-minute cut-off from `toastDue`; wire the card's Dismiss to `dismissReminder`, mark a meeting handled when its call ends, add `restore` and the popup's dimmed "Skipped · restore" row; move the bridge's calendar window to local midnight; verify `node --test`, the structure and bridge tests, and `qmllint` on the changed QML

## 7. Release

- [x] 7.1 Bump `version` in `manifest.json` to 0.2.0 and add a matching `## 0.2.0` entry at the top of `CHANGELOG.md` in the style of the existing entries describing the reminder card; verify the manifest version and the top changelog heading match and `python3 -m unittest discover -s tests` passes
