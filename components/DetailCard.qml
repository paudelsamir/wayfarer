import QtQuick

// Tiny contextual detail: serif name, quiet meta, one PillButton toggle.
// Slides/scales in on selection.
Rectangle {
  id: root
  property var feature: null
  property bool isVisited: false
  property string visitedOn: ""
  property string unit: "district"
  property string sub: ""
  property int provVisited: 0
  property int provTotal: 0

  signal toggle()
  signal dismiss()
  signal saveDate(double ms)

  property bool editingDate: false
  property string dateDraft: ""
  property string dateError: ""

  function parseDate(s) {    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec((s || "").trim())
    if (!m) return 0
    var y = +m[1], mo = +m[2], d = +m[3]
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return 0
    var dt = new Date(y, mo - 1, d, 12, 0, 0)
    if (dt.getFullYear() !== y || dt.getMonth() !== mo - 1 || dt.getDate() !== d) return 0
    if (dt.getTime() > Date.now() + 86400000) return 0
    return dt.getTime()
  }

  function commitDate() {
    var ms = parseDate(dateDraft)
    if (!ms) {
      dateError = "use YYYY-MM-DD, not in the future"
      return
    }
    editingDate = false
    dateError = ""
    saveDate(ms)
  }

  onFeatureChanged: { editingDate = false; dateError = "" }
  onIsVisitedChanged: if (!isVisited) editingDate = false
  onEditingDateChanged: if (editingDate) dateField.focusInput()

  visible: feature !== null && pop.scale > 0.01
  width: 236
  height: col.implicitHeight + Theme.pad * 2
  radius: Theme.radiusControl
  color: Theme.bg
  border.width: 1
  border.color: Theme.separator

  Item {
    id: pop
    anchors.fill: parent
    scale: root.feature !== null ? 1 : 0.94
    opacity: root.feature !== null ? 1 : 0
    Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    Text {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: Theme.s(10)
      text: "×"
      color: Theme.tertiary
      font.pixelSize: 15
      MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: root.dismiss() }
    }

    Column {
      id: col
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Theme.pad
      spacing: Theme.s(6)

      Text {
        width: parent.width - 20
        text: root.feature ? root.feature.name : ""
        color: Theme.label
        font.family: Theme.serif
        font.pixelSize: 17
        wrapMode: Text.WordWrap
      }
      Text {
        width: parent.width
        text: root.sub !== "" ? root.sub : (root.feature ? root.feature.name : "")
        color: Theme.secondary
        font.family: Theme.font
        font.pixelSize: Theme.footnote
      }
      Text {
        width: parent.width
        visible: root.feature && root.feature.highlights !== undefined
        text: root.feature && root.feature.highlights ? root.feature.highlights.join(" · ") : ""
        color: Theme.tertiary
        font.family: Theme.serif
        font.pixelSize: Theme.footnote
        font.italic: true
        wrapMode: Text.WordWrap
      }
      Text {
        width: parent.width
        visible: !root.editingDate
        text: root.isVisited ? ("visited" + (root.visitedOn !== "" ? " · " + root.visitedOn : "") + " · edit") : "unvisited"
        color: root.isVisited ? Theme.accent : Theme.tertiary
        font.family: Theme.font
        font.pixelSize: Theme.footnote
        MouseArea {
          anchors.fill: parent
          cursorShape: root.isVisited ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            if (!root.isVisited) return
            root.dateDraft = root.visitedOn
            root.dateError = ""
            root.editingDate = true
          }
        }
      }
      Column {
        width: parent.width
        visible: root.editingDate
        spacing: Theme.s(4)
        Field {
          id: dateField
          width: parent.width
          placeholder: "YYYY-MM-DD"
          text: root.dateDraft
          onTextChanged: root.dateDraft = text
          onAccepted: root.commitDate()
          onEscaped: root.editingDate = false
        }
        Text {
          width: parent.width
          visible: root.dateError !== ""
          text: root.dateError
          color: Theme.tertiary
          font.family: Theme.font
          font.pixelSize: Theme.caption
        }
      }

      Row {
        width: parent.width
        spacing: Theme.s(8)
        visible: root.provTotal > 1
        ProgressBar {
          width: parent.width - provLbl.width - Theme.s(8)
          anchors.verticalCenter: parent.verticalCenter
          value: root.provTotal > 0 ? root.provVisited / root.provTotal : 0
          fillColor: Theme.accent
          barHeight: Theme.s(5)
        }
        Text {
          id: provLbl
          text: root.provVisited + "/" + root.provTotal
          color: Theme.tertiary
          font.family: "monospace"
          font.pixelSize: Theme.caption
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      PillButton {
        width: parent.width
        text: root.isVisited ? "mark unvisited" : "mark visited"
        primary: !root.isVisited
        tint: Theme.accent
        onClicked: root.toggle()
      }
    }
  }
}
