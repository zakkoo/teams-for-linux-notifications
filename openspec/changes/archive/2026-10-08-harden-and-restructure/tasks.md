# Tasks

## 1. Model.js: layered pure logic with a context object

- [x] 1.1 Add `normalize(events)` (parsed startMs/endMs, unparsable starts dropped, sorted by start) and `pulseAdoptee(list, ctx)` (earliest unfinished event within ±5 min, or null); verify with new Node tests for bad input, ordering and the single adoptee.
- [x] 1.2 Add `eventState(item, ctx)` returning `{kind: now|upcoming|none, minutes}` for one meeting, using `adoptedId` instead of the generic pulse rule; verify with Node tests for "now", pulse-adopted "now", upcoming within and outside the horizon, ended.
- [x] 1.3 Rewrite `labelState(ctx)` as a composition over `normalize` + `eventState` (in-call branch, first "now", generic "Meeting started" within the pulse TTL, first "upcoming", none) with the same `{kind, event, title, suffix, text, minutes}` output; verify every existing label test passes once re-expressed with a `ctx()` builder and unchanged assertions.
- [x] 1.4 Rewrite `dueReminders(ctx)` over `eventState` + `toastDue`, keeping the in-call exemption, `remindAt` hold-back and the cap of three; verify the existing due-reminder tests pass and add the two bug tests: an unmatched pulse does not hold back an upcoming card, and only the earliest nearby event becomes "now" under a pulse.
- [x] 1.5 Replace `popupOrder` with `splitDay(ctx)` returning `{today, finished}` (today nearest-first, finished most-recent-first, `hidePast` honoured); verify a Node test reproduces the spec's "Two sections" scenario and the old popup-order assertions.
- [x] 1.6 Fix the stale "tests/model-check.js" comment at the top of Model.js and document the context shape in one comment block; verify `node --test tests/model.test.js` passes with every pre-existing test present by name.

## 2. Service.qml and Panel.qml: consume the context, lock the call's meeting, quiet restarts

- [x] 2.1 Add a `readonly property var ctx` gathering events, nowMs, inCall, inCallEventId, meetingStarted, pulseAt, horizonMinutes, effectiveLead, dismissed, remindAt and bind `meetingState` and `reminders` to the new Model entry points; verify `qmllint --import disable --unqualified disable Service.qml` reports no error and the structure suite passes.
- [x] 2.2 Add `mapWith(map, id, value)` / `mapWithout(map, id)` copying via `Object.assign({}, map)` and route `dismissEvent`, `restore` and `holdReminder` through them; update `test_reminder_is_drawn_in_process` to assert the helpers copy and that no other line writes `dismissed`/`remindAt`; verify the structure suite passes.
- [x] 2.3 Lock `inCallEvent`: set it when `inCall` turns true, and otherwise only while it is null; never re-point it; add a structure-test assertion that the only assignment outside `onInCallChanged` is guarded by `inCallEvent === null`; verify the suite passes.
- [x] 2.4 Turn `statusText()` into `readonly property string statusText` with identical wording and switch Panel.qml and BarWidget.qml to the property; verify qmllint on all three files reports no error and the structure suite passes.
- [x] 2.5 Add a `restarting` flag set in the bridge's `onCommandChanged` and consumed in `onExited` so a deliberate restart sets no "bridge exited" error while `bridgeAlive`/`connected` still drop; verify by a structure-test assertion that `onExited` checks the flag before writing `bridgeError`.
- [ ] 2.6 Replace Panel.qml's `rows`/`pastRows`/`pastCount` with one `Model.splitDay` call (hidePast passed in `ctx`); verify qmllint reports no error and the Today/Finished sections behave as in the spec when the plugin is run (`omarchy plugin validate .` plus a manual check with a finished and an upcoming meeting).

## 3. bridge.py: Broker object, error boundary, keepalive timeout

- [x] 3.1 Move `state`, `client`, `PREFIX`, `lock`, `emit`, `on_message`, `request_calendar` and `ticker` into a `Broker` class with an injectable output callable; keep framing helpers and `parse_graph_events` module-level; update `_bridge_helpers.FakeTeams` to take a `Broker`; verify every existing `Framing`, `Protocol`, `Process` and `EndToEndSocket` test passes with the `both` decorator building a fresh `Broker` per subtest.
- [x] 3.2 Make `request_calendar` snapshot `self.client` into a local and wrap the publish in `try/except Exception` with a log line; verify a new test where a fake client's `publish` clears `broker.client` and raises does not propagate and the ticker loop continues.
- [x] 3.3 Wrap each client's `serve()` in `serve_forever` with `except Exception` (log, close, emit disconnected); make `rdstr` raise `ValueError` on a truncated length; verify a new `Protocol` test that a SUBSCRIBE with a truncated topic string drops that client, emits `connected: false`, and a fresh `FakeTeams` is served afterwards.
- [x] 3.4 Read the keepalive from CONNECT and set `sock.settimeout(1.5 * keepalive)` when it is non-zero; verify a new `EndToEndSocket` test connecting with keepalive 1, sending nothing, sees `connected: false` within 3 s and a second connection is then served.
- [x] 3.5 Cap `read_packet`'s remaining-length loop at four bytes, returning `None` beyond that; verify a new `Framing` test with five continuation bytes returns `None`.
- [x] 3.6 Keep `main()` behaviour (initial state line, port-in-use error, argparse exit 2) on the Broker; verify the `Process` tests pass unchanged.

## 4. teams-config.py

- [x] 4.1 Make `load()` return `{}` when the JSON root is not an object; verify a new test that `connect` on a config.json containing `[]` succeeds, writes the managed keys and leaves a backup, while invalid JSON still fails loudly.

## 5. Integration and docs

- [x] 5.1 Run `python3 -m unittest discover -s tests -v` and `node --test tests/model.test.js`; verify both report zero failures and the Node suite still contains every pre-existing test name.
- [ ] 5.2 Run the plugin in the shell and walk the bug scenarios by hand: card appears for a meeting inside its lead time while the bar shows "Meeting started"; leaving an overrunning call leaves the next meeting urgent; killing Teams for Linux with SIGKILL dims the icon within 90 s and a restarted Teams reconnects; changing the poll interval restarts the bridge without an error in the status text; verify each observed outcome matches the spec scenario.
- [x] 5.3 Update the README development section to name the Model layers and the `ctx` object in one sentence each; verify the documented commands run as written.

## 6. Release

- [x] 6.1 Bump `version` in manifest.json to 0.3.5 and add a matching `## 0.3.5` CHANGELOG.md entry (one short paragraph: the five fixes in user terms, plus a line that the code was restructured with no other behaviour change); verify `test_marketplace_files_present` passes and the top CHANGELOG heading equals the manifest version.
- [x] 6.2 Commit with the release message style of the existing history and tag `v0.3.5`; verify `git tag` lists it and the tag points at the commit that contains the manifest bump.
