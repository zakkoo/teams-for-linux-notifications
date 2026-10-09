# Tasks

## 1. Bridge stays stopped after quit

- [x] 1.1 `Service.qml`: add `unloading` on the bridge, default false. In `Component.onDestruction`, set `unloading = true`, stop `restartTimer`, then set `bridge.running = false`. In `onExited`, return immediately when `unloading` is set, before `bridgeError` is written and before `restartTimer.restart()`. Leave the settings-change `restarting` path as it is. Verify `qmllint --import disable --unqualified disable Service.qml` reports no error.
- [x] 1.2 `tests/test_plugin_structure.py`: assert `onExited` checks `unloading` before `restartTimer.restart()`, and that `onDestruction` sets `unloading = true` before `bridge.running = false`. Verify `python3 -m unittest tests.test_plugin_structure` passes.

## 2. Quit control in the popup

- [x] 2.1 `Panel.qml`: at the bottom of the settings column, after Connect / Disconnect, add a separator and a "Quit plugin" button on its own `Process` whose command is `omarchy plugin disable io.github.zakkoo.teams-for-linux-notifications`. The first click only sets `quitArmed` and shows "Remove from the bar" plus a caption that contains `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications` and says the Teams for Linux config is left unchanged. The second click starts the process. `close()` and closing the settings fold clear `quitArmed`. The button stays disabled while this process or the Connect / Disconnect process is running. A non-zero exit sets the hint to `Could not quit the plugin (see shell log)` and clears `quitArmed`. Verify `qmllint --import disable --unqualified disable Panel.qml` reports no error.
- [x] 2.2 `tests/test_plugin_structure.py`: assert `Panel.qml` contains that disable command with the manifest id, the string `Quit plugin`, and the enable command, and that the quit process is not `actionProc` and does not invoke `teams-config.py`. Verify `python3 -m unittest tests.test_plugin_structure` passes.
- [x] 2.3 `README.md`: say that Settings & connection → Quit plugin takes the widget off the bar, and that `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications` puts it back. Verify the enable command in the README matches the caption string in `Panel.qml`.

## 3. Shell check

- [ ] 3.1 With the plugin enabled in the running shell, open the popup settings, click "Quit plugin" once and confirm the widget is still there and the caption names the enable command, then click "Remove from the bar". Verify the widget and any reminder card are gone, `pgrep -af scripts/bridge.py` shows no bridge for this plugin ten seconds later, and a shell restart does not bring the widget or the bridge back. Then run `omarchy plugin enable io.github.zakkoo.teams-for-linux-notifications` and verify the widget returns on the manifest defaults (horizon 15). Verify Disconnect still only edits the Teams config and leaves the widget in place.

## 4. Release

- [x] 4.1 Bump `version` in `manifest.json` from 0.3.10 to 0.3.11 and add a `## 0.3.11` heading at the top of `CHANGELOG.md` with one short paragraph in the style of the 0.3.10 entry: Quit plugin in the popup settings asks once, then removes the widget from the bar and stops its bridge until the plugin is enabled again; the Teams for Linux config is left alone, and enabling again starts from the default settings. Verify the manifest version and the top changelog heading are both 0.3.11, and `python3 -m unittest discover -s tests` passes.
