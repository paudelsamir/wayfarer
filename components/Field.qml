import QtQuick

// Text input with a quiet focus ring. Search fields, country filter.
Rectangle {
  id: root

  property alias text: input.text
  property alias input: input
  property string placeholder: ""

  signal accepted()
  signal escaped()

  function focusInput() { input.forceActiveFocus() }

  implicitWidth: Theme.s(200)
  implicitHeight: Theme.controlHeight + Theme.s(4)
  radius: Theme.radiusControl
  color: input.activeFocus ? Theme.fillStrong : (hover.hovered ? Theme.fillHover : Theme.fill)
  border.width: 1
  border.color: input.activeFocus ? Theme.alpha(Theme.accent, 0.55) : "transparent"
  Behavior on color { ColorAnimation { duration: Theme.fast } }
  Behavior on border.color { ColorAnimation { duration: Theme.fast } }

  HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

  TextInput {
    id: input
    anchors.left: parent.left
    anchors.leftMargin: Theme.s(11)
    anchors.right: parent.right
    anchors.rightMargin: Theme.s(11)
    anchors.verticalCenter: parent.verticalCenter
    color: Theme.label
    selectionColor: Theme.alpha(Theme.accent, 0.35)
    selectedTextColor: Theme.label
    font.family: Theme.font
    font.pixelSize: Theme.body
    clip: true
    selectByMouse: true
    Keys.onReturnPressed: root.accepted()
    Keys.onEscapePressed: root.escaped()
  }

  Text {
    textFormat: Text.PlainText
    visible: input.text === "" && root.placeholder !== ""
    anchors.left: parent.left
    anchors.leftMargin: Theme.s(11)
    anchors.verticalCenter: parent.verticalCenter
    text: root.placeholder
    color: Theme.tertiary
    font.family: Theme.font
    font.pixelSize: Theme.body
  }
}
