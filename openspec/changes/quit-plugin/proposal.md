# Proposal

## Why

Once this plugin is on the bar, the only way off it is a terminal command the popup never mentions. The icon stays even when Teams is closed, and the bridge is started again whenever it exits, so a user who wants the plugin gone has no way to quit it from the plugin itself.

## What Changes

- The popup's settings section gains a Quit action. It disables the plugin the same way `omarchy plugin disable io.github.zakkoo.teams-for-linux-notifications` does: the widget leaves the bar and stays gone across shell restarts.
- Quit asks once before it runs, in the popup. A misclick next to Connect or Disconnect must not remove the widget.
- Quitting does not uninstall the plugin files and does not edit the Teams for Linux config. Connect and Disconnect stay as they are. Turning the plugin back on is `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications`, which the confirmation text names.
- The shell stores this widget's settings on its bar entry and drops that entry on disable, so a later enable comes back on the manifest defaults. Quit does not invent a second place to keep those settings.
- While the plugin is enabled, the icon stays in the bar as it does today, including when Teams is closed. Quit is the way off, not a new idle-hide mode.
- Disabling the plugin stops the bridge and does not start it again. A crash while the plugin is still enabled still restarts the bridge.

Assumption recorded here: "quit" means this persistent disable, not a hide that returns on the next shell start, and not `omarchy plugin remove`.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `meeting-bar-widget`: a Quit action in the settings section of the popup disables the plugin after a confirmation, and tells the user how to enable it again.
- `teams-connection`: disabling the plugin (the Quit action, or removing the widget from the bar) stops the bridge and does not restart it, and does not rewrite the Teams for Linux config.

## Impact

- `Panel.qml`: the Quit control, its confirmation, and a process that runs `omarchy plugin disable` for this plugin's manifest id. Failure stays in the popup; success removes the widget.
- `Service.qml`: tearing the service down must not arm the bridge restart timer. Today `onExited` always schedules a restart, including when destruction sets `bridge.running = false`.
- `tests/test_plugin_structure.py`: the Quit command uses the manifest id, and destruction does not schedule a restart.
- `manifest.json` version and `CHANGELOG.md`: user-visible change, so a patch release.
- No new dependencies. Re-enable stays the existing `omarchy plugin enable` command. The shell has no separate in-plugin way back once the widget is gone.
