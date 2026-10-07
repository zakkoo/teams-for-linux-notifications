# teams-for-linux-notifications

Eight ways to learn that a meeting is starting, all feeding one sink: `alert/alert.sh`
(critical Omarchy toast with click-to-join, plus red Hyprland borders for a minute).
Try them, keep one, run `./keep.sh <name>` to delete the rest.

## Layout
```
alert/alert.sh      the visible thing — edit this to build your own; every firing is appended to ~/.local/state/meeting-alert.log
alert/due.py        config loading, "fire once N min before start" logic, Graph JSON parsing
alert/ics.py        ICS parsing (only 07/08 need it)
sources/NN-name/    one self-contained option: ./start (foreground, logs to stderr) + README.md
config.env          your settings (cp config.env.example config.env)
install.sh NAME     run one source as a systemd user service; install.sh --remove
keep.sh NAME        delete the losers
tests/selfcheck.py  python3 tests/selfcheck.py
```

## Trying one
```
cp config.env.example config.env        # fill in what the option's README asks for
alert/alert.sh "Test" "does the sink look right?"
sources/01-dbus-sniff/start             # Ctrl-C to stop; read sources/01-dbus-sniff/README.md first
```

## The options
| # | Source | Signal | Needs | Tenant OK? | Fires |
|---|--------|--------|-------|------------|-------|
| 01 | dbus-sniff | Teams/Firefox desktop notifications | Teams + Outlook notification settings on | no | when they'd have shown a toast |
| 02 | teams-mqtt | Teams for Linux `meeting-started` + calendar over MQTT | config.json change; Teams running | no (reuses Teams' own token) | banner + N min before |
| 03 | teams-cdp | Teams' own Graph token via DevTools port | `--remote-debugging-port`; Teams running | no (reuses Teams' own token) | N min before |
| 04 | hypr-events | Teams window titles | nothing | no | title regex match (experimental) |
| 05 | az-graph | Azure CLI → Graph | tenant must allow Calendars.Read for Azure CLI | **yes** — Azure CLI needs Calendars.Read consent (already got Unauthorized here) | N min before |
| 06 | power-automate | Flow trigger "upcoming event starting soon" → ntfy | build the flow once | partly — Power Automate enabled (usual); HTTP action is premium, email variant needs external forwarding allowed | server-side, N min before |
| 07 | ics-feed | Published Outlook ICS link | tenant must allow publishing | **yes** — calendar publishing must be enabled | N min before (feed lags hours) |
| 08 | email-rule | Outlook rule forwards invites → IMAP mailbox | an IMAP mailbox you can read | partly — rule forwarding to an external mailbox is often blocked | N min before |

Start with 01–04 (nothing to ask for). Then 06. Treat 05/07/08 as "check if the setting exists, else delete".

Dead ends not included: anything EWS-based (davmail, evolution-ews, exchangelib) — Microsoft began
disabling EWS in Exchange Online on 2026-10-01.

## Keeping one
```
./keep.sh 06-power-automate
./install.sh 06-power-automate
```
