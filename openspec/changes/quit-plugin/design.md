# Design

## Context

See proposal.md for why. The constraints that pick the approach:

- This plugin is both a bar widget and a service (`manifest.json` kinds). The shell treats a third-party plugin as enabled while its id sits in `shell.json`. `omarchy plugin disable <id>` is `omarchy-shell shell setPluginEnabled <id> false`, which deletes the bar entry. With no entry left, the service is destroyed. `Service.qml` `Component.onDestruction` already sets `bridge.running = false`.
- `bridge.onExited` always calls `restartTimer.restart()` (3 seconds, then `bridge.running = true`). Stopping the process from `onDestruction` can take that path before the timer is destroyed, so a quit can leave `scripts/bridge.py` running.
- Settings live on the bar entry. Disable deletes that object. Enable inserts a fresh `{ "id": "<manifest id>" }` in the default section, so the manifest defaults apply. There is no other settings store.
- The popup already runs `scripts/teams-config.py` from a `Process` for Connect and Disconnect, and shows a one-line hint when that process exits non-zero. There is no dialog component.
- `tests/test_plugin_structure.py` pins QML contracts with regexes, including "the bridge must die with the service" and "a deliberate restart is not an error".

## Goals / Non-Goals

**Goals:**

- One popup control that ends as `omarchy plugin disable` for this plugin's manifest id, after a confirmation that names the enable command.
- Service teardown never schedules another bridge start. A crash while the plugin is still enabled still does.
- Connect, Disconnect, and Quit do not share a process.

**Non-Goals:**

- No uninstall (`omarchy plugin remove`), no edit of `shell.json` from the plugin, no second store for the settings disable throws away.
- No change to Connect or Disconnect, and no call to `teams-config.py` from Quit.
- No change to the idle icon. An enabled plugin still occupies the bar when Teams is closed.
- No new manifest setting. Quit is an action, not a preference.

## Decisions

### D1. Disable through the shell command, not by writing shell.json

The Quit process runs `omarchy plugin disable io.github.zakkoo.teams-for-linux-notifications` (the id already required to match `moduleName`). The shell then removes the bar entry, persists it, and destroys the service on every monitor. Reminder cards are a `Loader` inside `Service.qml`, so they go with the service.

Alternatives: editing `~/.config/omarchy/shell.json` from the plugin races the shell's writer and skips the service unload. `execDetached` cannot report a non-zero exit, so a failed quit would look like nothing happened. A plugin-facing "disable me" API does not exist on the widget host; the CLI is the contract `omarchy plugin disable` already wraps.

### D2. Two clicks in the settings fold, not a dialog

`quitArmed` starts false. The control sits at the bottom of the settings column, under a separator, after Connect / Disconnect. First click sets `quitArmed`, changes the button to "Remove from the bar", and shows a caption that includes `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications` and says the Teams for Linux config is left as it is. Second click starts the process. `close()` and closing the settings fold set `quitArmed` back to false, so the next open shows "Quit plugin" again.

The button is disabled while that process runs, and while the Connect / Disconnect process runs. A non-zero exit sets the existing hint line to `Could not quit the plugin (see shell log)` and clears `quitArmed`. A zero exit needs no success text: the widget is removed.

### D3. An unloading flag in front of the restart

Add `property bool unloading: false` on the bridge. `Component.onDestruction` sets `unloading = true`, stops `restartTimer`, then sets `bridge.running = false`. `onExited` returns immediately when `unloading` is set, so it neither writes `bridgeError` nor calls `restartTimer.restart()`. The settings-change `restarting` flag stays as it is: that path still restarts, quietly.

An early return is enough. The crash path (`!unloading`) still reaches `restartTimer.restart()`, which is what the "crash while enabled" scenario checks.

### D4. Tests stay structural, plus one shell pass

Extend `QmlContracts` so `Panel.qml` contains the disable command with the manifest id and the enable command string, and so `onExited` consults `unloading` before `restartTimer.restart()`. A shell pass covers the two clicks, the still-gone-after-restart check, and `pgrep` showing no `scripts/bridge.py` for this plugin. That pass is manual because this repo has no QML runner.

## Risks / Trade-offs

- [Disable deletes the bar entry, so a custom horizon and the other settings are gone on the next enable] → Accepted. Called out in the confirmation only as the enable command; the spec scenario "Enable again uses defaults" is the contract. We do not copy the entry aside.
- [An in-flight Connect can still finish after Quit and edit the Teams config] → Quit refuses to start while that process is running. The reverse is the same. Quit itself never calls `teams-config.py`.
- [`omarchy` must be on the shell's PATH] → Same as every other `omarchy` invocation from a user session. A missing binary is a non-zero exit and the failure hint, and the widget stays.
- [`onExited` during teardown is timing-dependent] → The flag does not rely on the timer being destroyed first. Stopping the timer as well covers a restart that was already queued by a crash just before quit.
- [The structure test can only see the source, not that the shell actually removes the widget] → The manual shell pass is a task, not a substitute for the regex.

## Migration Plan

No config migration. Shipping the plugin update adds the button for anyone who already has it enabled. Rollback is installing the previous plugin version; a user who already quit re-enables with `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications` and gets the defaults, on this version or the previous one.
