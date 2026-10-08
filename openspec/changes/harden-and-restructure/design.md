# Design

## Context

See proposal.md for motivation. What shapes the approach:

- `Model.js` is a `.pragma library` file loaded by QML and by Node (the test strips the pragma and evaluates the source). It must stay plain ES5-ish JavaScript with no `export`, no `class` fields, no modules.
- `labelState(events, nowMs, inCall, meetingStarted, pulseAtMs, horizonMin, dismissed)` does two jobs: classify one event (now / upcoming / none, with pulse adoption) and compose the bar label (in-call override, generic "Meeting started" fallback). `dueReminders` calls it once per event with a one-element list and inherits the composition it does not want, which is where the pulse-suppression bug comes from.
- `Service.qml` holds `dismissed`, `remindAt` and `inCallEvent`. QML emits no change signal for a `var` property handed back the same object, so every mutation already copies; the copies are just spelled out six times.
- `bridge.py` has one accept loop serving one client at a time, a `ticker` thread that calls into the same globals, and `emit` under a lock. Tests load the script as a module and reach into `b.state`, `b.client`, `b.PREFIX`, `b.print`, `b.emit`.
- `tests/test_plugin_structure.py` pins contracts by regex over the QML source. Several of its assertions name the current spelling (`Object.assign({}, remindAt)`), so the restructuring has to carry that test along.
- No installs are allowed on this machine and the project has no dependencies; nothing here needs any.

## Goals / Non-Goals

**Goals:**
- One obvious place for each rule: per-event classification, bar composition, reminder selection, popup ordering.
- Every Model entry point callable from a test with a single literal object, so a scenario reads as data.
- Bridge state owned by one object that a test can construct fresh, instead of module globals reset by hand.
- Each bug in the proposal has a failing test before its fix.
- Identical observable behaviour everywhere the proposal does not name a bug. The existing 19 Node and 64 Python tests keep passing (adapted to the new signatures, not weakened).

**Non-Goals:**
- No change to the MQTT wire handling beyond the error boundary, the keepalive timeout and the varint cap. No QoS 2, no multi-client.
- No change to the stdout state-line format, the CLI flags, shell.json keys or the manifest schema.
- No QML test runner; QML stays covered by the structure tests and by running the plugin.
- No persistence of dismissals across shell restarts.
- The reminder card Repeater still rebuilds its delegates whenever the reminder list changes (every 15 s tick). It is cosmetic and untouched.
- No TypeScript, no bundler, no new files beyond what is listed below.

## Decisions

### D1. Model.js: normalise once, classify per event, compose on top

Three layers, all pure functions in the same file:

