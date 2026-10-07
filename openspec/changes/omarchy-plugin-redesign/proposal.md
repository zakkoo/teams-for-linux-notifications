# Proposal

## Why

The proof of concept (`sources/02-teams-mqtt`) proves the core idea: Teams for Linux pushes its calendar and a "meeting started" pulse over MQTT, and we can remind the user before a meeting starts. But it is installed by hand (systemd unit, `config.env`, manual edit of Teams' `config.json`) and surfaces alerts as a toast plus red window borders. The user wants the information permanently visible in the Omarchy bar and the whole thing distributable through the Omarchy plugin marketplace with a one-command install.

## What Changes

- **BREAKING** Repackage the repository as an Omarchy shell plugin (`manifest.json` at the root, id `io.github.zakkoo.teams-for-linux-notifications`) installable with `omarchy plugin add https://github.com/zakkoo/teams-for-linux-notifications.git --enable`.
- **BREAKING** Remove the systemd unit, `install.sh`, `config.env`, `alert/alert.sh` and the red-border effect. The MQTT bridge becomes a child process of the bar widget, so it lives and dies with the shell.
- New bar widget showing the next upcoming event (title + countdown) within a configurable horizon, and a sticky "meeting now" state until the user joins the call or the event ends. Click opens the join link.
- Widget is hidden while Teams for Linux is not connected to the bridge.
- All settings (lead minutes, horizon, poll interval, toast on/off, MQTT port and prefix) are declared in the manifest schema so the shell renders a settings form; nobody edits shell.json by hand.
- Teams for Linux configuration is done from the widget popup: a "Connect Teams for Linux" button merges the required MQTT/Graph keys into Teams' `config.json` (with backup); a "Disconnect" button reverts them. This replaces the manual merge step.
- Toast notification on meeting start becomes an opt-in setting (default off).

## Capabilities

### New Capabilities
- `meeting-bar-widget`: what the bar shows for upcoming and started meetings, click behaviour, visibility rules, optional toast.
- `teams-connection`: lifecycle of the embedded MQTT bridge, calendar polling, and the connect/disconnect actions that edit Teams for Linux configuration.
- `plugin-settings`: the user-configurable settings, their defaults and bounds, and that they take effect without editing files.

### Modified Capabilities
<!-- none: the project has no specs yet -->

## Impact

- Repository layout changes completely; everything under `sources/`, `alert/`, `install.sh`, `config.env.example` is deleted. The nested `sources/02-teams-mqtt/openspec` and `.claude` copies go too.
- `tests/selfcheck.py` is adapted to the new bridge script.
- Users of the PoC must run `./install.sh --remove` once before installing the plugin (documented in README).
- External: Omarchy 4 shell (Quickshell), Teams for Linux with MQTT, Graph API and meeting-start detection support. Python 3 standard library only, no new dependencies.
