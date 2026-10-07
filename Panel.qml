import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.zakkoo.teams-for-linux-notifications"
  ipcTarget: "io.github.zakkoo.teams-for-linux-notifications"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var w: hostWidget
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property color muted: Qt.darker(fg, 1.6)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property string actionHint: ""

  function open() { root.controller.show(); if (w) w.refreshWired(); actionHint = "" }
  function close() { root.controller.hide() }
  function toggle() { opened ? close() : open() }

  function statusText() {
    if (!w) return ""
    if (w.bridgeError) return w.bridgeError
    if (!w.bridgeAlive) return "Starting bridge…"
    if (!w.connected) return w.teamsWired ? "Waiting for Teams for Linux (is it running?)" : "Teams for Linux is not connected yet"
    if (w.events.length === 0) return "Connected · no calendar received yet"
    return "Connected"
  }

  Process {
    id: actionProc
    property string action: "connect"
    command: ["/usr/bin/python3", (w ? w.scriptDir : "") + "teams-config.py", action,
              "--port", String(w ? w.mqttPort : 1883), "--prefix", w ? w.mqttPrefix : "teams"]
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      if (w) w.refreshWired()
      root.actionHint = code !== 0 ? "Could not edit Teams config (see shell log)"
        : (action === "connect" ? "Written. Restart Teams for Linux to connect." : "Removed. Restart Teams for Linux to apply.")
    }
  }

  function runAction(a) { if (actionProc.running) return; actionProc.action = a; actionProc.running = true }

  PopupCard {
    id: card
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: Style.space(360)
    contentHeight: column.implicitHeight

    Column {
      id: column
      width: card.contentWidth
      spacing: Style.space(10)

      PanelSectionHeader { text: "Today"; foreground: root.muted; fontFamily: root.fontFamily }

      Text {
        visible: !w || w.events.length === 0
        text: "No meetings today"
        color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.body
      }

      Repeater {
        model: w ? w.events : []
        delegate: Row {
          required property var modelData
          readonly property bool isCurrent: w && w.meetingState.event && w.meetingState.event.id === modelData.id
          width: column.width
          spacing: Style.space(8)
          Text {
            width: Style.space(44)
            text: Model.fmtTime(modelData.start)
            color: isCurrent && w.urgent ? (bar ? bar.urgent : Color.urgent) : root.muted
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            width: parent.width - Style.space(44) - joinBtn.width - Style.space(16)
            text: modelData.subject
            elide: Text.ElideRight
            color: isCurrent ? (w.urgent ? (bar ? bar.urgent : Color.urgent) : root.fg) : root.fg
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            font.bold: isCurrent
            anchors.verticalCenter: parent.verticalCenter
          }
          Button {
            id: joinBtn
            text: "Join"
            visible: modelData.joinUrl !== ""
            fontFamily: root.fontFamily
            foreground: root.fg
            bordered: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: { Quickshell.execDetached(["xdg-open", modelData.joinUrl]); root.close() }
          }
        }
      }

      PanelSeparator {}

      Text {
        width: column.width
        text: root.statusText()
        wrapMode: Text.Wrap
        color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }

      Row {
        spacing: Style.space(8)
        Button {
          text: w && w.teamsWired ? "Disconnect Teams for Linux" : "Connect Teams for Linux"
          fontFamily: root.fontFamily
          foreground: root.fg
          bordered: true
          enabled: !actionProc.running
          onClicked: root.runAction(w && w.teamsWired ? "disconnect" : "connect")
        }
      }

      Text {
        visible: root.actionHint !== ""
        width: column.width
        text: root.actionHint
        wrapMode: Text.Wrap
        color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
    }
  }
}
