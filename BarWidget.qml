import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.zakkoo.teams-for-linux-notifications"

  // --- settings (schema in manifest.json)
  readonly property int horizonMinutes: setting("horizonMinutes", 15)
  readonly property int leadMinutes: setting("leadMinutes", 2)
  readonly property bool toast: setting("toast", false) === true
  readonly property int pollMinutes: setting("pollMinutes", 5)
  readonly property int mqttPort: setting("mqttPort", 1883)
  readonly property string mqttPrefix: String(setting("mqttPrefix", "teams"))

  // --- bridge state, one JSON line per change on stdout
  property bool connected: false
  property bool inCall: false
  property bool meetingStarted: false
  property real pulseAt: 0
  property string bridgeError: ""
  property var events: []
  property bool bridgeAlive: false

  // Teams config wired? (teams-config.py status). While not, show a dim icon so
  // the Connect button is reachable; otherwise hide when Teams is away.
  property bool teamsWired: true

  property real nowMs: Date.now()
  property var dismissed: ({})
  property var toasted: ({})

  readonly property var meetingState: Model.labelState(events, nowMs, inCall, meetingStarted, pulseAt, horizonMinutes, dismissed)
  readonly property bool urgent: meetingState.kind === "now" || meetingState.kind === "started"
  readonly property bool setupMode: !connected && !teamsWired
  readonly property string icon: "\u{F0ED}"
  readonly property string label: setupMode ? "" : meetingState.text
  property real maxLabelWidth: 220

  readonly property string scriptDir: {
    var url = Qt.resolvedUrl("scripts/").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.slice(7)) : url
  }

  visible: setupMode || (connected && meetingState.kind !== "none")
  implicitWidth: visible ? row.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

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

  onMeetingStateChanged: {
    if (!toast || !meetingState.event || toasted[meetingState.event.id]) return
    if (!Model.toastDue(meetingState, nowMs, leadMinutes)) return
    var t = toasted; t[meetingState.event.id] = true; toasted = t
    var args = ["omarchy-notification-send", "-u", "critical", "--app-name", "Teams Meetings",
                meetingState.kind === "now" ? "Meeting now" : "Meeting in " + meetingState.minutes + " min", meetingState.event.subject]
    if (meetingState.event.joinUrl) args.push("--exec", "xdg-open", meetingState.event.joinUrl)
    Quickshell.execDetached(args)
  }

  function openJoin() {
    if (meetingState.event && meetingState.event.joinUrl) Quickshell.execDetached(["xdg-open", meetingState.event.joinUrl])
    else togglePanel()
  }

  function dismiss() {
    if (!meetingState.event) return
    var d = dismissed; d[meetingState.event.id] = true; dismissed = d
  }

  function refreshWired() { wiredProc.running = true }

  // --- bridge process: lives with the widget, restarts on exit, restarts on relevant settings change
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

  // --- popup
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = root
    if ("hostWidget" in target) target.hostWidget = root
  }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  // --- label
  readonly property color fg: root.bar ? (root.urgent ? root.bar.urgent : root.bar.barForeground) : "white"

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.setupMode ? Qt.darker(root.fg, 1.8) : root.fg
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.vertical && root.label !== ""

      Text {
        id: labelText
        textFormat: Text.PlainText
        text: root.label
        color: root.fg
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
        property bool needsScroll: implicitWidth > scrollClip.width
        x: needsScroll ? x : 0
        NumberAnimation on x {
          running: labelText.needsScroll && !root.opened
          loops: Animation.Infinite
          duration: Math.max(6000, labelText.implicitWidth * 25)
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    onEntered: if (root.bar) root.bar.showTooltip(root, root.setupMode ? "Right-click to connect Teams for Linux"
                                                        : (root.meetingState.event ? Model.fmtTime(root.meetingState.event.start) + " " + root.meetingState.event.subject : root.meetingState.text))
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton || root.setupMode) root.togglePanel()
      else if (mouse.button === Qt.MiddleButton) root.dismiss()
      else root.openJoin()
    }
  }
}
