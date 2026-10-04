import QtQuick

// Quiet slider: a soft track, an accent fill, a knob that follows.
// Drag or click to jump. Reports continuous values; owners round.
Rectangle {
  id: root

  property real value: 1.0
  property real minimum: 0.3
  property real maximum: 1.0

  signal moved(real value)

  implicitWidth: Theme.s(160)
  implicitHeight: Theme.s(22)

  color: "transparent"

  function setFromX(x) {
    var t = Math.max(0, Math.min(1, x / track.width))
    var v = minimum + t * (maximum - minimum)
    if (v !== value) {
      value = v
      moved(v)
    }
  }

  Rectangle {
    id: track
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: Theme.s(5)
    radius: height / 2
    color: Theme.fillStrong

    Rectangle {
      width: parent.width * ((root.value - root.minimum) / (root.maximum - root.minimum))
      height: parent.height
      radius: parent.radius
      color: Theme.accent
      Behavior on width { NumberAnimation { duration: Theme.fast } }
    }
  }

  Rectangle {
    id: knob
    width: Theme.s(14)
    height: Theme.s(14)
    radius: width / 2
    color: Theme.label
    x: track.width * ((root.value - root.minimum) / (root.maximum - root.minimum)) - width / 2
    anchors.verticalCenter: parent.verticalCenter
    scale: drag.pressed ? 1.15 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
  }

  MouseArea {
    id: drag
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: function(mouse) { root.setFromX(mouse.x) }
    onPositionChanged: function(mouse) { if (pressed) root.setFromX(mouse.x) }
  }
}
