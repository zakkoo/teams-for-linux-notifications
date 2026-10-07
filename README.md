# Teams Meetings for Omarchy

**Never miss a Teams meeting again because Teams was hidden.**

Teams for Linux only reminds you inside its own window. This
widget puts your next meeting straight into the Omarchy bar.

- **Works out of the box.** It reads the calendar Teams for Linux already has.
  No Azure app registration, no admin approval, no API keys, no extra programs.
- **Nothing to configure by hand.** One click connects it to Teams for Linux,
  every setting lives in the widget's own popup.
- **Click to join.** Meetings open in Teams for Linux, not in a browser tab.
  Meetings in a physical room show the room instead.

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
| You are in the call, or nothing upcoming, or Teams closed | nothing |

Left click opens the popup with today's meetings. Right click joins the shown
meeting directly. Middle click dismisses a meeting you are skipping.

## Settings

Everything is in the popup under **Settings & connection**: how far ahead the
next meeting appears (15 minutes by default), how often the calendar is
checked, an optional pop-up reminder, and, under *Advanced*, the local port
and message prefix used to talk to Teams for Linux. The same values are also
editable in the shell's widget settings form.

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
Meeting-start detection matches the English Teams UI only; other locales need
`meetingStartDetection.patterns` in the Teams config.

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

No test dependencies: Python's `unittest` and Node's built-in test runner.
GitHub Actions runs both on every push, plus `qmllint` for QML syntax. The
QML behaviour itself has no headless runner in the shell, so the structure
tests pin the contracts between manifest, widget, service and scripts, and the
rest is covered by installing the plugin.
