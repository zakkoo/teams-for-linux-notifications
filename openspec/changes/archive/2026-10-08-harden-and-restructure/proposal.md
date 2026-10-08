# Proposal

## Why

The last eight releases were all fixes to the same few places: the bar label state machine, the reminder bookkeeping in the service, and the bridge. The code works, but its shape makes each change risky: the label logic takes seven to nine positional arguments and is reused for a purpose it was not written for, the service keeps three ad-hoc maps mutated from six places, and the bridge runs on module globals shared across threads. Reviewing the code for this change turned up five real logic errors that this shape hid.

## What Changes

Behaviour stays as it is, except where it was wrong. Every existing spec scenario and every existing test still holds.

**Bugs fixed (user-visible, so a release follows):**
- A meeting-started pulse from Teams that matches no calendar event suppresses every reminder card for up to ten minutes: a meeting that reaches its lead time in that window gets no card (verified with the current Model.js).
- The meeting a call "belongs to" can be re-pointed mid-call: once the joined meeting's end time passes while the user is still in the call, the next meeting on the list is adopted, and leaving the call then marks that later meeting as handled, so it never turns the bar urgent or shows a card.
- The bridge's calendar poll thread can die on a race when Teams disconnects between the connection check and the publish; polling then silently stops until the bridge is restarted.
- A malformed MQTT packet (truncated string, bad varint, undecodable UTF-8) kills the whole bridge process instead of dropping that client.
- A Teams connection that dies without a TCP close (crash, suspend) wedges the bridge: it never times out the dead socket, reports "connected" forever, and cannot accept the reconnecting Teams.
- Minor: the remaining-length varint is unbounded (the protocol caps it at four bytes); the Teams config helper crashes on a config.json whose root is not an object; a deliberate bridge restart after a settings change briefly shows "bridge exited" as an error.

**Restructuring (no behaviour change):**
- Model.js: events are normalised once (parsed times, unparsable ones dropped, sorted). A per-event classifier gives one meeting's own state (now / upcoming / none), and the bar label and the reminder list are both composed from it. Every entry point takes one context object instead of a positional argument list. The popup gets a single split into today and finished rows.
- Service.qml: the dismissed, remind-at and in-call-event state is managed through two small map helpers instead of six inline copies; status text becomes a property so it re-evaluates like everything else; a deliberate restart is distinguished from a crash.
- bridge.py: the module globals (state, client, prefix) move into one broker object that owns emit, message handling, calendar requests and the accept loop. Framing helpers stay as plain functions. Each client gets a keepalive-derived socket timeout and its own error boundary.
- Tests: the Node suite is rewritten against the context-object API with the same scenarios, plus one test per bug above. The bridge tests address the broker object instead of module globals, plus tests for the malformed packet, the poll race and the keepalive timeout. The structure test that checks copy-on-write of the maps follows the helpers.
- The README's development section and the stale comment in Model.js are updated.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `meeting-bar-widget`: the reminder card requirement gains the rule that a card is judged on the meeting alone, so an unmatched meeting-started pulse cannot hold it back; the reminder card buttons requirement gains the rule that the meeting a call belongs to is fixed when the call starts.
- `teams-connection`: the bridge lifecycle requirement gains the rules that a bad packet drops only that client, that a silent client is dropped after its keepalive lapses, and that calendar polling survives reconnects.

## Impact

- Code: `Model.js`, `Service.qml`, `Panel.qml` (consumes the new split helper), `scripts/bridge.py`, `scripts/teams-config.py`.
- Tests: `tests/model.test.js`, `tests/test_bridge.py`, `tests/_bridge_helpers.py`, `tests/test_plugin_structure.py`, `tests/test_teams_config.py`.
- Docs: `README.md` development section, `CHANGELOG.md`, `manifest.json` version.
- No new dependencies. The MQTT wire protocol, the stdout state line format, the shell.json setting keys and the manifest schema are unchanged. `BarWidget.qml` and `ReminderCard.qml` call the same service functions as before.
