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

  // The reminder card exists exactly while it is due: in-call, ended and
  // dismissed meetings already drop out of meetingState, and the 15 s tick
  // re-evaluates a snooze deadline without a timer of its own.
  readonly property bool reminderDue: toast && !inCall && !!meetingState.event
    && Model.toastDue(meetingState, nowMs, leadMinutes, remindAt[meetingState.event.id])

  function holdReminder(untilMs) {
    if (!meetingState.event) return
    var r = remindAt; r[meetingState.event.id] = untilMs; remindAt = r
  }
  function snooze() {
    var m = Model.snoozeMinutes(meetingState)
    if (m > 0) holdReminder(Date.now() + m * 60000)
  }
  function joinFromCard() {
    if (!meetingState.event) return
    join(meetingState.event.joinUrl)
    holdReminder(Infinity)
  }

  Loader {
    active: root.reminderDue
    source: Qt.resolvedUrl("ReminderCard.qml")
  }

  // Teams for Linux forwards argv to its running instance and opens meetup-join
  // links in the app (urlHandling.openMeetupJoinInApp defaults to true).
  function join(url) {
    if (!url) return
    Quickshell.execDetached(["sh", "-c", 'command -v teams-for-linux >/dev/null 2>&1 && exec teams-for-linux "$1" || exec xdg-open "$1"', "_", url])
  }

  function dismiss() {
    if (!meetingState.event) return
    var d = dismissed; d[meetingState.event.id] = true; dismissed = d
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
