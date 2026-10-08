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
  property var dismissed: ({})
  // Per event id: show the reminder card no earlier than this (ms). A snooze
  // deadline, or Infinity once the user joined from the card.
  property var remindAt: ({})

  readonly property var meetingState: Model.labelState(events, nowMs, inCall, meetingStarted, pulseAt, horizonMinutes, dismissed)
  readonly property bool urgent: meetingState.kind === "now" || meetingState.kind === "started"
  readonly property bool setupMode: !connected && !teamsWired

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

  // Reminder cards exist exactly while due: in-call, ended and dismissed
  // meetings drop out on their own, and the 15 s tick re-evaluates snooze
  // deadlines without a timer. One card per due meeting, capped in the model.
  // A meeting only enters the bar inside the horizon, so a lead time beyond
  // it could never fire; cap it there so the setting stays honest.
  readonly property int effectiveLead: Math.min(leadMinutes, horizonMinutes)
  readonly property var reminders: toast
    ? Model.dueReminders(events, nowMs, inCall && inCallEvent ? inCallEvent.id : "", meetingStarted, pulseAt, horizonMinutes, dismissed, effectiveLead, remindAt) : []

  // Changing the reminder rule starts over: snoozes and "joined" marks made
  // under the old rule no longer mean anything.
  onToastChanged: remindAt = ({})
  onLeadMinutesChanged: remindAt = ({})

  // Both maps are replaced with a copy: QML emits no change for a var property
  // that is handed the same object back, and the cards must react at once.
  function holdReminder(event, untilMs) {
    if (!event) return
    var r = Object.assign({}, remindAt); r[event.id] = untilMs; remindAt = r
  }
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

  // The meeting you were in: once you leave the call it is handled, so the
  // bar must not turn urgent again and no card may return for it.
  property var inCallEvent: null
  onInCallChanged: {
    if (inCall) inCallEvent = meetingState.event
    else { dismissEvent(inCallEvent); inCallEvent = null }
  }
  onMeetingStateChanged: if (inCall && meetingState.event) inCallEvent = meetingState.event

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

  function dismissEvent(event) {
    if (!event) return
    var d = Object.assign({}, dismissed); d[event.id] = true; dismissed = d
  }
  function dismiss() { dismissEvent(meetingState.event) }   // bar middle-click: skip the shown meeting
  function restore(event) {
    if (!event) return
    var d = Object.assign({}, dismissed); delete d[event.id]; dismissed = d
    var r = Object.assign({}, remindAt); delete r[event.id]; remindAt = r
  }

  function refreshWired() { wiredProc.running = true }

  function statusText() {
    if (bridgeError) return bridgeError
    if (!bridgeAlive) return "Starting bridge…"
    if (!connected) return teamsWired ? "Waiting for Teams for Linux (is it running?)" : "Teams for Linux is not connected yet"
    if (events.length === 0) return "Connected · no calendar received yet"
    return "Connected"
  }

  Process {
    id: bridge
    command: ["/usr/bin/python3", root.scriptDir + "bridge.py",
              "--port", String(root.mqttPort), "--prefix", root.mqttPrefix, "--poll-minutes", String(root.pollMinutes)]
    running: true
    stdout: SplitParser { onRead: function(line) { root.applyLine(line) } }
    stderr: SplitParser { onRead: function(line) { console.log("teams-bridge: " + line) } }
    onExited: function(code) {
      root.bridgeAlive = false
      root.connected = false
      if (!root.bridgeError) root.bridgeError = "bridge exited (" + code + ")"
      restartTimer.restart()
    }
    onCommandChanged: {
      if (!running) return
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