1. `normalize(events, nowMs)` → sorted array of `{event, startMs, endMs}` with unparsable starts dropped (end defaults to start when unparsable, matching today's `isNaN` filtering on start only). Called once per evaluation; every other function takes its output.
2. `eventState(item, ctx)` → `{kind: "now" | "upcoming" | "none", minutes}` for one meeting, where `ctx` is `{nowMs, horizonMin, adoptedId}`. `adoptedId` is the id of the single event a meeting-started pulse adopts (computed once by `pulseAdoptee(list, ctx)`: the earliest event with |start − now| ≤ 5 min that has not ended, or null). Dismissed events are filtered before classification, not inside it.
3. `labelState(ctx)` composes the bar label from the list exactly as today: in-call branch first, then the first "now", then the generic "Meeting started" while the pulse TTL holds, then the first "upcoming". `dueReminders(ctx)` walks the list, skips the in-call event id, applies `eventState` + `toastDue` and the cap of three. `splitDay(ctx)` returns `{today, finished}` for the popup (today nearest-first, finished most-recent-first) and replaces the two `popupOrder` calls plus the filter in `Panel.qml`.

The context object is one shape for all entry points:

```
{ events, nowMs, inCall, inCallEventId, meetingStarted, pulseAtMs,
  horizonMin, leadMin, dismissed, remindAt, hidePast }
```

Unused keys are ignored, so a test passes only what the scenario is about. `toastDue`, `dismissUntil`, `snoozeMinutes` and `fmtTime` keep their signatures; they are already small and the card calls two of them by name.

Why not keep positional arguments and only fix the bug: nine positional arguments, six of them booleans or maps, is the thing that makes every call site unreadable and every new flag a shotgun edit. The fix for the pulse bug *is* the split into classify and compose; the context object is the cheap way to make the split callable.

Why not a class: `.pragma library` plus Node evaluation keeps this simplest as functions; there is no instance state.

Alternative considered: keep `labelState` as is and give `dueReminders` a `meetingStarted=false` call plus a separate adoption check. Rejected: it duplicates the adoption rule and leaves the mixed-purpose function in place.

### D2. Service.qml: two map helpers, locked in-call event, property for status

- `mapWith(map, id, value)` and `mapWithout(map, id)` return a copy via `Object.assign({}, map)`. `dismissEvent`, `restore`, `holdReminder` call them. The structure test changes from asserting the literal `Object.assign({}, remindAt)` to asserting that every write to `dismissed`/`remindAt` goes through `mapWith`/`mapWithout` and that those helpers copy.
- `inCallEvent` is set when `inCall` turns true (from the current label event, possibly null when the calendar has not arrived) and otherwise only when it is still null and the label now has an in-call event. It is never re-pointed. On `inCall` turning false it is dismissed and cleared, as today.
- `statusText` becomes `readonly property string statusText` with the same wording, so Panel and BarWidget bind to a property. The function stays as a one-line wrapper only if a structure test or caller needs the call syntax; otherwise callers switch to the property.
- A `restarting` flag is set by `onCommandChanged` before `running = false`; `onExited` clears it and skips the "bridge exited" error when it was set. `bridgeAlive`/`connected` still drop so the icon dims during the restart, as the spec requires.
- Model calls are built from one `readonly property var ctx` binding that gathers the service's properties; `meetingState`, `reminders` and the popup rows all read it.

### D3. bridge.py: a Broker object, framing stays functional

```
class Broker:
    state, client, prefix, lock, poll_minutes
    emit(**changes)            # dedupe + print, as today
    on_message(topic, payload) # topic → state
    request_calendar()         # snapshot self.client into a local, try/except Exception, log
    serve_forever(srv)         # accept loop; per client: Client(self, sock).serve() inside try/except Exception
    ticker()                   # thread body, loops request_calendar
class Client:
    __init__(broker, sock); serve() as today but:
      - CONNECT reads keepalive; sock.settimeout(1.5 * keepalive) when keepalive > 0
      - SUBSCRIBE updates broker.prefix and calls broker.emit / broker.request_calendar
      - PUBLISH calls broker.on_message
```

`varint`, `rdvar`, `mkstr`, `rdstr`, `read_exact`, `read_packet`, `parse_graph_events` stay module-level functions; they are pure and the tests use them directly. `read_packet` caps the remaining-length loop at four bytes and returns `None` beyond that (the client is then dropped like a closed socket). `rdstr` raises `ValueError` on a truncated length instead of silently returning a short string; the per-client `except Exception` turns that into a logged drop. `main()` builds one `Broker`, binds the socket, prints the initial line, starts the ticker thread and calls `serve_forever`.

`_bridge_helpers.FakeTeams` takes a `Broker` instead of the module and wires `Client(broker, server_side)`. Protocol tests construct a fresh `Broker` per subtest and capture `broker.emit` output through a `print` override on the instance (an injectable `out` callable defaulting to stdout), which removes the `b.state.update(...)` reset dance.

Why one class and not two or three: there is one broker and one client; the globals are the only thing that needs a home. More structure would be the over-engineering the ladder forbids.

Keepalive 0 means no timeout, per the MQTT spec; Teams for Linux's client library defaults to 60 s so the real case is covered.

### D4. teams-config.py

`load()` returns `{}` when the parsed root is not an object, so `connect` cannot crash on `[]`; the backup still preserves the original. Invalid JSON still fails loudly, as the existing test requires. Nothing else changes.

### D5. Tests mirror the layers

- `tests/model.test.js`: a `ctx(overrides)` builder and the same `ev()` helper; every existing test is kept with the same assertions, re-expressed with the builder. New tests: pulse does not suppress an upcoming card; pulse adopts only the earliest nearby event; `normalize` drops bad starts and sorts; `splitDay` matches the two-section spec scenario.
- `tests/test_bridge.py`: existing classes kept; `Protocol.both` builds a fresh `Broker`. New tests: a truncated SUBSCRIBE string drops the client and the next `FakeTeams` connects; a CONNECT with keepalive 1 and no traffic is dropped within ~2 s (`EndToEndSocket`); `request_calendar` with `client` set to `None` between check and publish does not raise (simulate with a client whose `publish` sets `broker.client = None` then raises `OSError`); a five-byte remaining length returns `None`.
- `tests/test_plugin_structure.py`: `test_reminder_is_drawn_in_process` asserts the helpers instead of the literal copies; a new assertion pins that `inCallEvent` is only assigned when null outside `onInCallChanged`; the bridge-arguments test is unchanged.
- `tests/test_teams_config.py`: one test for a non-object root.

## Risks / Trade-offs

- [Rewriting `labelState` could drift from a spec scenario the old tests did not pin] → every old test is kept verbatim in intent; the new builder only changes how arguments are passed. Run both suites after each layer, not at the end.
- [QML binding to a large `ctx` object re-evaluates `meetingState` and `reminders` whenever any input changes] → that is already the case today; the inputs are the same properties, just gathered in one place. No new evaluation triggers.
- [The structure test is regex-based; renaming helpers can break it silently] → the test and the QML change in the same task.
- [Socket timeout also fires while Teams is idle but alive] → Teams pings at its keepalive; 1.5× is the spec's own allowance. A false drop only costs one reconnect, which Teams does on its own.
- [Locking `inCallEvent` at call start could pin the wrong meeting when two overlap] → it picks what the label picked, which is what today's code also starts with; the only change is not re-pointing later.
- [Removing `popupOrder`] → it is only called from `Panel.qml` and the test; both move to `splitDay`. No external consumers.

## Migration Plan

Single release (0.3.5). No data migration: dismissals and snoozes live in memory only and reset with the shell as before. Rollback is reverting the commit; the bridge CLI, state line and settings keys are unchanged, so the old and new QML and scripts are interchangeable.
