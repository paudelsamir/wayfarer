import QtQuick

// Capsule toggle with press physics. Country pills, province filters,
// unit pickers.
Rectangle {
  id: root

  property string text: ""
  property bool selected: false
  property color tint: Theme.accent

  signal clicked()

  implicitHeight: Theme.s(26)
  implicitWidth: row.implicitWidth + Theme.s(22)
  radius: height / 2
  color: selected ? Theme.alpha(tint, 0.22) : (mouse.containsMouse ? Theme.fillHover : Theme.fill)
  border.width: 1
  border.color: selected ? Theme.alpha(tint, 0.5) : "transparent"
  scale: mouse.pressed ? 0.94 : 1
  Behavior on color { ColorAnimation { duration: Theme.fast } }
  Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

  Row {
    id: row
    anchors.centerIn: parent
    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.selected ? Theme.label : Theme.secondary
      font.family: Theme.font
      font.pixelSize: Theme.callout
      font.weight: root.selected ? Font.DemiBold : Font.Normal
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
