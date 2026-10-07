import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "." as Plugin
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.zakkoo.teams-for-linux-notifications"
  ipcTarget: "io.github.zakkoo.teams-for-linux-notifications"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var w: Plugin.ServiceRegistry.instance
  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property color muted: Qt.darker(fg, 1.6)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property string actionHint: ""

  function open() { root.controller.show(); if (w) w.refreshWired(); actionHint = "" }
  function close() { root.controller.hide() }
  function toggle() { opened ? close() : open() }

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

  function save(key, value) {
    if (hostWidget && typeof hostWidget.saveSetting === "function") hostWidget.saveSetting(key, value)
  }

  function runAction(a) { if (actionProc.running) return; actionProc.action = a; actionProc.running = true }

  PopupCard {
    id: card
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: card.fittedContentWidth(Style.space(400))
    contentHeight: card.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(10)

      PanelSectionHeader { text: "Today"; foreground: root.muted; fontFamily: root.fontFamily }

      Text {
        visible: !w || w.events.length === 0
        text: "No meetings today"
        color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.body
      }

      Repeater {
        model: w ? w.events : []
        delegate: Item {
          id: rowItem
          required property var modelData
          readonly property bool isCurrent: w && w.meetingState.event && w.meetingState.event.id === modelData.id
          readonly property color rowColor: isCurrent && w.urgent ? (bar ? bar.urgent : Color.urgent) : root.fg
          width: column.width
          height: Math.max(timeText.implicitHeight, joinBtn.implicitHeight)
          Text {
            id: timeText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Model.fmtTime(rowItem.modelData.start)
            color: rowItem.isCurrent ? rowItem.rowColor : root.muted
            font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
          Text {
            anchors.left: timeText.right
            anchors.leftMargin: Style.space(10)
            anchors.right: joinBtn.visible ? joinBtn.left : (locationText.visible ? locationText.left : parent.right)
            anchors.rightMargin: joinBtn.visible || locationText.visible ? Style.space(10) : 0
            anchors.verticalCenter: parent.verticalCenter
            text: rowItem.modelData.subject
            elide: Text.ElideRight
            color: rowItem.rowColor
            font.family: root.fontFamily; font.pixelSize: Style.font.body
            font.bold: rowItem.isCurrent
          }
          Text {
            id: locationText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !joinBtn.visible && (rowItem.modelData.location || "") !== ""
            text: rowItem.modelData.location || ""
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Style.space(140))
            color: root.muted
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
          }
          Button {
            id: joinBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Join"
            visible: (rowItem.modelData.joinUrl || "") !== ""
            fontFamily: root.fontFamily
            foreground: root.fg
            bordered: true
            onClicked: { if (w) w.join(rowItem.modelData.joinUrl); root.close() }
          }
        }
      }


      PanelSeparator {}

      PanelSectionHeader { text: "Settings"; foreground: root.muted; fontFamily: root.fontFamily }

      NumberField {
        width: column.width
        label: "Show upcoming meetings within (min)"
        from: 1; to: 240
        value: root.setting("horizonMinutes", 15)
        foreground: root.fg; fontFamily: root.fontFamily
        onModified: function(v) { root.save("horizonMinutes", v) }
      }
      NumberField {
        width: column.width
        label: "Refresh calendar every (min)"
        from: 1; to: 60
        value: root.setting("pollMinutes", 5)
        foreground: root.fg; fontFamily: root.fontFamily
        onModified: function(v) { root.save("pollMinutes", v) }
      }
      Toggle {
        width: column.width
        label: "Desktop notification"
        description: "One toast per meeting, in addition to the bar."
        checked: root.setting("toast", false) === true
        foreground: root.fg; fontFamily: root.fontFamily
        titleSize: Style.font.body
        onClicked: root.save("toast", !checked)
      }
      NumberField {
        width: column.width
        visible: root.setting("toast", false) === true
        label: "Notify minutes before start"
        from: 0; to: 60
        value: root.setting("leadMinutes", 2)
        foreground: root.fg; fontFamily: root.fontFamily
        onModified: function(v) { root.save("leadMinutes", v) }
      }
      NumberField {
        width: column.width
        label: "MQTT port (then Connect again)"
        from: 1024; to: 65535
        value: root.setting("mqttPort", 1883)
        foreground: root.fg; fontFamily: root.fontFamily
        onModified: function(v) { root.save("mqttPort", v) }
      }
      Row {
        width: column.width
        spacing: Style.space(8)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "MQTT topic prefix"
          color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
        }
        TextField {
          id: prefixField
          width: Style.space(120)
          text: String(root.setting("mqttPrefix", "teams"))
          foreground: root.fg
          onEditingFinished: if (text.trim() !== "" && text.trim() !== String(root.setting("mqttPrefix", "teams"))) root.save("mqttPrefix", text.trim())
        }
      }

      PanelSeparator {}

      Text {
        width: column.width
        text: w ? w.statusText() : ""
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
