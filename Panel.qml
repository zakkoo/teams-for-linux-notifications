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
  property bool settingsOpen: false   // daily use is the meeting list; settings fold away
  property bool advancedOpen: false

  function open() { root.controller.show(); if (w) w.refreshWired(); actionHint = "" }
  function close() { root.controller.hide(); settingsOpen = false; advancedOpen = false }
  function toggle() { opened ? close() : open() }

  function save(key, value) {
    if (hostWidget && typeof hostWidget.saveSetting === "function") hostWidget.saveSetting(key, value)
  }

  Process {
    id: actionProc
    property string action: "connect"
    command: ["/usr/bin/python3", (w ? w.scriptDir : "") + "teams-config.py", action,
              "--port", String(w ? w.mqttPort : 1883), "--prefix", w ? w.mqttPrefix : "teams"]
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      if (w) w.refreshWired()
      root.actionHint = code !== 0 ? "Could not edit the Teams for Linux config (see shell log)"
        : (action === "connect" ? "Done. Restart Teams for Linux once and it will connect." : "Removed. Restart Teams for Linux to apply.")
    }
  }

  function runAction(a) { if (actionProc.running) return; actionProc.action = a; actionProc.running = true }

  // A labelled number with a one-line explanation underneath.
  component SettingNumber: Column {
    property alias label: field.label
    property alias from: field.from
    property alias to: field.to
    property alias value: field.value
    property string hint: ""
    signal modified(int value)
    width: column.width
    spacing: Style.space(2)
    NumberField {
      id: field
      width: parent.width
      foreground: root.fg; fontFamily: root.fontFamily
      onModified: function(v) { parent.modified(v) }
    }
    Text {
      width: parent.width
      text: parent.hint
      wrapMode: Text.Wrap
      color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
  }

  // Clickable section header with a chevron.
  component Fold: Item {
    property string title: ""
    property bool open: false
    signal toggled()
    width: column.width
    height: foldLabel.implicitHeight + Style.space(8)
    Text {
      id: foldLabel
      anchors.verticalCenter: parent.verticalCenter
      text: (parent.open ? "▾  " : "▸  ") + parent.title
      color: foldMouse.containsMouse ? root.fg : root.muted
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }
    MouseArea { id: foldMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.toggled() }
  }

  PopupCard {
    id: card
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: card.fittedContentWidth(Style.space(420))
    contentHeight: card.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(10)

      PanelSectionHeader { text: "Today"; foreground: root.muted; fontFamily: root.fontFamily }

      Text {
        visible: !w || w.events.length === 0
        text: w && w.connected ? "No meetings today" : "Waiting for Teams for Linux…"
        color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.body
      }

      Repeater {
        model: w ? w.events : []
        delegate: Item {
          id: rowItem
          required property var modelData
          readonly property bool isCurrent: w && w.meetingState.event && w.meetingState.event.id === modelData.id
          readonly property color rowColor: isCurrent && w.urgent ? (bar ? bar.urgent : Color.urgent) : root.fg
          readonly property string location: modelData.location || ""
          readonly property bool joinable: (modelData.joinUrl || "") !== ""
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
            anchors.right: rowItem.joinable ? joinBtn.left : (locationText.visible ? locationText.left : parent.right)
            anchors.rightMargin: rowItem.joinable || locationText.visible ? Style.space(10) : 0
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
            visible: !rowItem.joinable && rowItem.location !== ""
            text: rowItem.location
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Style.space(150))
            color: root.muted
            font.family: root.fontFamily; font.pixelSize: Style.font.caption
            MouseArea { id: locationMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
            PanelToolTip {
              visible: locationMouse.containsMouse && locationText.truncated
              text: rowItem.location
              fontFamily: root.fontFamily
            }
          }
          Button {
            id: joinBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Join"
            visible: rowItem.joinable
            fontFamily: root.fontFamily
            foreground: root.fg
            bordered: true
            onClicked: { if (w) w.join(rowItem.modelData.joinUrl); root.close() }
          }
        }
      }

      PanelSeparator {}

      Fold { title: "Settings & connection"; open: root.settingsOpen; onToggled: root.settingsOpen = !root.settingsOpen }

      Column {
        visible: root.settingsOpen
        width: column.width
        spacing: Style.space(10)

        SettingNumber {
          label: "Show the next meeting this many minutes ahead"
          from: 1; to: 240
          value: root.setting("horizonMinutes", 15)
          hint: "The bar stays empty until a meeting is this close. 15 means you see it a quarter of an hour before it starts."
          onModified: function(v) { root.save("horizonMinutes", v) }
        }
        SettingNumber {
          label: "Check the calendar every (minutes)"
          from: 1; to: 60
          value: root.setting("pollMinutes", 5)
          hint: "How often new or moved meetings are picked up from Teams. 5 is plenty; lower only if your calendar changes constantly."
          onModified: function(v) { root.save("pollMinutes", v) }
        }
        Toggle {
          width: parent.width
          label: "Pop-up reminder as well"
          description: "Besides the bar, show a normal desktop notification once per meeting. Off keeps everything in the bar."
          checked: root.setting("toast", false) === true
          foreground: root.fg; fontFamily: root.fontFamily
          titleSize: Style.font.body
          onClicked: root.save("toast", !checked)
        }
        SettingNumber {
          visible: root.setting("toast", false) === true
          label: "Remind me this many minutes before the start"
          from: 0; to: 60
          value: root.setting("leadMinutes", 2)
          hint: "When the pop-up reminder appears. 0 means right when the meeting starts."
          onModified: function(v) { root.save("leadMinutes", v) }
        }

        Toggle {
          width: parent.width
          label: "Advanced settings"
          description: "Connection details between Teams for Linux and this widget. The defaults work; change them only if something else already uses them."
          checked: root.advancedOpen
          foreground: root.fg; fontFamily: root.fontFamily
          titleSize: Style.font.body
          onClicked: root.advancedOpen = !root.advancedOpen
        }
        SettingNumber {
          visible: root.advancedOpen
          label: "Local port Teams for Linux talks to"
          from: 1024; to: 65535
          value: root.setting("mqttPort", 1883)
          hint: "Only reachable from this computer. After changing it, press Connect again and restart Teams for Linux."
          onModified: function(v) { root.save("mqttPort", v) }
        }
        Row {
          visible: root.advancedOpen
          width: parent.width
          spacing: Style.space(8)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Message prefix"
            color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.body
          }
          TextField {
            width: Style.space(120)
            text: String(root.setting("mqttPrefix", "teams"))
            foreground: root.fg
            onEditingFinished: if (text.trim() !== "" && text.trim() !== String(root.setting("mqttPrefix", "teams"))) root.save("mqttPrefix", text.trim())
          }
        }

        PanelSeparator {}

        Text {
          width: parent.width
          text: w ? w.statusText() : ""
          wrapMode: Text.Wrap
          color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        Button {
          text: w && w.teamsWired ? "Disconnect Teams for Linux" : "Connect Teams for Linux"
          fontFamily: root.fontFamily
          foreground: root.fg
          bordered: true
          enabled: !actionProc.running
          onClicked: root.runAction(w && w.teamsWired ? "disconnect" : "connect")
        }
        Text {
          visible: root.actionHint !== ""
          width: parent.width
          text: root.actionHint
          wrapMode: Text.Wrap
          color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
      }

      // Setup needed: surface the Connect button without opening the fold.
      Button {
        visible: !root.settingsOpen && w && !w.teamsWired
        text: "Connect Teams for Linux"
        fontFamily: root.fontFamily
        foreground: root.fg
        bordered: true
        enabled: !actionProc.running
        onClicked: root.runAction("connect")
      }
      Text {
        visible: !root.settingsOpen && root.actionHint !== ""
        width: column.width
        text: root.actionHint
        wrapMode: Text.Wrap
        color: root.fg; font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
    }
  }
}
