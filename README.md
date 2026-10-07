# teams-for-linux-notifications

Meeting alerts for Teams for Linux on Omarchy: a critical toast with click-to-join, plus red
Hyprland borders for a minute. Teams for Linux (≥2.20) publishes `meeting-started` pulses and
your calendar over MQTT; `sources/02-teams-mqtt/start` is a tiny stdlib MQTT broker that only
serves Teams, so nothing needs installing.

## Layout
```
alert/alert.sh           the visible thing — edit this to build your own; every firing is appended to ~/.local/state/meeting-alert.log
alert/due.py             config loading, "fire once N min before start" logic, Graph JSON parsing
sources/02-teams-mqtt/   the broker (./start, foreground, logs to stderr) + README.md with the Teams config
config.env               your settings (cp config.env.example config.env)
install.sh 02-teams-mqtt run it as a systemd user service; install.sh --remove
tests/selfcheck.py       python3 tests/selfcheck.py
```

## Setup
```
cp config.env.example config.env
alert/alert.sh "Test" "does the sink look right?"
```
Then follow `sources/02-teams-mqtt/README.md` (merge its `config.json` into Teams for Linux, restart Teams),
and `./install.sh 02-teams-mqtt`. Logs: `journalctl --user -fu meeting-alert`.

Dead ends tried and dropped (see git history before this commit): D-Bus notification sniffing, Teams DevTools
port, Hyprland window titles, Azure CLI → Graph, Power Automate, published ICS feed, Outlook email rule.
Anything EWS-based is out too — Microsoft began disabling EWS in Exchange Online on 2026-10-01.
