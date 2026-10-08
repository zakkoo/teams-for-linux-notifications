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
  property string version: ""
  // Languages whose "meeting started" toast the Connect button teaches Teams for Linux to recognise.
  readonly property var supportedLanguages: ["en", "de", "es", "fr", "pt"]
  readonly property var languageNames: ({ en: "English", de: "German", es: "Spanish", fr: "French", pt: "Portuguese" })
  readonly property string systemLanguage: String(Qt.locale().name || "").split("_")[0].toLowerCase()
  readonly property bool languageUnsupported: systemLanguage !== "" && supportedLanguages.indexOf(systemLanguage) < 0
  readonly property string issueUrl: "https://github.com/zakkoo/teams-for-linux-notifications/issues/new?title=" + encodeURIComponent("Support Teams in " + systemLanguage)
  function supportedList() { return supportedLanguages.map(function (l) { return languageNames[l] }).join(", ") }
  readonly property bool hidePast: setting("hidePast", Plugin.ServiceRegistry.defaults.hidePast) === true
  readonly property real nowMs: w ? w.nowMs : Date.now()
  // Today nearest-first, finished most recent first (empty while hidden, count kept for the toggle).
  readonly property var day: Model.splitDay({ events: w ? w.events : [], nowMs: nowMs, hidePast: hidePast })
  readonly property var rows: day.today
  readonly property var pastRows: day.finished
  readonly property int pastCount: day.finishedCount
  readonly property int rowHeight: Style.space(34)
  readonly property int maxRows: 5

  FileView {
    path: (w ? w.scriptDir : "") + "../manifest.json"
    onLoaded: { try { root.version = JSON.parse(text()).version || "" } catch (e) { root.version = "" } }
  }

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
              "--port", String(w ? w.mqttPort : Plugin.ServiceRegistry.defaults.mqttPort), "--prefix", w ? w.mqttPrefix : Plugin.ServiceRegistry.defaults.mqttPrefix]
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

  // One meeting row; used by both sections.
  component MeetingRow: Item {
      id: rowItem
      required property var modelData
      readonly property bool isCurrent: w && w.meetingState.event && w.meetingState.event.id === modelData.id
      readonly property bool past: Date.parse(modelData.end) <= root.nowMs
      // Skipped by middle-click or by dismissing a started meeting's card: shown dimmed, one click restores.
      readonly property bool skipped: !past && !!w && w.dismissed[modelData.id] === true
      readonly property color rowColor: isCurrent && w.urgent ? (bar ? bar.urgent : Color.urgent) : (past || skipped ? root.muted : root.fg)
      readonly property string location: modelData.location || ""
      readonly property bool joinable: (modelData.joinUrl || "") !== ""
      readonly property bool hasButton: joinable || skipped
      width: parent.width
      height: root.rowHeight
      opacity: past || skipped ? 0.55 : 1
      Text {
        id: timeText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: Model.fmtTime(rowItem.modelData.start)
        color: rowItem.isCurrent ? rowItem.rowColor : root.muted
        font.family: root.fontFamily; font.pixelSize: Style.font.body
      }
      Text {
        id: subjectText
        anchors.left: timeText.right
        anchors.leftMargin: Style.space(10)
        anchors.right: rowItem.hasButton ? joinBtn.left : (locationText.visible ? locationText.left : parent.right)
        anchors.rightMargin: rowItem.hasButton || locationText.visible ? Style.space(10) : 0
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: rowItem.modelData.subject
        elide: Text.ElideRight
        color: rowItem.rowColor
        font.family: root.fontFamily; font.pixelSize: Style.font.body
        font.bold: rowItem.isCurrent
        font.strikeout: rowItem.past
        MouseArea { id: subjectMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        PanelToolTip {
          visible: subjectMouse.containsMouse && subjectText.truncated
          text: rowItem.modelData.subject
          fontFamily: root.fontFamily
        }
      }
      Text {
        id: locationText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !rowItem.hasButton && rowItem.location !== ""
        textFormat: Text.PlainText
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
        text: rowItem.skipped ? "Skipped · restore" : "Join"
        visible: rowItem.hasButton
        fontFamily: root.fontFamily
        foreground: rowItem.skipped ? root.muted : root.fg
        bordered: true
        onClicked: {
          if (!w) return
          if (rowItem.skipped) w.restore(rowItem.modelData)
          else { w.join(rowItem.modelData.joinUrl); root.close() }
        }
      }
  }

  // A scrolling list of rows, at most maxRows tall.
  component MeetingList: Flickable {
    id: list
    property var rows: []
    width: column.width
    height: Math.min(rows.length, root.maxRows) * root.rowHeight
    contentWidth: width
    contentHeight: listCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    Column {
      id: listCol
      width: list.width
      Repeater { model: list.rows; delegate: MeetingRow {} }
    }
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
        visible: root.rows.length === 0
        text: !w || !w.connected ? "Waiting for Teams for Linux…" : (root.pastCount > 0 ? "No more meetings today" : "No meetings today")
        color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.body
      }

      MeetingList { rows: root.rows }

      // Finished meetings live in their own section at the bottom, most recent
      // first. The show/hide toggle persists, so it stays the way you set it.
      Item {
        width: column.width
        height: pastLabel.implicitHeight
        visible: root.pastCount > 0
        Text {
          anchors.left: parent.left
          text: "Finished"
          color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        Text {
          id: pastLabel
          anchors.right: parent.right
          text: root.hidePast ? "Show " + root.pastCount : "Hide " + root.pastCount
          color: pastMouse.containsMouse ? root.fg : root.muted
          font.family: root.fontFamily; font.pixelSize: Style.font.caption
          MouseArea { id: pastMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.save("hidePast", !root.hidePast) }
        }
      }

      MeetingList { rows: root.pastRows; visible: root.pastCount > 0 && !root.hidePast }

      PanelSeparator {}

      Fold { title: "Settings & connection"; open: root.settingsOpen; onToggled: root.settingsOpen = !root.settingsOpen }

      Column {
        visible: root.settingsOpen
        width: column.width
        spacing: Style.space(10)

        SettingNumber {
          label: "Show the next meeting this many minutes ahead"
          from: 1; to: 240
          value: root.setting("horizonMinutes", Plugin.ServiceRegistry.defaults.horizonMinutes)
          hint: "The bar stays empty until a meeting is this close. 15 means you see it a quarter of an hour before it starts."
          onModified: function(v) { root.save("horizonMinutes", v) }
        }
        SettingNumber {
          label: "Check the calendar every (minutes)"
          from: 1; to: 60
          value: root.setting("pollMinutes", Plugin.ServiceRegistry.defaults.pollMinutes)
          hint: "How often new or moved meetings are picked up from Teams. 5 is plenty; lower only if your calendar changes constantly."
          onModified: function(v) { root.save("pollMinutes", v) }
        }
        Dropdown {
          width: parent.width
          label: "Long titles in the bar"
          options: ["Always", "Never", "A few times"]
          value: String(root.setting("scroll", Plugin.ServiceRegistry.defaults.scroll))
          foreground: root.fg; fontFamily: root.fontFamily
          onChanged: function(v) { root.save("scroll", v) }
        }
        Text {
          width: parent.width
          text: "Long meeting titles scroll through the bar. Never shows a cut title instead; hover it for the full name. A few times scrolls, then stops."
          wrapMode: Text.Wrap
          color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.caption
        }
        SettingNumber {
          visible: String(root.setting("scroll", Plugin.ServiceRegistry.defaults.scroll)) === "A few times"
          label: "How many times to scroll"
          from: 1; to: 20
          value: root.setting("scrollTimes", Plugin.ServiceRegistry.defaults.scrollTimes)
          hint: "After that the title stays put, cut at the edge."
          onModified: function(v) { root.save("scrollTimes", v) }
        }
        Toggle {
          width: parent.width
          label: "Reminder card as well"
          description: "Besides the bar, show a card with Join, Remind me and Dismiss when a meeting is due. Clicking the card itself does nothing. Off keeps everything in the bar."
          checked: root.setting("toast", Plugin.ServiceRegistry.defaults.toast) === true
          foreground: root.fg; fontFamily: root.fontFamily
          titleSize: Style.font.body
          onClicked: root.save("toast", !checked)
        }
        SettingNumber {
          visible: root.setting("toast", Plugin.ServiceRegistry.defaults.toast) === true
          label: "Remind me this many minutes before the start"
          from: 0; to: Math.min(60, root.setting("horizonMinutes", Plugin.ServiceRegistry.defaults.horizonMinutes))
          value: root.setting("leadMinutes", Plugin.ServiceRegistry.defaults.leadMinutes)
          hint: "When the reminder card first appears, never earlier than the meeting shows in the bar. Remind me halves what is left each time. 0 means right when the meeting starts."
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
          value: root.setting("mqttPort", Plugin.ServiceRegistry.defaults.mqttPort)
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
            text: String(root.setting("mqttPrefix", Plugin.ServiceRegistry.defaults.mqttPrefix))
            foreground: root.fg
            onEditingFinished: if (text.trim() !== "" && text.trim() !== String(root.setting("mqttPrefix", Plugin.ServiceRegistry.defaults.mqttPrefix))) root.save("mqttPrefix", text.trim())
          }
        }

        PanelSeparator {}

        Text {
          width: parent.width
          text: w ? w.statusText : ""
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

      Text {
        visible: root.languageUnsupported
        width: column.width
        wrapMode: Text.Wrap
        textFormat: Text.RichText
        text: "Your system language is <b>" + root.systemLanguage + "</b>. Teams' \"meeting started\" banner is recognised in "
              + root.supportedList() + ". If Teams runs in another language, switch it to one of those, or "
              + "<a href=\"" + root.issueUrl + "\">ask the maintainer to add yours</a>."
        color: root.muted; linkColor: root.fg
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
        onLinkActivated: function(link) { Quickshell.execDetached(["xdg-open", link]) }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
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

    Text {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -Style.space(6)
      text: root.version ? "v" + root.version : ""
      color: Qt.darker(root.fg, 2.4)
      font.family: root.fontFamily; font.pixelSize: Math.max(8, Style.font.caption - 2)
    }
  }
}
