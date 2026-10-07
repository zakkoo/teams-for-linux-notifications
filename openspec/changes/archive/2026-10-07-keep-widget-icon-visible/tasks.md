# Tasks

## 1. Widget stays in the bar

- [x] 1.1 `BarWidget.qml`: set `visible: svc !== null` and `implicitWidth: row.implicitWidth + Style.space(14)` (drop the `visible ? … : 0` branch); verify with Teams for Linux closed and with it open but no meeting in the horizon that the calendar icon stays in the bar on every monitor
- [x] 1.2 `BarWidget.qml`: dim the glyph whenever `svc && !svc.connected` (replace the `setupMode` test on `glyph.color`); verify the icon is dimmed while Teams is quit, turns normal within 10 s of reconnect, and stays dimmed in setup mode
- [x] 1.3 `BarWidget.qml`: tooltip falls back to `svc.statusText()` when there is no event and no `meetingState.text` (keep the setup-mode "Click to connect Teams for Linux" wording); verify hovering the idle icon shows "Connected" / "Connected · no calendar received yet" / "Waiting for Teams for Linux (is it running?)" as appropriate
- [x] 1.4 Verify clicks in the idle state: left and right open the popup, middle does nothing (no error in `journalctl --user -u omarchy-shell` or the shell log); verify a shown meeting still joins on right-click and dismisses on middle-click
- [x] 1.5 `tests/test_plugin_structure.py`: add an assertion in `QmlContracts` that `BarWidget.qml` does not make `visible`/`implicitWidth` depend on `meetingState.kind`; verify `python3 -m unittest tests.test_plugin_structure` passes

## 2. Docs and release notes

- [x] 2.1 `README.md`: state that the icon is always in the bar, dimmed while Teams for Linux is not connected, and that the label appears only inside the horizon; verify the wording matches the tooltip strings in `Service.statusText()`
- [x] 2.2 `CHANGELOG.md`: add an unreleased entry describing the always-visible icon and dimmed disconnected state; verify it reads consistently with the 0.1.x entries

## 3. Release

- [x] 3.1 Bump `manifest.json` version to 0.1.3 and retitle the CHANGELOG.md "Unreleased" entry to 0.1.3; verify both read 0.1.3 and the test suite passes
