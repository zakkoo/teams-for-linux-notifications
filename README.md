# Teams Meetings for Omarchy

Your next Teams meeting, with a countdown, directly in the Omarchy bar.
When a meeting starts the label turns urgent and stays until you join.
No banner, no icon to click, nothing to install besides the plugin.

Teams for Linux publishes your calendar and a "meeting started" signal over
MQTT. This plugin runs a tiny MQTT broker of its own inside the shell, so
nothing else is needed on the machine.

## Install

```bash
omarchy plugin add https://github.com/zakkoo/teams-for-linux-notifications.git --enable
```

Then **right-click the widget** (it appears once Teams is connected, so right
after enabling you will find it under the bar's widget settings or at its
default center slot) and press **Connect Teams for Linux**. That merges the
needed MQTT keys into `~/.config/teams-for-linux/config.json`, keeping a
timestamped backup. Restart Teams for Linux once. Done.

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

Left click opens the join link. Right click opens the popup with today's
meetings, join buttons and the Connect / Disconnect button.

## Settings

All settings live in the shell's widget settings form (no file editing):
horizon, toast lead time, optional desktop notification (off by default),
calendar refresh interval, MQTT port and topic prefix.

## Remove

```bash
omarchy plugin remove io.github.zakkoo.teams-for-linux-notifications --yes
```

Press **Disconnect** in the popup first if you want the MQTT keys taken out
of Teams' config again. Forgot? Run
`python3 scripts/teams-config.py disconnect` from a checkout, or restore the
`config.json.bak-*` file next to it. Teams with a dangling MQTT config just
keeps retrying quietly.

## Requirements

Omarchy 4 shell, Teams for Linux 2.20 or newer with MQTT, Graph API and
meeting-start detection (the Connect button enables all three). Meeting-start
detection matches the English Teams UI only; other locales need
`meetingStartDetection.patterns` in the Teams config.

## Coming from the proof of concept?

If you ran the old systemd version from this repo: `./install.sh --remove`
on the old checkout before installing the plugin.

## Development

```bash
python3 tests/selfcheck.py          # broker, due logic, config helper
omarchy plugin validate .           # manifest
```
