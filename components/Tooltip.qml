import QtQuick

// Small premium tooltip: serif place, mono context, accent status.
// Pops in with a soft scale, like everything else here.
Rectangle {
  id: root
  property string placeName: ""
  property string subLine: ""
  property string statusLine: ""

  visible: placeName !== "" && pop.scale > 0.01
  width: 232
  height: col.implicitHeight + Theme.pad + 6
  radius: Theme.radiusControl
  color: Theme.bg
  border.width: 1
  border.color: Theme.separator

  Item {
    id: pop
    anchors.fill: parent
    scale: root.placeName !== "" ? 1 : 0.94
    opacity: root.placeName !== "" ? 1 : 0
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    Column {
      id: col
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Theme.pad
      anchors.rightMargin: Theme.pad
      spacing: 3

      Text {
        width: parent.width
        text: root.placeName
        color: Theme.label
        font.family: Theme.serif
        font.pixelSize: 15
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        visible: root.subLine !== ""
        text: root.subLine
        color: Theme.secondary
        font.family: "monospace"
        font.pixelSize: Theme.caption
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        visible: root.statusLine !== ""
        text: root.statusLine
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: Theme.caption
        elide: Text.ElideRight
      }
    }
  }
}
