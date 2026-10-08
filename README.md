# Teams Meetings for Omarchy

**Never miss a Teams meeting again.**

Teams for Linux only reminds you inside its own window. This
widget puts your next meeting straight into the Omarchy bar.

- **Works out of the box.** It reads the calendar Teams for Linux already has.
  No Azure app registration, no admin approval, no API keys, no extra programs.
- **Nothing to configure by hand.** One click connects it to Teams for Linux,
  every setting lives in the widget's own popup.
- **Click to join.** Meetings open in Teams for Linux, not in a browser tab.
  Meetings in a physical room show the room instead.
- **Snoozable reminder.** Optionally a card pops up before the meeting with
  **Join**, **Remind me in N min** and **Dismiss**. Each snooze halves the
  time left (15 min → remind in 7 → remind in 4 → …). Clicking the card
  itself does nothing; only the buttons act.

![Preview](preview.png)

## Install

```bash
omarchy plugin add https://github.com/zakkoo/teams-for-linux-notifications.git --enable
```

Then **click the small calendar icon** in the center of the bar and press
**Connect Teams for Linux**. That adds a few lines to Teams for Linux's own
config file (keeping a timestamped backup). Restart Teams for Linux once. Done.

Move it where you like:

```bash
omarchy bar move io.github.zakkoo.teams-for-linux-notifications --section right
```

## What you see

| State | Bar |
|---|---|
| Next meeting within the horizon (default 15 min) | `󰃰 Standup in 12m` |
| Meeting started, you have not joined | `󰃰 Standup · now` in the urgent colour, sticky |
| You are in the call | `󰃰 Standup · in call` |
| Nothing upcoming | `󰃰` alone; hover says "Connected" |
| Teams for Linux closed or not yet connected | `󰃰` dimmed; hover says why ("Waiting for Teams for Linux (is it running?)") |

The icon is always in the bar, so a bare icon means the widget is fine and
simply has nothing to announce. Only the text comes and goes.

Left click opens the popup with today's meetings. Right click joins the shown
meeting directly. Middle click dismisses a meeting you are skipping.

## Settings

Everything is in the popup under **Settings & connection**: how far ahead the
next meeting appears (15 minutes by default), how often the calendar is
checked, whether long titles scroll through the bar, an optional reminder
card and its lead time, and, under *Advanced*, the local port and message
prefix used to talk to Teams for Linux. The meeting list has its own toggle to
hide finished meetings. The same values are also editable in the shell's
widget settings form.

## Remove

```bash
omarchy plugin remove io.github.zakkoo.teams-for-linux-notifications --yes
```

Press **Disconnect** under Settings & connection first if you want the added
lines taken out of Teams' config again. Forgot? Run
`python3 scripts/teams-config.py disconnect` from a checkout, or restore the
`config.json.bak-*` file next to it. Teams with a dangling MQTT config just
keeps retrying quietly.

## Requirements

Omarchy 4 shell and Teams for Linux 2.20 or newer, installed as a package,
Flatpak or Snap (the config file is found automatically). The Connect button
enables Teams for Linux's MQTT, Graph API and meeting-start detection features.
## Languages

Teams for Linux detects a starting meeting primarily through Teams' internal
events, which work in any language. Its text-based fallback reads the
"meeting started" banner, and Connect teaches it the wording for **English,
German, Spanish, French and Portuguese**. If your system language is not one
of these, the popup says so and links to an issue template; switching Teams to
one of the supported languages also works. Requests for more languages are
welcome: [open an issue](https://github.com/zakkoo/teams-for-linux-notifications/issues/new).

## Coming from the proof of concept?

If you ran the old systemd version from this repo: `./install.sh --remove`
on the old checkout before installing the plugin.

## Versioning

Semantic versions, starting at 0.1.0, kept in `manifest.json` and listed in
[CHANGELOG.md](CHANGELOG.md). The running version is printed in the bottom
right corner of the popup.

## Development

```bash
python3 -m unittest discover -s tests -v   # bridge protocol, calendar parsing, Teams config helper, plugin structure
node --test tests/model.test.js            # bar label state machine against the spec scenarios
omarchy plugin validate .                  # the shell's own manifest check (needs Omarchy)
```

`Model.js` is pure logic in three layers: `normalize` parses and sorts the
events once, `eventState` judges one meeting on its own, and `labelState`,
`dueReminders` and `splitDay` compose the bar label, the reminder cards and the
popup sections from those. Every entry point takes one context object
(`{events, nowMs, inCall, inCallEventId, meetingStarted, pulseAtMs, horizonMin,
leadMin, dismissed, remindAt, hidePast}`), so a test scenario is a literal.
`Service.qml` builds that object once and owns the bookkeeping (dismissals,
snoozes, the meeting a call belongs to); `bridge.py` keeps its state in one
`Broker` object that the tests construct fresh per scenario.

No test dependencies: Python's `unittest` and Node's built-in test runner.
GitHub Actions runs both on every push, plus `qmllint` for QML syntax. The
QML behaviour itself has no headless runner in the shell, so the structure
tests pin the contracts between manifest, widget, service and scripts, and the
rest is covered by installing the plugin.
