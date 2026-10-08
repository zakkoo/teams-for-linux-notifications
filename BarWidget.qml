import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "." as Plugin
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.zakkoo.teams-for-linux-notifications"

  // One service per shell; this widget exists once per monitor and only renders.
  readonly property var svc: Plugin.ServiceRegistry.instance

  function pushSettings() {
    if (!svc) return
    svc.horizonMinutes = setting("horizonMinutes", 15)
    svc.leadMinutes = setting("leadMinutes", 2)
    svc.toast = setting("toast", false) === true
    svc.pollMinutes = setting("pollMinutes", 5)
    svc.mqttPort = setting("mqttPort", 1883)
    svc.mqttPrefix = String(setting("mqttPrefix", "teams"))
    svc.nowMs = Date.now()   // re-evaluate label, reminder and countdowns now, not at the next tick
  }
  onSvcChanged: { pushSettings(); injectPanel() }
  onSettingsChanged: { pushSettings(); injectPanel() }
  Component.onCompleted: pushSettings()

  readonly property var meetingState: svc ? svc.meetingState : { kind: "none", event: null, title: "", suffix: "", text: "" }
  readonly property bool urgent: svc ? svc.urgent : false
  readonly property bool setupMode: svc ? svc.setupMode : false
  readonly property string icon: "󰃭"
  readonly property string label: setupMode ? "" : meetingState.title
  readonly property string suffix: setupMode ? "" : (meetingState.suffix || "")
  property real maxLabelWidth: 180
  readonly property string scrollMode: String(setting("scroll", "Always"))
  readonly property int scrollTimes: Math.max(1, setting("scrollTimes", 3))
  property int scrollRuns: 0
  readonly property bool needsScroll: fullTitle.width > maxLabelWidth
  readonly property bool scrolling: needsScroll && !opened && (scrollMode === "Always" || (scrollMode === "A few times" && scrollRuns < scrollTimes))
  onLabelChanged: scrollRuns = 0
  // The animation leaves x wherever it stopped; park the title at the left edge when static.
  onScrollingChanged: if (!scrolling) labelText.x = 0

  // Always in the bar: the icon alone says "alive"; dimmed says "no Teams".
  visible: svc !== null
  implicitWidth: row.implicitWidth + Style.space(14)
  implicitHeight: barSize

  function openJoin() {
    if (svc && meetingState.event && meetingState.event.joinUrl) svc.join(meetingState.event.joinUrl)
    else togglePanel()
  }

  // Persist one setting into this widget's shell.json entry. The shell replaces
  // the whole entry, so merge the current values first.
  function saveSetting(key, value) {
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") return false
    var next = {}
    for (var k in settings) if (k !== "id") next[k] = settings[k]
    next[key] = value
    return bar.shell.updateEntryInline(moduleName, next)
  }

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
      color: root.svc && !root.svc.connected ? Qt.darker(root.fg, 1.8) : root.fg
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }

    // The title's full width, measured apart from the label: an elided Text
    // reports its *elided* width as implicitWidth, so sizing the clip from the
    // label itself shrinks it a step per pass until only "Bro…" is left.
    TextMetrics {
      id: fullTitle
      font: labelText.font
      text: root.label
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, fullTitle.width)
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
        // Static: cut at the clip edge, full title in the hover tooltip.
        width: root.scrolling ? fullTitle.width : scrollClip.width
        elide: root.scrolling ? Text.ElideNone : Text.ElideRight
        NumberAnimation on x {
          running: root.scrolling
          loops: 1
          duration: Math.max(6000, fullTitle.width * 25)
          from: scrollClip.width
          to: -fullTitle.width
          easing.type: Easing.Linear
          onFinished: { root.scrollRuns += 1; if (root.scrolling) restart() }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.vertical && root.suffix !== ""
      text: root.suffix
      color: root.fg
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.bold: root.urgent
    }
  }

  // The bar shows a tooltip only for targets that report this flag (see Bar.targetTooltipHovered).
  readonly property bool tooltipHovered: visible && mouse.containsMouse

  MouseArea {
    id: mouse
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    onEntered: if (root.bar) root.bar.showTooltip(root, root.setupMode ? "Click to connect Teams for Linux"
                                                        : root.meetingState.event ? Model.fmtTime(root.meetingState.event.start) + "  " + root.meetingState.event.subject + "  ·  " + root.suffix
                                                        : root.meetingState.text || (root.svc ? root.svc.statusText() : ""))
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) { if (root.svc) root.svc.dismiss() }
      else if (mouse.button === Qt.RightButton && !root.setupMode) root.openJoin()
      else root.togglePanel()
    }
  }
}
