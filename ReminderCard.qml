import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "." as Plugin
import "Model.js" as Model

// The reminder cards: one per due meeting, soonest at the top, at most three
// (capped in Model.dueReminders). The service loads this window only while
// something is due, so its lifetime is its visibility. Card bodies have no
// MouseArea on purpose: only the buttons act, a stray click changes nothing.
PanelWindow {
  id: root

  readonly property var svc: Plugin.ServiceRegistry.instance
  readonly property var reminders: svc ? svc.reminders : []
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
  implicitWidth: stack.width
  implicitHeight: stack.height
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  WlrLayershell.namespace: "teams-meetings-reminder"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Column {
    id: stack
    width: Style.space(380)
    spacing: Style.space(8)

    Repeater {
      model: root.reminders

      BorderSurface {
        id: card
        required property var modelData
        readonly property var event: modelData.event
        readonly property bool now: modelData.kind === "now"
        readonly property int snooze: Model.snoozeMinutes(modelData)

        width: stack.width
        height: column.implicitHeight + 2 * root.pad + borderTop + borderBottom
        color: Util.alpha(Color.background, 0.97)
        borderSpec: Border.surfaceSpec("popups", "border", card.now ? Color.urgent : Color.popups.border, Math.max(1, Style.space(2)))
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
            text: card.event.subject
            color: card.now ? Color.urgent : root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: card.now ? "Teams meeting now" : "Teams meeting in " + card.modelData.minutes + " min"
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
          Text {
            width: parent.width
            visible: !card.event.joinUrl && !!card.event.location
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: String(card.event.location || "")
            color: root.muted
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }

          Row {
            spacing: Style.space(8)
            Button {
              visible: !!card.event.joinUrl
              text: "Join"
              bordered: true; foreground: root.fg; fontFamily: root.fontFamily
              onClicked: if (root.svc) root.svc.joinFromCard(card.event)
            }
            Button {
              visible: card.snooze > 0
              text: "Remind me in " + card.snooze + " min"
              bordered: true; foreground: root.fg; fontFamily: root.fontFamily
              onClicked: if (root.svc) root.svc.snooze(card.modelData)
            }
            Button {
              text: "Dismiss"
              bordered: true; foreground: root.muted; fontFamily: root.fontFamily
              onClicked: if (root.svc) root.svc.dismissReminder(card.modelData)
            }
          }
        }
      }
    }
  }
}
