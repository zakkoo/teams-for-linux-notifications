import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "." as Plugin
import "Model.js" as Model

// The reminder card. The service loads it only while a reminder is due, so
// its lifetime is its visibility. The body has no MouseArea on purpose: only
// the three buttons act, a stray click on the text changes nothing.
PanelWindow {
  id: root

  readonly property var svc: Plugin.ServiceRegistry.instance
  readonly property var state: svc ? svc.meetingState : { kind: "none", event: null, minutes: 0 }
  readonly property var event: state.event
  readonly property int snooze: Model.snoozeMinutes(state)
  readonly property bool now: state.kind === "now"
  readonly property string fontFamily: Style.font.family
  readonly property color fg: Color.foreground
  readonly property color muted: Qt.darker(fg, 1.6)
  readonly property int pad: Style.space(14)

  // Follow the focused monitor; fall back to the first screen when Hyprland has none.
  screen: {
    var name = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  // Top-centre, below the bar: anchoring only the top centres the surface,
  // and respecting other exclusive zones keeps it off the bar on either edge.
  anchors.top: true
  margins.top: Style.space(12)
  implicitWidth: card.width
  implicitHeight: card.height
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  WlrLayershell.namespace: "teams-meetings-reminder"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  BorderSurface {
    id: card
    width: Style.space(380)
    height: column.implicitHeight + 2 * root.pad + borderTop + borderBottom
    color: Util.alpha(Color.background, 0.97)
    borderSpec: Border.surfaceSpec("popups", "border", root.now ? Color.urgent : Color.popups.border, Math.max(1, Style.space(2)))
    radius: Style.cornerRadius

    Column {
      id: column
      anchors.fill: parent
      anchors.margins: root.pad
      anchors.topMargin: root.pad + card.borderTop
      anchors.leftMargin: root.pad + card.borderLeft
      anchors.rightMargin: root.pad + card.borderRight
      spacing: Style.space(8)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: root.event ? root.event.subject : ""
        color: root.now ? Color.urgent : root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true
      }
      Text {
        textFormat: Text.PlainText
        text: root.now ? "Teams meeting now" : "Teams meeting in " + root.state.minutes + " min"
        color: root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Text {
        width: parent.width
        visible: root.event && !root.event.joinUrl && !!root.event.location
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: root.event ? String(root.event.location || "") : ""
        color: root.muted
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }

      Row {
        spacing: Style.space(8)
        Button {
          visible: root.event && !!root.event.joinUrl
          text: "Join"
          bordered: true; foreground: root.fg; fontFamily: root.fontFamily
          onClicked: if (root.svc) root.svc.joinFromCard()
        }
        Button {
          visible: root.snooze > 0
          text: "Remind me in " + root.snooze + " min"
          bordered: true; foreground: root.fg; fontFamily: root.fontFamily
          onClicked: if (root.svc) root.svc.snooze()
        }
        Button {
          text: "Dismiss"
          bordered: true; foreground: root.muted; fontFamily: root.fontFamily
          onClicked: if (root.svc) root.svc.dismiss()
        }
      }
    }
  }
}
