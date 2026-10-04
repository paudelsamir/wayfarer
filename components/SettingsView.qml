import QtQuick
// NOTE: no QtQuick.Dialogs here on purpose — the native file picker
// crashes this shell through the gvfs portal. Import works by pasted
// text instead; export writes straight to a file, no dialog needed.

// Settings: quiet rows — theme, accent, bar label, goal, data, danger.
Item {
  id: root
  property var store: null
  property var features: []

  property string ioText: ""
  property string ioMessage: ""
  property bool confirmReset: false
  property bool showRaw: false

  readonly property var accents: ["#6f9ab0", "#8ba888", "#c2a878", "#b07f6f", "#9a8fc2"]
  readonly property color danger: "#b07f6f"

  Flickable {
    anchors.fill: parent
    anchors.leftMargin: Theme.s(40)
    anchors.rightMargin: Theme.s(40)
    anchors.topMargin: Theme.s(24)
    anchors.bottomMargin: Theme.s(24)
    contentWidth: width
    contentHeight: col.height
    clip: true
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: col
      width: parent.width - 80
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Theme.s(8)

      Item { width: 1; height: Theme.s(16) }

      Text {
        width: parent.width
        text: "settings"
        color: Theme.label
        font.family: Theme.serif
        font.pixelSize: 22
        font.italic: true
      }

      Rectangle {
        width: parent.width
        height: Theme.controlHeight + Theme.s(12)
        radius: Theme.radiusControl
        color: Theme.alpha(root.danger, 0.10)
        border.width: 1
        border.color: Theme.alpha(root.danger, 0.5)
        scale: topHover.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Row {
          anchors.fill: parent
          anchors.leftMargin: Theme.s(12)
          anchors.rightMargin: Theme.s(12)
          spacing: Theme.s(10)
          Text {
            text: "change map"
            color: root.danger
            font.family: Theme.font
            font.pixelSize: Theme.body
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "switch country, goal, everything"
            color: Theme.tertiary
            font.family: Theme.font
            font.pixelSize: Theme.footnote
            anchors.verticalCenter: parent.verticalCenter
          }
        }
        MouseArea { id: topHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: store.requestSetup() }
      }

      SectionHeader { text: "look"; trailing: "theme · accent · bar" }

      SettingRow {
        title: "theme"
        detail: "auto follows your omarchy theme"
        Segmented {
          compact: true
          model: [{ key: "auto", label: "auto" }, { key: "dark", label: "dark" }, { key: "light", label: "light" }]
          current: store ? store.themeMode : "auto"
          onPicked: function(key) { store.set({ themeMode: key }) }
        }
      }

      SettingRow {
        title: "appearance"
        detail: "the window's material"
        Segmented {
          compact: true
          model: [{ key: "atlas", label: "atlas" }, { key: "clean", label: "clean" }, { key: "survey", label: "survey" }, { key: "mist", label: "mist" }]
          current: store ? (store.appearance || "atlas") : "atlas"
          onPicked: function(key) { store.set({ appearance: key }) }
        }
      }

      SettingRow {
        title: "accent"
        detail: "the colour of visited land"
        Row {
          spacing: Theme.gap
          Rectangle {
            width: Theme.s(58); height: Theme.s(30); radius: height / 2
            color: store && store.accent === "auto" ? Theme.alpha(Theme.accent, 0.22) : Theme.fill
            border.width: 1
            border.color: store && store.accent === "auto" ? Theme.alpha(Theme.accent, 0.5) : "transparent"
            Text {
              anchors.centerIn: parent
              text: "auto"
              color: store && store.accent === "auto" ? Theme.label : Theme.secondary
              font.family: Theme.font
              font.pixelSize: Theme.callout
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: store.set({ accent: "auto" }) }
          }
          Repeater {
            model: root.accents
            Rectangle {
              width: Theme.s(30); height: Theme.s(30); radius: width / 2
              color: modelData
              border.color: store && store.accent === modelData ? Theme.label : "transparent"
              border.width: 2
              scale: dotMouse.pressed ? 0.9 : 1
              Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
              MouseArea { id: dotMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: store.set({ accent: modelData }) }
            }
          }
        }
      }

      SettingRow {
        title: "map fill"
        detail: "presence of visited land · " + Math.round((store ? store.mapOpacity : 1) * 100) + "%"
        Slider {
          value: store ? store.mapOpacity : 1.0
          minimum: 0.3
          maximum: 1.0
          onMoved: function(v) { store.set({ mapOpacity: Math.round(v * 20) / 20 }) }
        }
      }

      SettingRow {
        title: "bar icon"
        detail: "flag before the count"
        Chip {
          text: "flag"
          selected: store ? (store.iconMode || "flag") === "flag" : true
          onClicked: store.set({ iconMode: (store && store.iconMode === "none") ? "flag" : "none" })
        }
      }

      SettingRow {
        title: "flag size"
        detail: Math.round((store ? store.flagSize : 1) * 100) + "% of bar text"
        Slider {
          value: store ? store.flagSize : 1.0
          minimum: 0.7
          maximum: 1.6
          onMoved: function(v) { store.set({ flagSize: Math.round(v * 20) / 20 }) }
        }
      }

SettingRow {
        title: "bar shows"
        detail: "the tiny text in your bar"
        Segmented {
          compact: true
          model: [{ key: "count", label: "36/77" }, { key: "place", label: "nepal" }, { key: "pct", label: "%" }]
          current: store ? store.barMode : "count"
          onPicked: function(key) { store.set({ barMode: key }) }
        }
      }

      SectionHeader { text: "traveler"; trailing: "the profile" }
      SettingRow {
        title: "name"
        detail: "shown on your profile"
        Field {
          width: 200
          placeholder: "wayfarer"
          text: store ? store.travelerName : ""
          onTextChanged: store.set({ travelerName: text })
        }
      }
      SettingRow {
        title: "picture"
        detail: "your assigned face"
        Row {
          spacing: Theme.gap
          Avatar {
            size: 30
            name: store ? (store.travelerName || "") : ""
            imagePath: store ? (store.avatarPath || "") : ""
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      SectionHeader { text: "scope"; trailing: "what counts" }
      SettingRow {
        title: "goal"
        detail: goalSummary()
        Row {
          spacing: Theme.s(16)
          PillButton {
            text: "whole country"
            primary: false
            onClicked: store.set({ goal: { type: "country", regions: [], places: [] } })
          }
          Rectangle {
            width: dangerLbl.implicitWidth + 24
            height: Theme.controlHeight
            radius: height / 2
            color: dangerHover.containsMouse ? Theme.alpha(root.danger, 0.18) : Theme.alpha(root.danger, 0.10)
            border.width: 1
            border.color: Theme.alpha(root.danger, 0.55)
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Text {
              id: dangerLbl
              anchors.centerIn: parent
              text: "revisit setup"
              color: root.danger
              font.family: Theme.font
              font.pixelSize: Theme.callout
              font.weight: Font.DemiBold
            }
            MouseArea {
              id: dangerHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: store.requestSetup()
            }
          }
        }
      }

      SectionHeader { text: "data"; trailing: "yours to keep" }
      SettingRow {
        title: "backup"
        detail: store && store.lastIo !== "" ? store.lastIo : "one file holds everything"
        PillButton {
          text: "export"
          primary: false
          onClicked: {
            root.ioText = store.exportJson()
            store.exportToFile(store.defaultExportPath())
          }
        }
      }
      Text {
        width: parent.width
        visible: store && store.lastExportPath !== ""
        text: store ? store.lastExportPath : ""
        color: Theme.quaternary
        font.family: "monospace"
        font.pixelSize: Theme.caption
        elide: Text.ElideMiddle
      }
      SettingRow {
        title: "restore"
        detail: "paste a backup below, then import"
        PillButton {
          text: "import"
          primary: false
          onClicked: {
            try { store.importJson(root.ioText); root.ioMessage = "imported · welcome back" }
            catch (e) { root.ioMessage = "that json did not parse" }
          }
        }
      }
      Rectangle {
        width: parent.width
        height: 110
        radius: Theme.radiusControl
        color: Theme.fill
        border.width: 1
        border.color: Theme.separator
        clip: true
        TextEdit {
          id: ioEdit
          anchors.fill: parent
          anchors.margins: Theme.s(10)
          text: root.ioText
          onTextChanged: root.ioText = text
          color: Theme.secondary
          font.pixelSize: Theme.footnote
          font.family: "monospace"
          wrapMode: TextEdit.Wrap
          selectByMouse: true
        }
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignRight
        visible: root.ioMessage !== ""
        text: root.ioMessage
        color: Theme.tertiary
        font.family: Theme.font
        font.pixelSize: Theme.footnote
      }

      SectionHeader { text: "danger"; trailing: "no undo" }
      SettingRow {
        title: "unvisit all"
        detail: root.confirmReset ? "click unvisit to confirm" : "erase all visited marks"
        PillButton {
          text: root.confirmReset ? "unvisit everything" : "unvisit all"
          primary: false
          tint: root.danger
          onClicked: {
            if (root.confirmReset) { store.clearVisited(); root.confirmReset = false }
            else { root.confirmReset = true; resetGuard.restart() }
          }
        }
      }
      Timer { id: resetGuard; interval: 4000; onTriggered: root.confirmReset = false }

      Item { width: 1; height: Theme.s(16) }
    }
  }

  function goalSummary() {
    if (!store) return ""
    var g = store.goal
    if (!g || g.type === "country") return "whole country · every area counts"
    if (g.type === "regions") return (g.regions || []).length + " areas selected"
    return ((g.places || []).length) + " custom places"
  }
}
