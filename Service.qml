import QtQuick
import Quickshell
import Quickshell.Io
import "." as Plugin
import "Model.js" as Model

// Mounted once per shell. The bar builds one widget per monitor; the bridge,
// its state, the toast bookkeeping and the dismissals must not be per screen.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property string omarchyPath: ""

  // Pushed by the widget from its shell.json settings.
  property int horizonMinutes: 15
  property int leadMinutes: 2
  property bool toast: false
  property int pollMinutes: 5
  property int mqttPort: 1883
  property string mqttPrefix: "teams"

  // Bridge state, one JSON line per change on stdout.
  property bool connected: false
  property bool inCall: false
  property bool meetingStarted: false
  property real pulseAt: 0
  property string bridgeError: ""
  property var events: []
  property bool bridgeAlive: false
  property bool teamsWired: true   // teams-config.py status

  property real nowMs: Date.now()
  // Per event id: skipped for good (middle-click, dismiss once started, left its call).
  property var dismissed: ({})
  // Per event id: show the reminder card no earlier than this (ms). A snooze
  // deadline, the start after an early dismiss, or Infinity once joined.
  property var remindAt: ({})
  // The meeting the current call belongs to. Fixed when the call starts (or
  // the first time the calendar matches during it) and never re-pointed, so
  // an overrunning call cannot mark the *next* meeting handled.
  property var inCallEvent: null

  // A meeting only enters the bar inside the horizon, so a lead time beyond
  // it could never fire; cap it there so the setting stays honest.
  readonly property int effectiveLead: Math.min(leadMinutes, horizonMinutes)

  // Everything Model needs, gathered once; every Model call reads this.
  readonly property var ctx: ({
    events: events, nowMs: nowMs, inCall: inCall,
    inCallEventId: inCall && inCallEvent ? inCallEvent.id : "",
    meetingStarted: meetingStarted, pulseAtMs: pulseAt,
    horizonMin: horizonMinutes, leadMin: effectiveLead,
    dismissed: dismissed, remindAt: remindAt
  })

  readonly property var meetingState: Model.labelState(ctx)
  readonly property bool urgent: meetingState.kind === "now" || meetingState.kind === "started"
  readonly property bool setupMode: !connected && !teamsWired
  // Reminder cards exist exactly while due: in-call, ended and dismissed
  // meetings drop out on their own, and the 15 s tick re-evaluates snooze
  // deadlines without a timer. One card per due meeting, capped in the model.
  readonly property var reminders: toast ? Model.dueReminders(ctx) : []

  readonly property string statusText: bridgeError ? bridgeError
    : !bridgeAlive ? "Starting bridge…"
    : !connected ? (teamsWired ? "Waiting for Teams for Linux (is it running?)" : "Teams for Linux is not connected yet")
    : events.length === 0 ? "Connected · no calendar received yet"
    : "Connected"

  readonly property string scriptDir: {
    var url = Qt.resolvedUrl("scripts/").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.slice(7)) : url
  }

  function applyLine(line) {
    var s
    try { s = JSON.parse(line) } catch (e) { return }
    bridgeAlive = true
    if (s.meetingStarted && !meetingStarted) pulseAt = Date.now()
    connected = s.connected === true
    inCall = s.inCall === true
    meetingStarted = s.meetingStarted === true
    bridgeError = s.error || ""
    events = s.events || []
    nowMs = Date.now()
  }

  // dismissed and remindAt are only ever replaced with a copy: QML emits no
  // change for a var property handed the same object back, and the cards and
  // bar must react at once. These two helpers are the only writers.
  function mapWith(map, id, value) { var m = Object.assign({}, map); m[id] = value; return m }
  function mapWithout(map, id) { var m = Object.assign({}, map); delete m[id]; return m }

  function holdReminder(event, untilMs) {
    if (!event) return
    remindAt = mapWith(remindAt, event.id, untilMs)
  }
  function dismissEvent(event) {
    if (!event) return
    dismissed = mapWith(dismissed, event.id, true)
  }
  function restore(event) {
    if (!event) return
    dismissed = mapWithout(dismissed, event.id)
    remindAt = mapWithout(remindAt, event.id)
  }
  function dismiss() { dismissEvent(meetingState.event) }   // bar middle-click: skip the shown meeting

  // Changing the reminder rule starts over: snoozes and "joined" marks made
  // under the old rule no longer mean anything.
  onToastChanged: remindAt = ({})
  onLeadMinutesChanged: remindAt = ({})

  // state: one entry of `reminders` ({event, kind, minutes}).
  function snooze(state) {
    var m = Model.snoozeMinutes(state)
    if (m > 0) holdReminder(state.event, Date.now() + m * 60000)
  }
  function joinFromCard(event) {
    if (!event) return
    join(event.joinUrl)
    holdReminder(event, Infinity)
  }
  // Dismiss on a card: before the start it only silences the early reminder
  // (the start announces itself); once started it skips the meeting for good.
  function dismissReminder(state) {
    var until = Model.dismissUntil(state)
    if (until === null) dismissEvent(state.event)
    else holdReminder(state.event, until)
  }

  // Once you leave the call its meeting is handled: the bar must not turn
  // urgent again and no card may return for it.
  onInCallChanged: {
    if (inCall) inCallEvent = meetingState.event
    else { dismissEvent(inCallEvent); inCallEvent = null }
  }
  // The calendar may arrive after the call started; adopt the match once, never re-point.
  onMeetingStateChanged: if (inCall && inCallEvent === null && meetingState.event) inCallEvent = meetingState.event

  Loader {
    active: root.reminders.length > 0
    source: Qt.resolvedUrl("ReminderCard.qml")
  }

  // Teams for Linux forwards argv to its running instance and opens meetup-join
  // links in the app (urlHandling.openMeetupJoinInApp defaults to true).
  function join(url) {
    if (!url) return
    Quickshell.execDetached(["sh", "-c", 'command -v teams-for-linux >/dev/null 2>&1 && exec teams-for-linux "$1" || exec xdg-open "$1"', "_", url])
  }

  function refreshWired() { wiredProc.running = true }

  Process {
    id: bridge
    // Set before a deliberate stop (settings change) so the exit is not reported as an error.
    property bool restarting: false
    command: ["/usr/bin/python3", root.scriptDir + "bridge.py",
              "--port", String(root.mqttPort), "--prefix", root.mqttPrefix, "--poll-minutes", String(root.pollMinutes)]
    running: true
    stdout: SplitParser { onRead: function(line) { root.applyLine(line) } }
    stderr: SplitParser { onRead: function(line) { console.log("teams-bridge: " + line) } }
    onExited: function(code) {
      root.bridgeAlive = false
      root.connected = false
      if (!restarting && !root.bridgeError) root.bridgeError = "bridge exited (" + code + ")"
      restarting = false
      restartTimer.restart()
    }
    onCommandChanged: {
      if (!running) return
      restarting = true
      running = false
      restartTimer.restart()
    }
  }

  Timer { id: restartTimer; interval: 3000; onTriggered: if (!bridge.running) bridge.running = true }

  Process {
    id: wiredProc
    command: ["/usr/bin/python3", root.scriptDir + "teams-config.py", "status",
              "--port", String(root.mqttPort), "--prefix", root.mqttPrefix]
    running: true
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.teamsWired = String(text).trim() === "connected" }
  }

  Timer { interval: 15000; running: true; repeat: true; onTriggered: root.nowMs = Date.now() }

  Component.onCompleted: Plugin.ServiceRegistry.instance = root
  Component.onDestruction: {
    bridge.running = false
    if (Plugin.ServiceRegistry.instance === root) Plugin.ServiceRegistry.instance = null
  }
}
