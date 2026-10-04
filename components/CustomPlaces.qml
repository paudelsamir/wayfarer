import QtQuick

// Custom places: quiet rows with dot radios, generous air.
Item {
  id: root
  property var store: null

  readonly property var places: store && store.goal && store.goal.places ? store.goal.places : []

  Column {
    anchors.centerIn: parent
    width: Math.min(420, parent.width - 80)
    spacing: Theme.s(4)

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: "your places"
      color: Theme.label
      font.family: Theme.serif
      font.pixelSize: 20
      font.italic: true
    }
    Item { width: 1; height: Theme.s(10) }

    Repeater {
      model: root.places
      Rectangle {
        width: parent.width
        height: Theme.rowHeight
        radius: Theme.radiusSmall
        color: rowHover.containsMouse ? Theme.fillHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Row {
          anchors.fill: parent
          anchors.leftMargin: Theme.s(12)
          anchors.rightMargin: Theme.s(12)
          spacing: Theme.s(12)
          CheckCircle {
            checked: !!store.visitedCustom[modelData.id]
            anchors.verticalCenter: parent.verticalCenter
            onToggled: store.toggleCustom(modelData.id)
          }
          Text {
            text: modelData.name
            color: store.visitedCustom[modelData.id] ? Theme.label : Theme.secondary
            font.family: Theme.font
            font.pixelSize: Theme.body
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Theme.fast } }
          }
        }
        MouseArea {
          id: rowHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: store.toggleCustom(modelData.id)
        }
      }
    }

    Item { width: 1; height: Theme.s(10) }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: "edit the list in setup → revisit setup"
      color: Theme.quaternary
      font.family: Theme.font
      font.pixelSize: Theme.footnote
    }
  }
}
